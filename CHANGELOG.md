# Changelog

## 1.2.1 - 2026-11-14

### New

- **Rogues, openers from stealth.** In stealth the addon suggests Garrote,
  or Cheap Shot when you are in front of the target and Garrote is refused.
- **Rogues:** Expose Armor on elites and bosses, at 5 combo points, once
  while it lasts. Gouge now gets a button next to Kick (not with the
  "Kick only" interrupt setting).

### Changed

- **Rogues while leveling:** Slice and Dice waits for 3 combo points on a
  target above half health, and Eviscerate spends your points before the
  target dies (5 points, 3 below 35% health, 2 below 20%). Fewer Slice and
  Dice are wasted in short fights.

## 1.2.0 - 2026-11-11

### New

- **Poisons, stones and oils with one key.** No more picking the item and
  then clicking your weapon: press one key and the right coating goes on
  the right weapon.
  - To set it up: Game Menu > Options > Key Bindings > AddOns >
    Forever One Button > **Apply the next weapon coating**, and pick a key.
  - Press it out of combat. Each press applies one coating; wait until it
    finishes, then press again for the next one. When everything is on,
    the key does nothing.
  - You can also just click the icon in the reminder row, as before.
- **Rogues:** a poison on each weapon. Instant Poison on the main hand and
  Deadly Poison on the off hand, unless you choose others on the
  *Reminders* page of the options. A poison and a sharpening stone can sit
  on the same weapon, so you are reminded of both.
- Stones and oils are now reminded for your off-hand weapon too.
- Coatings are reminded again shortly before they run out, not only once
  they are gone.

## 1.1.9 - 2026-11-09

### New

- When you come back from being away (AFK), the addon now reminds you about
  a log that is ready to send, wherever you are, not only in an inn or a
  city.
- If the log is off, coming back from being away may show a short, friendly
  question: would you like to help improve the addon? Click
  **[Turn on the log]** or **[No thanks]**. It asks at most three times, a
  week apart, and never again once you answer. The addon works exactly the
  same either way.

## 1.1.8 - 2026-11-08

### Fixed

- Warrior with Protection talents, while leveling: the button no longer sits
  idle for half of every fight. Heroic Strike waited for 40 rage, and at low
  level there was nothing else to press in the meantime. Now Heroic Strike
  is suggested as soon as you can afford it, until you learn Shield Slam;
  from then on it again waits for spare rage, so Shield Slam and Revenge
  keep theirs. Rend is now part of the list too, after Sunder Armor.
  In game, at level 11, the time the button waited for Heroic Strike went
  from about half of each fight to none.

### Thank you

This fix came straight from a shared diagnostic log. If you would like to
help in the same way, type `/fob log on`, play as usual, then click the
green **[Share the log]** link that appears in chat (or type `/fob share`)
and paste the line at <https://trace.lucabottani.dev>. Your character and
realm names are removed first, and nothing is sent unless you paste it
there. The addon works the same with the log off: helping is entirely up to
you, and every log is welcome.

## 1.1.7 - 2026-11-08

### You can help make Forever One Button better

Every class, level and situation plays a little differently, and we can
only test so many of them ourselves. If the addon ever suggests the wrong spell, or
the right one at the wrong moment, the quickest way to get it fixed is a
diagnostic log from your own play. If you would like to help, it takes a
minute:

1. Type `/fob log on` and play as usual. The log is off until you do this.
2. After about 30 minutes of play, when you are in an inn or a city, a chat
   line appears with a green **[Share the log]** link. (You can also type
   `/fob share` at any time.)
3. Click the link, copy the line in the window (Ctrl+A, Ctrl+C), paste it at
   <https://trace.lucabottani.dev> and press Send. Back in game, click
   **I sent it**.

What you send: the spells and items the addon suggested and you cast, the
game's own messages (such as "Out of range"), timings, your class, level,
language and the addon version. Your character and realm names are removed
before you see the line, and nothing leaves your computer unless you paste
it on that page. The page does not store your IP address, logs are read only
to improve the addon and are deleted after 180 days.

You do not have to do anything: the addon works the same with the log off.
But every log helps, and the fix below came straight from one. Thank you!

### Fixed

- Spells pressed during the global cooldown are no longer replaced by the
  next suggestion. The game queues a spell pressed during the global
  cooldown; the addon then moved on to the next spell at once, and pressing
  that one made the game cast it instead. With a Rogue, Sinister Strike went
  off in place of Slice and Dice about 4 times in 10, with "Another action
  is in progress" errors. Now the spells below a queued spell wait for it, at
  most 1.5 seconds. Heroic Strike and the other attacks on the next swing
  are not affected.

