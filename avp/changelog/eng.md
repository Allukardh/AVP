# eng

## v2.0.0 (2026-02-20)
* CHG: migrate avp-eng.sh -> avp-eng (Python wrapper v2.0.0) — delega ao script shell legado para manter compatibilidade completa enquanto preparamos a migração nativa.

## v1.2.40 (2026-02-06)
* FIX: init dev_mode no state quando ausente (evita WebUI/CLI "unknown" em devices novos):contentReference[oaicite:0]{index=0}.

## v1.2.39 (2026-01-27)
* CHORE: hygiene (trim trailing whitespace; collapse blank lines; sem mudança de lógica):contentReference[oaicite:1]{index=1}.

## v1.2.38 (2026-01-27)
* CHORE: hygiene (whitespace/blank lines; sem mudança de lógica):contentReference[oaicite:2]{index=2}.

## v1.2.37 (2026-01-26)
* VERSION: bump patch (pós harden canônico):contentReference[oaicite:3]{index=3}.

## v1.2.36 (2026-01-26)
* HARDEN: set_state() usa writer canônico (atomic + chmod 0600) para avp_${SL}.state:contentReference[oaicite:4]{index=4}.

## v1.2.35 (2026-01-26)
* HARDEN: garantir chmod 0600 em avp_${SL}.state (evita 0666 por umask):contentReference[oaicite:5]{index=5}.

## v1.2.34 (2026-01-21)
* POLISH: PATH robusto (cron/non-interactive) alinhado ao padrão AVP; sem impacto no motor:contentReference[oaicite:6]{index=6}.

## v1.2.33 (2026-01-18)
* POLISH: padroniza SCRIPT_VER + set -u (ordem oficial) e remove linhas em branco desnecessárias:contentReference[oaicite:7]{index=7}.

## v1.2.32 (2026-01-17)
* POLISH: higiene (remove termo legado do ping-interval nos docs/changelog) + harden na quebra de log [CONFIG] (anti-wrap):contentReference[oaicite:8]{index=8}.

## v1.2.31 (2026-01-17)
* POLISH: higiene (remove palavra ping-interval do changelog) + quebra log [CONFIG] >200 chars (anti-wrap):contentReference[oaicite:9]{index=9}.

## v1.2.30 (2026-01-16)
* CHORE: higiene do changelog (consolida entradas repetidas do topo; sem impacto no motor):contentReference[oaicite:10]{index=10}.

## v1.2.29 (2026-01-16)
* CHORE: remove legado do ping-interval (config/help/docs) e alinha SCRIPT_VER com header (sem impacto no motor):contentReference[oaicite:11]{index=11}.

## v1.2.28 (2026-01-16)
* NOTE: versão consumida durante higiene operacional (sem mudança funcional; consolidado no v1.2.30):contentReference[oaicite:12]{index=12}.

## v1.2.27 (2026-01-16)
* NOTE: versão consumida durante higiene operacional (sem mudança funcional; consolidado no v1.2.30):contentReference[oaicite:13]{index=13}.

## v1.2.26 (2026-01-16)
* NOTE: versão consumida durante higiene operacional (sem mudança funcional; consolidado no v1.2.30):contentReference[oaicite:14]{index=14}.

## v1.2.25 (2026-01-16)
* FIX: usb_rotate_daily dedup de arquivos (evita glob duplicado ao casar Y e YMD):contentReference[oaicite:15]{index=15}.

## v1.2.24 (2026-01-16)
* POLISH: get_state/set_state agora usam awk (sem grep|tail|cut pipeline); preserva "last wins" e mantém escrita atômica (tmp+mv); remove keys anteriores via awk:contentReference[oaicite:16]{index=16}.
* NOTE: state agora é awk-only; grep/tail/cut seguem críticos por escolha conservadora (não por dependência do state):contentReference[oaicite:17]{index=17}.

## v1.2.23 (2026-01-16)
* POLISH: rotate --rotate-usb passa por require_cmds (evita rotação silenciosa sem dependências):contentReference[oaicite:18]{index=18}.
* POLISH: require_cmds: grep/tail/cut seguem CRITICAL (decisão conservadora; state não depende mais):contentReference[oaicite:19]{index=19}.
* POLISH: usb_rotate_daily usa Y=avp_day (coerente com janela 06:00→05:59):contentReference[oaicite:20]{index=20}.

## v1.2.22 (2026-01-16)
* FIX: retenção 30d inclui archives .tar.gz (mantém compat com legado .gz):contentReference[oaicite:21]{index=21}.

## v1.2.21 (2026-01-16)
* FIX: janela 06:00→05:59: introduz AVP_DAY (hora<06 => dia anterior) para nomear logs e cycles:contentReference[oaicite:22]{index=22}.
* FIX: rotate usa prev_day() robusto (sem depender de date -d do BusyBox):contentReference[oaicite:23]{index=23}.
* CHG: padroniza nomes com hífen: avp_eng_YYYY-MM-DD_HHMMSS.log:contentReference[oaicite:24]{index=24}.
* CHG: archive coerente: avp_eng_YYYY-MM-DD_logs.tar.gz (antes .gz):contentReference[oaicite:25]{index=25}.

