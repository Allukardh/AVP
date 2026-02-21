# CHANGELOG — AVP-LIB

## v1.0.11 (2026-02-20)
- DOC: externaliza CHANGELOG para /jffs/scripts/avp/changelogs/avp-lib.md
- CHG: remove bloco CHANGELOG embutido do script
## v1.0.10 (2026-02-08)
- FIX: log_action() garante rc numerico antes de logar (evita JSON invalido)
## v1.0.9 (2026-02-06)
- FIX: add log_action() helper (required by avp-pol.sh; avoids "not found")
## v1.0.8 (2026-01-27)
- CHORE: hygiene (trim trailing WS; mark legacy example comment)
## v1.0.7 (2026-01-27)
- CHORE: hygiene (whitespace/blank lines; no logic change)
## v1.0.6 (2026-01-26)
- VERSION: bump patch (pos harden canônico)
## v1.0.5 (2026-01-26)
- ADD: state_write_file(): writer canônico (atomic + umask 077 + chmod 0600)
## v1.0.4 (2026-01-26)
- HARDEN: state_set() garante chmod 0600 no state final (evita 0666 por umask)
## v1.0.3 (2026-01-18)
- POLISH: padroniza SCRIPT_VER + set -u (ordem oficial) e remove linhas em branco desnecessarias
## v1.0.2 (2026-01-08)
- STD: padroniza header (File/Role/Status) + organiza CHANGELOG (sem linhas em branco)
## v1.0.1 (2026-01-08)
- ADD: helper has_fn() (type-based) para checar funcoes no sh (guards/Flash-Safe)
## v1.0.0 (2026-01-08)
- ADD: Flash-Safe v1 helpers: rotate_if_big, log_event/error/debug, state_set/get (rate-limited)
