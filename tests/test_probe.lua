-- Read-only spellbook probe: records client data, changes nothing.
local H = dofile("tests/harness/wow.lua")
Enum = {SpellBookItemType = {Spell = 1, FutureSpell = 2, PetAction = 3, Flyout = 4}, SpellBookSpellBank = {Player = 0}}
function UnitClass() return "Warrior", "WARRIOR" end
function UnitLevel() return 12 end
function GetBuildInfo() return "1.60.1", "70374" end
local items = {
    {type = 1, id = 6603, name = "Attack", passive = false},
    {type = 1, id = 100, name = "Charge", passive = false},
    {type = 2, id = 1464, name = "Slam", passive = false},
    {type = 1, id = 9116, name = "Shield", passive = true},
    {type = 1, id = H.Secret(), name = "Hidden", passive = false},
}
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 2 end,
    GetSpellBookSkillLineInfo = function(i)
        if i == 1 then return {name = "General", itemIndexOffset = 0, numSpellBookItems = 1} end
        return {name = "Arms", itemIndexOffset = 1, numSpellBookItems = 4}
    end,
    GetSpellBookItemInfo = function(index, bank)
        assert(bank == 0, "player bank")
        local it = items[index]
        return {name = it.name, isPassive = it.passive, spellID = it.id, itemType = it.type}
    end,
    GetSpellBookItemType = function(index) local it = items[index]; return it.type, it.id, it.id end,
}
function IsSpellKnown(id) return id ~= 1464 end
local ns = H.Boot(nil, nil)
local rotation = LibStub:NewLibrary("JustAC-RotationImport", 1)
function rotation.IsClassAbility(id) return id == 1464 end
local spellDB = LibStub:NewLibrary("JustAC-SpellDB", 1)
function spellDB.GetGapCloserDefaults() return {100, 20252} end

local cellsBefore = next(ForeverOneButtonCharDB.cells)
ns.Commands.Handle("probe spellbook")
local probe = ForeverOneButtonLog.probe
H.Equal(#probe, 6, "header + 5 items")
H.Equal(probe[1], "header|WARRIOR|1.60.1|level 12|0.2.0", "header")
H.Equal(probe[2], "1|General|1|Spell|6603|6603|Attack|false|true|-", "learned spell")
H.Equal(probe[3], "2|Arms|2|Spell|100|100|Charge|false|true|gap", "gap closer marked")
H.Equal(probe[4], "2|Arms|3|FutureSpell|1464|1464|Slam|false|false|class", "future spell and JustAC class ability")
H.Equal(probe[5], "2|Arms|4|Spell|9116|9116|Shield|true|true|-", "passive marked")
H.Check(probe[6]:find("|secret|secret|Hidden|"), "secret ID written as secret")
H.Equal(next(ForeverOneButtonCharDB.cells), cellsBefore, "no cell changed")
H.Equal(next(H.overrideBindings), nil, "no binding changed")

-- Kept across reload so the file on disk keeps it.
local saved = ForeverOneButtonLog
ns.Diagnostics.Load()
H.Equal(#ForeverOneButtonLog.probe, 6, "probe survives Load")
H.Done("test_probe")
