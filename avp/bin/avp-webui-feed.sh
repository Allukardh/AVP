#!/bin/sh
# =============================================================
# AutoVPN Platform (AVP)
# Component : AVP-WEBUI Feeder
# File      : avp-webui-feed.sh
# Role      : WebUI JSON status feed (exporter)
# Version   : v1.2.17 (2026-02-20)
# Status    : stable
# =============================================================

SCRIPT_VER="v1.2.17"
export PATH="/jffs/scripts:/jffs/scripts/avp/bin:/opt/bin:/opt/sbin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH:-}"
hash -r 2>/dev/null || true
set -u

CLI="/jffs/scripts/avp/bin/avp-cli.sh"
# CLI fallback (tree reorg / wrappers)
if [ ! -x "${CLI:-}" ]; then
  if [ -x "/jffs/scripts/avp/bin/avp-cli.sh" ]; then
    CLI="/jffs/scripts/avp/bin/avp-cli.sh"
  elif [ -x "/jffs/scripts/avp/bin/avp-cli" ]; then
    CLI="/jffs/scripts/avp/bin/avp-cli"
  fi
fi
OUT="/jffs/scripts/avp/www/avp-status.json"

PID="/tmp/avp_webui_feed.pid"
LOCK="/tmp/avp_webui_feed.lock"   # lockdir atômico (mkdir)

# logs (preferência: jffs; fallback: tmp)
AVP_LOGDIR="${AVP_LOGDIR:-/tmp/avp_logs}"
AVP_LIB="/jffs/scripts/avp/lib/avp-lib.sh"
[ -f "$AVP_LIB" ] && . "$AVP_LIB"
type has_fn >/dev/null 2>&1 || has_fn(){ type "$1" >/dev/null 2>&1; }
has_fn avp_init_layout && avp_init_layout >/dev/null 2>&1 || :

LOGDIR="$AVP_LOGDIR"
mkdir -p "$LOGDIR" 2>/dev/null || { LOGDIR="/tmp/avp_logs"; mkdir -p "$LOGDIR" 2>/dev/null || :; }

LOGW="${LOGDIR}/avp_webui_warn.log"
LOGS="${LOGDIR}/avp_webui_feed_state.log"

BASE_SLEEP=5
MAX_BACKOFF=60
ROTATE_MAX=65536  # 64 KiB

ts() { date '+%Y-%m-%d %H:%M:%S'; }

rotate_if_big() {
  _f="$1"
  [ -f "$_f" ] || return 0
  _sz="$(wc -c <"$_f" 2>/dev/null || echo 0)"
  [ "$_sz" -ge "$ROTATE_MAX" ] || return 0
  mv -f "$_f" "${_f}.1" 2>/dev/null || true
}

log_warn() { rotate_if_big "$LOGW"; echo "$(ts) [WARN] $*" >>"$LOGW"; }
log_state() { rotate_if_big "$LOGS"; echo "$(ts) [FEED] $*" >>"$LOGS"; }

json_escape_min() { printf "%s" "$1" | tr -d '\r' | sed 's/\\/\\\\/g; s/"/\\"/g'; }

json_err() {
  _code="$1"
  _level="${2:-ERR}"
  _hint="${3:-}"
  _where="${4:-FEED}"

  _codej="$(json_escape_min "$_code")"
  _lvl="$(json_escape_min "$_level")"
  _wh="$(json_escape_min "$_where")"
  _hj="$(json_escape_min "$_hint")"

  echo "{\"enabled\":0,\"profile\":\"n/a\",\"devices\":[],\"errors\":[\"${_codej}\"],\"err\":{\"level\":\"${_lvl}\",\"code\":\"${_codej}\",\"where\":\"${_wh}\",\"hint\":\"${_hj}\"}}"
}

write_atomic() {
  tmp="${OUT}.tmp"
  cat >"$tmp" && mv -f "$tmp" "$OUT"
}

purge_tmp_orphans_feed() {
  for f in /tmp/avp_webui_out.*; do
    [ -e "$f" ] || continue
    pid="${f##*.}"
    case "$pid" in *[!0-9]*|"") continue ;; esac
    kill -0 "$pid" 2>/dev/null && continue
    rm -f "$f" 2>/dev/null || :
  done
}

acquire_lock_or_exit() {
  if mkdir "$LOCK" 2>/dev/null; then
    return 0
  fi

  if [ -f "$LOCK/pid" ]; then
    p="$(cat "$LOCK/pid" 2>/dev/null || echo "")"
    if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then
      echo "running pid=$p"
      exit 0
    fi
  fi

  rm -rf "$LOCK" 2>/dev/null || true
  mkdir "$LOCK" 2>/dev/null || { echo "busy"; exit 1; }
}

