# AVP-META

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
