// The page at trace.lucabottani.dev: one form, the privacy notice, English
// and Italian (chosen from the browser language, switchable).
const REPO = "https://github.com/DoctorB/forever-one-button";

export function page() {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>Forever One Button: share a log</title>
<style>
:root { --bg:#f6f7f9; --card:#fff; --ink:#1b1f24; --muted:#5b6470; --line:#d8dde3; --accent:#2f6fde; --ok:#1f8a4c; --bad:#c0392b; }
@media (prefers-color-scheme: dark) { :root { --bg:#111418; --card:#1a1f25; --ink:#e7eaee; --muted:#9aa4b0; --line:#2c333b; --accent:#6c9bff; --ok:#4cc38a; --bad:#ff7b6b; } }
* { box-sizing: border-box; }
body { margin:0; background:var(--bg); color:var(--ink); font:16px/1.55 system-ui, -apple-system, "Segoe UI", sans-serif; }
main { max-width:760px; margin:0 auto; padding:32px 16px 48px; }
header { display:flex; justify-content:space-between; align-items:baseline; gap:12px; flex-wrap:wrap; }
h1 { font-size:1.5rem; margin:0 0 4px; }
h2 { font-size:1.05rem; margin:28px 0 8px; }
p, li { color:var(--muted); }
.card { background:var(--card); border:1px solid var(--line); border-radius:10px; padding:20px; margin-top:20px; }
ol { padding-left:20px; margin:0; }
code { background:var(--bg); border:1px solid var(--line); border-radius:4px; padding:1px 5px; font-size:.9em; color:var(--ink); }
textarea { width:100%; min-height:120px; margin-top:12px; padding:10px; border:1px solid var(--line); border-radius:8px; background:var(--bg); color:var(--ink); font:12px/1.4 ui-monospace, Consolas, monospace; resize:vertical; word-break:break-all; }
button { margin-top:12px; padding:10px 18px; border:0; border-radius:8px; background:var(--accent); color:#fff; font-weight:600; font-size:1rem; cursor:pointer; }
button:disabled { opacity:.55; cursor:default; }
.lang { background:none; color:var(--accent); padding:0; margin:0; font-weight:500; font-size:.9rem; }
#status { margin-top:14px; font-weight:600; }
#status.ok { color:var(--ok); } #status.bad { color:var(--bad); }
table { border-collapse:collapse; margin-top:10px; width:100%; font-size:.95rem; }
td { padding:4px 0; border-bottom:1px solid var(--line); } td:last-child { text-align:right; font-variant-numeric:tabular-nums; }
.small { font-size:.85rem; }
a { color:var(--accent); }
</style>
</head>
<body>
<main>
<header>
  <div><h1 data-t="title"></h1><p data-t="lead" style="margin:0"></p></div>
  <button class="lang" id="lang" type="button"></button>
</header>
<div class="card">
  <ol>
    <li data-t="step1"></li>
    <li data-t="step2"></li>
    <li data-t="step3"></li>
  </ol>
  <textarea id="paste" spellcheck="false" autocomplete="off" aria-label="log"></textarea>
  <button id="send" type="button" disabled></button>
  <div id="status" role="status" aria-live="polite"></div>
  <div id="result"></div>
</div>
<div class="card small">
  <h2 data-t="privacyTitle" style="margin-top:0"></h2>
  <div data-t="privacy"></div>
</div>
</main>
<script>
const REPO = ${JSON.stringify(REPO)};
const T = {
  en: {
    title: "Share a Forever One Button log",
    lead: "Logs from real play show where the addon suggests the wrong thing.",
    step1: "In game: <code>/fob log on</code>, then play as usual (the log is off by default).",
    step2: "Type <code>/fob share</code>, click the line in the window, press Ctrl+A and Ctrl+C.",
    step3: "Paste it here and press Send. Back in game, click <b>I sent it</b>.",
    send: "Send", sending: "Sending…", other: "Italiano",
    placeholder: "!FOB:1:z!…!END:FOB!",
    okTitle: "Received, thank you.", okRef: "Reference",
    rows: { entries: "Entries", minutes: "Minutes of play", combats: "Fights", casts: "Casts", errors: "Presses refused by the game" },
    top: "Most frequent refusals",
    network: "The site could not be reached. Check the connection and try again.",
    privacyTitle: "Privacy",
    privacy: "<p>What is stored: the log you paste, as it is. It holds spell and item IDs and names, game messages (such as \\"Out of range\\") and timings, plus the addon version, client build, class, level and language. The addon removes your character and realm names before the log is shown to you; nothing is sent unless you paste it here.</p><p>What is not stored: your IP address, cookies, or anything else about your browser. The address is used only by Cloudflare, for a few seconds, to limit how many logs one connection can send.</p><p>Why: to find and fix wrong suggestions in Forever One Button. Logs are read only by the addon's author, never sold or published, and deleted after 180 days.</p><p>To ask for a log to be deleted, open an issue at <a href=\\"" + REPO + "/issues\\">GitHub</a> with the reference shown after sending.</p>",
  },
  it: {
    title: "Condividi un log di Forever One Button",
    lead: "I log di gioco reale mostrano dove l'addon suggerisce la cosa sbagliata.",
    step1: "In gioco: <code>/fob log on</code>, poi gioca come al solito (il log è spento di default).",
    step2: "Scrivi <code>/fob share</code>, clicca la riga nella finestra, premi Ctrl+A e Ctrl+C.",
    step3: "Incollala qui e premi Invia. Tornato in gioco, clicca <b>I sent it</b>.",
    send: "Invia", sending: "Invio…", other: "English",
    placeholder: "!FOB:1:z!…!END:FOB!",
    okTitle: "Ricevuto, grazie.", okRef: "Riferimento",
    rows: { entries: "Righe", minutes: "Minuti di gioco", combats: "Combattimenti", casts: "Lanci", errors: "Pressioni rifiutate dal gioco" },
    top: "Rifiuti più frequenti",
    network: "Il sito non risponde. Controlla la connessione e riprova.",
    privacyTitle: "Privacy",
    privacy: "<p>Cosa viene salvato: il log che incolli, così com'è. Contiene ID e nomi di incantesimi e oggetti, messaggi del gioco (come \\"Out of range\\") e tempi, più versione dell'addon, build del client, classe, livello e lingua. L'addon toglie i nomi del personaggio e del reame prima di mostrarti il log; non parte niente finché non lo incolli qui.</p><p>Cosa non viene salvato: il tuo indirizzo IP, cookie o altro sul tuo browser. L'indirizzo è usato solo da Cloudflare, per pochi secondi, per limitare quanti log può inviare una connessione.</p><p>Perché: per trovare e correggere i suggerimenti sbagliati di Forever One Button. I log sono letti solo dall'autore dell'addon, mai venduti né pubblicati, e cancellati dopo 180 giorni.</p><p>Per chiedere la cancellazione di un log apri una issue su <a href=\\"" + REPO + "/issues\\">GitHub</a> con il riferimento mostrato dopo l'invio.</p>",
  },
};
let lang = (navigator.language || "en").toLowerCase().startsWith("it") ? "it" : "en";
const $ = (id) => document.getElementById(id);
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
let last = null;
function render() {
  const t = T[lang];
  document.documentElement.lang = lang;
  document.querySelectorAll("[data-t]").forEach((el) => { el.innerHTML = t[el.dataset.t]; });
  $("send").textContent = t.send;
  $("lang").textContent = t.other;
  $("paste").placeholder = t.placeholder;
  if (last) show(last);
}
function show(data) {
  const t = T[lang];
  last = data;
  if (!data.ok) {
    $("status").className = "bad";
    $("status").textContent = data.message || t.network;
    $("result").innerHTML = "";
    return;
  }
  $("status").className = "ok";
  $("status").textContent = t.okTitle;
  const s = data.summary;
  let rows = "";
  for (const k of ["entries", "minutes", "combats", "casts", "errors"]) rows += "<tr><td>" + t.rows[k] + "</td><td>" + esc(s[k]) + "</td></tr>";
  let top = "";
  if (s.topErrors && s.topErrors.length) {
    top = "<h2>" + t.top + "</h2><table>" + s.topErrors.map((e) => "<tr><td>" + esc(e.message) + "</td><td>" + esc(e.count) + "</td></tr>").join("") + "</table>";
  }
  const h = data.header || {};
  const who = [h.class, h.level && ("lv " + h.level), h.addon && ("FOB " + h.addon), h.build].filter(Boolean).map(esc).join(" · ");
  $("result").innerHTML = "<p class=small>" + who + "<br>" + t.okRef + ": <code>" + esc(data.id) + "</code></p><table>" + rows + "</table>" + top;
}
$("lang").addEventListener("click", () => { lang = lang === "it" ? "en" : "it"; render(); });
$("paste").addEventListener("input", () => { $("send").disabled = $("paste").value.trim().length === 0; });
$("send").addEventListener("click", async () => {
  const t = T[lang];
  $("send").disabled = true;
  $("send").textContent = t.sending;
  $("status").className = "";
  $("status").textContent = "";
  try {
    const response = await fetch("/api/share", { method: "POST", headers: { "Content-Type": "text/plain;charset=utf-8" }, body: $("paste").value });
    show(await response.json());
    if (last && last.ok) $("paste").value = "";
  } catch {
    show({ ok: false, message: t.network });
  }
  $("send").textContent = t.send;
  $("send").disabled = $("paste").value.trim().length === 0;
});
render();
</script>
</body>
</html>`;
}
