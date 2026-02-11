#!/bin/sh
# =============================================================
# AutoVPN Platform (AVP)
# Component : AVP-SMOKE
# File      : avp-smoke.sh
# Role      : Pre/Post/Hotfix gates (baseline + patch-safety + syntax + JSON probes + WebUI ASP gate)
# Version   : v1.4.9 (2026-02-08)
# Status    : stable
# =============================================================
#
# CHANGELOG
# - v1.4.9 (2026-02-08)
#   * FIX: BASHISM gate nao reprova local (busybox ash); continua bloqueando declare/typeset/function/source
# - v1.4.8 (2026-01-26)
#   * VERSION: bump patch (pos harden canônico + STRICT defaults)
# - v1.4.7 (2026-01-26)
#   * CHG  : VER gate aceita bloco canônico entre SCRIPT_VER e set -u (PATH/hash) com 1 linha em branco antes/depois
# - v1.4.6 (2026-01-20)
#   * POLISH: dedupe do PATH no bootstrap (higiene; log menor)
# - v1.4.5 (2026-01-20)
#   * POLISH: HELP corrige semantica do --hotfix (EXPECT recomendado; dirty auto-fill; clean warn/best-effort).
# - v1.4.4 (2026-01-20)
#   * POLISH: git_cmd agora blinda pager (core.pager=cat + pager.diff=false + --no-pager) — nunca “limpar tela”.
#   * POLISH: HELP/docs alinhados ao --hotfix (EXPECT recomendado; dirty=auto-fill; clean=warn/best-effort).
#   v1.4.3 (2026-01-20):
#   * HOTFIX gate: AVP_SMOKE_EXPECT opcional; auto-fill via git diff --name-only quando dirty; clean=best-effort
# - v1.4.2 (2026-01-20)
#   * FIX  : patch-check volta a ser opcional em --pre/--post/--hotfix (só roda com AVP_SMOKE_PATCH)
# - v1.4.1 (2026-01-20)
#   * HARDEN: --patch-check agora valida parse completo (headers vs "Checking patch")
# - v1.4.0 (2026-01-18)
#   * FEAT : consolida gates novos, auditoria e targets dinamicos como MINOR
#   * FEAT: modo AUDIT (AVP_SMOKE_AUDIT=1) forca STRICT_VER/STRICT_ORDER e pula exec de gates (POL/ACTION)
#   * FEAT: DEFAULT_TARGETS agora auto-detecta avp-*.sh + hooks + avp/www/*.asp (ordena se sort existir)
#   * FEAT: VER gate reforcado: ordem oficial (CHANGELOG -> SCRIPT_VER -> set -u) + STRICT_ORDER (+ modo AUDIT forca)
#   * FEAT: gate_syntax acumula falhas VER e lista arquivos; AUDIT SUMMARY (contadores) quando AUDIT=1
#   * POLISH: banner mostra AUDIT/STRICT_* e AUDIT_EFFECTIVE quando auditoria ativa
# - v1.3.20 (2026-01-18)
#   * POLISH: padroniza SCRIPT_VER + set -u (ordem oficial) e remove linhas em branco desnecessarias
# - v1.3.19 (2026-01-18)
#   * FIX : HOTFIX EXPECT nao falha quando nao ha dirty tracked (tree limpa); apenas WARN.
# - v1.3.18 (2026-01-18)
#   * TUNE: PROBE ACTION: token_get sem token agora pode ser SKIP limpo (mesmo em strict),
#           exceto se AVP_SMOKE_ACTION_TOKEN_REQUIRED=1.
# - v1.3.17 (2026-01-18)
#   * POLISH: bump+changelog (higiene operacional).
# - v1.3.16 (2026-01-18)
#   * FIX : --patch-check agora aceita patch via AVP_SMOKE_PATCH sem args (set -u safe).
# - v1.3.15 (2026-01-18)
#   * FIX : --patch-check não falha quando não há args; troca "${#}" por "$#" (set -u safe).
# - v1.3.14 (2026-01-16)
#   * FIX : remove bloco legado do banner (pre-init) que quebrava com set -u (_smoke_* unset).
# - v1.3.13 (2026-01-16)
#   * TUNE: banner agora mostra REPO=<rev-parse --short=12> DIRTY=<0|1> FILEHASH=<git hash-object>.
#   * DROP: remove smoke_hash (sha256/md5/cksum) — usa git como fonte unica.
# - v1.3.12 (2026-01-15)
#   * FIX : banner sempre imprime HASH=... ou HASH=unavailable (resolve path via ./file e fallback ROOT(/jffs/scripts)).
# - v1.3.11 (2026-01-15)
#   * ADD : banner de auditoria (SCRIPT_VER + file + HASH best-effort).
#   * NOTE: hash usa sha256sum/md5sum; fallback cksum (BusyBox).
# - v1.3.10 (2026-01-15)
#   * TUNE: Probes POL/ACTION agora são BEST-EFFORT por padrão (WARN ao falhar), evitando bloquear patch por estado runtime.
#           Para tornar probes obrigatórios: AVP_SMOKE_PROBES_STRICT=1
#   AVP_SMOKE_ACTION_TOKEN_REQUIRED=1 exige token no ACTION (token_get sem token vira FAIL; default=0 => SKIP limpo)
# - v1.3.9 (2026-01-15)
#   * FIX : BASHISM gate agora ignora POSIX charclass ([[:...:]]) e evita falso-positivo em sed/awk.
# - v1.3.8 (2026-01-15)
#   * DEFAULTS: MAXLEN agora = 200 (anti-wrap recomendado); LEN_STRICT segue WARN (0)
#   * CHANGE : --hotfix prefere AVP_SMOKE_EXPECT; se dirty auto-preenche via git diff --name-only; se clean apenas WARN (best-effort)
#              bypass consciente: AVP_SMOKE_ALLOW_EMPTY_EXPECT=1
#   * ADD    : AVP_SMOKE_BASHISM_STRICT=1 (modo estrito opcional; default = normal)
#   * TUNE   : ordem dos gates no --post/--hotfix: git diff --check mais cedo (reduz retrabalho)
#   * TUNE   : mensagens mais cirúrgicas para orientar o operador (pre/post/hotfix)
# - v1.3.7 (2026-01-15)
#   * FIX : SCRIPT_VER realmente definido no arquivo (após set -u)
# - v1.3.6 (2026-01-15)
#   * ADD : SCRIPT_VER no smoke (padrao DTP)
#   * FIX : gate_crlf refeito (detecção robusta de CR em BusyBox awk)
#   * ADD : gate_shebang (#!/bin/sh) para alvos shell
#   * ADD : gate_bashisms (heurística) para capturar tokens não-POSIX
#   * ADD : gate_line_len (anti-wrap) com limiar configurável
# - v1.3.5 (2026-01-15)
#   * ADD : AVP_SMOKE_ROOT + autodetecção de repo (fallback útil para snapshots/tar)
#   * FIX : gate_perms vira zero-intervenção por padrão (valida +x; corrige só se AVP_SMOKE_FIX_PERMS=1)
#   * ADD : gates de higiene de texto (CRLF/BOM) para .sh/.asp (catch precoce de conversão de linha)
#   * TUNE: mensagens de erro agora apontam envs (AVP_SMOKE_ROOT / AVP_SMOKE_FIX_PERMS)
# - v1.3.4 (2026-01-15)
#   * FIX : suite padrão agora inclui TODOS os avp-*.sh do topo (inclui avp-lib.sh/avp-backup.sh/avp-diag.sh).
# - v1.3.3 (2026-01-15)
#   * ADD : alvos (targets) por argumento/env: permite rodar gates gerais ou focar em arquivos específicos (sh/asp).
#   * ADD : gate opcional de patch (git apply --check) via modo --patch-check ou AVP_SMOKE_PATCH.
#   * ADD : gate git diff --check em --post/--hotfix (pega whitespace/EOF) + opção de estrito por env.
#   * ADD : validação opcional de versão (header Version vs SCRIPT_VER) para scripts alvo (warn por padrão).
#   * TUNE: bootstrap reforçado (PATH + no-pager) e lista padrão inclui services-start/post-mount.
# - v1.3.2 (2026-01-07)
#   * CHANGE: substitui o modo --pre-hotfix pelo modo --hotfix (bypass explícito do baseline limpo)
#   * TUNE  : textos/help agora referenciam --hotfix (e continuam orientando --post quando já está editando)
# - v1.3.1 (2026-01-07)
#   * FIX: implementa EXPECT sem depender de awk; comparação por lista (ordem-insensível se sort existir)
#   * TUNE: mensagens de erro mais claras para --pre/--post/--hotfix
# - v1.3.0 (2026-01-07)
#   * ADD: modo --hotfix (bypass explícito do baseline limpo) + EXPECT opcional p/ arquivos sujos
#   * TUNE: mensagens orientando --post quando a árvore já está suja por edição em andamento
# - v1.2.0 (2026-01-07)
#   * ADD: gate do avp.asp (WEBUI_VER/pill): header Version vs const WEBUI_VER (+ sanity changelog)
#   * TUNE: mantém bootstrap robusto (PATH + binscan real) e gates POL/ACTION
# - v1.1.0 (2026-01-07)
#   * FIX: bootstrap robusto (PATH + busca por binários reais) p/ cron/CGI/non-interactive
#   * ADD: gates --pre/--post com foco em baseline limpo, sintaxe e JSON parseável (se jq existir)
#   * ADD: prova “rápida” de POL/ACTION (somente JSON parseável + contratos mínimos)
# - v1.0.0 (2026-01-06)
#   * ADD: initial release
# =============================================================

