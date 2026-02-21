#!/bin/sh
# =============================================================
# AutoVPN Platform (AVP)
# Component : AVP-DIAG
# File      : avp-diag.sh
# Role      : Diagnostics (read-only)
# Version   : v1.2.6 (2026-02-20)
# Status    : stable
# =============================================================

SCRIPT_VER="v1.2.6"
export PATH="/jffs/scripts:/jffs/scripts/avp/bin:/opt/bin:/opt/sbin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH:-}"
hash -r 2>/dev/null || true
set -u

ts() { date '+%Y-%m-%d %H:%M:%S'; }
exists() { command -v "$1" >/dev/null 2>&1; }

# Canonical AVP runtime (read-only usage)
CANON_BASE="/jffs/scripts/avp"

# Policy inventory (single source of truth)
POLICY_DIR="/jffs/scripts/avp/policy"
DEVICES_CONF="$POLICY_DIR/devices.conf"
DEVICES_LIST=""

load_devices_from_conf() {
  [ -f "$DEVICES_CONF" ] || return 1
  DEVICES_LIST=""
  while IFS= read -r raw || [ -n "$raw" ]; do
    line="$(printf "%s" "$raw" | tr -d "\r" | sed "s/[[:space:]]*$//")"
    case "$line" in ""|"#"*) continue ;; esac
    set -- $line
    [ $# -ge 3 ] || continue
    L="$1"; I="$2"; P="$3"
    DEVICES_LIST="${DEVICES_LIST}${L}|${I}|${P}\n"
  done < "$DEVICES_CONF"
  [ -n "$DEVICES_LIST" ] || return 1
  return 0
}

require_devices_conf() {
  load_devices_from_conf || {
    echo "ERR: devices.conf obrigatório ausente/vazio/inválido: $DEVICES_CONF"
    return 1
  }
}

AVP_LOGDIR="${AVP_LOGDIR:-/tmp/avp_logs}"
PRIMARY_LOGDIR="$AVP_LOGDIR"
PRIMARY_STATEDIR="/jffs/scripts/avp/state"

# Defaults (safe)
WGS="wgc1 wgc2 wgc3 wgc4 wgc5"
TARGETS="1.1.1.1 8.8.8.8"
DNS_TARGETS="one.one.one.one dns.google"
PINGCOUNT=2
PINGW=2
HANDSHAKE_MAX_AGE=180

usage() {
  cat <<'U'
Usage: avp-diag.sh [--raw] [--synth] [--logs] [--cur] [--tldr] [--all] [--live]

  --raw    : checks raw (ping/dns/wg)
  --synth  : score/ordering summary for wg ifaces
  --logs   : tail status-ish lines from latest AVP logs
  --cur    : show ip rule/route tables for known devices (read-only)
  --tldr   : short summary
  --all    : raw + synth + logs + cur + tldr
  --live   : repeat --all every 5s (Ctrl+C to stop)
U
}

iface_up() {
  iface="$1"
  ip link show "$iface" 2>/dev/null | grep -q "UP" || return 1
  return 0
}

wan_ping_ok() {
  ok=0
  for t in $TARGETS; do
    if ping -c "$PINGCOUNT" -W "$PINGW" "$t" >/dev/null 2>&1; then
      ok=$((ok+1))
    fi
  done
  echo "$ok"
}

dns_check() {
  # Se nslookup não existe, não é FAIL; é SKIP.
  exists nslookup || { echo "SKIP"; return 0; }

  ok=0
  for d in $DNS_TARGETS; do
    if nslookup "$d" >/dev/null 2>&1; then
      ok=$((ok+1))
    fi
  done

  if [ "$ok" -ge 1 ]; then
    echo "OK"
  else
    echo "FAIL"
  fi
}

