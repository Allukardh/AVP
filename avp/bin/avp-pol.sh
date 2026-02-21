#!/bin/sh
# =============================================================
# AutoVPN Platform (AVP)
# Component : AVP-POL
# File      : avp-pol.sh
# Role      : Policy Controller (global.conf + profiles.conf + devices.conf)
# Version   : v1.3.24 (2026-02-20)
# Status    : stable
# =============================================================

SCRIPT_VER="v1.3.24"
export PATH="/jffs/scripts:/jffs/scripts/avp/bin:/opt/bin:/opt/sbin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH:-}"
hash -r 2>/dev/null || true
set -u

ENGINE="/jffs/scripts/avp/bin/avp-eng.sh"

POLICY_DIR="/jffs/scripts/avp/policy"
GLOBAL_CONF="$POLICY_DIR/global.conf"
PROFILES_CONF="$POLICY_DIR/profiles.conf"
DEVICES_CONF="$POLICY_DIR/devices.conf"

# GUI / API state (C2.1)
AVP_STATE_DIR="/jffs/scripts/avp/state"
AVP_GUI_APPLY_STATE="$AVP_STATE_DIR/avp_gui_apply.state"
AVP_LOGDIR="${AVP_LOGDIR:-/tmp/avp_logs}"
AVP_LIB="/jffs/scripts/avp/lib/avp-lib.sh"
[ -f "$AVP_LIB" ] && . "$AVP_LIB"
type has_fn >/dev/null 2>&1 || has_fn(){ type "$1" >/dev/null 2>&1; }
has_fn avp_init_layout && avp_init_layout >/dev/null 2>&1 || :

[ -d "$AVP_LOGDIR" ] || mkdir -p "$AVP_LOGDIR" 2>/dev/null || :

# Lock (writers) para evitar concorrência em operações mutantes de policy
POL_LOCKDIR="/tmp/avp_pol.lock"
POL_LOCK_WAIT=5
POL_LOCK_HELD=0
POL_LOCK_TRAP_SET=0

DEFAULT_PROFILE="balanced"
CRITICAL_VARS="AVP_LOGDIR AVP_LOGDIR_POLICY AVP_LOGDIR_ENG AVP_LOGDIR_DIAG"
CRITICAL_VARS="${CRITICAL_VARS} AVP_ERRORS_LOG AVP_EVENTS_LOG AVP_GUI_APPLY_STATE"
DEF_COOLDOWN_SEC=600
DEF_WAN_STABLE_RUNS=3
DEF_VPN_BACK_STABLE_RUNS=5

# Defaults alinhados ao AVP-ENG (v1.0.14)
DEF_WAN_ADVANTAGE_MS=20
DEF_VPN_BACK_MARGIN_MS=10

DEF_RETURN_DELAY_SEC=3600
DEF_RETURN_MARGIN_MS=5
DEF_RETURN_STABLE_RUNS=5

DEF_QUAR_DEGRADE_SCORE=120
DEF_QUAR_DEGRADE_RUNS=3
DEF_QUAR_AVOID_SEC=1800

ts() { date "+%Y-%m-%d %H:%M:%S"; }
ts_epoch() { date +%s; }

pol_lock_acquire() {
  _wait="${1:-${POL_LOCK_WAIT:-5}}"
  _i=0
  while ! mkdir "$POL_LOCKDIR" 2>/dev/null; do
    # stale lock? se pid morto, remove e tenta de novo
    if [ -f "$POL_LOCKDIR/pid" ]; then
      _pid="$(cat "$POL_LOCKDIR/pid" 2>/dev/null || echo "")"
      if [ -n "$_pid" ] && ! kill -0 "$_pid" 2>/dev/null; then
        rm -rf "$POL_LOCKDIR" 2>/dev/null || :
        continue
      fi
    fi
    _i=$((_i+1))
    [ "$_i" -ge "$_wait" ] && return 1
    sleep 1
  done
  echo "$$" >"$POL_LOCKDIR/pid" 2>/dev/null || :
  echo "$(ts_epoch)" >"$POL_LOCKDIR/ts" 2>/dev/null || :
  POL_LOCK_HELD=1
  # trap p/ reduzir chance de lock preso em falhas (SIGKILL não é capturável)
  if [ "${POL_LOCK_TRAP_SET:-0}" != "1" ]; then
    trap "pol_lock_cleanup" EXIT HUP INT TERM
    POL_LOCK_TRAP_SET=1
  fi
  return 0
}

pol_lock_release() {
  # idempotente; não remove lock de outro PID
  if [ -f "$POL_LOCKDIR/pid" ] && [ "$(cat "$POL_LOCKDIR/pid" 2>/dev/null || echo "")" != "$$" ]; then
    POL_LOCK_HELD=0
    return 0
  fi
  rm -rf "$POL_LOCKDIR" 2>/dev/null || :
  POL_LOCK_HELD=0
  return 0
}

pol_lock_cleanup() {
  # cleanup via trap (EXIT/HUP/INT/TERM): remove somente se o lock pertence a este PID
  [ "${POL_LOCK_HELD:-0}" = "1" ] || return 0
  if [ -f "$POL_LOCKDIR/pid" ] && [ "$(cat "$POL_LOCKDIR/pid" 2>/dev/null || echo "")" = "$$" ]; then
    rm -rf "$POL_LOCKDIR" 2>/dev/null || :
  fi
  POL_LOCK_HELD=0
  return 0
}
jesc() {
  printf '%s' "$1" | sed \
    -e 's/\\/\\\\/g' \
    -e 's/"/\\"/g' \
    -e 's/\t/\\t/g' \
    -e 's/\r/\\r/g' \
    -e ':a;N;$!ba;s/\n/\\n/g'
}

