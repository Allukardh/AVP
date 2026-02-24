# CHANGELOG — AVP-ENG

## v2.0.3 (2026-02-23)
- CHG: remove fallback por glob no `legacy-live` e mantém resolução canônica do TMPLOG por PID.
- CHG: remove log de debug temporário do fallback de TMPLOG.
- TUNE: reduz drain final do `legacy-live` de 8 para 6 ciclos estáveis.


## v2.0.2 (2026-02-23)
- FIX: `legacy-live` agora resolve TMPLOG com fallback por glob (`/tmp/avp_eng.*`) quando o nome por PID não casa com o `$$` do shell legado.
- FIX: aumenta janela de drain final do live para reduzir risco de corte nas últimas linhas.


## v2.0.1 (2026-02-23)
- FIX: normaliza header canônico de `avp-eng` para o padrão AVP (Version/Status no bloco comentado + `SCRIPT_VER` fora do comentário).
- FIX: hygiene no helper `legacy-live` (context manager em `/dev/null`).


## v2.0.1 (2026-02-23)
- FIX: normaliza header do entrypoint canônico `avp-eng`, reposicionando `SCRIPT_VER` no bloco de metadados e alinhando com `Version`.
- FIX: ajuste de hygiene no helper `legacy-live` (uso de context manager para `/dev/null`).


## v2.0.0 (2026-02-23)
- NEW: cria entrypoint canônico Python `avp-eng` (sem extensão).
- NEW: adiciona helper `legacy-live` para follow robusto do TMPLOG legado (`/tmp/avp_eng.<pid>`), base para eliminar truncamento no live.
- NOTE: `avp-eng.sh` permanece legado congelado (fallback), sem bump/changelog durante a migração Shell→Python.


## v1.2.51 (2026-02-22)
- FIX: branch disabled agora faz purge por `from IP` (cleanup_rules_for_ip_anypref) em vez de purge por `pref`, evitando remover regra ativa de outro device quando há compartilhamento/deriva de pref
- SAFE: mantém compatibilidade com VPN Director (regra real por host = `from <IP>`), com reconciliação mais robusta e determinística


## v1.2.50 (2026-02-22)
- FIX: loader de devices agora prioriza `pref` do kernel (`ip rule`) sobre `prefmap` (MAC), evitando drift de mapeamento que causava falso `WAN/(none)`
- FIX: self-heal do `prefmap` quando detecta divergência `prefmap != kernel` (log `[PREFMAP] drift ... -> heal`)

## v1.2.49 (2026-02-21)
- FIX: `current_device_table()` agora usa parser determinístico por `pref + from IP` em `ip -4 rule show`, corrigindo falso `WAN/(none)` quando a regra `lookup wgc*` existe no kernel

## v1.2.48 (2026-02-21)
- FIX: final_reconcile canônico no fim do ciclo (rele kernel e persiste dev_mode/last_real_* após apply/fallback/return)
- FIX: branch SSOT disabled (enabled=0) agora persiste estado WAN no statefile para GUI/CLI (dev_mode/last_real_* = wan)

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
