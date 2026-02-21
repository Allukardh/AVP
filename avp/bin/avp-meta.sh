#!/bin/sh
# =============================================================
# AutoVPN Platform (AVP)
# Component : AVP-META
# File      : avp-meta.sh
# Role      : Metadata governor (header/changelog/SCRIPT_VER)
# Version   : v1.0.1 (2026-02-20)
# Status    : stable
# =============================================================

SCRIPT_VER="v1.0.1"
export PATH="/jffs/scripts:/jffs/scripts/avp/bin:/opt/bin:/opt/sbin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH:-}"
hash -r 2>/dev/null || true
set -u

# =============================================================
# avp-meta.sh — contratos
# - Nunca altera “corpo do código” (após o bloco canônico).
# - Só mexe em: header (meta), CHANGELOG, SCRIPT_VER e blanks canônicos.
# - Operação transacional: escreve /tmp/*.new e só então mv.
# =============================================================

ts(){ date "+%Y-%m-%d %H:%M:%S"; }
log(){ echo "$(ts) [META] $*"; }
warn(){ echo "$(ts) [META] WARN: $*" >&2; }
err(){ echo "$(ts) [META] ERR: $*" >&2; }
die(){ err "$*"; exit 1; }

have(){ command -v "$1" >/dev/null 2>&1; }

need_jq(){
  have jq || die "jq nao encontrado. Instale via Entware (opkg install jq) ou ajuste PATH."
}

trim(){
  # trim trailing spaces/tabs only (safe)
  # shellcheck disable=SC2001
  echo "$1" | sed 's/[[:space:]]*$//'
}

is_date(){
  case "$1" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) return 0 ;;
  esac
  return 1
}

norm_ver(){
  v="$1"
  [ -n "${v:-}" ] || return 1
  case "$v" in
    v*) : ;;
    *) v="v$v" ;;
  esac
  case "$v" in
    v[0-9]*.[0-9]*.[0-9]*) echo "$v"; return 0 ;;
    *) return 1 ;;
  esac
}

today(){ date "+%Y-%m-%d"; }

# -------------------------------------------------------------
# CANONICAL HEADER (exact structure)
# - shebang
# - sep
# - metadata
# - sep
# - blank + SCRIPT_VER + PATH/hash + set -u + blank (IMPORTANT)
# -------------------------------------------------------------
SEP="# ============================================================="

write_canon_header(){
  out="$1"
  component="$2"
  file="$3"
  role="$4"
  version="$5"
  date_="$6"
  status="$7"
  script_ver="$8"
  changelog_block="$9"   # path to file holding changelog lines (already prefixed with "# ...")

  {
    echo "#!/bin/sh"
    echo "$SEP"
    echo "# AutoVPN Platform (AVP)"
    printf "# Component : %s\n" "$component"
    printf "# File      : %s\n" "$file"
    printf "# Role      : %s\n" "$role"
    printf "# Version   : %s (%s)\n" "$version" "$date_"
    printf "# Status    : %s\n" "$status"
    echo "$SEP"
    echo "#"
    echo "# CHANGELOG"
    # changelog_block must contain ONLY the lines after "# CHANGELOG" (no blanks)
    if [ -s "$changelog_block" ]; then
      cat "$changelog_block"
    fi
    echo "$SEP"
    echo ""
    printf 'SCRIPT_VER="%s"\n' "$script_ver"
    echo 'export PATH="/jffs/scripts:/opt/bin:/opt/sbin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH:-}"'
    echo 'hash -r 2>/dev/null || true'
    echo 'set -u'
    echo ""  # <<< regra canônica: 1 linha em branco APÓS set -u
  } > "$out"
}

# -------------------------------------------------------------
# Parse existing meta (best-effort, preserve if present)
# -------------------------------------------------------------
extract_kv(){
  # $1=file, $2=prefix regex literal (e.g. "# Component :")
  f="$1"; key="$2"
  # Keep everything after ":" (trim)
  val="$(grep -m1 "^${key}" "$f" 2>/dev/null | sed 's/^[^:]*:[[:space:]]*//' )"
  val="$(trim "${val:-}")"
  echo "${val:-}"
}

