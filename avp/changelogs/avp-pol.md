# CHANGELOG — AVP-POL

## v2.0.4 (2026-02-23)
- FEAT: `avp-pol run` (sem `--live`) agora usa caminho canônico Python, compartilhando a mesma base de profile/env do `run --live`.
- CHG: `run` e `run --live` passam a chamar o entrypoint canônico `avp-eng`; modo live segue via helper `legacy-live`.
- NOTE: demais subcomandos continuam em fallback para `avp-pol.sh` (legado congelado).


## v2.0.3 (2026-02-23)
- CHG: remove exigência de `devices.conf` no caminho canônico `run --live` (SSOT via VPN Director).


## v2.0.2 (2026-02-23)
- FEAT: migra caminho `run --live` para o entrypoint canônico Python `avp-pol`.
- FEAT: `run --live` agora chama `avp-eng legacy-live`, eliminando dependência do `tail -f` do legado no live.
- NOTE: demais subcomandos/fluxos continuam em fallback para `avp-pol.sh` (transição gradual).


## v2.0.1 (2026-02-23)
- FIX: normaliza header canônico de `avp-pol` para o padrão AVP (Version/Status no bloco comentado + `SCRIPT_VER` fora do comentário).


## v2.0.1 (2026-02-23)
- FIX: normaliza header do entrypoint canônico `avp-pol`, reposicionando `SCRIPT_VER` no bloco de metadados e alinhando com `Version`.


## v2.0.0 (2026-02-23)
- NEW: cria entrypoint canônico Python `avp-pol` (sem extensão).
- NOTE: `avp-pol.sh` permanece legado congelado (fallback), sem bump/changelog durante a migração Shell→Python.


