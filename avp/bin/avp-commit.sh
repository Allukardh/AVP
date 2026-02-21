#!/bin/sh
# =============================================================
# AutoVPN Platform (AVP)
# Component : AVP-COMMIT
# File      : avp-commit.sh
# Role      : Governança e gate final de commit (3A/3B)
# Version : v1.0.12 (2026-02-20)
# Status    : stable
# =============================================================

SCRIPT_VER="v1.0.12"
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
# Permite staged/unstaged; bloqueia apenas UNTRACKED (sem 'porcelain' total)
UNTRACKED="$(git ls-files --others --exclude-standard 2>/dev/null)"
if [ -n "$UNTRACKED" ]; then
  echo "ERROR: existem arquivos untracked (limpe/ignore antes do commit)"
  git status -sb
  exit 1
fi

CHANGED_WORK="$(git diff --name-only)"
CHANGED_CACHED="$(git diff --cached --name-only)"
CHANGED="$(printf '%s\n%s\n' "$CHANGED_WORK" "$CHANGED_CACHED" | sed '/^$/d' | sort -u)"
[ -n "$CHANGED" ] || { echo "ERROR: nenhuma alteracao detectada"; exit 1; }

# ---- MULTI .SH GATE ----
SH_FILES="$(echo "$CHANGED" | grep '\.sh$' || true)"
COUNT_SH="$(echo "$SH_FILES" | wc -l | tr -d ' ')"
if [ "$COUNT_SH" -gt 1 ] && [ "$ALLOW_MULTI" -ne 1 ]; then
  echo "ERROR: mais de um .sh alterado (use --allow-multi)"
  exit 3
fi

# ---- GOVERNANCA ROBUSTA ----
for f in $SH_FILES; do
  HEADER_VER="$(grep -E '^# Version' "$f" | head -n1 | awk '{for(i=1;i<=NF;i++) if($i ~ /^v[0-9]/){print $i; exit}}')"
  SCRIPT_VER_LINE="$(grep -E '^SCRIPT_VER=' "$f" | head -n1 | cut -d'"' -f2)"
  CHANGELOG_MATCH="$(awk "/^# CHANGELOG/{flag=1;next}/^# =============================================================/{flag=0}flag" "$f" | grep -E "$HEADER_VER" || true)"

  [ -n "$HEADER_VER" ] || { echo "ERROR: Version ausente em $f"; exit 2; }
  [ "$HEADER_VER" = "$SCRIPT_VER_LINE" ] || { echo "ERROR: SCRIPT_VER mismatch em $f"; exit 2; }
  [ -n "$CHANGELOG_MATCH" ] || { echo "ERROR: CHANGELOG nao contem $HEADER_VER em $f"; exit 2; }
done

# ---- REMOCOES ----
REMOVED_WORK="$(git diff --numstat | awk '{s+=$2} END{print s+0}')"
REMOVED_CACHED="$(git diff --cached --numstat | awk '{s+=$2} END{print s+0}')"
REMOVED="$((REMOVED_WORK + REMOVED_CACHED))"

if [ "$REMOVED" -gt 20 ] && [ "$ALLOW_LARGE_REMOVAL" -ne 1 ]; then
  echo "ERROR: mais de 20 linhas removidas (use --allow-large-removal)"
  exit 4
fi

# ---- EXIT FINAL ROBUSTO ----
# Valida apenas se o arquivo estiver em CHANGED; ignora comentarios/linhas em branco finais.
STRUCT_EXIT_FILES="avp-pol.sh avp-apply.sh avp-smoke.sh services-start service-event"
for f in $STRUCT_EXIT_FILES; do
  echo "$CHANGED" | grep -qx "$f" || continue
  [ -f "$f" ] || continue
  LAST_EXEC="$(awk '
    /^[[:space:]]*#/ {next}
    NF==0 {next}
    {last=$0}
    END{print last}
  ' "$f")"
  [ -n "$LAST_EXEC" ] || { echo "ERROR: nao achei linha executavel para validar exit 0 em $f"; exit 1; }
  echo "$LAST_EXEC" | grep -Eq "^[[:space:]]*exit[[:space:]]+0[[:space:]]*$" || {
    echo "ERROR: ultimo comando executavel nao e 'exit 0' em $f"
    exit 1
  }
done
# ---- DETERMINISMO 3B ----
MODE="3A"
if [ -f /tmp/avp_last_apply.ok ]; then
  MODE="3B"
  EXPECTED="$(sort /tmp/avp_last_apply_files.list)"
  CURRENT="$(echo "$CHANGED" | sort)"
  [ "$EXPECTED" = "$CURRENT" ] || { echo "ERROR: arquivos modificados nao batem com contexto 3B"; exit 5; }
fi

# ---- COMMIT LOCAL ----
# -A para capturar deletions, caso existam
git add -A -- $CHANGED || exit 1
git commit -m "$MSG" || exit 1

# ---- CLEANUP 3B ----
if [ "$MODE" = "3B" ]; then
  rm -f /tmp/avp_last_apply.ok /tmp/avp_last_apply_files.list
fi

echo "OK: commit realizado com sucesso (modo $MODE)"
exit 0