### Diagnostic log

- Each change of the suggestions records, for every spell, whether it is
  ready or why it waits (cooldown, not enough energy, rage or mana, its
  condition, range...). This is what showed the problem above.
- `/fob share` and the chat reminder are new (see above). After you click
  **I sent it**, the shared part of the log is removed; **Close** keeps it
  so you can try again.

## 1.1.6 - 2026-11-07

- Warrior, leveling lists (Arms and Fury): Hamstring is suggested first when
  the target runs away in fear, so it cannot come back with friends. Once
  per flight: it is not suggested again for 10 seconds.
- Diagnostic log (`/fob log on`): it now holds 20,000 entries instead of
  5,000, enough for a 2-3 hour session (5,000 held about 76 minutes of
  leveling). It also records why a press was refused by the game (target
  not in front, out of range, not enough energy...) and failed casts, and
  `scripts/analyze_log.py` lists them. Suggestions and the pixel are
  unchanged.

## 1.1.5 - 2026-11-06

- No more unwanted target switch at the end of a fight. With a pixel reader,
  the last key presses could reach the game just after the target died; the
  game then picked the nearest enemy by itself. Now:
  - Heroic Strike (and other attacks on the next swing: Cleave, Maul,
    Raptor Strike) is no longer suggested again once it is queued; the next
    ready spell takes position 1 until the swing.
  - The pixel turns black when the suggestion is an attack and no living
    enemy is targeted (dead target, no target, friendly target). Spells on
    yourself (shouts, seals, stances, the emergency heal) are still shown.
    The grid status line says "no enemy targeted".
  - The pixel follows a target change or a target's death at once instead
    of at the next refresh.

## 1.1.4 - 2026-11-05

