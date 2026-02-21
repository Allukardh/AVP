# CHANGELOG — AVP-WEBUI

## v1.0.6 (2026-02-20)
- DOC: externaliza CHANGELOG para /jffs/scripts/avp/changelogs/service-event.md
- CHG: remove bloco CHANGELOG embutido do script
## v1.0.5 (2026-02-17)
- CHG: atualiza ACT/POL p/ nova estrutura (avp/bin) (hook usa caminho absoluto)
## v1.0.4 (2026-02-16)
- FIX: WebUI backend SSOT last-action (write SSOT + /www/user symlink)
- FIX: ensure_monotonic_ts usa SSOT (evita break no polling)
- FIX: auto token_get no backend p/ actions (profile_list/toggle/etc)
## v1.0.3 (2026-02-10)
- FIX: ensure monotonic ts in last.json (avoid same-second actions breaking UI polling)
## v1.0.2 (2026-02-10)
- FIX: accept Merlin service-event args (event=start/stop/restart, target=svc) and also restart_svc form
- ADD: log argv + normalized event/target for observability
## v1.0.1 (2026-02-10)
- FIX: BusyBox/Merlin: remove dependency on 'install' (use cp+chmod only)
- FIX: last-action writer now deterministic on Merlin
## v1.0.0 (2026-02-10)
- ADD: hook for rc_service=avp_webui_restart (nvram contract avp_webui_*)
- ADD: last-action JSON writer (/www/user + /tmp/var/wwwext) + action log
- ADD: alias map (device_remove->device_del, device_update->device_set) + toggle (enable/disable)
