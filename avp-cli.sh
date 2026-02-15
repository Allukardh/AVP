#!/bin/sh
# =============================================================
# AutoVPN Platform (AVP)
# Component : AVP-CLI
# File      : avp-cli.sh
# Role      : Machine-readable status for WebUI/automation (JSON canon + KV fallback)
# Version   : v1.0.13 (2026-01-27)
# Status    : C1 (initial)
# =============================================================
#
# CHANGELOG
# - v1.0.13 (2026-01-27)
#   * CHORE: hygiene (trim trailing WS; collapse blank lines; no logic change)
# - v1.0.12 (2026-01-27)
#   * CHORE: hygiene (whitespace/blank lines; no logic change)
# - v1.0.11 (2026-01-26)
#   * VERSION: bump patch (pos harden canônico)
# - v1.0.10 (2026-01-26)
#   * DEDUP: remove harden_state_dir do CLI; perms 0600 via writer canônico + ENG + services-start --perms-only
# - v1.0.9 (2026-01-26)
#   * HARDEN: cura states dinamicos (avp_*.state) como 0600 (labels mudam via GUI/devices.conf)
# - v1.0.8 (2026-01-21)
#   * FIX   : AVP_CLI_STRICT=1 agora retorna RC=2 tambem em status com flag invalida; e main propaga RC do status.
# - v1.0.7 (2026-01-21)
#   * ADD   : AVP_CLI_STRICT=1 => unknown flag/command retorna RC=2 (mantem JSON impresso; default segue RC=0).
# - v1.0.6 (2026-01-18)
#   * POLISH: padroniza SCRIPT_VER + set -u (ordem oficial) e remove linhas em branco desnecessarias
# - v1.0.5 (2026-01-17)
#   * FIX   : json_escape chamado sem aspas escapadas (remove ruído \"$VAR\")
# - v1.0.4 (2026-01-17)
#   * FIX   : remove duplicacao do bloco obj JSON (awk consume com ltrim) + indent consistente
# - v1.0.3 (2026-01-17)
#   * POLISH: split do obj JSON (anti-wrap) + indent consistente
# - v1.0.2 (2026-01-04)
#   * FIX: POLICY_DIR volta ao canônico do projeto (AVP_ROOT/autovpn/policy) mantendo STATE_DIR em (AVP_ROOT/avp/state)
# - v1.0.1 (2026-01-04)
#   * ADD: erro estruturado no JSON (err:{level,code,where,hint}) mantendo errors[] para compatibilidade
#   * ADD: purge leve de /tmp (/tmp/avp_cli_devices.*) para evitar sobras órfãs AVP-only
# - v1.0.0 (2025-12-30)
#   * ADD: status (JSON compacto canonico) para GUI/automacao (sem jq)
#   * ADD: status --pretty (jq opcional; stderr warn; stdout preserva contrato)
#   * ADD: status --kv (fallback humano/legado; grep/shell-friendly)
#   * SAFETY: nunca falha por ausencia de dependencias/policy; sempre retorna JSON valido
# =============================================================

SCRIPT_VER="v1.0.13"
export PATH="/jffs/scripts:/opt/bin:/opt/sbin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH:-}"
hash -r 2>/dev/null || true
set -u

# Allow test harness / offline runs (default = Merlin real path)
AVP_ROOT="${AVP_ROOT:-/jffs/scripts}"

POLICY_DIR="${AVP_ROOT}/autovpn/policy"
STATE_DIR="${AVP_ROOT}/avp/state"

GLOBAL_CONF="$POLICY_DIR/global.conf"
DEVICES_CONF="$POLICY_DIR/devices.conf"

ts() { date '+%Y-%m-%d %H:%M:%S'; }
warn() { printf "%s\n" "$*" >&2; }

# Collect errors (also exported in JSON)
ERRORS=""

add_err() {
  # store as plain text (will be JSON-escaped later)
  if [ -z "${ERRORS:-}" ]; then
    ERRORS="$1"
  else
    ERRORS="${ERRORS} | $1"
  fi
}

err_meta() {
  # Maps error codes to: LEVEL|HINT (kept short; safe for GUI/log)
  _c="$1"
  case "$_c" in
    global.conf_missing) echo "WARN|crie $GLOBAL_CONF";;
    global.enabled_invalid) echo "WARN|verifique AUTOVPN_ENABLED em $GLOBAL_CONF";;
    global.profile_invalid) echo "WARN|verifique AUTOVPN_PROFILE em $GLOBAL_CONF";;
    devices.conf_missing) echo "WARN|crie $DEVICES_CONF";;
    cli.unknown_flag) echo "ERR|use: $0 status [--pretty|--kv]";;
    cli.unknown_command) echo "ERR|use: $0 status [--pretty|--kv]";;
    *) echo "ERR|verifique logs e configs";;
  esac
}

