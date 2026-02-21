#!/bin/sh
# =============================================================
# AutoVPN Platform (AVP)
# Component : AVP-ENG
# File      : avp-eng.sh
# Role      : Multi-Device VPN Failover (Engine)
# Version   : v1.2.46 (2026-02-21)
# Status    : stable
# =============================================================

SCRIPT_VER="v1.2.46"
export PATH="/jffs/scripts:/jffs/scripts/avp/bin:/opt/bin:/opt/sbin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH:-}"
hash -r 2>/dev/null || true
set -u

# HARDEN: states dinamicos (avp_*.state) devem ser 0600 (labels mudam via devices.conf/GUI)
harden_state_dir() {
  # Merlin-puro: sem find; nao bloqueia o fluxo
  for f in "$STATEDIR"/avp_*.state; do
    [ -e "$f" ] || continue
    chmod 0600 "$f" 2>/dev/null || true
  done
}

# PATH robusto para cron/non-interactive (Merlin)

# ====== CONFIG ======
# Canonical AVP paths (directories only)
CANON_BASE="/jffs/scripts/avp"

AVP_LOGDIR="${AVP_LOGDIR:-/tmp/avp_logs}"
AVP_LIB="/jffs/scripts/avp/lib/avp-lib.sh"
[ -f "$AVP_LIB" ] && . "$AVP_LIB"
type has_fn >/dev/null 2>&1 || has_fn(){ type "$1" >/dev/null 2>&1; }
has_fn avp_init_layout && avp_init_layout >/dev/null 2>&1 || :

LOGDIR="$AVP_LOGDIR"
STATEDIR="$CANON_BASE/state"

# HARDEN: cura states dinamicos uma vez por exec (labels mudam via devices.conf/GUI)
harden_state_dir
CACHEDIR="$CANON_BASE/cache"

# Ensure canonical dirs
mkdir -p "$STATEDIR" "$CACHEDIR" 2>/dev/null || :
mkdir -p "$LOGDIR" 2>/dev/null || { LOGDIR="/tmp/avp_logs"; mkdir -p "$LOGDIR" 2>/dev/null || :; }

# Policy integration (devices inventory)
DEVICES_CONF="/jffs/scripts/avp/policy/devices.conf"
AVP_POL_BIN="/jffs/scripts/avp/bin/avp-pol.sh"
RULE_PREF_BASE=11210
PREFMAP_DB="/jffs/scripts/avp/state/prefmap.db"

# (RULE_PREF e STATE_FILE são selecionados por device em runtime)
RULE_PREF=""

WGS="wgc1 wgc2 wgc3 wgc4 wgc5"
DEFAULT_WG="wgc1"

: "${TARGETS:="8.8.8.8 1.1.1.1"}"
: "${PINGCOUNT:=3}"
: "${PINGW:=1}"
: "${DWARN_TTL:=1800}"  # seconds; 0=off  (re-warn "still_degraded" por TTL)

# ===== FAILOVER (Modo A) =====
: "${SWITCH_MARGIN_MS:=15}"
: "${COOLDOWN_SEC:=600}"
HANDSHAKE_MAX_AGE=180

DEGRADE_SCORE_WARN=120

# ===== QUARANTINE (WG degradada) =====
: "${QUAR_ENABLE:=1}"
: "${QUAR_DEGRADE_SCORE:=120}"   # score acima disso é considerado degradado
: "${QUAR_DEGRADE_RUNS:=3}"      # runs consecutivos para entrar em quarentena
: "${QUAR_AVOID_SEC:=1800}"      # tempo de avoid (segundos)

# ===== RETORNO AO DEFAULT =====
: "${RETURN_MARGIN_MS:=5}"
: "${RETURN_DELAY_SEC:=3600}"
: "${RETURN_STABLE_RUNS:=5}"

# ===== WAN FALLBACK =====
: "${WAN_FALLBACK_ENABLE:=1}"
: "${WAN_ADVANTAGE_MS:=20}"
: "${WAN_STABLE_RUNS:=3}"
: "${VPN_BACK_MARGIN_MS:=10}"
: "${VPN_BACK_STABLE_RUNS:=5}"

STATE_FILE=""

# Quarentena: buffer de eventos do run (precisa existir antes de qualquer referência por causa do "set -u")
QUAR_EVENTS=""

# ====== UTILS ======
ts() { date '+%Y-%m-%d %H:%M:%S'; }
epoch() { date +%s; }

prev_day() {
  # retorna YYYY-MM-DD (dia anterior) de forma robusta (Merlin/BusyBox-safe)
  _d=""
  for _e in "yesterday" "1 day ago" "-1 day"; do
    _d="$(date -d "$_e" +%F 2>/dev/null)"
    echo "$_d" | awk '/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ {ok=1} END{exit !ok}' >/dev/null 2>&1 && { echo "$_d"; return 0; }
  done
  if type python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import datetime
print((datetime.datetime.now()-datetime.timedelta(days=1)).strftime("%Y-%m-%d"))
PY
    return 0
  fi
  # ultimo fallback: hoje (mantem rodando, mas pode rotular errado)
  date +%F 2>/dev/null
  return 1
}

avp_day() {
  # dia logico do AVP (janela 06:00->05:59)
  _h="$(date +%H 2>/dev/null)"
  case "$_h" in
    ""|*[!0-9]* ) date +%F 2>/dev/null; return 0 ;;
  esac
  if [ "$_h" -lt 6 ] 2>/dev/null; then
    prev_day
  else
    date +%F 2>/dev/null
  fi
}

# ===== LOG RETENTION / CLOCK GUARD =====
LOG_RETENTION_DAYS=30
# consider clock "sane" only inside this window (avoids accidental cleanup if NTP/clock broke)
CLOCK_MIN_EPOCH=1704067200   # 2024-01-01 00:00:00 UTC
CLOCK_MAX_EPOCH=2082758400   # 2036-01-01 00:00:00 UTC

AVP_DAY="$(avp_day)"

LOG="$LOGDIR/avp_eng_${AVP_DAY}_$(date +%H%M%S).log"

# Bootstrap log early (captures aborts before main run logging)
: >"$LOG" 2>/dev/null || :
elog(){
  echo "$*"
  echo "$*" >>"$LOG" 2>/dev/null || :
}
elog "$(ts) [BOOT] AVP-ENG $SCRIPT_VER start (log=$LOG)"
if [ "${DWARN_TTL:-0}" -eq 0 ]; then
  echo "[INFO] DWARN_TTL=0 (disabled)"
fi

TMPLOG="/tmp/avp_eng.$$"

clock_sane() {
  NOWE="$(epoch)"
  [ "$NOWE" -ge "$CLOCK_MIN_EPOCH" ] && [ "$NOWE" -le "$CLOCK_MAX_EPOCH" ]
}

