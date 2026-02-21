# CHANGELOG — AVP-ENG

## v1.2.47 (2026-02-21)
- FEAT: Fase 4 de reconciliação operacional no AVP-ENG (`ip rule`) com purge por `pref` + `from IP` antes de aplicar regra final
- FEAT: validação explícita do estado final no kernel (lookup esperado para VPN e ausência de regra para WAN/disabled)
- UX: logs `[RECON]` adicionados para auditoria clara da reconciliação por device
## v1.2.46 (2026-02-21)
- FEAT: adiciona `prefmap.db` em `/jffs/scripts/avp/state/` para persistir `MAC -> pref` no AVP-ENG
- FEAT: alocação de `pref` agora prioriza prefmap por MAC, depois reaproveita `ip rule`, e por fim aloca próximo livre >= `11210`
- SAFE: reserva de `pref` fica estável por MAC (evita drift por reorder/rename na GUI do Merlin)
## v1.2.45 (2026-02-21)
- FEAT: AVP-ENG passa a consumir inventário SSOT do VPN Director via `avp-pol.sh device ssot` (sem `devices.conf`)
- FEAT: devices `enabled=0` na SSOT agora são ignorados pelo engine e têm limpeza de resíduos `ip rule` por IP
- SAFE: `pref` temporário nesta fase reaproveita `pref` existente por IP ou aloca base `11210 + índice` (prefmap por MAC fica para a próxima fase)
- FIX: evita subshell em load_devices_from_ssot (pipe|while), preservando DEVICES_LIST no BusyBox /bin/sh