SCRIPT_VER="v1.4.9"
export PATH="/jffs/scripts:/opt/bin:/opt/sbin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH:-}"
hash -r 2>/dev/null || true
set -u

ts()   { date "+%Y-%m-%d %H:%M:%S"; }
log()  { echo "$(ts) [SMOKE] $*"; }
warn() { echo "$(ts) [SMOKE] WARN: $*" >&2; }
err()  { echo "$(ts) [SMOKE] ERR: $*"  >&2; }
die()  { err "$*"; exit 1; }

# -------------------------------------------------------------
# DEFAULTS CANÔNICOS (operacional / anti-erro)
# -------------------------------------------------------------
# - MAXLEN default = 200 (anti-wrap)
# - LEN_STRICT default = 0 (WARN)
# - Bashism default = normal (estrito só via env)
# - Perms default = zero-intervenção (fix só via env)
# - CRLF/BOM = FAIL sempre
# - Probes (POL/ACTION) = BEST-EFFORT por default (WARN ao falhar)
#   -> Para tornar probes obrigatórios (FAIL): AVP_SMOKE_PROBES_STRICT=1
# -------------------------------------------------------------

# ---------------------------
# BOOTSTRAP (sempre no topo)
# ---------------------------

dedupe_path() {
  _in="$1"; _out="";
  _IFS="$IFS"; IFS=":";
  for _p in $_in; do
    [ -n "${_p:-}" ] || continue;
    case ":$_out:" in
      *":$_p:"*) : ;;
      *) _out="${_out:+$_out:}$_p" ;;
    esac;
  done;
  IFS="$_IFS";
  echo "$_out";
}
PATH="$(dedupe_path "$PATH")"; export PATH

export GIT_PAGER=cat PAGER=cat

find_bin() {
  _name="$1"; shift
  for _p in "$@"; do
    [ -n "${_p:-}" ] && [ -x "$_p" ] && { echo "$_p"; return 0; }
  done
  if command -v "$_name" >/dev/null 2>&1; then
    _p="$(command -v "$_name" 2>/dev/null || true)"
    [ -n "$_p" ] && [ -x "$_p" ] && { echo "$_p"; return 0; }
  fi
  return 1
}

GIT_BIN="$(find_bin git \
  /jffs/scripts/git /opt/bin/git \
  /usr/bin/git /usr/sbin/git /bin/git /sbin/git 2>/dev/null || true)"
JQ_BIN="$(find_bin jq \
  /opt/bin/jq /jffs/scripts/jq \
  /usr/bin/jq /usr/sbin/jq /bin/jq /sbin/jq 2>/dev/null || true)"

have_git(){ [ -n "${GIT_BIN:-}" ] && [ -x "${GIT_BIN:-}" ]; }
have_jq(){  [ -n "${JQ_BIN:-}"  ] && [ -x "${JQ_BIN:-}"  ]; }

git_cmd() {
  have_git || die "git nao encontrado (necessario...e repo)."

  # REGRA INVIOLAVEL: nunca abrir pager/less (nem “limpar a tela”)
  # - core.pager=cat + pager.diff=false garantem que diff/stat/check nunca invocam pager
  "$GIT_BIN" \
    -c color.ui=false \
    -c core.pager=cat \
    -c pager.diff=false \
    --no-pager \
    "$@"
}

