<!DOCTYPE html>
<!--
=============================================================
AutoVPN Platform (AVP)
Component : AVP-WEBUI (ASP)
File      : avp.asp
Role      : WebUI frontend (router user page)
Version   : v1.0.11 (2026-01-27)
Status    : stable
=============================================================

CHANGELOG
- v1.0.10 (2026-01-08)
  * CHG: logs (FEED_STATE/FEED_WARN/POL_LAST) agora em /tmp/avp_logs — evita escrita no jffs
- v1.0.9 (2026-01-07)
  * FIX: bump do pill de versao (WEBUI_VER + texto inicial do #ver)
- v1.0.8 (2026-01-04)
  * CHORE: adiciona header + mini-changelog interno (estilo ENG)
  * FIX: corrige markup do "Last refresh" (linha quebrada)
- v1.0.7 (2026-01-04)
  * FIX: Open logs (btnLogs) handler único + logMode (C1.5)
-->
<html>
<head>
  <meta charset="utf-8">
  <title>AVP — AutoVPN Platform</title>
  <style>

  /* C1.5: Age ok/warn/bad (UI staleness) */
  #age.ok{ color:#0a7a0a; font-weight:600; }
  #age.warn{ color:#c77700; font-weight:700; }
  #age.bad{ color:#b00020; font-weight:800; }

    body { font-family: Arial, Helvetica, sans-serif; margin: 16px; }
    .row { display:flex; gap:12px; flex-wrap:wrap; align-items:center; }
    .card { border:1px solid #bbb; border-radius:8px; padding:12px; min-width:260px; }
    .muted { opacity:.75; }
    .btn { border:1px solid #666; background:#f2f2f2; border-radius:6px; padding:6px 10px; cursor:pointer; }
    .btn:active { transform: translateY(1px); }
    table { border-collapse: collapse; width: 100%; margin-top: 12px; }
    th, td { border:1px solid #bbb; padding:8px; text-align:left; }
    th { background:#efefef; }
    .ok { color:#1b7f1b; font-weight:bold; }
    .warn { color:#b85c00; font-weight:bold; }
    .bad { color:#b00020; font-weight:bold; }
    pre { background:#f6f6f6; border:1px solid #ddd; border-radius:8px; padding:10px; overflow:auto; }
    .pill { display:inline-block; border:1px solid #aaa; border-radius:999px; padding:2px 10px; background:#fafafa; }
    code { background:#f6f6f6; padding:2px 6px; border-radius:6px; }
  </style>
</head>
<body>
  <h2>AVP — AutoVPN Platform <span class="pill" id="ver">WebUI v1.0.8</span></h2>

  <div class="row">
    <div class="card">
      <div><b>Status:</b> <span id="enabled">...</span></div>
      <div><b>Profile:</b> <span id="profile">...</span></div>
      <div class="muted" style="margin-top:8px;">Last refresh: <span id="last">...</span> <span class="muted">(age: <span id="age">...</span>)</span></div>
    </div>

    <div class="card">
      <div class="row">
        <button class="btn" id="btnRefresh">Refresh</button>
        <button class="btn" id="btnCopy">Copy JSON</button>
        <button class="btn" id="btnOpenJson">Open JSON</button>
        <button class="btn" id="btnKv">status --kv</button>
        <select id="logMode">
          <option value="feed_summary">Feed Summary</option>
          <option value="feed_state">Feed State (last)</option>
          <option value="feed_warn">Feed Warn (last)</option>
          <option value="pol_last">AVP Last (POL)</option>
          <option value="feed_live">Feed LIVE</option>
          <option value="pol_live">AVP Last (POL LIVE)</option>
        </select>
        <button class="btn" id="btnLogs">Open logs</button>
        <label class="muted">
          Filter
          <select id="filter">
            <option value="all" selected>all</option>
            <option value="vpn">vpn</option>
            <option value="wan">wan</option>
          </select>
        </label>

        <label class="muted">
          Auto-refresh
          <select id="auto">
            <option value="0">off</option>
            <option value="5" selected>5s</option>
            <option value="10">10s</option>
            <option value="30">30s</option>
          </select>
        </label>
      </div>
      <div class="muted" style="margin-top:8px;">
        Endpoint: <code>/user/avp-status.json</code>
      </div>
    </div>
  </div>

  <div id="errorsBox" style="display:none; margin-top:12px;">
    <div class="card">
      <div class="bad"><b>Errors</b></div>
      <pre id="errors"></pre>
    </div>
  </div>

  <table>
    <thead>
      <tr>
        <th>Label</th>
        <th>IP</th>
        <th>Pref</th>
        <th>State</th>
        <th>Route</th>
        <th>Last switch (epoch)</th>
      </tr>
    </thead>
    <tbody id="tbody">
      <tr><td colspan="6" class="muted">Loading...</td></tr>
    </tbody>
  </table>

<script>
(function(){
  const $ = (id)=>document.getElementById(id);
  let timer = null;

  const WEBUI_VER = "v1.0.11";
  if ($("ver")) $("ver").textContent = "WebUI " + WEBUI_VER;


  // Endpoint fixo do feed
  const ENDPOINT = "/user/avp-status.json";

  // guarda o JSON bruto pra "Copy JSON"
  let lastRawJson = "";

  function escapeHtml(s){
    s = (s === null || s === undefined) ? "" : String(s);
    return s.replace(/[&<>"']/g, function(m){
      return ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]);
    });
  }

  function stateBadge(state){
    const s = (state||"unknown").toLowerCase();
    if (s === "vpn") return '<span class="ok">vpn</span>';
    if (s === "wan") return '<span class="warn">wan</span>';
    if (s === "unknown") return '<span class="muted">unknown</span>';
    return '<span class="muted">' + escapeHtml(state) + '</span>';
  }

  // route: state + table (wgc2/wgc3 etc)
  function routeHtml(d){
    const st = (d && d.state) ? String(d.state).toLowerCase() : "unknown";
    const tb = (d && d.table) ? String(d.table) : "";
    const tbPill = tb ? (' <span class="pill" style="font-size:12px; padding:1px 8px;">' + escapeHtml(tb) + '</span>') : "";
    return escapeHtml(st) + tbPill;
  }

  function fmtAgeSec(sec){
    sec = Math.max(0, Math.floor(sec || 0));
    const m = Math.floor(sec/60);
    const h = Math.floor(m/60);
    const d = Math.floor(h/24);
    if (d > 0) return d + "d " + (h%24) + "h";
    if (h > 0) return h + "h " + (m%60) + "m";
    if (m > 0) return m + "m " + (sec%60) + "s";
    return sec + "s";
  }

  function fmtEpoch(epoch){
    const n = Number(epoch);
    if (!isFinite(n) || n <= 0) return "";
    return new Date(n * 1000).toLocaleString();
  }

  function ageFromEpoch(epoch){
    const n = Number(epoch);
    if (!isFinite(n) || n <= 0) return "";
    const ms = Date.now() - (n * 1000);
    if (ms < 0) return "";
    return fmtAgeSec(ms/1000);
  }

  async function load(){
    try{
      const url = ENDPOINT + "?_=" + Date.now();
      const r = await fetch(url, { cache: "no-store" });

      // tenta pegar last-modified pra "age"
      const lm = r.headers.get("Last-Modified");
      if (lm){
        const t = Date.parse(lm);
        if (!isNaN(t)){
          const sec = (Date.now() - t) / 1000;
          if ($("age")) $("age").textContent = fmtAgeSec(sec) + " ago";
        }
      } else {
        if ($("age")) $("age").textContent = "n/a";
      }

      const txt = await r.text();

      // Se voltar HTML (login), falha com msg clara
      if ((txt || "").trim().startsWith("<")) throw new Error("Not authenticated (login required)");

      lastRawJson = txt;

      const j = JSON.parse(txt);

      // C1.5: feed_epoch (staleness-safe) vindo do feeder
      const fe = (j && typeof j.feed_epoch === "number") ? j.feed_epoch : null;
      if (fe){
        const ageSec = Math.max(0, Math.floor(Date.now()/1000 - fe));
        const lastTxt = fmtEpoch(fe);
        if (lastTxt) $("last").textContent = lastTxt;
        const ageEl = $("age");
        ageEl.textContent = fmtAgeSec(ageSec) + " ago";
        // thresholds: <20s ok, 20-59s warn, >=60s bad
        const cls = (ageSec >= 60) ? "bad" : (ageSec >= 20 ? "warn" : "ok");
        // classList-safe: não apaga outras classes do elemento
        ageEl.classList.remove("ok","warn","bad");
        ageEl.classList.add(cls);
      }
      $("enabled").innerHTML = (j.enabled === 1) ? '<span class="ok">enabled</span>' : '<span class="bad">disabled</span>';
      $("profile").textContent = j.profile || "n/a";
      if (!fe) $("last").textContent = new Date().toLocaleString();

      if (j.errors && j.errors.length){
        $("errorsBox").style.display = "";
        $("errors").textContent = JSON.stringify(j.errors, null, 2);
      } else {
        $("errorsBox").style.display = "none";
      }

      const tb = $("tbody");
      tb.innerHTML = "";

      let devs = (j.devices || []);

      // filtro
      const f = $("filter") ? String($("filter").value || "all") : "all";
      if (f === "vpn") devs = devs.filter(d => String(d.state||"").toLowerCase() === "vpn");
      if (f === "wan") devs = devs.filter(d => String(d.state||"").toLowerCase() === "wan");

      // ordenar por label
      devs.sort((a,b)=> String(a.label||"").localeCompare(String(b.label||"")));

      if (!devs.length){
        tb.innerHTML = '<tr><td colspan="6" class="muted">No devices</td></tr>';
        return;
      }

      for (const d of devs){
        const tr = document.createElement("tr");

        const epoch = (d.last_switch_epoch !== undefined) ? d.last_switch_epoch : "";
        const human = fmtEpoch(epoch);
        const age = ageFromEpoch(epoch);

        let lastCell = escapeHtml(epoch);
        if (human){
          lastCell = escapeHtml(epoch) +
            '<div class="muted" style="margin-top:2px;">' +
            escapeHtml(human) + (age ? (' · ' + escapeHtml(age) + ' ago') : '') +
            '</div>';
        }

        tr.innerHTML =
          "<td>" + escapeHtml(d.label) + "</td>" +
          "<td>" + escapeHtml(d.ip) + "</td>" +
          "<td>" + escapeHtml(d.pref) + "</td>" +
          "<td>" + stateBadge(d.state) + "</td>" +
          "<td>" + routeHtml(d) + "</td>" +
          "<td>" + lastCell + "</td>";

        tb.appendChild(tr);
      }
    }catch(e){
      $("enabled").innerHTML = '<span class="bad">error</span>';
      $("profile").textContent = "n/a";
      $("last").textContent = new Date().toLocaleString();
      if ($("age")) $("age").textContent = "n/a";

      $("errorsBox").style.display = "";
      $("errors").textContent = "Fetch/parse error: " + (e && e.message ? e.message : String(e));

      const tb = $("tbody");
      tb.innerHTML = '<tr><td colspan="6" class="bad">Failed to load JSON from /user/avp-status.json</td></tr>';
    }
  }

  function setAuto(sec){
    if (timer){ clearInterval(timer); timer = null; }
    if (sec > 0){
      timer = setInterval(function(){
        if (document.visibilityState === "visible") load();
      }, sec * 1000);
    }
  }

  // Buttons
  function copyToClipboard(text){
    text = String(text || "");
    if (navigator.clipboard && navigator.clipboard.writeText){
      return navigator.clipboard.writeText(text);
    }
    // fallback legacy (document.execCommand)
    const ta = document.createElement("textarea");
    ta.value = text;
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand("copy"); } catch(_) {}
    document.body.removeChild(ta);
    return Promise.resolve();
  }

  if ($("btnCopy")){
  $("btnCopy").addEventListener("click", function(){
    // Copy JSON (fresh): evita copiar JSON antigo em cache
    (async function(){
      try {
        const u = ENDPOINT + "?_=" + Date.now();
        const r = await fetch(u, { cache: "no-store" });
        const txt = await r.text();
        await copyToClipboard(txt);
        toast("Copied fresh JSON");
      } catch(e){
        // fallback: copy lastRawJson (in-memory)
        try { await copyToClipboard(lastRawJson || ""); } catch(_) {}
        toast("Copy failed");
      }
    })();
  });
  }

  if ($("btnOpenJson")){
    $("btnOpenJson").addEventListener("click", function(){
      window.open(ENDPOINT + "?_=" + Date.now());
    });
  }

  if ($("btnKv")){
    $("btnKv").addEventListener("click", function(){
      const cmd = "./avp-cli.sh status --kv";
      copyToClipboard(cmd).then(()=>alert("Command copied:\n" + cmd));
    });
  }


  if ($("btnLogs")){
    $("btnLogs").addEventListener("click", function(){
      const mode = $("logMode") ? $("logMode").value : "feed_summary";

      const FEED_STATE = "/tmp/avp_logs/avp_webui_feed_state.log";
      const FEED_WARN  = "/tmp/avp_logs/avp_webui_warn.log";
      const POL_LAST   = "/tmp/avp_logs/avp-pol-cron.log";

      let cmd = "";

      if (mode === "feed_summary"){
        cmd = "[ -f " + FEED_STATE + " ] && tail -n 200 " + FEED_STATE +
              " | grep -E 'FEED_(OK|ERR|BACKOFF|WARN)|cli_' || echo missing: " + FEED_STATE;
      } else if (mode === "feed_state"){
        cmd = "[ -f " + FEED_STATE + " ] && tail -n 200 " + FEED_STATE +
              " || echo missing: " + FEED_STATE;
      } else if (mode === "feed_warn"){
        cmd = "[ -f " + FEED_WARN + " ] && tail -n 200 " + FEED_WARN +
              " || echo missing: " + FEED_WARN;
      } else if (mode === "pol_last"){
        cmd = "[ -f " + POL_LAST + " ] && tail -n 200 " + POL_LAST +
              " || echo missing: " + POL_LAST;
      } else if (mode === "feed_live"){
        cmd = "echo \"Ctrl+C pra sair\"; [ -f " + FEED_STATE +
              " ] && tail -f " + FEED_STATE + " || echo missing: " + FEED_STATE;
      } else if (mode === "pol_live"){
        cmd = "echo \"Ctrl+C pra sair\"; [ -f " + POL_LAST +
              " ] && tail -f " + POL_LAST + " || echo missing: " + POL_LAST;
      } else {
        cmd = "echo invalid mode";
      }

      copyToClipboard(cmd).then(function(){
        alert("Command copied:\n" + cmd);
      });
    });
  }
  $("btnRefresh").addEventListener("click", load);
  if ($("auto")){
    $("auto").addEventListener("change", function(){
      setAuto(parseInt(this.value, 10) || 0);
    });
  }
  if ($("filter")){
    $("filter").addEventListener("change", load);
  }

  document.addEventListener("visibilitychange", function(){
    if (document.visibilityState === "visible") load();
  });

  // init
  load();
  setAuto(parseInt($("auto").value, 10) || 0);
})();
</script>
</body>
</html>
