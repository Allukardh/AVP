# AVP-META

## v1.1.0 (2026-02-18)
- CHG: noop test
- ADD: --register --targets ... --msg ... (msg obrigatório, sem auto-msg)
- ADD: --register --staged ... --msg ... (ouro na migração em lote)
- CHG: remove fallback A2.1 (sem inferência de componente sem header)
- ADD: AVP_JSON=1 => stdout JSON limpo; logs no stderr


## v1.0.3 (2026-02-18)
- FIX: avp/changelog/*.md não é alvo governado (meta ignora e não exige header/SCRIPT_VER).
- ADD: A2.1 fallback no normalize (cria header quando faltar, se existir SCRIPT_VER).
- POLISH: inferência segura de Component para avp/bin (AVP-ENTRY e AVP-<TOOL>).

## v1.0.2 (2026-02-17)
- FIX: atomic_write escreve tmp no mesmo filesystem do destino (evita EXDEV cross-device link em /tmp -> /jffs)


## v1.0.1 (2026-02-17)
- FIX: autodetect do header do alvo (Component/Version/Status/Role) no --check/--normalize (V2)
- FIX: valida changelog externo do componente correto (não hardcode AVP-META)
- DROP: dependência de jq/command -v (motor Python)

## v1.0.0 (2026-02-17)
- ADD: rewrite Python-first (V2-only) com changelog externo (./avp/changelog/meta.md)
- ADD: modos check/normalize/apply + spec JSON
- ADD: templates por linguagem (python/shell) sem changelog interno
