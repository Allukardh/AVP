#!/bin/sh
# =============================================================
# AutoVPN Platform (AVP)
# Component : AVP-WEBUI Installer/Orchestrator
# File      : avp-webui.sh
# Role      : WebUI installer/orchestrator
# Version   : v1.0.11 (2026-02-10)
# Status    : stable
# =============================================================
#
# CHANGELOG
# - v1.0.11 (2026-02-10)
#   * FIX: install: evita falha 'cp same file' detectando SRC/DST por inode (BusyBox-safe) e pulando copy
# - v1.0.10 (2026-01-26)
#   * VERSION: bump patch (pos harden canônico)
# - v1.0.9 (2026-01-18)
#   * POLISH: padroniza SCRIPT_VER + set -u (ordem oficial) e remove linhas em branco desnecessarias
# - v1.0.8 (2026-01-08)
#   * CHG: warn/feed logs agora em /tmp/avp_logs (opt AVP_LOGDIR) — evita escrita no jffs
# - v1.0.7 (2026-01-05)
#   * CHORE: padroniza header + changelog (C1.5)
# - v1.0.6 (2026-01-04)
#   * FIX: install não falha quando avp.asp source == destination (cp same file vira no-op OK)
# - v1.0.5 (2026-01-04)
#   * CHG: avp-webui.sh vira somente installer/orquestrador (remove templates embutidos de asp/feeder e runtime legado)
#   * SAFETY: install/uninstall não sobrescrevem feeder nem geram avp.asp; usam arquivos canônicos e chamam feeder real
#   * ADD: validações explícitas (fonte do avp.asp, feeder executável) + mensagens de erro claras
# - v1.0.4 (2025-12-31)
#   * ADD: Open logs (Feed Summary/State/Warn + AVP Last (POL))
#   * ADD: Modos LIVE com dica "Ctrl+C pra sair"
# - v1.0.3 (2025-12-30)
#   * FIX: Evita CGI e appGet (incompatibilidades/whitelist/token em alguns 3006)
#   * ADD: Endpoint estático /user/avp-status.json (arquivo)
#   * ADD: Daemon feeder avp-webui-feed.sh (atualiza JSON a cada 5s)
# =============================================================

SCRIPT_VER="v1.0.11"
export PATH="/jffs/scripts:/jffs/scripts/avp/bin:/opt/bin:/opt/sbin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH:-}"
hash -r 2>/dev/null || true
set -u

ADDON="avp"
ADDON_DIR="/jffs/addons/${ADDON}"
WWW_DIR="${ADDON_DIR}/www"

# web paths exposed by httpd
ASP_DST="/www/user/avp.asp"
JSON_DST="/www/user/avp-status.json"

# canonical components
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
CLI="/jffs/scripts/avp/bin/avp-cli.sh"
FEED="/jffs/scripts/avp/bin/avp-webui-feed.sh"

ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "$(ts) [AVP-WEBUI] $*"; }
die() { log "[ERR] $*"; exit 1; }

restart_httpd() {
  if pidof httpd >/dev/null 2>&1; then
    log "Restarting httpd..."
    service restart_httpd >/dev/null 2>&1 || killall -HUP httpd >/dev/null 2>&1 || true
  fi
}

# Find canonical avp.asp source (single source of truth; no template embedded here)
find_asp_src() {
  # Priority:
  # 1) sibling path (repo layout): /jffs/scripts/avp/www/avp.asp
  # 2) same dir:                  <script_dir>/avp/www/avp.asp
  # 3) already installed addon:    /jffs/addons/avp/www/avp.asp
  # 4) fallback: current /www/user/avp.asp (if it exists and is a regular file)
  for p in \
    "/jffs/scripts/avp/www/avp.asp" \
    "${SCRIPT_DIR}/avp/www/avp.asp" \
    "${WWW_DIR}/avp.asp" \
    "${ASP_DST}"
  do
    if [ -f "$p" ]; then
      echo "$p"
      return 0
    fi
  done
  return 1
}

link_www() {
  mkdir -p "$WWW_DIR" >/dev/null 2>&1 || true
  rm -f "$ASP_DST" "$JSON_DST" >/dev/null 2>&1 || true

  ln -s "${WWW_DIR}/avp.asp" "$ASP_DST" || return 1
  ln -s "${WWW_DIR}/avp-status.json" "$JSON_DST" || return 1
  return 0
}

# Thin wrappers to manage feeder (no legacy embedded feeder implementation here)
feed_start()  { [ -x "$FEED" ] && "$FEED" start  || return 1; }
feed_stop()   { [ -x "$FEED" ] && "$FEED" stop   || return 1; }
feed_status() { [ -x "$FEED" ] && "$FEED" status || return 1; }

install() {
  log "Installing AVP WebUI..."

  mkdir -p "$WWW_DIR" >/dev/null 2>&1 || die "cannot create WWW_DIR=$WWW_DIR"
  mkdir -p "$(dirname "$ASP_DST")" >/dev/null 2>&1 || true

  ASP_SRC="$(find_asp_src)" || die "avp.asp source not found. Expected in /jffs/scripts/avp/www/avp.asp (preferred) or ${SCRIPT_DIR}/avp/www/avp.asp"

  # if source already equals destination, keep it (avoid cp same-file error)
  if [ "$ASP_SRC" != "${WWW_DIR}/avp.asp" ]; then
    {
      # FIX same-file: SRC e DST podem apontar pro mesmo inode via symlink/bind; cp falha.
      local _src_i _dst_i
      _src_i="$(ls -Li "$ASP_SRC" 2>/dev/null | awk 'NR==1{print $1; exit}')"
      _dst_i="$(ls -Li "${WWW_DIR}/avp.asp" 2>/dev/null | awk 'NR==1{print $1; exit}')"
      if [ -n "$_src_i" ] && [ -n "$_dst_i" ] && [ "$_src_i" = "$_dst_i" ]; then
        : # same file, skip copy
      else
        cp -f "$ASP_SRC" "${WWW_DIR}/avp.asp" || die "failed to copy avp.asp from $ASP_SRC"
      fi
    }
  fi
  chmod 0644 "${WWW_DIR}/avp.asp" >/dev/null 2>&1 || true

  # placeholder json (feeder will overwrite atomically)
  [ -f "${WWW_DIR}/avp-status.json" ] || echo '{"enabled":0,"profile":"n/a","devices":[]}' >"${WWW_DIR}/avp-status.json" 2>/dev/null || true
  chmod 0644 "${WWW_DIR}/avp-status.json" >/dev/null 2>&1 || true

  link_www || die "failed to link /www/user entries"
  restart_httpd

  # feeder must exist; we do NOT generate or overwrite it here
  [ -x "$FEED" ] || die "feeder not found or not executable: $FEED"
  feed_start >/dev/null 2>&1 || die "failed to start feeder (see ${WWW_DIR}/avp-status.json and /tmp/avp_logs/avp_webui_warn.log)"

  log "OK."
}

uninstall() {
  log "Uninstalling AVP WebUI..."

  # stop feeder, but do not delete it (managed by your repo/scripts)
  [ -x "$FEED" ] && "$FEED" stop >/dev/null 2>&1 || true

  rm -f "$ASP_DST" "$JSON_DST" >/dev/null 2>&1 || true
  rm -rf "$ADDON_DIR" >/dev/null 2>&1 || true

  restart_httpd
  log "OK."
}

case "${1:-}" in
  install) install ;;
  uninstall) uninstall ;;
  start) feed_start ;;
  stop) feed_stop ;;
  status) feed_status ;;
  *) echo "Usage: $0 {install|uninstall|start|stop|status}"; exit 1 ;;
esac