jq_cmd()  { have_jq  || return 1; "$JQ_BIN"  "$@"; }

ROOT="${AVP_SMOKE_ROOT:-/jffs/scripts}"
if [ -d "$ROOT" ]; then
  cd "$ROOT" 2>/dev/null || die "nao consegui entrar em $ROOT (ajuste AVP_SMOKE_ROOT)"
else
  die "ROOT inexistente: $ROOT (ajuste AVP_SMOKE_ROOT)"
fi
if [ ! -d .git ] && [ -d "./scripts/.git" ]; then
  cd "./scripts" 2>/dev/null || die "nao consegui entrar em $ROOT/scripts"
  log "ROOT auto-detect: usando $(pwd)"
fi

_build_default_targets() {
  _t=""
  # avp-*.sh (ordenado quando sort existir)
  _sh="$(ls -1 avp-*.sh 2>/dev/null | { command -v sort >/dev/null 2>&1 && sort || cat; } | tr "\n" " ")"
  [ -n "${_sh:-}" ] && _t="$_t $_sh"

  # hooks fixos
  [ -f services-start ] && _t="$_t services-start"
  [ -f post-mount ]     && _t="$_t post-mount"

  # ASPs (ordenado quando sort existir)
  _asp="$(ls -1 avp/www/*.asp 2>/dev/null | { command -v sort >/dev/null 2>&1 && sort || cat; } | tr "\n" " ")"
  [ -n "${_asp:-}" ] && _t="$_t $_asp"

  echo "$_t" | sed "s/^[[:space:]]\+//; s/[[:space:]]\+$//; s/[[:space:]]\+/ /g"
}

DEFAULT_TARGETS="$(_build_default_targets)"

MODE="${1:-}"
[ -n "$MODE" ] || MODE="--pre"

shift 0 2>/dev/null || true

case "$MODE" in
  --pre|--post|--hotfix|--patch-check|--help|-h)
    shift 1 2>/dev/null || true
    ;;
  *)
    set -- "$MODE" "$@"
    MODE="--pre"
    ;;
esac

TARGETS=""
if [ "$#" -gt 0 ]; then
  TARGETS="$*"
elif [ -n "${AVP_SMOKE_TARGETS:-}" ]; then
  TARGETS="$AVP_SMOKE_TARGETS"
else
  TARGETS="$DEFAULT_TARGETS"
fi

# ---------------------------
# Helpers de gate
# ---------------------------
ensure_repo() {
  [ -d .git ] || die "nao achei .git em $(pwd). Dica: exporte AVP_SMOKE_ROOT=/jffs/scripts (ou o root correto)."
}

gate_perms() {
  _fix="${AVP_SMOKE_FIX_PERMS:-0}"
  _fail=0
  _skip="${AVP_SMOKE_PERMS_SKIP:-avp-lib.sh}"

  for f in $TARGETS; do
    case "$f" in
      *.sh|services-start|post-mount)
        [ -f "$f" ] || continue
        echo " $_skip " | grep -q " $f " && continue
        if [ ! -x "$f" ]; then
          if [ "$_fix" = "1" ]; then
            chmod 755 "$f" 2>/dev/null || true
            log "PERMS gate: corrigido chmod 755 em $f"
          else
            err "PERMS gate: $f sem bit de exec (+x). Use AVP_SMOKE_FIX_PERMS=1 para corrigir."
            _fail=1
          fi
        fi
        ;;
    esac
  done

  [ "$_fail" -eq 0 ] || exit 1
}

gate_baseline_clean() {
  ensure_repo
  log "git status -sb"
  git_cmd status -sb || die "git status falhou"
  if ! git_cmd diff --name-only --exit-code >/dev/null 2>&1; then
    die "PRE gate: working tree sujo (tracked). Se ja está no meio da edicao, rode --post. Se for hotfix minúsculo, rode --hotfix com AVP_SMOKE_EXPECT."
  fi
}

gate_baseline_report_only() {
  ensure_repo
  log "git status -sb"
  git_cmd status -sb || die "git status falhou"
}

_norm_list() {
  tr ' ' '\n' | sed '/^[[:space:]]*$/d; s/[[:space:]]\+$//' \
    | { command -v sort >/dev/null 2>&1 && sort || cat; }
}

gate_expect_dirty() {
  _exp="${AVP_SMOKE_EXPECT:-}"
  _allow_empty="${AVP_SMOKE_ALLOW_EMPTY_EXPECT:-0}"

  if [ -z "$_exp" ]; then
    # HOTFIX: auto-fill EXPECT a partir do dirty (evita exigir operador)
    _d="$(git_cmd diff --name-only 2>/dev/null || true)"
    _d_n="$(printf "%s\n" "$_d" | _norm_list)"
    if [ -n "${_d_n:-}" ]; then
      _exp="$_d_n"
      log "HOTFIX: AVP_SMOKE_EXPECT auto=$_exp"
    else
      if [ "$_allow_empty" = "1" ]; then
        warn "HOTFIX: EXPECT vazio permitido por AVP_SMOKE_ALLOW_EMPTY_EXPECT=1 (menos seguro)"
        return 0
      fi
      warn "HOTFIX gate: AVP_SMOKE_EXPECT ausente e árvore limpa; seguindo best-effort"
      return 0
    fi
  fi

  _dirty="$(git_cmd diff --name-only 2>/dev/null || true)"
  _dirty_n="$(printf "%s\n" "$_dirty" | _norm_list)"
  _exp_n="$(printf "%s\n" "$_exp"   | _norm_list)"

  # Se a arvore esta limpa, nao faz sentido falhar por EXPECT mismatch.
  if [ -z "$_dirty_n" ]; then
    warn "HOTFIX: working tree limpa (dirty=<none>); EXPECT ignorado. Dica: use --pre quando possivel."
    return 0
  fi

  [ "$_dirty_n" = "$_exp_n" ] || {
    err "EXPECT mismatch (hotfix):"
    err "  dirty   = $( [ -n \"$_dirty_n\" ] && printf \"%s\" \"$_dirty_n\" | tr \"\\n\" \" \" || printf \"<none>\" )"
    err "  esperado= $( [ -n \"$_exp_n\" ]   && printf \"%s\" \"$_exp_n\"   | tr \"\\n\" \" \" || printf \"<none>\" )"
    err "  Dica: ajuste AVP_SMOKE_EXPECT p/ refletir exatamente o dirty tracked."
    exit 1
  }
  log "EXPECT OK"
}

