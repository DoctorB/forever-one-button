-- Options are limited to bindings and the necessary UI/pixel settings
-- (criterion 10, docs/BINDINGS_AND_OPTIONS.md). Nothing is imported from
-- HCOneButton or other saved data.
local H = dofile("tests/harness/wow.lua")

-- HCOneButton data present on the same account must not seed anything.
HCOB_DB = {actionSlotKeys = {"SHIFT-1"}, diagPixel = false, prePullSafety = true, warriorAutoRend = true, locked = false}

local raw = {
    schema = 1, -- 0.1.0 layout: its account-wide cells migrate to the character spamButton = true, pullAdvisor = true, autoPull = true, priority = {1, 2}, rotation = "x",
    cells = {[1] = {kind = "macro", id = 1}, [2] = {kind = "spell", id = 5}, [3] = {kind = "spell", id = 5},
        [4] = {kind = "item", id = -3}, [25] = {kind = "spell", id = 9}, [6] = {kind = "spell", id = 6, extra = "spam"}},
    keys = {[1] = "BUTTON1", [2] = "shift-2", [3] = "SHIFT-2", [4] = "ctrl+alt+q", [30] = "F"},
    grid = {columns = 999, slots = -4, scale = "big", cellSize = 33.4, foo = true, locked = false, point = {"NOWHERE", "CENTER", 1, 2}},
    pixel = {enabled = false, color = {1, 0, 0}, size = 32, point = {"TOPLEFT", "TOPLEFT", 5, -5}},
}
local ns = H.Boot(raw)
local db = ForeverOneButtonDB

