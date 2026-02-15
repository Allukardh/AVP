#!/bin/sh
# =============================================================
# AutoVPN Platform (AVP)
# Component : AVP-ACTION
# File      : avp-action.sh
# Role      : Local action handler (whitelist + token + JSON)
# Version   : v1.0.20 (2026-01-27)
# Status    : stable
# =============================================================
#
# CHANGELOG
# - v1.0.20 (2026-01-27)
#   * CHORE: hygiene (trim trailing WS; collapse blank lines; no logic change)
# - v1.0.19 (2026-01-27)
#   * CHORE: hygiene (whitespace/blank lines; no logic change)
# - v1.0.18 (2026-01-27)
#   * FIX: url_decode STRICT %HH agora BusyBox-sed safe (BRE); evita gerar "\x" sem dígitos e restaura UTF-8 (%C3%A1 etc.)
# - v1.0.17 (2026-01-27)
#   * HARDEN: url_decode — STRICT %XX (decodifica só %[0-9A-Fa-f]{2}); mantém % inválido literal + protege \\ antes do printf %b
# - v1.0.16 (2026-01-27)
#   * HARDEN: url_decode — escapa "\\" literal antes do printf %b (evita interpretar \\n/\\t/\\r etc.), mantendo %XX (UTF-8)
# - v1.0.15 (2026-01-27)
#   * FIX: url_decode — decode %XX com printf %b (UTF-8 correto, ex: ol%C3%A1%21 -> olá!)
# - v1.0.14 (2026-01-27)
#   * FIX: json_reply — valida/normaliza data com jq (quando disponível) e remove hack por contagem de chaves
#   * FIX: qs_get — parser em POSIX sh (sem awk), preserva valores com = e mantém url_decode
# - v1.0.13 (2026-01-27)
#   * FIX: Jeito B — AVP_STATE_DIR/AVP_TOKEN_FILE respeitam override via env (debug/teste sem tocar state real)
# - v1.0.12 (2026-01-27)
#   * DEBUG: token_rand loga método (AVP_ACTION_DEBUG/AVP_DEBUG) + mantém fallbacks sem od
# - v1.0.11 (2026-01-27)
#   * FIX: token_get robusto (fallback sem od: hexdump/openssl/md5sum/uuid)
# - v1.0.10 (2026-01-26)
#   * VERSION: bump patch (pos harden canônico)
# - v1.0.9 (2026-01-21)
#   * POLISH: qs_get passa a fazer URL decode (+ e %XX) para inputs via QUERY_STRING
# - v1.0.8 (2026-01-18)
#   * POLISH: padroniza SCRIPT_VER + set -u (ordem oficial) e remove linhas em branco desnecessarias
# - v1.0.7 (2026-01-07)
#   * SAFETY: força PATH robusto (CGI/non-interactive) incluindo /jffs/scripts e /opt/bin
# - v1.0.6 (2026-01-06)
#   * CHG: reload usa POL reload --async (nao bloqueia CGI enquanto ENG roda)
# - v1.0.5 (2026-01-06)
#   * FIX: unwrap_pol_data usa /opt/bin/jq quando PATH (CGI/non-interactive) nao expoe jq
#   * SAFETY: mantem fallback sem jq (devolve JSON inteiro, ainda valido)
# - v1.0.4 (2026-01-06)
#   * FIX: json_reply sanitiza "data" por balanceamento (remove somente "}" quando close>open)
#   * SAFETY: nao altera JSON valido/aninhado; mantém contrato ok/rc/action/msg/data/ts
# - v1.0.3 (2026-01-06)
#   * FIX: token sanitize (remove CR/LF/spaces/quotes/backslashes)
#   * FIX: token_get JSON canônico (data via printf)
#   * SAFETY: status/snapshot pegam a última linha do POL + unwrap .data quando houver jq
# - v1.0.2 (2026-01-05)
#   * FIX: JSON canônico (json_reply em 1 printf)
#   * FIX: token fallback forte (urandom->hex) quando sem openssl
# - v1.0.1 (2026-01-05)
#   * ADD: action=token_get (bootstrap do token via JSON)
#   * SAFETY: gate de origem (CGI) - permite apenas IP local/LAN (RFC1918 + 127/8)
# - v1.0.0 (2026-01-05)
#   * ADD: C2.2 local action handler (whitelist + token + JSON)
# =============================================================

