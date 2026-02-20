#!/bin/sh
# =============================================================
# AutoVPN Platform (AVP)
# Component : AVP-POL-CRON
# File      : avp-pol-cron.sh
# Role      : Cron wrapper (timestamp + rc) for AVP-POL run
# Version   : v1.0.22 (2026-02-10)
# Status    : stable
# =============================================================
#
# CHANGELOG
# - v1.0.22 (2026-02-10)
#   * HARDEN: emit_error detecta log_error mesmo sem has_fn (fallback silencioso)
# - v1.0.21 (2026-02-10)
#   * POLISH: remove mkdir -p redundante (LOGDIR)
#   * POLISH: emit_error usa has_fn log_error + detail arg
# - v1.0.20 (2026-02-10)
#   * CHORE: remove restos ### INJECT_*
#   * HARDEN: emit_error sem clobber de variáveis globais (rc/msg)
#   * POLISH: SKIP rc=99 log usa SELF_VER
# - v1.0.19 (2026-02-10)
#   * FIX: tratar rc=99 (lock_active) como SKIP (rc=0) antes do END/failure_dump/emit_error
# - v1.0.18 (2026-02-10)
#   * FIX: rc=99 (lock_active) vira SKIP (rc=0) antes do END/failure_dump/emit_error
# - v1.0.17 (2026-02-10)
#   * FIX: STRICT_ORDER (set -u logo abaixo do SCRIPT_VER)
#   * FEAT: rc=99 (lock_active) vira SKIP (treat as rc=0) no cron
# - v1.0.16 (2026-02-10)
#   * FIX: evitar clobber do SCRIPT_VER pelo avp-lib (SELF_VER + restore) e logar versão correta
# - v1.0.15 (2026-02-10)
#   * FIX: START log volta a incluir pid=$$ (wrapper visível no cron)
#   * HARDEN: guard se /jffs/scripts/avp/bin/avp-pol.sh ausente (rc=127 + log)
#   * HARDEN: emit_error fallback para /tmp se /jffs/scripts/avp/logs nao gravavel
# - v1.0.14 (2026-02-09)
#   * FIX: emit_error usa log_error (avp-lib); remove JSON manual em avp_errors.log
# - v1.0.13 (2026-01-27)
#   * CHORE: hygiene (trim trailing WS; collapse blank lines; no logic change)
# - v1.0.12 (2026-01-26)
#   * VERSION: bump patch (pos harden canônico)
# - v1.0.11 (2026-01-26)
#   * HARDEN: export PATH robusto p/ cron (evita "funciona no SSH, falha no cron")
# - v1.0.10 (2026-01-18)
#   * POLISH: padroniza SCRIPT_VER + set -u (ordem oficial) e remove linhas em branco desnecessarias
# - v1.0.9 (2026-01-10)
#   * ADD: erro estruturado no avp_errors.log quando rc!=0 (cron)
# - v1.0.8 (2026-01-08)
#   * CHG: Flash-Safe v1: erro de execucao logado em /jffs/scripts/avp/logs/avp_errors.log
# - v1.0.7 (2026-01-08)
#   * CHG: LOGDIR padrão agora /tmp/avp_logs (opt AVP_LOGDIR) para evitar escrita no jffs
# - v1.0.6 (2026-01-07)
#   * SAFETY: rotate_if_big (evita crescimento infinito do log do cron)
#   * SAFETY: mkdir -p logs + fallback /tmp quando /jffs indisponível
# - v1.0.5 (2026-01-05)
#   * CHORE: padroniza header + changelog (C1.5)
# - v1.0.4 (2025-12-29)
#   * ADD: START agora inclui pid=$$ (distingue instancias em execucao manual/cron)
# - v1.0.3 (2025-12-29)
#   * ADD: se rc!=0, anexa dump (status + head do ultimo log do ENG) no log do cron
# - v1.0.2 (2025-12-29)
#   * FIX: alinhado ao POL v1.2.4+ (usa comando run; alias antigo removido do POL)
#   * CHG: cron continua silencioso; detalhes ficam em /tmp/avp_logs/avp-pol-cron.log (opt AVP_LOGDIR) e no ENG (opt AVP_LOGDIR)
# - v1.0.1 (2025-12-26)
#   * CHG: wrapper adotado como método oficial do cron (START/END + rc em log dedicado)
# - v1.0.0 (2025-12-26)
#   * ADD: timestamped START/END + rc in dedicated log file
#   * SAFETY: keep cron quoting simple (wrapper script)
# =============================================================

