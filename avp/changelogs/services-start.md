# CHANGELOG — AVP-BOOT

## v1.1.26 (2026-02-20)
- DOC: externaliza CHANGELOG para /jffs/scripts/avp/changelogs/services-start.md
- CHG: remove bloco CHANGELOG embutido do script
## v1.1.25 (2026-02-17)
- POLISH: AVP_ENG_ROTATE_PAYLOAD inclui /jffs/scripts/avp/bin no PATH (coerencia de estrutura)
## v1.1.24 (2026-02-17)
- CHG: atualiza paths p/ nova estrutura (avp/bin) nos calls do hook (cron/rotate/webui-feed)
## v1.1.23 (2026-02-17)
- CHG: remove PERMS HARDEN (auto-chmod) + modo --perms-only (não necessário)
## v1.1.22 (2026-02-16)
- FIX: restaura bullets do CHANGELOG historico (v1.1.9/v1.1.8/v1.0.2/v1.0.1) que regrediram
## v1.1.21 (2026-02-16)
- FIX: restaura linhas do CHANGELOG historico (v1.1.10/v1.1.9/v1.0.3/v1.0.2) que regrediram
## v1.1.20 (2026-02-16)
- CHG: delega a montagem do Entware ao AMTM (mount-entware.mod) via post-mount; remove vestigios do legacy mount-fix
## v1.1.19 (2026-02-16)
- FIX: WebUI SSOT em /jffs/scripts/avp/www (remove confusao com /jffs/addons)
- FIX: garante /www/user antes do symlink avp-action-last.json (race no boot)
## v1.1.18 (2026-02-15)
- FIX: remove duplicacao do pre-populate known_hosts (mantem apenas o bloco deterministico)
## v1.1.17 (2026-02-15)
- FIX: remove duplicacao do bloco SSH HOME FIX (GitHub)
- FIX: injeta bloco unico antes do boot settle + known_hosts via StrictHostKeyChecking=accept-new (non-blocking)
## v1.1.16 (2026-02-15)
- FIX: GitHub known_hosts auto via OpenSSH accept-new (ssh -T puro, sem ssh-keyscan)
## v1.1.15 (2026-02-15)
- FIX: header date -> 2026-02-15
- FIX: recria /root/.ssh -> /jffs/.ssh no boot (GitHub ssh -T puro) antes do boot settle
## v1.1.14 (2026-01-26)
- VERSION: bump patch (pos harden canônico)
## v1.1.13 (2026-01-26)
- HARDEN: perms 0600 dinamico em /jffs/scripts/avp/state/* (suporta devices/GUI sem paths fixos)
## v1.1.12 (2026-01-26)
- HARDEN: auto-fix perms (chmod) no boot + modo --perms-only (corrige 0666/0777)
## v1.1.11 (2026-01-18)
- POLISH: padroniza SCRIPT_VER + set -u (ordem oficial) e remove linhas em branco desnecessarias
## v1.1.10 (2026-01-17)
- POLISH: logs do Entware mais cirurgicos (detectado + rc do bind + suspeito com src)
## v1.1.9 (2026-01-17)
- FIX: Entware autodetect em /tmp/mnt/* (robusto a label/nome do mount) + bind /tmp/opt
## v1.1.8 (2026-01-16)
- FIX: AVP-ENG-ROTATE fica com 1 linha canonica (payload-var + aspas seguras), removendo duplicacoes/quoting quebrado
## v1.1.7 (2026-01-16)
- FIX: rotate cron usa payload-var com quoting robusto; remove duplicacao de cru a AVP-ENG-ROTATE
## v1.1.6 (2026-01-16)
- CHORE: rotacao USB usa payload em variavel; changelog sem sequencia (hex) para evitar falso-positivo de grep
## v1.1.5 (2026-01-16)
- FIX: remove linha cru a AVP-ENG-ROTATE com escape hex literal; mantém apenas a forma com aspas reais
## v1.1.4 (2026-01-16)
- FIX: services-start executavel (+x) e comando cru sem escape hex literal (quoting correto no boot)
## v1.1.3 (2026-01-16)
- ADD: cron diario 05:58 para avp-eng.sh --rotate-usb (preserva logs em /tmp antes do reboot 06:00)
## v1.1.2 (2025-12-31)
- FIX: evita start duplicado do AVP WebUI feeder no boot (services-start tinha 2 chamadas)
## v1.1.1 (2025-12-30)
- FIX: Recria symlinks do AVP WebUI em /www/user a cada boot (/www é volátil)
- FIX: Symlink do JSON é criado mesmo antes do arquivo existir (feeder cria depois)
## v1.1.0 (2025-12-30)
- ADD: start do AVP WebUI feeder no boot (gera /user/avp-status.json)
## v1.0.9 (2025-12-26)
- CHG: cron AVP-POL agora executa /jffs/scripts/avp/bin/avp-pol-cron.sh (log dedicado com timestamp + rc)
## v1.0.8 (2025-12-24)
- CHORE: polimento preparatório pra GUI (suite alinhada)
## v1.0.7 (2025-12-24)
- CHORE: cron renomeado de DEVICE_FAILOVER para AVP-POL (sem alterar comando/frequencia)
## v1.0.6 (2025-12-23)
- CHORE: consolidacao historica e renumeração coerente (Etapa B)
## v1.0.5 (2025-12-23)
- STD: padroniza header + bloco CHANGELOG (Etapa A)
## v1.0.4 (2025-12-23)
- FIX: remove dependencia de mountpoint (Merlin-safe) via /proc/mounts
## v1.0.3 (2025-12-23)
- FIX: aguarda Entware REAL ficar pronto (opkg executavel) antes de prosseguir
## v1.0.2 (2025-12-23)
- ADD: montagem persistente do Entware em /opt via bind mount (USB)
## v1.0.1 (2025-12-20)
- CHG: cron chama AVP-POL (--run) em vez de AVP-ENG direto
## v1.0.0 (2025-12-20)
- BASE: cron inicial do failover multi-dispositivo
