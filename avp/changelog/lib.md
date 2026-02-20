# lib

## v2.0.0 (2026-02-20)
* CHG: migrate avp-lib.sh -> avp_lib.py (Python module v2.0.0) — adiciona funções de logging e state management equivalentes em Python.

## v1.0.10 (2026-02-08)
* FIX: log_action garante rc numérico antes de logar (evita JSON inválido):contentReference[oaicite:1]{index=1}.

## v1.0.9 (2026-02-06)
* ADD: log_action helper (requerido pelo avp-pol.sh; evita “not found”):contentReference[oaicite:2]{index=2}.

## v1.0.8 (2026-01-27)
* CHORE: hygiene (trim trailing whitespace; marca comentário legado):contentReference[oaicite:3]{index=3}.

## v1.0.7 (2026-01-27)
* CHORE: hygiene (whitespace/blank lines; sem mudança de lógica):contentReference[oaicite:4]{index=4}.

## v1.0.6 (2026-01-26)
* VERSION: bump patch (pós harden canônico):contentReference[oaicite:5]{index=5}.

## v1.0.5 (2026-01-26)
* ADD: state_write_file (writer canônico; grava atomica + chmod 0600):contentReference[oaicite:6]{index=6}.

## v1.0.4 (2026-01-26)
* HARDEN: state_set garante chmod 0600 no state final (evita 0666 por umask):contentReference[oaicite:7]{index=7}.

## v1.0.3 (2026-01-18)
* POLISH: padroniza SCRIPT_VER + set -u e remove linhas em branco desnecessárias:contentReference[oaicite:8]{index=8}.

## v1.0.2 (2026-01-08)
* STD: padroniza header (File/Role/Status) + organiza changelog:contentReference[oaicite:9]{index=9}.

## v1.0.1 (2026-01-08)
* ADD: helper has_fn (type-based) para checar funções no sh (guards/Flash‑Safe):contentReference[oaicite:10]{index=10}.

## v1.0.0 (2026-01-08)
* ADD: Flash-Safe v1 helpers: rotate_if_big, log_event/error/debug, state_set/get (rate-limited):contentReference[oaicite:11]{index=11}.
