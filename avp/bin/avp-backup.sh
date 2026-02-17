#!/bin/sh
# =============================================================
# AutoVPN Platform (AVP)
# Component : AVP-UTIL
# File      : avp-backup.sh
# Role      : Version-aware backup utility (idempotente por versao)
# Version   : v1.0.7 (2026-01-26)
# Status    : stable
# =============================================================
#
# CHANGELOG
# - v1.0.7 (2026-01-26)
#   * VERSION: bump patch (pos harden canônico)
# - v1.0.6 (2026-01-18)
#   * POLISH: padroniza SCRIPT_VER + set -u (ordem oficial) e remove linhas em branco desnecessarias
# - v1.0.5 (2025-12-26)
#   * CHORE: polimento preparatório pra GUI (suite alinhada)
# - v1.0.4 (2025-12-23)
#   * CHORE: consolidacao historica (Etapa B) + semantica final do changelog
# - v1.0.3 (2025-12-23)
#   * STD: padroniza header + bloco CHANGELOG (Etapa A)
# - v1.0.2 (2025-12-21)
#   * ADD: self-backup (inclui o proprio avp-backup.sh)
# - v1.0.1 (2025-12-21)
#   * SAFETY: idempotente por versao (se .bak da versao ja existir -> SKIP)
#   * CHG: leitura robusta do campo Version no header
# - v1.0.0 (2025-12-21)
#   * ADD: backup automatico baseado na versao do header
#   * ADD: destino fixo /jffs/scripts/backups
# =============================================================

SCRIPT_VER="v1.0.7"
export PATH="/jffs/scripts:/opt/bin:/opt/sbin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH:-}"
hash -r 2>/dev/null || true
set -u

BACKUP_DIR="/jffs/scripts/backups"

mkdir -p "$BACKUP_DIR"

get_version_token() {
  FILE="$1"

  # Aceita:
  #   "# VER       : vX"
  #   "# VER       : vX (YYYY-MM-DD)"
  LINE="$(grep -im1 -E '^[[:space:]]*#[[:space:]]*(Version|VERSION)[[:space:]]*:' "$FILE")"
  [ -z "$LINE" ] && { echo "unknown"; return 0; }

  # Extrai "vX.Y.Z" (primeira ocorrencia)
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

  # Idempotente por versao
  if [ -f "$DST" ]; then
    echo "SKIP: $BASE ($VER) ja existe"
    return 0
  fi

  cp -a "$SRC" "$DST" 2>/dev/null && \
  echo "OK: $BASE -> $DST" || \
  echo "ERR: falha ao copiar $BASE"
}

# Lista canonica (inclui self-backup)
backup_file "/jffs/scripts/services-start"
backup_file "/jffs/scripts/post-mount"
backup_file "/jffs/scripts/avp-eng.sh"
backup_file "/jffs/scripts/avp-pol.sh"
backup_file "/jffs/scripts/avp-diag.sh"
backup_file "/jffs/scripts/avp-backup.sh"

exit 0
