<!DOCTYPE html>
<!--
=============================================================
AutoVPN Platform (AVP)
Component : AVP-WEBUI (ASP)
File      : avp.asp
Role      : WebUI frontend (router user page)
Version   : v1.0.18 (2026-02-10)
Status    : stable
=============================================================

CHANGELOG
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
  * FIX: toolbar Order/Auto-refresh (rebuild HTML; restore options/labels) + keep default devices.conf order
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

/* C2: Toast */
#toast {
  position: fixed;
  right: 16px;
  bottom: 16px;
  z-index: 9999;
  display: none;
  max-width: 520px;
  border: 1px solid #444;
  border-radius: 10px;
  padding: 10px 12px;
  background: #111;
  color: #fff;
  box-shadow: 0 6px 18px rgba(0,0,0,.25);
  font-size: 13px;
  line-height: 1.35;
  white-space: pre-wrap;
  word-break: break-word;
}
#toast.ok{ border-color:#1b7f1b; }
#toast.warn{ border-color:#c77700; }
#toast.bad{ border-color:#b00020; }

/* C2: Console */
.consoleGrid { display:flex; gap:12px; flex-wrap:wrap; align-items:flex-start; }
.consoleGrid .card { min-width: 360px; }
.consoleRow { display:flex; gap:10px; flex-wrap:wrap; align-items:center; }
.consoleRow label { display:flex; gap:6px; align-items:center; }
.consoleRow input[type="text"], .consoleRow select { padding:4px 6px; border:1px solid #aaa; border-radius:6px; }
.mini { font-size:12px; opacity:.85; }
  </style>
</head>
<body>
  <h2>AVP — AutoVPN Platform <span class="pill" id="ver">WebUI v1.0.17</span></h2>

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
          Order
          <select id="order">
            <option value="conf">devices.conf</option>
            <option value="label">label</option>
            <option value="pref">pref</option>
          </select>
        </label>

        <label class="muted">
          Auto-refresh
          <select id="auto">
            <option value="0">off</option>
            <option value="5">5s</option>
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

<!-- C2: Console + Last Action -->
<div class="consoleGrid" style="margin-top:12px;">
  <div class="card">
    <div><b>Console</b> <span class="muted">(apply.cgi)</span></div>

    <div class="consoleRow" style="margin-top:10px;">
      <button class="btn" id="btnSnap">snapshot</button>
      <button class="btn" id="btnReload">reload</button>
      <button class="btn" id="btnToggle">toggle</button>
    </div>

    <div class="consoleRow" style="margin-top:10px;">
      <label class="muted">DHCP refresh
        <select id="dhcpMode">
          <option value="dhcp_refresh">normal</option>
          <option value="dhcp_refresh_aggr">aggressive</option>
        </select>
      </label>
      <button class="btn" id="btnDhcp">run</button>
    </div>

    <div class="consoleRow" style="margin-top:10px;">
      <label class="muted">Profile</label>
      <select id="profileSel">
        <option value="" selected>(not loaded)</option>
      </select>
      <button class="btn" id="btnProfileList">list</button>
      <button class="btn" id="btnProfileGet">get</button>
      <button class="btn" id="btnProfileSet">set</button>
    </div>

    <div class="consoleRow" style="margin-top:10px;">
      <label class="muted">Device key</label>
      <input type="text" id="devKey" placeholder="label/ip/mac (key)" size="22">
      <label class="muted">payload</label>
      <input type="text" id="devPayload" placeholder="optional payload" size="22">
      <button class="btn" id="btnDevList">list</button>
      <button class="btn" id="btnDevAdd">add</button>
      <button class="btn" id="btnDevRemove">remove</button>
      <button class="btn" id="btnDevUpdate">update</button>
    </div>

    <div class="consoleRow" style="margin-top:10px;">
      <label class="muted">Token</label>
      <input type="text" id="token" placeholder="(auto)" size="34">
      <button class="btn" id="btnTokenGet">get</button>
      <button class="btn" id="btnTokenClear">clear</button>
    </div>

    <div class="mini muted" style="margin-top:10px;">
      Last action endpoint: <code>/user/avp-action-last.json</code>
    </div>
  </div>

  <div class="card" style="flex:1; min-width:420px;">
    <div style="display:flex; justify-content:space-between; align-items:center;">
      <div><b>Last action</b></div>
      <span class="pill" id="actState" style="font-size:12px;">idle</span>
    </div>
    <pre id="lastAction" style="margin-top:10px;">(no data)</pre>
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

  const WEBUI_VER = "v1.0.18";
  if ($("ver")) $("ver").textContent = "WebUI " + WEBUI_VER;


  // Endpoint fixo do feed
  const ENDPOINT = "/user/avp-status.json";

  // guarda o JSON bruto pra "Copy JSON"
  let lastRawJson = "";

// C2: Action plumbing (apply.cgi + last action json)

  const TOKEN_KEY = "avp_webui_token";

  function getToken(){
    try{
      const el = document.getElementById("token");
      const v1 = el && el.value ? String(el.value).trim() : "";
      if (v1) return v1;
      const v2 = localStorage.getItem(TOKEN_KEY) || "";
      return String(v2).trim();
    }catch(e){ return ""; }
  }

  function setToken(t){
    try{
      const v = (t ? String(t) : "").trim();
      const el = document.getElementById("token");
      if (el) el.value = v;
      if (v){
        localStorage.setItem(TOKEN_KEY, v);
        // compat: se existir código antigo lendo avp_token, mantém também
        localStorage.setItem("avp_token", v);
      }
    }catch(e){}
  }

  async function syncTokenFromLast(){
    try{
      const u = "/user/avp-action-last.json?_ts=" + Date.now();
      const r = await fetch(u, { cache: "no-store" });
      if (!r || !r.ok) return;
      const j = await r.json();
      if (j && j.ok && j.action === "token_get" && j.data && j.data.token){
        setToken(j.data.token);
      }
    }catch(e){}
  }


const LAST_ACTION = "/user/avp-action-last.json";
let lastStatusEnabled = null;
let lastActionTs = null;
var t = "";


function toast(msg, level){
  const el = $("toast");
  if (!el) return;
  el.classList.remove("ok","warn","bad");
  level = level || "ok";
  el.classList.add(level);
  el.textContent = String(msg || "");
  el.style.display = "";
  setTimeout(function(){ try{ el.style.display="none"; }catch(_){} }, 2600);
}

function syncTokenUi(){

  if ($("token")) $("token").value = (typeof t === "string" ? t : String(t||""));
}

async function loadLastAction(forceToast){
  try{
    const u = LAST_ACTION + "?_=" + Date.now();
    const r = await fetch(u, { cache: "no-store" });
    const txt = await r.text();

    if ((txt || "").trim().startsWith("<")) throw new Error("Not authenticated (login required)");
    const j = JSON.parse(txt);

    if ($("lastAction")) $("lastAction").textContent = JSON.stringify(j, null, 2);

    // state pill + optional toast
    const ok = (j && j.ok === true);
    const rc = (j && typeof j.rc === "number") ? j.rc : null;
    const ts = (j && typeof j.ts === "number") ? j.ts : null;

    if (ts !== null) lastActionTs = ts;

    const st = ok ? "ok" : "fail";
    if ($("actState")) $("actState").textContent = st;

    if (forceToast){
      if (ok) toast("OK: " + (j.action || "action"), "ok");
      else toast("FAIL: " + (j.msg || "error") + (rc !== null ? (" (rc=" + rc + ")") : ""), "bad");
    }

    // Profiles: update select when response carries list
    if (j && j.data && Array.isArray(j.data.profiles) && $("profileSel")){
      const sel = $("profileSel");
      sel.innerHTML = "";
      for (const p of j.data.profiles){
        const opt = document.createElement("option");
        opt.value = String(p);
        opt.textContent = String(p);
        sel.appendChild(opt);
      }
    }

    // Token: store when response carries token
    if (j && j.data && j.data.token){
      localStorage.setItem("avp_token", String(j.data.token));
        setToken(data.token);

      syncTokenUi();
    }

    return j;
  }catch(e){
    if ($("lastAction")) $("lastAction").textContent = "(no data)";
    if ($("actState")) $("actState").textContent = "idle";
    return null;
  }
}

function postApply(params){
  const fd = new URLSearchParams();
  fd.set("current_page", "user/avp.asp");
  fd.set("next_page", "user/avp.asp");
  fd.set("action_mode", "apply");
  fd.set("action_script", "");
  fd.set("rc_service", "avp_webui_restart");

  for (const k in (params||{})){
    if (!Object.prototype.hasOwnProperty.call(params,k)) continue;
    fd.set(k, String(params[k]));
  }

  return fetch("/apply.cgi", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: fd.toString()
  });
}