json_reply() {
  ok="$1"; rc="$2"; action="$3"; msg="$4"; data="${5:-{}}"

  # FIX(v1.3.2): sanitize data JSON (remove somente "}" extra quando houver desbalanceamento)
  case "$data" in
    {*)
      data="$(printf "%s" "$data" | sed "s/[[:space:]]*$//")"
      set -- $(printf "%s" "$data" | awk "{ o+=gsub(/\\{/ ,\"{\"); c+=gsub(/\\}/,\"}\"); } END{ print o, c }")
      o="${1:-0}"; c="${2:-0}"
      while [ "$c" -gt "$o" ]; do
        case "$data" in
          *"}") data="${data%?}"; c=$((c-1));;
          *) break;;
        esac
      done
    ;;
  esac

  tsj="$(ts_epoch)"
  [ "$ok" = "1" ] && okstr=true || okstr=false

  printf '{'
  printf '"ok":%s,' "$okstr"
  printf '"rc":%s,' "$rc"
  printf '"action":"%s",' "$(jesc "$action")"
  printf '"msg":"%s",' "$(jesc "$msg")"
  printf '"data":%s,' "$data"
  printf '"ts":%s' "$tsj"
  printf '}\n'
}

json_ok()  { json_reply 1 "${1:-0}" "${2:-ok}"  "${3:-ok}"  "${4:-{}}"; }
json_err(){
  # Flash-Safe v1: 1 linha no flash (erro) + JSON no stdout
  rc="${1:-1}"
  msg="${3:-error}"
  if has_fn log_error; then
    log_error "POL" "json_err" "$rc" "msg=$msg"
  fi
  json_reply 0 "$rc" "${2:-err}" "$msg" "${4:-{}}"
}

ensure_state_dir() { [ -d "$AVP_STATE_DIR" ] || mkdir -p "$AVP_STATE_DIR" 2>/dev/null || :; }

is_label() { echo "$1" | grep -Eq '^[A-Za-z0-9_-]{1,32}$'; }

is_ipv4() {
  echo "$1" | awk -F. '
    NF!=4{exit 1}
    {for(i=1;i<=4;i++){
      if($i!~/^[0-9]+$/) exit 1;
      if($i<0||$i>255) exit 1
    }}
    END{exit 0}'
}

is_rule() {
  case "$1" in
    balanced|force_vpn|force_wan|bypass|block) return 0;;
    *) return 1;;
  esac
}

fix_policy_perms() {
  _ref=""
  _uid="0"
  _gid="0"

  # Prefer devices.conf (if present) to mirror intended policy ownership; fallback to global.conf; final fallback 0:0
  if [ -f "$DEVICES_CONF" ]; then
    _ref="$DEVICES_CONF"
  elif [ -f "$GLOBAL_CONF" ]; then
    _ref="$GLOBAL_CONF"
  fi

  if [ -n "${_ref:-}" ]; then
    _uid="$(ls -ln "$_ref" 2>/dev/null | awk '{print $3}')"
    _gid="$(ls -ln "$_ref" 2>/dev/null | awk '{print $4}')"
    case "${_uid:-}" in ""|*[!0-9]* ) _uid="0";; esac
    case "${_gid:-}" in ""|*[!0-9]* ) _gid="0";; esac
  fi

  # perms + ownership (best-effort; never fatal)
  [ -f "$GLOBAL_CONF" ]   && chmod 0600 "$GLOBAL_CONF"   2>/dev/null || :
  [ -f "$PROFILES_CONF" ] && chmod 0600 "$PROFILES_CONF" 2>/dev/null || :
  [ -f "$DEVICES_CONF" ]  && chmod 0600 "$DEVICES_CONF"  2>/dev/null || :

  [ -f "$GLOBAL_CONF" ]   && chown "${_uid}:${_gid}" "$GLOBAL_CONF"   2>/dev/null || :
  [ -f "$PROFILES_CONF" ] && chown "${_uid}:${_gid}" "$PROFILES_CONF" 2>/dev/null || :
  [ -f "$DEVICES_CONF" ]  && chown "${_uid}:${_gid}" "$DEVICES_CONF"  2>/dev/null || :
}

require_profiles_files() {
  [ -d "$POLICY_DIR" ] || die 10 "policy_dir ausente: $POLICY_DIR"
  [ -f "$GLOBAL_CONF" ] || die 10 "global.conf ausente: $GLOBAL_CONF"
  [ -f "$PROFILES_CONF" ] || die 10 "profiles.conf ausente: $PROFILES_CONF"
  fix_policy_perms
}

profile_exists() { grep -q "^\[$1\]" "$PROFILES_CONF" 2>/dev/null; }

