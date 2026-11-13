// Error reports sent by Regia (https://github.com/DoctorB/regia), only when the
// person using it has agreed. Regia anonymizes them before sending (paths,
// user name, secrets); here the report is checked field by field and stored
// as normalized JSON. Pure functions: the Worker (index.js) and the tests use
// them alike.

export const MAX_REPORT_BYTES = 16 * 1024;
const SOURCES = new Set(["fase", "server", "ui"]);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

export class ReportError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function text(value, max, field, required = false) {
  if (value === undefined || value === null || value === "") {
    if (required) throw new ReportError("field", `Missing field: ${field}.`);
    return undefined;
  }
  if (typeof value !== "string") throw new ReportError("field", `Field ${field} must be a string.`);
  return value.slice(0, max);
}

/** Checks a report and returns the stored form; throws ReportError when it is not a valid Regia report. */
export function parseReport(raw) {
  let j;
  try {
    j = JSON.parse(raw);
  } catch {
    throw new ReportError("json", "The report is not valid JSON.");
  }
  if (!j || typeof j !== "object" || Array.isArray(j)) throw new ReportError("json", "The report must be a JSON object.");
  if (j.v !== 1) throw new ReportError("version", "Unknown report version.");
  const install = text(j.install, 36, "install", true);
  if (!UUID.test(install)) throw new ReportError("field", "Field install must be a UUID.");
  const source = text(j.source, 10, "source", true);
  if (!SOURCES.has(source)) throw new ReportError("field", "Unknown source.");
  const at = text(j.at, 30, "at", true);
  if (Number.isNaN(Date.parse(at))) throw new ReportError("field", "Field at must be a date.");
  return {
    v: 1,
    install,
    regia: text(j.regia, 20, "regia", true),
    os: text(j.os, 60, "os"),
    node: text(j.node, 20, "node"),
    lang: text(j.lang, 10, "lang"),
    source,
    key: text(j.key, 100, "key"),
    kind: text(j.kind, 30, "kind"),
    message: text(j.message, 2000, "message", true),
    detail: text(j.detail, 8000, "detail"),
    at,
  };
}

/** KV metadata shown in the admin list (KV allows at most 1024 bytes). */
export function reportMeta(r) {
  return {
    regia: r.regia, os: (r.os ?? "").slice(0, 40), source: r.source, key: r.key ?? "", kind: r.kind ?? "",
    install: r.install.slice(0, 8), message: r.message.slice(0, 160),
  };
}

export function reportKey(now, id) {
  const iso = now.toISOString();
  return `regia/${iso.slice(0, 10)}/${iso.slice(11, 19).replaceAll(":", "")}-${id}.json`;
}
