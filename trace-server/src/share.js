// Reads a Forever One Button share (ForeverOneButton/Core/Share.lua):
//   "!FOB:1:<z|t>!" + base64(body) + "!END:FOB!"
//   z: body is raw deflate of the text, t: body is the text.
//   text: "fob-share 1\n" + "key=value\n"... + "\n" + log entries, one per line.
// Pure functions: the Worker (index.js) and the tests use them alike.

export const MAX_PASTE_BYTES = 4 * 1024 * 1024;
export const MAX_TEXT_BYTES = 24 * 1024 * 1024;
const PREFIX = /^!FOB:(\d+):([zt])!/;
const SUFFIX = "!END:FOB!";
const HEADER_KEYS = new Set(["addon", "build", "class", "level", "locale", "exported", "entries"]);

export class ShareError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function base64Bytes(text) {
  if (!/^[A-Za-z0-9+/]*={0,2}$/.test(text) || text.length % 4 !== 0) {
    throw new ShareError("encoding", "The text between the markers is not valid base64.");
  }
  const binary = atob(text);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

// Raw inflate with a ceiling on the output, so a small paste cannot expand
// into an unbounded amount of memory.
async function inflateRaw(bytes, limit) {
  const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream("deflate-raw"));
  const reader = stream.getReader();
  const chunks = [];
  let total = 0;
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.length;
      if (total > limit) {
        await reader.cancel();
        throw new ShareError("too_large", "The log is larger than the site accepts.");
      }
      chunks.push(value);
    }
  } catch (error) {
    if (error instanceof ShareError) throw error;
    throw new ShareError("encoding", "The compressed log could not be read: it may have been cut short.");
  }
  const out = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    out.set(chunk, offset);
    offset += chunk.length;
  }
  return out;
}

// The pasted line -> { format, compressed, text }.
export async function decodeShare(paste) {
  const line = String(paste ?? "").trim();
  if (line.length === 0) throw new ShareError("empty", "Nothing was pasted.");
  if (line.length > MAX_PASTE_BYTES) throw new ShareError("too_large", "The pasted text is larger than the site accepts.");
  const head = PREFIX.exec(line);
  if (!head) throw new ShareError("not_fob", "This is not a Forever One Button log: it must start with !FOB:1:");
  if (head[1] !== "1") throw new ShareError("version", `Log format ${head[1]} is newer than this page: update the page or the addon.`);
  if (!line.endsWith(SUFFIX)) throw new ShareError("cut", "The end marker !END:FOB! is missing: the text was cut short. Copy it again with Ctrl+A, Ctrl+C.");
  const bytes = base64Bytes(line.slice(head[0].length, line.length - SUFFIX.length));
  const compressed = head[2] === "z";
  const raw = compressed ? await inflateRaw(bytes, MAX_TEXT_BYTES) : bytes;
  if (raw.length > MAX_TEXT_BYTES) throw new ShareError("too_large", "The log is larger than the site accepts.");
  let text;
  try {
    text = new TextDecoder("utf-8", { fatal: true }).decode(raw);
  } catch {
    throw new ShareError("encoding", "The log is not valid text.");
  }
  return { format: 1, compressed, text };
}

// text -> { header, entries } ; the header keeps known keys only.
export function parseText(text) {
  const split = text.indexOf("\n\n");
  if (!text.startsWith("fob-share 1\n") || split < 0) {
    throw new ShareError("not_fob", "The log has no Forever One Button header.");
  }
  const header = {};
  for (const line of text.slice("fob-share 1\n".length, split).split("\n")) {
    const eq = line.indexOf("=");
    if (eq <= 0) continue;
    const key = line.slice(0, eq);
    if (HEADER_KEYS.has(key)) header[key] = line.slice(eq + 1).slice(0, 64);
  }
  const body = text.slice(split + 2);
  const entries = body.length ? body.split("\n") : [];
  if (entries.length === 0) throw new ShareError("empty", "The log has no entries.");
  const bad = entries.filter((entry) => !/^\d+(\.\d+)?\|[a-z_]+/.test(entry)).length;
  if (bad > entries.length / 10) throw new ShareError("not_fob", "The entries do not look like a Forever One Button log.");
  return { header, entries };
}

// What the page shows back: a few counts, as analyze_log.py reports them.
export function summarize(entries) {
  const counts = { casts: 0, errors: 0, failed: 0, combats: 0, pixel: 0 };
  const messages = new Map();
  let first = null;
  let last = null;
  let previous = null;
  let span = 0;
  for (const entry of entries) {
    const parts = entry.split("|");
    const t = Number(parts[0]);
    if (Number.isFinite(t)) {
      if (first === null) first = t;
      // The clock restarts with the client: count each run on its own.
      if (previous !== null && t >= previous) span += t - previous;
      previous = t;
      last = t;
    }
    switch (parts[1]) {
      case "cast": counts.casts++; break;
      case "failed": counts.failed++; break;
      case "pixel": counts.pixel++; break;
      case "combat": if (parts[2] === "in") counts.combats++; break;
      case "error": {
        counts.errors++;
        const text = parts.slice(3).join("|");
        messages.set(text, (messages.get(text) ?? 0) + 1);
        break;
      }
      default: break;
    }
  }
  const topErrors = [...messages.entries()].sort((a, b) => b[1] - a[1]).slice(0, 5)
    .map(([message, count]) => ({ message, count }));
  return { entries: entries.length, minutes: Math.round(span / 60), ...counts, topErrors, first, last };
}

// The storage key: date folder, then time and a random ID.
export function storageKey(now, id) {
  const iso = now.toISOString();
  return `fob/${iso.slice(0, 10)}/${iso.slice(11, 19).replaceAll(":", "")}-${id}.txt`;
}