profiles_list_json() {
  awk '
    BEGIN{first=1; printf "["}
    /^\[/{gsub(/^\[/,"");gsub(/\]$/,"");
      if(NF){
        if(first==0) printf ",";
        first=0;
        gsub(/\\/,"\\\\"); gsub(/"/,"\\\"");
        printf "\"%s\"", $0
      }
    }
    END{printf "]"}
  ' "$PROFILES_CONF" 2>/dev/null
}

devices_list_json() {
  awk '
    BEGIN{ first=1; printf "[" }
    /^[[:space:]]*#/ || NF<3 { next }
    {
      label=$1; ip=$2; pref=$3; rule=$4;
      if(rule==""){ rule="balanced" }
      if(first==0){ printf "," } else { first=0 }
      gsub(/\\/,"\\\\",label); gsub(/"/,"\\\"",label)
      gsub(/\\/,"\\\\",ip);    gsub(/"/,"\\\"",ip)
      gsub(/\\/,"\\\\",rule);  gsub(/"/,"\\\"",rule)
      printf "{\"label\":\"%s\",\"ip\":\"%s\",\"pref\":%s,\"rule\":\"%s\"}",
             label, ip, pref, rule
    }
    END{ printf "]" }
  ' "$DEVICES_CONF" 2>/dev/null
}

LIVE_MODE=0
LIVE_SLEEP=5

is_live_arg() { [ "$1" = "--live" ]; }

load_global() {
  . "$GLOBAL_CONF" 2>/dev/null || :
  [ -z "${AUTOVPN_ENABLED:-}" ] && AUTOVPN_ENABLED=1
  [ -z "${AUTOVPN_PROFILE:-}" ] && AUTOVPN_PROFILE="$DEFAULT_PROFILE"
}

init_global() {
  # Garante GLOBAL_CONF mínimo (status/enable/disable podem rodar mesmo sem devices.conf)
  [ -d "$POLICY_DIR" ] || mkdir -p "$POLICY_DIR" 2>/dev/null || :
  if [ ! -f "$GLOBAL_CONF" ]; then
    cat >"$GLOBAL_CONF" <<'EOF'
AUTOVPN_ENABLED=1
AUTOVPN_PROFILE=balanced
EOF
  fi
  load_global
}

POL_RC=0
set_rc(){ [ "${POL_RC:-0}" -eq 0 ] && POL_RC="$1"; }

err(){
  code="$1"; shift
  msg="$*"
  echo "[ERR] code=${code} ${msg}" >&2
  if has_fn log_error; then
    log_error "POL" "${msg}" "${code}"
  fi
}

next(){
  echo "[NEXT] $*" >&2
}

die() {
  code="${1:-10}"; shift
  err "$code" "$*"
  next "verifique: policy_dir=$POLICY_DIR | global=$GLOBAL_CONF | profiles=$PROFILES_CONF | devices=$DEVICES_CONF"
  set_rc "$code"
  exit "$code"
}

devices_conf_has_entries() {
  [ -f "$DEVICES_CONF" ] || return 1
  awk '
    { gsub(/\r/, "") }
    /^[[:space:]]*#/ {next}
    /^[[:space:]]*$/ {next}
    NF>=3 { ok=1; exit 0 }
    END { exit(ok?0:1) }
  ' "$DEVICES_CONF"
}

require_policy_files() {
  [ -d "$POLICY_DIR" ] || die 10 "policy_dir ausente: $POLICY_DIR"
  [ -f "$GLOBAL_CONF" ] || die 10 "global.conf ausente: $GLOBAL_CONF"
  [ -f "$PROFILES_CONF" ] || die 10 "profiles.conf ausente: $PROFILES_CONF"
  fix_policy_perms
  [ -f "$DEVICES_CONF" ] || die 10 "devices.conf ausente: $DEVICES_CONF"
  fix_policy_perms
  devices_conf_has_entries || die 20 "devices.conf ausente/vazio/inválido: $DEVICES_CONF"
}

clean_line() { tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'; }

is_positive_int() {

  case "$1" in
    ""|*[!0-9]* ) return 1 ;;
    0) return 1 ;;
    *) return 0 ;;
  esac
}

get_profile_kv_lines() {
  prof="$1"
  [ -f "$PROFILES_CONF" ] || return 1
  in=0
  while IFS= read -r raw || [ -n "$raw" ]; do
    line="$(printf "%s" "$raw" | clean_line)"
    [ -z "$line" ] && continue
    case "$line" in
      \#*) continue ;;
      \[*\])
        sec="${line#\[}"; sec="${sec%\]}"
        [ "$sec" = "$prof" ] && in=1 || in=0
        continue ;;
    esac
    [ "$in" -ne 1 ] && continue
    case "$line" in
      *"="*)
        key="$(printf "%s" "${line%%=*}" | clean_line)"
        val="$(printf "%s" "${line#*=}" | clean_line)"
        val="${val%%#*}"; val="${val%%;*}"
        val="$(printf "%s" "$val" | clean_line)"
        case "$key" in
          [A-Z0-9_]*)
            [ -n "$key" ] && printf "%s=%s\n" "$key" "$val"
            ;;
        esac ;;
    esac
  done <"$PROFILES_CONF"
}

apply_profile_exports() {
  prof="$1"
  lines="$(get_profile_kv_lines "$prof" 2>/dev/null)" || return 1
  [ -z "$lines" ] && return 1
  while IFS= read -r kv || [ -n "$kv" ]; do
    key="${kv%%=*}"; val="${kv#*=}"
    case " $CRITICAL_VARS " in
      *" $key "*)
        if ! is_positive_int "$val"; then
          case "$key" in
             COOLDOWN_SEC) val="$DEF_COOLDOWN_SEC" ;;
             WAN_STABLE_RUNS) val="$DEF_WAN_STABLE_RUNS" ;;
             VPN_BACK_STABLE_RUNS) val="$DEF_VPN_BACK_STABLE_RUNS" ;;
             WAN_ADVANTAGE_MS) val="$DEF_WAN_ADVANTAGE_MS" ;;
             VPN_BACK_MARGIN_MS) val="$DEF_VPN_BACK_MARGIN_MS" ;;
             RETURN_DELAY_SEC) val="$DEF_RETURN_DELAY_SEC" ;;
             RETURN_MARGIN_MS) val="$DEF_RETURN_MARGIN_MS" ;;
             RETURN_STABLE_RUNS) val="$DEF_RETURN_STABLE_RUNS" ;;
             QUAR_DEGRADE_SCORE) val="$DEF_QUAR_DEGRADE_SCORE" ;;
             QUAR_DEGRADE_RUNS) val="$DEF_QUAR_DEGRADE_RUNS" ;;
             QUAR_AVOID_SEC) val="$DEF_QUAR_AVOID_SEC" ;;
           esac
        fi ;;
    esac
    export "$key=$val"
  done <<EOF2
$lines
EOF2
}

