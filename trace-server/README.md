# trace-server

The page at <https://trace.lucabottani.dev> where players paste the line
from `/fob share` (ForeverOneButton/Core/Share.lua). A Cloudflare Worker:
it checks the line, stores the log in the R2 bucket `fob-trace-shares` and
shows a short summary. No IP address or other request data is stored; the
bucket deletes logs after 180 days (lifecycle rule).

Format: `!FOB:1:<z|t>!` + base64 + `!END:FOB!`; `z` is raw deflate, which
is what `C_EncodingUtil.CompressString(..., Enum.CompressionMethod.Deflate)`
writes on the Forever client (checked on 2026-11-08 by inflating data saved
by another addon on that client).

    npm install
    npm test                    # node --test, no Cloudflare needed
    npx wrangler deploy         # needs `npx wrangler login`

One-time setup (done on 2026-11-08):

    npx wrangler r2 bucket create fob-trace-shares
    npx wrangler r2 bucket lifecycle add fob-trace-shares expire-180 fob/ --expire-days 180
    npx wrangler secret put ADMIN_TOKEN

Reading the logs: `py -B ../scripts/fetch_shares.py` with the token in
`trace-server/.dev.vars` (`ADMIN_TOKEN=...`, git-ignored) downloads new
logs into `local/shares/` and runs `scripts/analyze_log.py` on each.
