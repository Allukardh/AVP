#!/bin/sh
# =============================================================
# AutoVPN Platform (AVP)
# Component : AVP-POL-CRON
# File      : avp-pol-cron.sh
# Role      : Cron wrapper (timestamp + rc) for AVP-POL run
# Version   : v1.0.23 (2026-02-20)
# Status    : stable
# =============================================================

SCRIPT_VER="v1.0.23"
set -u

SELF_VER="$SCRIPT_VER"
export PATH="/jffs/scripts:/jffs/scripts/avp/bin:/opt/bin:/opt/sbin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH:-}"
hash -r 2>/dev/null || true

AVP_LIB="/jffs/scripts/avp/lib/avp-lib.sh"
[ -f "$AVP_LIB" ] && . "$AVP_LIB"
type has_fn >/dev/null 2>&1 || has_fn(){ type "$1" >/dev/null 2>&1; }
has_fn avp_init_layout && avp_init_layout >/dev/null 2>&1 || :

emit_error(){
  _rc="$1"
  _msg="$2"
  if { type has_fn >/dev/null 2>&1 && has_fn log_error; } || type log_error >/dev/null 2>&1; then
    log_error "AVP-POL-CRON" "$_msg" "$_rc" "stage=emit_error"
    return 0
  fi

  _tsn="$(date +%s)"
  _errd="/jffs/scripts/avp/logs"
  _errf="$_errd/avp_errors.log"
  [ -d "$_errd" ] || mkdir -p "$_errd" 2>/dev/null || :
  _line="{\"ts\":\"$_tsn\",\"comp\":\"AVP-POL-CRON\",\"msg\":\"$_msg\",\"rc\":$_rc}"
  if ! echo "$_line" >>"$_errf" 2>/dev/null; then
    echo "$_line" >>"/tmp/avp_errors.log" 2>/dev/null || :
  fi
}

ts(){ date "+%F %T"; }
ROTATE_MAX=262144  # 256 KiB

rotate_if_big() {
  _f="$1"
  [ -f "$_f" ] || return 0
  _sz="$(wc -c <"$_f" 2>/dev/null || echo 0)"
  [ "$_sz" -ge "$ROTATE_MAX" ] || return 0
  mv -f "$_f" "${_f}.1" 2>/dev/null || true
}

# logdir: padrão em RAM para evitar escrita persistente no jffs (override: AVP_LOGDIR)
LOGDIR="${AVP_LOGDIR:-/tmp/avp_logs}"
mkdir -p "$LOGDIR" 2>/dev/null || { LOGDIR="/tmp/avp_logs"; mkdir -p "$LOGDIR" 2>/dev/null || :; }
LOG="$LOGDIR/avp-pol-cron.log"
rotate_if_big "$LOG"
echo "$(ts) [CRON] AVP-POL-CRON $SELF_VER START pid=$$" >>"$LOG"
POL="/jffs/scripts/avp/bin/avp-pol.sh"
if [ ! -f "$POL" ]; then
  echo "$(ts) [CRON] AVP-POL-CRON $SELF_VER ERR missing $POL" >>"$LOG"
  rc=127
else
  /bin/sh "$POL" run >>"$LOG" 2>&1
  rc=$?
  # rc=99 (lock_active) => SKIP (nao é falha; evita ruido no cron)
  if [ "${rc:-0}" -eq 99 ] 2>/dev/null; then
    echo "$(ts) [CRON] AVP-POL-CRON $SELF_VER SKIP rc=99 (lock_active)" >>"$LOG"
    rc=0
  fi
fi
echo "$(ts) [CRON] AVP-POL-CRON $SELF_VER END rc=$rc" >>"$LOG"
if [ "$rc" -ne 0 ]; then
  if has_fn log_error; then
    log_error "CRON" "avp-pol.sh failed" "$rc" "log=$LOG"
  fi

  {
    echo "$(ts) [CRON] failure_dump BEGIN rc=$rc"
    /bin/sh /jffs/scripts/avp/bin/avp-pol.sh status
    echo "---- LAST LOG (head 80) ----"
    /bin/sh /jffs/scripts/avp/bin/avp-pol.sh run --show-last | head -n 80
    echo "$(ts) [CRON] failure_dump END rc=$rc"
  } >>"$LOG" 2>&1
fi
if [ "$rc" -ne 0 ]; then
  emit_error "$rc" "policy_apply_failed"
fi
exit "$rc"
