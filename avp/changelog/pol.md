# pol

## v2.0.0 (2026-02-20)
* EXP: migrate avp-pol.sh -> avp-pol (Python wrapper). Registra início e fim das ações via avp_lib e delega comandos ao avp-pol.sh (mantém compatibilidade).

## v1.3.22 (2026-02-09)
* HARDEN: fix_policy_perms também alinha ownership (chown UID:GID) nos arquivos .conf:contentReference[oaicite:1]{index=1}.

## v1.3.21 (2026-02-09)
* FIX: garante perms 0600 em global.conf, profiles.conf e devices.conf;
* POLISH: reload assíncrono usa `rc_state=pending` com código numérico no contrato:contentReference[oaicite:2]{index=2}.

## v1.3.20 (2026-02-06)
* FIX: restaura `reload --async` na GUI e mantém o `run --reload` síncrono esperando "DONE":contentReference[oaicite:3]{index=3}.

## v1.3.19 (2026-02-06)
* FIX: reload síncrono aguarda a string " - DONE" no último log e retorna códigos/mensagens coerentes:contentReference[oaicite:4]{index=4}.

## v1.3.18 (2026-02-06)
* FIX: `run --live` executa mesmo com `AUTOVPN_ENABLED=0` (override para troubleshooting):contentReference[oaicite:5]{index=5}.

## v1.3.17 (2026-01-27)
* CHORE: higiene (remove espaços/linhas em branco, adiciona header Version) sem mudanças funcionais:contentReference[oaicite:6]{index=6}.

## v1.3.16 (2026-01-27)
* HARDEN: trap cleanup do `POL_LOCKDIR` (EXIT/HUP/INT/TERM) remove o lock apenas se pertencer ao processo:contentReference[oaicite:7]{index=7}.

## v1.3.15 (2026-01-26)
* VERSION: bump patch (pós hardening canônico):contentReference[oaicite:8]{index=8}.

## v1.3.14 (2026-01-26)
* HARDEN: PATH robusto para cron e non-interactive, evitando falhas intermitentes nos comandos (inclui /usr/sbin, /sbin):contentReference[oaicite:9]{index=9}.

## v1.3.13 (2026-01-26)
* HARDEN: gravação de `avp_gui_apply.state` agora usa `state_write_file()` (escrita atômica + chmod 0600):contentReference[oaicite:10]{index=10}.

## v1.3.12 (2026-01-21)
* FIX: `cmd_run --live` passa a retornar o código real do engine, evitando mascarar erros:contentReference[oaicite:11]{index=11}.

## v1.3.11 (2026-01-18)
* POLISH: padroniza `SCRIPT_VER` + `set -u` (ordem oficial) e remove linhas em branco desnecessárias:contentReference[oaicite:12]{index=12}.

## v1.3.10 (2026-01-17)
* FIX: variáveis críticas (`CRITICAL_VARS`) são quebradas em linhas curtas para evitar wrap; indentação consistente:contentReference[oaicite:13]{index=13}.

## v1.3.9 (2026-01-10)
* ADD: `status` inclui observabilidade de degradado via análise de logs (janela temporal em `avp_errors.log`) sem escrita extra no flash:contentReference[oaicite:14]{index=14}.

## v1.3.8 (2026-01-10)
* CHG: `enable` e `disable` retornam JSON canônico; modo `--kv` continua como fallback humano/legado:contentReference[oaicite:15]{index=15}.

## v1.3.7 (2026-01-08)
* CHG: Flash-Safe v1 — eventos e erros passam para `/jffs/scripts/logs` enquanto os logs verbosos permanecem em `/tmp/avp_logs`:contentReference[oaicite:16]{index=16}.
* CHG: remove o arquivo dedicado `avp_gui_actions.log`; eventos vão para `avp_events.log`.

## v1.3.6 (2026-01-08)
* CHG: documentos de ajuda e referências alinhados; logs padrão agora em `/tmp/avp_logs` (pode ser alterado via `AVP_LOGDIR`):contentReference[oaicite:17]{index=17}.

