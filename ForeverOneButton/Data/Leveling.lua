-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (c) 2026 DoctorB
--
-- Forever One Button: leveling priority lists (levels 1-59), one per class
-- talent tree, in the format of Data/Rotations.lua (entries {id, gates},
-- rank-1 IDs, contexts st / aoe). The imported lists model level-60
-- characters; these follow the abilities a character learns while leveling.
-- An entry the character does not know yet is skipped, so a list grows with
-- the character. `base` is used for a tree without its own list.
-- Written for Forever One Button; IDs are checked against the class
-- abilities of the imported data (tests/test_leveling.lua).
local _, ns = ...
ns.Data = ns.Data or {}

-- Gate helpers: plain tables, as in the imported data.
local function buffMissing(id, dur) return {t = "buff", id = id, dur = dur, neg = true} end
local function dot(id) return {t = "dot", id = id} end
local function rageAtLeast(n) return {t = "power", res = "rage", op = ">=", n = n} end
local function rageBelow(n) return {t = "power", res = "rage", op = "<", n = n} end
local function manaAtLeast(pct) return {t = "power", res = "mana", op = ">=", n = pct, ispct = true} end
local function manaBelow(pct) return {t = "power", res = "mana", op = "<", n = pct, ispct = true} end
local function energyAtLeast(n) return {t = "power", res = "energy", op = ">=", n = n} end
local function targetsAtLeast(n) return {t = "targets", op = ">=", n = n} end
local function execute(pct) return {t = "execute", op = "<", pct = pct or 20} end
local function healthAbove(pct) return {t = "health", op = ">", pct = pct} end
local function healthBelow(pct) return {t = "health", op = "<", pct = pct} end
local function combo(op, n) return {t = "resource", res = "combo_points", op = op, n = n} end
local function unknown(id) return {t = "known", id = id, neg = true} end
local function stacksBelow(id, n) return {t = "stack", id = id, op = "<", n = n, tgt = true} end
local function near(yards) return {t = "near", n = yards} end
local function totemDown(slot) return {t = "totem", slot = slot, neg = true} end
local function onCooldown(id) return {t = "cd", id = id, neg = true} end
local function stealthed() return {t = "stealth"} end
local function any(...) return {t = "any", g = {...}} end
local function all(...) return {t = "all", g = {...}} end
local function e(id, ...) return {id = id, gates = {...}} end