## v1.2.44 (2026-02-21)
- FIX: corrige `printf "%s\n"` no parser de ping para newline real.
- FIX: remove `trap ... EXIT` no `run_device` (não protegia `return` de função e podia induzir leitura errada do fluxo).
## v1.2.43 (2026-02-21)
- FIX: hotfix intermediário do parser de ping (ajuste de `printf` no pipeline para `ping_parse_stats`).
- SAFETY: tentativa de flush defensivo do state no `run_device` (substituída no ajuste final v1.2.44).
## v1.2.42 (2026-02-21)
- PERF: pré-aquecimento de métricas WAN/WG por ciclo (reuso para todos os devices).
- PERF: state por device em `/tmp` (cache temporário) com flush único no fim do device.
- PERF: reduz `PINGCOUNT` padrão de 10 para 3 (loop operacional mais leve).
- PERF: consolida parsing do ping em uma função awk (`ping_parse_stats`), reduzindo subprocessos.
## v1.2.41 (2026-02-20)
- DOC: externaliza CHANGELOG para /jffs/scripts/avp/changelogs/avp-eng.md
- CHG: remove bloco CHANGELOG embutido do script
## v1.2.40 (2026-02-06)
- FIX: init dev_mode no state quando ausente (evita WebUI/CLI "unknown" em devices novos)
## v1.2.39 (2026-01-27)
- CHORE: hygiene (trim trailing WS; collapse blank lines; no logic change)
## v1.2.38 (2026-01-27)
- CHORE: hygiene (whitespace/blank lines; no logic change)
## v1.2.37 (2026-01-26)
- VERSION: bump patch (pos harden canônico)
## v1.2.36 (2026-01-26)
- HARDEN: set_state() usa writer canônico (atomic + chmod 0600) p/ avp_${SL}.state
## v1.2.35 (2026-01-26)
- HARDEN: garantir chmod 0600 em avp_${SL}.state (evita 0666 por umask)
## v1.2.34 (2026-01-21)
- POLISH: PATH robusto (cron/non-interactive) alinhado ao padrao AVP; sem impacto no motor
## v1.2.33 (2026-01-18)
- POLISH: padroniza SCRIPT_VER + set -u (ordem oficial) e remove linhas em branco desnecessarias
## v1.2.32 (2026-01-17)
- POLISH: higiene (remove termo legado do ping-interval (docs/changelog)) + harden quebra do log [CONFIG] (anti-wrap)
## v1.2.31 (2026-01-17)
- POLISH: hygiene (remove palavra ping-interval do changelog) + quebra log [CONFIG] >200 chars (anti-wrap)
## v1.2.30 (2026-01-16)
- CHORE: higiene do changelog (consolida entradas repetidas do topo; sem impacto no motor)
## v1.2.29 (2026-01-16)
- CHORE: remove legado do ping-interval (config/help/docs) e alinha SCRIPT_VER com header (sem impacto no motor)
## v1.2.28 (2026-01-16)
- NOTE: versao consumida durante higiene operacional (sem mudanca funcional; consolidado no v1.2.30)
## v1.2.27 (2026-01-16)
- NOTE: versao consumida durante higiene operacional (sem mudanca funcional; consolidado no v1.2.30)
## v1.2.26 (2026-01-16)
- NOTE: versao consumida durante higiene operacional (sem mudanca funcional; consolidado no v1.2.30)
## v1.2.25 (2026-01-16)
- FIX: usb_rotate_daily dedup de arquivos (evita glob duplicado ao casar Y e YMD)
## v1.2.24 (2026-01-16)
- POLISH: get_state/set_state agora usam awk (sem grep|tail|cut pipeline); preserva "last wins"
- SAFETY: set_state mantém escrita atomica (tmp+mv) e remove keys anteriores via awk
- NOTE: state agora é awk-only; grep/tail/cut seguem CRIT por escolha conservadora (nao por dependencia do state).
## v1.2.23 (2026-01-16)
- POLISH: rotate --rotate-usb passa por require_cmds (evita rotacao silenciosa sem dependencias)
- POLISH: require_cmds: grep/tail/cut seguem CRITICAL (decisao conservadora; state nao depende mais)
- POLISH: usb_rotate_daily usa Y=avp_day (coerente com janela 06:00->05:59)
## v1.2.22 (2026-01-16)
- FIX: retenção 30d inclui archives .tar.gz (mantem compat com legado .gz)
## v1.2.21 (2026-01-16)
- FIX: janela 06:00->05:59: introduce AVP_DAY (hora<06 => dia anterior) p/ nomear logs e cycles
- FIX: rotate usa prev_day() robusto (sem depender de date -d do BusyBox)
- CHG: padroniza nomes com hifen: avp_eng_YYYY-MM-DD_HHMMSS.log
- CHG: archive coerente: avp_eng_YYYY-MM-DD_logs.tar.gz (antes .gz)
## v1.2.20 (2026-01-16)
- FIX: usb_rotate_daily: USB_DIR=/mnt/AVPUSB/avp_logs + glob YYYYMMDD (YMD) p/ compactar avp_eng_YYYYMMDD_HHMMSS.log
## v1.2.19 (2026-01-14)
- POLISH: age_print=NA sem sufixo 's' (quando PREV_TS=0)
- POLISH: log único no boot quando DWARN_TTL=0 (disabled)
## v1.2.18 (2026-01-14)
- CHG: still_degraded WARN: age_print=NA quando PREV_TS=0 (log mais semântico)
## v1.2.17 (2026-01-13)
- CHG: degraded_iface WARN = transicao + reset em quarentena + TTL opcional (DWARN_TTL)
- CHG: still_degraded re-warn controlado (ttl/age), sem spam (DWARN_TTL=0 desliga)
## v1.2.16 (2026-01-13)
- FIX: Merlin/BusyBox ping nao suporta -i; removido -i do ping (evita INF falso: packet_loss all_targets)
- FIX: WARN degraded_iface state-key: usar IF (interface do loop), nao WG (variavel stale)
## v1.2.15 (2026-01-13)
- CHG: ping metrics: -c 10 -W 1 (PINGCOUNT=10, PINGW=1)
- CHG: TARGETS primario->fallback real (8.8.8.8 -> 1.1.1.1); INF somente se ambos falharem (loss!=0)
- ADD: E1: summary JSON por ciclo (ultimo ciclo) em /tmp para consumo da WebUI
## v1.2.14 (2026-01-08)
- CHG: Flash-Safe v1: em falha (rc!=0) grava ERROR em /jffs/scripts/avp/logs/avp_errors.log
## v1.2.13 (2026-01-08)
- CHG: eng logs default /tmp/avp_logs (opt AVP_LOGDIR)
## v1.2.12 (2026-01-07)
- CHORE: remove duplicate cleanup_tmp() definition (sem impacto funcional)
- POLISH: split FW_KERNEL/FW_BUILD/FW_FW assignments (evita wrap)
## v1.2.11 (2025-12-29)
- FIX: B5 purge_tmp_orphans sem erro de escopo (remove chamada solta + remove duplicata)
## v1.2.10 (2025-12-29)
- CHORE: B5 sanitize /tmp (remove orfaos avp_eng.* por PID morto, sem regressao)
## v1.2.9 (2025-12-29)
- FIX: aborts iniciais agora geram log bootstrap (melhor observabilidade no cron/CLI)
## v1.2.8 (2025-12-29)
- ADD: --help/-h documenta uso correto do ENG
- SAFETY: explicita bloqueio de execucao standalone (override documentado)
## v1.2.7 (2025-12-29)
- FIX: AVP_LIVE=1 agora eh live real (stream do TMPLOG no terminal durante execucao)
- SAFETY: bloqueia execucao standalone por padrao (use POL); override: AVP_ALLOW_STANDALONE=1 ou --standalone
- CHG: TARGETS com primario+fallback (8.8.8.8 -> 1.1.1.1 somente se falhar)
- CHG: PINGW default=1 (PINGCOUNT permanece 5)
## v1.2.6 (2025-12-28)
- FIX: lockdir compat (arquivo->dir) + stale lock cleanup (pid nao roda)
- FIX: trap unificado (cleanup tmp + release_lock) + inclui HUP
## v1.2.5 (2025-12-28)
- CHG: [CONFIG] dividido em 2 linhas para evitar wrap/truncamento em terminais e logs
## v1.2.4 (2025-12-27)
- POLISH: cleanup TMP_DEVLIST (trap) + tee sem pipe
## v1.2.3 (2025-12-27)
- FIX(GapB): add set_rc() (first error wins) to preserve final engine RC
- FIX(GapB): apply_device_table returns code=30 + NEXT hints (ip rule/ip route) and sets rc via set_rc
- FIX(GapB): device loop no MAIN without pipeline/subshell to keep ENG_RC across devices
## v1.2.2 (2025-12-26)
- ADD: Gap A — códigos padronizados + NEXT acionável para falhas críticas (pre-GUI)
- CHG: missing_cmds(critical) -> code=10 (instrução: type ... / PATH/BusyBox/Entware)
- CHG: logdir failures -> code=11 + NEXT
- CHG: statedir failures -> code=12 + NEXT
- CHG: fallback para ausência de tee (stdout + append em log, sem quebrar execução)
## v1.2.1 (2025-12-26)
- FIX: RC real do core preservado (MAIN em subshell + TMPLOG + tee) — caller/cron recebe o rc correto
- FIX: devices.conf ausente/inválido retorna code=20 com [NEXT] acionável (caminho + formato esperado)
- CHG: lock ativo retorna code=99 com mensagem + próxima ação (remover /tmp/avp_eng.lock se preso)
## v1.2.0 (2025-12-26)
- MINOR: pre-GUI hardening; devices.conf vira fonte unica (remove hardcode de devices/IP/pref); header Devices dinamico; abort-only sem devices.conf
## v1.1.0 (2025-12-25)
- ADD: suporte a knobs estendidos via profiles.conf (WAN/RET-DEF/QUAR) — sem mudar defaults do core
- CHORE: log de contexto (profile + CONFIG efetivo) para auditoria/afinacao na Etapa C
- FIX: log inicial agora expande corretamente FW_BUILD/FW_FW (sem escapes literais)
## v1.0.14 (2025-12-24)
- FIX: devices.conf loader CRLF-safe + EOF-safe (aceita ultima linha sem newline)
- FIX: DEVICES_LIST usa "\\n" literal (evita string multilinha que quebra o shell)
## v1.0.13 (2025-12-23)
- CHORE: changelog hygiene (semantica ADD/CHG/FIX/CHORE/STD + nota de gaps)
## v1.0.12 (2025-12-23)
- STD: padroniza header + bloco CHANGELOG (Etapa A)
## v1.0.11 (2025-12-21)
- FIX: QUAR_* defaults (sem regressao)
## v1.0.10 (2025-12-21)
- CHORE: observabilidade (sem mudanca de decisao)
## v1.0.9 (2025-12-21)
- CHG: profiles (overrides via env com defaults preservados)
## v1.0.8 (2025-12-20)
- CHORE: changelog reorganizado (somente comentarios)
## v1.0.7 (2025-12-20)
- FIX: sanitize_label (compatibilidade BusyBox)
## v1.0.6 (2025-12-20)
- NOTE: versao existiu durante iteracao, mas sem registro confiavel nos MDs/commits para detalhar
## v1.0.5 (2025-12-20)
- NOTE: versao existiu durante iteracao, mas sem registro confiavel nos MDs/commits para detalhar
## v1.0.4 (2025-12-20)
- FIX: devices.conf strict (obrigatorio; se ausente/invalido -> aborta com [ERR])
## v1.0.3 (2025-12-20)
- CHG: integracao Policy -> Engine (Device Loader via devices.conf)
## v1.0.2 (2025-12-19)
- FIX: log/consistencia pos-switch
## v1.0.1 (2025-12-19)
- FIX: set -u (evita "parameter not set")
## v1.0.0 (2025-12-19)
- CHORE: observabilidade + quarentena (sem regressao do core)
