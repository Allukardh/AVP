#!/bin/sh
# dhcp-lease-refresh.sh
#
# Purpose: Force DHCP clients to re-acquire reserved IPs on Asuswrt-Merlin without router reboot.
#
# Version: 1.0.1 (2026-02-06)
# SCRIPT_VER="1.0.1"
#
# CHANGELOG:
# - 1.0.1 (2026-02-06): remove leases backup (per user request); keep optional wifi deauth; keep before/after proof.
# - 1.0.0 (2026-02-06): initial release (clear leases, restart dnsmasq, optional wifi deauth, verify output)

set -u

LEASES="/var/lib/misc/dnsmasq.leases"
DEAUTH_ALL="0"

usage() {
  cat <<'EOF'
Usage:
  sh dhcp-lease-refresh.sh [--deauth-all]

What it does:
  - Clear /var/lib/misc/dnsmasq.leases
  - Restart dnsmasq (DHCP/DNS)
  - Show BEFORE/AFTER lease counts
  - Show current leases after restart (will fill as clients renew)
  - If --deauth-all: deauth all Wi-Fi clients on wl0/wl1/wl2 (forces reconnect + DHCP renew)

Notes:
  - Wired devices may still need unplug/replug or DHCP renew on the device.
EOF
}

log() { printf '%s\n' "$*"; }

# args
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

# sanity
if [ ! -f "$LEASES" ]; then
  log "ERR: leases file not found: $LEASES"
  exit 1
fi

log "=== DHCP Lease Refresh (dnsmasq) ==="
log "SCRIPT_VER=1.0.1"
log "LEASES=$LEASES"
log "DEAUTH_ALL=$DEAUTH_ALL"
log

# BEFORE
log "=== BEFORE: lease count ==="
wc -l "$LEASES" 2>/dev/null || true
log

# clear leases
: > "$LEASES" || {
  log "ERR: failed to clear leases: $LEASES"
  exit 1
}
log "OK: leases cleared"
log

# restart dnsmasq
log "=== Restarting dnsmasq ==="
service restart_dnsmasq || {
  log "ERR: service restart_dnsmasq failed"
  exit 1
}
log "OK: dnsmasq restarted"
log

# optional deauth all wifi clients
if [ "$DEAUTH_ALL" = "1" ]; then
  log "=== Deauth all Wi-Fi clients (wl0/wl1/wl2) ==="
  for ifn in "$(nvram get wl0_ifname 2>/dev/null)" "$(nvram get wl1_ifname 2>/dev/null)" "$(nvram get wl2_ifname 2>/dev/null)"; do
    [ -n "$ifn" ] || continue

    # assoclist output: "assoclist <MAC>"
    wl -i "$ifn" assoclist 2>/dev/null | while IFS= read -r line; do
      mac="$(printf '%s' "$line" | awk '{print $2}')"
      [ -n "${mac:-}" ] || continue
      wl -i "$ifn" deauth "$mac" 2>/dev/null || true
    done
  done
  log "OK: deauth issued (clients should reconnect and renew DHCP)"
  log
fi

# AFTER
log "=== AFTER: lease count ==="
wc -l "$LEASES" 2>/dev/null || true
log

log "=== Current leases (may fill as clients renew) ==="
cat "$LEASES" 2>/dev/null || true
log

log "DONE."
exit 0