release_lock() { rm -rf "$LOCK" 2>/dev/null || true; }

feed_cleanup() {
  # cleanup via trap no loop (EXIT/INT/TERM)
  # remove PID/LOCK somente se este processo for o dono
  if [ -f "$PID" ] && [ "$(cat "$PID" 2>/dev/null || echo "")" = "$$" ]; then
    rm -f "$PID" 2>/dev/null || true
  fi
  if [ -f "$LOCK/pid" ] && [ "$(cat "$LOCK/pid" 2>/dev/null || echo "")" = "$$" ]; then
    rm -rf "$LOCK" 2>/dev/null || true
  fi
  return 0
}
run_loop() {
  sleep_s="$BASE_SLEEP"

  while :; do
    tmp_out="/tmp/avp_webui_out.$$"

    if [ -x "$CLI" ]; then
      if "$CLI" status >"$tmp_out" 2>>"$LOGW"; then
        FEED_EPOCH="$(date +%s)"; sed "s/}$/,\"feed_epoch\":${FEED_EPOCH}}/" "$tmp_out" | write_atomic
        log_state "ok (sleep=${sleep_s}s)"
        sleep_s="$BASE_SLEEP"
      else
        log_warn "cli status returned non-zero"
        json_err "cli_failed" "ERR" "cli status falhou; veja ${LOGW}" "FEED" | write_atomic
        sleep_s=$((sleep_s * 2))
        [ "$sleep_s" -gt "$MAX_BACKOFF" ] && sleep_s="$MAX_BACKOFF"
      fi
    else
      log_warn "cli missing or not executable: $CLI"
      json_err "cli_missing_or_not_executable" "ERR" "verifique permissões/arquivo em ${CLI}" "FEED" | write_atomic
      sleep_s=$((sleep_s * 2))
      [ "$sleep_s" -gt "$MAX_BACKOFF" ] && sleep_s="$MAX_BACKOFF"
    fi

    rm -f "$tmp_out" 2>/dev/null || true
    sleep "$sleep_s"
  done
}

start() {
  # já rodando?
  if [ -f "$PID" ]; then
    p="$(cat "$PID" 2>/dev/null || echo "")"
    if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then
      echo "running pid=$p"
      exit 0
    fi
  fi

  purge_tmp_orphans_feed
  acquire_lock_or_exit

  # spawn HUP-safe
  ( trap '' HUP; trap "feed_cleanup" EXIT INT TERM; run_loop ) </dev/null >/dev/null 2>&1 &
  loop_pid=$!

  echo "$loop_pid" >"$PID" 2>/dev/null || true
  echo "$loop_pid" >"$LOCK/pid" 2>/dev/null || true

  sleep 1
  if ! kill -0 "$loop_pid" 2>/dev/null; then
    log_warn "start: loop died immediately (pid=$loop_pid)"
    json_err "feed_loop_died" "ERR" "loop morreu ao iniciar; veja ${LOGW}" "FEED" | write_atomic
    rm -f "$PID" 2>/dev/null || true
    release_lock
    echo "stopped"
    exit 1
  fi

  echo "started pid=$loop_pid"
  if has_fn log_event; then
    log_event "FEED" "start" 0 "pid=$loop_pid"
  fi

}

stop() {
  p=""
  if [ -f "$PID" ]; then p="$(cat "$PID" 2>/dev/null || echo "")"; fi
  [ -n "$p" ] && kill "$p" 2>/dev/null || true
  rm -f "$PID" 2>/dev/null || true
  release_lock
  echo "stopped"
  if has_fn log_event; then
    log_event "FEED" "stop" 0 "ok=1"
  fi

}

status() {
  if [ -f "$PID" ]; then
    p="$(cat "$PID" 2>/dev/null || echo "")"
    if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then
      echo "running pid=$p"
      exit 0
    fi
  fi
  if [ -f "$LOCK/pid" ]; then
    p="$(cat "$LOCK/pid" 2>/dev/null || echo "")"
    if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then
      echo "running pid=$p"
      exit 0
    fi
  fi
  echo "stopped"
  if has_fn log_event; then
    log_event "FEED" "stop" 0 "ok=1"
  fi

}

case "${1:-}" in
  start) start ;;
  stop) stop ;;
  status) status ;;
  *) echo "Usage: $0 {start|stop|status}"; exit 1 ;;
esac