-- Warrior ----------------------------------------------------------------
local BATTLE_SHOUT = e(6673, buffMissing(6673, 120))
local BLOODRAGE = e(2687, rageBelow(30), healthAbove(50))
-- Heroic Strike: early, whenever affordable (it comes after Rend, Sunder and
-- Thunder Clap in the lists); once Bloodthirst or Mortal Strike is known,
-- only the excess. In game (2026-10-16, level 13) a 20-rage threshold left
-- the queue waiting with 15-19 rage.
local HEROIC_STRIKE = e(78, any(all(unknown(23881), unknown(12294)), rageAtLeast(45)))
local WARRIOR_AOE_HEAD = {
    BATTLE_SHOUT, BLOODRAGE,
    e(6343, targetsAtLeast(2)),           -- Thunder Clap
    e(1160, targetsAtLeast(2), dot(1160)), -- Demoralizing Shout
    e(1680),                               -- Whirlwind
    e(845, rageAtLeast(20)),               -- Cleave
}
local warrior = {
    arms = {
        st = {
            BATTLE_SHOUT, BLOODRAGE,
            e(5308, execute()),                -- Execute
            e(7384),                           -- Overpower (after a dodge)
            e(12294),                          -- Mortal Strike
            e(772, dot(772)),                  -- Rend
            e(7386, stacksBelow(7386, 1)),     -- Sunder Armor, once
            e(1680, targetsAtLeast(2)),        -- Whirlwind
            e(6343, targetsAtLeast(2)),        -- Thunder Clap
            e(845, targetsAtLeast(2), rageAtLeast(30)), -- Cleave
            HEROIC_STRIKE,
            e(1240193, rageAtLeast(40)),       -- Slam
            e(2457, buffMissing(2457)),        -- Battle Stance
        },
        aoe = {
            WARRIOR_AOE_HEAD[1], WARRIOR_AOE_HEAD[2], WARRIOR_AOE_HEAD[3], WARRIOR_AOE_HEAD[4],
            e(5308, execute()), e(12294), WARRIOR_AOE_HEAD[5], WARRIOR_AOE_HEAD[6],
            e(7384), e(772, dot(772)), HEROIC_STRIKE,
            e(2457, buffMissing(2457)),
        },
    },
    fury = {
        st = {
            BATTLE_SHOUT, BLOODRAGE,
            e(12328),                          -- Death Wish
            e(1719),                           -- Recklessness (Berserker Stance)
            e(5308, execute()),                -- Execute
            e(23881),                          -- Bloodthirst
            e(1680, onCooldown(23881)),        -- Whirlwind while Bloodthirst cools down
            e(7384),                           -- Overpower (after a dodge, Battle Stance)
            e(772, dot(772)),                  -- Rend
            e(7386, stacksBelow(7386, 1)),     -- Sunder Armor, once
            e(6343, targetsAtLeast(2)),        -- Thunder Clap
            e(845, targetsAtLeast(2), rageAtLeast(30)), -- Cleave
            HEROIC_STRIKE,
            e(2458, buffMissing(2458)),        -- Berserker Stance (Battle Stance until learned)
        },
        aoe = {
            WARRIOR_AOE_HEAD[1], WARRIOR_AOE_HEAD[2], WARRIOR_AOE_HEAD[3], WARRIOR_AOE_HEAD[4],
            e(12328), e(1719),                 -- Death Wish, Recklessness
            e(5308, execute()), e(23881), WARRIOR_AOE_HEAD[5], WARRIOR_AOE_HEAD[6],
            e(772, dot(772)), HEROIC_STRIKE,
            e(2458, buffMissing(2458)),
        },
    },
    protection = {
        st = {
            BATTLE_SHOUT, BLOODRAGE,
            e(23922),                          -- Shield Slam
            e(6572),                           -- Revenge (after a block, dodge or parry)
            e(7386, stacksBelow(7386, 5)),     -- Sunder Armor up to 5
            e(1160, dot(1160)),                -- Demoralizing Shout
            e(6343, targetsAtLeast(2)),        -- Thunder Clap
            e(845, targetsAtLeast(2), rageAtLeast(30)), -- Cleave
            e(5308, execute()),                -- Execute
            e(78, rageAtLeast(40)),            -- Heroic Strike with spare rage
            e(71, buffMissing(71)),            -- Defensive Stance
        },
        aoe = {
            BATTLE_SHOUT, BLOODRAGE,
            e(6343),                           -- Thunder Clap
            e(1160, dot(1160)),                -- Demoralizing Shout
            e(6572), e(23922),
            e(845, rageAtLeast(25)),           -- Cleave
            e(7386, stacksBelow(7386, 5)),
            e(71, buffMissing(71)),
        },
    },
}

-- Rogue --------------------------------------------------------------------
local SLICE_AND_DICE = e(5171, buffMissing(5171, 12), combo(">=", 1))
local EVISCERATE = e(2098, any(combo(">=", 5), all(combo(">=", 2), execute(20))))
local rogue = {
    base = {
        st = {
            e(1833, stealthed()),              -- Cheap Shot from stealth
            SLICE_AND_DICE, EVISCERATE,
            e(13750),                          -- Adrenaline Rush
            e(13877, targetsAtLeast(2)),       -- Blade Flurry
            e(1752, energyAtLeast(40)),        -- Sinister Strike
        },
    },
    assassination = {
        st = {
            e(703, stealthed()),               -- Garrote from stealth
            SLICE_AND_DICE,
            e(14177, combo(">=", 4)),          -- Cold Blood before a finisher
            EVISCERATE,
            e(1310707),                        -- Mutilate
            e(1752, energyAtLeast(40)),        -- Sinister Strike until Mutilate
        },
    },
    subtlety = {
        st = {
            e(8676, stealthed()),              -- Ambush from stealth
            e(14183, stealthed()),             -- Premeditation
            SLICE_AND_DICE, EVISCERATE,
            e(16511),                          -- Hemorrhage
            e(1752, energyAtLeast(40)),        -- Sinister Strike until Hemorrhage
        },
    },
}

-- Hunter -------------------------------------------------------------------
-- Ranged shots keep their minimum range and melee strikes their reach: the
-- client's range answer holds each back where it cannot hit.
local HUNTER_ST = {
    e(1130, dot(1130)),                        -- Hunter's Mark
    e(3045),                                   -- Rapid Fire
    e(19574),                                  -- Bestial Wrath (with a pet)
    e(1495),                                   -- Mongoose Bite (after a dodge)
    e(2973),                                   -- Raptor Strike in melee
    e(1978, dot(1978), manaAtLeast(20)),       -- Serpent Sting
    e(19434, manaAtLeast(30)),                 -- Aimed Shot
    e(3044, manaAtLeast(40)),                  -- Arcane Shot
    e(2643, any(targetsAtLeast(2), manaAtLeast(70))), -- Multi-Shot
}
local hunter = {
    base = {
        st = HUNTER_ST,
        aoe = {
            e(1130, dot(1130)),
            e(1510, targetsAtLeast(3), manaAtLeast(40)), -- Volley
            e(2643),                           -- Multi-Shot
            e(2973), e(1495),
            e(1978, dot(1978), manaAtLeast(30)),
        },
    },
}

