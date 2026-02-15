#!/bin/sh
# =============================================================
# AutoVPN Platform (AVP)
# Component : AVP-COMMIT
# File      : commit.sh
# Role      : Governança e gate final de commit (3A/3B)
# Version   : v1.0.0 (2026-02-14)
# Status    : stable
# =============================================================
#
# CHANGELOG
# - v1.0.0 (2026-02-14)
#   * ADD: gate unificado para 3A e 3B
#   * ADD: valida governança (Version/SCRIPT_VER/CHANGELOG)
#   * ADD: bloqueio multi .sh sem --allow-multi
#   * ADD: bloqueio >20 linhas removidas sem --allow-large-removal
#   * ADD: valida ultimo exit em scripts estruturais
#   * ADD: valida determinismo no modo 3B
# =============================================================

SCRIPT_VER="v1.0.0"
set -u

ALLOW_MULTI=0
ALLOW_LARGE_REMOVAL=0
MSG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --allow-multi) ALLOW_MULTI=1 ;;
    --allow-large-removal) ALLOW_LARGE_REMOVAL=1 ;;
    *) MSG="$1" ;;
  esac
  shift
done

[ -n "$MSG" ] || { echo "ERROR: commit message obrigatoria"; exit 1; }

# Detect mode
MODE="3A"
if [ -f /tmp/avp_last_apply.ok ]; then
  MODE="3B"
fi

# Baseline checks
git diff-index --quiet HEAD -- || true
CHANGED="$(git diff --name-only)"
[ -n "$CHANGED" ] || { echo "ERROR: nenhuma alteracao detectada"; exit 1; }

# Smoke estrutural
/jffs/scripts/avp-smoke.sh --pre || exit 6
/jffs/scripts/avp-smoke.sh --post || exit 6

# Validar arquivos .sh modificados
SH_FILES="$(echo "$CHANGED" | grep '\.sh$' || true)"
COUNT_SH="$(echo "$SH_FILES" | wc -l | tr -d ' ')"

if [ "$COUNT_SH" -gt 1 ] && [ "$ALLOW_MULTI" -ne 1 ]; then
  echo "ERROR: mais de um .sh alterado (use --allow-multi)"
  exit 3
fi

# Governança versão
for f in $SH_FILES; do
  HEADER_VER="$(grep -E '^# Version' "$f" | head -n1 | awk '{print $3}')"
  SCRIPT_VER_LINE="$(grep -E '^SCRIPT_VER=' "$f" | head -n1 | cut -d'"' -f2)"
  grep -q "$HEADER_VER" "$f" || { echo "ERROR: CHANGELOG nao contem $HEADER_VER"; exit 2; }
  [ "$HEADER_VER" = "$SCRIPT_VER_LINE" ] || { echo "ERROR: SCRIPT_VER mismatch em $f"; exit 2; }
done

# Remoções
REMOVED="$(git diff --numstat | awk '{s+=$2} END{print s+0}')"
if [ "$REMOVED" -gt 20 ] && [ "$ALLOW_LARGE_REMOVAL" -ne 1 ]; then
  echo "ERROR: mais de 20 linhas removidas (use --allow-large-removal)"
  exit 4
fi

# Validar ultimo exit
for f in avp-pol.sh avp-apply.sh avp-smoke.sh services-start service-event; do
  [ -f "$f" ] || continue
  LAST_EXIT_LINE="$(grep -n 'exit' "$f" | tail -n1 | cut -d: -f1)"
  TOTAL_LINES="$(wc -l < "$f")"
  [ "$LAST_EXIT_LINE" = "$TOTAL_LINES" ] || {
    echo "ERROR: codigo apos ultimo exit em $f"
    exit 1
  }
done

# Determinismo 3B
if [ "$MODE" = "3B" ]; then
  EXPECTED="$(cat /tmp/avp_last_apply_files.list)"
  [ "$EXPECTED" = "$CHANGED" ] || {
    echo "ERROR: arquivos modificados nao batem com contexto 3B"
    exit 5
  }
fi

git add $CHANGED || exit 1
git commit -m "$MSG" || exit 1
git push origin main || exit 1

# Cleanup 3B context
if [ "$MODE" = "3B" ]; then
  rm -f /tmp/avp_last_apply.ok /tmp/avp_last_apply_files.list
fi

echo "OK: commit realizado com sucesso (modo $MODE)"
exit 0