## v1.3.28 (2026-02-21)
- FEAT: parser SSOT read-only do VPN Director (Merlin) em `avp-pol.sh` via `/jffs/openvpn/vpndirector_rulelist`
- FEAT: novo subcomando `device ssot` (plain e `--json`) emitindo `enabled|label|ip|iface_base|mac`
- CHG: sem fallback para `devices.conf` na leitura do inventário SSOT (falha explícita no subcomando)
## v1.3.27 (2026-02-21)
- FIX: restaura contrato de `CRITICAL_VARS` no AVP-POL (fallbacks canônicos dos campos core voltam a ser aplicados).
- FIX: completa bloco `[balanced]` no template `ensure_profiles_conf()` com `PINGCOUNT`, `PINGW` e `TARGETS`.
- SAFE: mantém tunáveis do ENG via `profiles.conf` alinhados com defaults e template interno.
## v1.3.26 (2026-02-21)
- FIX: remove variáveis globais indevidas (`PINGCOUNT`, `PINGW`, `TARGETS`) do topo do AVP-POL.
- SAFE: mantém somente defaults canônicos `DEF_PINGCOUNT`, `DEF_PINGW`, `DEF_TARGETS` e export via `apply_profile_exports`.
## v1.3.25 (2026-02-21)
- FEAT: profiles.conf agora suporta tunáveis de métricas do ENG (`PINGCOUNT`, `PINGW`, `TARGETS`).
- FEAT: AVP-POL valida e exporta `PINGCOUNT`, `PINGW` e `TARGETS` para o AVP-ENG.
- SAFE: fallback canônico em valores inválidos (`DEF_PINGCOUNT`, `DEF_PINGW`, `DEF_TARGETS`).
- UX: template interno de `ensure_profiles_conf` atualizado com os novos campos (prepara integração com GUI/API).
## v1.3.24 (2026-02-20)
- DOC: externaliza CHANGELOG para /jffs/scripts/avp/changelogs/avp-pol.md
- CHG: remove bloco CHANGELOG embutido do script
## v1.3.23 (2026-02-20)
- BREAK: remove auto-backup implicito (pre_run_backup) do fluxo run
- CHG: backup passa a ser manual/on-demand
## v1.3.22 (2026-02-09)
- HARDEN: fix_policy_perms tambem alinha ownership (chown UID:GID best-effort) nos .conf
## v1.3.21 (2026-02-09)
- FIX: enforce perms 0600 em policy confs (global/profiles/devices) via require_*
- POLISH: async reload usa rc_state=pending (rc numerico no contrato)
## v1.3.20 (2026-02-06)
- FIX: restore reload --async (GUI) + keep sync wait-for-DONE (no regression)
## v1.3.19 (2026-02-06)
- FIX: reload sincrono (aguarda " - DONE" no ultimo log) + rc/msg coerentes
## v1.3.18 (2026-02-06)
- FIX   : run --live executa mesmo com AUTOVPN_ENABLED=0 (override p/ troubleshooting)
## v1.3.17 (2026-01-27)
- CHORE: hygiene (trim trailing WS; collapse blank lines; add header Version; no logic change)
- - vX.Y.Z (2026-01-27)
- CHORE: hygiene (trim trailing WS; collapse blank lines; no logic change)
## v1.3.16 (2026-01-27)
- HARDEN: trap cleanup do POL_LOCKDIR (EXIT/HUP/INT/TERM), remove somente se pid==$$.
## v1.3.15 (2026-01-26)
- VERSION: bump patch (pos harden canônico)
## v1.3.14 (2026-01-26)
- HARDEN: export PATH robusto (cron/non-interactive) p/ evitar falhas intermitentes (/usr/sbin,/sbin)
## v1.3.13 (2026-01-26)
- HARDEN: writer de avp_gui_apply.state usa state_write_file() (atomic + chmod 0600)
## v1.3.12 (2026-01-21)
- FIX   : cmd_run --live agora propaga RC real do engine (antes podia mascarar 0).
## v1.3.11 (2026-01-18)
- POLISH: padroniza SCRIPT_VER + set -u (ordem oficial) e remove linhas em branco desnecessarias
## v1.3.10 (2026-01-17)
- FIX   : CRITICAL_VARS (anti-wrap): quebra em linhas curtas e indent consistente.
- NOTE  : somente higiene operacional; sem mudar fluxo/contrato.
## v1.3.9 (2026-01-10)
- ADD: status inclui observabilidade de degradado
- (janela temporal via /jffs/scripts/avp/logs/avp_errors.log; sem escrita extra no flash)
## v1.3.8 (2026-01-10)
- CHG: enable/disable agora retornam JSON canônico; --kv mantém fallback humano/legado
## v1.3.7 (2026-01-08)
- CHG: Flash-Safe v1: eventos/erros em /jffs/scripts/avp/logs; verbose segue em /tmp/avp_logs
- CHG: remove arquivo dedicado avp_gui_actions.log (vira EVENT em avp_events.log)
## v1.3.6 (2026-01-08)
- CHG: help/refs alinhados: logs padrao em /tmp/avp_logs (opt AVP_LOGDIR)
## v1.3.5 (2026-01-08)
- CHG: logs default /tmp/avp_logs (opt AVP_LOGDIR); GUI/cron/status/show-last ajustados
## v1.3.4 (2026-01-07)
- SAFETY: lockdir (mkdir atômico) em operações mutantes de policy (evita concorrência GUI/ação/cron)
## v1.3.3 (2026-01-06)
- CHG: reload --async (GUI) agenda execucao do ENG em background (resposta imediata)
- ADD: state last_apply marca RC=PENDING e depois grava RC+LAST_LOG quando concluir
- FIX: reload aceita token=<...> sem repassar como opcao; exporta TOKEN/AVP_TOKEN (sync/async)
- FIX: reload unknown option retorna JSON com data.opt (sem quebrar payload)
## v1.3.2 (2026-01-06)
- FIX: json_reply sanitiza "data" por balanceamento (remove somente "}" quando close>open)
- SAFETY: evita quebrar JSON válido/aninhado (snapshot/profile/device)
## v1.3.1 (2026-01-06)
- FIX: json_reply sanitiza "data" quando vier com "}" extra (garante status --json parseável)
- SAFETY: mantém contrato ok/rc/action/msg/data/ts sem mudar fluxo normal
## v1.3.0 (2026-01-05)
- ADD: C2.1 GUI-safe API no AVP-POL (json + snapshot + profile/device + reload)
- SAFETY: validações fortes + whitelist (sem comando arbitrário)
- ADD: last Apply/Reload em /jffs/scripts/avp/state/avp_gui_apply.state
## v1.2.13 (2025-12-29)
- FIX: --help expande SCRIPT_VER (cat <<EOF no show_help)
## v1.2.12 (2025-12-29)
- FIX: --help expande SCRIPT_VER (remove heredoc quoted) (padrao alinhado ao ENG)
## v1.2.11 (2025-12-29)
- STD: help mostra versao do POL (padrao alinhado ao ENG)
## v1.2.10 (2025-12-29)
- STD: adiciona SCRIPT_VER (padrao do ENG) (sem alterar fluxo)
## v1.2.9 (2025-12-29)
- ADD: SCRIPT_VER (padrao do ENG). Usado no --help, sem alterar status/fluxo.
## v1.2.8 (2025-12-29)
- FIX: status CRON_LOG agora pega o ultimo END rc= (robusto com failure_dump/append)
## v1.2.7 (2025-12-29)
- ADD: status mostra ultimo log do ENG e ultimo END rc do cron (observabilidade rápida)
## v1.2.6 (2025-12-29)
- ADD: quando engine falha, registra rc + last_log no syslog (sem alterar modo silencioso)
## v1.2.5 (2025-12-29)
- FIX: run --show-last resiliente a pipe/head (evita quebrar por SIGPIPE / broken pipe)
## v1.2.4 (2025-12-29)
- CHG: help/usage polido (sem duplicacoes) + remove alias --run
- ADD: run --show-last (imprime ultimo log do ENG sem executar)
- CHG: status agora mostra paths (POLICY_DIR/GLOBAL/PROFILES/DEVICES)
- CHG: run com parsing de opcoes (--live/--show-last/-h) e modo quiet mantido
## v1.2.3 (2025-12-28)
- FIX: cmd_run deterministico (init_global antes do enabled-check) e remove duplicacoes de init_global/require_policy_files
## v1.2.2 (2025-12-28)
- FIX: status/run agora carregam global.conf (AUTOVPN_ENABLED/AUTOVPN_PROFILE) e mostram valores corretamente
## v1.2.1 (2025-12-27)
- POLISH: die() code+NEXT; require_policy_files codes 10/20; remove require_policy_files de is_positive_int()
## v1.2.0 (2025-12-26)
- MINOR: pre-GUI hardening; remove bootstrap/hardcode; policy files obrigatorios; abort-only se policy/global/profiles/devices.conf ausentes ou devices.conf vazio/inválido
## v1.1.0 (2025-12-25)
- ADD: profiles.conf expandido (WAN/RET-DEF/QUAR knobs) com validacao e defaults (sem mudar o balanced)
- CHG: exporta AUTOVPN_PROFILE + knobs efetivos para o AVP-ENG (observabilidade; sem regressao)
## v1.0.9 (2025-12-24)
- FIX: remove duplicacao do LIVE_MODE no cmd_run() (sem regressao; --live segue verboso; cron segue silencioso)
## v1.0.8 (2025-12-24)
- ADD: modo ao vivo (--live) com loop + help (-h/--help) para execucao humana
- CHG: run silencioso preservado (padrao para automacao/cron)
## v1.0.7 (2025-12-23)
- CHORE: consolidacao historica (Etapa B) com base nos MDs
## v1.0.6 (2025-12-23)
- STD: padroniza header + bloco CHANGELOG (Etapa A)
## v1.0.5 (2025-12-22)
- CHORE: canonizacao AVP (engine=avp-eng.sh) + organizacao estrutural
## v1.0.4 (2025-12-21)
- NOTE: legado do auto-backup (removido no v1.3.23)
## v1.0.3 (2025-12-21)
- FIX: parsing CRLF-safe + trims + defaults robustos
## v1.0.2 (2025-12-21)
- FIX: profile loader (exports aplicados corretamente; evita subshell bug)
## v1.0.1 (2025-12-21)
- ADD: AUTOVPN_PROFILE via global.conf e profiles.conf
## v1.0.0 (2025-12-21)
- BASE: enable/disable/status/run; delega execucao ao AVP-ENG