extract_version(){
  f="$1"
  line="$(grep -m1 '^# Version[[:space:]]*:' "$f" 2>/dev/null || true)"
  [ -n "$line" ] || { echo ""; return 0; }
  # extract "vX.Y.Z" and "(YYYY-MM-DD)"
  v="$(echo "$line" | sed -n 's/^# Version[[:space:]]*:[[:space:]]*\(v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p')"
  d="$(echo "$line" | sed -n 's/.*(\([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\)).*/\1/p')"
  echo "$v|$d"
}

extract_script_ver(){
  f="$1"
  sv="$(grep -m1 '^SCRIPT_VER=' "$f" 2>/dev/null | sed 's/^SCRIPT_VER="//; s/"[[:space:]]*$//' || true)"
  sv="$(trim "${sv:-}")"
  echo "${sv:-}"
}

extract_changelog_lines(){
  # output ONLY lines after "# CHANGELOG" up to next SEP (or end),
  # already prefixed with "# " exactly as stored in file.
  in="$1"
  out="$2"
  : > "$out"
  awk -v sep="$SEP" '
    BEGIN{cl=0}
    /^# CHANGELOG[[:space:]]*$/ { cl=1; next }
    cl==1 && $0==sep { exit }
    cl==1 {
      # ignore pure blank or "#" lines inside changelog (normalize)
      if ($0 ~ /^$/) next
      if ($0 ~ /^#[[:space:]]*$/) next
      print $0
    }
  ' "$in" >> "$out" 2>/dev/null || true

  # final trim trailing spaces
  tmp="${out}.tmp"
  : > "$tmp"
  while IFS= read -r l || [ -n "$l" ]; do
    printf "%s\n" "$(echo "$l" | sed 's/[[:space:]]*$//')" >> "$tmp"
  done < "$out"
  mv "$tmp" "$out"
}

# -------------------------------------------------------------
# Body extraction (preserve exactly after canonical boundary)
# boundary = first "set -u" line; body starts at first NONBLANK line after it
# -------------------------------------------------------------
extract_body(){
  in="$1"
  out="$2"
  : > "$out"

  # find first set -u line number
  ln_setu="$(awk '{
    if ($0=="set -u") { print NR; exit }
  }' "$in" 2>/dev/null || true)"

  [ -n "${ln_setu:-}" ] || {
    # no set -u => assume whole file is body (meta will create header)
    cat "$in" > "$out"
    return 0
  }

  # compute body start: first nonblank after set -u line
  awk -v n="$ln_setu" '
    NR<=n { next }
    # skip blank lines immediately after set -u (they are header-space)
    started==0 {
      if ($0 ~ /^[[:space:]]*$/) next
      started=1
    }
    started==1 { print }
  ' "$in" > "$out"
}

# -------------------------------------------------------------
# Apply/Update changelog entry (top insertion or replace)
# -------------------------------------------------------------
render_new_entry(){
  # $1=ver, $2=date, $3=items_file(out lines WITHOUT "# " prefix, one per line)
  ver="$1"; date_="$2"; items="$3"
  echo "# - ${ver} (${date_})"
  if [ -s "$items" ]; then
    while IFS= read -r it || [ -n "$it" ]; do
      it="$(trim "$it")"
      [ -n "$it" ] || continue
      # normalize: allow "* ..." or "FIX: ..." etc.
      case "$it" in
        \**)
          it="$(echo "$it" | sed 's/^\*[[:space:]]*/* /')"
          ;;
        *)
          it="* $it"
          ;;
      esac
      echo "# $it"
    done < "$items"
  else
    echo "# * NOTE: (no changelog items provided)"
  fi
}

