# Changelog

## 1.0.0 - unreleased

- Built-in suggestion engine; JustAC is no longer needed. Priority lists for
  all nine classes and their talent trees (single target, cleave, aoe),
  imported from JustAC 6.0.0's Forever data (`scripts/import_justac_data.py`,
  source hashes pinned), with all 19 condition types evaluated secret-safely:
  an unknown value never holds a suggestion back.
- Only the active tree's list (plus gap closers) is suggested: the
  Defensive/Battle Stance loop seen with JustAC 6.0.0 cannot happen.
- Wait when nothing can be pressed in a fight; Charge out of melee; DoTs
  ticking on the target wait; ranks on the action bars are used.
- Burst cue: a ready burst cooldown moves to position 2 (purple frame).
- Interrupts: icon left of the grid with the enemy cast and the key, red "!"
  on the cell; kicks first, crowd control on shielded casts; modes and fears
  configurable.
- Defensive column right of the grid: class cooldowns and the best healing
  item, ordered by health band and tier, emergencies held until health is
  low; pet heal/revive, group heals and loss-of-control escapes (the last
  two off by default).
- Reminder row out of combat, clickable: class buffs, flask/elixir, food,
  scroll, weapon stone/oil or shaman imbue, stealth, top-off heal, food,
  drink and bandage after a fight. Hidden in combat.
- Automatic fill also places interrupts, defensives and one healing-item
  cell (replaced in place by a better item).
- Options: a Features page; `/fob features`, `/fob feature <name> ...`.
- License: GPL-3.0-or-later (imported data from JustAC, GPL; priority lists
  derived from wowsims, MIT).

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