ensure_profiles_conf() {
  [ -f "$PROFILES_CONF" ] && return 0
  cat >"$PROFILES_CONF" <<'EOF2'
# AVP Profiles
# conservative / balanced / aggressive
#
# Values are exported by AVP-POL and consumed by AVP-ENG.
# Keep [balanced] aligned with current AVP-ENG defaults to avoid behavioral change.
#
# Keys:
#   COOLDOWN_SEC, WAN_STABLE_RUNS, VPN_BACK_STABLE_RUNS
#   WAN_ADVANTAGE_MS, VPN_BACK_MARGIN_MS
#   RETURN_DELAY_SEC, RETURN_MARGIN_MS, RETURN_STABLE_RUNS
#   QUAR_DEGRADE_SCORE, QUAR_DEGRADE_RUNS, QUAR_AVOID_SEC

[conservative]
# core cadence
COOLDOWN_SEC=900
WAN_STABLE_RUNS=5
VPN_BACK_STABLE_RUNS=4

# WAN fallback / return
WAN_ADVANTAGE_MS=30
VPN_BACK_MARGIN_MS=10

# return-to-default (wgc1) behavior
RETURN_DELAY_SEC=7200
RETURN_MARGIN_MS=5
RETURN_STABLE_RUNS=6

# quarantine (WG degraded)
QUAR_DEGRADE_SCORE=120
QUAR_DEGRADE_RUNS=3
QUAR_AVOID_SEC=3600

[balanced]
# core cadence (CURRENT)
COOLDOWN_SEC=600
WAN_STABLE_RUNS=3
VPN_BACK_STABLE_RUNS=5

# WAN fallback / return (CURRENT ENG DEFAULTS)
WAN_ADVANTAGE_MS=20
VPN_BACK_MARGIN_MS=10

# return-to-default (CURRENT ENG DEFAULTS)
RETURN_DELAY_SEC=3600
RETURN_MARGIN_MS=5
RETURN_STABLE_RUNS=5

# quarantine (CURRENT ENG DEFAULTS)
QUAR_DEGRADE_SCORE=120
QUAR_DEGRADE_RUNS=3
QUAR_AVOID_SEC=1800

[aggressive]
# core cadence
COOLDOWN_SEC=300
WAN_STABLE_RUNS=2
VPN_BACK_STABLE_RUNS=2

# WAN fallback / return
WAN_ADVANTAGE_MS=20
VPN_BACK_MARGIN_MS=10

# return-to-default
RETURN_DELAY_SEC=900
RETURN_MARGIN_MS=5
RETURN_STABLE_RUNS=3

# quarantine
QUAR_DEGRADE_SCORE=120
QUAR_DEGRADE_RUNS=2
QUAR_AVOID_SEC=900
EOF2
}


show_help() {
  cat <<EOF
Usage:
  (AVP-POL version: ${SCRIPT_VER:-unknown})
  avp-pol.sh enable
  avp-pol.sh disable
  avp-pol.sh status
  avp-pol.sh run [--live] [--show-last]

Notes:
  enable/disable:
    - cria (se faltar) e atualiza global.conf (AUTOVPN_ENABLED=1/0)

  status:
    - mostra AUTOVPN_ENABLED/AUTOVPN_PROFILE e os paths:
      POLICY_DIR / GLOBAL_CONF / PROFILES_CONF / DEVICES_CONF

  run (padrão):
    - 1 ciclo silencioso: aplica policy/profile e chama o ENG (quiet)
    - saída vai para o log do ENG em /tmp/avp_logs

  run --show-last:
    - imprime o último log do ENG (1 ciclo), sem executar nada

  run --live:
    - loop "ao vivo" (a cada 5s): chama o ENG com AVP_LIVE=1
    - streaming real no terminal (ENG faz tail -f do TMPLOG)
    - para parar: Ctrl+C
EOF
}

cmd_show_last() {
  LOG_DIR="$AVP_LOGDIR"
  last="$(ls -1t "$LOG_DIR"/avp_eng_*.log 2>/dev/null | head -n 1)"
  if [ -z "${last:-}" ]; then
    echo "ERR: no logs found in $LOG_DIR" >&2
    return 1
  fi
  echo "LAST_LOG=$last"
  echo "--------------------------------"
  cat "$last" 2>/dev/null || :
}