apply_entry_into_changelog(){
  # $1=existing_changelog_block_file, $2=ver, $3=date, $4=items_file, $5=out_changelog_block_file
  in="$1"; ver="$2"; date_="$3"; items="$4"; out="$5"
  : > "$out"

  # If existing already starts with the same version, replace that first entry’s bullets.
  # Else insert at top.
  first_ver="$(grep -m1 '^# - v' "$in" 2>/dev/null | sed 's/^# - \(v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/' || true)"

  if [ -n "$first_ver" ] && [ "$first_ver" = "$ver" ]; then
    # Replace first entry:
    render_new_entry "$ver" "$date_" "$items" >> "$out"
    # Append remaining entries (skip old first entry bullets)
    awk '
      BEGIN{seen=0; skipping=0}
      /^# - v[0-9]+\.[0-9]+\.[0-9]+/ {
        if (seen==0) { seen=1; skipping=1; next }
        skipping=0
      }
      seen==1 && skipping==1 { next }
      seen==1 && skipping==0 { print }
    ' "$in" >> "$out"
    return 0
  fi

  # Insert at top:
  render_new_entry "$ver" "$date_" "$items" >> "$out"
  if [ -s "$in" ]; then
    cat "$in" >> "$out"
  fi
}

# -------------------------------------------------------------
# Normalize (no bump): align header Version/SCRIPT_VER, enforce canonical blanks/order.
# -------------------------------------------------------------
normalize_one(){
  f="$1"
  [ -f "$f" ] || die "arquivo nao existe: $f"

  tmp_base="/tmp/avp_meta_$$"
  in_s="${tmp_base}.in"
  body="${tmp_base}.body"
  chlog="${tmp_base}.chlog"
  chlog2="${tmp_base}.chlog2"
  hdr="${tmp_base}.hdr"
  out="${tmp_base}.out"

  # sanitize CRLF (strip \r)
  tr -d "\r" < "$f" > "$in_s" || die "falha lendo $f"

  # preserve body
  extract_body "$in_s" "$body"

  # meta fields (preserve if present)
  component="$(extract_kv "$in_s" "# Component")"
  role="$(extract_kv "$in_s" "# Role")"
  status="$(extract_kv "$in_s" "# Status")"
  file_field="$(extract_kv "$in_s" "# File")"

  [ -n "$file_field" ] || file_field="$(basename "$f")"
  [ -n "$component" ] || component="AVP-META"
  [ -n "$role" ] || role="(unspecified)"
  [ -n "$status" ] || status="stable"

  vd="$(extract_version "$in_s")"
  v_hdr="$(echo "$vd" | cut -d'|' -f1)"
  d_hdr="$(echo "$vd" | cut -d'|' -f2)"

  sv="$(extract_script_ver "$in_s")"

  # pick a version for normalization
  v_use=""
  if [ -n "$sv" ]; then v_use="$sv"; fi
  if [ -z "$v_use" ] && [ -n "$v_hdr" ]; then v_use="$v_hdr"; fi
  if [ -z "$v_use" ]; then v_use="v0.0.0"; fi

  v_use="$(norm_ver "$v_use" 2>/dev/null || true)"
  [ -n "$v_use" ] || v_use="v0.0.0"

  d_use="$d_hdr"
  is_date "$d_use" || d_use="$(today)"

  # extract + normalize changelog block lines
  extract_changelog_lines "$in_s" "$chlog"

  # No bump: keep changelog exactly (already normalized: no blanks/#-only)
  cp "$chlog" "$chlog2" 2>/dev/null || : > "$chlog2"

  # write canonical header
  write_canon_header "$hdr" "$component" "$file_field" "$role" "$v_use" "$d_use" "$status" "$v_use" "$chlog2"

  # stitch output
  cat "$hdr" "$body" > "$out" || die "falha gerando $f"

  if cmp -s "$in_s" "$out" 2>/dev/null; then
    log "OK: normalize nao necessario: $f"
    rm -f "$tmp_base".* 2>/dev/null || true
    return 0
  fi

  # apply (transacional)
  mv "$out" "${f}.new" || die "falha preparando swap: $f.new"
  sh -n "${f}.new" 2>/dev/null || { rm -f "${f}.new"; die "sh -n falhou em ${f}.new"; }
  chmod 755 "${f}.new" 2>/dev/null || true
  mv "${f}.new" "$f" || die "falha no swap final: $f"

  log "OK: normalized: $f"
  rm -f "$tmp_base".* 2>/dev/null || true
}