cleanup_old_logs() {
  case "$LOGDIR" in /tmp/*) return 0;; esac
  [ "${HAS_FIND:-1}" -eq 1 ] || { echo "[WARN] log_retention skipped (find_missing)"; return 0; }
  clock_sane || { echo "[WARN] log_retention skipped (clock_invalid epoch=$(epoch))"; return 0; }
  # tenta -delete; se não suportado, cai no -exec rm
  if find "$LOGDIR" -type f -name 'avp_eng_*.log' -mtime +"$LOG_RETENTION_DAYS" -delete >/dev/null 2>&1; then
    :
  else
    find "$LOGDIR" -type f -name 'avp_eng_*.log' -mtime +"$LOG_RETENTION_DAYS" -exec rm -f {} \; >/dev/null 2>&1
  fi
}

# ---------- SAFETY (anti-overlap + healthcheck) ----------
LOCKDIR="/tmp/avp_eng.lock"

acquire_lock() {
  # compat: lock antigo pode ser arquivo (remova para permitir mkdir)
  [ -f "$LOCKDIR" ] && rm -f "$LOCKDIR" 2>/dev/null || :

  # stale lock dir: se existir mas pid não roda, remove e segue
  if [ -d "$LOCKDIR" ] && [ -f "$LOCKDIR/pid" ]; then
    _lp="$(cat "$LOCKDIR/pid" 2>/dev/null)"
    if [ -n "$_lp" ] && kill -0 "$_lp" 2>/dev/null; then
      :
    else
      rm -rf "$LOCKDIR" 2>/dev/null || :
    fi
  fi

  if mkdir "$LOCKDIR" 2>/dev/null; then
    echo "$$" >"$LOCKDIR/pid" 2>/dev/null || :
    return 0
  fi
  elog "$(date "+%F %T") [ERR] code=99 lock_active (another instance running) | next: aguarde 1 ciclo; se preso, remova /tmp/avp_eng.lock"

  exit 99
}

require_cmds() {
  # Merlin/BusyBox-friendly: use 'type' (handles applets/builtins) instead of 'command -v'
  cmd_exists() { type "$1" >/dev/null 2>&1; }

  # ---- critical (must exist) ----
  CRIT_MISS=""
  for C in ip wg ping awk sed date mv mkdir cat grep tail cut; do
    cmd_exists "$C" || CRIT_MISS="${CRIT_MISS}${C} "
  done
  if [ -n "$CRIT_MISS" ]; then
  elog "[ERR] code=10 missing_cmds(critical): $CRIT_MISS"
    elog "[NEXT] verifique PATH/BusyBox/Entware; rode: type ip wg ping awk sed date mv mkdir cat"
    exit 10
  fi

  # ---- optional (degrade gracefully) ----
  HAS_FIND=0; HAS_GREP=0; HAS_CUT=0; HAS_TAIL=0; HAS_MV=0; HAS_UNAME=0; HAS_NVRAM=0
  cmd_exists find  && HAS_FIND=1
  cmd_exists grep  && HAS_GREP=1
  cmd_exists cut   && HAS_CUT=1
  cmd_exists tail  && HAS_TAIL=1
  cmd_exists mv    && HAS_MV=1
  cmd_exists uname && HAS_UNAME=1
  cmd_exists nvram && HAS_NVRAM=1

  # LOGDIR gravável (evita execução “no escuro”)
  if ! mkdir -p "$LOGDIR" 2>/dev/null; then
    elog "[ERR] code=11 cannot_create_logdir: $LOGDIR"
    elog "[NEXT] crie o diretório; verifique JFFS/permissões/espaço"
    exit 11
  fi

  # sanity: /tmp gravável (lock/atomic state)
  if ! : >"/tmp/.avp_eng_write_test.$$" 2>/dev/null; then
    echo "[WARN] cannot_write_tmp (lock/atomic state may be impacted)"
  else
    rm -f "/tmp/.avp_eng_write_test.$$" 2>/dev/null || :
  fi

  if ! : >"$LOGDIR/.write_test.$$" 2>/dev/null; then
    echo "[ERR] code=11 logdir_not_writable: $LOGDIR"
    elog "[NEXT] garanta escrita; verifique JFFS/permissões/espaço"
    exit 11
  fi
  rm -f "$LOGDIR/.write_test.$$" 2>/dev/null || :

  # STATEDIR gravável (evita counters/reset silencioso)
  if ! mkdir -p "$STATEDIR" 2>/dev/null; then
    elog "[ERR] code=12 cannot_create_statedir: $STATEDIR"
    elog "[NEXT] verifique permissões/espaço; JFFS montado OK"
    exit 12
  fi
  if ! : >"$STATEDIR/.write_test.$$" 2>/dev/null; then
    echo "[ERR] code=12 statedir_not_writable: $STATEDIR"
    elog "[NEXT] verifique permissões/espaço; diretório deve ser gravável (JFFS OK)"
    exit 12
  fi
  rm -f "$STATEDIR/.write_test.$$" 2>/dev/null || :
}

# ---------- STATE ----------
STATE_MEM_FILE=""

state_store_file() {
  if [ -n "${STATE_MEM_FILE:-}" ]; then
    printf "%s" "$STATE_MEM_FILE"
  else
    printf "%s" "$STATE_FILE"
  fi
}

state_begin_device() {
  [ -n "${STATE_FILE:-}" ] || return 0
  STATE_MEM_FILE="/tmp/avp_state.$$.${RULE_PREF}.tmp"
  if [ -f "$STATE_FILE" ]; then
    cp -f "$STATE_FILE" "$STATE_MEM_FILE" 2>/dev/null || : >"$STATE_MEM_FILE"
  else
    : >"$STATE_MEM_FILE" 2>/dev/null || :
  fi
  chmod 0600 "$STATE_MEM_FILE" 2>/dev/null || :
}

state_flush_device() {
  [ -n "${STATE_MEM_FILE:-}" ] || return 0
  state_write_file "$STATE_FILE" <"$STATE_MEM_FILE" 2>/dev/null || :
  rm -f "$STATE_MEM_FILE" 2>/dev/null || :
  STATE_MEM_FILE=""
}

get_state() {
  # semantica: ultima ocorrencia vence ("last wins")
  _sf="$(state_store_file)"
  awk -F= -v k="$1" '$1==k{v=substr($0,index($0,"=")+1)} END{print v}' "$_sf" 2>/dev/null
}
set_state() {
  KEY="$1"; VAL="$2"
  _sf="$(state_store_file)"
  _tmp="${_sf}.w.$$"
  {
    if [ -f "$_sf" ]; then
      awk -F= -v k="$KEY" '$1!=k{print}' "$_sf" 2>/dev/null || true
    fi
    printf "%s=%s\n" "$KEY" "$VAL"
  } >"$_tmp" 2>/dev/null || :
  mv -f "$_tmp" "$_sf" 2>/dev/null || rm -f "$_tmp" 2>/dev/null || :
}

cooldown_ok() {
  LAST="$(get_state last_switch_epoch)"
  [ -z "${LAST:-}" ] && return 0
  [ $(( $(epoch) - LAST )) -ge "$COOLDOWN_SEC" ]
}

mark_switch() {
  set_state last_switch_epoch "$(epoch)"
  set_state return_stable 0
  set_state wan_bad_vpn_runs 0
  set_state wan_good_vpn_runs 0
  set_state vpn_good_runs 0
}

# ---------- CACHE (vars por execução) ----------
set_cache() {
  PREFIX="$1"; KEY="$2"; VAL="$3"
  ESC="$(printf "%s" "$VAL" | sed "s/'/'\\\\''/g")"
  eval "${PREFIX}_${KEY}='$ESC'"
}
get_cache() {
  PREFIX="$1"; KEY="$2"
  eval "printf '%s' \"\${${PREFIX}_${KEY}:-}\""
}

# ---------- METRICS ----------
handshake_age() {
  IFACE="$1"
  # pega o handshake mais recente (múltiplos peers -> usa maior epoch válido)
  MAXE="$(wg show "$IFACE" latest-handshakes 2>/dev/null | awk '{if($2 ~ /^[0-9]+$/ && $2>max) max=$2} END{print max+0}')"
  [ -z "$MAXE" ] && echo "none" && return
  [ "$MAXE" -le 0 ] && echo "none" && return
  echo $(( $(epoch) - MAXE ))
}

ping_parse_stats() {
  awk '
    /packet loss/ {
      if (match($0, /([0-9]+)% packet loss/, m)) loss=m[1]
    }
    /round-trip|rtt/ {
      split($0, a, "=")
      if (length(a) > 1) {
        gsub(/ /, "", a[2]); gsub(/ms/, "", a[2])
        split(a[2], r, "/")
        if (r[1] != "" && r[2] != "" && r[3] != "") {
          min=r[1]; avg=r[2]; max=r[3]
        }
      }
    }
    END {
      if (loss == "") exit 1
      if (avg == "") { print loss; exit 2 }
      print loss, min, avg, max
    }
  '
}

ping_stats_iface() {
  IFACE="$1"; DST="$2"
  OUT="$(ping -I "$IFACE" -c "$PINGCOUNT" -W "$PINGW" "$DST" 2>/dev/null)" || return 1
  PARSED="$(printf "%s\n" "$OUT" | ping_parse_stats)" || return $?
  echo "$PARSED"
}

ping_stats_default() {
  DST="$1"
  OUT="$(ping -c "$PINGCOUNT" -W "$PINGW" "$DST" 2>/dev/null)" || return 1
  PARSED="$(printf "%s\n" "$OUT" | ping_parse_stats)" || return $?
  echo "$PARSED"
}

make_key() { echo "$1" | sed 's/[^A-Za-z0-9_]/_/g'; }
# ---------- JSON / USB ROTATE (Camada A: sh puro) ----------
json_escape() {
  # escape minimo (\, ", newline, tab)
  printf "%s" "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r//g; s/\n/\\n/g'
}

write_cycle_json() {
  TS="$(date +%s)"
  D="$(avp_day)"
  LAST="/tmp/avp_eng_last.json"
  JLOG="/tmp/avp_eng_cycles_${D}.jsonl"

  _dev="$(json_escape "${DEVICE_LABEL:-}")"
  _mode="$(json_escape "${DEV_MODE:-}")"
  _cur="$(json_escape "${CUR:-}")"
  _best="$(json_escape "${BEST_IF:-}")"
  _bs="$(json_escape "${BEST_SCORE:-}")"
  _wan="$(json_escape "${WAN_SCORE:-}")"
  _act="$(json_escape "${LAST_ACTION:-none}")"

  # JSON em partes (anti-wrap)
  JSON="$(printf '{')"
  JSON="${JSON}$(printf '"ts":%s,' "$TS")"
  JSON="${JSON}$(printf '"script":"AVP-ENG",')"
  JSON="${JSON}$(printf '"ver":"%s",' "${SCRIPT_VER}")"
  JSON="${JSON}$(printf '"dev":"%s",' "$_dev")"
  JSON="${JSON}$(printf '"mode":"%s",' "$_mode")"
  JSON="${JSON}$(printf '"cur":"%s",' "$_cur")"
  JSON="${JSON}$(printf '"best":"%s",' "$_best")"
  JSON="${JSON}$(printf '"best_score":"%s",' "$_bs")"
  JSON="${JSON}$(printf '"wan":"%s",' "$_wan")"
  JSON="${JSON}$(printf '"action":"%s"}' "$_act")"

  printf "%s\n" "$JSON" >"${LAST}.tmp" && mv -f "${LAST}.tmp" "$LAST"
  printf "%s\n" "$JSON" >>"$JLOG"
}

usb_rotate_daily() {
  USB_DIR="/mnt/AVPUSB/avp_logs"
  mkdir -p "$USB_DIR" 2>/dev/null || return 0

  Y="$(avp_day)"
  [ -z "${Y:-}" ] && Y="$(date +%F)"
  YMD="$(echo "$Y" | tr -d "-")"

  SRC_JSONL="/tmp/avp_eng_cycles_${Y}.jsonl"
  DST_SUM="$USB_DIR/avp_summary_${Y}.log"
  [ -s "$SRC_JSONL" ] && { cat "$SRC_JSONL" >>"$DST_SUM"; rm -f "$SRC_JSONL"; }

  # ENG logs do dia anterior -> tar.gz (se existirem em LOGDIR)
  GZ="$USB_DIR/avp_eng_${Y}_logs.tar.gz"
  if [ -n "${LOGDIR:-}" ] && [ -d "$LOGDIR" ]; then
    (
      cd "$LOGDIR" 2>/dev/null || exit 0
      FILES=""
      SEEN=" "
      for f in avp_eng*"${Y}"* avp_eng*"${YMD}"*; do
        [ -e "$f" ] || continue
        case "$SEEN" in
          *" $f "*) continue ;;
        esac
        SEEN="$SEEN$f "
        FILES="$FILES $f"
      done
      [ -n "$FILES" ] && tar -czf "$GZ" $FILES
      [ -n "$FILES" ] && rm -f $FILES 2>/dev/null || true
    ) >/dev/null 2>&1
  fi

  # retenção 30d (summary + gz)
  find "$USB_DIR" -type f \( -name "avp_summary_*.log" -o -name "avp_eng_*_logs.tar.gz" -o -name "avp_eng_*_logs.gz" \) -mtime +30 -delete 2>/dev/null || true
}

rotate_mode_handler() {
  case "${1:-}" in
    --rotate-usb) require_cmds; usb_rotate_daily; exit 0;;
  esac
}

ping_stats_iface_cached() {
  IFACE="$1"; DST="$2"
  K="$(make_key "${IFACE}_${DST}")"
  C="$(get_cache PING "$K")"
  [ -n "$C" ] && { echo "$C"; return 0; }
  S="$(ping_stats_iface "$IFACE" "$DST")" || return $?
  set_cache PING "$K" "$S"
  echo "$S"
}

ping_stats_default_cached() {
  DST="$1"
  K="$(make_key "DEF_${DST}")"
  C="$(get_cache PING "$K")"
  [ -n "$C" ] && { echo "$C"; return 0; }
  S="$(ping_stats_default "$DST")" || return $?
  set_cache PING "$K" "$S"
  echo "$S"
}

score_iface() {
  IFACE="$1"
  ip link show "$IFACE" >/dev/null 2>&1 || { echo "INF iface_missing"; return; }

  HSA="$(handshake_age "$IFACE")"
  [ "$HSA" = "none" ] && { echo "INF handshake_none"; return; }

  T_SEL=""; S_SEL=""
  for T in $TARGETS; do
    S="$(ping_stats_iface_cached "$IFACE" "$T")" || continue
    LOSS="$(echo "$S" | awk '{print $1}')"
    [ "$LOSS" = "0" ] && { T_SEL="$T"; S_SEL="$S"; break; }
  done

  [ -z "$T_SEL" ] && { echo "INF packet_loss all_targets"; return; }
  MIN="$(echo "$S_SEL" | awk '{print $2}')"
  AVG="$(echo "$S_SEL" | awk '{print $3}')"
  MAX="$(echo "$S_SEL" | awk '{print $4}')"
  JIT="$(awk -v b="$MAX" -v c="$MIN" 'BEGIN{printf "%.2f",(b-c)}')"
  AVGMEAN="$(awk -v a="$AVG" 'BEGIN{printf "%.2f", a}')"
  PEN=0; [ "$HSA" -gt "$HANDSHAKE_MAX_AGE" ] && PEN=50

  SCORE="$(awk -v a="$AVGMEAN" -v j="$JIT" -v p="$PEN" 'BEGIN{printf "%.2f", a+(j*2)+p}')"
  echo "$SCORE ok hsa=$HSA jitter=$JIT avg=$AVGMEAN pen=$PEN target=$T_SEL"
}
detect_wan_if() {
  ip link show ppp0 >/dev/null 2>&1 && { echo "ppp0"; return; }
  WAN="$(nvram get wan0_ifname 2>/dev/null)"
  [ -n "$WAN" ] && ip link show "$WAN" >/dev/null 2>&1 && { echo "$WAN"; return; }
  echo ""
}

score_wan_with_if() {
  WAN_IF="$1"
  T_SEL=""; S_SEL=""

  for T in $TARGETS; do
    if [ -n "$WAN_IF" ]; then
      S="$(ping_stats_iface_cached "$WAN_IF" "$T")" || continue
    else
      S="$(ping_stats_default_cached "$T")" || continue
    fi
    LOSS="$(echo "$S" | awk '{print $1}')"
    [ "$LOSS" = "0" ] && { T_SEL="$T"; S_SEL="$S"; break; }
  done

  [ -z "$T_SEL" ] && { echo "INF packet_loss all_targets"; return; }
  MIN="$(echo "$S_SEL" | awk '{print $2}')"
  AVG="$(echo "$S_SEL" | awk '{print $3}')"
  MAX="$(echo "$S_SEL" | awk '{print $4}')"
  JIT="$(awk -v b="$MAX" -v c="$MIN" 'BEGIN{printf "%.2f",(b-c)}')"
  AVGMEAN="$(awk -v a="$AVG" 'BEGIN{printf "%.2f", a}')"
  SCORE="$(awk -v a="$AVGMEAN" -v j="$JIT" 'BEGIN{printf "%.2f", a+(j*2)}')"
  if [ -n "$WAN_IF" ]; then
    echo "$SCORE ok wan_if=$WAN_IF jitter=$JIT avg=$AVGMEAN target=$T_SEL"
  else
    echo "$SCORE ok wan_if=default jitter=$JIT avg=$AVGMEAN target=$T_SEL"
  fi
}

warm_metrics_cycle() {
  # Pré-aquece métricas globais do ciclo (reaproveitadas por todos os devices)
  WAN_IF_CYCLE="$(detect_wan_if)"
  set_cache WAN IFACE "$WAN_IF_CYCLE"

  WAN_RES_CYCLE="$(score_wan_with_if "$WAN_IF_CYCLE")"
  set_cache WAN RES "$WAN_RES_CYCLE"
  set_cache WAN SCORE "$(echo "$WAN_RES_CYCLE" | awk '{print $1}')"
  set_cache WAN META  "$(echo "$WAN_RES_CYCLE" | cut -d' ' -f2-)"

  for WG in $WGS; do
    RES="$(score_iface "$WG")"
    set_cache VPN_SCORE "$WG" "$(echo "$RES" | awk '{print $1}')"
    set_cache VPN_META  "$WG" "$(echo "$RES" | cut -d' ' -f2-)"
  done
}

# ---------- ROUTING ----------
current_device_table() {
  ip rule show | awk -v ip="$DEVICE_IP" -v pref="$RULE_PREF" \
    '$1~pref":" && $0~("from "ip){for(i=1;i<=NF;i++)if($i=="lookup"){print $(i+1); exit}}'
}

apply_device_table() {
  TBL="$1"
  ip rule del pref "$RULE_PREF" 2>/dev/null
  if ! ip rule add pref "$RULE_PREF" from "$DEVICE_IP" lookup "$TBL" 2>/dev/null; then
    echo "[ERR] code=30 apply_device_table failed (table=$TBL)"
    echo "[NEXT] verifique ip rule/ip route; tabela=$TBL; pref=$RULE_PREF; rode: ip rule | grep \"pref $RULE_PREF\"; ip route show table $TBL"
    set_rc 30
    return 30
  fi
  echo "[OK] applied ip rule: lookup $TBL (pref $RULE_PREF from $DEVICE_IP)"
  ip route flush cache 2>/dev/null
  set_state dev_mode vpn
  return 0
}

apply_wan_fallback() {
  if ! ip rule del pref "$RULE_PREF" 2>/dev/null; then
    # se já não existe, ok; se deu erro real, continua mesmo assim
    :
  fi
  echo "[OK] applied ip rule: lookup main (deleted pref $RULE_PREF; default routing)"
  ip route flush cache 2>/dev/null
  set_state dev_mode wan
  return 0
}

print_counters() {
  NB="$(get_state wan_bad_vpn_runs)"; [ -z "${NB:-}" ] && NB=0
  NG="$(get_state wan_good_vpn_runs)"; [ -z "${NG:-}" ] && NG=0
  RS="$(get_state return_stable)"; [ -z "${RS:-}" ] && RS=0
    VG="$(get_state vpn_good_runs)"; [ -z "${VG:-}" ] && VG=0
  echo "[COUNTERS] wan_bad_vpn_runs=$NB/$WAN_STABLE_RUNS wan_good_vpn_runs=$NG/$VPN_BACK_STABLE_RUNS vpn_good_runs=$VG/$VPN_BACK_STABLE_RUNS return_stable=$RS/$RETURN_STABLE_RUNS"
}

# ---------- DEVICE LOADER (Policy -> Engine) ----------
sanitize_label() {
  # BusyBox/POSIX-safe:
  # - lowercase via sed transliteration (y///) para evitar tr [:upper:]/[:lower:]
  # - troca qualquer char fora de [a-z0-9_] por underscore
  # - normaliza underscores (sem bordas, sem repetição)
  IN="$1"
  OUT="$(printf "%s" "$IN" | LC_ALL=C sed 'y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/')"
  OUT="$(printf "%s" "$OUT" | LC_ALL=C sed 's/[^a-z0-9_]/_/g; s/__*/_/g; s/^_//; s/_$//')"
  [ -z "${OUT:-}" ] && OUT="device"
  echo "$OUT"
}