SCRIPT_VER="v1.0.20"
export PATH="/jffs/scripts:/opt/bin:/opt/sbin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH:-}"
hash -r 2>/dev/null || true
set -u

# URL decode: + => space; %XX => byte (best-effort, BusyBox-safe)
url_decode() {
  s="${1:-}"
  # + -> space (querystring)
  s="$(printf "%s" "$s" | tr "+" " ")"
  # HARDEN + STRICT:
  #  - primeiro escapa "\" literal -> "\\" (pra printf %b não interpretar \n/\t/\r etc.)
  #  - depois converte SOMENTE %HH (HH hex) -> \xHH (BRE, BusyBox-safe)
  esc="$(printf "%s" "$s" | sed 's/\\/\\\\/g; s/%\([0-9A-Fa-f][0-9A-Fa-f]\)/\\x\1/g')"
  printf "%b" "$esc"
}

# PATH robusto para CGI/non-interactive (Merlin/WebUI)

ts_epoch() { date +%s; }

AVP_STATE_DIR="${AVP_STATE_DIR:-/jffs/scripts/avp/state}"
AVP_TOKEN_FILE="${AVP_TOKEN_FILE:-$AVP_STATE_DIR/avp_gui.token}"

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
  tsj="$(ts_epoch)"
  [ "$ok" = "1" ] && okstr=true || okstr=false
  [ -n "${data:-}" ] || data="{}"

  data="$(printf "%s" "$data" | sed "s/[[:space:]]*$//")"
  case "$data" in
    "{"*|"["*)
      if [ -x /opt/bin/jq ]; then
        nd="$(printf "%s" "$data" | /opt/bin/jq -c . 2>/dev/null || true)"
        [ -n "${nd:-}" ] && data="$nd" || data="{}"
      elif command -v jq >/dev/null 2>&1; then
        nd="$(printf "%s" "$data" | jq -c . 2>/dev/null || true)"
        [ -n "${nd:-}" ] && data="$nd" || data="{}"
      fi
      ;;
    *) data="{}" ;;
  esac

  printf '{"ok":%s,"rc":%s,"action":"%s","msg":"%s","data":%s,"ts":%s}\n' \
    "$okstr" "$rc" "$(jesc "$action")" "$(jesc "$msg")" "$data" "$tsj"
}

err() { json_reply 0 "${1:-1}" "${2:-err}" "${3:-error}" "${4:-{}}"; }
ok()  { json_reply 1 0 "${1:-ok}"  "${2:-ok}"    "${3:-{}}"; }

ensure_state() {
  [ -d "$AVP_STATE_DIR" ] || mkdir -p "$AVP_STATE_DIR" 2>/dev/null || :
}

read_token() {
  ensure_state
  [ -f "$AVP_TOKEN_FILE" ] || return 1
  # sanitize: remove CR/LF/spaces/quotes/backslashes (bug antigo gravou \"...\")
  tr -d '\r\n "' <"$AVP_TOKEN_FILE" 2>/dev/null | tr -d '\\'
}