- Live WoW Forever client: the installation instructions point to the live
  client folder `World of Warcraft\_forever_\Interface\AddOns\` instead of
  the beta folder. Suggestions, bindings and the pixel output are unchanged.

## 1.1.3 - 2026-10-21

- Pixel reader: the short black after each cast of the suggested spell now
  stays on screen for at least 60 ms, as the protocol says. It was timed from
  the start of the game frame, while the cast arrives later in the frame, so
  it could last only 40-58 ms and a pixel reader could miss it. Colours and
  timings are otherwise unchanged.

## 1.1.2 - 2026-10-21

- The addon has its own icon in the AddOns list instead of the question mark.

## 1.1.1 - 2026-10-20

- Spells that only work on some creatures are no longer suggested on the
  others: Exorcism and Holy Wrath only on undead and demons, Turn Undead
  and Shackle Undead on undead, Banish, Enslave Demon, Hibernate, Scare
  Beast, Soothe Animal, Polymorph and Sap on their own creature types.
  Their cell turns grey on a target they cannot affect.
- When the game refuses a cast with "Invalid target" or "Immune", that spell
  is no longer suggested against that kind of creature until the next
  /reload. A hit that lands as "Immune" after a successful cast is not
  detected (the combat log is not available to addons on Forever).

## 1.1.0 - 2026-10-19

- Cooldowns on the panel: while a cell's cooldown runs, its icon is greyed
  out under a cooldown swipe (the global cooldown is not shown). This works
  in combat too, where Forever hides cooldown timers, and right after the
  cast or the potion, when the panel used to show the action as ready again.
  The suggestions follow the same rule: an action on cooldown is no longer
  suggested as ready in the moment after you use it.
- Readiness at a glance: a blue icon means not enough mana, rage or energy,
  a grey icon that the action cannot be used right now (wrong stance, no
  target, Execute not available). Item cells show how many you carry.
- The action to use now stands out: its cell has a gold frame, a large "1"
  and a pulsing glow, and the first icon of the queue strip is larger and
  framed. Upcoming actions that are not ready yet keep a grey number and no
  frame.
- Countdown numbers on the swipe follow the client option *Show numbers for
  cooldowns*.

## 1.0.2 - 2026-10-18

- Spell ranks, all classes: a newly learned rank now replaces the old one
  in its cell. Before, a rank still sitting on the hidden Blizzard bar kept
  the cell (and the suggestion) on that rank, so a level-19 character could
  still be casting rank 1. Every spell cell, also the ones you placed and
  also with automatic filling off, now uses the highest rank you know.
- Critical health: below 30 % health in a fight, a healing spell on a cell
  (the class's first ready one, else your healing potion or healthstone)
  takes position 1, with a green frame, and the diagnostic pixel shows its
  cell. Options *Combat*: on/off and the threshold (10-60 %).

## 1.0.1 - 2026-10-16

- Options window: the engine features no longer run past the bottom of the
  window. They are now on two pages, *Combat* and *Reminders*, with the
  buttons and values in their own column so no label is covered.

## 1.0.0 - 2026-10-16

First public release for WoW Forever.

- Built-in suggestion engine, no other addon needed: priority lists for all
  nine classes and their talent trees (single target, cleave, aoe). The list
  follows the tree you spent the most talent points in.
- Leveling lists from level 1 to 59 that grow with every ability you learn;
  the level-60 lists from 60.
- Conditions that work with Forever's hidden combat values (rage, energy,
  mana, buffs, DoTs, cooldowns, stances, combo points, enemy count): an
  unknown value never holds a suggestion back.
- Only your tree's list is suggested, so the panel never bounces between
  stances; when you are in the wrong stance, it tells you which one to use.
- A clear "wait" when nothing can be pressed; Charge when you are out of
  melee; DoTs and Sunder Armor are not suggested again while they last.
- Burst cue: a ready big cooldown moves to position 2 (purple frame).
- Interrupts: an icon left of the grid shows the interrupt, the enemy's cast
  and your key (red "!" on the cell); crowd control on casts that cannot be
  kicked.
- Defensive column right of the grid: cooldowns, potions and healthstones
  ordered by how hurt you are, the big ones held until you need them; pet
  heal and revive.
- Clickable reminders out of combat: class buffs, flasks and elixirs, Well
  Fed food, scrolls, weapon stones and oils, shaman imbues, stealth, and
  food, drink or bandages after a fight.
- Action panel of up to 20 secure buttons that fill themselves and never
  move; you bind and press every key. Your best healing item gets a cell
  that follows what is in your bags.
- Every feature can be switched in the options (`/fob`, Features page) or
  with `/fob feature <name> on|off`.
- License: GPL-3.0-or-later. Priority and class data from Just Assisted
  Combat (wealdly, GPL-3.0), whose level-60 lists derive from wowsims (MIT).

## 0.2.0 - unreleased

- Cells fill automatically from JustAC's ability pool
  (`JustAC-BlizzardAPI.GetRotationSpells`): first free cell, never moved;
  new ranks replace the old one in the same cell; cleared spells stay out.
- Default keys `SHIFT-1…0` / `CTRL-SHIFT-1…0`; `Unbind` removes the key,
  `Default` restores it.
- Cells are saved per character (`ForeverOneButtonCharDB`); 0.1.0 cells move
  to the first character that logs in.
- Default grid: 20 cells in 10 columns.
- Any rank of a cell's spell maps to that cell for the pixel.
- Option to hide Blizzard's bottom bar (main action bar, micro menu, bags)
  while keeping the stance and experience bars; keys keep working.
- The automatic fill also includes JustAC's gap closers (Charge, Intercept...),
  which JustAC suggests from a separate list, not from its rotation pool.
- The grid title bar is always shown: right-click locks or unlocks it, left-drag
  moves it while unlocked; the position is saved in SavedVariables (also when
  combat starts mid-drag) and restored after `/reload`.
- The diagnostic log records the frame time of every pixel write; edges are
  measured on it (the edge timer and the screen run on frame time).
- The diagnostic log shows the visible pixel states with the cell
  content and key, durations, cycles and states shorter than 20 ms.
- Optional diagnostic log (`/fob log`, `ForeverOneButtonLog`) of pixel
  writes, casts, acknowledgement edges and combat transitions, with
  `scripts/analyze_log.py`.
- The pixel is black out of combat by default ("pixel only in combat"): the
  player picks the pull and the opener; JustAC is followed once combat starts.

## 0.1.0 - unreleased

First version. Offline suites pass; in-game verification is pending.

- Action Panel grid of up to 20 secure action buttons with user-assigned
  spells/items and override key bindings; changes only out of combat.
- JustAC suggestions from `JustAC-SpellQueue` / `GetCurrentSpellQueue`:
  numbered marks on the cells and a queue strip in JustAC order; explicit
  states for missing JustAC, errors, unreadable data, empty queue and waits.
- HCOneButton Diagnostic Pixel protocol v3 ported unchanged (colours,
  8×8 geometry, TOOLTIP strata, 60 ms acknowledgement edge) on an anchor
  independent of the grid.
- `/fob` commands and an options window limited to bindings and UI/pixel
  settings.
