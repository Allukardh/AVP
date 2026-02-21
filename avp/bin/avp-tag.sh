#!/bin/sh
# =============================================================
# AutoVPN Platform (AVP)
# Component : AVP-TAG
# File      : avp-tag.sh
# Role      : Git tag helper (rel/* stable, ck/* checkpoints)
# Version   : v1.0.7 (2026-02-20)
# Status    : stable
# =============================================================

SCRIPT_VER="v1.0.7"
export PATH="/jffs/scripts:/jffs/scripts/avp/bin:/opt/bin:/opt/sbin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH:-}"
hash -r 2>/dev/null || true
set -u

die(){ echo "ERROR: $*" >&2; exit 1; }

usage(){
  cat <<'USG'
avp-tag.sh — Tagger oficial do repo AVP

Uso:
  avp-tag.sh [--publish|--no-publish] rel vX.Y.Z "mensagem" [ref]
  avp-tag.sh [--publish|--no-publish] ck  slug_YYYYMMDD "mensagem" [ref]

Regras:
  - rel: vX.Y.Z
  - ck : slug_YYYYMMDD (lowercase)
  - ref default: HEAD

Publish (SSOT):
  - rel/*: publish ligado por padrão (push main + push tag)
           para desligar: --no-publish
  - ck/* : publish desligado por padrão
           para publicar: --publish

Variável de ambiente:
  AVP_TAG_PUBLISH=1  força publish (qualquer tipo)
USG
}

# --- publish mode (SSOT) ---
PUBLISH_SET=0
if [ "${AVP_TAG_PUBLISH+x}" = "x" ] || [ "${AVP_TAG_PUBLISH+x}" = "1" ]; then :; fi
if [ "${AVP_TAG_PUBLISH+x}" ]; then
  PUBLISH="${AVP_TAG_PUBLISH:-0}"
  PUBLISH_SET=1
else
  PUBLISH="0"
fi

# flags pré-parse do kind
while [ $# -gt 0 ]; do
  case "$1" in
    --publish)    PUBLISH=1; PUBLISH_SET=1; shift ;;
    --no-publish) PUBLISH=0; PUBLISH_SET=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    *) break ;;
  esac
done

kind="${1:-}"
name="${2:-}"
msg="${3:-}"
ref="${4:-HEAD}"

[ -n "$kind" ] || { usage; die "missing kind (rel|ck)"; }
[ -n "$name" ] || die "missing name"
[ -n "$msg"  ] || die "missing message"

# defaults por tipo (se usuário não setou publish explicitamente)
if [ "$PUBLISH_SET" -eq 0 ]; then
  if [ "$kind" = "rel" ]; then
    PUBLISH=1
  else
    PUBLISH=0
  fi
fi

ensure_main_branch(){
  b="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
  [ "$b" = "main" ] || die "branch atual nao e main (atual=$b)"
}

ensure_diff_check(){
  git diff --check >/dev/null 2>&1 || die "git diff --check falhou (whitespace/patch issues)"
}

rel_minicheck_last_commit(){
  # valida em .sh tocados no ultimo commit: Version/SCRIPT_VER/CHANGELOG contem tag
  files="$(git show -1 --name-only --pretty="" 2>/dev/null | grep "\.sh$" || true)"
  [ -n "$files" ] || return 0

  for f in $files; do
    [ -f "$f" ] || continue

    hv="$(grep -E "^# Version" "$f" | head -n1 | awk '{for(i=1;i<=NF;i++) if($i ~ /^v[0-9]/){print $i; exit}}')"
    sv="$(grep -E "^SCRIPT_VER=" "$f" | head -n1 | cut -d\" -f2)"

    [ -n "$hv" ] || die "Version ausente em $f"
    [ "$hv" = "$sv" ] || die "SCRIPT_VER mismatch em $f (Version=$hv SCRIPT_VER=$sv)"

    awk '/^# CHANGELOG/{flag=1;next}/^# =============================================================/{flag=0}flag' "$f" | grep -q "$hv" \
      || die "CHANGELOG nao contem $hv em $f"

    [ "$hv" = "$name" ] || die "Version ($hv) nao bate com tag rel ($name) em $f"
  done
}

case "$kind" in
  rel)
    echo "$name" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$' || die "release name must be like vX.Y.Z"
    tag="rel/$name"
    ;;
  ck)
    echo "$name" | grep -Eq '^[a-z0-9][a-z0-9._-]*_[0-9]{8}$' || die "ck name must be like slug_YYYYMMDD (lowercase)"
    tag="ck/$name"
    ;;
  *)
    die "unknown kind: $kind (use rel|ck)"
    ;;
esac

git rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1 && die "tag already exists: $tag"
obj="$(git rev-parse "$ref")" || die "invalid ref: $ref"

# -------------------------------
# Incremental Governance Guards
# -------------------------------

if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  echo "Working tree not clean. Commit first."
  git status -sb
  exit 1
fi

git rev-parse HEAD~1 >/dev/null 2>&1 || {
  echo "No previous commit to diff against."
  exit 1
}

git tag | grep -q "^${tag}$" && {
  echo "Tag ${tag} already exists."
  exit 1
}

# --- validação adicional para releases
case "$kind" in
  rel)
    if [ -f CHANGELOG ] && ! grep -q "${name}" CHANGELOG; then
      die "CHANGELOG não possui entrada para ${name}"
    fi
    ;;
esac

# cria tag anotada
git tag -a "$tag" -m "$msg" "$obj"

# --- Mini-checklist + publish (opcional/padrão por tipo) ---
ensure_main_branch
ensure_diff_check
case "$kind" in
  rel) rel_minicheck_last_commit ;;
esac

if [ "$PUBLISH" -eq 1 ]; then
  git push origin main || die "push main falhou"
  git push origin "$tag" || die "push tag falhou"
else
  echo "INFO: tag criada localmente e NAO publicada (use --publish ou AVP_TAG_PUBLISH=1)."
fi

echo "OK: created tag $tag -> $obj"
git -c color.ui=false --no-pager show -s --decorate --oneline "$obj"