async function doAction(action, extra){
  extra = extra || {};
  extra.avp_webui_action = action;

  const t = getToken();
  const needsToken = (action !== "token_get");
  if (needsToken){
    if (!t){
      toast("Token required (use Token get first)", "bad");
      return Promise.resolve({ ok:false, rc:22, action:"auth", msg:"missing token", data:{hint:"token required"}, ts:Math.floor(Date.now()/1000) });
    }
    extra.avp_webui_token = t;
  }


  try{
    if ($("actState")) $("actState").textContent = "busy";
    await postApply(extra);
      try{ syncTokenFromLast(); }catch(e){};

    // backend is async: poll last.json until ts changes (or timeout)
    let tries = 0;
    const max = 10;
    const prevTs = lastActionTs;

    const poll = setInterval(async function(){
      tries++;
      const j = await loadLastAction(false);
      const curTs = j && typeof j.ts === "number" ? j.ts : null;

      if (curTs !== null && prevTs !== null && curTs !== prevTs){
        clearInterval(poll);
        if ($("actState")) $("actState").textContent = "idle";
        await loadLastAction(true);
        return;
      }

      // first successful read after action => toast once
      if (prevTs === null && curTs !== null){
        clearInterval(poll);
        if ($("actState")) $("actState").textContent = "idle";
        await loadLastAction(true);
        return;
      }

      if (tries >= max){
        clearInterval(poll);
        if ($("actState")) $("actState").textContent = "idle";
        await loadLastAction(true);
      }
    }, 450);

  }catch(e){
    toast("apply.cgi failed: " + (e && e.message ? e.message : String(e)), "bad");
    if ($("actState")) $("actState").textContent = "idle";
  }
}


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
        {
        const lastEl = $("last");
        if (lastEl && lastTxt) lastEl.textContent = lastTxt;
        const ageEl = $("age");
        if (ageEl){
          ageEl.textContent = fmtAgeSec(ageSec) + " ago";
          // thresholds: <20s ok, 20-59s warn, >=60s bad
          const cls = (ageSec >= 60) ? "bad" : (ageSec >= 20 ? "warn" : "ok");
          // classList-safe: não apaga outras classes do elemento
          ageEl.classList.remove("ok","warn","bad");
          ageEl.classList.add(cls);
        }
      }
      }
      if ($("enabled")) $("enabled").innerHTML = (j.enabled === 1) ? '<span class="ok">enabled</span>' : '<span class="bad">disabled</span>';
      lastStatusEnabled = (j.enabled === 1);
      if ($("profile")) $("profile").textContent = j.profile || "n/a";
      if (!fe && $("last")) if ($("last")) $("last").textContent = new Date().toLocaleString();

      if (j.errors && j.errors.length){
        if ($("errorsBox")) if ($("errorsBox")) $("errorsBox").style.display = "";
        if ($("errors")) $("errors").textContent = JSON.stringify(j.errors, null, 2);
      } else {
        if ($("errorsBox")) $("errorsBox").style.display = "none";
      }

      const tb = $("tbody");
      if (!tb) return;
      tb.innerHTML = "";

      let devs = (j.devices || []);

      // filtro
      const f = $("filter") ? String($("filter").value || "all") : "all";
      if (f === "vpn") devs = devs.filter(d => String(d.state||"").toLowerCase() === "vpn");
      if (f === "wan") devs = devs.filter(d => String(d.state||"").toLowerCase() === "wan");

      // order (default: devices.conf order)
      const ord = $("order") ? String($("order").value || "conf") : (localStorage.getItem("avp_order") || "conf");
      if (ord === "label"){
        devs.sort((a,b)=> String(a.label||"").localeCompare(String(b.label||"")));
      } else if (ord === "pref"){
        devs.sort((a,b)=> (parseInt(a.pref,10)||999999) - (parseInt(b.pref,10)||999999) || String(a.label||"").localeCompare(String(b.label||"")));
      }

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
      if ($("enabled")) $("enabled").innerHTML = '<span class="bad">error</span>';
      if ($("profile")) $("profile").textContent = "n/a";
      if ($("last")) $("last").textContent = new Date().toLocaleString();
      if ($("age")) $("age").textContent = "n/a";

      if ($("errorsBox")) if ($("errorsBox")) $("errorsBox").style.display = "";
      if ($("errors")) $("errors").textContent = "Fetch/parse error: " + (e && e.message ? e.message : String(e));

      const tb = $("tbody");
      if (!tb) return;
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
      const cmd = "/jffs/scripts/avp/bin/avp-cli.sh status --kv";
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
    const k = "avp_auto";
    let v = localStorage.getItem(k);
    if (v === null || v === ""){ v = "5"; localStorage.setItem(k, v); }
    $("auto").value = v;
    $("auto").addEventListener("change", function(){
      localStorage.setItem(k, this.value || "0");
      setAuto(parseInt(this.value, 10) || 0);
    });
  }
  if ($("filter")){
    $("filter").addEventListener("change", load);
  }
  if ($("order")){
    const k = "avp_order";
    const v = localStorage.getItem(k) || "conf";
    $("order").value = v;
    $("order").addEventListener("change", function(){
      localStorage.setItem(k, this.value || "conf");
      load();
    });
  }

  document.addEventListener("visibilitychange", function(){
    if (document.visibilityState === "visible") load();
  });


