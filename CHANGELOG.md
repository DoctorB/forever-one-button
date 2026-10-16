# Changelog

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