gate_git_diff_check() {
  ensure_repo
  _out="$(git_cmd diff --check 2>/dev/null || true)"
  [ -z "$_out" ] || {
    err "git diff --check encontrou problemas (whitespace/EOF):"
    printf '%s\n' "$_out" >&2
    err "Dica: corrija whitespace/EOF antes de continuar (preferir NEW determinístico + diff -u normalizado)."
    exit 1
  }
}

_extract_ver3() { sed -n 's/.*\(v[0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p'; }

_extract_header_version_sh() {
  _f="$1"
  grep -m1 -E '^[[:space:]]*#[[:space:]]*Version[[:space:]]*:[[:space:]]*v[0-9]+\.[0-9]+\.[0-9]+' "$_f" 2>/dev/null | _extract_ver3 | head -n 1
}

_extract_script_ver_var() {
  _f="$1"
  grep -m1 -E '^[[:space:]]*SCRIPT_VER="v[0-9]+\.[0-9]+\.[0-9]+"' "$_f" 2>/dev/null | _extract_ver3 | head -n 1
}

gate_version_consistency_sh() {
  _f="$1"
  _strict="${AVP_SMOKE_STRICT_VER:-1}"
  _order_strict="${AVP_SMOKE_STRICT_ORDER:-1}"
  _audit="${AVP_SMOKE_AUDIT:-0}"

  # auditoria: torna tudo estrito sem precisar exportar 2 vars
  if [ "$_audit" = "1" ]; then
    _strict=1
    _order_strict=1
  fi

  _hv="$(_extract_header_version_sh "$_f")"
  [ -n "$_hv" ] || { warn "VER gate: $_f sem header Version"; [ "$_audit" = "1" ] && return 1; return 0; }

  _fail=0

  # --- ORDEM OFICIAL ---
  _sv_line="$(grep -n -m1 -E "^[[:space:]]*SCRIPT_VER=\"v[0-9]+\.[0-9]+\.[0-9]+\"" "$_f" 2>/dev/null || true)"
  if [ -z "$_sv_line" ]; then
    if [ "$_order_strict" = "1" ]; then
      warn "VER gate: $_f sem SCRIPT_VER (ordem oficial)"
      return 1
    fi
    warn "VER gate: $_f sem SCRIPT_VER (ok se ainda nao padronizado)"
    return 0
  fi

  _sv_nr="${_sv_line%%:*}"
  _sv="$(_extract_script_ver_var "$_f")"

  _next="$(sed -n "$((${_sv_nr:-0}+1))p" "$_f" 2>/dev/null || true)"
    # allow canonical env block exactly:
    # <blank> SCRIPT_VER; export PATH; hash -r; set -u; <blank>
    _p="$(sed -n "$((_sv_nr-1))p" "$_f" 2>/dev/null || true)"
    _l1="$(sed -n "$((_sv_nr+1))p" "$_f" 2>/dev/null || true)"
    _l2="$(sed -n "$((_sv_nr+2))p" "$_f" 2>/dev/null || true)"
    _l3="$(sed -n "$((_sv_nr+3))p" "$_f" 2>/dev/null || true)"
    _l4="$(sed -n "$((_sv_nr+4))p" "$_f" 2>/dev/null || true)"

    _pt="$(printf "%s" "$_p"  | sed "s/^[ \t]*//;s/[ \t]*$//")"
    _t1="$(printf "%s" "$_l1" | sed "s/^[ \t]*//;s/[ \t]*$//")"
    _t2="$(printf "%s" "$_l2" | sed "s/^[ \t]*//;s/[ \t]*$//")"
    _t3="$(printf "%s" "$_l3" | sed "s/^[ \t]*//;s/[ \t]*$//")"
    _t4="$(printf "%s" "$_l4" | sed "s/^[ \t]*//;s/[ \t]*$//")"

    if [ -z "${_pt:-}" ] \
      && [ "$_t1" = "export PATH=\"/jffs/scripts:/opt/bin:/opt/sbin:/usr/bin:/usr/sbin:/bin:/sbin:\${PATH:-}\"" ] \
      && [ "$_t2" = "hash -r 2>/dev/null || true" ] \
      && [ "$_t3" = "set -u" ] \
      && [ -z "${_t4:-}" ]; then
      _next="set -u"
    fi

  if [ "$_next" != "set -u" ]; then
    warn "VER gate: $_f ordem oficial violada (set -u deve vir logo abaixo do SCRIPT_VER)"
    _fail=1
  fi

  _chg_nr="$(grep -n -m1 "^# CHANGELOG" "$_f" 2>/dev/null | cut -d: -f1 || true)"
  if [ -n "$_chg_nr" ] && [ "$_sv_nr" -le "$_chg_nr" ]; then
    warn "VER gate: $_f ordem oficial violada (SCRIPT_VER deve vir apos # CHANGELOG)"
    _fail=1
  fi

  if [ "$_hv" != "$_sv" ]; then
    warn "VER gate: mismatch em $_f (header=$_hv vs SCRIPT_VER=$_sv)"
    [ "$_strict" = "1" ] && _fail=1
  fi

  [ "$_fail" -eq 0 ] && return 0
  return 1
}

gate_syntax() {
  _fail_syn=0
  _fail_ver=0
  _bad_ver=""
  _n_syn=0
  _n_syn_fail=0
  _n_ver_fail=0

  for f in $TARGETS; do
    case "$f" in
      *.sh|services-start|post-mount)
        [ -f "$f" ] || continue
        _n_syn=$((_n_syn+1))
        if sh -n "$f"; then
          :
        else
          _fail_syn=1
          _n_syn_fail=$((_n_syn_fail+1))
        fi

        if ! gate_version_consistency_sh "$f"; then
          _fail_ver=1
          _n_ver_fail=$((_n_ver_fail+1))
          _bad_ver="$_bad_ver $f"
        fi
        ;;
    esac
  done

  [ "$_fail_syn" -eq 0 ] || die "SINTAXE gate: sh -n falhou (erro sintatico). Dica: rever o ultimo hunk/patch e reaplicar micro-patch."

  if [ "$_fail_ver" -ne 0 ]; then
    _bad_ver="$(echo "$_bad_ver" | sed "s/^[[:space:]]\+//; s/[[:space:]]\+$//; s/[[:space:]]\+/ /g")"
    die "VER gate: falhou em: $_bad_ver"
  fi

  if [ "${AUDIT_MODE:-0}" = "1" ]; then
    log "AUDIT SUMMARY: syn_checked=$_n_syn syn_fail=$_n_syn_fail ver_fail=$_n_ver_fail exec_skipped=POL,ACTION"
  fi
}