SCRIPT_VER="v1.0.22"
set -u

SELF_VER="$SCRIPT_VER"
export PATH="/jffs/scripts:/jffs/scripts/avp/bin:/opt/bin:/opt/sbin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH:-}"
hash -r 2>/dev/null || true

AVP_LIB="/jffs/scripts/avp/lib/avp-lib.sh"
[ -f "$AVP_LIB" ] && . "$AVP_LIB"
type has_fn >/dev/null 2>&1 || has_fn(){ type "$1" >/dev/null 2>&1; }
has_fn avp_init_layout && avp_init_layout >/dev/null 2>&1 || :

emit_error(){
  _rc="$1"
  _msg="$2"
  if { type has_fn >/dev/null 2>&1 && has_fn log_error; } || type log_error >/dev/null 2>&1; then
    log_error "AVP-POL-CRON" "$_msg" "$_rc" "stage=emit_error"
    return 0
  fi

  _tsn="$(date +%s)"
  _errd="/jffs/scripts/avp/logs"
  _errf="$_errd/avp_errors.log"
  [ -d "$_errd" ] || mkdir -p "$_errd" 2>/dev/null || :
  _line="{\"ts\":\"$_tsn\",\"comp\":\"AVP-POL-CRON\",\"msg\":\"$_msg\",\"rc\":$_rc}"
  if ! echo "$_line" >>"$_errf" 2>/dev/null; then
    echo "$_line" >>"/tmp/avp_errors.log" 2>/dev/null || :
  fi
}

ts(){ date "+%F %T"; }
ROTATE_MAX=262144  # 256 KiB

rotate_if_big() {
  _f="$1"
  [ -f "$_f" ] || return 0
  _sz="$(wc -c <"$_f" 2>/dev/null || echo 0)"
  [ "$_sz" -ge "$ROTATE_MAX" ] || return 0
  mv -f "$_f" "${_f}.1" 2>/dev/null || true
}

# logdir: padrão em RAM para evitar escrita persistente no jffs (override: AVP_LOGDIR)
LOGDIR="${AVP_LOGDIR:-/tmp/avp_logs}"
mkdir -p "$LOGDIR" 2>/dev/null || { LOGDIR="/tmp/avp_logs"; mkdir -p "$LOGDIR" 2>/dev/null || :; }
LOG="$LOGDIR/avp-pol-cron.log"
rotate_if_big "$LOG"
echo "$(ts) [CRON] AVP-POL-CRON $SELF_VER START pid=$$" >>"$LOG"
POL="/jffs/scripts/avp/bin/avp-pol.sh"
if [ ! -f "$POL" ]; then
  echo "$(ts) [CRON] AVP-POL-CRON $SELF_VER ERR missing $POL" >>"$LOG"
  rc=127
else
  /bin/sh "$POL" run >>"$LOG" 2>&1
  rc=$?
  # rc=99 (lock_active) => SKIP (nao é falha; evita ruido no cron)
  if [ "${rc:-0}" -eq 99 ] 2>/dev/null; then
    echo "$(ts) [CRON] AVP-POL-CRON $SELF_VER SKIP rc=99 (lock_active)" >>"$LOG"
    rc=0
  fi
fi
echo "$(ts) [CRON] AVP-POL-CRON $SELF_VER END rc=$rc" >>"$LOG"
if [ "$rc" -ne 0 ]; then
  if has_fn log_error; then
    log_error "CRON" "avp-pol.sh failed" "$rc" "log=$LOG"
  fi

  {
    echo "$(ts) [CRON] failure_dump BEGIN rc=$rc"
    /bin/sh /jffs/scripts/avp/bin/avp-pol.sh status
    echo "---- LAST LOG (head 80) ----"
    /bin/sh /jffs/scripts/avp/bin/avp-pol.sh run --show-last | head -n 80
    echo "$(ts) [CRON] failure_dump END rc=$rc"
  } >>"$LOG" 2>&1
fi
if [ "$rc" -ne 0 ]; then
  emit_error "$rc" "policy_apply_failed"
fi
exit "$rc"
