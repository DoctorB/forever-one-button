# trace-server

The page at <https://trace.lucabottani.dev> where players paste the line
from `/fob share` (ForeverOneButton/Core/Share.lua). A Cloudflare Worker:
it checks the line, stores the log in the Workers KV namespace `SHARES` and
shows a short summary. No IP address or other request data is stored; KV
deletes each log 180 days after it was sent (expirationTtl).

Format: `!FOB:1:<z|t>!` + base64 + `!END:FOB!`; `z` is raw deflate, which
is what `C_EncodingUtil.CompressString(..., Enum.CompressionMethod.Deflate)`
writes on the Forever client (checked on 2026-11-08 by inflating data saved
by another addon on that client).

    npm install
    npm test                    # node --test, no Cloudflare needed
    npx wrangler deploy         # needs `npx wrangler login`

One-time setup (done on 2026-11-08):

    npx wrangler kv namespace create SHARES   # id in wrangler.jsonc
    npx wrangler secret put ADMIN_TOKEN

(R2 would need billing enabled on the account; KV does not, and its
per-key expiry does the 180-day deletion.)

Reading the logs: `py -B ../scripts/fetch_shares.py` with the token in
`trace-server/.dev.vars` (`ADMIN_TOKEN=...`, git-ignored) downloads new
logs into `local/shares/` and runs `scripts/analyze_log.py` on each.