_deg_window_summary() {
  # Degraded = houve ERROR recente dentro da janela (leitura do flash; sem escrita extra)
  # ENV: AVP_DEG_WINDOW_SEC (default 600)
  # Output: DEG|CNT|LAST_TS|SINCE|COMP|MSG|RC|WIN
  _now="$(date +%s 2>/dev/null || echo 0)"
  _win="${AVP_DEG_WINDOW_SEC:-600}"
  _f="/jffs/scripts/avp/logs/avp_errors.log"

  _cnt=0
  _last_ts=""
  _last_comp=""
  _last_msg=""
  _last_rc=""

  if [ -f "$_f" ] && [ "$_now" -gt 0 ] && [ "$_win" -gt 0 ]; then
    _out="$(awk -v now="$_now" -v win="$_win" '
      BEGIN{cnt=0;lt="";lc="";lm="";lrc=""}
      {
        if(match($0, /"ts":"[0-9]+"/)){t=substr($0,RSTART+6,RLENGTH-7)+0}else{next}
        if(t >= (now-win)){
          cnt++; lt=t;
          if(match($0, /"comp":"[^"]*"/)){lc=substr($0,RSTART+8,RLENGTH-9)} else {lc=""}
          if(match($0, /"msg":"[^"]*"/)){lm=substr($0,RSTART+7,RLENGTH-8)} else {lm=""}
          if(match($0, /"rc":[-0-9]+/)){lrc=substr($0,RSTART+5,RLENGTH-5)} else {lrc=""}
        }
      }
      END{printf "%d|%s|%s|%s|%s", cnt, lt, lc, lm, lrc}
    ' "$_f" 2>/dev/null)"
    IFS='|' read -r _cnt _last_ts _last_comp _last_msg _last_rc <<EOF
$_out
EOF
  fi

  if [ "${_cnt:-0}" -gt 0 ] && [ -n "${_last_ts:-}" ]; then
    _deg=1
    _since=$(( _now - _last_ts ))
    [ "$_since" -lt 0 ] && _since=0
  else
    _deg=0
    _since=0
  fi

  printf '%s|%s|%s|%s|%s|%s|%s|%s' "$_deg" "${_cnt:-0}" "${_last_ts:-}" "${_since:-0}" "${_last_comp:-}" "${_last_msg:-}" "${_last_rc:-}" "${_win:-600}"
}

cmd_status_json() {
  init_global

  _dw="$(_deg_window_summary)"
  IFS='|' read -r _deg _deg_cnt _deg_last_ts _deg_since _deg_comp _deg_msg _deg_rc _deg_win <<EOF
$_dw
EOF
  _deg_reason=""
  if [ "${_deg:-0}" -eq 1 ]; then
    _deg_reason="${_deg_comp:-}: ${_deg_msg:-} (rc=${_deg_rc:-})"
  fi

  _last_eng="$(ls -1t "$AVP_LOGDIR"/avp_eng_*.log 2>/dev/null | head -n 1)"
  _cronlog="$AVP_LOGDIR/avp-pol-cron.log"
  _last_rc=""

  if [ -f "$_cronlog" ]; then
    _last_rc="$(awk '/\[CRON\] AVP-POL-CRON .* END rc=/{for(i=1;i<=NF;i++) if($i ~ /^rc=/) rc=$i} END{print rc}' \
      "$_cronlog" 2>/dev/null)"
  fi

  data="$(printf '{'
    printf '"enabled":%s,' "${AUTOVPN_ENABLED:-1}"
    printf '"profile":"%s",' "$(jesc "${AUTOVPN_PROFILE:-$DEFAULT_PROFILE}")"
    printf '"policy_dir":"%s",' "$(jesc "$POLICY_DIR")"
    printf '"global_conf":"%s",' "$(jesc "$GLOBAL_CONF")"
    printf '"profiles_conf":"%s",' "$(jesc "$PROFILES_CONF")"
    printf '"devices_conf":"%s",' "$(jesc "$DEVICES_CONF")"
    printf '"last_eng_log":"%s",' "$(jesc "${_last_eng:-}")"
    printf '"cron_log":"%s",' "$(jesc "$_cronlog")"
    printf '"cron_last_rc":"%s",' "$(jesc "${_last_rc:-}")"
    printf '"degraded":%s,'         "${_deg:-0}"
    printf '"degraded_err_count":%s,' "${_deg_cnt:-0}"
    printf '"degraded_last_ts":"%s",' "$(jesc "${_deg_last_ts:-}")"
    printf '"degraded_since_sec":%s,' "${_deg_since:-0}"
    printf '"degraded_reason":"%s",'  "$(jesc "${_deg_reason:-}")"
    printf '"degraded_window_sec":%s,' "${_deg_win:-600}"
    printf '"script_ver":"%s"' "$(jesc "${SCRIPT_VER:-}")"
    printf '}'
  )"

  json_ok 0 "status" "ok" "$data"
}

cmd_profile_list() {
  require_profiles_files
  data="$(printf '{ "profiles": %s }' "$(profiles_list_json)")"
  json_ok 0 "profile_list" "ok" "$data"
}

cmd_profile_get() {
  init_global
  require_profiles_files
  cur="${AUTOVPN_PROFILE:-$DEFAULT_PROFILE}"
  data="$(printf '{ "profile":"%s", "profiles": %s }' "$(jesc "$cur")" "$(profiles_list_json)")"
  json_ok 0 "profile_get" "ok" "$data"
}

cmd_profile_set() {
  name="$1"
  require_profiles_files

  [ -n "${name:-}" ] || { json_err 22 "profile_set" "missing profile" '{"hint":"profile set <name>"}'; return 22; }
  profile_exists "$name" || {
    data="$(printf '{ "allowed": %s }' "$(profiles_list_json)")"
    json_err 22 "profile_set" "invalid profile" "$data"
    return 22
  }

  pol_lock_acquire || {
    json_err 75 "profile_set" "policy busy" '{"hint":"try again"}'
    return 75
  }

  init_global
  sed -i "s/^AUTOVPN_PROFILE=.*/AUTOVPN_PROFILE=$name/" "$GLOBAL_CONF" 2>/dev/null || :
  logger -t AVP-POL "profile_set: $name"
  log_action profile_set "profile=$name" "rc=0"
  data="$(printf '{ "profile":"%s" }' "$(jesc "$name")")"
  pol_lock_release

  json_ok 0 "profile_set" "ok" "$data"
}

cmd_device_list() {
  require_policy_files
  data="$(printf '{ "devices": %s }' "$(devices_list_json)")"
  json_ok 0 "device_list" "ok" "$data"
}

_next_pref() {
  awk '
    /^[[:space:]]*#/ || NF<3 { next }
    { if($3+0 > m) m=$3+0 }
    END{ if(m=="") m=11210; else m=m+1; print m }
  ' "$DEVICES_CONF" 2>/dev/null
}

cmd_device_add() {
  label="$1"; ip="$2"; rule="${3:-balanced}"; pref="${4:-}"
  require_policy_files

  is_label "$label" || { json_err 22 "device_add" "invalid label" '{"hint":"A-Z a-z 0-9 _ - (1..32)"}'; return 22; }
  is_ipv4 "$ip"   || { json_err 22 "device_add" "invalid ip" '{"hint":"ipv4 required"}'; return 22; }
  is_rule "$rule" || { json_err 22 "device_add" "invalid rule" '{"allowed":["balanced","force_vpn","force_wan","bypass","block"]}'; return 22; }

  pol_lock_acquire || {
    json_err 75 "device_add" "policy busy" '{"hint":"try again"}'
    return 75
  }

  awk -v L="$label" ' /^[[:space:]]*#/ {next} $1==L{found=1} END{exit(found?0:1)} ' \
    "$DEVICES_CONF" 2>/dev/null
  if [ $? -eq 0 ]; then
    data="$(printf '{ "label":"%s" }' "$(jesc "$label")")"
    json_err 17 "device_add" "device already exists" "$data"
    pol_lock_release
    return 17
  fi

  [ -n "${pref:-}" ] || pref="$(_next_pref)"
  printf '%-14s %-15s %-8s %s\n' "$label" "$ip" "$pref" "$rule" >>"$DEVICES_CONF"

  logger -t AVP-POL "device_add: $label $ip $pref $rule"
  log_action device_add "label=$label" "ip=$ip" "pref=$pref" "rule=$rule" "rc=0"

  data="$(printf '{ "label":"%s","ip":"%s","pref":%s,"rule":"%s" }' \
    "$(jesc "$label")" "$(jesc "$ip")" "$pref" "$(jesc "$rule")")"
  pol_lock_release

  json_ok 0 "device_add" "ok" "$data"
}

cmd_device_del() {
  label="$1"
  require_policy_files
  is_label "$label" || { json_err 22 "device_del" "invalid label" '{}'; return 22; }

  pol_lock_acquire || {
    json_err 75 "device_del" "policy busy" '{"hint":"try again"}'
    return 75
  }

  tmp="/tmp/avp_devices.$$"
  awk -v L="$label" '
    /^[[:space:]]*#/ { print; next }
    NF<3 { print; next }
    $1==L { removed=1; next }
    { print }
    END{ exit(removed?0:1) }
  ' "$DEVICES_CONF" >"$tmp" 2>/dev/null

  if [ $? -ne 0 ]; then
    rm -f "$tmp" 2>/dev/null || :
    data="$(printf '{ "label":"%s" }' "$(jesc "$label")")"
    json_err 2 "device_del" "device not found" "$data"
    pol_lock_release
    return 2
  fi

  mv "$tmp" "$DEVICES_CONF" 2>/dev/null || {
    rm -f "$tmp"
    json_err 1 "device_del" "failed to write devices.conf" '{}'
    pol_lock_release
    return 1
  }

  logger -t AVP-POL "device_del: $label"
  log_action device_del "label=$label" "rc=0"
  data="$(printf '{ "label":"%s" }' "$(jesc "$label")")"
  pol_lock_release

  json_ok 0 "device_del" "ok" "$data"
}

cmd_device_set() {
  label="$1"; ip="$2"; rule="${3:-balanced}"; pref="${4:-}"
  require_policy_files

  is_label "$label" || { json_err 22 "device_set" "invalid label" '{}'; return 22; }
  is_ipv4 "$ip"   || { json_err 22 "device_set" "invalid ip" '{}'; return 22; }
  is_rule "$rule" || { json_err 22 "device_set" "invalid rule" '{"allowed":["balanced","force_vpn","force_wan","bypass","block"]}'; return 22; }

  pol_lock_acquire || {
    json_err 75 "device_set" "policy busy" '{"hint":"try again"}'
    return 75
  }

  tmp="/tmp/avp_devices.$$"
  awk -v L="$label" -v IP="$ip" -v R="$rule" -v P="$pref" '
    BEGIN{ updated=0 }
    /^[[:space:]]*#/ { print; next }
    NF<3 { print; next }
    $1==L {
      updated=1
      if(P==""){ P=$3 }
      printf "%-14s %-15s %-8s %s\n", L, IP, P, R
      next
    }
    { print }
    END{ exit(updated?0:1) }
  ' "$DEVICES_CONF" >"$tmp" 2>/dev/null

  if [ $? -ne 0 ]; then
    rm -f "$tmp" 2>/dev/null || :
    data="$(printf '{ "label":"%s" }' "$(jesc "$label")")"
    json_err 2 "device_set" "device not found" "$data"
    pol_lock_release
    return 2
  fi

  mv "$tmp" "$DEVICES_CONF" 2>/dev/null || {
    rm -f "$tmp"
    json_err 1 "device_set" "failed to write devices.conf" '{}'
    pol_lock_release
    return 1
  }

  logger -t AVP-POL "device_set: $label $ip $rule"
  log_action device_set "label=$label" "ip=$ip" "rule=$rule" "rc=0"

  data="$(printf '{ "label":"%s","ip":"%s","rule":"%s" }' \
    "$(jesc "$label")" "$(jesc "$ip")" "$(jesc "$rule")")"
  pol_lock_release

  json_ok 0 "device_set" "ok" "$data"
}

cmd_reload() {
  local ASYNC RUN_ARGS WAIT_SECS
  local _before _after lf rc msg ok i tsn tmpf payload pid

  ASYNC=0
  RUN_ARGS=""
  WAIT_SECS=15

  while [ $# -gt 0 ]; do
    case "$1" in
      --async) ASYNC=1; shift;;
      --wait=*) WAIT_SECS="${1#--wait=}"; shift;;
      -h|--help) json_err 0 "reload" "usage" "{\"hint\":\"reload [--async] [--wait=N]\"}"; return 0;;
      token=*) _tok="${1#token=}"; TOKEN="$_tok"; AVP_TOKEN="$_tok"; export TOKEN AVP_TOKEN; shift;;
      *) data="$(printf "{ \"opt\":\"%s\" }" "$(jesc "$1")")"; json_err 2 "reload" "unknown option" "$data"; return 2;;
    esac
  done

  ensure_state_dir

  # pega referencia do ultimo log ANTES de rodar
  _before="$(ls -1t "$AVP_LOGDIR"/avp_eng_*.log 2>/dev/null | head -n 1)"

  if [ "$ASYNC" = "1" ]; then
    # modo async (GUI): marca PENDING e agenda
    tsn="$(ts_epoch)"
    tmpf="${AVP_GUI_APPLY_STATE}.tmp.$tsn.$$"
    payload="$(printf "TS=%s\nRC=PENDING\nLAST_LOG=\n" "$tsn")"
    state_write_file "$AVP_GUI_APPLY_STATE" "$payload" 2>/dev/null || :

    log_action "reload" "mode=async" "rc_state=pending"

    (
      local _b _a _lf _rc _msg _ok _i _ts2 _tmp2 _pl
      _b="$(ls -1t "$AVP_LOGDIR"/avp_eng_*.log 2>/dev/null | head -n 1)"
      cmd_run >/dev/null 2>&1
      _rc=$?
      _a="$(ls -1t "$AVP_LOGDIR"/avp_eng_*.log 2>/dev/null | head -n 1)"
      _lf="${_a:-${_b:-}}"

      if [ -n "${_lf:-}" ]; then
        _i=0
        while [ $_i -lt "$WAIT_SECS" ]; do
          grep -q " - DONE" "$_lf" 2>/dev/null && break
          sleep 1
          _i=$((_i+1))
        done
      fi

      if [ "$_rc" -eq 0 ] && [ -n "${_lf:-}" ] && grep -q " - DONE" "$_lf" 2>/dev/null; then
        _msg="applied"; _ok=1
      else
        [ "$_rc" -eq 0 ] && _rc=99
        _msg="apply_failed"; _ok=0
      fi

      _ts2="$(ts_epoch)"
      _pl="$(printf "TS=%s\nRC=%s\nLAST_LOG=%s\n" "$_ts2" "$_rc" "${_lf:-}")"
      state_write_file "$AVP_GUI_APPLY_STATE" "$_pl" 2>/dev/null || :

      logger -t AVP-POL "reload_async_done rc=$_rc last_log=${_lf:-none}"
      log_action "reload" "mode=async_done" "rc=$_rc" "last_log=${_lf:-}"
    ) >/dev/null 2>&1 &
    pid=$!

    data="$(printf "{ \"scheduled\":true,\"pid\":\"%s\" }" "$(jesc "$pid")")"
    json_reply 1 0 "reload" "scheduled" "$data"
    return 0
  fi

  # modo sync (CLI): roda e aguarda DONE no ultimo log
  cmd_run >/dev/null 2>&1
  rc=$?
  _after="$(ls -1t "$AVP_LOGDIR"/avp_eng_*.log 2>/dev/null | head -n 1)"
  lf="${_after:-${_before:-}}"

  if [ -n "${lf:-}" ]; then
    i=0
    while [ $i -lt "$WAIT_SECS" ]; do
      grep -q " - DONE" "$lf" 2>/dev/null && break
      sleep 1
      i=$((i+1))
    done
  fi

  if [ "$rc" -eq 0 ] && [ -n "${lf:-}" ] && grep -q " - DONE" "$lf" 2>/dev/null; then
    msg="applied"; ok=1
  else
    [ "$rc" -eq 0 ] && rc=99
    msg="apply_failed"; ok=0
  fi

  tsn="$(ts_epoch)"
  payload="$(printf "TS=%s\nRC=%s\nLAST_LOG=%s\n" "$tsn" "$rc" "${lf:-}")"
  state_write_file "$AVP_GUI_APPLY_STATE" "$payload" 2>/dev/null || :

  log_action "reload" "rc=$rc" "msg=$msg" "last_log=${lf:-}"
  json_reply "$ok" "$rc" "reload" "$msg" "{ \"last_log\":\"$(jesc "$lf")\" }"
  return $rc
}

