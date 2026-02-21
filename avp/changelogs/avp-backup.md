# CHANGELOG — AVP-UTIL

## v1.0.9 (2026-02-20)
- DOC: externaliza CHANGELOG para /jffs/scripts/avp/changelogs/avp-backup.md
- CHG: remove bloco CHANGELOG embutido do script
## v1.0.8 (2026-02-20)
- CHG: targets dinâmicos via git ls-files (repo-aware)
- CHG: inclui hooks raiz + avp/bin + avp/lib (scripts versionados)
- CHG: uso manual/on-demand (sem depender de auto-call do POL)
## v1.0.7 (2026-01-26)
- VERSION: bump patch (pos harden canônico)
## v1.0.6 (2026-01-18)
- POLISH: padroniza SCRIPT_VER + set -u (ordem oficial) e remove linhas em branco desnecessarias
## v1.0.5 (2025-12-26)
- CHORE: polimento preparatório pra GUI (suite alinhada)
## v1.0.4 (2025-12-23)
- CHORE: consolidacao historica (Etapa B) + semantica final do changelog
## v1.0.3 (2025-12-23)
- STD: padroniza header + bloco CHANGELOG (Etapa A)
## v1.0.2 (2025-12-21)
- ADD: self-backup (inclui o proprio avp-backup.sh)
## v1.0.1 (2025-12-21)
- SAFETY: idempotente por versao (se .bak da versao ja existir -> SKIP)
- CHG: leitura robusta do campo Version no header
## v1.0.0 (2025-12-21)
- ADD: backup automatico baseado na versao do header
- ADD: destino fixo /jffs/scripts/backups
