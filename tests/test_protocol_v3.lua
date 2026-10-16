-- Protocol v3 encoding, end to end from the JustAC queue to the 8-bit colour.
--
-- DecodeV3 below decodes the colour as specified in the HCOneButton README
-- (protocol v3, steps 4-5): a spec-derived check of the encoding.
local H = dofile("tests/harness/wow.lua")
local ns = H.Boot(nil)
ForeverOneButtonDB.pixel.combatOnly = false -- the combat-only gate is tested at the end
local lib = H.InstallJustAC(43)

local function DecodeV3(r, g, b)
    if r == 0 and g == 0 and b == 0 then return "none" end
    if r == 255 and g == 255 and b == 255 then return "unmapped" end
    if g ~= 96 or b ~= 224 or r % 12 ~= 0 then return "invalid" end
    local slot = r / 12
    if slot < 1 or slot > 20 then return "invalid" end
    return slot
end

local function Decoded()
    local r, g, b, a = H.Pixel255()
    H.Equal(a, 1, "alpha is always 1")
    return DecodeV3(r, g, b)
end

H.Check(ns.Settings.SetGridValue("slots", 20), "20 cells")
for slot = 1, 20 do
    H.spells[7000 + slot] = {name = "S" .. slot, inRange = true}
    H.Check(ns.Actions.Assign(slot, "spell", 7000 + slot), "assign slot " .. slot)
end

-- README examples table.
local examples = {[1] = "0C60E0", [2] = "1860E0", [3] = "2460E0", [10] = "7860E0", [18] = "D860E0", [19] = "E460E0", [20] = "F060E0"}
for slot = 1, 20 do
    lib.SetQueue({7000 + slot, 7001})
    H.Tick(0.06)
    H.Equal(Decoded(), slot, "queue head on cell " .. slot)
    if examples[slot] then
        local r, g, b = H.Pixel255()
        H.Equal(string.format("%02X%02X%02X", r, g, b), examples[slot], "README hex for slot " .. slot)
    end
end

-- Only position 1 is encoded; the tail never leaks into the pixel.
lib.SetQueue({9999, 7003})
H.Tick(0.06)
H.Equal(Decoded(), "unmapped", "unmapped head is white even if position 2 is on the grid")

-- States that must be black ("no executable recommendation").
lib.SetQueue({})
H.Tick(0.06)
H.Equal(Decoded(), "none", "empty queue")
lib.SetQueue({lib.WAIT_SENTINEL, 7004})
H.Tick(0.06)
H.Equal(Decoded(), "none", "JustAC wait")
lib.GetCurrentSpellQueue = function() return {H.Secret()} end
H.Tick(0.06)
H.Equal(Decoded(), "none", "unreadable head")
lib.GetCurrentSpellQueue = function() error("x") end
H.Tick(0.06)
H.Equal(Decoded(), "none", "JustAC error")
lib.GetCurrentSpellQueue = function() return lib._shared end

lib.SetQueue({7005})
H.Tick(0.06)
H.Equal(Decoded(), 5, "back to slot 5")
H.casting = "Frostbolt"
H.Tick(0.06)
H.Equal(Decoded(), "none", "player casting")
H.casting = nil
H.channeling = H.Secret()
H.Tick(0.06)
H.Equal(Decoded(), "none", "secret channel info still means channeling")
H.channeling = nil
H.Tick(0.06)
H.Equal(Decoded(), 5, "cast over")

H.target = true
H.spells[7005].inRange = false
H.Tick(0.06)
H.Equal(Decoded(), "none", "confirmed out of range")
H.spells[7005].inRange = H.Secret()
H.Tick(0.06)
H.Equal(Decoded(), 5, "secret range is unknown, not out of range")
H.spells[7005].inRange = nil
H.Tick(0.06)
H.Equal(Decoded(), 5, "nil range is unknown")
H.spells[7005].inRange = true

-- JustAC disappears: black at once, nothing obsolete stays.
H.libs["JustAC-SpellQueue"] = nil
H.Tick(0.06)
H.Equal(Decoded(), "none", "library gone")
H.Equal(ns.Grid.statusText:GetText():find("not loaded") ~= nil, true, "grid says JustAC not loaded")
for slot = 1, 20 do
    H.Equal(ns.Grid.buttons[slot].positionText:GetText(), "", "no stale mark on cell " .. slot)
end

-- Items: JustAC -itemID maps to the cell holding that item.
H.libs["JustAC-SpellQueue"] = nil
lib = H.InstallJustAC(43)
H.items[5512] = {name = "Healthstone", spell = 6262}
H.Check(ns.Actions.Clear(9), "clear 9")
H.Check(ns.Actions.Assign(9, "item", 5512), "item on 9")
lib.SetQueue({-5512})
H.Tick(0.06)
H.Equal(Decoded(), 9, "item head")
H.Check(ns.Pixel.AcknowledgeCast(6262), "item use spell acknowledges the item")
H.Equal(Decoded(), "none", "item ack edge")

-- Override spells: JustAC shows the display (override) ID of the cell's spell.
H.spells[7006].override = 8806
H.spells[8806] = {name = "Empowered S6"}
lib.SetQueue({8806})
H.Tick(0.2)
H.Equal(Decoded(), 6, "override ID resolves to the cell of its base spell")

-- Combat-only pixel (default; owner decision 2026-10-15): the player opens
-- every fight; out of combat the pixel is protocol black, in combat it
-- follows JustAC position 1. The grid keeps showing suggestions throughout.
ns.Pixel.SetCombatOnly(true)
lib.SetQueue({7005})
H.Tick(0.1)
H.Equal(Decoded(), "none", "out of combat: black although JustAC suggests cell 5")
H.Equal(ns.Grid.buttons[5].positionText:GetText(), "1", "grid still shows the suggestion out of combat")
H.inCombat = true
H.Fire("PLAYER_REGEN_DISABLED")
H.Equal(Decoded(), 5, "entering combat publishes at once, without waiting for the poll")
lib.SetQueue({7007})
H.Tick(0.1)
H.Equal(Decoded(), 7, "in combat: follows JustAC")
H.Check(ns.Pixel.AcknowledgeCast(7007), "acknowledgement works in combat")
H.Equal(Decoded(), "none", "ack edge")
H.Advance(0.061)
H.Equal(Decoded(), 7, "after the edge")
H.inCombat = false
H.Fire("PLAYER_REGEN_ENABLED")
H.Equal(Decoded(), "none", "leaving combat turns black at once")
H.Advance(0.2)
H.Tick(0.2)
H.Equal(Decoded(), "none", "stays black out of combat")
ns.Commands.Handle("pixel combat off")
H.Equal(Decoded(), 7, "option off: active out of combat")
ns.Commands.Handle("pixel combat on")
H.Equal(Decoded(), "none", "option back on")

-- The decoder never sees anything outside the protocol.
for _, colour in ipairs(_G.ForeverOneButtonDiagPixel.regions[1].colorHistory) do
    local function b8(v) return math.floor(v * 255 + 0.5) end
    H.Check(DecodeV3(b8(colour[1]), b8(colour[2]), b8(colour[3])) ~= "invalid", "every written colour decodes")
end

H.Done("test_protocol_v3")