purge_tmp_orphans_cli() {
  # Remove only AVP CLI tmp files that belong to dead PIDs (AVP-only safety)
  for f in /tmp/avp_cli_devices.*; do
    [ -e "$f" ] || continue
    pid="${f##*.}"
    case "$pid" in
      *[!0-9]*|"") continue ;;
    esac
    kill -0 "$pid" 2>/dev/null && continue
    rm -f "$f" 2>/dev/null || :
  done
}

# BusyBox/POSIX-safe label sanitizer (same spirit as ENG)
sanitize_label() {
  IN="$1"
  OUT="$(printf "%s" "$IN" | LC_ALL=C sed 'y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/')"
  OUT="$(printf "%s" "$OUT" | LC_ALL=C sed 's/[^a-z0-9_]/_/g; s/__*/_/g; s/^_//; s/_$//')"
  [ -z "${OUT:-}" ] && OUT="device"
  printf "%s" "$OUT"
}

# Minimal JSON escaping (enough for our fields)
json_escape() {
  # escape backslash and double quote; strip CR; keep others
  printf "%s" "$1" \
    | tr -d '\r' \
    | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# Read key=value from state file (returns empty if not found)
get_state_kv() {
  _file="$1"
  _key="$2"
  [ -f "$_file" ] || { printf "%s" ""; return 0; }
  _val="$(grep -m 1 "^${_key}=" "$_file" 2>/dev/null | sed "s/^${_key}=//")"
  printf "%s" "${_val:-}"
}

# Load global.conf with safe defaults
load_global() {
  AUTOVPN_ENABLED=1
  AUTOVPN_PROFILE="balanced"

  if [ ! -f "$GLOBAL_CONF" ]; then
    add_err "global.conf_missing"
    warn "[WARN] global.conf missing: $GLOBAL_CONF (defaults enabled=1 profile=balanced)"
    return 0
  fi

  _en="$(grep -m 1 '^AUTOVPN_ENABLED=' "$GLOBAL_CONF" 2>/dev/null | sed 's/^AUTOVPN_ENABLED=//')"
  _pr="$(grep -m 1 '^AUTOVPN_PROFILE=' "$GLOBAL_CONF" 2>/dev/null | sed 's/^AUTOVPN_PROFILE=//')"

  case "${_en:-}" in
    0) AUTOVPN_ENABLED=0 ;;
    1|"") AUTOVPN_ENABLED=1 ;;
    *) AUTOVPN_ENABLED=1; add_err "global.enabled_invalid"; warn "[WARN] AUTOVPN_ENABLED invalid; using 1" ;;
  esac

  case "${_pr:-}" in
    "" ) : ;;
    balanced|performance|lunar ) AUTOVPN_PROFILE="$_pr" ;;
    *) add_err "global.profile_invalid"; warn "[WARN] AUTOVPN_PROFILE invalid; using balanced" ;;
  esac
}

# Load devices from devices.conf (LABEL IP PREF ...)
load_devices_from_conf() {
  DEVICES_LIST=""

  if [ ! -f "$DEVICES_CONF" ]; then
    add_err "devices.conf_missing"
    warn "[WARN] devices.conf missing: $DEVICES_CONF (devices=[])"
    return 0
  fi

  while read -r LABEL IP PREF _rest || [ -n "${LABEL:-}" ]; do
    LABEL="$(printf "%s" "$LABEL" | tr -d '\r')"
    IP="$(printf "%s" "$IP" | tr -d '\r')"
    PREF="$(printf "%s" "$PREF" | tr -d '\r')"

    [ -z "${LABEL:-}" ] && continue
    case "$LABEL" in \#*) continue ;; esac

    SL="$(sanitize_label "$LABEL")"
    SF="${STATE_DIR}/avp_${SL}.state"

    if [ -z "${DEVICES_LIST:-}" ]; then
      DEVICES_LIST="${LABEL}|${IP}|${PREF}|${SF}|${SL}\n"
    else
      DEVICES_LIST="${DEVICES_LIST}${LABEL}|${IP}|${PREF}|${SF}|${SL}\n"
    fi
  done <"$DEVICES_CONF"
}