wg_handshake_age() {
  iface="$1"
  exists wg || return 2

  # BusyBox wg: latest-handshakes -> "<peer_pubkey> <epoch>"
  now="$(date +%s)"
  last_hs="$(wg show "$iface" latest-handshakes 2>/dev/null | awk '{print $2}' | sort -n | tail -n 1)"

  # Sem peers/sem handshake válido -> unknown
  [ -z "$last_hs" ] && return 3
  [ "$last_hs" -eq 0 ] 2>/dev/null && return 3

  echo $((now - last_hs))
  return 0
}

score_iface() {
  iface="$1"

  # Score rule: menor = melhor.
  # UP + age pequeno => bom
  # UP + UNKNOWN => ruim, mas não marca DEGRADED automaticamente
  # DOWN => pior
  if iface_up "$iface"; then
    age="$(wg_handshake_age "$iface")"
    rc=$?
    case "$rc" in
      0) : ;;
      2) age="" ;;
      3) age="" ;;
      *) age="" ;;
    esac

    if [ -z "$age" ]; then
      score=9999
      echo "$iface|UP|UNKNOWN|$score"
      return 0
    fi

    score="$age"
    echo "$iface|UP|$age|$score"
    return 0
  else
    echo "$iface|DOWN|UNKNOWN|99999"
    return 0
  fi
}

sorted_ifaces_by_score() {
  for i in $WGS; do
    score_iface "$i"
  done | sort -t'|' -k4,4n
}

best_iface_by_score() {
  sorted_ifaces_by_score | head -n 1
}

pick_latest_log() {
  pat="${1:-avp_.*\.log}"

  # prefer canonical
  if [ -d "$PRIMARY_LOGDIR" ]; then
    f="$(ls -1 "$PRIMARY_LOGDIR" 2>/dev/null | grep -E "$pat" | sort | tail -n 1)"
    [ -n "$f" ] && { echo "$PRIMARY_LOGDIR/$f"; return 0; }
  fi

  # fallback (legacy/other)
  for d in /jffs/scripts/avp/logs /jffs/scripts/avp/policy/logs /tmp; do
    [ -d "$d" ] || continue
    f="$(ls -1 "$d" 2>/dev/null | grep -E "$pat" | sort | tail -n 1)"
    [ -n "$f" ] && { echo "$d/$f"; return 0; }
  done

  echo ""
  return 0
}

show_tldr() {
  wan_ok="$(wan_ping_ok)"
  dns="$(dns_check)"

  best="$(best_iface_by_score)"
  b_if="$(echo "$best" | cut -d'|' -f1)"
  b_st="$(echo "$best" | cut -d'|' -f2)"
  b_age="$(echo "$best" | cut -d'|' -f3)"
  b_score="$(echo "$best" | cut -d'|' -f4)"

  echo "TL;DR:"
  echo "  WAN: $( [ "$wan_ok" -ge 1 ] && echo "OK ($wan_ok/2)" || echo "FAIL ($wan_ok/2)" )"
  case "$dns" in
    OK) echo "  DNS: OK" ;;
    FAIL) echo "  DNS: FAIL" ;;
    SKIP) echo "  DNS: SKIP (nslookup_missing)" ;;
    *) echo "  DNS: UNKNOWN" ;;
  esac
  echo "  WG: best=$b_if st=$b_st age=$b_age score=$b_score"
}

show_raw() {
  echo "RAW:"
  echo "  time: $(ts)"
  echo "  wan targets: $TARGETS"
  for t in $TARGETS; do
    if ping -c "$PINGCOUNT" -W "$PINGW" "$t" >/dev/null 2>&1; then
      echo "  ping $t: OK"
    else
      echo "  ping $t: FAIL"
    fi
  done

  echo "  dns targets: $DNS_TARGETS"
  if exists nslookup; then
    for d in $DNS_TARGETS; do
      if nslookup "$d" >/dev/null 2>&1; then
        echo "  nslookup $d: OK"
      else
        echo "  nslookup $d: FAIL"
      fi
    done
  else
    echo "  nslookup: missing (skip dns checks)"
  fi

  echo "  wg ifaces: $WGS"
  for i in $WGS; do
    if iface_up "$i"; then
      age="$(wg_handshake_age "$i")"
      rc=$?
      case "$rc" in
        0) echo "  $i: UP handshake_age=${age}s" ;;
        2) echo "  $i: UP handshake_age=? (wg_missing)" ;;
        3) echo "  $i: UP handshake_age=? (no_handshake)" ;;
        *) echo "  $i: UP handshake_age=? (unknown)" ;;
      esac
    else
      echo "  $i: DOWN"
    fi
  done
}