gate_crlf() {
  for f in $TARGETS; do
    case "$f" in
      *.sh|*.asp|services-start|post-mount)
        [ -f "$f" ] || continue
        if awk 'index($0, sprintf("%c", 13)) { exit 0 } END { exit 1 }' "$f" 2>/dev/null; then
          err "CRLF gate: $f contem CR (carriage return). Normalize p/ LF antes do patch/commit."
          exit 1
        fi
        ;;
    esac
  done
}

_hex3() {
  _f="$1"
  dd if="$_f" bs=1 count=3 2>/dev/null | {
    if command -v hexdump >/dev/null 2>&1; then
      hexdump -v -e '3/1 "%02x"'
    else
      od -An -tx1 2>/dev/null | tr -d ' \n'
    fi
  }
}

gate_bom() {
  for f in $TARGETS; do
    case "$f" in
      *.sh|*.asp|services-start|post-mount)
        [ -f "$f" ] || continue
        _h="$(_hex3 "$f" 2>/dev/null || true)"
        [ "$_h" = "efbbbf" ] && {
          err "BOM gate: $f tem UTF-8 BOM (EF BB BF). Remova BOM (UTF-8 sem BOM)."
          exit 1
        }
        ;;
    esac
  done
}

gate_shebang() {
  _no="${AVP_SMOKE_NO_SHEBANG:-0}"
  [ "$_no" = "1" ] && return 0

  _skip="${AVP_SMOKE_SHEBANG_SKIP:-}"

  for f in $TARGETS; do
    case "$f" in
      *.sh|services-start|post-mount)
        [ -f "$f" ] || continue
        [ -n "$_skip" ] && echo " $_skip " | grep -q " $f " && continue
        _h1="$(head -n 1 "$f" 2>/dev/null || true)"
        [ "$_h1" = "#!/bin/sh" ] || {
          err "SHEBANG gate: $f primeira linha deve ser '#!/bin/sh' (atual: '$_h1')"
          exit 1
        }
        ;;
    esac
  done
}

gate_bashisms() {
  _no="${AVP_SMOKE_NO_BASHISM:-0}"
  [ "$_no" = "1" ] && return 0

  _skip="${AVP_SMOKE_BASHISM_SKIP:-avp-smoke.sh}"
  _strict="${AVP_SMOKE_BASHISM_STRICT:-0}"

  _fail=0
  for f in $TARGETS; do
    case "$f" in
      *.sh|services-start|post-mount)
        [ -f "$f" ] || continue
        echo " $_skip " | grep -q " $f " && continue

        if awk 'BEGIN{rc=0}
          /^[[:space:]]*#/ {next}
          {
            p=index($0,"[[");
            if (p>0) {
              prev=(p>1?substr($0,p-1,1):"");
              nxt=substr($0,p+2,1);
              if (prev!="\\" && nxt!=":") { print NR ":" $0; rc=1; exit }
            }
          }
          END{exit rc}' "$f" >/tmp/avp_smoke_bashism_hits.$$ 2>/dev/null; then
          :
        else
          err "BASHISM gate: $f contém token [[ (use [ ... ])"
          head -n 3 /tmp/avp_smoke_bashism_hits.$$ >&2
          _fail=1
        fi

        if awk 'BEGIN{rc=0}
          /^[[:space:]]*#/ {next}
          {
            p=index($0,"]]");
            if (p>0) {
              prev=substr($0,p-1,1);
              if (prev!=":") { print NR ":" $0; rc=1; exit }
            }
          }
          END{exit rc}' "$f" >/tmp/avp_smoke_bashism_hits.$$ 2>/dev/null; then
          :
        else
          err "BASHISM gate: $f contém token ]]"
          head -n 3 /tmp/avp_smoke_bashism_hits.$$ >&2
          _fail=1
        fi

        if grep -nE '^[[:space:]]*(declare|typeset|function|source)[[:space:]]+' "$f" >/dev/null 2>&1; then
          err "BASHISM gate: $f contém declare/typeset/function/source"
          grep -nE '^[[:space:]]*(declare|typeset|function|source)[[:space:]]+' "$f" | head -n 3 >&2
          _fail=1
        fi

        if grep -nE '^[[:space:]]*for[[:space:]]*\(\(' "$f" >/dev/null 2>&1; then
          err "BASHISM gate: $f contém for (( (use while/seq)"
          grep -nE '^[[:space:]]*for[[:space:]]*\(\(' "$f" | head -n 3 >&2
          _fail=1
        fi

        if awk 'BEGIN{rc=0}
          /^[[:space:]]*#/ {next}
          { if (index($0,"<(")>0 || index($0,">(")>0) { print NR ":" $0; rc=1; exit } }
          END{exit rc}' "$f" >/tmp/avp_smoke_bashism_hits.$$ 2>/dev/null; then
          :
        else
          err "BASHISM gate: $f contém process substitution <( ) / >( ) (proibido no Merlin sh)"
          head -n 3 /tmp/avp_smoke_bashism_hits.$$ >&2
          _fail=1
        fi
        ;;
    esac
  done

  rm -f /tmp/avp_smoke_bashism_hits.$$ 2>/dev/null || true
  [ "$_fail" -eq 0 ] || exit 1
}

gate_line_len() {
  _max="${AVP_SMOKE_MAXLEN:-200}"
  _strict="${AVP_SMOKE_LEN_STRICT:-0}"

  for f in $TARGETS; do
    case "$f" in
      *.sh|*.asp|services-start|post-mount)
        [ -f "$f" ] || continue
        _hit="$(awk -v m="$_max" 'length($0)>m { print NR ":" length($0); exit 0 } END { exit 1 }' "$f" 2>/dev/null || true)"
        if [ -n "$_hit" ]; then
          if [ "$_strict" = "1" ]; then
            err "LEN gate: $f tem linha > $_max chars (NR:LEN=$_hit). Quebre em linhas menores."
            exit 1
          else
            warn "LEN gate: $f tem linha > $_max chars (NR:LEN=$_hit). Considere quebrar para reduzir risco de wrap."
          fi
        fi
        ;;
    esac
  done
}

