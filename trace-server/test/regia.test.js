import { test } from "node:test";
import assert from "node:assert/strict";
import worker from "../src/index.js";
import { parseReport, reportKey, reportMeta, ReportError } from "../src/regia.js";

const good = {
  v: 1, install: "1b4e28ba-2fa1-41d2-883f-0016d3cca427", regia: "0.10.0", os: "win32 10.0.26300", node: "v22.12.0", lang: "it",
  source: "fase", key: "events.phaseFailed", kind: "collaudo", message: "Collaudo: errore — adb non risponde", detail: "riga 1\nriga 2", at: "2026-11-13T14:00:00.000Z",
};

test("parseReport keeps the known fields, cut to their limits", () => {
  const r = parseReport(JSON.stringify({ ...good, message: "x".repeat(5000), extra: "ignored" }));
  assert.equal(r.message.length, 2000);
  assert.equal(r.extra, undefined);
  assert.equal(r.kind, "collaudo");
  assert.deepEqual(Object.keys(reportMeta(r)).sort(), ["install", "key", "kind", "message", "os", "regia", "source"]);
  assert.ok(JSON.stringify(reportMeta(parseReport(JSON.stringify({ ...good, message: "y".repeat(2000), os: "z".repeat(60) })))).length < 1024);
});

test("parseReport rejects what is not a Regia report", () => {
  for (const bad of ["not json", "[]", JSON.stringify({ ...good, v: 2 }), JSON.stringify({ ...good, install: "me" }),
    JSON.stringify({ ...good, source: "web" }), JSON.stringify({ ...good, message: "" }), JSON.stringify({ ...good, at: "ieri" }),
    JSON.stringify({ ...good, message: 42 })]) {
    assert.throws(() => parseReport(bad), ReportError, bad);
  }
});

test("reportKey sorts by time under the regia/ prefix", () => {
  assert.equal(reportKey(new Date("2026-11-13T14:05:09Z"), "abc"), "regia/2026-11-13/140509-abc.json");
});

test("POST /api/regia/report stores the report with its metadata and the 180-day expiry", async () => {
  const puts = [];
  const env = { SHARES: { put: async (k, v, o) => puts.push({ k, v, o }) } };
  const ok = await worker.fetch(new Request("https://trace.lucabottani.dev/api/regia/report", { method: "POST", body: JSON.stringify(good) }), env);
  assert.equal(ok.status, 200);
  assert.equal(puts.length, 1);
  assert.match(puts[0].k, /^regia\/\d{4}-\d{2}-\d{2}\/\d{6}-[0-9a-f-]+\.json$/);
  assert.equal(JSON.parse(puts[0].v).key, "events.phaseFailed");
  assert.equal(puts[0].o.expirationTtl, 180 * 24 * 3600);
  assert.equal(puts[0].o.metadata.source, "fase");
  const bad = await worker.fetch(new Request("https://trace.lucabottani.dev/api/regia/report", { method: "POST", body: "{}" }), env);
  assert.equal(bad.status, 400);
  const get = await worker.fetch(new Request("https://trace.lucabottani.dev/api/regia/report"), env);
  assert.equal(get.status, 405);
  const big = await worker.fetch(new Request("https://trace.lucabottani.dev/api/regia/report", { method: "POST", body: "x".repeat(20000) }), env);
  assert.equal(big.status, 413);
  assert.equal(puts.length, 1);
});
