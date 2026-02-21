# AVP-META

## v1.0.2 (2026-02-21)
* CHG: normalização passa a ler/escrever CHANGELOG externo em /jffs/scripts/avp/changelogs/*.md
* CHG: header canônico gerado sem bloco CHANGELOG embutido
* CHG: bootstrap canônico atualizado com /jffs/scripts/avp/bin no PATH
* ADD: inserção/reescrita de changelog .md com entrada mais recente no topo (formato canônico)

## v1.0.1 (2026-02-20)
- DOC: externaliza CHANGELOG para /jffs/scripts/avp/changelogs/avp-meta.md
- CHG: remove bloco CHANGELOG embutido do script

## v1.0.0 (2026-02-16)
- ADD: spec-driven meta editor (create/normalize/apply) for header + CHANGELOG + SCRIPT_VER (canonical)
- ADD: modes: --check / --normalize / --apply --spec / --print-spec-template / --help
