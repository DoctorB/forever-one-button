-- Forever One Button: share the diagnostic log.
--
-- An addon cannot send anything over the network: the log becomes one line
-- of text that the player copies and pastes at Share.URL, where it is
-- checked and stored. Nothing leaves the computer unless the player does
-- that, and the log itself is off by default (/fob log on).
--
-- Format (version 1):
--   "!FOB:1:<z|t>!" .. base64(body) .. "!END:FOB!"
--   z: body = raw deflate of the text (C_EncodingUtil.CompressString,
--      Enum.CompressionMethod.Deflate; raw deflate on the Forever client,
--      checked on 2026-11-08 against another addon's saved data), t: the
--      text itself when the client cannot compress.
--   text = "fob-share 1\n" header lines "key=value\n", an empty line, then
--          the log entries, one per line (Core/Diagnostics.lua).
-- The markers show at a glance whether a pasted line was cut short.
--
-- Privacy: the entries hold spell and item IDs and names, game error
-- messages and times; the character's name and realm are replaced with
-- "<player>" / "<realm>" wherever they appear all the same. The header has
-- the class, level, addon version and client build, never a name.
local ADDON_NAME, ns = ...

local Share = {}
ns.Share = Share

Share.FORMAT = 1
Share.URL = "https://trace.lucabottani.dev"
Share.PREFIX = "!FOB:" .. Share.FORMAT .. ":"
Share.SUFFIX = "!END:FOB!"

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_CHARS = {}
for i = 1, 64 do B64_CHARS[i - 1] = B64:sub(i, i) end

-- Standard base64 with "=" padding (RFC 4648), pure Lua 5.1.
function Share.Base64(data)
    local out, n = {}, #data
    local floor = math.floor
    for i = 1, n - 2, 3 do
        local a, b, c = data:byte(i, i + 2)
        local v = a * 65536 + b * 256 + c
        out[#out + 1] = B64_CHARS[floor(v / 262144)] .. B64_CHARS[floor(v / 4096) % 64]
            .. B64_CHARS[floor(v / 64) % 64] .. B64_CHARS[v % 64]
    end
    local rest = n % 3
    if rest == 1 then
        local v = data:byte(n) * 65536
        out[#out + 1] = B64_CHARS[floor(v / 262144)] .. B64_CHARS[floor(v / 4096) % 64] .. "=="
    elseif rest == 2 then
        local a, b = data:byte(n - 1, n)
        local v = a * 65536 + b * 256
        out[#out + 1] = B64_CHARS[floor(v / 262144)] .. B64_CHARS[floor(v / 4096) % 64]
            .. B64_CHARS[floor(v / 64) % 64] .. "="
    end
    return table.concat(out)
end

local function EscapePattern(text)
    return (text:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1"))
end

local function Readable(value)
    return type(value) == "string" and value ~= "" and not ns.IsSecret(value)
end

-- Replaces the player's name and realm, as whole words where they start and
-- end with a letter.
function Share.Scrub(line, name, realm)
    for _, pair in ipairs({{name, "<player>"}, {realm, "<realm>"}}) do
        local word, mark = pair[1], pair[2]
        if Readable(word) and #word >= 2 then
            local pattern = EscapePattern(word)
            if word:find("^[A-Za-z]") then pattern = "%f[A-Za-z]" .. pattern end
            if word:find("[A-Za-z]$") then pattern = pattern .. "%f[^A-Za-z]" end
            line = line:gsub(pattern, mark)
        end
    end
    return line
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok then return nil end
    return a, b
end

-- Who and what produced the log, without names.
function Share.Header()
    local header = {}
    local _, class = Call(UnitClass, "player")
    header[#header + 1] = "addon=" .. tostring(ns.VERSION)
    if GetBuildInfo then
        local version, number = Call(GetBuildInfo)
        if Readable(version) then header[#header + 1] = "build=" .. version .. "." .. tostring(number) end
    end
    if Readable(class) then header[#header + 1] = "class=" .. class end
    local level = Call(UnitLevel, "player")
    if type(level) == "number" and not ns.IsSecret(level) then header[#header + 1] = "level=" .. level end
    local locale = Call(GetLocale)
    if Readable(locale) then header[#header + 1] = "locale=" .. locale end
    if type(date) == "function" then header[#header + 1] = "exported=" .. date("!%Y-%m-%dT%H:%M:%SZ") end
    return header
end

-- The text of a share: header and scrubbed entries.
function Share.Text(entries, header)
    local name = Call(UnitName, "player")
    local realm = Call(GetRealmName)
    local lines = {"fob-share " .. Share.FORMAT}
    for _, line in ipairs(header or Share.Header()) do lines[#lines + 1] = line end
    lines[#lines + 1] = "entries=" .. #entries
    lines[#lines + 1] = ""
    for _, entry in ipairs(entries) do lines[#lines + 1] = Share.Scrub(entry, name, realm) end
    return table.concat(lines, "\n")
end

-- Raw deflate through the client, or nil when it cannot compress.
function Share.Compress(text)
    local util = C_EncodingUtil
    local method = Enum and Enum.CompressionMethod and Enum.CompressionMethod.Deflate
    if not (util and util.CompressString and method) then return nil end
    local level = Enum.CompressionLevel and Enum.CompressionLevel.Default
    local ok, compressed = pcall(util.CompressString, text, method, level)
    if ok and type(compressed) == "string" and compressed ~= "" then return compressed end
    return nil
end

-- Seconds of play the entries cover: gaps up to IDLE_GAP between entries
-- count, longer ones (logged out, AFK) and clock restarts do not. In game
-- the first-to-last difference read "11 h 20 min" for a few hours of play.
Share.IDLE_GAP = 300
function Share.Played(entries)
    local played, previous = 0, nil
    for _, entry in ipairs(entries) do
        local t = tonumber((entry:match("^([%d.]+)|")))
        if t then
            if previous and t >= previous and t - previous <= Share.IDLE_GAP then played = played + t - previous end
            previous = t
        end
    end
    return played
end

-- What /fob share shows: {text = the line to paste, entries = count, last =
-- the last entry shared, compressed, size, played seconds}, or nil and a reason.
function Share.Build()
    local entries = ForeverOneButtonLog and ForeverOneButtonLog.entries
    if type(entries) ~= "table" or #entries == 0 then return nil, "empty" end
    local snapshot = {}
    for i = 1, #entries do snapshot[i] = entries[i] end
    local text = Share.Text(snapshot)
    local compressed = Share.Compress(text)
    local body = Share.Base64(compressed or text)
    return {
        text = Share.PREFIX .. (compressed and "z" or "t") .. "!" .. body .. Share.SUFFIX,
        entries = #snapshot,
        last = snapshot[#snapshot],
        compressed = compressed ~= nil,
        size = #text,
        played = Share.Played(snapshot),
    }
end

-- After the player says the share was sent: removes the shared entries (up
-- to and including `last`); entries logged since stay. The oldest entries
-- may have been trimmed meanwhile, so `last` is searched, not counted.
function Share.Forget(last)
    local entries = ForeverOneButtonLog and ForeverOneButtonLog.entries
    if type(entries) ~= "table" or type(last) ~= "string" then return 0 end
    local through
    for i = #entries, 1, -1 do
        if entries[i] == last then through = i break end
    end
    if not through then return 0 end
    local count = #entries
    for i = 1, count - through do entries[i] = entries[i + through] end
    for i = count - through + 1, count do entries[i] = nil end
    return through
end
