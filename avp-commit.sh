#!/bin/sh
# =============================================================
# AutoVPN Platform (AVP)
# Component : AVP-COMMIT
# File      : avp-commit.sh
# Role      : Governança e gate final de commit (3A/3B)
# Version   : v1.0.2 (2026-02-15)
# Status    : stable
# =============================================================
#
# CHANGELOG
# - v1.0.2 (2026-02-15)
#   * FIX: baseline gate real (bloqueia repo DIRTY)
#   * FIX: validacao robusta de CHANGELOG
#   * FIX: determinismo 3B com ordenacao
#   * FIX: validacao segura do ultimo exit 0
#   * FIX: auto-checkpoint antes do push
# - v1.0.1 (2026-02-15)
#   * ADD: auto-checkpoint para scripts estruturais (Modelo B)
#   * ADD: gate unificado para 3A e 3B
#   * ADD: valida governança (Version/SCRIPT_VER/CHANGELOG)
#   * ADD: bloqueio multi .sh sem --allow-multi
#   * ADD: bloqueio >20 linhas removidas sem --allow-large-removal
#   * ADD: valida ultimo exit em scripts estruturais
#   * ADD: valida determinismo no modo 3B
# - v1.0.0 (2026-02-14)
#   * ADD: versao inicial
# =============================================================

SCRIPT_VER="v1.0.2"
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

# ---- BASELINE GATE REAL ----
git diff-index --quiet HEAD -- || {
  echo "ERROR: baseline DIRTY antes do commit"
  exit 1
}

CHANGED="$(git diff --name-only)"
[ -n "$CHANGED" ] || { echo "ERROR: nenhuma alteracao detectada"; exit 1; }

# ---- SMOKE ----
/jffs/scripts/avp-smoke.sh --pre || exit 6
/jffs/scripts/avp-smoke.sh --post || exit 6

# ---- MULTI .SH GATE ----
SH_FILES="$(echo "$CHANGED" | grep '\.sh$' || true)"
COUNT_SH="$(echo "$SH_FILES" | wc -l | tr -d ' ')"

if [ "$COUNT_SH" -gt 1 ] && [ "$ALLOW_MULTI" -ne 1 ]; then
  echo "ERROR: mais de um .sh alterado (use --allow-multi)"
  exit 3
fi

# ---- GOVERNANCA ROBUSTA ----
for f in $SH_FILES; do
  HEADER_VER="$(grep -E '^# Version' "$f" | head -n1 | awk '{print $3}')"
  SCRIPT_VER_LINE="$(grep -E '^SCRIPT_VER=' "$f" | head -n1 | cut -d'"' -f2)"
  CHANGELOG_MATCH="$(awk "/^# CHANGELOG/{flag=1;next}/^# =============================================================/{flag=0}flag" "$f" | grep -E "$HEADER_VER" || true)"

  [ -n "$HEADER_VER" ] || { echo "ERROR: Version ausente em $f"; exit 2; }
  [ "$HEADER_VER" = "$SCRIPT_VER_LINE" ] || { echo "ERROR: SCRIPT_VER mismatch em $f"; exit 2; }
  [ -n "$CHANGELOG_MATCH" ] || { echo "ERROR: CHANGELOG nao contem $HEADER_VER em $f"; exit 2; }
done

# ---- REMOCOES ----
REMOVED="$(git diff --numstat | awk '{s+=$2} END{print s+0}')"
if [ "$REMOVED" -gt 20 ] && [ "$ALLOW_LARGE_REMOVAL" -ne 1 ]; then
  echo "ERROR: mais de 20 linhas removidas (use --allow-large-removal)"
  exit 4
fi

# ---- EXIT FINAL SEGURO ----
for f in avp-pol.sh avp-apply.sh avp-smoke.sh services-start service-event; do
  [ -f "$f" ] || continue
  LAST_LINE="$(tail -n1 "$f")"
  echo "$LAST_LINE" | grep -q "^exit 0" || {
    echo "ERROR: ultimo comando nao e 'exit 0' em $f"
    exit 1
  }
done

# ---- DETERMINISMO 3B ----
MODE="3A"
if [ -f /tmp/avp_last_apply.ok ]; then
  MODE="3B"
  EXPECTED="$(sort /tmp/avp_last_apply_files.list)"
  CURRENT="$(echo "$CHANGED" | sort)"
  [ "$EXPECTED" = "$CURRENT" ] || {
    echo "ERROR: arquivos modificados nao batem com contexto 3B"
    exit 5
  }
fi

# ---- COMMIT LOCAL ----
git add $CHANGED || exit 1
git commit -m "$MSG" || exit 1

# ---- AUTO-CHECKPOINT ANTES DO PUSH ----
STRUCTURAL_FILES="avp-apply.sh avp-smoke.sh avp-pol.sh services-start service-event"
for f in $CHANGED; do
  for s in $STRUCTURAL_FILES; do
    if [ "$f" = "$s" ]; then
      DATE_TAG="$(date +%Y%m%d)"
      SLUG="$(basename "$f" .sh)_${DATE_TAG}"
      /jffs/scripts/avp-tag.sh ck "$SLUG" "Checkpoint automatico: $f alterado" || exit 1
      break 2
    fi
  done
done

# ---- PUSH ----
git push origin main || exit 1

# ---- CLEANUP 3B ----
if [ "$MODE" = "3B" ]; then
  rm -f /tmp/avp_last_apply.ok /tmp/avp_last_apply_files.list
fi

echo "OK: commit realizado com sucesso (modo $MODE)"
exit 0
