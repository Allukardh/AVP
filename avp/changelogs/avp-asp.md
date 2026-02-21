# CHANGELOG — AVP-ASP

## v1.0.19 (2026-02-21)
  * CHG: WebUI troca referências visuais de devices.conf para SSOT (VPN Director)
  * FIX: bump do WEBUI_VER + header version (fase 6)
- v1.0.18 (2026-02-10)
  * FIX: auto-refresh default (5s) + persist in localStorage (avp_auto) without breaking guards
- v1.0.17 (2026-02-10)
  * FIX: defensivo contra DOM ausente (evita crash e regressão de auto-refresh)
- v1.0.16 (2026-02-10)
  * FIX: restore <span id="last"> in header card (avoid JS null crash) — WebUI v1.0.15 hotfix
- v1.0.15 (2026-02-10)
  * ADD: WebUI Console (apply.cgi) + last action box (/user/avp-action-last.json) + toast
  * ADD: Console actions: toggle enable/disable, reload, snapshot, dhcp_refresh (normal/aggressive), profile list/get/set, device list/add/remove/update
- v1.0.14 (2026-02-09)
  * FIX: toolbar Order/Auto-refresh (rebuild HTML; restore options/labels) + keep default SSOT order (VPN Director)
- v1.0.13 (2026-02-09)
  * UX: Order selector (devices.conf default; optional label/pref) + persist in localStorage (fix HTML injection + smoke gate)
- v1.0.11 (2026-01-27) - CHORE: changelog entry (smoke gate)
- v1.0.10 (2026-01-08)
  * CHG: logs (FEED_STATE/FEED_WARN/POL_LAST) agora em /tmp/avp_logs — evita escrita no jffs
- v1.0.9 (2026-01-07)
  * FIX: bump do pill de versao (WEBUI_VER + texto inicial do #ver)
- v1.0.8 (2026-01-04)
  * CHORE: adiciona header + mini-changelog interno (estilo ENG)
  * FIX: corrige markup do "Last refresh" (linha quebrada)
- v1.0.7 (2026-01-04)
  * FIX: Open logs (btnLogs) handler único + logMode (C1.5)