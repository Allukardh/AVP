#!/bin/sh
# =============================================================
# Component : AVP-TOOLS
# File      : avp-tag.sh
# Role      : Git tag helper (rel/* stable, ck/* checkpoints)
# Version   : v1.0.1 (2026-02-08)
# Status    : stable
# -------------------------------------------------------------
#
# CHANGELOG
# - v1.0.1 (2026-02-08)
#   * FIX: git show usa --no-pager (evita pager/less no Merlin/SSH)
#   * FIX: padroniza header Version e SCRIPT_VER (sem aspas)
# - v1.0.0 (2026-01-27)
#   * initial (tag convention enforcement)
# =============================================================

SCRIPT_VER="v1.0.1"
export PATH="/jffs/scripts:/opt/bin:/opt/sbin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH:-}"
hash -r 2>/dev/null || true
set -u

# avp-tag.sh — Tagger oficial do repo AVP
#
# Uso:
#   ./avp-tag.sh rel v1.0.0 "Release v1.0.0 — baseline sólido (a partir daqui, rel/* = estável)" [ref]
#   ./avp-tag.sh ck  slug_YYYYMMDD "checkpoint ..." [ref]
#

kind="${1:-}"
name="${2:-}"
msg="${3:-}"
ref="${4:-HEAD}"

die(){ echo "ERROR: $*" >&2; exit 1; }

[ -n "$kind" ] || die "missing kind (rel|ck)"
[ -n "$name" ] || die "missing name"
[ -n "$msg"  ] || die "missing message"

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
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Working tree not clean. Commit first."
  exit 1
fi

git rev-parse HEAD~1 >/dev/null 2>&1 || {
  echo "No previous commit to diff against."
  exit 1
}

git tag | grep -q "^${TAG}$" && {
  echo "Tag ${TAG} already exists."
  exit 1
}

git tag -a "$tag" -m "$msg" "$obj"

echo "OK: created tag $tag -> $obj"
git -c color.ui=false --no-pager show -s --decorate --oneline "$obj"
