#!/bin/sh
# ============================================================
# Component: AVP
# File: avp-tag.sh
# Role: Tag validator + creator (Governance enforced)
# Status: ACTIVE
# ============================================================

set -e

TAG="$1"

if [ -z "$TAG" ]; then
  echo "Usage: avp-tag.sh rel/vX.Y.Z"
  exit 1
fi

echo "$TAG" | grep -Eq '^rel/v[0-9]+\.[0-9]+\.[0-9]+$' || {
  echo "Invalid tag format. Use rel/vX.Y.Z"
  exit 1
}

VERSION="${TAG#rel/}"

# Ensure clean working tree
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Working tree not clean. Commit first."
  exit 1
fi

# Ensure previous commit exists
git rev-parse HEAD~1 >/dev/null 2>&1 || {
  echo "No previous commit to diff against."
  exit 1
}

echo "Validating diff..."
git diff HEAD~1

# Validate Version header
grep -R "Version: ${VERSION}" . >/dev/null 2>&1 || {
  echo "Version header not updated to ${VERSION}"
  exit 1
}

# Validate SCRIPT_VER
grep -R "SCRIPT_VER=\"${VERSION}\"" . >/dev/null 2>&1 || {
  echo "SCRIPT_VER not matching ${VERSION}"
  exit 1
}

# Validate CHANGELOG entry
grep -R "${VERSION}" CHANGELOG* >/dev/null 2>&1 || {
  echo "CHANGELOG missing entry for ${VERSION}"
  exit 1
}

# Prevent duplicate tag
git tag | grep -q "^${TAG}$" && {
  echo "Tag ${TAG} already exists."
  exit 1
}

git tag "${TAG}"
echo "Tag ${TAG} created successfully."
exit 0