prefmap_ensure() {
  mkdir -p "/jffs/scripts/avp/state" 2>/dev/null || return 1
  [ -f "$PREFMAP_DB" ] || : >"$PREFMAP_DB" 2>/dev/null || return 1
  return 0
}

prefmap_get() {
  _mac="$(printf "%s" "${1:-}" | tr '[:lower:]' '[:upper:]')"
  [ -n "${_mac:-}" ] || return 1
  [ -f "$PREFMAP_DB" ] || return 1
  awk -F'|' -v mac="$_mac" '
    $1==mac && $2 ~ /^[0-9]+$/ { print $2; exit }
  ' "$PREFMAP_DB" 2>/dev/null
}

prefmap_set() {
  _mac="$(printf "%s" "${1:-}" | tr '[:lower:]' '[:upper:]')"
  _pref="${2:-}"
  [ -n "${_mac:-}" ] || return 1
  echo "$_pref" | awk '($0 ~ /^[0-9]+$/){ok=1} END{exit ok?0:1}' >/dev/null 2>&1 || return 1

  prefmap_ensure || return 1
  _tmp="/tmp/avp_prefmap.$$"
  awk -F'|' -v mac="$_mac" '
    $1 != mac { print $0 }
  ' "$PREFMAP_DB" 2>/dev/null >"$_tmp" || : >"$_tmp"
  printf "%s|%s\n" "$_mac" "$_pref" >>"$_tmp" || { rm -f "$_tmp" 2>/dev/null || :; return 1; }
  mv "$_tmp" "$PREFMAP_DB" 2>/dev/null || { rm -f "$_tmp" 2>/dev/null || :; return 1; }
  return 0
}

