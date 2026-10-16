-- Forever One Button: read-only spellbook probe (/fob probe spellbook).
--
-- Records the character's whole spellbook as the client reports it, so the
-- per-class cell layout can be derived from client data instead of invented
-- tables. Nothing is changed, cast or bound. Output goes to
-- ForeverOneButtonLog.probe (written to disk on /reload or logout), one string
-- per spellbook item:
--   "<line>|<line name>|<index>|<item type>|<spell ID>|<action ID>|<name>|<passive>|<known>|<data>"
-- <data>: "gap" for a gap closer of the class, "class" for a class ability of
-- the imported data (Data/Rotations.lua classAbilities, any rank), "-" otherwise. Secret or missing values are written as "secret" / "none".
local ADDON_NAME, ns = ...

local Probe = {}
ns.Probe = Probe

local function Text(value)
    if ns.IsSecret(value) then return "secret" end
    if value == nil then return "none" end
    return (tostring(value):gsub("|", "/"))
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c
end

local function ItemTypeName(itemType)
    if ns.IsSecret(itemType) then return "secret" end
    local names = Enum and Enum.SpellBookItemType
    if type(names) == "table" then
        for name, value in pairs(names) do
            if value == itemType then return name end
        end
    end
    return Text(itemType)
end

-- /fob probe frames: which Blizzard bottom-bar frames exist on this client
-- and their parents, for the "hide Blizzard bar" option.
function Probe.Frames()
    local lines = {}
    for _, entry in ipairs(ns.BlizzardBar.Found()) do
        local name = entry:gsub("%(kept%)$", "")
        local frame = _G[name]
        local parent = frame and frame.GetParent and Call(frame.GetParent, frame)
        local parentName = parent and parent.GetName and Call(parent.GetName, parent)
        lines[#lines + 1] = string.format("%s|parent %s|shown %s", entry, Text(parentName),
            Text(frame and frame.IsShown and Call(frame.IsShown, frame)))
    end
    -- Children of the main bar, and bar-like children of UIParent, to find
    -- art that is not in the candidate list.
    local function Children(frame)
        if type(frame) ~= "table" or type(frame.GetChildren) ~= "function" then return {} end
        local result = {pcall(frame.GetChildren, frame)}
        if not result[1] then return {} end
        table.remove(result, 1)
        return result
    end
    local function Describe(prefix, child)
        local name = child.GetName and Call(child.GetName, child)
        local kind = child.GetObjectType and Call(child.GetObjectType, child)
        local shown = child.IsShown and Call(child.IsShown, child)
        local alpha = child.GetAlpha and Call(child.GetAlpha, child)
        lines[#lines + 1] = string.format("%s|%s|%s|shown %s|alpha %s", prefix, Text(name), Text(kind),
            Text(shown), Text(alpha))
    end
    for _, barName in ipairs({"MainActionBar", "MainMenuBar"}) do
        for _, child in ipairs(Children(_G[barName])) do Describe("child of " .. barName, child) end
    end
    for _, child in ipairs(Children(UIParent)) do
        local name = child.GetName and Call(child.GetName, child)
        if type(name) == "string" and (name:find("Bar") or name:find("Action") or name:find("Menu")) then
            Describe("UIParent child", child)
        end
    end
    ForeverOneButtonLog.probeFrames = lines
    return true, string.format("frame probe: %d frames found; /reload or log out to write them to disk", #lines)
end

function Probe.Spellbook()
    if not C_SpellBook or type(C_SpellBook.GetNumSpellBookSkillLines) ~= "function" then
        return false, "C_SpellBook not available"
    end
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local lines = {}
    local _, class = Call(UnitClass, "player")
    local gap, ability = {}, {}
    local readableClass = ns.Readable(class) and class or nil
    for _, id in ipairs(readableClass and ns.Data.Defaults.gapClosers[readableClass] or {}) do gap[id] = true end
    for _, id in ipairs(readableClass and ns.Data.Rotations.classAbilities[readableClass] or {}) do ability[id] = true end
    local build = Call(GetBuildInfo)
    lines[#lines + 1] = string.format("header|%s|%s|level %s|%s", Text(class), Text(build),
        Text(Call(UnitLevel, "player")), Text(ns.VERSION))
    local numLines = Call(C_SpellBook.GetNumSpellBookSkillLines) or 0
    if ns.IsSecret(numLines) then numLines = 0 end
    for lineIndex = 1, numLines do
        local info = Call(C_SpellBook.GetSpellBookSkillLineInfo, lineIndex)
        if type(info) == "table" and not ns.IsSecret(info.itemIndexOffset) and not ns.IsSecret(info.numSpellBookItems) then
            local first = (info.itemIndexOffset or 0) + 1
            local last = (info.itemIndexOffset or 0) + (info.numSpellBookItems or 0)
            for index = first, last do
                local item = Call(C_SpellBook.GetSpellBookItemInfo, index, bank)
                local itemType, actionID, spellID = Call(C_SpellBook.GetSpellBookItemType, index, bank)
                local name, passive = nil, nil
                if type(item) == "table" then
                    name, passive = item.name, item.isPassive
                    spellID = spellID or item.spellID
                    actionID = actionID or item.actionID
                    itemType = itemType or item.itemType
                end
                local known, data = nil, "-"
                if ns.Readable(spellID) and type(spellID) == "number" then
                    known = Call(IsSpellKnown, spellID)
                    local first = ns.Ranks.Base(spellID)
                    if gap[first] then data = "gap"
                    elseif ability[first] then data = "class" end
                end
                lines[#lines + 1] = table.concat({lineIndex, Text(info.name), index, ItemTypeName(itemType),
                    Text(spellID), Text(actionID), Text(name), Text(passive), Text(known), data}, "|")
            end
        end
    end
    ForeverOneButtonLog.probe = lines
    return true, string.format("spellbook probe: %d lines saved; /reload or log out to write them to disk", #lines)
end
