-- SPDX-License-Identifier: GPL-3.0-or-later
-- Copyright (c) 2026 DoctorB
--
-- Forever One Button: spells that only affect some creature types. Keys are
-- rank-1 spell IDs; values the creature type IDs the spell can affect
-- (1 Beast, 2 Dragonkin, 3 Demon, 4 Elemental, 6 Undead, 7 Humanoid,
-- 8 Critter). The client reports these spells as usable on any target and
-- refuses them only at cast time, so without this table they would be
-- suggested on targets they cannot affect.
-- Written for Forever One Button.
local _, ns = ...
ns.Data = ns.Data or {}

ns.Data.TargetRules = {
    creatureTypes = {
        [879] = {6, 3},     -- Exorcism: undead, demons
        [2812] = {6, 3},    -- Holy Wrath: undead, demons
        [2878] = {6},       -- Turn Undead
        [9484] = {6},       -- Shackle Undead
        [710] = {3, 4},     -- Banish: demons, elementals
        [1098] = {3},       -- Enslave Demon
        [2637] = {1, 2},    -- Hibernate: beasts, dragonkin
        [1513] = {1},       -- Scare Beast
        [2908] = {1},       -- Soothe Animal
        [118] = {7, 1, 8},  -- Polymorph: humanoids, beasts, critters
        [6770] = {7},       -- Sap: humanoids
    },
}