// C2: Console handlers
if ($("btnSnap"))   $("btnSnap").addEventListener("click", function(){ doAction("snapshot"); });
if ($("btnReload")) $("btnReload").addEventListener("click", function(){ doAction("reload"); });

if ($("btnToggle")) $("btnToggle").addEventListener("click", function(){
  const act = (lastStatusEnabled === true) ? "disable" : "enable";
  doAction(act);
});

if ($("btnDhcp")) $("btnDhcp").addEventListener("click", function(){
  const m = $("dhcpMode") ? $("dhcpMode").value : "dhcp_refresh";
  doAction(m);
});

if ($("btnProfileList")) $("btnProfileList").addEventListener("click", function(){ doAction("profile_list"); });

if ($("btnProfileGet")) $("btnProfileGet").addEventListener("click", function(){
  const p = $("profileSel") ? $("profileSel").value : "";
  doAction("profile_get", { avp_webui_profile: p });
});

if ($("btnProfileSet")) $("btnProfileSet").addEventListener("click", function(){
  const p = $("profileSel") ? $("profileSel").value : "";
  doAction("profile_set", { avp_webui_profile: p });
});

if ($("btnDevList")) $("btnDevList").addEventListener("click", function(){ doAction("device_list"); });

if ($("btnDevAdd")) $("btnDevAdd").addEventListener("click", function(){
  const k = $("devKey") ? $("devKey").value : "";
  const p = $("devPayload") ? $("devPayload").value : "";
  doAction("device_add", { avp_webui_device: k, avp_webui_payload: p });
});

if ($("btnDevRemove")) $("btnDevRemove").addEventListener("click", function(){
  const k = $("devKey") ? $("devKey").value : "";
  doAction("device_remove", { avp_webui_device: k });
});

if ($("btnDevUpdate")) $("btnDevUpdate").addEventListener("click", function(){
  const k = $("devKey") ? $("devKey").value : "";
  const p = $("devPayload") ? $("devPayload").value : "";
  doAction("device_update", { avp_webui_device: k, avp_webui_payload: p });
});

if ($("btnTokenGet")) $("btnTokenGet").addEventListener("click", function(){ doAction("token_get"); });

if ($("btnTokenClear")) $("btnTokenClear").addEventListener("click", function(){
  localStorage.removeItem("avp_token");
  syncTokenUi();
  toast("Token cleared", "warn");
});

// C2: keep last action fresh (light)
syncTokenUi();
loadLastAction(false);
setInterval(function(){ if (document.visibilityState === "visible") loadLastAction(false); }, 2500);

  // init
  load();
  setAuto(parseInt(($("auto") ? $("auto").value : "0"), 10) || 0);
})();
</script>
  <div id="toast"></div>
</body>
</html>
