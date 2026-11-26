-- Targets a spell cannot affect: creature-type rules (Exorcism only on
-- undead and demons) and casts the client refused with "Invalid target" or
-- "Immune", learned per kind of creature. Such a spell is never suggested
-- on that target and its cell is greyed.
local H = dofile("tests/harness/wow.lua")
H.class = "PALADIN"
local ns = H.Boot({}, {})
local T, Q = ns.Targets, ns.Queue
ns.Settings.Get().autoFill = false -- cells chosen by the test
SPELL_FAILED_BAD_TARGETS = "Invalid target"

local SEAL, JUDGEMENT, STRIKE, EXORCISM = 20154, 20271, 679, 879
for id, name in pairs({[SEAL] = "Seal of Righteousness", [JUDGEMENT] = "Judgement",
    [STRIKE] = "Holy Strike", [EXORCISM] = "Exorcism"}) do
    H.known[id] = true
    H.spells[id] = {name = name, icon = name}
end
H.units.player = {level = 20, health = 100, healthMax = 100, power = {[0] = 100}, powerMax = {[0] = 100}}
H.units.target = {health = 100, healthMax = 100, attackable = true,
    guid = "Creature-0-1-2-3-1234-00000001", creatureType = "Beast"}

local function Fresh() H.now = H.now + 1 end
local function Has(id)
    Fresh()
    local s = Q.Build(nil)
    for i = 1, s.count do if s.entries[i].id == id then return true end end
    return false
end

-- Creature types: the localized name, or the ID when the client gives it.
H.Equal(T.CreatureType("target"), 1, "Beast")
H.units.target.creatureTypeID = 6
H.Equal(T.CreatureType("target"), 6, "type ID wins")
H.units.target.creatureTypeID = nil
H.units.target.creatureType = H.Secret()
H.Equal(T.CreatureType("target"), nil, "secret type: unknown")

-- Exorcism: only undead and demons; an unknown type never blocks.
Fresh()
H.Equal(T.Allows(EXORCISM), nil, "unknown type: no opinion")
H.Check(Has(EXORCISM), "unknown type: still suggested")
H.units.target.creatureType = "Beast"
Fresh()
H.Equal(T.Allows(EXORCISM), false, "beast: Exorcism refused")
H.Check(not Has(EXORCISM), "beast: Exorcism not in the queue")
H.Check(Has(JUDGEMENT), "beast: the rest of the list stays")
H.units.target.creatureType = "Undead"
Fresh()
H.Equal(T.Allows(EXORCISM), true, "undead: allowed")
H.Check(Has(EXORCISM), "undead: Exorcism suggested")
H.units.target.creatureType = "Demon"
Fresh()
H.Check(Has(EXORCISM), "demon: Exorcism suggested")
H.Equal(T.Allows(10312), true, "higher ranks follow the rank-1 rule")
H.Equal(T.Allows(STRIKE), nil, "spells without a rule: no opinion")

-- The cell of a spell the target cannot be affected by is greyed.
H.Check(ns.Actions.Assign(1, "spell", EXORCISM), "Exorcism on cell 1")
H.units.target.creatureType = "Beast"
Fresh()
ns.Grid.RefreshCooldowns(true)
local tint = ns.Grid.buttons[1].icon.vertex
H.Check(tint[1] < 1 and tint[1] == tint[3], "Exorcism cell grey on a beast")
H.units.target.creatureType = "Undead"
Fresh()
ns.Grid.RefreshCooldowns(true)
H.Equal(ns.Grid.buttons[1].icon.vertex[1], 1, "Exorcism cell in colour on undead")

-- Learned refusal: Holy Strike refused with "Invalid target" on this kind of
-- creature, in either event order.
H.inCombat = true
H.Fire("UNIT_SPELLCAST_FAILED", "player", "cast-1", STRIKE)
H.Fire("UI_ERROR_MESSAGE", 50, "Invalid target")
Fresh()
H.Equal(T.Allows(STRIKE), false, "refusal learned")
H.Check(not Has(STRIKE), "refused spell not suggested on this creature")
H.units.target.guid = "Creature-0-1-2-3-1234-00000002"
Fresh()
H.Equal(T.Allows(STRIKE), false, "another creature of the same kind (same NPC ID)")
H.units.target.guid = "Creature-0-1-2-3-5678-00000003"
Fresh()
H.Equal(T.Allows(STRIKE), nil, "a different creature: no opinion")
H.Check(Has(STRIKE), "suggested again on it")

H.Fire("UI_ERROR_MESSAGE", 50, "Invalid target")
H.Fire("UNIT_SPELLCAST_FAILED", "player", "cast-2", JUDGEMENT)
Fresh()
H.Equal(T.Allows(JUDGEMENT), false, "error before the failed cast: learned too")