local function Keys(t)
    local list = {}
    for k in pairs(t) do list[#list + 1] = tostring(k) end
    table.sort(list)
    return table.concat(list, ",")
end
H.Equal(Keys(db), "autoFill,features,grid,hideBlizzardBar,keys,pixel,schema", "top-level whitelist: no cells, no spam/pull")
H.Equal(db.hideBlizzardBar, false, "Blizzard bar visible by default")
-- Features: every key from Settings.FEATURES with its default; nothing else.
local featureNames = {}
for name in pairs(ns.Settings.FEATURES) do featureNames[#featureNames + 1] = name end
table.sort(featureNames)
H.Equal(Keys(db.features), table.concat(featureNames, ","), "feature whitelist")
H.Equal(db.features.burstCue, true, "burst cue on by default")
H.Equal(db.features.groupHeals, false, "group heals off by default")
H.Equal(db.features.interruptMode, "kickPrefer", "interrupt mode default")
local again = ns.Settings.Sanitize({features = {burstCue = "yes", interruptMode = "spam", petHealBelow = 500,
    autoInterrupt = true}})
H.Equal(again.features.burstCue, false, "non-boolean -> off")
H.Equal(again.features.interruptMode, "kickPrefer", "unknown mode -> default")
H.Equal(again.features.petHealBelow, 90, "number clamped")
H.Equal(again.features.autoInterrupt, nil, "unknown feature dropped")
H.Check(not ns.Settings.SetFeature("burstCue", "maybe"), "boolean feature refuses other values")
H.Check(not ns.Settings.SetFeature("autoCast", true), "unknown feature refused")
ns.Commands.Handle("feature burstcue off")
H.Equal(ns.Settings.Feature("burstCue"), false, "/fob feature, any case")
ns.Commands.Handle("feature burstCue on")
local char = ForeverOneButtonCharDB
H.Equal(Keys(char), "cells,dismissed,schema", "character whitelist")
H.Equal(db.schema, 2, "schema upgraded")
H.Equal(Keys(db.grid), "cellSize,columns,locked,point,queueDepth,scale,shown,slots,spacing", "grid whitelist")
H.Equal(Keys(db.pixel), "combatOnly,enabled,locked,point", "pixel whitelist: no colour, size or protocol fields")
H.Equal(db.pixel.combatOnly, true, "combat-only pixel on by default")
H.Equal(db.grid.columns, 20, "columns clamped")
H.Equal(db.grid.slots, 1, "slots clamped")
H.Equal(db.grid.scale, 1.0, "invalid scale -> default")
H.Equal(db.grid.cellSize, 33, "integer size")
H.Equal(db.grid.locked, false, "lock flag kept")
H.Equal(db.grid.point[1], "CENTER", "invalid anchor -> default")
H.Equal(db.pixel.enabled, false, "pixel visibility kept")
H.Equal(db.pixel.point[3], 5, "pixel position kept")
H.Equal(Keys(char.cells), "2,6", "invalid, duplicate and out-of-range cells dropped")
H.Equal(Keys(char.cells[6]), "id,kind", "no extra cell fields")
H.Equal(Keys(db.keys), "2,4", "invalid, duplicate and out-of-range keys dropped")
H.Equal(db.keys[4], "CTRL-ALT-Q", "keys normalized")
H.Equal(HCOB_DB.actionSlotKeys[1], "SHIFT-1", "HCOneButton data left untouched")

-- Option surfaces: numeric rows match the grid whitelist exactly.
local listed = {}
for _, name in ipairs(ns.Options.NUMERIC_ORDER) do listed[name] = true end
for name in pairs(ns.Settings.GRID_LIMITS) do H.Check(listed[name], "option row for " .. name) end
H.Equal(#ns.Options.NUMERIC_ORDER, 6, "six numeric options")
H.Check(not ns.Settings.SetGridValue("spam", 1), "unknown option refused")
H.Check(not ns.Settings.SetGridValue("pullTimer", 1), "unknown option refused")

-- Open the window and inventory its controls.
db.grid.slots = 12
H.Check(ns.Options.Open(), "options open")
local checks, buttons = 0, {}
for _, f in ipairs(H.frames) do
    if f.template == "UICheckButtonTemplate" then checks = checks + 1 end
    if f.template == "UIPanelButtonTemplate" then buttons[#buttons + 1] = f end
end
-- Features page: a check box per boolean feature, -/+ per number.
local featureChecks, featureNumbers = 0, 0
for _, row in ipairs(ns.Options.FEATURE_ORDER) do
    local kind = ns.Settings.FEATURES[row[1]].kind
    if kind == "boolean" then featureChecks = featureChecks + 1 elseif kind == "number" then featureNumbers = featureNumbers + 1 end
end
H.Equal(checks, 7 + featureChecks, "grid shown/locked, pixel shown/locked/combat only, Blizzard bar, automatic fill, features")
local labels = {}
for _, b in ipairs(buttons) do labels[b.text] = (labels[b.text] or 0) + 1 end
H.Equal(labels["Bind"], 20, "one Bind per cell")
H.Equal(labels["Unbind"], 20, "one Unbind per cell")
H.Equal(labels["Clear"], 20, "one Clear per cell")
H.Equal(labels["Default"], 20, "one Default key per cell")
H.Equal(labels["-"], 6 + featureNumbers, "six layout decrement buttons plus the feature numbers")
for text in pairs(labels) do
    H.Check(not text:lower():find("spam") and not text:lower():find("pull") and not text:lower():find("priorit"), "no excluded control: " .. text)
end

-- Key capture through the Bind button.
H.spells[5] = {name = "Five"}
local bind3
for _, b in ipairs(buttons) do if b.text == "Bind" then bind3 = bind3 or {}; bind3[#bind3 + 1] = b end end
bind3[3]:Click()
local capture = _G.ForeverOneButtonKeyCapture
H.Check(capture.shown, "capture shown")
H.Equal(capture.keyboard, true, "capture takes the keyboard")
capture.scripts.OnKeyDown(capture, "LSHIFT")
H.Check(capture.shown, "bare modifier ignored")
H.ctrl = true
capture.scripts.OnKeyDown(capture, "5")
H.ctrl = false
H.Check(not capture.shown, "capture closed")
H.Equal(db.keys[3], "CTRL-5", "captured key stored for cell 3")
bind3[3]:Click()
capture.scripts.OnKeyDown(capture, "ESCAPE")
H.Equal(db.keys[3], "CTRL-5", "escape cancels")
bind3[7]:Click()
capture.scripts.OnMouseWheel(capture, 1)
H.Equal(db.keys[7], "MOUSEWHEELUP", "mouse wheel captured")

-- Entering combat closes the window and any capture.
bind3[8]:Click()
H.inCombat = true
H.Fire("PLAYER_REGEN_DISABLED")
H.Check(not capture.shown and not ns.Options.IsShown(), "closed on combat")
H.inCombat = false
H.Fire("PLAYER_REGEN_ENABLED")

H.Done("test_options_whitelist")