json_parse_gate() {
  _j="$1"
  if have_jq; then
    printf '%s\n' "$_j" | jq_cmd -e . >/dev/null 2>&1 || return 1
    return 0
  fi
  [ -n "$_j" ] || return 1
  echo "$_j" | grep -q '^{.*}$' || return 1
  return 0
}

# ---------------------------
# Probes (BEST-EFFORT por default)
# ---------------------------
PROBES_STRICT="${AVP_SMOKE_PROBES_STRICT:-0}"
# Se 1, token_get SEM token vira FAIL. Default 0 = SKIP limpo.
ACTION_TOKEN_REQUIRED="${AVP_SMOKE_ACTION_TOKEN_REQUIRED:-0}"

AUDIT_MODE="${AVP_SMOKE_AUDIT:-0}"

audit_skip_probes() {
  [ "$AUDIT_MODE" = "1" ] && return 0
  return 1
}

probe_fail() {
  _name="$1"
  _why="$2"
  if [ "$PROBES_STRICT" = "1" ]; then
    die "PROBE $_name falhou (strict=1): $_why"
  fi
  warn "PROBE $_name falhou (best-effort): $_why"
  return 0
}

probe_skip() {
  _name="$1"
  _why="$2"
  # SKIP nunca deve matar o gate; é "estado ausente detectado" com mensagem limpa.
  warn "PROBE $_name SKIP: $_why"
  return 0
}

gate_pol_json() {
  if audit_skip_probes; then
    warn "AUDIT: POL JSON gates SKIP (nao executado): status --json | snapshot | profile list | device list"
    return 0
  fi
  echo " $TARGETS " | grep -q " avp-pol.sh " || return 0

  for cmd in \
    "./avp-pol.sh status --json" \
    "./avp-pol.sh snapshot" \
    "./avp-pol.sh profile list" \
    "./avp-pol.sh device list"
  do
    _l="$(sh -c "$cmd" 2>/dev/null | tail -n 1)"
    json_parse_gate "$_l" || return 1
  done
  return 0
}

gate_action_json_basic() {
  if audit_skip_probes; then
    warn "AUDIT: ACTION JSON gates SKIP (nao executado): token_get | status token=<token>"
    return 0
  fi
  echo " $TARGETS " | grep -q " avp-action.sh " || return 0

  _l="$(./avp-action.sh action=token_get 2>/dev/null | tail -n 1)"
  json_parse_gate "$_l" || return 1

  if have_jq; then
    _tok="$(printf '%s\n' "$_l" | jq_cmd -r '.data.token // empty' 2>/dev/null || true)"
    [ -n "$_tok" ] || return 2

    _s="$(./avp-action.sh action=status token="$_tok" 2>/dev/null | tail -n 1)"
    json_parse_gate "$_s" || return 3
    printf '%s\n' "$_s" | jq_cmd -e '.data.enabled? and .data.profile?' >/dev/null 2>&1 || return 4
  else
    warn "jq ausente: pulando checks de token/status unwrap (mantendo apenas JSON parseável básico)"
  fi
  return 0
}

# ---------------------------
# Gate WebUI ASP (avp.asp)
# ---------------------------
_extract_header_version_asp() {
  _f="$1"
  grep -m1 -E '^[[:space:]]*Version[[:space:]]*:[[:space:]]*v[0-9]+\.[0-9]+\.[0-9]+' "$_f" 2>/dev/null | sed -n 's/.*\(v[0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p' | head -n 1
}

gate_webui_asp() {
  _asp="${1:-avp/www/avp.asp}"
  [ -f "$_asp" ] || { warn "ASP gate: $_asp nao encontrado"; return 0; }

  _hv="$(_extract_header_version_asp "$_asp")"
  [ -n "$_hv" ] || die "ASP gate: nao achei 'Version : vX.Y.Z' no header"

  _wv="$(grep -m1 -E '^[[:space:]]*const[[:space:]]+WEBUI_VER[[:space:]]*=' "$_asp" 2>/dev/null | sed -n 's/.*\(v[0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p' | head -n 1)"
  [ -n "$_wv" ] || die "ASP gate: nao achei const WEBUI_VER"

  [ "$_hv" = "$_wv" ] || die "ASP gate: mismatch (header $_hv) vs (WEBUI_VER $_wv)"

  grep -q '<span[^>]*id="ver"' "$_asp" 2>/dev/null || warn "ASP gate: span id=ver nao encontrado (ok se layout mudou)"
  grep -qE "^[[:space:]]*-[[:space:]]+$_hv[[:space:]]*\\(" "$_asp" 2>/dev/null || warn "ASP gate: changelog sem entrada para $_hv"

  log "ASP gate: OK ($_asp Version=$_hv WEBUI_VER=$_wv)"
}

# ---------------------------
# Gate de patch (git apply --check)
# ---------------------------
gate_patch_check() {
  _p="${AVP_SMOKE_PATCH:-}"
  [ -n "${_p:-}" ] || _p="${1:-}"
  [ -n "${_p:-}" ] || die "PATCH gate: sem patch (use AVP_SMOKE_PATCH ou passe caminho)"
  [ -f "$_p" ] || die "PATCH gate: patch nao existe: $_p"

  log "PATCH gate: git apply --check -v $_p"
  _OUT="/tmp/avp_smoke_patchcheck.$$"
  git -c color.ui=false --no-pager apply --check -v "$_p" >"$_OUT" 2>&1
  _rc=$?
  cat "$_OUT"

  _hdr="$(grep -c '^--- a/' "$_p" 2>/dev/null || echo 0)"
  _chk="$(grep -c '^Checking patch ' "$_OUT" 2>/dev/null || echo 0)"
  rm -f "$_OUT" 2>/dev/null || true

  [ "$_rc" -eq 0 ] || die "PATCH gate: git apply --check falhou (rc=$_rc)"
  if [ "$_hdr" -gt 0 ] && [ "$_chk" -ne "$_hdr" ]; then
    die "PATCH gate: PARSE MISMATCH (headers=$_hdr checking=$_chk). Patch pode ter sido parcialmente parseado."
  fi
  log "OK: --patch-check"
}