check_one(){
  f="$1"
  [ -f "$f" ] || die "arquivo nao existe: $f"

  tmp_base="/tmp/avp_meta_chk_$$"
  in_s="${tmp_base}.in"
  body="${tmp_base}.body"
  chlog="${tmp_base}.chlog"
  hdr="${tmp_base}.hdr"
  out="${tmp_base}.out"

  tr -d "\r" < "$f" > "$in_s" || die "falha lendo $f"
  extract_body "$in_s" "$body"
  extract_changelog_lines "$in_s" "$chlog"

  component="$(extract_kv "$in_s" "# Component")"; [ -n "$component" ] || component="AVP-META"
  role="$(extract_kv "$in_s" "# Role")"; [ -n "$role" ] || role="(unspecified)"
  status="$(extract_kv "$in_s" "# Status")"; [ -n "$status" ] || status="stable"
  file_field="$(extract_kv "$in_s" "# File")"; [ -n "$file_field" ] || file_field="$(basename "$f")"

  vd="$(extract_version "$in_s")"
  v_hdr="$(echo "$vd" | cut -d'|' -f1)"
  d_hdr="$(echo "$vd" | cut -d'|' -f2)"
  sv="$(extract_script_ver "$in_s")"
  v_use="$sv"; [ -n "$v_use" ] || v_use="$v_hdr"; [ -n "$v_use" ] || v_use="v0.0.0"
  v_use="$(norm_ver "$v_use" 2>/dev/null || true)"; [ -n "$v_use" ] || v_use="v0.0.0"
  d_use="$d_hdr"; is_date "$d_use" || d_use="$(today)"

  write_canon_header "$hdr" "$component" "$file_field" "$role" "$v_use" "$d_use" "$status" "$v_use" "$chlog"
  cat "$hdr" "$body" > "$out" || die "falha gerando check para $f"

  if cmp -s "$in_s" "$out" 2>/dev/null; then
    log "OK: canonical: $f"
    rm -f "$tmp_base".* 2>/dev/null || true
    return 0
  fi

  warn "NEEDS_NORMALIZE: $f"
  rm -f "$tmp_base".* 2>/dev/null || true
  return 2
}

