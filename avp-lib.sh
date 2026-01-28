#!/bin/sh
# =============================================================
# AutoVPN Platform (AVP)
# Component : AVP-LIB
# File      : avp-lib.sh
# Role      : Common library (Flash-Safe v1 logs/state + helpers)
# Version   : v1.0.8 (2026-01-27)
# Status    : stable
# =============================================================
#
# CHANGELOG
# - v1.0.8 (2026-01-27)
#   * CHORE: hygiene (trim trailing WS; mark legacy example comment)
# - v1.0.7 (2026-01-27)
#   * CHORE: hygiene (whitespace/blank lines; no logic change)
# - v1.0.6 (2026-01-26)
#   * VERSION: bump patch (pos harden canônico)
# - v1.0.5 (2026-01-26)
#   * ADD: state_write_file(): writer canônico (atomic + umask 077 + chmod 0600)
# - v1.0.4 (2026-01-26)
#   * HARDEN: state_set() garante chmod 0600 no state final (evita 0666 por umask)
# - v1.0.3 (2026-01-18)
#   * POLISH: padroniza SCRIPT_VER + set -u (ordem oficial) e remove linhas em branco desnecessarias
# - v1.0.2 (2026-01-08)
#   * STD: padroniza header (File/Role/Status) + organiza CHANGELOG (sem linhas em branco)
# - v1.0.1 (2026-01-08)
#   * ADD: helper has_fn() (type-based) para checar funcoes no sh (guards/Flash-Safe)
# - v1.0.0 (2026-01-08)
#   * ADD: Flash-Safe v1 helpers: rotate_if_big, log_event/error/debug, state_set/get (rate-limited)
# =============================================================

SCRIPT_VER="v1.0.8"
export PATH="/jffs/scripts:/opt/bin:/opt/sbin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH:-}"
hash -r 2>/dev/null || true
set -u

avp_now()   { date '+%Y-%m-%d %H:%M:%S'; }
avp_epoch() { date +%s; }

has_fn(){ type "$1" >/dev/null 2>&1; }
# Layout (Flash-Safe v1)
AVP_FLASH_LOGDIR="${AVP_FLASH_LOGDIR:-/jffs/scripts/logs}"          # Classe A (flash)
AVP_TMP_LOGDIR="${AVP_LOGDIR:-${AVP_TMP_LOGDIR:-/tmp/avp_logs}}"    # Classe B (tmpfs)
AVP_STATEDIR="${AVP_STATEDIR:-/jffs/scripts/avp/state}"             # Classe C (flash, rate-limited)

AVP_STATE_FILE="${AVP_STATE_FILE:-$AVP_STATEDIR/avp_state.kv}"

AVP_EVENT_LOG="${AVP_EVENT_LOG:-$AVP_FLASH_LOGDIR/avp_events.log}"
AVP_ERROR_LOG="${AVP_ERROR_LOG:-$AVP_FLASH_LOGDIR/avp_errors.log}"
AVP_DEBUG_LOG="${AVP_DEBUG_LOG:-$AVP_TMP_LOGDIR/avp_debug.log}"

# Defaults de rotação (KB)
AVP_FLASH_LOG_MAX_KB="${AVP_FLASH_LOG_MAX_KB:-256}"
AVP_TMP_LOG_MAX_KB="${AVP_TMP_LOG_MAX_KB:-512}"

avp_init_layout() {
  mkdir -p "$AVP_FLASH_LOGDIR" "$AVP_TMP_LOGDIR" "$AVP_STATEDIR" 2>/dev/null || :
}

rotate_if_big() {
  f="$1"
  max_kb="${2:-128}"
  [ -n "$f" ] || return 0
  [ -f "$f" ] || return 0

  sz="$(wc -c < "$f" 2>/dev/null || echo 0)"
  max=$((max_kb * 1024))
  [ "$sz" -le "$max" ] && return 0

  mv -f "$f" "$f.1" 2>/dev/null || return 0
  : > "$f" 2>/dev/null || :
}

json_escape() {
  # escape mínimo (\" e \\ + controles básicos)
  printf '%s' "$*" | awk 'BEGIN{ORS=""}{
    gsub(/\\/,"\\\\"); gsub(/"/,"\\\"");
    gsub(/\r/,"\\r"); gsub(/\t/,"\\t"); gsub(/\n/,"\\n");
    print
  }'
}

