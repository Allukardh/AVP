#!/bin/sh
# =============================================================
# AutoVPN Platform (AVP)
# Component : AVP-DHCP
# File      : avp-dhcp-tool.sh
# Role      : DHCP lease refresh helper (dnsmasq + optional Wi-Fi deauth)
# Version   : v1.0.2 (2026-02-20)
# Status    : stable
# =============================================================

SCRIPT_VER="v1.0.2"
export PATH="/jffs/scripts:/jffs/scripts/avp/bin:/opt/bin:/opt/sbin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH:-}"
hash -r 2>/dev/null || true
set -u

LEASES="/var/lib/misc/dnsmasq.leases"
DEAUTH_ALL="0"

usage() {
  cat <<'EOF2'
Usage:
  sh avp-dhcp-tool.sh [--deauth-all]

What it does:
  - Clear /var/lib/misc/dnsmasq.leases
  - Restart dnsmasq (DHCP/DNS)
  - Show BEFORE/AFTER lease counts
  - Show current leases after restart (will fill as clients renew)
  - If --deauth-all: deauth all Wi-Fi clients on wl0/wl1/wl2 (forces reconnect + DHCP renew)

Notes:
  - Wired devices may still need unplug/replug or DHCP renew on the device.
EOF2
}

log() { printf '%s\n' "$*"; }

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ "${1:-}" = "--deauth-all" ]; then
  DEAUTH_ALL="1"
elif [ -n "${1:-}" ]; then
  log "ERR: unknown argument: $1"
  usage
  exit 2
fi

if [ ! -f "$LEASES" ]; then
  log "ERR: leases file not found: $LEASES"
  exit 1
fi

log "=== DHCP Lease Refresh (dnsmasq) ==="
log "SCRIPT_VER=v1.0.2"
log "LEASES=$LEASES"
log "DEAUTH_ALL=$DEAUTH_ALL"
log

log "=== BEFORE: lease count ==="
wc -l "$LEASES" 2>/dev/null || true
log

: > "$LEASES" || {
  log "ERR: failed to clear leases: $LEASES"
  exit 1
}
log "OK: leases cleared"
log

log "=== Restarting dnsmasq ==="
service restart_dnsmasq || {
  log "ERR: service restart_dnsmasq failed"
  exit 1
}
log "OK: dnsmasq restarted"
log

if [ "$DEAUTH_ALL" = "1" ]; then
  log "=== Deauth all Wi-Fi clients (wl0/wl1/wl2) ==="
  for ifn in "$(nvram get wl0_ifname 2>/dev/null)" "$(nvram get wl1_ifname 2>/dev/null)" "$(nvram get wl2_ifname 2>/dev/null)"; do
    [ -n "$ifn" ] || continue
    wl -i "$ifn" assoclist 2>/dev/null | while IFS= read -r line; do
      mac="$(printf '%s' "$line" | awk '{print $2}')"
      [ -n "${mac:-}" ] || continue
      wl -i "$ifn" deauth "$mac" 2>/dev/null || true
    done
  done
  log "OK: deauth issued (clients should reconnect and renew DHCP)"
  log
fi

log "=== AFTER: lease count ==="
wc -l "$LEASES" 2>/dev/null || true
log

log "=== Current leases (may fill as clients renew) ==="
cat "$LEASES" 2>/dev/null || true
log

log "DONE."
exit 0
