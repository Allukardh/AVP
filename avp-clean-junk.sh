#!/bin/sh
# ============================================================
# AutoVPN Platform (AVP)
# Component : AVP-CLEAN
# File      : avp-clean-junk.sh
# Role      : Safe cleanup of common untracked junk (dry-run default)
# Status    : stable
# Version   : v1.0.0 (2026-01-27)
# ============================================================
#
# CHANGELOG
# - v1.0.0 (2026-01-27)
#   * ADD: dry-run scanner + optional remover (untracked-only with git)
#
SCRIPT_VER="v1.0.0"
set -u

ts(){ date '+%Y-%m-%d %H:%M:%S'; }
say(){ printf "%s [CLEAN] %s\n" "$(ts)" "$*"; }
die(){ printf "%s [CLEAN] ERROR: %s\n" "$(ts)" "$*" >&2; exit 1; }

ROOT="/jffs/scripts"
MODE="scan"
YES=0

while [ $# -gt 0 ]; do
  case "$1" in
    --scan) MODE="scan" ;;
    --apply) MODE="apply" ;;
    --yes) YES=1 ;;
    --root) shift; [ $# -gt 0 ] || die "--root requires a path"; ROOT="$1" ;;
    -h|--help)
      cat <<'USAGE'
Usage:
  avp-clean-junk.sh --scan
  avp-clean-junk.sh --apply --yes
Options:
  --root PATH   repo root (default: /jffs/scripts)
Safety:
  - --apply requires git repo and removes ONLY untracked files.
  - Never touches: .git/, backups/, autovpn/, avp/state/, avp/cache/, avp/logs/
USAGE
      exit 0 ;;
    *) die "unknown arg: $1" ;;
  esac
  shift
done

[ -d "$ROOT" ] || die "root not found: $ROOT"

export PATH="/jffs/scripts:/opt/bin:/opt/sbin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH:-}"
export GIT_PAGER=cat PAGER=cat
hash -r 2>/dev/null || true

GIT_OK=0
if command -v git >/dev/null 2>&1; then
  if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    GIT_OK=1
  fi
fi

if [ "$MODE" = "apply" ]; then
  [ "$YES" -eq 1 ] || die "--apply requires --yes"
  [ "$GIT_OK" -eq 1 ] || die "refusing --apply without git repo"
fi

find "$ROOT" -type f \
  -not -path "$ROOT/.git/*" \
  -not -path "$ROOT/backups/*" \
  -not -path "$ROOT/autovpn/*" \
  -not -path "$ROOT/avp/state/*" \
  -not -path "$ROOT/avp/cache/*" \
  -not -path "$ROOT/avp/logs/*" \
  \( \
    -name "*.new" -o \
    -name "*.patch" -o \
    -name "*.rej" -o \
    -name "*.orig" -o \
    -name "*.tmp" -o \
    -name "*~" -o \
    -name "nohup.out" -o \
    -name ".DS_Store" -o \
    -name "Thumbs.db" -o \
    -name "core" -o \
    -name "core.*" -o \
    -name ".*.swp" \
  \) 2>/dev/null | while IFS= read -r f; do
    [ -n "$f" ] || continue
    rel="${f#"$ROOT"/}"

    if [ "$GIT_OK" -eq 1 ]; then
      if git -C "$ROOT" ls-files --error-unmatch "$rel" >/dev/null 2>&1; then
        continue
      fi
    fi

    if [ "$MODE" = "apply" ]; then
      rm -f -- "$f" 2>/dev/null || die "failed to remove: $rel"
      say "DEL untracked: $rel"
    else
      say "CANDIDATE: $rel"
    fi
  done

say "done (mode=$MODE)"
