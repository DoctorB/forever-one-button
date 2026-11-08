import { test } from "node:test";
import assert from "node:assert/strict";
import { deflateRawSync } from "node:zlib";
import { decodeShare, parseText, summarize, storageKey, ShareError } from "../src/share.js";
import worker from "../src/index.js";

const TEXT = [
  "fob-share 1", "addon=1.1.6", "build=1.60.1.70862", "class=ROGUE", "level=10", "locale=enUS",
  "exported=2026-11-08T10:00:00Z", "entries=6", "secret=nope", "",
  "100.0000|combat|in",
  "100.1000|pixel|2|100.0900|spell 1757 Sinister Strike / SHIFT-2",
  "100.2000|cast|1757|1",
  "100.3000|failed|5171",
  "100.3100|error|62|Ability is not ready yet.",
  "160.0000|combat|out",
].join("\n");

const line = (kind, body) => `!FOB:1:${kind}!${Buffer.from(body).toString("base64")}!END:FOB!`;

test("compressed share: raw deflate, as C_EncodingUtil writes it", async () => {
  const decoded = await decodeShare(line("z", deflateRawSync(Buffer.from(TEXT))));
  assert.equal(decoded.compressed, true);
  assert.equal(decoded.text, TEXT);
});

test("plain share", async () => {
  const decoded = await decodeShare("  " + line("t", TEXT) + "\n");
  assert.equal(decoded.compressed, false);
  assert.equal(decoded.text, TEXT);
});

test("refusals say what is wrong", async () => {
  const code = async (paste) => { try { await decodeShare(paste); return "accepted"; } catch (e) { assert.ok(e instanceof ShareError); return e.code; } };
  assert.equal(await code(""), "empty");
  assert.equal(await code("!QuestieTrace:1!abc"), "not_fob");
  assert.equal(await code("!FOB:2:z!AAAA!END:FOB!"), "version");
  assert.equal(await code(line("z", deflateRawSync(Buffer.from(TEXT))).slice(0, -3)), "cut");
  assert.equal(await code("!FOB:1:z!@@@@!END:FOB!"), "encoding");
  assert.equal(await code(line("z", Buffer.from("not deflate at all"))), "encoding");
  // A small paste that inflates past the ceiling is refused.
  assert.equal(await code(line("z", deflateRawSync(Buffer.alloc(30 * 1024 * 1024, 65)))), "too_large");
});

test("header keeps known keys; entries and summary", () => {
  const { header, entries } = parseText(TEXT);
  assert.deepEqual(header, { addon: "1.1.6", build: "1.60.1.70862", class: "ROGUE", level: "10", locale: "enUS", exported: "2026-11-08T10:00:00Z", entries: "6" });
  assert.equal(entries.length, 6);
  const s = summarize(entries);
  assert.equal(s.casts, 1);
  assert.equal(s.failed, 1);
  assert.equal(s.errors, 1);
  assert.equal(s.combats, 1);
  assert.equal(s.minutes, 1);
  assert.deepEqual(s.topErrors, [{ message: "Ability is not ready yet.", count: 1 }]);
  assert.throws(() => parseText("hello\n\nworld"), ShareError);
  assert.throws(() => parseText("fob-share 1\naddon=1\n\nnot|a log\nreally not"), ShareError);
});

test("a client restart does not count as play time", () => {
  const s = summarize(["5000.0|combat|in", "5060.0|combat|out", "10.0|combat|in", "70.0|combat|out",
    "9000.0|combat|in", "9060.0|combat|out"]);
  assert.equal(s.minutes, 3, "restart and a long idle gap do not count");
});

test("storage key", () => {
  assert.equal(storageKey(new Date("2026-11-08T09:08:07Z"), "abc"), "fob/2026-11-08/090807-abc.txt");
});

function fakeEnv() {
  const stored = new Map();
  return {
    stored,
    ADMIN_TOKEN: "x".repeat(40),
    SHARES: {
      async put(key, value, options) { stored.set(key, { value, options }); },
      async get(key) { const o = stored.get(key); return o ? o.value : null; },
      async list() { return { keys: [...stored.keys()].map((name) => ({ name, metadata: stored.get(name).options.metadata })), list_complete: true }; },
    },
    LIMITER: { calls: 0, async limit() { this.calls++; return { success: this.calls <= 5 }; } },
  };
}

test("worker: page, share stored without request data, admin behind the token", async () => {
  const env = fakeEnv();
  const pageResponse = await worker.fetch(new Request("https://trace.lucabottani.dev/"), env);
  assert.equal(pageResponse.status, 200);
  assert.match(await pageResponse.text(), /Forever One Button/);
  assert.match(pageResponse.headers.get("Content-Security-Policy"), /frame-ancestors 'none'/);

  const body = line("z", deflateRawSync(Buffer.from(TEXT)));
  const response = await worker.fetch(new Request("https://trace.lucabottani.dev/api/share", {
    method: "POST", body, headers: { "CF-Connecting-IP": "203.0.113.9" } }), env);
  const result = await response.json();
  assert.equal(response.status, 200);
  assert.equal(result.ok, true);
  assert.equal(result.summary.casts, 1);
  assert.equal(env.stored.size, 1);
  const [[key, saved]] = [...env.stored];
  assert.match(key, /^fob\/\d{4}-\d\d-\d\d\/\d{6}-[0-9a-f-]{36}\.txt$/);
  assert.equal(saved.value, TEXT);
  assert.equal(saved.options.metadata.class, "ROGUE");
  assert.equal(saved.options.expirationTtl, 180 * 24 * 3600, "deleted after 180 days");
  assert.ok(!JSON.stringify(saved).includes("203.0.113.9"), "no IP stored");

  const bad = await worker.fetch(new Request("https://trace.lucabottani.dev/api/share", { method: "POST", body: "hello" }), env);
  assert.equal(bad.status, 400);
  assert.equal((await bad.json()).code, "not_fob");

  const denied = await worker.fetch(new Request("https://trace.lucabottani.dev/admin/list"), env);
  assert.equal(denied.status, 404);
  const wrong = await worker.fetch(new Request("https://trace.lucabottani.dev/admin/list", { headers: { Authorization: "Bearer " + "y".repeat(40) } }), env);
  assert.equal(wrong.status, 404);
  const listed = await worker.fetch(new Request("https://trace.lucabottani.dev/admin/list", { headers: { Authorization: "Bearer " + env.ADMIN_TOKEN } }), env);
  assert.equal((await listed.json()).objects[0].key, key);
  const got = await worker.fetch(new Request("https://trace.lucabottani.dev/admin/get?key=" + encodeURIComponent(key), { headers: { Authorization: "Bearer " + env.ADMIN_TOKEN } }), env);
  assert.equal(await got.text(), TEXT);
});

test("worker: rate limit and size limit", async () => {
  const env = fakeEnv();
  env.LIMITER.calls = 5;
  const limited = await worker.fetch(new Request("https://trace.lucabottani.dev/api/share", { method: "POST", body: "x" }), env);
  assert.equal(limited.status, 429);
  const big = await worker.fetch(new Request("https://trace.lucabottani.dev/api/share", { method: "POST", body: "!FOB:1:t!" + "A".repeat(5 * 1024 * 1024) }), fakeEnv());
  assert.equal(big.status, 413);
  const get = await worker.fetch(new Request("https://trace.lucabottani.dev/api/share"), fakeEnv());
  assert.equal(get.status, 405);
});