show_synth() {
  echo "SYNTH:"
  sorted_ifaces_by_score | while IFS= read -r line || [ -n "$line" ]; do
    iface="$(echo "$line" | cut -d'|' -f1)"
    st="$(echo "$line" | cut -d'|' -f2)"
    age="$(echo "$line" | cut -d'|' -f3)"
    score="$(echo "$line" | cut -d'|' -f4)"

    note=""
    if [ "$st" = "UP" ] && [ "$age" != "UNKNOWN" ]; then
      if [ "$age" -gt "$HANDSHAKE_MAX_AGE" ] 2>/dev/null; then
        note="DEGRADED"
      fi
    fi
    printf "  %-4s  %-4s  age=%-6s  score=%-5s  %s\n" "$iface" "$st" "$age" "$score" "$note"
  done
}

show_logs() {
  echo "LOGS:"
  f="$(pick_latest_log 'avp_.*\.log')"
  if [ -z "$f" ]; then
    echo "  latest: (none)"
    return 0
  fi
  echo "  latest: $f"
  tail -n 80 "$f" 2>/dev/null | \
    grep -E '^(\[[A-Z-]+\]|[0-9]{4}-[0-9]{2}-[0-9]{2} ).*(STATUS|SUMMARY|ACTION|ERR|WARN|TL;DR|DONE)' | \
    tail -n 25 || :
}

show_cur() {
  require_devices_conf || return 1
  printf "%b" "$DEVICES_LIST" | while IFS="|" read -r L I P; do
    [ -z "${L:-}" ] && continue
    echo "CUR: $L ($I, pref=$P)"
    ip rule show 2>/dev/null | grep -E "pref $P|from $I" || echo "  rule: (none)"
  done
}

sep() { echo "------------------------------------------------------------"; }

DO_RAW=0
DO_SYNTH=0
DO_LOGS=0
DO_CUR=0
DO_TLDR=0
DO_ALL=0
DO_LIVE=0

[ $# -eq 0 ] && { usage; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --raw) DO_RAW=1 ;;
    --synth) DO_SYNTH=1 ;;
    --logs) DO_LOGS=1 ;;
    --cur) DO_CUR=1 ;;
    --tldr) DO_TLDR=1 ;;
    --all) DO_ALL=1 ;;
    --live) DO_LIVE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
  shift
done

run_all() {
  sep
  show_tldr
  sep
  show_raw
  sep
  show_synth
  sep
  show_logs
  sep
  show_cur
  echo ""
}

if [ "$DO_ALL" -eq 1 ]; then
  if [ "$DO_LIVE" -eq 1 ]; then
    n=0
    while :; do
      n=$((n+1))
      echo "$(ts) [DIAG] cycle=$n (every 5s)  script=AVP-DIAG ${SCRIPT_VER}"
      run_all
      sleep 5
    done
  else
    run_all
  fi
  exit 0
fi

# run selected
[ "$DO_TLDR" -eq 1 ] && { sep; show_tldr; }
[ "$DO_RAW" -eq 1 ] && { sep; show_raw; }
[ "$DO_SYNTH" -eq 1 ] && { sep; show_synth; }
[ "$DO_LOGS" -eq 1 ] && { sep; show_logs; }
[ "$DO_CUR" -eq 1 ] && { sep; show_cur; }
echo ""
