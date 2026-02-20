#!/bin/sh
# =============================================================
# AutoVPN Platform (AVP)
# Component : AVP-APPLY
# File      : avp-apply.sh
# Role      : Patch runner (smoke pre/patch-check/post + git apply) with session-safe background execution
# Version   : v1.0.26 (2026-02-15)
# Status    : stable
# =============================================================
#
# CHANGELOG
# - v1.0.26 (2026-02-15)
#   * CHANGE: baseline policy alinhada com avp-tag.sh (status --porcelain)
# - v1.0.25 (2026-02-14)
#   * FEATURE: registra contexto 3B apos patch aplicado com sucesso,
#     criando /tmp/avp_last_apply.ok e /tmp/avp_last_apply_files.list
# - v1.0.24 (2026-01-26)
#   * VERSION: bump patch (pos harden canônico)
# - v1.0.23 (2026-01-21)
#   * FIX   : RC cirurgico: separa apply --check (RC=14) de strict_ws (RC=13); apply continua RC=15.
# - v1.0.22 (2026-01-20)
#   * POLISH: remove duplicidade de _spc/log no bloco SMOKE --patch-check; log fica coerente com SKIP e fluxo fica deterministico.
# - v1.0.21 (2026-01-20)
#   * FIX   : AVP_APPLY_SMOKE_PATCHCHECK=0 agora pula de fato o bloco do smoke --patch-check (evita RC=21 quando toggle=0 e permite RC=13 no apply --check).
# - v1.0.20 (2026-01-20)
#   * CONTRACT: toggle AVP_APPLY_SMOKE_PATCHCHECK=0 para pular smoke --patch-check e deixar RC=13 representar falha do git apply --check no APPLY.
# - v1.0.19 (2026-01-20)
#   * CONTRACT: separa RC do SMOKE vs PATCH (SMOKE pre=20, patch-check=21, post=22; PATCH inexistente=11, sem leitura=12, --check=13).
# - v1.0.18 (2026-01-20)
#   * CONTRACT: RC dedicado p/ patch inexistente (11), sem leitura (12) e git apply --check falha (13).
# - v1.0.17 (2026-01-20)
#   * POLISH: bloqueia rename/copy em patches (gate antes do apply) para evitar repo dirty.
# - v1.0.16 (2026-01-20)
#   * POLISH: gate duro de paths no patch (bloqueia b/tmp, /tmp, path absoluto e ../) antes do smoke/apply (RC=17).
#   * POLISH: mantém apply determinístico: recusa patch suspeito (não normaliza paths automaticamente).
# - v1.0.15 (2026-01-20)
#   * FIX   : HOTFIX auto-fill do AVP_SMOKE_EXPECT (usa dirty-files do git diff --name-only); se vazio, segue best-effort.
#   * POLISH: padroniza prova de diff sem pager (usar --no-index + --stat em arquivo quando preciso).
#   * TEST  : T20 (patch aplicavel) + T19B (hotfix/dirty) cobrindo RC=10 vs RC=12.
# - v1.0.14 (2026-01-20)
#   * FIX   : baseline DIRTY agora aborta cedo (sem smoke --post em DIRTY; --hotfix e o unico bypass).
#   * POLISH: STRICT_WS usa log() + git --no-pager/cor off + exit code especifico.
#   * POLISH: exit codes distintos: strict_ws=13, check=14, apply=15.
# - v1.0.13 (2026-01-19)
#   * HARDEN: aborta apply quando baseline DIRTY (permitido somente com --hotfix)
# - v1.0.12 (2026-01-19)
#   * FIX   : NORMALIZE_PERMS agora força chmod 755 (evita 777 por umask/attrs e padroniza estado final).
# - v1.0.11 (2026-01-19)
#   * ADD   : NORMALIZE_PERMS apos git apply (previne perda de +x por efeitos colaterais de /tmp/umask/patch).
#   * ADD   : AVP_APPLY_FIX_PERMS=1 (default) e AVP_APPLY_PERMS_SKIP (default: avp-lib.sh).
# - v1.0.10 (2026-01-18)
#   * POLISH: padroniza SCRIPT_VER + set -u (ordem oficial) e remove linhas em branco desnecessarias
# - v1.0.9 (2026-01-17)
#   * FIX   : baseline auto: repo limpo => smoke --pre; repo DIRTY => smoke --post.
#   * NOTE  : evita abort do apply em repo sujo (o smoke --pre recusa DIRTY por design).
# - v1.0.8 (2026-01-17)
#   * POLISH: alinha estrutura ao padrao do ENG (1 shebang/header/changelog/SCRIPT_VER), remove duplicatas e restaura historico.
# - v1.0.7 (2026-01-17)
#   * FIX   : rebuild canonico (shebang+header+changelog+env harden) e remove blocos duplicados que quebravam o fluxo.
#   * POLISH: padroniza SCRIPT_VER e remove espacos/linhas em branco fora do padrao.
# - v1.0.6 (2026-01-17)
#   * NOTE  : versao consumida durante iteracao/higiene operacional (sem registro confiavel para detalhar).
# - v1.0.5 (2026-01-17)
#   * POLISH: header+changelog no topo; remove BOOTSTRAP vazio; limpa espacos apos SCRIPT_VER.
# - v1.0.4 (2026-01-17)
#   * FIX   : remove WARN legado de git; BOOTSTRAP nao duplica env; PATCH_HASH_OBJECT via git() wrapper.
# - v1.0.3 (2026-01-17)
#   * FIX   : env harden no topo + remove WARN falso de git; garante wrapper git() desde o inicio.
# - v1.0.2 (2026-01-17)
#   * FIX   : env harden nao depende de log/die/ts; precheck de git define git() (falha cedo).
# - v1.0.1 (2026-01-17)
#   * FIX   : detecta git (caminho real) + forca PATH canonico; remove WARN falso.
# - v1.0.0 (2026-01-17)
#   * ADD   : runner de aplicacao de patch com logs persistentes (resistente a "session disconnected")
#   * ADD   : integra smoke --pre + --patch-check + --post e git apply --check/apply
#   * ADD   : modo background default + --fg opcional
# =============================================================

