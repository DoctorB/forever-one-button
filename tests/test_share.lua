-- /fob share: the diagnostic log as one line to paste on the collection
-- page; names removed; only "I sent it" removes the shared entries.
local H = dofile("tests/harness/wow.lua")
local ns = H.Boot(nil, nil)
local Share = ns.Share

-- Base64 (RFC 4648 test vectors).
for plain, encoded in pairs({[""] = "", f = "Zg==", fo = "Zm8=", foo = "Zm9v", foob = "Zm9vYg==",
        fooba = "Zm9vYmE=", foobar = "Zm9vYmFy", ["\0\255\128"] = "AP+A"}) do
    H.Equal(Share.Base64(plain), encoded, "base64 of " .. plain)
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function Decode(text)
    text = text:gsub("=", "")
    local bits, out = 0, {}
    local value = 0
    for i = 1, #text do
        value = value * 64 + (B64:find(text:sub(i, i), 1, true) - 1)
        bits = bits + 6
        if bits >= 8 then
            bits = bits - 8
            local byte = math.floor(value / 2 ^ bits)
            out[#out + 1] = string.char(byte)
            value = value - byte * 2 ^ bits
        end
    end
    return table.concat(out)
end

-- Nothing to share yet.
local _, reason = Share.Build()
H.Equal(reason, "empty", "empty log")
H.Equal(ns.ShareWindow.Open(), false, "no window for an empty log")

-- Names are removed, as whole words.
H.units.player = H.units.player or {health = 100, healthMax = 100}
H.units.player.name = "Roggo"
GetRealmName = function() return "Forever" end
H.Equal(Share.Scrub("1.0|error|50|Roggo is dead, Roggos too", "Roggo", "Forever"),
    "1.0|error|50|<player> is dead, Roggos too", "player name as a whole word")
H.Equal(Share.Scrub("Forever-Roggo", "Roggo", "Forever"), "<realm>-<player>", "realm too")

ns.Commands.Handle("log on")
ns.Log("error", 50, "Roggo cannot do that")
ns.Log("cast", 1757, 1)

-- Without client compression: text, base64.
C_EncodingUtil = nil
local share = assert(Share.Build())
H.Check(share.text:find("^!FOB:1:t!") ~= nil, "plain marker: " .. share.text:sub(1, 12))
H.Check(share.text:sub(-#Share.SUFFIX) == Share.SUFFIX, "end marker")
local body = share.text:sub(#"!FOB:1:t!" + 1, -#Share.SUFFIX - 1)
local text = Decode(body)
H.Check(text:find("^fob%-share 1\naddon=" .. ns.VERSION:gsub("%.", "%%.") .. "\n") ~= nil, "header: " .. text:sub(1, 40))
H.Check(text:find("\nclass=" .. H.class .. "\n", 1, true) ~= nil, "class in the header")
H.Check(text:find("\nentries=" .. share.entries .. "\n\n", 1, true) ~= nil, "entry count, then the entries")
H.Check(text:find("<player> cannot do that", 1, true) ~= nil, "name removed")
H.Check(text:find("Roggo", 1, true) == nil, "no name anywhere")
H.Equal(share.compressed, false, "not compressed")

-- With client compression: the compressed bytes are what is encoded.
local seen
C_EncodingUtil = {CompressString = function(input, method, level)
    seen = {method = method, level = level}
    return "DEFLATE:" .. #input
end}
Enum.CompressionMethod = {Deflate = 0}
Enum.CompressionLevel = {Default = 1}
share = assert(Share.Build())
H.Check(share.text:find("^!FOB:1:z!") ~= nil, "compressed marker")
H.Equal(seen.method, 0, "deflate")
H.Equal(Decode(share.text:sub(#"!FOB:1:z!" + 1, -#Share.SUFFIX - 1)):sub(1, 8), "DEFLATE:", "compressed body")
-- A failing compressor falls back to text.
C_EncodingUtil.CompressString = function() error("no") end
H.Check(assert(Share.Build()).text:find("^!FOB:1:t!") ~= nil, "fallback to text")
C_EncodingUtil = nil

-- The window: Close keeps the log; "I sent it" removes the shared entries
-- and keeps those logged since.
H.Equal(ns.ShareWindow.Open(), true, "window opens")
local window = _G.ForeverOneButtonShare
H.Check(window:IsShown(), "shown")
local shared = #ForeverOneButtonLog.entries
window:Hide()
H.Equal(#ForeverOneButtonLog.entries, shared, "closing keeps the log")
ns.Commands.Handle("share")
H.Check(window:IsShown(), "/fob share opens it")
ns.Log("cast", 6760, 1)
local later = ForeverOneButtonLog.entries[#ForeverOneButtonLog.entries]
ns.ShareWindow.Sent()
H.Equal(#ForeverOneButtonLog.entries, 1, "only the entry logged after the share is left")
H.Equal(ForeverOneButtonLog.entries[1], later, "the later entry")
H.Check(not window:IsShown(), "closed after sending")
ns.ShareWindow.Sent()
H.Equal(#ForeverOneButtonLog.entries, 1, "a second click removes nothing")

-- Play time: idle gaps (logged out, AFK) and clock restarts do not count.
H.Equal(Share.Played({"100.0|combat|in", "160.0|cast|1|1", "5000.0|combat|in", "5030.0|combat|out",
    "20.0|combat|in", "50.0|combat|out"}), 120, "60 + 30 + 30 seconds")

-- Trimmed meanwhile: the shared entries are found by content, not counted.
ns.Commands.Handle("log clear")
for i = 1, 5 do ns.Log("cast", 100 + i, 1) end
share = assert(Share.Build())
table.remove(ForeverOneButtonLog.entries, 1)
table.remove(ForeverOneButtonLog.entries, 1)
ns.Log("cast", 999, 1)
H.Equal(Share.Forget(share.last), 3, "the three shared entries still there")
H.Equal(#ForeverOneButtonLog.entries, 1, "the new one stays")
H.Equal(Share.Forget("not in the log"), 0, "unknown entry: nothing removed")

-- Reminder: a chat link to the share window, in a resting area, out of
-- combat, with 30 minutes of unshared play, at most once an hour.
local R = ns.ShareReminder
H.Equal(R.linkHandler, "SetItemRef", "no LinkUtil in the harness: SetItemRef hook")
local clock = 1000000
time = function() return clock end
local resting = false
IsResting = function() return resting end
ns.Commands.Handle("log clear")
for i = 0, 40 do ns.Log("combat", "in"); end
-- 40 minutes of entries, one a minute.
for i = 1, #ForeverOneButtonLog.entries do
    ForeverOneButtonLog.entries[i] = string.format("%.4f|cast|1752|1", 100 + i * 60)
end
ForeverOneButtonLog.remindedAt = nil
local function Reminders()
    local n = 0
    for _, line in ipairs(H.printed) do if line:find("|Hfobshare:open|h", 1, true) then n = n + 1 end end
    return n
end
local before = Reminders()
H.Fire("PLAYER_UPDATE_RESTING")
H.Equal(Reminders(), before, "not resting: no reminder")
resting = true
H.inCombat = true
H.Fire("PLAYER_UPDATE_RESTING")
H.Equal(Reminders(), before, "in combat: no reminder")
H.inCombat = false
H.Fire("PLAYER_REGEN_ENABLED")
H.Equal(Reminders(), before + 1, "out of combat in an inn: reminder with the link")
H.Fire("PLAYER_UPDATE_RESTING")
H.Equal(Reminders(), before + 1, "once an hour")
clock = clock + 3601
ns.Commands.Handle("log off")
H.Fire("PLAYER_UPDATE_RESTING")
H.Equal(Reminders(), before + 1, "log off: no reminder")
ns.Commands.Handle("log on")
for i = #ForeverOneButtonLog.entries, 1, -1 do
    if not ForeverOneButtonLog.entries[i]:find("|cast|", 1, true) then table.remove(ForeverOneButtonLog.entries, i) end
end
H.Fire("PLAYER_UPDATE_RESTING")
H.Equal(Reminders(), before + 2, "an hour later: again")
-- The link opens the window; opening it counts as a reminder.
_G.ForeverOneButtonShare:Hide()
SetItemRef("fobshare:open", "[Share the log]", "LeftButton")
H.Check(_G.ForeverOneButtonShare:IsShown(), "the link opens the share window")
H.Equal(ForeverOneButtonLog.remindedAt, clock, "opening counts as reminded")
H.Equal(R.HandleLink("item:123"), false, "other links are not ours")
-- Too little play: no reminder.
ns.ShareWindow.Sent()
clock = clock + 7200
for i = 1, 5 do ns.Log("cast", 1, 1) end
H.Fire("PLAYER_UPDATE_RESTING")
H.Equal(Reminders(), before + 2, "under 30 minutes of play: no reminder")

H.Done("test_share")