# ---------------------------
# Main
# ---------------------------

_smoke_bn="${0##*/}"
_smoke_file="./$_smoke_bn"
[ -f "$_smoke_file" ] || _smoke_file="${ROOT%/}/$_smoke_bn"
_repo_head="unknown"
_repo_dirty="0"
_file_hash="unavailable"
if have_git; then
  _repo_head="$(git_cmd rev-parse --short=12 HEAD 2>/dev/null || true)"
  if git_cmd status --porcelain 2>/dev/null | head -n 1 | grep -q .; then _repo_dirty="1"; fi
  _file_hash="$(git_cmd hash-object "$_smoke_file" 2>/dev/null || true)"
fi
log "AVP-SMOKE ${SCRIPT_VER:-} (file=$_smoke_bn) REPO=${_repo_head:-unknown} DIRTY=${_repo_dirty:-0} FILEHASH=${_file_hash:-unavailable}"

log "MODE=$MODE"
: "${AVP_SMOKE_STRICT_VER:=1}"
: "${AVP_SMOKE_STRICT_ORDER:=1}"
log "AUDIT=${AVP_SMOKE_AUDIT:-0} STRICT_VER=${AVP_SMOKE_STRICT_VER} STRICT_ORDER=${AVP_SMOKE_STRICT_ORDER}"
if [ "${AVP_SMOKE_AUDIT:-0}" = "1" ]; then
  log "AUDIT_EFFECTIVE: STRICT_VER=1 STRICT_ORDER=1 (forcado)"
fi
log "PATH=$PATH"
have_git || warn "git nao encontrado via binscan"
have_jq  || warn "jq nao encontrado via binscan (ok, mas gates JSON ficam mais fracos)"
log "TARGETS=$TARGETS"

case "$MODE" in
  --pre)
    gate_crlf
    gate_bom
    gate_shebang
    gate_bashisms
    gate_line_len
    gate_perms
    gate_baseline_clean
    # PATCH gate é opcional: só roda quando AVP_SMOKE_PATCH estiver setado
    if [ -n "${AVP_SMOKE_PATCH:-}" ]; then
      gate_patch_check
    fi
    gate_syntax

    if ! gate_pol_json; then
      probe_fail "POL" "JSON invalido (ou comando falhou)"
    fi

    _rc=0
    gate_action_json_basic; _rc=$?
    case "$_rc" in
      0) : ;;
      1) probe_fail "ACTION" "token_get JSON invalido (ou comando falhou)" ;;
        2)
          if [ "$ACTION_TOKEN_REQUIRED" = "1" ]; then
            probe_fail "ACTION" "token_get sem token (token REQUIRED por AVP_SMOKE_ACTION_TOKEN_REQUIRED=1)"
          else
            probe_skip "ACTION" "token_get sem token (estado/config ausente; use AVP_SMOKE_ACTION_TOKEN_REQUIRED=1 para exigir)"
          fi
          ;;
      3) probe_fail "ACTION" "status JSON invalido" ;;
      4) probe_fail "ACTION" "status nao trouxe .data.enabled/.data.profile" ;;
      *) probe_fail "ACTION" "falha desconhecida rc=$_rc" ;;
    esac

    echo " $TARGETS " | grep -q " avp/www/avp.asp " && gate_webui_asp "avp/www/avp.asp" || true
  # --- EXTRA GATE: service-event (exists + exec + syntax) ---
  if [ -f "./service-event" ]; then
    [ -x "./service-event" ] || { echo "[SMOKE] ERR: service-event nao e executavel"; return 1; }
    sh -n "./service-event" >/dev/null 2>&1 || { echo "[SMOKE] ERR: sh -n falhou em service-event"; return 1; }
  else
    echo "[SMOKE] WARN: service-event ausente (baseline antigo ok)"
  fi
    log "OK: --pre (baseline limpo + patch-check opcional + sintaxe + probes best-effort + ASP gate)"
    ;;

  --hotfix)
    gate_crlf
    gate_bom
    gate_shebang
    gate_bashisms
    gate_line_len
    gate_perms
    gate_baseline_report_only
    gate_expect_dirty
    gate_git_diff_check
    # PATCH gate é opcional: só roda quando AVP_SMOKE_PATCH estiver setado
    if [ -n "${AVP_SMOKE_PATCH:-}" ]; then
      gate_patch_check
    fi
    gate_syntax

    if ! gate_pol_json; then
      probe_fail "POL" "JSON invalido (ou comando falhou)"
    fi

    _rc=0
    gate_action_json_basic; _rc=$?
    case "$_rc" in
      0) : ;;
      1) probe_fail "ACTION" "token_get JSON invalido (ou comando falhou)" ;;
        2)
          if [ "$ACTION_TOKEN_REQUIRED" = "1" ]; then
            probe_fail "ACTION" "token_get sem token (token REQUIRED por AVP_SMOKE_ACTION_TOKEN_REQUIRED=1)"
          else
            probe_skip "ACTION" "token_get sem token (estado/config ausente; use AVP_SMOKE_ACTION_TOKEN_REQUIRED=1 para exigir)"
          fi
          ;;
      3) probe_fail "ACTION" "status JSON invalido" ;;
      4) probe_fail "ACTION" "status nao trouxe .data.enabled/.data.profile" ;;
      *) probe_fail "ACTION" "falha desconhecida rc=$_rc" ;;
    esac

    echo " $TARGETS " | grep -q " avp/www/avp.asp " && gate_webui_asp "avp/www/avp.asp" || true
    log "OK: --hotfix (EXPECT obrigatório + diff --check + patch-check opcional + probes best-effort + ASP gate)"
    ;;

  --post)
    gate_crlf
    gate_bom
    gate_shebang
    gate_bashisms
    gate_line_len
    gate_perms
    ensure_repo
    gate_git_diff_check
    # PATCH gate é opcional: só roda quando AVP_SMOKE_PATCH estiver setado
    if [ -n "${AVP_SMOKE_PATCH:-}" ]; then
      gate_patch_check
    fi
    gate_syntax

    if ! gate_pol_json; then
      probe_fail "POL" "JSON invalido (ou comando falhou)"
    fi

    _rc=0
    gate_action_json_basic; _rc=$?
    case "$_rc" in
      0) : ;;
      1) probe_fail "ACTION" "token_get JSON invalido (ou comando falhou)" ;;
        2)
          if [ "$ACTION_TOKEN_REQUIRED" = "1" ]; then
            probe_fail "ACTION" "token_get sem token (token REQUIRED por AVP_SMOKE_ACTION_TOKEN_REQUIRED=1)"
          else
            probe_skip "ACTION" "token_get sem token (estado/config ausente; use AVP_SMOKE_ACTION_TOKEN_REQUIRED=1 para exigir)"
          fi
          ;;
      3) probe_fail "ACTION" "status JSON invalido" ;;
      4) probe_fail "ACTION" "status nao trouxe .data.enabled/.data.profile" ;;
      *) probe_fail "ACTION" "falha desconhecida rc=$_rc" ;;
    esac

    echo " $TARGETS " | grep -q " avp/www/avp.asp " && gate_webui_asp "avp/www/avp.asp" || true
  # --- EXTRA GATE: service-event (must exist) ---
  [ -f "./service-event" ] || { echo "[SMOKE] ERR: service-event ausente"; return 1; }
  [ -x "./service-event" ] || { echo "[SMOKE] ERR: service-event nao e executavel"; return 1; }
  sh -n "./service-event" >/dev/null 2>&1 || { echo "[SMOKE] ERR: sh -n falhou em service-event"; return 1; }

  # --- EXTRA GATE: last.json ts monotonic (entre rodadas do smoke) ---
  LAST="/www/user/avp-action-last.json"
  STT="/tmp/avp_smoke_lastjson_ts.state"
  cur_ts=""
  if [ -f "$LAST" ]; then
    cur_ts="$(sed -n "s/.*\"ts\":\([0-9][0-9]*\).*/\1/p" "$LAST" | head -n 1)"
    printf "%s" "$cur_ts" | grep -Eq "^[0-9]+$" || cur_ts=""
  fi
  if [ -n "$cur_ts" ]; then
    prev_ts=""
    if [ -f "$STT" ]; then
      prev_ts="$(head -n 1 "$STT" 2>/dev/null)"
      printf "%s" "$prev_ts" | grep -Eq "^[0-9]+$" || prev_ts=""
    fi
    if [ -n "$prev_ts" ] && [ "$cur_ts" -lt "$prev_ts" ]; then
      echo "[SMOKE] ERR: last.json ts regrediu (cur=$cur_ts < prev=$prev_ts)"
      return 1
    fi
    echo "$cur_ts" >"$STT" 2>/dev/null || true
  else
    echo "[SMOKE] WARN: last.json sem ts parseavel (skip monotonic)"
  fi
    log "OK: --post (diff --check + patch-check opcional + sintaxe + probes best-effort + ASP gate)"
    ;;

  --patch-check)
    gate_patch_check "${1:-}"
    log "OK: --patch-check"
    ;;

  --help|-h)
    cat <<EOF