SCRIPT_VER="v1.0.26"
export PATH="/jffs/scripts:/jffs/scripts/avp/bin:/opt/bin:/opt/sbin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH:-}"
hash -r 2>/dev/null || true
set -u

# --- env harden (Merlin/cron/session-safe) ---
export GIT_PAGER=cat PAGER=cat

_find_git() {
  _g="$(command -v git 2>/dev/null || true)"
  [ -n "${_g:-}" ] && { echo "$_g"; return 0; }
  for _p in /opt/bin/git /usr/bin/git /bin/git; do
    [ -x "$_p" ] && { echo "$_p"; return 0; }
  done
  return 1
}

GIT_BIN="$(_find_git 2>/dev/null || true)"
if [ -z "${GIT_BIN:-}" ]; then
  echo "$(date "+%Y-%m-%d %H:%M:%S") [APPLY] ERR: git nao encontrado (PATH=$PATH)" >&2
  exit 127
fi

git() { "$GIT_BIN" "$@"; }

ts()   { date "+%Y-%m-%d %H:%M:%S"; }
log()  { echo "$(ts) [APPLY] $*"; }
warn() { echo "$(ts) [APPLY] WARN: $*" >&2; }
err()  { echo "$(ts) [APPLY] ERR: $*"  >&2; }
die()  { err "$*"; exit 1; }

usage() {
  cat <<EOF2
Usage:
  avp-apply.sh <patchfile> [--fg] [--hotfix]

Behavior:
  - Default: roda em BACKGROUND (nao depende da sessao SSH) e grava log em /jffs/scripts/avp/logs/
  - --fg    : roda em foreground (bom p/ debug)
  - --hotfix: usa smoke --hotfix (bypass consciente do baseline limpo). So em urgencia.

Env:
  AVP_APPLY_ROOT       : root do repo (default: /jffs/scripts)
  AVP_APPLY_LOGDIR     : dir de logs (default: /jffs/scripts/avp/logs)
  AVP_APPLY_FIX_PERMS  : 1=normaliza perms apos apply (default: 1)
  AVP_APPLY_PERMS_SKIP : lista (espaco) de arquivos a pular (default: avp-lib.sh)
EOF2
}

