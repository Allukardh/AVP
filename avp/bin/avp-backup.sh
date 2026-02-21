#!/bin/sh
# =============================================================
# AutoVPN Platform (AVP)
# Component : AVP-UTIL
# File      : avp-backup.sh
# Role      : Version-aware backup utility (idempotente por versao)
# Version   : v1.0.9 (2026-02-20)
# Status    : stable
# =============================================================

SCRIPT_VER="v1.0.9"
export PATH="/jffs/scripts:/jffs/scripts/avp/bin:/opt/bin:/opt/sbin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH:-}"
hash -r 2>/dev/null || true
set -u

BACKUP_DIR="/jffs/scripts/avp/backups"
mkdir -p "$BACKUP_DIR"

get_version_token() {
  FILE="$1"
  LINE="$(grep -im1 -E '^[[:space:]]*#[[:space:]]*(Version|VERSION)[[:space:]]*:' "$FILE")"
  [ -z "$LINE" ] && { echo "unknown"; return 0; }
  VER="$(echo "$LINE" | sed -n 's/.*\(v[0-9][0-9.]*\).*/\1/p' | head -n 1)"
  [ -z "$VER" ] && VER="unknown"
  echo "$VER"
}

backup_file() {
  SRC="$1"
  [ -f "$SRC" ] || return 0

  VER="$(get_version_token "$SRC")"
  BASE="$(basename "$SRC")"
  DST="$BACKUP_DIR/${BASE}.${VER}.bak"

  if [ -f "$DST" ]; then
    echo "SKIP: $BASE ($VER) ja existe"
    return 0
  fi

  cp -a "$SRC" "$DST" 2>/dev/null && \
  echo "OK: $BASE -> $DST" || \
  echo "ERR: falha ao copiar $BASE"
}

# Lista dinâmica (repo-aware; inclui self-backup)
list_targets() {
  cd /jffs/scripts || return 1
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1

  git ls-files | grep -E \
    '^(services-start|service-event|post-mount|avp/bin/[^/]+(\.sh)?|avp/lib/[^/]+\.sh)$' \
    | while IFS= read -r rel; do
        [ -n "$rel" ] || continue
        printf '/jffs/scripts/%s\n' "$rel"
      done
}

list_targets | while IFS= read -r src; do
  [ -n "$src" ] || continue
  backup_file "$src"
done

exit 0
