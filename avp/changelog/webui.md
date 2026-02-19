# webui

## v2.0.0 (2026-02-19)
* CHG: migrate avp-webui.sh -> avp-webui (python core v2.0.0)

## v1.0.11 (2026-02-10)
* FIX: install: evita falha 'cp same file' detectando SRC/DST por inode (BusyBox-safe) e pulando copy

## v1.0.10 (2026-01-26)
* VERSION: bump patch (pos harden canônico)

## v1.0.9 (2026-01-18)
* POLISH: padroniza SCRIPT_VER + set -u (ordem oficial) e remove linhas em branco desnecessarias

## v1.0.8 (2026-01-08)
* CHG: warn/feed logs agora em /tmp/avp_logs (opt AVP_LOGDIR) — evita escrita no jffs

## v1.0.7 (2026-01-05)
* CHORE: padroniza header + changelog (C1.5)

## v1.0.6 (2026-01-04)
* FIX: install não falha quando avp.asp source == destination (cp same file vira no-op OK)

## v1.0.5 (2026-01-04)
* CHG: avp-webui.sh vira somente installer/orquestrador (remove templates embutidos de asp/feeder e runtime legado)
* SAFETY: install/uninstall não sobrescrevem feeder nem geram avp.asp; usam arquivos canônicos e chamam feeder real
* ADD: validações explícitas (fonte do avp.asp, feeder executável) + mensagens de erro claras

## v1.0.4 (2025-12-31)
* ADD: Open logs (Feed Summary/State/Warn + AVP Last (POL))
* ADD: Modos LIVE com dica "Ctrl+C pra sair"

## v1.0.3 (2025-12-30)
* FIX: Evita CGI e appGet (incompatibilidades/whitelist/token em alguns 3006)
* ADD: Endpoint estático /user/avp-status.json (arquivo)
* ADD: Daemon feeder avp-webui-feed.sh (atualiza JSON a cada 5s)
