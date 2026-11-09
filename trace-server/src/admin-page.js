// The owner's page at /admin: the list of the stored logs, the ones not
// marked as seen yet highlighted. The page itself holds nothing: the admin
// token is given once in the address fragment (/admin#<token>), which the
// browser never sends to the server, is kept in this browser's
// localStorage and removed from the address bar. The list is then read
// from /admin/list with the token in the Authorization header.
export function adminPage() {
  return `<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<title>FOB log condivisi</title>
<style>
:root { --bg:#f6f7f9; --card:#fff; --ink:#1b1f24; --muted:#5b6470; --line:#d8dde3; --accent:#2f6fde; --new:#fff4d6; }
@media (prefers-color-scheme: dark) { :root { --bg:#111418; --card:#1a1f25; --ink:#e7eaee; --muted:#9aa4b0; --line:#2c333b; --accent:#6c9bff; --new:#3a3115; } }
* { box-sizing: border-box; }
body { margin:0; background:var(--bg); color:var(--ink); font:16px/1.5 system-ui, -apple-system, "Segoe UI", sans-serif; }
main { max-width:860px; margin:0 auto; padding:32px 16px 48px; }
h1 { font-size:1.5rem; margin:0 0 4px; }
#summary { font-size:1.15rem; font-weight:600; margin:16px 0; }
p { color:var(--muted); }
.card { background:var(--card); border:1px solid var(--line); border-radius:10px; padding:4px 0; overflow-x:auto; }
table { width:100%; border-collapse:collapse; font-size:.95rem; }
th, td { text-align:left; padding:8px 14px; border-bottom:1px solid var(--line); white-space:nowrap; }
th { color:var(--muted); font-weight:500; }
tr:last-child td { border-bottom:0; }
tr.new td { background:var(--new); }
button { padding:8px 16px; border:0; border-radius:8px; background:var(--accent); color:#fff; font-weight:600; font-size:.95rem; cursor:pointer; margin-right:8px; }
button.plain { background:none; color:var(--accent); padding:8px 0; }
</style>
</head>
<body>
<main>
<h1>Forever One Button: log condivisi</h1>
<div id="summary">Caricamento…</div>
<div id="actions" hidden><button id="seen">Segna tutti come visti</button><button id="forget" class="plain">Dimentica il token su questo browser</button></div>
<div class="card" id="card" hidden><table><thead><tr><th>Ricevuto (UTC)</th><th>Classe</th><th>Livello</th><th>FOB</th><th>Build</th><th>Righe</th></tr></thead><tbody id="rows"></tbody></table></div>
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

  const when = (key) => { const m = /^fob\\/(\\d{4}-\\d{2}-\\d{2})\\/(\\d{2})(\\d{2})(\\d{2})-/.exec(key); return m ? m[1] + " " + m[2] + ":" + m[3] : key; };
  const cell = (row, text) => { const td = document.createElement("td"); td.textContent = text ?? "?"; row.appendChild(td); };

  async function load() {
    let objects = [], cursor = null;
    do {
      const r = await fetch("/admin/list?prefix=fob/" + (cursor ? "&cursor=" + encodeURIComponent(cursor) : ""), { headers: { Authorization: "Bearer " + token }, cache: "no-store" });
      if (!r.ok) { summary.textContent = "Token non valido: riapri la pagina come /admin#<ADMIN_TOKEN>."; store.del("fob-admin-token"); return; }
      const page = await r.json();
      objects = objects.concat(page.objects);
      cursor = page.cursor;
    } while (cursor);
    objects.sort((a, b) => (a.key < b.key ? 1 : -1));
    const seen = store.get("fob-admin-seen") ?? "";
    const fresh = objects.filter((o) => o.key > seen).length;
    summary.textContent = fresh === 0 ? "Nessun log nuovo (" + objects.length + " in totale)."
      : fresh + (fresh === 1 ? " log nuovo" : " log nuovi") + " su " + objects.length + ".";
    document.title = (fresh ? "(" + fresh + ") " : "") + "FOB log condivisi";
    const rows = document.getElementById("rows");
    rows.replaceChildren();
    for (const o of objects) {
      const m = o.meta || {}, tr = document.createElement("tr");
      if (o.key > seen) tr.className = "new";
      cell(tr, when(o.key)); cell(tr, m.class); cell(tr, m.level); cell(tr, m.addon); cell(tr, m.build); cell(tr, m.entries);
      rows.appendChild(tr);
    }
    document.getElementById("card").hidden = objects.length === 0;
    document.getElementById("actions").hidden = false;
    document.getElementById("seen").onclick = () => { if (objects.length) store.set("fob-admin-seen", objects[0].key); load(); };
  }
  document.getElementById("forget").onclick = () => { store.del("fob-admin-token"); location.reload(); };
  load().catch(() => { summary.textContent = "Il sito non ha risposto: riprova più tardi."; });
})();
</script>
</body>
</html>`;
}
