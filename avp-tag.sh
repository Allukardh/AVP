#!/bin/sh
# =============================================================
# Component : AVP-TOOLS
# File      : avp-tag.sh
# Role      : Git tag helper (rel/* stable, ck/* checkpoints)
# Version   : v1.0.3 (2026-02-14)
# Status    : stable
# =============================================================

SCRIPT_VER="v1.0.3"

set -u

die() {
  echo "[avp-tag] ERROR: $1"
  exit 1
}

[ $# -eq 1 ] || die "Usage: avp-tag.sh <rel/vX.Y.Z | ck/slug_YYYYMMDD>"

tag="$1"

case "$tag" in
  rel/v*)
    ;;
  ck/*)
    ;;
  *)
    die "Invalid tag format. Use rel/vX.Y.Z or ck/slug_YYYYMMDD"
    ;;
esac

# --- árvore limpa (robusta)
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  die "Working tree not clean."
fi

# --- HEAD~1 deve existir
git rev-parse HEAD~1 >/dev/null 2>&1 || die "No previous commit to diff."

# --- tag não pode existir
if git tag | grep -q "^${tag}$"; then
  die "Tag ${tag} already exists."
fi

# --- validações adicionais para rel/*
case "$tag" in
  rel/v*)
    version="${tag#rel/}"

    # coerência SCRIPT_VER
    if [ "$SCRIPT_VER" != "$version" ]; then
      die "SCRIPT_VER (${SCRIPT_VER}) does not match tag (${version})."
    fi

    # entrada no CHANGELOG externo
    if ! grep -q "${version}" CHANGELOG 2>/dev/null; then
      die "CHANGELOG missing entry for ${version}"
    fi
    ;;
esac

# --- criação da tag anotada
git tag -a "$tag" -m "AVP ${tag}" || die "Failed to create tag."

echo "[avp-tag] Tag ${tag} created successfully."
exit 0