prefmap_next_free() {
  prefmap_ensure || return 1
  ip rule show 2>/dev/null | awk -v base="$RULE_PREF_BASE" -v db="$PREFMAP_DB" '
    BEGIN{
      while ((getline line < db) > 0) {
        n=split(line, a, "|")
        if (n >= 2 && a[2] ~ /^[0-9]+$/ && a[2] >= base) used[a[2]] = 1
      }
      close(db)
    }
    {
      p=$1
      sub(/:$/, "", p)
      if (p ~ /^[0-9]+$/ && p >= base) used[p] = 1
    }
    END{
      for (p=base; p<65535; p++) {
        if (!(p in used)) { print p; exit 0 }
      }
      exit 1
    }
  '
}

current_pref_for_ip_any() {
  _ip="$1"
  [ -n "${_ip:-}" ] || return 1
  ip rule show 2>/dev/null | awk -v ip="$_ip" '
    $0 ~ ("from " ip) {
      p=$1
      sub(/:$/, "", p)
      if (p ~ /^[0-9]+$/) { print p; exit }
    }
  '
}

cleanup_rules_for_ip_anypref() {
  _ip="$1"
  [ -n "${_ip:-}" ] || return 0
  _prefs="$(ip rule show 2>/dev/null | awk -v ip="$_ip" '
    $0 ~ ("from " ip) {
      p=$1
      sub(/:$/, "", p)
      if (p ~ /^[0-9]+$/) print p
    }
  ' | awk '!seen[$0]++')"
  [ -z "${_prefs:-}" ] && return 0
  echo "$_prefs" | while read -r _p; do
    [ -n "${_p:-}" ] || continue
    ip rule del pref "$_p" 2>/dev/null || true
  done
}

load_devices_from_ssot() {
  # Popula DEVICES_LIST com linhas:
  # LABEL|IP|PREF|STATEFILE|ENABLED|IFACE_BASE|MAC
  DEVICES_LIST=""

  [ -x "$AVP_POL_BIN" ] || return 1

  _ssot="$("$AVP_POL_BIN" device ssot 2>/dev/null || true)"
  [ -n "${_ssot:-}" ] || return 1

  prefmap_ensure || return 1

  _idx=0
  _ssot_tmp="/tmp/avp_eng_ssot.$$"
  printf "%s\n" "$_ssot" >"$_ssot_tmp" 2>/dev/null || return 1

  while IFS='|' read -r EN LABEL IP IFACE_BASE MAC || [ -n "${LABEL:-}" ]; do
    EN="$(printf "%s" "${EN:-}" | tr -d "\r")"
    LABEL="$(printf "%s" "${LABEL:-}" | tr -d "\r")"
    IP="$(printf "%s" "${IP:-}" | tr -d "\r")"
    IFACE_BASE="$(printf "%s" "${IFACE_BASE:-}" | tr -d "\r")"
    MAC="$(printf "%s" "${MAC:-}" | tr -d "\r")"

    [ -z "${LABEL:-}" ] && continue
    case "$LABEL" in \#*) continue ;; esac

    echo "$EN" | awk '($0=="0" || $0=="1"){ok=1} END{exit ok?0:1}' >/dev/null 2>&1 || continue
    echo "$IP" | awk -F. 'NF!=4{exit 1} {for(i=1;i<=4;i++) if($i<0||$i>255) exit 1} END{exit 0}' >/dev/null 2>&1 || continue

    _idx=$((_idx+1))

    PREF=""
    if [ -n "${MAC:-}" ]; then
      PREF="$(prefmap_get "$MAC" 2>/dev/null || true)"
    fi

    if ! echo "${PREF:-}" | awk '($0 ~ /^[0-9]+$/){exit 0} {exit 1}' >/dev/null 2>&1; then
      PREF="$(current_pref_for_ip_any "$IP" 2>/dev/null || true)"
    fi

    if ! echo "${PREF:-}" | awk '($0 ~ /^[0-9]+$/){exit 0} {exit 1}' >/dev/null 2>&1; then
      PREF="$(prefmap_next_free 2>/dev/null || true)"
    fi

    if ! echo "${PREF:-}" | awk '($0 ~ /^[0-9]+$/){exit 0} {exit 1}' >/dev/null 2>&1; then
      PREF=$((RULE_PREF_BASE + _idx))
    fi

    if [ -n "${MAC:-}" ]; then
      prefmap_set "$MAC" "$PREF" 2>/dev/null || true
    fi

    SL="$(sanitize_label "$LABEL")"
    SF="$STATEDIR/avp_${SL}.state"

    # guarda \n literal (pra printf "%b" interpretar depois)
    DEVICES_LIST="${DEVICES_LIST}${LABEL}|${IP}|${PREF}|${SF}|${EN}|${IFACE_BASE}|${MAC}\n"
  done <"$_ssot_tmp"

  rm -f "$_ssot_tmp" 2>/dev/null || :

  [ -n "$DEVICES_LIST" ] || return 1
  return 0
}