## v1.3.5 (2026-01-08)
* CHG: logs padrão mudam para `/tmp/avp_logs`; interfaces GUI/cron/status/show-last ajustadas para refletir essa mudança:contentReference[oaicite:18]{index=18}.

## v1.3.4 (2026-01-07)
* SAFETY: usa `mkdir` atômico em `POL_LOCKDIR` para evitar concorrência em operações mutantes de policy:contentReference[oaicite:19]{index=19}.

## v1.3.3 (2026-01-06)
* CHG: `reload --async` (GUI) agenda a execução do engine em background, retornando imediatamente:contentReference[oaicite:20]{index=20}.
* ADD: grava estado `last_apply` com `rc=PENDING` e depois `rc+LAST_LOG` ao concluir:contentReference[oaicite:21]{index=21}.
* FIX: `reload` aceita `token=<...>` sem repassar como opção; exporta `TOKEN`/`AVP_TOKEN` (sync/async):contentReference[oaicite:22]{index=22}.
* FIX: opção desconhecida em `reload` retorna JSON com campo `data.opt` em vez de quebrar o payload:contentReference[oaicite:23]{index=23}.

## v1.3.2 (2026-01-06)
* FIX: `json_reply` sanitiza `data` removendo apenas chaves extras quando há desbalanceamento:contentReference[oaicite:24]{index=24}.
* SAFETY: evita corromper JSON válido/aninhado em `snapshot`, `profile` ou `device`:contentReference[oaicite:25]{index=25}.

## v1.3.1 (2026-01-06)
* FIX: `json_reply` sanitiza `data` quando possui "}" extra, garantindo que `status --json` seja parseável:contentReference[oaicite:26]{index=26}.
* SAFETY: preserva os campos `ok`, `rc`, `action`, `msg`, `data` e `ts` sem mudar o fluxo:contentReference[oaicite:27]{index=27}.

## v1.3.0 (2026-01-05)
* ADD: API C2.1 "GUI-safe" (status, snapshot, profile/device, reload) com JSON padronizado:contentReference[oaicite:28]{index=28}.
* SAFETY: validações fortes + whitelist (impede comandos arbitrários):contentReference[oaicite:29]{index=29}.
* ADD: registra `last Apply/Reload` em `/jffs/scripts/avp/state/avp_gui_apply.state`:contentReference[oaicite:30]{index=30}.

## v1.2.13 (2025-12-29)
* FIX: `--help` agora expande `SCRIPT_VER` corretamente, exibindo a versão do POL no texto de ajuda:contentReference[oaicite:31]{index=31}.

## v1.2.12 (2025-12-29)
* FIX: melhorias no help; `--help` remove aspas do heredoc e alinha saída ao padrão do ENG:contentReference[oaicite:32]{index=32}.

## v1.2.11 (2025-12-29)
* STD: help mostra a versão do POL (mesma convenção do ENG):contentReference[oaicite:33]{index=33}.

## v1.2.10 (2025-12-29)
* STD: introduz `SCRIPT_VER` no header (sem alterar lógica):contentReference[oaicite:34]{index=34}.

## v1.2.9 (2025-12-29)
* ADD: adiciona variável `SCRIPT_VER` (utilizada no help):contentReference[oaicite:35]{index=35}.

## v1.2.8 (2025-12-29)
* FIX: `status` captura o último `END rc=` do log do cron de forma robusta, mesmo com `failure_dump` appended:contentReference[oaicite:36]{index=36}.

## v1.2.7 (2025-12-29)
* ADD: `status` mostra o último log do ENG e o último `END rc` do cron para facilitar diagnóstico rápido:contentReference[oaicite:37]{index=37}.

## v1.2.6 (2025-12-29)
* ADD: se o engine falhar, registra `rc` e `last_log` no syslog sem alterar o modo silencioso:contentReference[oaicite:38]{index=38}.

## v1.2.5 (2025-12-29)
* FIX: `run --show-last` torna-se resiliente a quebras de pipeline (evita `broken pipe`):contentReference[oaicite:39]{index=39}.