Usage: ./avp-smoke.sh [--pre|--post|--hotfix|--patch-check|--help] [targets...]

--pre         : antes de qualquer mudança (exige baseline limpo tracked + patch-check opcional + sintaxe + probes best-effort + ASP gate)
--post        : depois da mudança (antes do commit) (diff --check + patch-check opcional + sintaxe + probes best-effort + ASP gate)
--hotfix      : bypass explícito do baseline limpo (para hotfix minúsculo já com árvore suja)
               RECOMENDA: AVP_SMOKE_EXPECT="arquivo1 arquivo2" (allowlist tracked) quando houver dirty, mas nao trava o operador
               bypass consciente: AVP_SMOKE_ALLOW_EMPTY_EXPECT=1
--patch-check : valida patch em arquivo com git apply --check (não aplica)

Targets (opcional): se informado, roda gates apenas nos arquivos indicados.
  Ex.: ./avp-smoke.sh --post avp-pol.sh services-start
  Ex.: ./avp-smoke.sh --post avp/www/avp.asp

Envs úteis:
  AVP_SMOKE_ROOT=/jffs/scripts     root do repo (útil fora do router / snapshot/tar)
  AVP_SMOKE_FIX_PERMS=1            auto-corrige +x em alvos shell (padrão = valida e falha)
  AVP_SMOKE_PERMS_SKIP="..."       pula arquivos no PERMS gate (padrão = avp-lib.sh)
  AVP_SMOKE_TARGETS="..."          define targets sem passar args
  AVP_SMOKE_PATCH=/tmp/p.patch     habilita gate de patch em --pre/--post/--hotfix
  AVP_SMOKE_EXPECT="..."           allowlist recomendada do dirty tracked em --hotfix; se vazio: dirty=auto-fill; clean=warn+best-effort
  AVP_SMOKE_ALLOW_EMPTY_EXPECT=1   permite hotfix sem EXPECT (menos seguro)
  AVP_SMOKE_STRICT_VER=1           mismatch header Version vs SCRIPT_VER vira FAIL (padrão = WARN)
  AVP_SMOKE_NO_SHEBANG=1           desativa SHEBANG gate (padrão = ativo)
  AVP_SMOKE_SHEBANG_SKIP="..."     pula arquivos no SHEBANG gate
  Hotfix semantics:
  --hotfix:
    - bypass explícito do baseline limpo (tracked dirty permitido)
    - AVP_SMOKE_EXPECT é recomendado (allowlist), mas o operador não fica travado
    - se tracked dirty: auto-preenche AVP_SMOKE_EXPECT via 'git diff --name-only'
    - se tree limpa e sem EXPECT: apenas WARN e segue best-effort
    - AVP_SMOKE_ALLOW_EMPTY_EXPECT=1 permite EXPECT vazio (menos seguro)

  AVP_SMOKE_NO_BASHISM=1           desativa BASHISM gate (padrão = ativo)
  AVP_SMOKE_BASHISM_SKIP="..."     pula arquivos no BASHISM gate (padrão = avp-smoke.sh)
  AVP_SMOKE_BASHISM_STRICT=1       modo estrito opcional (default = 0)
  AVP_SMOKE_MAXLEN=200             limiar do LEN gate (default canônico = 200)
  AVP_SMOKE_LEN_STRICT=1           LEN gate vira FAIL (padrão = WARN)
  AVP_SMOKE_PROBES_STRICT=1        torna probes POL/ACTION obrigatórios (default = WARN/best-effort)
EOF
    ;;

  *)
    die "modo invalido: $MODE (use --pre, --post, --hotfix, --patch-check)"
    ;;
esac

exit 0
