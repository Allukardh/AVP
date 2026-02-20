# action

## v2.0.0 (2026-02-19)
* CHG: migrate avp-action.sh -> avp-action (python core v2.0.0)

## v1.0.20 (2026-01-27)
* CHORE: hygiene (trim trailing WS; collapse blank lines; no logic change)

## v1.0.19 (2026-01-27)
* CHORE: hygiene (whitespace/blank lines; no logic change)

## v1.0.18 (2026-01-27)
* FIX: url_decode STRICT %HH agora BusyBox-sed safe (BRE); evita gerar "\x" sem dígitos e restaura UTF-8 (%C3%A1 etc.)

## v1.0.17 (2026-01-27)
* HARDEN: url_decode — STRICT %XX (decodifica só %[0-9A-Fa-f]{2}); mantém % inválido literal + protege \\ antes do printf %b

## v1.0.16 (2026-01-27)
* HARDEN: url_decode — escapa "\\" literal antes do printf %b (evita interpretar \\n/\\t/\\r etc.), mantendo %XX (UTF-8)

## v1.0.15 (2026-01-27)
* FIX: url_decode — decode %XX com printf %b (UTF-8 correto, ex: ol%C3%A1%21 -> olá!)

## v1.0.14 (2026-01-27)
* FIX: json_reply — valida/normaliza data com jq (quando disponível) e remove hack por contagem de chaves
* FIX: qs_get — parser em POSIX sh (sem awk), preserva valores com = e mantém url_decode

## v1.0.13 (2026-01-27)
* FIX: Jeito B — AVP_STATE_DIR/AVP_TOKEN_FILE respeitam override via env (debug/teste sem tocar state real)

## v1.0.12 (2026-01-27)
* DEBUG: token_rand loga método (AVP_ACTION_DEBUG/AVP_DEBUG) + mantém fallbacks sem od

## v1.0.11 (2026-01-27)
* FIX: token_get robusto (fallback sem od: hexdump/openssl/md5sum/uuid)

## v1.0.10 (2026-01-26)
* VERSION: bump patch (pos harden canônico)

## v1.0.9 (2026-01-21)
* POLISH: qs_get passa a fazer URL decode (+ e %XX) para inputs via QUERY_STRING

## v1.0.8 (2026-01-18)
* POLISH: padroniza SCRIPT_VER + set -u (ordem oficial) e remove linhas em branco desnecessarias

## v1.0.7 (2026-01-07)
* SAFETY: força PATH robusto (CGI/non-interactive) incluindo /jffs/scripts e /opt/bin

## v1.0.6 (2026-01-06)
* CHG: reload usa POL reload --async (nao bloqueia CGI enquanto ENG roda)

## v1.0.5 (2026-01-06)
* FIX: unwrap_pol_data usa /opt/bin/jq quando PATH (CGI/non-interactive) nao expoe jq
* SAFETY: mantem fallback sem jq (devolve JSON inteiro, ainda valido)

## v1.0.4 (2026-01-06)
* FIX: json_reply sanitiza "data" por balanceamento (remove somente "}" quando close>open)
* SAFETY: nao altera JSON valido/aninhado; mantém contrato ok/rc/action/msg/data/ts

## v1.0.3 (2026-01-06)
* FIX: token sanitize (remove CR/LF/spaces/quotes/backslashes)
* FIX: token_get JSON canônico (data via printf)
* SAFETY: status/snapshot pegam a última linha do POL + unwrap .data quando houver jq

## v1.0.2 (2026-01-05)
* FIX: JSON canônico (json_reply em 1 printf)
* FIX: token fallback forte (urandom->hex) quando sem openssl

## v1.0.1 (2026-01-05)
* ADD: action=token_get (bootstrap do token via JSON)
* SAFETY: gate de origem (CGI) - permite apenas IP local/LAN (RFC1918 + 127/8)

## v1.0.0 (2026-01-05)
* ADD: C2.2 local action handler (whitelist + token + JSON)
