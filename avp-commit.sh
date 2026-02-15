#!/bin/sh
# =============================================================
# AutoVPN Platform (AVP)
# Component : AVP-COMMIT
# File      : avp-commit.sh
# Role      : Governança + commit gate + auto-checkpoint estrutural
# Version   : v1.1.0 (2026-02-14)
# Status    : stable
# =============================================================
#
# CHANGELOG
# - v1.1.0 (2026-02-14)
#   * ADD: auto-checkpoint apenas para scripts estruturais
# - v1.0.0 (2026-02-14)
#   * ADD: gate unificado 3A/3B com validações completas
# =============================================================

SCRIPT_VER="v1.1.0"
set -u

MSG="$1"
[ -n "${MSG:-}" ] || { echo "ERROR: commit message obrigatoria"; exit 1; }

STRUCTURAL_FILES="avp-apply.sh avp-smoke.sh avp-pol.sh services-start service-event"

MODE="3A"
[ -f /tmp/avp_last_apply.ok ] && MODE="3B"

CHANGED="$(git diff --name-only)"
[ -n "$CHANGED" ] || { echo "ERROR: nenhuma alteracao detectada"; exit 1; }

# Smoke estrutural
/jffs/scripts/avp-smoke.sh --pre || exit 6
/jffs/scripts/avp-smoke.sh --post || exit 6

# Governança básica
for f in $CHANGED; do
  case "$f" in
    *.sh)
      HEADER_VER="$(grep -E '^# Version' "$f" | awk '{print $3}')"
      SCRIPT_VER_LINE="$(grep -E '^SCRIPT_VER=' "$f" | cut -d'"' -f2)"
      grep -q "$HEADER_VER" "$f" || { echo "ERROR: CHANGELOG nao contem $HEADER_VER em $f"; exit 2; }
      [ "$HEADER_VER" = "$SCRIPT_VER_LINE" ] || { echo "ERROR: SCRIPT_VER mismatch em $f"; exit 2; }
      ;;
  esac
done

# Remoções
REMOVED="$(git diff --numstat | awk '{s+=$2} END{print s+0}')"
[ "$REMOVED" -le 20 ] || { echo "ERROR: mais de 20 linhas removidas"; exit 4; }

# Determinismo 3B
if [ "$MODE" = "3B" ]; then
  EXPECTED="$(cat /tmp/avp_last_apply_files.list)"
  [ "$EXPECTED" = "$CHANGED" ] || {
    echo "ERROR: arquivos nao batem com contexto 3B"
    exit 5
  }
fi

# Detectar auto-checkpoint (Modelo B)
AUTO_CK=0
CK_SLUG=""

for f in $CHANGED; do
  for s in $STRUCTURAL_FILES; do
    if [ "$f" = "$s" ]; then
      AUTO_CK=1
      CK_SLUG="$(basename "$f" .sh)"
      break 2
    fi
  done
done

git add $CHANGED || exit 1
git commit -m "$MSG" || exit 1
git push origin main || exit 1

if [ "$MODE" = "3B" ]; then
  rm -f /tmp/avp_last_apply.ok /tmp/avp_last_apply_files.list
fi

# Executar checkpoint automático se necessário
if [ "$AUTO_CK" -eq 1 ]; then
  DATE_TAG="$(date +%Y%m%d)"
  SLUG="${CK_SLUG}_${DATE_TAG}"
  /jffs/scripts/avp-tag.sh ck "$SLUG" "Checkpoint automatico: $CK_SLUG alterado"
fi

echo "OK: commit realizado (modo $MODE)"
exit 0