gen_token() {
  ensure_state
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 16 2>/dev/null && return 0
  fi
  # token rand (16 bytes -> 32 hex) com fallbacks (BusyBox/Merlin-safe)
  # DEBUG: export AVP_ACTION_DEBUG=1 (ou AVP_DEBUG=1) para logar método em stderr
  if [ "${AVP_ACTION_DEBUG:-${AVP_DEBUG:-0}}" = "1" ]; then
    if type od >/dev/null 2>&1; then
      echo "[ACTION] DEBUG: token_rand method=od" >&2
    elif type hexdump >/dev/null 2>&1; then
      echo "[ACTION] DEBUG: token_rand method=hexdump" >&2
    elif type openssl >/dev/null 2>&1; then
      echo "[ACTION] DEBUG: token_rand method=openssl" >&2
    elif type md5sum >/dev/null 2>&1; then
      echo "[ACTION] DEBUG: token_rand method=md5sum" >&2
    elif [ -r /proc/sys/kernel/random/uuid ]; then
      echo "[ACTION] DEBUG: token_rand method=uuid" >&2
    else
      echo "[ACTION] DEBUG: token_rand method=none" >&2
    fi
  fi
  if type od >/dev/null 2>&1; then
    dd if=/dev/urandom bs=16 count=1 2>/dev/null | od -An -tx1 | tr -d " \n"
  elif type hexdump >/dev/null 2>&1; then
    dd if=/dev/urandom bs=16 count=1 2>/dev/null | hexdump -v -e "1/1 \"%02x\"" 2>/dev/null | head -c 32
  elif type openssl >/dev/null 2>&1; then
    openssl rand -hex 16 2>/dev/null | tr -d " \n" | head -c 32
  elif type md5sum >/dev/null 2>&1; then
    dd if=/dev/urandom bs=32 count=1 2>/dev/null | md5sum 2>/dev/null | awk "{print \$1}" | head -c 32
  elif [ -r /proc/sys/kernel/random/uuid ]; then
    tr -d "-" </proc/sys/kernel/random/uuid 2>/dev/null | head -c 32
  else
    echo ""
  fi
}

require_token() {
  tok_in="${1:-}"
  tok="$(read_token 2>/dev/null || true)"

  if [ -z "${tok:-}" ]; then
    tok="$(gen_token)"
    printf '%s\n' "$tok" >"$AVP_TOKEN_FILE" 2>/dev/null || :
    chmod 600 "$AVP_TOKEN_FILE" 2>/dev/null || :
  fi

  [ -n "${tok_in:-}" ] || { err 22 "auth" "missing token" '{"hint":"token required"}'; return 22; }
  [ "$tok_in" = "$tok" ] || { err 22 "auth" "invalid token" '{}'; return 22; }
  return 0
}

qs_get() {
  key="$1"
  qs="${QUERY_STRING:-}"
  [ -n "${qs:-}" ] || { printf "%s" ""; return 0; }
  oldIFS="$IFS"; IFS="&"
  for kv in $qs; do
    case "$kv" in
      "$key="*) v="${kv#*=}"; IFS="$oldIFS"; url_decode "${v:-}"; return 0;;
      "$key")   IFS="$oldIFS"; printf "%s" ""; return 0;;
    esac
  done
  IFS="$oldIFS"
  printf "%s" ""
}

is_private_ip() {
  ip="$1"
  case "$ip" in
    127.*|10.*|192.168.*) return 0;;
    172.*)
      o2="$(printf '%s' "$ip" | cut -d. -f2 2>/dev/null)"
      [ -n "${o2:-}" ] && [ "$o2" -ge 16 ] && [ "$o2" -le 31 ] 2>/dev/null && return 0
      return 1
      ;;
    *) return 1;;
  esac
}

require_origin() {
  ip="${REMOTE_ADDR:-}"
  [ -n "${ip:-}" ] || return 0
  is_private_ip "$ip" && return 0
  err 22 "origin" "forbidden" '{"hint":"LAN/local only"}'
  return 22
}

unwrap_pol_data() {
  polj="$1"
  if [ -x /opt/bin/jq ]; then
    printf '%s' "$polj" | /opt/bin/jq -c '.data // {}' 2>/dev/null || printf '{}'
  elif command -v jq >/dev/null 2>&1; then
    printf '%s' "$polj" | jq -c '.data // {}' 2>/dev/null || printf '{}'
  else
    # sem jq: devolve o JSON inteiro (ainda é JSON válido)
    printf '%s' "$polj"
  fi
}