apply_spec(){
  spec="$1"
  [ -f "$spec" ] || die "spec nao existe: $spec"
  need_jq

  n="$(jq -r '.files | length' "$spec" 2>/dev/null || echo 0)"
  [ "$n" -ge 1 ] 2>/dev/null || die "spec invalido: .files vazio"

  i=0
  while [ "$i" -lt "$n" ]; do
    path="$(jq -r ".files[$i].path" "$spec")"
    ver="$(jq -r ".files[$i].version" "$spec")"
    date_="$(jq -r ".files[$i].date" "$spec")"
    status="$(jq -r ".files[$i].status // \"stable\"" "$spec")"
    component="$(jq -r ".files[$i].component // \"\"" "$spec")"
    role="$(jq -r ".files[$i].role // \"\"" "$spec")"

    [ -n "$path" ] && [ "$path" != "null" ] || die "spec: files[$i].path invalido"
    [ -f "$path" ] || die "arquivo nao existe: $path"

    ver="$(norm_ver "$ver" 2>/dev/null || true)" || true
    [ -n "$ver" ] || die "spec: version invalida em files[$i]"
    is_date "$date_" || die "spec: date invalida (YYYY-MM-DD) em files[$i]"

    [ -n "$component" ] || component="$(extract_kv "$path" "# Component")"
    [ -n "$component" ] || component="AVP-META"
    [ -n "$role" ] || role="$(extract_kv "$path" "# Role")"
    [ -n "$role" ] || role="(unspecified)"

    file_field="$(extract_kv "$path" "# File")"
    [ -n "$file_field" ] || file_field="$(basename "$path")"

    tmp_base="/tmp/avp_meta_apply_$$_${i}"
    in_s="${tmp_base}.in"
    body="${tmp_base}.body"
    chlog="${tmp_base}.chlog"
    chlog_new="${tmp_base}.chlog_new"
    items="${tmp_base}.items"
    hdr="${tmp_base}.hdr"
    out="${tmp_base}.out"

    tr -d "\r" < "$path" > "$in_s" || die "falha lendo $path"
    extract_body "$in_s" "$body"
    extract_changelog_lines "$in_s" "$chlog"

    # items from spec.changelog[]
    : > "$items"
    jq -r ".files[$i].changelog[]? // empty" "$spec" > "$items" 2>/dev/null || true

    apply_entry_into_changelog "$chlog" "$ver" "$date_" "$items" "$chlog_new"

    write_canon_header "$hdr" "$component" "$file_field" "$role" "$ver" "$date_" "$status" "$ver" "$chlog_new"
    cat "$hdr" "$body" > "$out" || die "falha gerando $path"

    mv "$out" "${path}.new" || die "falha preparando swap: ${path}.new"
    sh -n "${path}.new" 2>/dev/null || { rm -f "${path}.new"; die "sh -n falhou em ${path}.new"; }
    chmod 755 "${path}.new" 2>/dev/null || true
    mv "${path}.new" "$path" || die "falha no swap final: $path"

    log "OK: applied meta: $path => $ver ($date_)"
    rm -f "$tmp_base".* 2>/dev/null || true

    i=$((i+1))
  done
}

print_spec_template(){
cat <<'J'
{
  "files": [
    {
      "path": "avp-pol.sh",
      "version": "v1.3.18",
      "date": "2026-02-16",
      "status": "stable",
      "component": "AVP-POL",
      "role": "Policy engine",
      "changelog": [
        "* FIX: descreva aqui",
        "* CHG: descreva aqui"
      ]
    }
  ]
}
J
}

usage(){
cat <<'U'
Usage:
  avp-meta.sh --help
  avp-meta.sh --print-spec-template

  # Apenas verificar (sem escrever):
  avp-meta.sh --check --targets <file> [<file>...]

  # Normalizar (sem bump):
  avp-meta.sh --normalize --targets <file> [<file>...]

  # Aplicar bump + changelog via spec JSON (jq obrigatório):
  avp-meta.sh --apply --spec /caminho/spec.json

Notas:
- O "bloco canônico" segue o padrão do avp-diag.sh (header + changelog + SCRIPT_VER).
- Regra canônica: 1 linha em branco APÓS 'set -u' (antes do corpo do código).
- O script NÃO altera o corpo do código; ele apenas reescreve a área de metadata.
U
}

MODE=""
SPEC=""
TARGETS=""

[ $# -ge 1 ] || { usage; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --print-spec-template) MODE="print"; shift ;;
    --check) MODE="check"; shift ;;
    --normalize) MODE="normalize"; shift ;;
    --apply) MODE="apply"; shift ;;
    --spec) SPEC="${2:-}"; shift 2 ;;
    --targets) shift; TARGETS="$*"; break ;;
    *) die "arg invalido: $1 (use --help)" ;;
  esac
done

case "$MODE" in
  print) print_spec_template; exit 0 ;;
  check)
    [ -n "${TARGETS:-}" ] || die "--check requer --targets"
    rc=0
    for f in $TARGETS; do
      check_one "$f" || rc=$?
    done
    exit "$rc"
    ;;
  normalize)
    [ -n "${TARGETS:-}" ] || die "--normalize requer --targets"
    for f in $TARGETS; do
      normalize_one "$f"
    done
    exit 0
    ;;
  apply)
    [ -n "${SPEC:-}" ] || die "--apply requer --spec"
    apply_spec "$SPEC"
    exit 0
    ;;
  *) die "modo ausente/invalido (use --help)" ;;
esac