cmd_snapshot() {
  init_global
  require_policy_files
  ensure_state_dir

  a_ts=""; a_rc=""; a_log=""
  if [ -f "$AVP_GUI_APPLY_STATE" ]; then
    a_ts="$(awk -F= '$1=="TS"{print $2}' "$AVP_GUI_APPLY_STATE" 2>/dev/null)"
    a_rc="$(awk -F= '$1=="RC"{print $2}' "$AVP_GUI_APPLY_STATE" 2>/dev/null)"
    a_log="$(awk -F= '$1=="LAST_LOG"{sub(/^LAST_LOG=/,"");print $0}' "$AVP_GUI_APPLY_STATE" 2>/dev/null)"
  fi

  data="$(printf '{'
    printf '"enabled":%s,' "${AUTOVPN_ENABLED:-1}"
    printf '"profile":"%s",' "$(jesc "${AUTOVPN_PROFILE:-$DEFAULT_PROFILE}")"
    printf '"profiles":%s,' "$(profiles_list_json)"
    printf '"devices":%s,' "$(devices_list_json)"
    printf '"last_apply":{'
      printf '"ts":"%s",' "$(jesc "${a_ts:-}")"
      printf '"rc":"%s",' "$(jesc "${a_rc:-}")"
      printf '"last_log":"%s"' "$(jesc "${a_log:-}")"
    printf '}'
    printf '}'
  )"

  json_ok 0 "snapshot" "ok" "$data"
}

