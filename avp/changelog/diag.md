# diag

## v2.0.0 (2026-02-20)
* CHG: migrate avp-diag.sh -> avp-diag (python core v2.0.0)

## v1.2.5 (2026-01-26)
* VERSION: bump patch (pos harden canônico)

## v1.2.4 (2026-01-18)
* POLISH: padroniza SCRIPT_VER + set -u (ordem oficial) e remove linhas em branco desnecessarias

## v1.2.3 (2026-01-08)
* CHG: PRIMARY_LOGDIR padrao em /tmp/avp_logs (opt AVP_LOGDIR) — evita escrita no jffs

## v1.2.2 (2025-12-26)
* FIX: --live usa SCRIPT_VER (remove hardcode residual de versao)

## v1.2.1 (2025-12-26)
* FIX: --live exibe versao correta (remove hardcode de versao)

## v1.2.0 (2025-12-26)
* MINOR: pre-GUI hardening; diag 100% dinamico via devices.conf; remove hardcode/fallback; abort-only sem devices.conf

## v1.0.3 (2025-12-24)
* FIX: runtime canonico AVP (/jffs/scripts/avp) para logs/state; logs buscam avp_* (ex.: avp_eng_*.log)
* FIX: synth ordena por score corretamente (menor=melhor) e evita 'tudo degradado' quando handshake é desconhecido
* CHG: DNS: se nslookup ausente -> SKIP (nao marca FAIL); melhora mensagens
* CHG: --live mais 'humano' (cabecalho por ciclo + tail de linhas relevantes do ultimo log)