validate_patch_paths() {
  _p="$1"
  [ -n "${_p:-}" ] || { err "PATCH PATHS: patch vazio"; exit 17; }
  [ -r "$_p" ] || { err "PATCH PATHS: sem leitura do patch: $_p"; exit 17; }

  # Captura apenas headers que definem paths (mantém determinístico e barato)
  _hdr="$(grep -E '^(diff --git |--- |\+\+\+ )' "$_p" 2>/dev/null || true)"
  # BLOQUEIO DETERMINISTICO: patch com rename/copy (evita repo dirty)
  if grep -qE "^(rename from |rename to |copy from |copy to )" "$_p" 2>/dev/null; then
    err "PATCH META: BLOQUEADO (rename/copy)"
    exit 18
  fi

  # BLOQUEIOS:
  # - /tmp, b/tmp, tmp/
  # - path absoluto
  # - traversal ../
  _bad="$(printf "%s\n" "$_hdr" \
    | grep -E '(/tmp/|(^|[[:space:]])[ab]/tmp/|(^|[[:space:]])tmp/|(^|[[:space:]])/|(^|[[:space:]])[ab]/\.\./|(^|[[:space:]])\.\./)' \
    | head -n 1)"

  [ -z "${_bad:-}" ] || {
    err "PATCH PATHS: BLOQUEADO (header suspeito): $_bad"
    err "Dica: o patch deve referenciar somente paths do repo no formato 'a/<repo_rel>' e 'b/<repo_rel>'."
    exit 17
  }

  return 0
}

ROOT="${AVP_APPLY_ROOT:-/jffs/scripts}"
LOGDIR="${AVP_APPLY_LOGDIR:-/jffs/scripts/avp/logs}"

FG=0
HOTFIX=0
PATCH=""

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0;;
    --fg) FG=1; shift;;
    --hotfix) HOTFIX=1; shift;;
    --) shift; break;;
    -*)
      die "flag desconhecida: $1 (use --help)"
      ;;
    *)
      if [ -z "$PATCH" ]; then
        PATCH="$1"
      else
        die "arg extra inesperado: $1"
      fi
      shift
      ;;
  esac
done

[ -n "$PATCH" ] || { usage; exit 2; }
[ -f "$PATCH" ] || { err "PATCH: nao existe: $PATCH"; exit 11; }
[ -r "$PATCH" ] || { err "PATCH: sem permissao de leitura: $PATCH"; exit 12; }
[ -s "$PATCH" ] || die "patchfile vazio: $PATCH"
[ -d "$ROOT" ] || die "AVP_APPLY_ROOT invalido: $ROOT"
mkdir -p "$LOGDIR" 2>/dev/null || true

if [ "${PATCH#/}" = "$PATCH" ]; then
  PATCH="$(pwd)/$PATCH"
fi

TS="$(date +%Y%m%d-%H%M%S)"
LOGF="$LOGDIR/apply_${TS}.log"

normalize_perms_after_apply() {
  _fix="${AVP_APPLY_FIX_PERMS:-1}"
  [ "$_fix" = "1" ] || { log "NORMALIZE_PERMS=SKIP (AVP_APPLY_FIX_PERMS=$_fix)"; return 0; }

  _skip="${AVP_APPLY_PERMS_SKIP:-avp-lib.sh}"
  _touched="$(git diff --name-only 2>/dev/null | tr "\n" " " | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"
  [ -n "${_touched:-}" ] || { log "NORMALIZE_PERMS=SKIP (nenhum arquivo tocado)"; return 0; }

  log "NORMALIZE_PERMS=1 touched='$_touched' skip='$_skip'"

  for f in $_touched; do
    [ -f "$f" ] || continue
    echo " $_skip " | grep -q " $f " && continue
    case "$f" in
      *.sh|services-start|post-mount)
        # estado final conhecido: executavel -> 755 (evita 777 por umask/attrs)
        chmod 755 "$f" 2>/dev/null || true
        if [ -x "$f" ]; then
          log "NORMALIZE_PERMS: chmod 755 OK em $f"
        else
          warn "NORMALIZE_PERMS: falhou chmod 755 em $f (ok se FS/attrs bloquearem)"
        fi
        ;;
    esac
  done

  return 0
}