-- Paladin ------------------------------------------------------------------
-- A seal lasts 30 s; Judgement spends it, then the seal comes back.
local PALADIN_SEALS = {
    e(20375, buffMissing(20375, 30)),                  -- Seal of Command
    e(20154, unknown(20375), buffMissing(20154, 30)),  -- Seal of Righteousness until then
}
local function PaladinList(extra)
    local list = {PALADIN_SEALS[1], PALADIN_SEALS[2],
        e(20271),                              -- Judgement
        e(24275, execute()),                   -- Hammer of Wrath
    }
    for _, entry in ipairs(extra) do list[#list + 1] = entry end
    list[#list + 1] = e(879, manaAtLeast(40))  -- Exorcism (undead and demons)
    list[#list + 1] = e(26573, targetsAtLeast(2), manaAtLeast(40)) -- Consecration
    return list
end
local paladin = {
    base = {st = PaladinList({e(679)})},                                        -- Holy Strike
    holy = {st = PaladinList({e(1311606, manaAtLeast(40)), e(679)})},           -- Holy Shock
    protection = {st = PaladinList({e(20925, buffMissing(20925, 10)), e(407632), e(679)})}, -- Holy Shield, Hammer of the Righteous
    retribution = {st = PaladinList({e(679)})},
}

-- Shaman -------------------------------------------------------------------
local shaman = {
    base = {
        st = {
            e(8050, dot(8050)),                -- Flame Shock
            e(408490),                         -- Lava Burst
            e(421, targetsAtLeast(2), manaAtLeast(30)), -- Chain Lightning
            e(8042, manaAtLeast(50)),          -- Earth Shock
            e(403),                            -- Lightning Bolt
        },
        aoe = {
            e(408341, near(10)),               -- Fire Nova
            e(8190, totemDown(1), near(10)),   -- Magma Totem
            e(421),                            -- Chain Lightning
            e(8050, dot(8050)),
            e(403),
        },
    },
    enhancement = {
        st = {
            e(324, buffMissing(324, 600)),     -- Lightning Shield
            e(17364),                          -- Stormstrike
            e(8050, dot(8050), manaAtLeast(25)), -- Flame Shock
            e(8042, manaAtLeast(40)),          -- Earth Shock
            e(3599, totemDown(1), manaAtLeast(30)), -- Searing Totem
            e(8075, totemDown(2), manaAtLeast(50)), -- Strength of Earth Totem
        },
        aoe = {
            e(324, buffMissing(324, 600)),
            e(408341, near(10)),               -- Fire Nova
            e(8190, totemDown(1), near(10)),   -- Magma Totem
            e(17364),
            e(8050, dot(8050)),
        },
    },
}

-- Priest -------------------------------------------------------------------
-- The wand (Shoot) is the filler at the end, used when mana runs short.
local priest = {
    base = {
        st = {
            e(10060),                          -- Power Infusion
            e(589, dot(589)),                  -- Shadow Word: Pain
            e(14914, manaAtLeast(40)),         -- Holy Fire
            e(402174, manaAtLeast(30)),        -- Penance
            e(8092, manaAtLeast(30)),          -- Mind Blast
            e(1309595, execute(20)),           -- Shadow Word: Death
            e(585, manaAtLeast(50)),           -- Smite
            e(5019),                           -- Shoot (wand)
        },
        aoe = {
            e(15237, targetsAtLeast(3), near(10), manaAtLeast(40)), -- Holy Nova
            e(589, dot(589)),
            e(8092, manaAtLeast(30)),
            e(5019),
        },
    },
    shadow = {
        st = {
            e(589, dot(589)),                  -- Shadow Word: Pain
            e(2944),                           -- Devouring Plague
            e(8092, manaAtLeast(25)),          -- Mind Blast
            e(1309595, execute(20)),           -- Shadow Word: Death
            e(15407, manaAtLeast(25)),         -- Mind Flay
            e(585, unknown(15407), manaAtLeast(50)), -- Smite until Mind Flay
            e(5019),                           -- Shoot (wand)
        },
    },
}

-- Mage ---------------------------------------------------------------------
local MAGE_AOE = {
    e(122, near(8), targetsAtLeast(2)),        -- Frost Nova
    e(11113, near(10), targetsAtLeast(2)),     -- Blast Wave
    e(120, near(10), targetsAtLeast(2)),       -- Cone of Cold
    e(1449, near(10), targetsAtLeast(3)),      -- Arcane Explosion
    e(10, targetsAtLeast(3)),                  -- Blizzard
    e(2120, targetsAtLeast(3)),                -- Flamestrike
}
local function MageList(spells)
    local list = {e(12051, manaBelow(15))}     -- Evocation
    for _, entry in ipairs(spells) do list[#list + 1] = entry end
    list[#list + 1] = e(2136, manaAtLeast(30)) -- Fire Blast
    list[#list + 1] = e(5019)                  -- Shoot (wand)
    return list
end
local mage = {
    base = {st = MageList({e(116, manaAtLeast(10))}), aoe = MAGE_AOE},          -- Frostbolt
    arcane = {
        st = MageList({e(12042), e(12043),     -- Arcane Power, Presence of Mind
            e(400574, manaAtLeast(40)), e(5143, manaAtLeast(25)), e(116, manaAtLeast(10))}), -- Arcane Blast, Arcane Missiles
        aoe = MAGE_AOE,
    },
    fire = {st = MageList({e(11129), e(133, manaAtLeast(10))}), aoe = MAGE_AOE}, -- Combustion, Fireball
    frost = {st = MageList({e(116, manaAtLeast(10)), e(1312002, manaAtLeast(20))}), aoe = MAGE_AOE}, -- Frostbolt, Ice Lance
}

-- Warlock ------------------------------------------------------------------
local LIFE_TAP = e(1454, manaBelow(30), healthAbove(60))
local warlock = {
    base = {
        st = {
            LIFE_TAP,
            e(980, dot(980)),                  -- Bane of Agony
            e(172, dot(172)),                  -- Corruption
            e(18265, dot(18265)),              -- Siphon Life
            e(348, dot(348)),                  -- Immolate
            e(689, healthBelow(50), manaAtLeast(20)), -- Drain Life when hurt
            e(1120, execute(20)),              -- Drain Soul to finish
            e(686, manaAtLeast(25)),           -- Shadow Bolt
            e(5019),                           -- Shoot (wand)
        },
        aoe = {
            LIFE_TAP,
            e(1949, near(10), healthAbove(60), targetsAtLeast(3)), -- Hellfire
            e(5740, targetsAtLeast(3)),        -- Rain of Fire
            e(980, dot(980)), e(172, dot(172)),
            e(5019),
        },
    },
    destruction = {
        st = {
            LIFE_TAP,
            e(348, dot(348)),                  -- Immolate
            e(1293817),                        -- Conflagrate
            e(17877, execute(20)),             -- Shadowburn
            e(172, dot(172)),                  -- Corruption
            e(686, manaAtLeast(20)),           -- Shadow Bolt
            e(5019),
        },
    },
}

-- Druid --------------------------------------------------------------------
local DRUID_CASTER = {
    st = {
        e(8921, dot(8921)),                    -- Moonfire
        e(5570, dot(5570)),                    -- Insect Swarm
        e(5176),                               -- Wrath
    },
    aoe = {
        e(16914, targetsAtLeast(3)),           -- Hurricane
        e(8921, dot(8921)), e(5570, dot(5570)), e(5176),
    },
}
local druid = {
    base = DRUID_CASTER,
    balance = {
        st = {
            e(24858, buffMissing(24858)),      -- Moonkin Form
            DRUID_CASTER.st[1], DRUID_CASTER.st[2],
            e(2912, manaAtLeast(60)),          -- Starfire with mana to spare
            e(5176),
        },
        aoe = DRUID_CASTER.aoe,
    },
    feral = {
        st = {
            e(768, buffMissing(768)),          -- Cat Form
            e(6785, stealthed()),              -- Ravage from Prowl
            e(1822, dot(1822)),                -- Rake
            e(1079, combo(">=", 5), dot(1079)), -- Rip
            e(22568, combo(">=", 5)),          -- Ferocious Bite
            e(407995),                         -- Primal Bite
            e(5221),                           -- Shred
            e(1082),                           -- Claw
        },
    },
    feral_bear = {
        st = {
            e(99, dot(99)),                    -- Demoralizing Roar
            e(414644, stacksBelow(414644, 5)), -- Lacerate
            e(779, targetsAtLeast(2)),         -- Swipe
            e(6807, rageAtLeast(15)),          -- Maul
        },
        aoe = {
            e(99, dot(99)), e(779), e(6807, rageAtLeast(25)),
        },
    },
}

ns.Data.Leveling = {
    WARRIOR = warrior, ROGUE = rogue, HUNTER = hunter, PALADIN = paladin, SHAMAN = shaman,
    PRIEST = priest, MAGE = mage, WARLOCK = warlock, DRUID = druid,
}
