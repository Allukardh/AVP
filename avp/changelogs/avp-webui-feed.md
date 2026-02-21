# AVP-WEBUI Feeder

## v1.2.17 (2026-02-20)
- DOC: externaliza CHANGELOG para /jffs/scripts/avp/changelogs/avp-webui-feed.md
- CHG: remove bloco CHANGELOG embutido do script

## v1.2.16 (2026-02-16)
- FIX: OUT SSOT em /jffs/scripts/avp/www
- FIX: start do feeder daemoniza corretamente (redirect >/dev/null 2>&1 &)
## v1.2.15 (2026-01-27)
- HARDEN: trap cleanup do LOCK/PID no loop (EXIT/INT/TERM); reduz lock preso em stop/kill.
## v1.2.14 (2026-01-26)
- VERSION: bump patch (pos harden canônico)
## v1.2.13 (2026-01-18)
- POLISH: padroniza SCRIPT_VER + set -u (ordem oficial) e remove linhas em branco desnecessarias
## v1.2.12 (2026-01-08)
- CHG: Flash-Safe v1: EVENT (start/stop) em /jffs/scripts/avp/logs; warn/state seguem em /tmp/avp_logs
## v1.2.11 (2026-01-08)
- CHG: LOGDIR padrao agora /tmp/avp_logs (opt AVP_LOGDIR) para evitar escrita no jffs
## v1.2.10 (2026-01-05)
- CHORE: padroniza header + changelog (C1.5)
## v1.2.9 (2026-01-04)
- ADD(C1.5): feed_epoch no JSON publicado pelo feeder (staleness-safe)
## v1.2.8 (2026-01-04)
- FIX: start() usa lockdir de verdade (acquire_lock_or_exit) antes do spawn
- FIX: loop fica HUP-safe (trap '' HUP) pra sobreviver a logout/queda de sessão
- ADD: valida se o loop ficou vivo (kill -0 após 1s) e loga motivo
## v1.2.7 (2026-01-04)
- ADD: erro estruturado no JSON (err:{level,code,where,hint}) mantendo errors[] para compatibilidade
- ADD: purge leve de /tmp (avp_webui_out.*) para evitar sobras órfãs AVP-only
## v1.2.6 (2025-12-31)
- FIX: reintroduz anti-orphan no start() após gravar LOCK/pid (impede duplicidade e protege o próprio start)