print_devices_header() {
  echo "[DEVICES] source=$1"
  printf "%b" "$DEVICES_LIST" | while IFS='|' read -r L I P S EN IFACE MAC; do
    [ -z "${L:-}" ] && continue
    _flag="enabled"
    [ "${EN:-1}" = "0" ] && _flag="disabled"
    _if="${IFACE:-?}"
    _mac="${MAC:-}"
    [ -n "$_mac" ] && _mac=" mac=$_mac"
    echo "  - $L: $I (pref $P) state=$S ssot=${_flag}:${_if}${_mac}"
  done
}

run_device() {
  # Contexto esperado (setado no loop): DEVICE_LABEL, DEVICE_IP, RULE_PREF, STATE_FILE
  echo "-------------------------------"
  echo "[DEVICE] $DEVICE_LABEL  ip=$DEVICE_IP  pref=$RULE_PREF  state=$STATE_FILE"
  state_begin_device
  CUR_RAW="$(current_device_table)"
  CUR="$CUR_RAW"; [ -z "$CUR_RAW" ] && CUR="(none)"

  # ===== RECONCILE: modo real via ip rule =====
  MODE_REAL="wan"
  [ -n "$CUR_RAW" ] && MODE_REAL="vpn"

  # audit: persiste a realidade observada
  set_state last_real_mode "$MODE_REAL"
  set_state last_real_table "${CUR_RAW:-wan}"

  DEV_MODE_STATE="$(get_state dev_mode)"
  if [ -z "${DEV_MODE_STATE:-}" ]; then
    # init: state novo/legado sem dev_mode => persistir p/ GUI/CLI (evita "unknown")
    set_state dev_mode "$MODE_REAL"
    DEV_MODE_STATE="$MODE_REAL"
  fi

  if [ "$DEV_MODE_STATE" != "$MODE_REAL" ]; then
    echo "[STATE] reconcile: state_mode=$DEV_MODE_STATE -> real_mode=$MODE_REAL (current_table=$CUR)"
    set_state dev_mode "$MODE_REAL"
  fi

  DEV_MODE="$MODE_REAL"
  echo "[STATE] $DEVICE_LABEL mode=$DEV_MODE current_table=$CUR"

  # ===== STATUS (na cara) =====
  if [ "$DEV_MODE" = "vpn" ] && [ "$CUR" != "(none)" ]; then
    echo "[STATUS] $DEVICE_LABEL via $CUR (VPN)"
  else
    echo "[STATUS] $DEVICE_LABEL via WAN"
  fi

  # ===== VPN snapshot =====
  echo "[VPN] snapshot"
  [ -n "${QUAR_EVENTS:-}" ] && printf "%b" "${QUAR_EVENTS:-}"
  BEST_IF=""
  BEST_SCORE=""
  INF_LINES=""

  SNAP_LIST=""

    NOW_EPOCH="$(epoch)"
  QUAR_EVENTS=""
  KEEP_IF=""

  for WG in $WGS; do
    SCORE="$(get_cache VPN_SCORE "$WG")"
    META="$(get_cache VPN_META "$WG")"
    if [ -z "${SCORE:-}" ] || [ -z "${META:-}" ]; then
      RES="$(score_iface "$WG")"
      SCORE="$(echo "$RES" | awk '{print $1}')"
      META="$(echo "$RES" | cut -d' ' -f2-)"
      set_cache "VPN_SCORE" "$WG" "$SCORE"
      set_cache "VPN_META"  "$WG" "$META"
    fi

    AVOID_UNTIL="$(get_state q_avoid_until_${WG})"; [ -z "${AVOID_UNTIL:-}" ] && AVOID_UNTIL=0
    BADRUNS="$(get_state q_bad_degrade_${WG})";    [ -z "${BADRUNS:-}" ] && BADRUNS=0

    QUAR_FLAG=0
    QUAR_LEFT=0

    if [ "$AVOID_UNTIL" -gt 0 ] 2>/dev/null; then
      if [ "$NOW_EPOCH" -lt "$AVOID_UNTIL" ] 2>/dev/null; then
        QUAR_FLAG=1
        QUAR_LEFT=$((AVOID_UNTIL - NOW_EPOCH))
      else
        set_state q_avoid_until_${WG} 0
        set_state q_bad_degrade_${WG} 0
        AVOID_UNTIL=0
        BADRUNS=0
      fi
    fi

    if [ "$SCORE" = "INF" ]; then
      INF_LINES="${INF_LINES}
    $WG score=INF  $META"
      continue
    fi

    if [ "$QUAR_ENABLE" -eq 1 ] && awk -v s="$SCORE" -v thr="$QUAR_DEGRADE_SCORE" 'BEGIN{exit !(s>thr)}'; then
      BADRUNS=$((BADRUNS+1))
      set_state q_bad_degrade_${WG} "$BADRUNS"
      if [ "$BADRUNS" -ge "$QUAR_DEGRADE_RUNS" ] && [ "$QUAR_FLAG" -eq 0 ]; then
        AVOID_UNTIL=$((NOW_EPOCH + QUAR_AVOID_SEC))
        set_state q_avoid_until_${WG} "$AVOID_UNTIL"
        set_state q_bad_degrade_${WG} 0
        QUAR_FLAG=1
        QUAR_LEFT=$QUAR_AVOID_SEC
        QUAR_EVENTS="${QUAR_EVENTS}[QUAR] ${WG} bad_degrade_runs=${QUAR_DEGRADE_RUNS}/${QUAR_DEGRADE_RUNS} -> avoid=${QUAR_AVOID_SEC}s (until=${AVOID_UNTIL}) (reason=score>${QUAR_DEGRADE_SCORE})
  "
      fi
    else
      if [ "$BADRUNS" -ne 0 ]; then
        set_state q_bad_degrade_${WG} 0
      fi
    fi

    SNAP_LIST="${SNAP_LIST}${SCORE}|${WG}|${META}|${QUAR_FLAG}|${QUAR_LEFT}
    "

    if [ "$QUAR_FLAG" -eq 0 ]; then
      if [ -z "$BEST_SCORE" ] || awk -v a="$SCORE" -v b="$BEST_SCORE" 'BEGIN{exit !(a<b)}'; then
        BEST_SCORE="$SCORE"
        BEST_IF="$WG"
      fi
    fi
  done

  if [ -z "$BEST_IF" ] && [ -n "$SNAP_LIST" ]; then
    KEEP_LINE="$(printf "%b" "$SNAP_LIST" | sort -n -t'|' -k1,1 | head -n 1)"
    KEEP_SCORE="$(echo "$KEEP_LINE" | awk -F'|' '{print $1}')"
    KEEP_IF="$(echo "$KEEP_LINE" | awk -F'|' '{print $2}')"
    BEST_IF="$KEEP_IF"
    BEST_SCORE="$KEEP_SCORE"
    echo "[QUAR] all_wgs_quarantined -> keeping_one_eligible=$KEEP_IF (least_bad) to preserve WAN competition"
  fi

  if [ -n "$BEST_IF" ]; then
    echo "  *BEST* $BEST_IF score=$BEST_SCORE  iface=$BEST_IF $(get_cache VPN_META "$BEST_IF")"
  else
    echo "  *BEST* (none) (all INF)"
  fi

  # CUR será impresso depois que for calculado, mas já podemos destacá-lo aqui se for VPN
  if [ -n "$CUR_RAW" ] && [ "$CUR_RAW" != "$BEST_IF" ]; then
    CS="$(get_cache VPN_SCORE "$CUR_RAW")"
    [ -z "${CS:-}" ] && CS="INF"
    if [ "$CS" != "INF" ]; then
      echo "  *CUR*  $CUR_RAW score=$CS  iface=$CUR_RAW $(get_cache VPN_META "$CUR_RAW")"
    else
      echo "  *CUR*  $CUR_RAW score=INF  $(get_cache VPN_META "$CUR_RAW")"
    fi
  fi

  # demais por score (exclui BEST e CUR)
  if [ -n "$SNAP_LIST" ]; then
    echo "$SNAP_LIST" | sort -n -t'|' -k1,1 | while IFS='|' read -r S IF M QF QL; do
      [ -z "${IF:-}" ] && continue
      [ "$IF" = "$BEST_IF" ] && continue
      [ -n "$CUR_RAW" ] && [ "$IF" = "$CUR_RAW" ] && continue
      if [ "${QF:-0}" -eq 1 ] && [ "$IF" != "$KEEP_IF" ]; then

    # reset degraded WARN state while quarantined
    set_state d_warn_${IF} 0
    set_state d_warn_ts_${IF} 0
        echo "       $IF score=$S  iface=$IF $M (SKIP quarantined ${QL}s_left)"
      else
        echo "       $IF score=$S  iface=$IF $M"
      fi
    done
  fi

  # INF no final
  [ -n "$INF_LINES" ] && printf "%b
  " "$INF_LINES"

  if [ -n "$BEST_IF" ]; then
    echo "[VPN] best=$BEST_IF score=$BEST_SCORE  iface=$BEST_IF $(get_cache VPN_META "$BEST_IF")"
    echo "[NOTE] best_by_score=$BEST_IF  score=avg+(jitter*2)  (lower_is_better)"
  else
    echo "[VPN] best=(none) (all INF)"
  fi

  # aviso de túneis degradados (apenas visibilidade)
  if [ -n "$SNAP_LIST" ]; then
    echo "$SNAP_LIST" | sort -n -t'|' -k1,1 | while IFS='|' read -r S IF M QF QL; do
      [ -z "${IF:-}" ] && continue
      # WARN somente por transicao (entra/sai degraded)
      PREV_D="$(get_state d_warn_${IF})"; [ -z "${PREV_D:-}" ] && PREV_D=0
      PREV_TS="$(get_state d_warn_ts_${IF})"; [ -z "${PREV_TS:-}" ] && PREV_TS=0
      NOW_TS="$(date +%s)"

      NOW_D=0
      awk -v s="$S" -v thr="$DEGRADE_SCORE_WARN" 'BEGIN{exit !(s>thr)}' && NOW_D=1
      if [ "$NOW_D" -eq 1 ] && [ "$PREV_D" -eq 0 ]; then
        echo "[WARN] degraded_iface=$IF score=$S (>${DEGRADE_SCORE_WARN})"
        set_state d_warn_${IF} 1
        set_state d_warn_ts_${IF} "$NOW_TS"

      elif [ "$NOW_D" -eq 1 ] && [ "$PREV_D" -eq 1 ]; then
        # TTL overlay: se continuar degradado, re-warn ocasionalmente (0=off)
        if [ "${DWARN_TTL:-0}" -gt 0 ]; then
          ELAPSED=$((NOW_TS - PREV_TS))
          AGE_PRINT="$ELAPSED"
          [ "$PREV_TS" -eq 0 ] && AGE_PRINT="NA" && AGE_SUFFIX=""
          [ "$PREV_TS" -ne 0 ] && AGE_SUFFIX="s"
          if [ "$PREV_TS" -eq 0 ] || [ "$ELAPSED" -ge "$DWARN_TTL" ]; then
            echo "[WARN] degraded_iface=$IF still_degraded score=$S (>${DEGRADE_SCORE_WARN}) ttl=${DWARN_TTL}s age=${AGE_PRINT}${AGE_SUFFIX}"
            set_state d_warn_ts_${IF} "$NOW_TS"
          fi
        fi
      elif [ "$NOW_D" -eq 0 ] && [ "$PREV_D" -eq 1 ]; then
        echo "[WARN] degraded_iface=$IF recovered score=$S (<=${DEGRADE_SCORE_WARN})"
        set_state d_warn_${IF} 0
        set_state d_warn_ts_${IF} 0

      fi
    done
  fi

  # ===== WAN snapshot =====

  WAN_IF="$(get_cache WAN IFACE)"
  WAN_RES="$(get_cache WAN RES)"
  WAN_SCORE="$(get_cache WAN SCORE)"
  WAN_META="$(get_cache WAN META)"
  if [ -z "${WAN_SCORE:-}" ] || [ -z "${WAN_META:-}" ]; then
    WAN_IF="$(detect_wan_if)"
    WAN_RES="$(score_wan_with_if "$WAN_IF")"
    WAN_SCORE="$(echo "$WAN_RES" | awk '{print $1}')"
    WAN_META="$(echo "$WAN_RES" | cut -d' ' -f2-)"
    set_cache WAN IFACE "$WAN_IF"
    set_cache WAN RES "$WAN_RES"
    set_cache WAN SCORE "$WAN_SCORE"
    set_cache WAN META "$WAN_META"
  fi
  echo "[WAN] score=$WAN_SCORE  $WAN_META"

  # ===== CUR snapshot =====
  CUR_SCORE="INF"
  if [ "$CUR" != "(none)" ]; then
    CUR_SCORE="$(get_cache VPN_SCORE "$CUR")"
    [ -z "${CUR_SCORE:-}" ] && CUR_SCORE="INF"
  fi
  echo "[CUR] $CUR score=$CUR_SCORE"
  # ===== TL;DR (no topo) =====
  DIFF_TLDR="NA"
DIFF_TLDR_NOTE=""
if [ "$DEV_MODE" = "vpn" ] && [ "$CUR" != "(none)" ] && [ "$CUR_SCORE" = "INF" ]; then
  DIFF_TLDR="INF"; DIFF_TLDR_NOTE=" (packet loss)"
fi
  if [ "$DEV_MODE" = "vpn" ] && [ -n "$BEST_IF" ] && [ "$BEST_SCORE" != "INF" ] && [ "$CUR" != "(none)" ] && [ "$CUR_SCORE" != "INF" ]; then
    DIFF_TLDR="$(awk -v c="$CUR_SCORE" -v b="$BEST_SCORE" 'BEGIN{printf "%.2f",(c-b)}')"
  fi
  echo "[TL;DR] cur=$CUR best=${BEST_IF:-none} diff=$DIFF_TLDR$DIFF_TLDR_NOTE thr=$SWITCH_MARGIN_MS wan=${WAN_SCORE:-INF}"
  # WAN incidente upstream (INF) — estado explicito, WARN por transicao
  PREV_W="$(get_state wan_incident)"; [ -z "${PREV_W:-}" ] && PREV_W=0
  NOW_W=0; [ "${WAN_SCORE:-INF}" = "INF" ] && NOW_W=1
  if [ "$NOW_W" -eq 1 ] && [ "$PREV_W" -eq 0 ]; then
    echo "[WARN] wan_incident_upstream=1 (wan_score=INF)"
    set_state wan_incident 1
  elif [ "$NOW_W" -eq 0 ] && [ "$PREV_W" -eq 1 ]; then
    echo "[WARN] wan_incident_upstream=0 (wan_score=${WAN_SCORE})"
    set_state wan_incident 0
  fi

  # ===== MODO A (VPN->VPN) =====
  if [ "$DEV_MODE" = "vpn" ]; then
    SHOULD_SWITCH=0
    NO_SWITCH_REASON="already_best"

    if [ "$CUR" = "(none)" ] || [ "$CUR_SCORE" = "INF" ]; then
      SHOULD_SWITCH=1
    elif [ -z "$BEST_IF" ] || [ "$BEST_SCORE" = "INF" ]; then
      SHOULD_SWITCH=0
      NO_SWITCH_REASON="no_best_available"
    elif [ "$BEST_IF" != "$CUR" ]; then
      DIFF="$(awk -v c="$CUR_SCORE" -v b="$BEST_SCORE" 'BEGIN{printf "%.2f",(c-b)}')"
      echo "[A] diff(cur-best)=$DIFF  thr=$SWITCH_MARGIN_MS"
      if awk -v d="$DIFF" -v m="$SWITCH_MARGIN_MS" 'BEGIN{exit !(d>=m)}'; then
        SHOULD_SWITCH=1
      else
        SHOULD_SWITCH=0
        NO_SWITCH_REASON="diff<threshold"
      fi
    else
      SHOULD_SWITCH=0
      NO_SWITCH_REASON="already_best"
    fi

    if [ "$SHOULD_SWITCH" -eq 1 ] && [ -n "$BEST_IF" ]; then
      if cooldown_ok; then
        echo "[A] switch_vpn: $CUR -> $BEST_IF"
        if apply_device_table "$BEST_IF"; then
          mark_switch
          CUR="$BEST_IF"
          NO_SWITCH_REASON="switched"
          echo "[ACTION] vpn_switched"
        else
          NO_SWITCH_REASON="apply_failed"
          echo "[ERR] code=30 switch_vpn aborted (apply_failed)"
          echo "[NEXT] verifique ip rule/pref=$RULE_PREF; tabela alvo; permissões; tente: ip rule | grep \"pref $RULE_PREF\""
          set_rc 30
        fi
      else
        NO_SWITCH_REASON="cooldown_active"
        echo "[A] no_switch (reason=$NO_SWITCH_REASON)"
      fi
    else
      echo "[A] no_switch (reason=$NO_SWITCH_REASON)"
    fi
  else
    echo "[A] skipped (mode=$DEV_MODE)"
  fi

# ===== VPN-STABLE (observabilidade: estabilidade em VPN) =====
if [ "$DEV_MODE" = "vpn" ]; then
  VG="$(get_state vpn_good_runs)"; [ -z "${VG:-}" ] && VG=0
  case "$NO_SWITCH_REASON" in
    already_best|diff\<threshold|cooldown_active)
      if [ "$VG" -lt "$VPN_BACK_STABLE_RUNS" ]; then
        VG=$((VG+1)); set_state vpn_good_runs "$VG"
      fi
      echo "[VPN-STABLE] vpn_good_runs=$VG/$VPN_BACK_STABLE_RUNS (reason=$NO_SWITCH_REASON)"
      ;;
    *)
      if [ "$VG" -ne 0 ]; then
        echo "[RESET] vpn_good_runs=0 (reason=$NO_SWITCH_REASON)"
      fi
      set_state vpn_good_runs 0
      ;;
  esac