## v1.2.20 (2026-01-16)
* FIX: usb_rotate_daily: USB_DIR=/mnt/AVPUSB/avp_logs + glob YYYYMMDD (YMD) para compactar avp_eng_YYYYMMDD_HHMMSS.log:contentReference[oaicite:26]{index=26}.

## v1.2.19 (2026-01-14)
* POLISH: age_print=NA sem sufixo 's' (quando PREV_TS=0):contentReference[oaicite:27]{index=27}.
* POLISH: log único no boot quando DWARN_TTL=0 (desativado):contentReference[oaicite:28]{index=28}.

## v1.2.18 (2026-01-14)
* CHG: still_degraded WARN: age_print=NA quando PREV_TS=0 (log mais semântico):contentReference[oaicite:29]{index=29}.

## v1.2.17 (2026-01-13)
* CHG: degraded_iface WARN = transição + reset em quarentena + TTL opcional (DWARN_TTL):contentReference[oaicite:30]{index=30}.
* CHG: still_degraded re-warn controlado (ttl/age), sem spam (DWARN_TTL=0 desliga):contentReference[oaicite:31]{index=31}.

## v1.2.16 (2026-01-13)
* FIX: Merlin/BusyBox ping não suporta -i; removido -i do ping (evita INF falso: packet_loss all_targets):contentReference[oaicite:32]{index=32}.
* FIX: WARN degraded_iface state-key: usar IF (interface do loop), não WG (variável stale):contentReference[oaicite:33]{index=33}.

## v1.2.15 (2026-01-13)
* CHG: ping metrics: -c 10 -W 1 (PINGCOUNT=10, PINGW=1):contentReference[oaicite:34]{index=34}.
* CHG: TARGETS primário→fallback real (8.8.8.8 → 1.1.1.1); INF somente se ambos falharem (loss!=0):contentReference[oaicite:35]{index=35}.
* ADD: E1: summary JSON por ciclo (último ciclo) em /tmp para consumo da WebUI:contentReference[oaicite:36]{index=36}.

## v1.2.14 (2026-01-08)
* CHG: Flash-Safe v1: em falha (rc!=0) grava ERROR em /jffs/scripts/logs/avp_errors.log:contentReference[oaicite:37]{index=37}.

## v1.2.13 (2026-01-08)
* CHG: eng logs default /tmp/avp_logs (opt AVP_LOGDIR):contentReference[oaicite:38]{index=38}.

## v1.2.12 (2026-01-07)
* CHORE: remove definição duplicada de cleanup_tmp() (sem impacto funcional):contentReference[oaicite:39]{index=39}.
* POLISH: split FW_KERNEL/FW_BUILD/FW_FW assignments (evita wrap):contentReference[oaicite:40]{index=40}.

## v1.2.11 (2025-12-29)
* FIX: B5 purge_tmp_orphans sem erro de escopo (remove chamada solta + remove duplicata):contentReference[oaicite:41]{index=41}.

## v1.2.10 (2025-12-29)
* CHORE: B5 sanitize /tmp (remove órfãos avp_eng.* por PID morto, sem regressão):contentReference[oaicite:42]{index=42}.

## v1.2.9 (2025-12-29)
* FIX: aborts iniciais agora geram log bootstrap (melhor observabilidade no cron/CLI):contentReference[oaicite:43]{index=43}.

## v1.2.8 (2025-12-29)
* ADD: --help/-h documenta uso correto do ENG:contentReference[oaicite:44]{index=44}.
* SAFETY: explicita bloqueio de execução standalone (override documentado):contentReference[oaicite:45]{index=45}.

## v1.2.7 (2025-12-29)
* FIX: AVP_LIVE=1 agora é live real (stream do TMPLOG no terminal durante execução):contentReference[oaicite:46]{index=46}.
* SAFETY: bloqueia execução standalone por padrão (use POL); override: AVP_ALLOW_STANDALONE=1 ou --standalone:contentReference[oaicite:47]{index=47}.
* CHG: TARGETS com primário+fallback (8.8.8.8 → 1.1.1.1) somente se falhar:contentReference[oaicite:48]{index=48}.
* CHG: PINGW default=1 (PINGCOUNT permanece 5):contentReference[oaicite:49]{index=49}.

## v1.2.6 (2025-12-28)
* FIX: lockdir compat (arquivo→dir) + stale lock cleanup (pid não roda):contentReference[oaicite:50]{index=50}.
* FIX: trap unificado (cleanup tmp + release_lock) + inclui HUP:contentReference[oaicite:51]{index=51}.

## v1.2.5 (2025-12-28)
* CHG: [CONFIG] dividido em 2 linhas para evitar wrap/truncamento em terminais e logs:contentReference[oaicite:52]{index=52}.

## v1.2.4 (2025-12-27)
* POLISH: cleanup TMP_DEVLIST (trap) + tee sem pipe:contentReference[oaicite:53]{index=53}.

