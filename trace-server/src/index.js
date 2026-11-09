// trace.lucabottani.dev: collection point for Forever One Button logs.
//   GET  /            the page: paste the line from /fob share, send it
//   POST /api/share   the pasted line (text/plain) -> stored in KV, summary back
//   GET  /admin       the owner's list page (token in the #fragment, kept in localStorage)
//   GET  /admin/list  ?prefix=&cursor=   (Authorization: Bearer ADMIN_TOKEN)
//   GET  /admin/get   ?key=              (same)
// No IP address or other request data is stored: only the log and the
// header it carries (addon version, client build, class, level, locale).
import { decodeShare, parseText, summarize, storageKey, ShareError, MAX_PASTE_BYTES } from "./share.js";
import { page } from "./page.js";
import { adminPage } from "./admin-page.js";
import { FAVICON } from "./favicon.js";

// Logs are deleted by KV itself after this long (privacy notice: 180 days).
export const KEEP_SECONDS = 180 * 24 * 3600;

const SECURITY_HEADERS = {
  "Content-Security-Policy": "default-src 'none'; script-src 'self' 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; img-src 'self' data:; base-uri 'none'; form-action 'self'; frame-ancestors 'none'",
  "X-Content-Type-Options": "nosniff",
  "Referrer-Policy": "no-referrer",
  "Strict-Transport-Security": "max-age=31536000",
};

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store", ...SECURITY_HEADERS },
  });
}

function html(body) {
  return new Response(body, {
    headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "public, max-age=300", ...SECURITY_HEADERS },
  });
}

function sameSecret(given, expected) {
  if (typeof given !== "string" || typeof expected !== "string" || expected.length < 32) return false;
  const a = new TextEncoder().encode(given);
  const b = new TextEncoder().encode(expected);
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

async function readLimited(request, limit) {
  const declared = Number(request.headers.get("Content-Length") ?? "0");
  if (declared > limit) throw new ShareError("too_large", "The pasted text is larger than the site accepts.");
  const reader = request.body?.getReader();
  if (!reader) return "";
  const chunks = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.length;
    if (total > limit) {
      await reader.cancel();
      throw new ShareError("too_large", "The pasted text is larger than the site accepts.");
    }
    chunks.push(value);
  }
  return new TextDecoder().decode(await new Blob(chunks).arrayBuffer());
}

async function share(request, env) {
  if (env.LIMITER) {
    // The address is only the rate-limit key, held by Cloudflare for the
    // window; it is not written anywhere.
    const { success } = await env.LIMITER.limit({ key: request.headers.get("CF-Connecting-IP") ?? "unknown" });
    if (!success) return json({ ok: false, code: "rate", message: "Too many logs in a short time: wait a minute and try again." }, 429);
  }
  try {
    const paste = await readLimited(request, MAX_PASTE_BYTES + 1024);
    const decoded = await decodeShare(paste);
    const { header, entries } = parseText(decoded.text);
    const summary = summarize(entries);
    const id = crypto.randomUUID();
    const key = storageKey(new Date(), id);
    await env.SHARES.put(key, decoded.text, {
      expirationTtl: KEEP_SECONDS,
      metadata: {
        addon: header.addon ?? "", build: header.build ?? "", class: header.class ?? "",
        level: header.level ?? "", locale: header.locale ?? "", entries: String(entries.length),
        compressed: decoded.compressed ? "1" : "0",
      },
    });
    return json({ ok: true, id, header, summary: { ...summary, first: undefined, last: undefined } });
  } catch (error) {
    if (error instanceof ShareError) {
      return json({ ok: false, code: error.code, message: error.message }, error.code === "too_large" ? 413 : 400);
    }
    console.error("share failed", error);
    return json({ ok: false, code: "server", message: "The site could not store the log. Try again later." }, 500);
  }
}

async function admin(request, env, url) {
  const auth = request.headers.get("Authorization") ?? "";
  if (!sameSecret(auth.replace(/^Bearer /, ""), env.ADMIN_TOKEN)) return json({ ok: false }, 404);
  if (url.pathname === "/admin/list") {
    const listed = await env.SHARES.list({
      prefix: url.searchParams.get("prefix") ?? "fob/",
      cursor: url.searchParams.get("cursor") ?? undefined,
      limit: 1000,
    });
    return json({
      ok: true,
      objects: listed.keys.map((k) => ({ key: k.name, expiration: k.expiration, meta: k.metadata })),
      cursor: listed.list_complete ? null : listed.cursor,
    });
  }
  if (url.pathname === "/admin/get") {
    const text = await env.SHARES.get(url.searchParams.get("key") ?? "");
    if (text === null) return json({ ok: false }, 404);
    return new Response(text, { headers: { "Content-Type": "text/plain; charset=utf-8", "Cache-Control": "no-store" } });
  }
  return json({ ok: false }, 404);
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/" && (request.method === "GET" || request.method === "HEAD")) return html(page());
    if (url.pathname === "/api/share") {
      if (request.method !== "POST") return json({ ok: false, code: "method" }, 405);
      return share(request, env);
    }
    if (url.pathname === "/favicon.svg" && (request.method === "GET" || request.method === "HEAD")) {
      return new Response(FAVICON, { headers: { "Content-Type": "image/svg+xml", "Cache-Control": "public, max-age=86400", ...SECURITY_HEADERS } });
    }
    if (url.pathname === "/admin" && request.method === "GET") {
      const response = html(adminPage());
      response.headers.set("Cache-Control", "no-store");
      return response;
    }
    if (url.pathname.startsWith("/admin/") && request.method === "GET") return admin(request, env, url);
    return json({ ok: false, code: "not_found" }, 404);
  },
};
