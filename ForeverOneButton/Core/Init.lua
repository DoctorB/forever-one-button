-- Forever One Button: namespace, constants and secret-value helpers.
-- Every module receives the private addon table from the client as `...`;
-- nothing here is exported to _G except the SavedVariables and frame names.
local ADDON_NAME, ns = ...

ns.NAME = "ForeverOneButton"
ns.TITLE = "Forever One Button"
ns.VERSION = "0.2.0"

-- Diagnostic Pixel Protocol v3 (HCOneButton) encodes action slots 1..20 only:
-- R = slot * 12 must stay <= 240 (HCOneButton README, "For action slots 1-20").
-- The grid therefore never exposes more than 20 cells.
ns.MAX_SLOTS = 20

-- Snapshot states published by the JustAC adapter.
ns.STATUS = {
    OK = "ok",                 -- queue read; may still be empty
    MISSING = "missing",       -- JustAC-SpellQueue not registered (yet)
    NO_METHOD = "no_method",   -- library present without GetCurrentSpellQueue
    ERROR = "error",           -- the call raised an error
    INVALID = "invalid",       -- result does not match the verified contract
    UNREADABLE = "unreadable", -- result table cannot be accessed (secret)
}

-- Queue entry kinds, as defined by JustAC SpellQueue.lua @ 431e9a2:
-- positive = spell ID, negative = -itemID, WAIT_SENTINEL = deliberate wait.
ns.ENTRY = {
    SPELL = "spell",
    ITEM = "item",
    WAIT = "wait",
    UNREADABLE = "unreadable",
}

local issecretvalue = issecretvalue

-- True only when the client says the value is secret. `issecretvalue` is
-- verified present on Forever 1.60.1.70374 (forever-chatguard compatibility
-- record); absent outside Forever, where nothing is secret.
function ns.IsSecret(value)
    if issecretvalue == nil then return false end
    return issecretvalue(value) == true
end

-- A value that is present and safe to compare or index with.
function ns.Readable(value)
    if ns.IsSecret(value) then return false end
    return value ~= nil
end

-- Calls a client API and returns its first result only when it is readable.
function ns.SafeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if not ok or not ns.Readable(value) then return nil end
    return value
end

function ns.InCombat()
    return InCombatLockdown ~= nil and InCombatLockdown() == true
end

function ns.Print(message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff4fc3f7Forever One Button|r: " .. tostring(message))
    end
end

-- Spell/item presentation helpers. Every client call is guarded: a missing
-- API or a secret result simply yields nil.
function ns.SpellName(spellID)
    if not C_Spell then return nil end
    local name = ns.SafeCall(C_Spell.GetSpellName, spellID)
    if type(name) == "string" then return name end
    return nil
end

function ns.SpellIcon(spellID)
    if not C_Spell then return nil end
    return ns.SafeCall(C_Spell.GetSpellTexture, spellID)
end

function ns.ItemName(itemID)
    if not C_Item then return nil end
    local name = ns.SafeCall(C_Item.GetItemNameByID, itemID)
    if type(name) == "string" then return name end
    return nil
end

function ns.ItemIcon(itemID)
    if not C_Item then return nil end
    return ns.SafeCall(C_Item.GetItemIconByID, itemID)
end