-- On a corpse (or no enemy targeted) "Invalid target" teaches nothing: the
-- creature itself never refused the spell.
H.units.target.dead = true
H.Fire("UNIT_SPELLCAST_FAILED", "player", "cast-5", SEAL)
H.Fire("UI_ERROR_MESSAGE", 50, "Invalid target")
H.units.target.dead = nil
Fresh()
H.Equal(T.Allows(SEAL), nil, "refusal on a corpse not learned")

-- Other failures, or an error long after the cast, teach nothing.
H.Fire("UNIT_SPELLCAST_FAILED", "player", "cast-3", SEAL)
H.Fire("UI_ERROR_MESSAGE", 50, "Not enough mana")
H.now = H.now + 2
H.Fire("UI_ERROR_MESSAGE", 50, "Invalid target")
Fresh()
H.Equal(T.Allows(SEAL), nil, "unrelated or late errors ignored")
H.Fire("UNIT_SPELLCAST_FAILED", "player", "cast-4", H.Secret())
H.Fire("UI_ERROR_MESSAGE", 50, H.Secret())
Fresh()
H.Equal(T.Allows(SEAL), nil, "secret payloads ignored without errors")

-- A stronger version of a buff already up (battleground of 2026-11-22:
-- Battle Shout refused 72 times): held for a while on every target.
H.Fire("UNIT_SPELLCAST_FAILED", "player", "cast-6", SEAL)
H.Fire("UI_ERROR_MESSAGE", 57, "A more powerful spell is already active")
Fresh()
H.Equal(T.Allows(SEAL), false, "stronger aura: held")
H.units.target.guid = "Creature-0-1-2-3-777-0000000009"
H.Fire("PLAYER_TARGET_CHANGED")
Fresh()
H.Equal(T.Allows(SEAL), false, "stronger aura: held on another target too")
H.now = H.now + T.STRONGER_HOLD_SECONDS + 1
Fresh()
H.Equal(T.Allows(SEAL), nil, "stronger aura: asked again after the hold")

-- A refusal message that belongs to something else is not paired with a
-- cast that failed for its own reason in the same moment.
T.Forget()
H.Fire("UNIT_SPELLCAST_FAILED", "player", "cast-a", STRIKE)
H.Fire("UI_ERROR_MESSAGE", 62, "Ability is not ready yet.")
H.Fire("UI_ERROR_MESSAGE", 57, "Invalid target")
Fresh()
H.Equal(T.Allows(STRIKE), nil, "failure explained by its own error: not refused")
T.Forget()
H.Fire("UI_ERROR_MESSAGE", 62, "Ability is not ready yet.")
H.Fire("UNIT_SPELLCAST_FAILED", "player", "cast-b", STRIKE)
H.Fire("UI_ERROR_MESSAGE", 57, "Invalid target")
Fresh()
H.Equal(T.Allows(STRIKE), nil, "error first, then the failure: not refused")
T.Forget()
H.Fire("UI_ERROR_MESSAGE", 57, "Invalid target")
H.now = H.now + 0.3
H.Fire("UNIT_SPELLCAST_FAILED", "player", "cast-c", STRIKE)
Fresh()
H.Equal(T.Allows(STRIKE), nil, "refusal 0.3 s earlier: not paired")
T.Forget()
H.Fire("UNIT_SPELLCAST_FAILED", "player", "cast-d", STRIKE)
H.Fire("UI_ERROR_MESSAGE", 57, "Invalid target")
Fresh()
H.Equal(T.Allows(STRIKE), false, "a real refusal is still learned")

-- A stronger debuff of someone else on the target (battleground of
-- 2026-11-25: Rend refused, then held 60 s on every target): only that
-- target waits, and not past the debuff's time.
T.Forget()
H.spells[STRIKE].harmful = true
H.Fire("UNIT_SPELLCAST_FAILED", "player", "cast-7", STRIKE)
H.Fire("UI_ERROR_MESSAGE", 57, "A more powerful spell is already active")
Fresh()
H.Equal(T.Allows(STRIKE), false, "stronger debuff: held on this target")
H.units.target.guid = "Creature-0-1-2-3-778-0000000010"
H.Fire("PLAYER_TARGET_CHANGED")
Fresh()
H.Equal(T.Allows(STRIKE), nil, "stronger debuff: another target is free")
H.Fire("UNIT_SPELLCAST_FAILED", "player", "cast-8", STRIKE)
H.Fire("UI_ERROR_MESSAGE", 57, "A more powerful spell is already active")
Fresh()
H.Equal(T.Allows(STRIKE), false, "stronger debuff: held again here")
H.now = H.now + T.STRONGER_DEBUFF_SECONDS + 1
Fresh()
H.Equal(T.Allows(STRIKE), nil, "stronger debuff: asked again when it can have run out")
H.spells[STRIKE].harmful = nil

T.Forget()
Fresh()
H.Equal(T.Allows(JUDGEMENT), nil, "forgotten")
H.inCombat = false
H.Done("test_targets")