## v1.2.3 (2025-12-27)
* FIX (GapB): adiciona set_rc() (first error wins) para preservar código final do engine:contentReference[oaicite:54]{index=54}.
* FIX (GapB): apply_device_table retorna code=30 + NEXT hints (ip rule/ip route) e define rc via set_rc:contentReference[oaicite:55]{index=55}.
* FIX (GapB): device loop no MAIN sem pipeline/subshell para manter ENG_RC entre devices:contentReference[oaicite:56]{index=56}.

## v1.2.2 (2025-12-26)
* ADD: Gap A — códigos padronizados + NEXT acionável para falhas críticas (pre-GUI):contentReference[oaicite:57]{index=57}.
* CHG: missing_cmds(critical) -> code=10 (instrução: type ... / PATH/BusyBox/Entware):contentReference[oaicite:58]{index=58}.
* CHG: logdir failures -> code=11 + NEXT:contentReference[oaicite:59]{index=59}.
* CHG: statedir failures -> code=12 + NEXT:contentReference[oaicite:60]{index=60}.
* CHG: fallback para ausência de tee (stdout + append em log, sem quebrar execução):contentReference[oaicite:61]{index=61}.

## v1.2.1 (2025-12-26)
* FIX: RC real do core preservado (MAIN em subshell + TMPLOG + tee) — caller/cron recebe o rc correto:contentReference[oaicite:62]{index=62}.
* FIX: devices.conf ausente/inválido retorna code=20 com [NEXT] acionável (caminho + formato esperado):contentReference[oaicite:63]{index=63}.
* CHG: lock ativo retorna code=99 com mensagem + próxima ação (remover /tmp/avp_eng.lock se preso):contentReference[oaicite:64]{index=64}.

## v1.2.0 (2025-12-26)
* MINOR: pre-GUI hardening; devices.conf vira fonte única (remove hardcode de devices/IP/pref); cabeçalho Devices dinâmico; abort-only sem devices.conf:contentReference[oaicite:65]{index=65}.

## v1.1.0 (2025-12-25)
* ADD: suporte a knobs estendidos via profiles.conf (WAN/RET-DEF/QUAR) — sem mudar defaults do core:contentReference[oaicite:66]{index=66}.
* CHORE: log de contexto (profile + CONFIG efetivo) para auditoria/afinação na Etapa C:contentReference[oaicite:67]{index=67}.
* FIX: log inicial agora expande corretamente FW_BUILD/FW_FW (sem escapes literais):contentReference[oaicite:68]{index=68}.

## v1.0.14 (2025-12-24)
* FIX: devices.conf loader CRLF-safe + EOF-safe (aceita última linha sem newline):contentReference[oaicite:69]{index=69}.
* FIX: DEVICES_LIST usa "\\n" literal (evita string multilinha que quebra o shell):contentReference[oaicite:70]{index=70}.

## v1.0.13 (2025-12-23)
* CHORE: changelog hygiene (semântica ADD/CHG/FIX/CHORE/STD + nota de gaps):contentReference[oaicite:71]{index=71}.

## v1.0.12 (2025-12-23)
* STD: padroniza header + bloco CHANGELOG (Etapa A):contentReference[oaicite:72]{index=72}.

## v1.0.11 (2025-12-21)
* FIX: QUAR_* defaults (sem regressão):contentReference[oaicite:73]{index=73}.

## v1.0.10 (2025-12-21)
* CHORE: observabilidade (sem mudança de decisão):contentReference[oaicite:74]{index=74}.

## v1.0.9 (2025-12-21)
* CHG: profiles (overrides via env com defaults preservados):contentReference[oaicite:75]{index=75}.

## v1.0.8 (2025-12-20)
* CHORE: changelog reorganizado (somente comentários):contentReference[oaicite:76]{index=76}.

## v1.0.7 (2025-12-20)
* FIX: sanitize_label (compatibilidade BusyBox):contentReference[oaicite:77]{index=77}.

## v1.0.6 (2025-12-20)
* NOTE: versão existiu durante iteração, mas sem registro confiável nos MDs/commits para detalhar:contentReference[oaicite:78]{index=78}.

## v1.0.5 (2025-12-20)
* NOTE: versão existiu durante iteração, mas sem registro confiável nos MDs/commits para detalhar:contentReference[oaicite:79]{index=79}.

## v1.0.4 (2025-12-20)
* FIX: devices.conf strict (obrigatório; se ausente/inválido -> aborta com [ERR]):contentReference[oaicite:80]{index=80}.

## v1.0.3 (2025-12-20)
* CHG: integração Policy → Engine (Device Loader via devices.conf):contentReference[oaicite:81]{index=81}.

## v1.0.2 (2025-12-19)
* FIX: log/consistência pós-switch:contentReference[oaicite:82]{index=82}.

## v1.0.1 (2025-12-19)
* FIX: set -u (evita "parameter not set"):contentReference[oaicite:83]{index=83}.

## v1.0.0 (2025-12-19)
* CHORE: observabilidade + quarentena (sem regressão do core):contentReference[oaicite:84]{index=84}.