build_json_status() {
  purge_tmp_orphans_cli

  _enabled="${AUTOVPN_ENABLED:-1}"
  _profile="${AUTOVPN_PROFILE:-balanced}"

  dev_json=""
  first=1

  _tmp="/tmp/avp_cli_devices.$$"
  printf "%b" "${DEVICES_LIST:-}" >"$_tmp" 2>/dev/null || :

  if [ -s "$_tmp" ]; then
    while IFS='|' read -r L I P S SL || [ -n "${L:-}" ]; do
      [ -z "${L:-}" ] && continue

      mode="$(get_state_kv "$S" "dev_mode")"; [ -z "${mode:-}" ] && mode="unknown"
      table="$(get_state_kv "$S" "last_real_table")"
      lse="$(get_state_kv "$S" "last_switch_epoch")"; [ -z "${lse:-}" ] && lse=""

      obj="{\"label\":\"$(json_escape "$L")\",\"ip\":\"$(json_escape "$I")\",\"pref\":\"$(json_escape "$P")\","
      obj="${obj}\"state\":\"$(json_escape "$mode")\",\"table\":\"$(json_escape "${table:-}")\","
      obj="${obj}\"last_switch_epoch\":\"$(json_escape "${lse:-}")\"}"

      if [ "$first" -eq 1 ]; then
        dev_json="$obj"
        first=0
      else
        dev_json="${dev_json},${obj}"
      fi
    done <"$_tmp"
  fi

  rm -f "$_tmp" 2>/dev/null || :

  # errors as array (split by " | ")
  err_arr=""
  if [ -n "${ERRORS:-}" ]; then
    _rest="$ERRORS"
    while :; do
      case "$_rest" in
        *" | "*) _one="${_rest%% | *}"; _rest="${_rest#* | }" ;;
        *) _one="$_rest"; _rest="" ;;
      esac
      _onej="$(json_escape "$_one")"
      if [ -z "${err_arr:-}" ]; then
        err_arr="\"$_onej\""
      else
        err_arr="${err_arr},\"$_onej\""
      fi
      [ -z "$_rest" ] && break
    done
  fi

  if [ -n "${err_arr:-}" ]; then
    _first="${ERRORS%% | *}"
    _meta="$(err_meta "$_first")"
    _lvl="${_meta%%|*}"
    _hint="${_meta#*|}"
    _fj="$(json_escape "$_first")"
    _lvlj="$(json_escape "$_lvl")"
    _hj="$(json_escape "$_hint")"
    printf "{\"enabled\":%s,\"profile\":\"%s\",\"devices\":[%s],\"errors\":[%s],\"err\":{\"level\":\"%s\",\"code\":\"%s\",\"where\":\"CLI\",\"hint\":\"%s\"}}\n" \
      "$_enabled" "$(json_escape "$_profile")" "${dev_json:-}" "$err_arr" "$_lvlj" "$_fj" "$_hj"
  else
    printf "{\"enabled\":%s,\"profile\":\"%s\",\"devices\":[%s]}\n" \
      "$_enabled" "$(json_escape "$_profile")" "${dev_json:-}"
  fi
}

build_kv_status() {
  printf "enabled=%s\n" "${AUTOVPN_ENABLED:-1}"
  printf "profile=%s\n" "${AUTOVPN_PROFILE:-balanced}"

  _tmp="/tmp/avp_cli_devices.$$"
  printf "%b" "${DEVICES_LIST:-}" >"$_tmp" 2>/dev/null || :

  if [ -s "$_tmp" ]; then
    while IFS='|' read -r L I P S SL || [ -n "${L:-}" ]; do
      [ -z "${L:-}" ] && continue

      mode="$(get_state_kv "$S" "dev_mode")"; [ -z "${mode:-}" ] && mode="unknown"
      table="$(get_state_kv "$S" "last_real_table")"
      lse="$(get_state_kv "$S" "last_switch_epoch")"; [ -z "${lse:-}" ] && lse=""

      printf "device_%s_label=%s\n" "$SL" "$L"
      printf "device_%s_ip=%s\n" "$SL" "$I"
      printf "device_%s_pref=%s\n" "$SL" "$P"
      printf "device_%s_state=%s\n" "$SL" "$mode"
      printf "device_%s_table=%s\n" "$SL" "${table:-}"
      printf "device_%s_last_switch_epoch=%s\n" "$SL" "${lse:-}"
    done <"$_tmp"
  fi

  rm -f "$_tmp" 2>/dev/null || :

  if [ -n "${ERRORS:-}" ]; then
    printf "errors=%s\n" "$ERRORS"
  fi
}

show_help() {
  cat <<'HELP_EOF'
Usage:
  avp-cli.sh status [--pretty|--kv]

Modes:
  status           JSON compacto (canonico, machine-friendly)
  status --pretty  JSON formatado (jq opcional; stderr warn)
  status --kv      KV (humano/grep-friendly)
HELP_EOF
}

cmd_status() {
  mode="${1:-}"

  load_global
  load_devices_from_conf

  case "$mode" in
    "" ) build_json_status; return 0 ;;
    "--kv" ) build_kv_status; return 0 ;;
    "--pretty" )
      if command -v jq >/dev/null 2>&1; then
        build_json_status | jq .
      else
        warn "[WARN] jq not found; returning compact JSON"
        build_json_status
      fi
      return 0
      ;;
    * )
      add_err "cli.unknown_flag"
      build_json_status
      [ "${AVP_CLI_STRICT:-0}" = "1" ] && return 2
      return 0
      ;;
  esac
}

main() {
  cmd="${1:-}"
  case "$cmd" in
    ""|-h|--help|help) show_help; exit 0 ;;
    status) shift || true; cmd_status "${1:-}"; exit $? ;;
    *)
      add_err "cli.unknown_command"
      build_json_status
      [ "${AVP_CLI_STRICT:-0}" = "1" ] && exit 2
      exit 0
      ;;
  esac
}

main "$@"