main() {
  action=""; token=""; label=""; ip=""; rule=""; profile=""

  if [ -n "${QUERY_STRING:-}" ]; then
    action="$(qs_get action)"
    token="$(qs_get token)"
    label="$(qs_get label)"
    ip="$(qs_get ip)"
    rule="$(qs_get rule)"
    profile="$(qs_get profile)"
  else
    for kv in "$@"; do
      k="${kv%%=*}"; v="${kv#*=}"
      case "$k" in
        action) action="$v";;
        token) token="$v";;
        label) label="$v";;
        ip) ip="$v";;
        rule) rule="$v";;
        profile) profile="$v";;
      esac
    done
  fi

  # gate de origem: só faz sentido em CGI
  if [ -n "${QUERY_STRING:-}" ]; then
    require_origin || exit $?
  fi

  # bootstrap do token (sem exigir token prévio)
  if [ "$action" = "token_get" ]; then
    ensure_state
    tok="$(read_token 2>/dev/null || true)"
    if [ -z "${tok:-}" ]; then
      tok="$(gen_token)"
      printf '%s\n' "$tok" >"$AVP_TOKEN_FILE" 2>/dev/null || :
      chmod 600 "$AVP_TOKEN_FILE" 2>/dev/null || :
    fi
    data="$(printf '{"token":"%s"}' "$(jesc "$tok")")"
    json_reply 1 0 "token_get" "ok" "$data"
    exit 0
  fi

  require_token "$token" || exit $?

  POL="/jffs/scripts/avp-pol.sh"
  [ -x "$POL" ] || { err 10 "dispatch" "avp-pol.sh not found" '{}'; exit 10; }

  case "$action" in
    enable)
      "$POL" enable >/dev/null 2>&1 || { err 30 "enable" "failed" '{}'; exit 30; }
      ok "enable" "ok" '{}'
      ;;
    disable)
      "$POL" disable >/dev/null 2>&1 || { err 30 "disable" "failed" '{}'; exit 30; }
      ok "disable" "ok" '{}'
      ;;
    reload)
      "$POL" reload --async >/dev/null 2>&1 || { err 30 "reload" "failed" '{}'; exit 30; }
      ok "reload" "ok" '{}'
      ;;
    status)
      polj="$("$POL" status --json 2>/dev/null | tail -n 1)"
      [ -n "${polj:-}" ] || polj="{}"
      data="$(unwrap_pol_data "$polj")"
      json_reply 1 0 "status" "ok" "$data"
      ;;
    snapshot)
      polj="$("$POL" snapshot 2>/dev/null | tail -n 1)"
      [ -n "${polj:-}" ] || polj="{}"
      data="$(unwrap_pol_data "$polj")"
      json_reply 1 0 "snapshot" "ok" "$data"
      ;;
    profile_list) "$POL" profile list;;
    profile_get)  "$POL" profile get;;
    profile_set)
      [ -n "${profile:-}" ] || { err 22 "profile_set" "missing profile" '{}'; exit 22; }
      "$POL" profile set "$profile"
      ;;
    device_list) "$POL" device list;;
    device_add)
      [ -n "${label:-}" ] || { err 22 "device_add" "missing label" '{}'; exit 22; }
      [ -n "${ip:-}" ]    || { err 22 "device_add" "missing ip" '{}'; exit 22; }
      [ -n "${rule:-}" ]  || rule="balanced"
      "$POL" device add "$label" "$ip" "$rule"
      ;;
    device_del)
      [ -n "${label:-}" ] || { err 22 "device_del" "missing label" '{}'; exit 22; }
      "$POL" device del "$label"
      ;;
    device_set)
      [ -n "${label:-}" ] || { err 22 "device_set" "missing label" '{}'; exit 22; }
      [ -n "${ip:-}" ]    || { err 22 "device_set" "missing ip" '{}'; exit 22; }
      [ -n "${rule:-}" ]  || rule="balanced"
      "$POL" device set "$label" "$ip" "$rule"
      ;;
    *)
      err 2 "dispatch" "invalid action" \
        '{"allowed":["enable","disable","status","reload","snapshot","profile_list","profile_get","profile_set","device_list","device_add","device_del","device_set","token_get"]}'
      exit 2
      ;;
  esac
}

main "$@"
