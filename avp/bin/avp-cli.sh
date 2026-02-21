#!/bin/sh
# =============================================================
# AutoVPN Platform (AVP)
# Component : AVP-CLI
# File      : avp-cli.sh
# Role      : Machine-readable status for WebUI/automation (JSON canon + KV fallback)
# Version   : v1.0.21 (2026-02-21)
# Status    : C1 (initial)
# =============================================================

SCRIPT_VER="v1.0.21"
export PATH="/jffs/scripts:/jffs/scripts/avp/bin:/opt/bin:/opt/sbin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH:-}"
hash -r 2>/dev/null || true
set -u

# Allow test harness / offline runs (default = Merlin real path)
AVP_ROOT="${AVP_ROOT:-/jffs/scripts}"

POLICY_DIR="${AVP_ROOT}/avp/policy"
STATE_DIR="${AVP_ROOT}/avp/state"

GLOBAL_CONF="$POLICY_DIR/global.conf"
AVP_POL_BIN="${AVP_ROOT}/avp/bin/avp-pol.sh"

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
    ssot.unavailable) echo "ERR|verifique SSOT: $AVP_POL_BIN device ssot";;
    cli.unknown_flag) echo "ERR|use: $0 status [--json|--pretty|--kv]";;
    cli.unknown_command) echo "ERR|use: $0 status [--json|--pretty|--kv]";;
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

# Load devices from SSOT (VPN Director via AVP-POL)
# DEVICES_LIST lines:
#   LABEL|IP|PREF|STATEFILE|SLUG|ENABLED|IFACE_BASE|MAC
load_devices_from_ssot() {
  DEVICES_LIST=""

  if [ ! -x "$AVP_POL_BIN" ]; then
    add_err "ssot.unavailable"
    warn "[ERR] AVP-POL not executable: $AVP_POL_BIN"
    return 1
  fi

  _ssot="$("$AVP_POL_BIN" device ssot 2>/dev/null || true)"
  if [ -z "${_ssot:-}" ]; then
    add_err "ssot.unavailable"
    warn "[ERR] SSOT unavailable via AVP-POL (sem fallback para devices.conf)"
    return 1
  fi

  _tmp="/tmp/avp_cli_ssot.$$"
  printf "%s\n" "$_ssot" >"$_tmp" 2>/dev/null || return 1

  while IFS='|' read -r EN LABEL IP IFACE_BASE MAC || [ -n "${LABEL:-}" ]; do
    EN="$(printf "%s" "${EN:-}" | tr -d '\r')"
    LABEL="$(printf "%s" "${LABEL:-}" | tr -d '\r')"
    IP="$(printf "%s" "${IP:-}" | tr -d '\r')"
    IFACE_BASE="$(printf "%s" "${IFACE_BASE:-}" | tr -d '\r')"
    MAC="$(printf "%s" "${MAC:-}" | tr -d '\r')"

    [ -z "${LABEL:-}" ] && continue
    case "$LABEL" in \#*) continue ;; esac

    SL="$(sanitize_label "$LABEL")"
    SF="${STATE_DIR}/avp_${SL}.state"

    # PREF no CLI é informativo; tenta ler o pref atual do kernel por IP
    PREF="$(ip rule show 2>/dev/null | awk -v ip="$IP" '
      $0 ~ ("from " ip) {
        p=$1; sub(/:$/, "", p)
        if (p ~ /^[0-9]+$/) { print p; exit }
      }'
    )"
    [ -z "${PREF:-}" ] && PREF=""

    DEVICES_LIST="${DEVICES_LIST}${LABEL}|${IP}|${PREF}|${SF}|${SL}|${EN}|${IFACE_BASE}|${MAC}\n"
  done <"$_tmp"

  rm -f "$_tmp" 2>/dev/null || :
  return 0
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
    while IFS='|' read -r L I P S SL EN IFACE MAC || [ -n "${L:-}" ]; do
      [ -z "${L:-}" ] && continue

      mode="$(get_state_kv "$S" "dev_mode")"; [ -z "${mode:-}" ] && mode="unknown"
      table="$(get_state_kv "$S" "last_real_table")"
      lse="$(get_state_kv "$S" "last_switch_epoch")"; [ -z "${lse:-}" ] && lse=""

      [ -z "${EN:-}" ] && EN="1"
      [ -z "${IFACE:-}" ] && IFACE="wan"
      obj="{\"label\":\"$(json_escape "$L")\",\"ip\":\"$(json_escape "$I")\",\"pref\":\"$(json_escape "$P")\","
      obj="${obj}\"enabled\":${EN},\"iface_base\":\"$(json_escape "${IFACE:-}")\",\"mac\":\"$(json_escape "${MAC:-}")\","
      obj="${obj}\"state\":\"$(json_escape "$mode")\",\"route\":\"$(json_escape "${table:-}")\",\"table\":\"$(json_escape "${table:-}")\","
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
    while IFS='|' read -r L I P S SL EN IFACE MAC || [ -n "${L:-}" ]; do
      [ -z "${L:-}" ] && continue

      mode="$(get_state_kv "$S" "dev_mode")"; [ -z "${mode:-}" ] && mode="unknown"
      table="$(get_state_kv "$S" "last_real_table")"
      lse="$(get_state_kv "$S" "last_switch_epoch")"; [ -z "${lse:-}" ] && lse=""

      printf "device_%s_label=%s\n" "$SL" "$L"
      printf "device_%s_ip=%s\n" "$SL" "$I"
      printf "device_%s_pref=%s\n" "$SL" "$P"
      printf "device_%s_enabled=%s\n" "$SL" "${EN:-1}"
      printf "device_%s_iface_base=%s\n" "$SL" "${IFACE:-}"
      printf "device_%s_mac=%s\n" "$SL" "${MAC:-}"
      printf "device_%s_state=%s\n" "$SL" "$mode"
      printf "device_%s_table=%s\n" "$SL" "${table:-}"
      printf "device_%s_route=%s\n" "$SL" "${table:-}"
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
  avp-cli.sh status [--json|--pretty|--kv]

Modes:
  status           JSON compacto (canonico, machine-friendly)
  status --pretty  JSON formatado (jq opcional; stderr warn)
  status --kv      KV (humano/grep-friendly)
HELP_EOF
}

cmd_status() {
  mode="${1:-}"

  load_global
  load_devices_from_ssot || return 20

  case "$mode" in
    ""|"--json" ) build_json_status; return 0 ;;
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