else
  VG="$(get_state vpn_good_runs)"; [ -z "${VG:-}" ] && VG=0
  if [ "$VG" -ne 0 ]; then
    echo "[RESET] vpn_good_runs=0 (reason=not_in_vpn)"
  fi
  set_state vpn_good_runs 0
fi

  print_counters

  # ===== WAN FALLBACK (VPN pior que WAN por runs) =====
  if [ "$WAN_FALLBACK_ENABLE" -eq 1 ] && [ "$DEV_MODE" != "wan" ]; then
    if [ "$WAN_SCORE" != "INF" ] && [ "$BEST_SCORE" != "INF" ]; then
      DIFF_VPN_WAN="$(awk -v v="$BEST_SCORE" -v w="$WAN_SCORE" 'BEGIN{printf "%.2f",(v-w)}')"
      echo "[WAN-FB] diff(vpn-wan)=$DIFF_VPN_WAN  need>=$WAN_ADVANTAGE_MS  runs_req=$WAN_STABLE_RUNS"

      if awk -v d="$DIFF_VPN_WAN" -v m="$WAN_ADVANTAGE_MS" 'BEGIN{exit !(d>=m)}'; then
        N="$(get_state wan_bad_vpn_runs)"; [ -z "${N:-}" ] && N=0
        N=$((N+1)); set_state wan_bad_vpn_runs "$N"
      else
        echo "[RESET] wan_bad_vpn_runs=0 (reason=diff(vpn-wan)<need)"
        set_state wan_bad_vpn_runs 0
      fi

      N="$(get_state wan_bad_vpn_runs)"; [ -z "${N:-}" ] && N=0
      echo "[WAN-FB] wan_bad_vpn_runs=$N/$WAN_STABLE_RUNS"

      if [ "$N" -ge "$WAN_STABLE_RUNS" ] && cooldown_ok; then
        echo "[WAN-FB] apply wan fallback"
        if apply_wan_fallback; then
          mark_switch
        else
          echo "[ERR] code=30 wan_fallback aborted (apply_failed)"
          echo "[NEXT] verifique ip rule/pref=$RULE_PREF; WAN table; tente: ip rule | grep \"pref $RULE_PREF\""
          set_rc 30
        fi
        echo "[ACTION] wan_fallback_applied"
      fi
    else
      echo "[WAN-FB] cannot_evaluate (INF score)"
    fi
  else
    echo "[WAN-FB] skipped"
  fi

  # ===== WAN RETURN (WAN -> VPN por runs) =====
  if [ "$DEV_MODE" = "wan" ]; then
    if [ "$WAN_SCORE" != "INF" ] && [ "$BEST_SCORE" != "INF" ]; then
      DIFF_WAN_VPN="$(awk -v w="$WAN_SCORE" -v v="$BEST_SCORE" 'BEGIN{printf "%.2f",(w-v)}')"
      echo "[WAN-RET] diff(wan-vpn)=$DIFF_WAN_VPN  need>=$VPN_BACK_MARGIN_MS  runs_req=$VPN_BACK_STABLE_RUNS"

      if awk -v d="$DIFF_WAN_VPN" -v m="$VPN_BACK_MARGIN_MS" 'BEGIN{exit !(d>=m)}'; then
        N="$(get_state wan_good_vpn_runs)"; [ -z "${N:-}" ] && N=0
        N=$((N+1)); set_state wan_good_vpn_runs "$N"
      else
        echo "[RESET] wan_good_vpn_runs=0 (reason=diff<threshold_or_not_in_wan)"
        set_state wan_good_vpn_runs 0
      fi

      N="$(get_state wan_good_vpn_runs)"; [ -z "${N:-}" ] && N=0
      echo "[WAN-RET] good_vpn_runs=$N/$VPN_BACK_STABLE_RUNS"

      if [ "$N" -ge "$VPN_BACK_STABLE_RUNS" ] && cooldown_ok; then
        echo "[WAN-RET] return_to_vpn: apply $BEST_IF"
        if apply_device_table "$BEST_IF"; then
          mark_switch
        else
          echo "[ERR] code=30 switch_vpn aborted (apply_failed)"
          echo "[NEXT] verifique ip rule/pref=$RULE_PREF; tabela alvo; permissões; tente: ip rule | grep \"pref $RULE_PREF\""
          set_rc 30
        fi
        echo "[ACTION] returned_from_wan"
      fi
    else
      echo "[WAN-RET] cannot_evaluate (INF score)"
    fi
  else
    echo "[WAN-RET] skipped (not_in_wan)"
  fi

  # ===== RETORNO AO DEFAULT (wgc1) =====
  if [ "$DEV_MODE" != "vpn" ]; then
    echo "[RET-DEF] skip (mode=$DEV_MODE)"
  elif [ "$CUR" = "$DEFAULT_WG" ]; then
    echo "[RET-DEF] skip (already_on_default_table=$DEFAULT_WG)"
  elif [ "$CUR" = "(none)" ] || [ "$CUR_SCORE" = "INF" ]; then
    echo "[RET-DEF] skip (current VPN unstable)"
  else
    LAST_SW="$(get_state last_switch_epoch)"
    NOW="$(epoch)"

    if [ -z "${LAST_SW:-}" ]; then
      echo "[RET-DEF] not_eligible_yet (no last_switch_epoch)"
    elif [ $((NOW - LAST_SW)) -lt "$RETURN_DELAY_SEC" ]; then
      echo "[RET-DEF] not_eligible_yet (age=$((NOW - LAST_SW))s < ${RETURN_DELAY_SEC}s)"
    else
      DEF_SCORE="$(get_cache VPN_SCORE "$DEFAULT_WG")"
      [ -z "${DEF_SCORE:-}" ] && DEF_SCORE="INF"

      echo "[RET-DEF] default=$DEFAULT_WG score=$DEF_SCORE"
      echo "[RET-DEF] need stable=$RETURN_STABLE_RUNS margin=$RETURN_MARGIN_MS (delay_sec=$RETURN_DELAY_SEC)"

      if [ "$DEF_SCORE" = "INF" ]; then
        echo "[RESET] return_stable=0 (reason=default_INF)"
        set_state return_stable 0
        echo "[RET-DEF] default INF -> stable_runs reset"
      else
        DIFFR="$(awk -v c="$CUR_SCORE" -v d="$DEF_SCORE" 'BEGIN{printf "%.2f",(c-d)}')"
        echo "[RET-DEF] diff(cur-default)=$DIFFR  thr=$RETURN_MARGIN_MS"

        if awk -v d="$DIFFR" -v m="$RETURN_MARGIN_MS" 'BEGIN{exit !(d>=m)}'; then
          STABLE="$(get_state return_stable)"; [ -z "${STABLE:-}" ] && STABLE=0
          STABLE=$((STABLE + 1)); set_state return_stable "$STABLE"
        else
          set_state return_stable 0
        fi

        STABLE="$(get_state return_stable)"; [ -z "${STABLE:-}" ] && STABLE=0
        echo "[RET-DEF] stable_runs=$STABLE/$RETURN_STABLE_RUNS"

        if [ "$STABLE" -ge "$RETURN_STABLE_RUNS" ] && cooldown_ok; then
          echo "[RET-DEF] apply: $CUR -> $DEFAULT_WG"
          if apply_device_table "$DEFAULT_WG"; then
            mark_switch
            echo "[ACTION] returned_to_default"
          else
            echo "[ERR] code=30 ret_default aborted (apply_failed)"
            echo "[NEXT] verifique apply $DEFAULT_WG; ip rule/pref=$RULE_PREF; tente: ip route show table $DEFAULT_WG"
          set_rc 30
          fi
        fi
      fi
    fi
  fi

  # ===== SUMMARY (no final) =====
  if [ "$DEV_MODE" = "vpn" ] && [ "$CUR" != "(none)" ]; then
    echo "[SUMMARY] $DEVICE_LABEL via $CUR (VPN) | best=${BEST_IF:-none}(${BEST_SCORE:-INF}) | wan=${WAN_SCORE:-INF}"
    [ -z "${LAST_ACTION:-}" ] && LAST_ACTION=none
    write_cycle_json
  else
    echo "[SUMMARY] $DEVICE_LABEL via WAN | best=${BEST_IF:-none}(${BEST_SCORE:-INF}) | wan=${WAN_SCORE:-INF}"
  fi

  state_flush_device
}