## v1.2.4 (2025-12-29)
* CHG: ajuda/uso (help) polida, sem duplicações, e remove o alias `--run`:contentReference[oaicite:40]{index=40}.
* ADD: `run --show-last` imprime o último log do ENG sem executar o engine novamente:contentReference[oaicite:41]{index=41}.
* CHG: `status` exibe os caminhos do `POLICY_DIR`, `GLOBAL`, `PROFILES` e `DEVICES`:contentReference[oaicite:42]{index=42}.
* CHG: `run` agora suporta parsing de opções (`--live`, `--show-last`, `-h`) mantendo o modo quiet padrão:contentReference[oaicite:43]{index=43}.

## v1.2.3 (2025-12-28)
* FIX: `cmd_run` torna-se determinístico, inicializando `global.conf` antes de verificar se está habilitado; remove duplicidades de `init_global` e `require_policy_files`:contentReference[oaicite:44]{index=44}.

## v1.2.2 (2025-12-28)
* FIX: `status`/`run` carregam `global.conf` (AUTOVPN_ENABLED/AUTOVPN_PROFILE) e exibem corretamente os valores:contentReference[oaicite:45]{index=45}.

## v1.2.1 (2025-12-27)
* POLISH: `die()` passa a incluir código + hint `[NEXT]`; erros de `require_policy_files` usam códigos 10/20; remove `require_policy_files` do `is_positive_int`:contentReference[oaicite:46]{index=46}.

## v1.2.0 (2025-12-26)
* MINOR: pre‑GUI hardening; remove hardcodes do bootstrap; arquivos de policy tornam-se obrigatórios; aborta se `global.conf`, `profiles.conf` ou `devices.conf` estiverem ausentes ou se `devices.conf` for vazio/inválido:contentReference[oaicite:47]{index=47}.

## v1.1.0 (2025-12-25)
* ADD: `profiles.conf` expandido com knobs WAN/RET-DEF/QUAR, com validações e defaults preservados:contentReference[oaicite:48]{index=48}.
* CHG: exporta `AUTOVPN_PROFILE` e knobs efetivos para o AVP-ENG, melhorando observabilidade:contentReference[oaicite:49]{index=49}.

## v1.0.9 (2025-12-24)
* FIX: remove duplicidade do `LIVE_MODE` em `cmd_run()`, mantendo o modo verbose para `--live` e silencioso no cron:contentReference[oaicite:50]{index=50}.

## v1.0.8 (2025-12-24)
* ADD: modo ao vivo `--live` (loop) e help `-h/--help` para execução humana:contentReference[oaicite:51]{index=51}.
* CHG: modo de execução (`run`) permanece silencioso para automação/cron:contentReference[oaicite:52]{index=52}.

## v1.0.7 (2025-12-23)
* CHORE: consolidação histórica (Etapa B) com base nos .mds existentes:contentReference[oaicite:53]{index=53}.

## v1.0.6 (2025-12-23)
* STD: padroniza cabeçalho e bloco CHANGELOG (Etapa A):contentReference[oaicite:54]{index=54}.

## v1.0.5 (2025-12-22)
* CHORE: canonização da AVP (engine = avp-eng.sh) e organização estrutural:contentReference[oaicite:55]{index=55}.

## v1.0.4 (2025-12-21)
* FIX: hook de auto-backup (`pre_run_backup()`):contentReference[oaicite:56]{index=56}.

## v1.0.3 (2025-12-21)
* FIX: parsing CRLF-safe, trims e defaults robustos:contentReference[oaicite:57]{index=57}.

## v1.0.2 (2025-12-21)
* FIX: loader de profiles exporta corretamente variáveis e evita bug de subshell:contentReference[oaicite:58]{index=58}.

## v1.0.1 (2025-12-21)
* ADD: suporte a `AUTOVPN_PROFILE` via `global.conf` e `profiles.conf`:contentReference[oaicite:59]{index=59}.

## v1.0.0 (2025-12-21)
* BASE: implementa `enable`, `disable`, `status` e `run` delegando a execução ao AVP-ENG:contentReference[oaicite:60]{index=60}.
