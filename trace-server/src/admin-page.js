// The owner's page at /admin: the list of the stored logs (Forever One Button
// shares) and of the Regia error reports, the ones not marked as seen yet
// highlighted. The page itself holds nothing: the admin token is given once in
// the address fragment (/admin#<token>), which the browser never sends to the
// server, is kept in this browser's localStorage and removed from the address
// bar. The list is then read from /admin/list with the token in the
// Authorization header; a Regia report opens with a click (/admin/get).
export function adminPage() {
  return `<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<title>Log e segnalazioni</title>
<style>
:root { --bg:#f6f7f9; --card:#fff; --ink:#1b1f24; --muted:#5b6470; --line:#d8dde3; --accent:#2f6fde; --new:#fff4d6; }
@media (prefers-color-scheme: dark) { :root { --bg:#111418; --card:#1a1f25; --ink:#e7eaee; --muted:#9aa4b0; --line:#2c333b; --accent:#6c9bff; --new:#3a3115; } }
* { box-sizing: border-box; }
body { margin:0; background:var(--bg); color:var(--ink); font:16px/1.5 system-ui, -apple-system, "Segoe UI", sans-serif; }
main { max-width:1000px; margin:0 auto; padding:32px 16px 48px; }
h1 { font-size:1.5rem; margin:0 0 4px; }
#summary { font-size:1.15rem; font-weight:600; margin:16px 0; }
p { color:var(--muted); }
.tabs { display:flex; gap:8px; margin:12px 0 0; }
.tabs button { background:var(--card); color:var(--ink); border:1px solid var(--line); }
.tabs button.on { background:var(--accent); color:#fff; border-color:var(--accent); }
.card { background:var(--card); border:1px solid var(--line); border-radius:10px; padding:4px 0; overflow-x:auto; }
table { width:100%; border-collapse:collapse; font-size:.95rem; }
th, td { text-align:left; padding:8px 14px; border-bottom:1px solid var(--line); white-space:nowrap; }
td.msg { white-space:normal; min-width:280px; }
th { color:var(--muted); font-weight:500; }
tr:last-child td { border-bottom:0; }
tr.new td { background:var(--new); }
tr.open { cursor:pointer; }
tr.open:hover td { text-decoration:underline; }
button { padding:8px 16px; border:0; border-radius:8px; background:var(--accent); color:#fff; font-weight:600; font-size:.95rem; cursor:pointer; margin-right:8px; }
button.plain { background:none; color:var(--accent); padding:8px 0; }
pre { background:var(--card); border:1px solid var(--line); border-radius:10px; padding:14px; white-space:pre-wrap; word-break:break-word; font-size:.85rem; }
</style>
</head>
<body>
<main>
<h1>Log e segnalazioni</h1>
<div class="tabs"><button data-mode="fob">Forever One Button</button><button data-mode="regia">Regia</button></div>
<div id="summary">Caricamento…</div>
<div id="actions" hidden><button id="seen">Segna tutti come visti</button><button id="forget" class="plain">Dimentica il token su questo browser</button></div>
<div class="card" id="card" hidden><table><thead id="head"></thead><tbody id="rows"></tbody></table></div>
<pre id="detail" hidden></pre>
</main>
<script>
(() => {
  const store = {
    get(k) { try { return localStorage.getItem(k); } catch { return null; } },
    set(k, v) { try { localStorage.setItem(k, v); } catch {} },
    del(k) { try { localStorage.removeItem(k); } catch {} },
  };
  const summary = document.getElementById("summary");
  if (location.hash.length > 1) {
    store.set("fob-admin-token", decodeURIComponent(location.hash.slice(1)));
    history.replaceState(null, "", location.pathname);
  }
  const token = store.get("fob-admin-token");
  if (!token) { summary.textContent = "Apri questa pagina una volta come /admin#<ADMIN_TOKEN>: il token resta su questo browser."; return; }

  const MODES = {
    fob: { prefix: "fob/", title: "FOB log condivisi", none: "Nessun log nuovo", one: " log nuovo", many: " log nuovi",
      cols: ["Ricevuto (UTC)", "Classe", "Livello", "FOB", "Build", "Righe"],
      row: (m) => [m.class, m.level, m.addon, m.build, m.entries] },
    regia: { prefix: "regia/", title: "Segnalazioni di Regia", none: "Nessuna segnalazione nuova", one: " segnalazione nuova", many: " segnalazioni nuove",
      cols: ["Ricevuto (UTC)", "Regia", "Sistema", "Fonte", "Fase", "Installazione", "Messaggio"],
      row: (m) => [m.regia, m.os, m.source, m.kind, m.install, m.message], open: true },
  };
  let mode = store.get("fob-admin-mode") === "regia" ? "regia" : "fob";
  const when = (key) => { const m = /^[a-z]+\\/(\\d{4}-\\d{2}-\\d{2})\\/(\\d{2})(\\d{2})(\\d{2})-/.exec(key); return m ? m[1] + " " + m[2] + ":" + m[3] : key; };
  const cell = (row, text, cls) => { const td = document.createElement("td"); td.textContent = text ?? "?"; if (cls) td.className = cls; row.appendChild(td); };
  const detail = document.getElementById("detail");

  async function show(key) {
    const r = await fetch("/admin/get?key=" + encodeURIComponent(key), { headers: { Authorization: "Bearer " + token }, cache: "no-store" });
    if (!r.ok) return;
    const t = await r.text();
    try { detail.textContent = JSON.stringify(JSON.parse(t), null, 2); } catch { detail.textContent = t; }
    detail.hidden = false;
    detail.scrollIntoView({ behavior: "smooth" });
  }

  async function load() {
    const M = MODES[mode];
    for (const b of document.querySelectorAll(".tabs button")) b.className = b.dataset.mode === mode ? "on" : "";
    detail.hidden = true;
    let objects = [], cursor = null;
    do {
      const r = await fetch("/admin/list?prefix=" + M.prefix + (cursor ? "&cursor=" + encodeURIComponent(cursor) : ""), { headers: { Authorization: "Bearer " + token }, cache: "no-store" });
      if (!r.ok) { summary.textContent = "Token non valido: riapri la pagina come /admin#<ADMIN_TOKEN>."; store.del("fob-admin-token"); return; }
      const page = await r.json();
      objects = objects.concat(page.objects);
      cursor = page.cursor;
    } while (cursor);
    objects.sort((a, b) => (a.key < b.key ? 1 : -1));
    const seenKey = mode === "fob" ? "fob-admin-seen" : "regia-admin-seen";
    const seen = store.get(seenKey) ?? "";
    const fresh = objects.filter((o) => o.key > seen).length;
    summary.textContent = fresh === 0 ? M.none + " (" + objects.length + " in totale)."
      : fresh + (fresh === 1 ? M.one : M.many) + " su " + objects.length + ".";
    document.title = (fresh ? "(" + fresh + ") " : "") + M.title;
    const head = document.getElementById("head");
    head.replaceChildren();
    const htr = document.createElement("tr");
    for (const c of M.cols) { const th = document.createElement("th"); th.textContent = c; htr.appendChild(th); }
    head.appendChild(htr);
    const rows = document.getElementById("rows");
    rows.replaceChildren();
    for (const o of objects) {
      const m = o.meta || {}, tr = document.createElement("tr");
      tr.className = (o.key > seen ? "new " : "") + (M.open ? "open" : "");
      cell(tr, when(o.key));
      const vals = M.row(m);
      vals.forEach((v, i) => cell(tr, v, M.open && i === vals.length - 1 ? "msg" : ""));
      if (M.open) tr.onclick = () => show(o.key);
      rows.appendChild(tr);
    }
    document.getElementById("card").hidden = objects.length === 0;
    document.getElementById("actions").hidden = false;
    document.getElementById("seen").onclick = () => { if (objects.length) store.set(seenKey, objects[0].key); load(); };
  }
  for (const b of document.querySelectorAll(".tabs button")) b.onclick = () => { mode = b.dataset.mode; store.set("fob-admin-mode", mode); load().catch(() => {}); };
  document.getElementById("forget").onclick = () => { store.del("fob-admin-token"); location.reload(); };
  load().catch(() => { summary.textContent = "Il sito non ha risposto: riprova più tardi."; });
})();
</script>
</body>
</html>`;
}
