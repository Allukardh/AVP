# AVP-BACKUP

## v2.0.0 (2026-02-18)
- CHG: Part1 migrate avp-backup.sh -> avp-backup (python core v2.0.0) + preserve legacy changelog (backup.md) + remove legacy .sh

## v1.0.7 (2026-01-26)
- VERSION: bump patch (pos harden canônico)

## v1.0.6 (2026-01-18)
- POLISH: padroniza SCRIPT_VER + set -u (ordem oficial) e remove linhas em branco desnecessarias

## v1.0.5 (2025-12-26)
- CHORE: polimento preparatório pra GUI (suite alinhada)

## v1.0.4 (2025-12-23)
- (sem detalhes)

## v1.0.3 (2025-12-23)
- (sem detalhes)

## v1.0.2 (2025-12-21)
- ADD: self-backup (inclui o proprio avp-backup.sh)

## v1.0.1 (2025-12-21)
- SAFETY: idempotente por versao (se .bak da versao ja existir -> SKIP)
- CHG: leitura robusta do campo Version no header

## v1.0.0 (2025-12-21)
- ADD: backup automatico baseado na versao do header
- ADD: destino fixo /jffs/scripts/backups