cmd_enable() {
  # default: JSON canônico; --kv = fallback humano/legado
  OUT_MODE="json"
  [ "${1:-}" = "--kv" ] && OUT_MODE="kv"

  init_global
  pol_lock_acquire || {
    logger -t AVP-POL "busy: policy lock"
    if [ "$OUT_MODE" = "kv" ]; then
      echo "busy"
    else
      json_err 75 "enable" "busy" '{ "hint":"policy lock" }'
    fi
    return 75
  }
  sed -i 's/^AUTOVPN_ENABLED=.*/AUTOVPN_ENABLED=1/' "$GLOBAL_CONF" 2>/dev/null || :
  rc=$?
  pol_lock_release

  if [ "$rc" -eq 0 ]; then
    logger -t AVP-POL "enabled"
    if [ "$OUT_MODE" = "kv" ]; then
      echo "enabled"
    else
      json_ok 0 "enable" "enabled" '{ "enabled":1 }'
    fi
    return 0
  fi

  logger -t AVP-POL "ERR: enable_failed"
  if [ "$OUT_MODE" = "kv" ]; then
    echo "enable_failed"
  else
    json_err 70 "enable" "enable_failed" '{ "enabled":0 }'
  fi
  return 70
}

cmd_disable() {
  # default: JSON canônico; --kv = fallback humano/legado
  OUT_MODE="json"
  [ "${1:-}" = "--kv" ] && OUT_MODE="kv"

  init_global
  pol_lock_acquire || {
    logger -t AVP-POL "busy: policy lock"
    if [ "$OUT_MODE" = "kv" ]; then
      echo "busy"
    else
      json_err 75 "disable" "busy" '{ "hint":"policy lock" }'
    fi
    return 75
  }
  sed -i 's/^AUTOVPN_ENABLED=.*/AUTOVPN_ENABLED=0/' "$GLOBAL_CONF" 2>/dev/null || :
  rc=$?
  pol_lock_release

  if [ "$rc" -eq 0 ]; then
    logger -t AVP-POL "disabled"
    if [ "$OUT_MODE" = "kv" ]; then
      echo "disabled"
    else
      json_ok 0 "disable" "disabled" '{ "enabled":0 }'
    fi
    return 0
  fi

  logger -t AVP-POL "ERR: disable_failed"
  if [ "$OUT_MODE" = "kv" ]; then
    echo "disable_failed"
  else
    json_err 70 "disable" "disable_failed" '{ "enabled":1 }'
  fi
  return 70
}