_avp_log_line() {
  file="$1"; lvl="$2"; comp="$3"; rc="${4:-0}"; msg="$5"; meta="$6"
  avp_init_layout >/dev/null 2>&1 || :

  case "$file" in
    "$AVP_EVENT_LOG"|"$AVP_ERROR_LOG")
      rotate_if_big "$file" "$AVP_FLASH_LOG_MAX_KB"
      ;;
    *)
      rotate_if_big "$file" "$AVP_TMP_LOG_MAX_KB"
      ;;
  esac

  ts="$(avp_now)"
  jts="$(json_escape "$ts")"
  jlvl="$(json_escape "$lvl")"
  jcomp="$(json_escape "$comp")"
  jmsg="$(json_escape "$msg")"
  jmeta="$(json_escape "$meta")"

  printf '{"ts":"%s","lvl":"%s","comp":"%s","rc":%s,"msg":"%s","meta":"%s"}\n' \
    "$jts" "$jlvl" "$jcomp" "$rc" "$jmsg" "$jmeta" >> "$file" 2>/dev/null || :
}

# Classe A (flash): eventos e erros (1 linha por ocorrência importante)
log_event() {
  comp="$1"; shift
  msg="$1"; shift
  rc="${1:-0}"; shift || :
  meta="$*"
  _avp_log_line "$AVP_EVENT_LOG" "EVENT" "$comp" "$rc" "$msg" "$meta"
}

log_error() {
  comp="$1"; shift
  msg="$1"; shift
  rc="${1:-1}"; shift || :
  meta="$*"
  _avp_log_line "$AVP_ERROR_LOG" "ERROR" "$comp" "$rc" "$msg" "$meta"
}

# Classe B (tmp): debug verboso (opcional)
log_debug() {
  comp="$1"; shift
  msg="$1"; shift
  meta="$*"
  _avp_log_line "$AVP_DEBUG_LOG" "DEBUG" "$comp" 0 "$msg" "$meta"
}

# Classe C (flash): estado (rate-limited)
state_get() {
  k="$1"
  [ -f "$AVP_STATE_FILE" ] || return 1
  awk -F= -v k="$k" '$1==k{print substr($0,index($0,"=")+1); found=1} END{exit(found?0:1)}' \
    "$AVP_STATE_FILE" 2>/dev/null
}

# Writer canônico de arquivos state (não rate-limited)
# - Atomic: grava em tmp no mesmo FS e renomeia (mv -f)
# - Seguro: força umask 077 no tmp e finaliza com chmod 0600 (evita 0666/0777 por umask permissivo)
# Uso:
#   state_write_file "/caminho/arquivo.state" "payload"
#   printf "payload\\n" | state_write_file "/caminho/arquivo.state"
state_write_file() {
  dest="$1"
  [ -n "${dest:-}" ] || return 1

  ddir="$(dirname "$dest" 2>/dev/null)"
  [ -n "${ddir:-}" ] && [ -d "$ddir" ] || mkdir -p "$ddir" 2>/dev/null || :

  tmp="${dest}.tmp.$$"

  if [ "$#" -ge 2 ]; then
    ( umask 077; printf "%s" "$2" >"$tmp" ) 2>/dev/null || { rm -f "$tmp" 2>/dev/null; return 1; }
  else
    ( umask 077; cat >"$tmp" ) 2>/dev/null || { rm -f "$tmp" 2>/dev/null; return 1; }
  fi

  mv -f "$tmp" "$dest" 2>/dev/null || { rm -f "$tmp" 2>/dev/null; return 1; }
  chmod 0600 "$dest" 2>/dev/null || :
  return 0
}

state_set() {
  k="$1"; v="$2"; min="${3:-60}"
  [ -n "$k" ] || return 1

  avp_init_layout >/dev/null 2>&1 || :

  cur="$(state_get "$k" 2>/dev/null || echo "")"
  [ "$cur" = "$v" ] && return 0

  now="$(avp_epoch)"
  lwf="/tmp/avp_state.lastwrite"
  last=0
  [ -f "$lwf" ] && last="$(cat "$lwf" 2>/dev/null || echo 0)"
  diff=$((now - last))

  # rate-limit de escrita na flash
  [ "$diff" -lt "$min" ] && return 0

  tmp="/tmp/avp_state.kv.$$"
  if [ -f "$AVP_STATE_FILE" ]; then
    awk -F= -v k="$k" -v v="$v" '
      BEGIN{found=0}
      $1==k {print k"="v; found=1; next}
      {print}
      END{if(!found) print k"="v}
    ' "$AVP_STATE_FILE" > "$tmp" 2>/dev/null || return 1
  else
    printf '%s=%s\n' "$k" "$v" > "$tmp" 2>/dev/null || return 1
  fi

  mv -f "$tmp" "$AVP_STATE_FILE" 2>/dev/null || { rm -f "$tmp" 2>/dev/null || :; return 1; }
  chmod 0600 "$AVP_STATE_FILE" 2>/dev/null || true
  echo "$now" > "$lwf" 2>/dev/null || :
  return 0
}