run_apply() {
  cd "$ROOT" || exit 3

  SMOKE="/jffs/scripts/avp/bin/avp-smoke.sh"
  [ -x "$SMOKE" ] || die "smoke nao encontrado/executavel em /jffs/scripts/avp/bin/avp-smoke.sh"

  log "== AVP-APPLY start =="
  log "SCRIPT_VER=$SCRIPT_VER"
  log "ROOT=$ROOT"
  log "PATCH=$PATCH"
  log "LOGF=$LOGF"

  PH="$(git hash-object "$PATCH" 2>/dev/null || true)"
  [ -n "${PH:-}" ] && log "PATCH_HASH_OBJECT=$PH" || warn "PATCH_HASH_OBJECT=unavailable"

  if [ "$HOTFIX" -eq 1 ]; then
    log "SMOKE=--hotfix"
      # HOTFIX: auto-fill AVP_SMOKE_EXPECT (evita exigir operador)
      if [ -z "${AVP_SMOKE_EXPECT:-}" ]; then
        _d="$(git -c color.ui=false --no-pager diff --name-only 2>/dev/null | tr "\n" " " | sed "s/[[:space:]][[:space:]]*/ /g; s/^ //; s/ $//")"
        if [ -n "${_d:-}" ]; then
          export AVP_SMOKE_EXPECT="$_d"
          log "SMOKE(HOTFIX): AVP_SMOKE_EXPECT auto=$_d"
        else
          export AVP_SMOKE_ALLOW_EMPTY_EXPECT=1
          warn "SMOKE(HOTFIX): AVP_SMOKE_EXPECT ausente e dirty=<none>; seguindo best-effort (ALLOW_EMPTY_EXPECT=1)"
        fi
      fi
    "$SMOKE" --hotfix || exit 10
  else
    _dirty=0
[ -n "$(git status --porcelain 2>/dev/null)" ] && _dirty=1
    if [ "$_dirty" -eq 0 ]; then
      log "SMOKE=--pre (baseline limpo)"
      "$SMOKE" --pre || exit 20
    else
      err "baseline DIRTY; recusei apply. Use --hotfix apenas em urgencia."
      exit 16
    fi
  fi

  log "PATCH PATHS gate (anti b/tmp,/tmp,abs,../)"
  validate_patch_paths "$PATCH"

  _spc="${AVP_APPLY_SMOKE_PATCHCHECK:-1}"
  if [ "$_spc" = "1" ]; then
    log "SMOKE=--patch-check (AVP_SMOKE_PATCH)"
    AVP_SMOKE_PATCH="$PATCH" "$SMOKE" --patch-check || exit 21
  else
    log "SMOKE=--patch-check SKIP (AVP_APPLY_SMOKE_PATCHCHECK=$_spc)"
  fi
  log "GIT_APPLY=--check"

# ====== STRICT WHITESPACE GATE (P16F) ======
: "${AVP_APPLY_STRICT_WS:=1}"
if [ "${AVP_APPLY_STRICT_WS}" = "1" ]; then
  log "GIT_APPLY=--whitespace=error --check"
  git -c color.ui=false --no-pager apply --whitespace=error --check -v "$PATCH" || exit 13
fi
  git -c color.ui=false --no-pager apply --check -v "$PATCH" || exit 14

  log "GIT_APPLY=apply"
  git -c color.ui=false --no-pager apply -v "$PATCH" || exit 15

  normalize_perms_after_apply

  log "SMOKE=--post"
  "$SMOKE" --post || exit 22

  log "== AVP-APPLY OK =="

  # ---------------------------------------------------
  # Registro de contexto 3B para commit.sh
  FILES="$(git diff --name-only)"
  if [ -z "$FILES" ]; then
    log "APPLY-CONTEXT: nenhum arquivo modificado detectado apos o apply."
  else
    echo "$FILES" > /tmp/avp_last_apply_files.list
    echo "OK" > /tmp/avp_last_apply.ok
    log "APPLY-CONTEXT: contexto 3B registrado em /tmp/avp_last_apply_files.list"
  fi
  # ---------------------------------------------------

  exit 0
}

if [ "$FG" -eq 1 ]; then
  exec >"$LOGF" 2>&1
  run_apply
else
  (
    exec >"$LOGF" 2>&1
    run_apply
  ) </dev/null &
  log "RUNNING (background). Abra o log:"
  log "  tail -n 200 '$LOGF'"
fi