set_rc() {
  # sobe RC (não deixa baixar): primeiro erro relevante vence
  _n="$1"
  case "$_n" in
    ""|*[!0-9]* ) return 0 ;;
  esac
  [ "${ENG_RC:-0}" -eq 0 ] && ENG_RC="$_n"
}

purge_tmp_orphans() {
  # Remove sobras orfas do ENG em /tmp (por PID morto). Nao toca em nada fora do escopo AVP.
  _me="$$"
  for f in /tmp/avp_eng.* /tmp/avp_eng.devices.* /tmp/.avp_eng_write_test.*; do
    [ -f "$f" ] || continue
    _pid="${f##*.}"
    [ "$_pid" = "$_me" ] && continue
    case "$_pid" in
      *[!0-9]*|"") continue;;
    esac
    kill -0 "$_pid" 2>/dev/null && continue
    rm -f "$f" 2>/dev/null || :
  done
}

# ---------- MAIN ----------
(
show_help() {
  cat <<'EOF'
Usage:
  avp-eng.sh --help
  avp-eng.sh --standalone        (override explicito do bloqueio)
  avp-eng.sh --rotate-usb         (rotate diário: move resumo p/ USB + compacta logs)
  AVP_ALLOW_STANDALONE=1 avp-eng.sh   (override explicito)

Notas importantes:
  - Por padrao, o ENG NAO deve ser executado sozinho.
    Ele foi projetado para rodar via POL (avp-pol.sh run / run --live),
    pois o POL aplica policy/profile antes de chamar o ENG.

  - Live real:
      AVP_LIVE=1  => streaming do TMPLOG no terminal durante a execucao

  - Ping / alvos:
      TARGETS="8.8.8.8 1.1.1.1"  (primario + fallback)
      PINGCOUNT=10
      PINGW=1

  - Diagnostico:
      Use o POL em modo live (avp-pol.sh run --live) ou o DIAG.
EOF
}

{
# CLI (somente quando rodar manualmente)
rotate_mode_handler "${1:-}"

case "${1:-}" in
  -h|--help) show_help; exit 0;;
  --standalone) shift;;
  "") :;;
  *) :;;
