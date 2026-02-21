# AVP-META

## v1.0.3 (2026-02-21)

- POLISH: --apply passa a atualizar changelog externo .md (topo + preserva histórico), sem depender de bloco embutido

## v1.0.2 (2026-02-21)
* CHG: normalizao passa a ler/escrever CHANGELOG externo em /jffs/scripts/avp/changelogs/*.md
* CHG: header cannico gerado sem bloco CHANGELOG embutido
* CHG: bootstrap cannico atualizado com /jffs/scripts/avp/bin no PATH
* ADD: insero/reescrita de changelog .md com entrada mais recente no topo (formato cannico)

## v1.0.1 (2026-02-20)
- DOC: externaliza CHANGELOG para /jffs/scripts/avp/changelogs/avp-meta.md
- CHG: remove bloco CHANGELOG embutido do script

## v1.0.0 (2026-02-16)
- ADD: spec-driven meta editor (create/normalize/apply) for header + CHANGELOG + SCRIPT_VER (canonical)
- ADD: modes: --check / --normalize / --apply --spec / --print-spec-template / --help