cmd_status() {
  init_global
  _dw="$(_deg_window_summary)"
  IFS='|' read -r _deg _deg_cnt _deg_last_ts _deg_since _deg_comp _deg_msg _deg_rc _deg_win <<EOF
$_dw
EOF
  DEGRADED="${_deg:-0}"
  DEGRADED_ERR_COUNT="${_deg_cnt:-0}"
  DEGRADED_LAST_TS="${_deg_last_ts:-}"
  DEGRADED_SINCE_SEC="${_deg_since:-0}"
  if [ "${DEGRADED:-0}" -eq 1 ]; then
    DEGRADED_REASON="${_deg_comp:-}: ${_deg_msg:-} (rc=${_deg_rc:-})"
  else
    DEGRADED_REASON=""
  fi
  DEGRADED_WINDOW_SEC="${_deg_win:-600}"

  echo "AUTOVPN_ENABLED=${AUTOVPN_ENABLED:-1}"
  echo "AUTOVPN_PROFILE=${AUTOVPN_PROFILE:-$DEFAULT_PROFILE}"
  echo "POLICY_DIR=$POLICY_DIR"
  echo "GLOBAL_CONF=$GLOBAL_CONF"
  echo "PROFILES_CONF=$PROFILES_CONF"
  echo "DEVICES_CONF=$DEVICES_CONF"
  echo "DEGRADED=${DEGRADED}"
  echo "DEGRADED_REASON=${DEGRADED_REASON}"
  echo "DEGRADED_SINCE_SEC=${DEGRADED_SINCE_SEC}"
  echo "DEGRADED_WINDOW_SEC=${DEGRADED_WINDOW_SEC}"
  echo "DEGRADED_ERR_COUNT=${DEGRADED_ERR_COUNT}"
  echo "DEGRADED_LAST_TS=${DEGRADED_LAST_TS}"
  # Observabilidade rápida
  _last_eng="$(ls -1t "$AVP_LOGDIR"/avp_eng_*.log 2>/dev/null | head -n 1)"
  [ -n "${_last_eng:-}" ] && echo "LAST_ENG_LOG=$_last_eng" || echo "LAST_ENG_LOG=(none)"
  _cronlog="$AVP_LOGDIR/avp-pol-cron.log"
  if [ -f "$_cronlog" ]; then
    _last_rc="$(awk '/\[CRON\] AVP-POL-CRON .* END rc=/{for(i=1;i<=NF;i++) if($i ~ /^rc=/) rc=$i} END{print rc}' "$_cronlog" 2>/dev/null)"
    echo "CRON_LOG=$_cronlog ${_last_rc:-}"
  else
    echo "CRON_LOG=$_cronlog (missing)"
  fi
}

cmd_run() {
  LIVE_MODE=0
  SHOW_LAST=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --live) LIVE_MODE=1; shift;;
      --show-last) SHOW_LAST=1; shift;;
      -h|--help) show_help; return 0;;
      *) echo "ERR: unknown option: $1" >&2; show_help; return 2;;
    esac
  done

  [ "$SHOW_LAST" = "1" ] && { cmd_show_last; return $?; }

  init_global
  if [ "$LIVE_MODE" != "1" ]; then
    [ "${AUTOVPN_ENABLED:-1}" = "1" ] || { logger -t AVP-POL "skip: disabled"; return 0; }
  else
    [ "${AUTOVPN_ENABLED:-1}" = "1" ] || logger -t AVP-POL "live override: running while disabled"
  fi
  require_policy_files

  apply_profile_exports "${AUTOVPN_PROFILE:-$DEFAULT_PROFILE}" 2>/dev/null \
    || apply_profile_exports "$DEFAULT_PROFILE" 2>/dev/null \
    || :

  export AUTOVPN_PROFILE="${AUTOVPN_PROFILE:-$DEFAULT_PROFILE}"


  [ -f "$ENGINE" ] || { logger -t AVP-POL "ERR: engine_not_found ($ENGINE)"; return 1; }
  logger -t AVP-POL "run: profile=${AUTOVPN_PROFILE:-$DEFAULT_PROFILE}"

  if [ "$LIVE_MODE" = "1" ]; then
    echo "$(ts) [POL] run: profile=${AUTOVPN_PROFILE:-$DEFAULT_PROFILE} (live=1)"
    echo "$(ts) [POL] calling engine: $ENGINE"
    AVP_CALLER=POL AVP_LIVE=1 /bin/sh "$ENGINE"
    rc=$?
    echo "$(ts) [POL] done"
  else
    _before="$(ls -1t "$AVP_LOGDIR"/avp_eng_*.log 2>/dev/null | head -n 1)"
    AVP_CALLER=POL /bin/sh "$ENGINE" >/dev/null 2>&1
    rc=$?
    _after="$(ls -1t "$AVP_LOGDIR"/avp_eng_*.log 2>/dev/null | head -n 1)"
    [ -n "${_after:-}" ] && [ "${_after:-}" != "${_before:-}" ] || _after="${_before:-}"
    [ "$rc" -eq 0 ] || logger -t AVP-POL "ERR: engine_rc=$rc last_log=${_after:-none}"
    return $rc
  fi
}

case "${1:-}" in
  -h|--help|"") show_help; exit 0;;
  enable) shift; cmd_enable "$@";;
  disable) shift; cmd_disable "$@";;
  status)
    shift
    [ "${1:-}" = "--json" ] && cmd_status_json || cmd_status
    ;;
  run) shift; cmd_run "$@";;
  reload) shift; cmd_reload "$@";;
  snapshot) shift; cmd_snapshot "$@";;

  profile)
    sub="${2:-}"
    case "$sub" in
      list) cmd_profile_list;;
      get)  cmd_profile_get;;
      set)  cmd_profile_set "${3:-}";;
      *) json_err 2 "profile" "invalid subcommand" '{"hint":"profile list|get|set <name>"}'; exit 2;;
    esac
    ;;

  device)
    sub="${2:-}"
    case "$sub" in
      list) cmd_device_list;;
      add)  cmd_device_add "${3:-}" "${4:-}" "${5:-}" "${6:-}";;
      del)  cmd_device_del "${3:-}";;
      set)  cmd_device_set "${3:-}" "${4:-}" "${5:-}" "${6:-}";;
      *) json_err 2 "device" "invalid subcommand" '{"hint":"device list|add|del|set"}'; exit 2;;
    esac
    ;;

  *) echo "ERR: invalid command: ${1:-}" >&2; show_help >&2; exit 2;;
esac
