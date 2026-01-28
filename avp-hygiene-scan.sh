#!/bin/sh
# ============================================================
# AutoVPN Platform (AVP)
# Component : AVP-HYGIENE
# File      : avp-hygiene-scan.sh
# Role      : Scan scripts for hygiene candidates (NO changes)
# Status    : stable
# Version   : v1.0.0 (2026-01-27)
# ============================================================
#
# CHANGELOG
# - v1.0.0 (2026-01-27)
#   * ADD: safe scanner (report-only) for comments/blank lines/dead patterns
#
SCRIPT_VER="v1.0.0"
set -u

ts(){ date '+%Y-%m-%d %H:%M:%S'; }
say(){ printf "%s [HYGIENE] %s\n" "$(ts)" "$*"; }
die(){ printf "%s [HYGIENE] ERROR: %s\n" "$(ts)" "$*" >&2; exit 1; }

usage(){
  cat <<'USAGE'
Usage:
  avp-hygiene-scan.sh <file>
Examples:
  ./avp-hygiene-scan.sh avp-lib.sh
Notes:
  - Report only (does NOT modify files)
  - Shows line numbers and short snippets
USAGE
}

[ $# -ge 1 ] || { usage; exit 1; }
FILE="$1"
[ -f "$FILE" ] || die "file not found: $FILE"

say "scan start: $FILE"

# helper: print matches with line number + snippet
grep_snip(){
  _label="$1"; _pat="$2"
  say "$_label"
  grep -nE "$_pat" "$FILE" 2>/dev/null | awk -F: '{
    ln=$1; $1=""; sub(/^:/,""); s=$0;
    if (length(s)>140) s=substr(s,1,140) "...";
    printf "  L%-6s %s\n", ln, s
  }'
}

# 1) trailing whitespace
grep_snip "TRAILING WHITESPACE (revise/remove)" "[ \t]+$"

# 2) multiple blank lines (detect runs)
say "MULTIPLE BLANK LINES (revise/remove)"
awk '
  BEGIN{b=0}
  {
    if ($0 ~ /^[ \t]*$/) { b++; if (b==2) print NR ":<blank-run>"; }
    else b=0
  }
' "$FILE" | awk -F: '{printf "  L%-6s %s\n",$1,$2}'

# 3) likely "commented-out code" (candidates only)
grep_snip "COMMENTED-OUT CODE (candidate)" "^[ \t]*#[ \t]*(if|then|else|fi|for|while|do|done|case|esac|exit|return|rm[ \t]|mv[ \t]|cp[ \t]|sed[ \t]|awk[ \t]|grep[ \t]|printf[ \t])"

# 4) legacy/deprec/todo/hack/workaround/debug notes
grep_snip "LEGACY/TODO/HACK/DEBUG NOTES (candidate)" "^[ \t]*#.*(LEGACY|DEPRECAT|OBSOLE|TODO|FIXME|HACK|WORKAROUND|TEMP|DEBUG|REMOVE ME|OLD)\\b"

# 5) suspicious no-op / unreachable patterns (candidate)
grep_snip "SUSPICIOUS UNREACHABLE/NO-OP (candidate)" "^[ \t]*(if[ \t]+false|if[ \t]+0[ \t]*;|:[ \t]*<<|return[ \t]+0[ \t]*#|exit[ \t]+0[ \t]*#)"

# 6) redundant adjacent duplicate comment lines (candidate)
say "ADJACENT DUPLICATE COMMENTS (candidate)"
awk '
  function norm(s){ gsub(/[ \t]+/," ",s); sub(/^ /,"",s); sub(/ $/,"",s); return s }
  {
    s=$0
    if (s ~ /^[ \t]*#/) {
      n=norm(s)
      if (n==p && n!="") print NR ":" s
      p=n
    } else p=""
  }
' "$FILE" | awk -F: '{
  ln=$1; $1=""; sub(/^:/,"");
  s=$0; if (length(s)>140) s=substr(s,1,140) "...";
  printf "  L%-6s %s\n", ln, s
}'

say "scan done: $FILE"
