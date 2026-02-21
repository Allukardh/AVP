# CHANGELOG — AVP-META

## v1.0.5 (2026-02-21)

- FEAT: adiciona --normalize-md <.sh|.md> para normalizar changelog externo (aceita .sh e resolve o .md correspondente)
- FEAT: adiciona --normalize-md-all para faxina em lote de avp/changelogs/*.md
- HELP: atualiza --help com os novos modos de higiene de changelog .md

## v1.0.4 (2026-02-21)

- POLISH: write_changelog_md agora normaliza automaticamente o corpo do changelog externo (.md): CRLF/LF, trailing spaces, blank lines e bullets simples

## v1.0.3 (2026-02-21)

- POLISH: --apply passa a atualizar changelog externo .md (topo + preserva histórico), sem depender de bloco embutido

## v1.0.2 (2026-02-21)
- CHG: normalizao passa a ler/escrever CHANGELOG externo em /jffs/scripts/avp/changelogs/*.md
- CHG: header cannico gerado sem bloco CHANGELOG embutido
- CHG: bootstrap cannico atualizado com /jffs/scripts/avp/bin no PATH
- ADD: insero/reescrita de changelog .md com entrada mais recente no topo (formato cannico)

## v1.0.1 (2026-02-20)
- DOC: externaliza CHANGELOG para /jffs/scripts/avp/changelogs/avp-meta.md
- CHG: remove bloco CHANGELOG embutido do script

## v1.0.0 (2026-02-16)
- ADD: spec-driven meta editor (create/normalize/apply) for header + CHANGELOG + SCRIPT_VER (canonical)
- ADD: modes: --check / --normalize / --apply --spec / --print-spec-template / --help