esac

  # ENG deve rodar via POL (policy/profile). Standalone é bloqueado por padrão.
  if [ "${AVP_CALLER:-}" != "POL" ] && [ "${AVP_ALLOW_STANDALONE:-0}" != "1" ] && [ "${1:-}" != "--standalone" ]; then
    echo "$(ts) [ERR] engine_standalone_blocked (use POL: avp-pol.sh run --live | ou DIAG)"
    echo "$(ts) [NEXT] override: AVP_ALLOW_STANDALONE=1 ou --standalone"
    exit 64
  fi
acquire_lock
ENG_RC=0
require_cmds
echo "==============================="
echo "$(ts) - AutoVPN Platform (AVP)"
echo "Component : AVP-ENG"
echo "Role      : Multi-Device VPN Failover"
echo "Version   : $SCRIPT_VER"
FW_KERNEL="$( [ "${HAS_UNAME:-0}" -eq 1 ] && uname -r 2>/dev/null || echo ? )"
FW_BUILD="$( [ "${HAS_NVRAM:-0}" -eq 1 ] && nvram get buildno 2>/dev/null || echo ? )"
FW_FW="$( [ "${HAS_NVRAM:-0}" -eq 1 ] && nvram get firmver 2>/dev/null || echo ? )"
echo "SCRIPT=$SCRIPT_VER  kernel=$FW_KERNEL  buildno=${FW_BUILD:-?}  firmver=${FW_FW:-?}"
echo "[POLICY] profile=${AUTOVPN_PROFILE:-unknown}"
echo "[CONFIG] cooldown=${COOLDOWN_SEC}s wan_need=${WAN_ADVANTAGE_MS}ms wan_runs=${WAN_STABLE_RUNS} vpn_back_need=${VPN_BACK_MARGIN_MS}ms vpn_back_runs=${VPN_BACK_STABLE_RUNS}"
echo "[CONFIG] ret_delay=${RETURN_DELAY_SEC}s ret_margin=${RETURN_MARGIN_MS}ms ret_runs=${RETURN_STABLE_RUNS}"
echo "[CONFIG] quar_score=${QUAR_DEGRADE_SCORE} quar_runs=${QUAR_DEGRADE_RUNS} quar_avoid=${QUAR_AVOID_SEC}s"
cleanup_old_logs

# ===== DEVICE LOOP =====
# Fonte de verdade (obrigatória): SSOT do VPN Director via AVP-POL.
if ! load_devices_from_ssot; then
  echo "[ERR] SSOT do VPN Director indisponível/inválida (via AVP-POL)"
  echo "[ERR] Engine abortado para evitar comportamento imprevisível"
  echo "[NEXT] teste: $AVP_POL_BIN device ssot"
  exit 20

fi
DEV_LABELS="$(printf '%b' "$DEVICES_LIST" | awk -F'|' 'NF>=1 && $1!="" { s=(s ? s", " : "") $1 } END{ print s }')"
echo "Devices   : ${DEV_LABELS:-?}"
print_devices_header "ssot(vpndirector via avp-pol.sh device ssot)"

warm_metrics_cycle

# Ordem de execução segue DEVICES_LIST
#
# limpeza garantida mesmo em exit antecipado (evita lixo em /tmp)
cleanup_tmp() { [ -n "${TMP_DEVLIST:-}" ] && rm -f "$TMP_DEVLIST" 2>/dev/null || :; }

release_lock() { rm -rf "$LOCKDIR" 2>/dev/null || :; }
cleanup_all() { cleanup_tmp; release_lock; }
trap cleanup_all EXIT HUP INT TERM

TMP_DEVLIST="/tmp/avp_eng.devices.$$"
printf "%b" "$DEVICES_LIST" >"$TMP_DEVLIST"
while IFS='|' read -r L I P S EN IFACE MAC; do
  [ -z "${L:-}" ] && continue

  if [ "${EN:-1}" != "1" ]; then
    echo "-------------------------------"
    echo "[DEVICE] $L  ip=$I  pref=$P  state=$S"
    echo "[SSOT] disabled (iface_base=${IFACE:-?} mac=${MAC:-}) -> skip manage + cleanup residual ip rule(s)"
    cleanup_rules_for_ip_anypref "$I"
    continue
  fi

  DEVICE_LABEL="$L"
  DEVICE_IP="$I"
  RULE_PREF="$P"
  STATE_FILE="$S"
  run_device
done <"$TMP_DEVLIST"
rm -f "$TMP_DEVLIST" 2>/dev/null || :

echo "$(ts) - DONE"
echo
exit "${ENG_RC:-0}"
} ) >"$TMPLOG" 2>&1 &
pid=$!

if [ "${AVP_LIVE:-0}" = "1" ]; then
  # streaming real no terminal enquanto o engine roda
  tail -f "$TMPLOG" &
  tpid=$!
  wait "$pid"; rc=$?
  kill "$tpid" 2>/dev/null || :

  # anexa no LOG sem duplicar a tela (já foi mostrado pelo tail)
  if type tee >/dev/null 2>&1; then
    tee -a "$LOG" <"$TMPLOG" >/dev/null
  else
    cat "$TMPLOG" >>"$LOG"
  fi
  rm -f "$TMPLOG" 2>/dev/null || :
  exit $rc
fi

# modo normal: espera o engine e então grava/mostra como antes
wait "$pid"; rc=$?
if type tee >/dev/null 2>&1; then
  tee -a "$LOG" <"$TMPLOG"
else
  cat "$TMPLOG" >>"$LOG"
  cat "$TMPLOG"
fi
if [ "$rc" -ne 0 ]; then
  if has_fn log_error; then
    log_error "ENG" "run failed" "$rc" "log=$LOG"
  fi
fi
rm -f "$TMPLOG" 2>/dev/null || :
exit $rc
