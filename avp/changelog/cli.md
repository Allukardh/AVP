# cli

## v2.0.0 (2026-02-19)
* CHG: migrate avp-cli.sh -> avp-cli (python core v2.0.0)

## v1.0.18 (2026-02-16)
* FIX: JSON agora realmente inclui "route" por device (alias de "table") — compat WebUI
* DOC: help/hint incluem --json (alias do default)

## v1.0.17 (2026-02-16)
* FIX: JSON agora inclui "route" por device (alias de "table") — compat WebUI
* FIX: status aceita --json (alias do default; remove cli.unknown_flag)

## v1.0.16 (2026-02-16)
* FIX: status aceita --json (alias do default; remove cli.unknown_flag)
* FIX: JSON injeta "route" como alias de "table" (pós-processamento seguro)

## v1.0.15 (2026-02-16)
* FIX: JSON agora expõe "route" (alias de "table") por device (compat WebUI)
* FIX: cmd status aceita --json (alias do modo default; remove cli.unknown_flag)

## v1.0.14 (2026-02-16)
* FIX: adiciona "route" (alias de "table") no JSON/KV p/ compat da coluna Route na WebUI

## v1.0.13 (2026-01-27)
* CHORE: hygiene (trim trailing WS; collapse blank lines; no logic change)

## v1.0.12 (2026-01-27)
* CHORE: hygiene (whitespace/blank lines; no logic change)

## v1.0.11 (2026-01-26)
* VERSION: bump patch (pos harden canônico)

## v1.0.10 (2026-01-26)
* DEDUP: remove harden_state_dir do CLI; perms 0600 via writer canônico + ENG + services-start --perms-only

## v1.0.9 (2026-01-26)
* HARDEN: cura states dinamicos (avp_*.state) como 0600 (labels mudam via GUI/devices.conf)

## v1.0.8 (2026-01-21)
* FIX   : AVP_CLI_STRICT=1 agora retorna RC=2 tambem em status com flag invalida; e main propaga RC do status.

## v1.0.7 (2026-01-21)
* ADD   : AVP_CLI_STRICT=1 => unknown flag/command retorna RC=2 (mantem JSON impresso; default segue RC=0).

## v1.0.6 (2026-01-18)
* POLISH: padroniza SCRIPT_VER + set -u (ordem oficial) e remove linhas em branco desnecessarias

## v1.0.5 (2026-01-17)
* FIX   : json_escape chamado sem aspas escapadas (remove ruído \\\"$VAR\\\")

## v1.0.4 (2026-01-17)
* FIX   : remove duplicacao do bloco obj JSON (awk consume com ltrim) + indent consistente

## v1.0.3 (2026-01-17)
* POLISH: split do obj JSON (anti-wrap) + indent consistente

## v1.0.2 (2026-01-04)
* FIX: POLICY_DIR volta ao canônico do projeto (AVP_ROOT/autovpn/policy) mantendo STATE_DIR em (AVP_ROOT/avp/state)

## v1.0.1 (2026-01-04)
* ADD: erro estruturado no JSON (err:{level,code,where,hint}) mantendo errors[] para compatibilidade
* ADD: purge leve de /tmp (/tmp/avp_cli_devices.*) para evitar sobras órfãs AVP-only

## v1.0.0 (2025-12-30)
* ADD: status (JSON compacto canonico) para GUI/automacao (sem jq)
* ADD: status --pretty (jq opcional; stderr warn; stdout preserva contrato)
* ADD: status --kv (fallback humano/legado; grep/shell-friendly)
* SAFETY: nunca falha por ausencia de dependencias/policy; sempre retorna JSON valido
