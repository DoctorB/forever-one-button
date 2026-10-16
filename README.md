# Forever One Button

<img src="docs/logo.png" alt="Forever One Button logo" width="160">

An Action Panel for **WoW Forever** with its own suggestion engine: the
priority lists of every class on a grid of action buttons you bind yourself,
plus a burst cue, interrupts, defensives and out-of-combat reminders. It keeps
the HCOneButton **Diagnostic Pixel protocol v3**.

- **Built-in engine.** Priority lists for all nine classes and their talent
  trees (single target, cleave, aoe), with secret-safe conditions on rage,
  energy, mana, buffs, DoTs, cooldowns, stances, combo points, swing timer
  and enemy count. Only the active list is suggested, so it never flips
  between stances.
- **You press every key.** Cells are secure action buttons that run only when
  you click them or press their key. There is no spam button, no repeat, no
  pull automation and no pull advisor.
- **More than a rotation.** Burst cooldowns move to position 2 when ready;
  the right interrupt appears when your target casts; a defensive column
  orders your cooldowns and healing items by how hurt you are; out of combat
  a clickable row reminds you of class buffs, consumables, weapon stones,
  stealth, food and drink.
- **The pixel keeps its contract.** The 8×8 diagnostic square encodes the cell
  holding the first ready suggestion exactly as HCOneButton protocol v3 does.

Status: **1.0.0**. The offline suites pass; the in-game checks listed in
[docs/RUNTIME_CHECKLIST.md](docs/RUNTIME_CHECKLIST.md) are still open.

## Requirements

- WoW Forever client (`_classic_beta_`, build 1.60.1.x, Interface `16001`).
- No other addon. (Up to 0.2.0 the suggestions came from JustAC; its data now
  ships inside, see License.)

## Installation

1. Download `ForeverOneButton-<version>.zip` (or build it, see below).
2. Extract it into `World of Warcraft\_classic_beta_\Interface\AddOns\` so the
   folder `AddOns\ForeverOneButton\ForeverOneButton.toc` exists.
3. Restart the client or `/reload`.

## Configuration

Open the options with `/fob`.

1. **Cells fill themselves.** The spells of your active talent tree's list,
   then your gap closers (Charge...), interrupts and defensive cooldowns, and
   the best healing potion or healthstone you carry, each take the first free
   cell and **keep it**. A new spell you learn goes to the next free cell; a
   new rank replaces the old one in the same cell; a better potion replaces
   the old one. Nothing is ever moved. Cells are saved per character.
   You can still drag a spell or item onto a cell, or use
   `/fob assign <cell> spell <id or name>` / `/fob assign <cell> item <id>`.
   **Clear** empties a cell and keeps that spell out of the automatic fill
   (`/fob autofill reset` undoes this). Turn the fill off in the options or
   with `/fob autofill off`.
2. **Keys.** Cells 1–10 use `SHIFT-1`…`SHIFT-0`, cells 11–20
   `CTRL-SHIFT-1`…`CTRL-SHIFT-0` by default. In *Cells & keys* press **Bind**
   and a key to change one (Esc cancels), **Unbind** for no key, **Default** to
   go back. A key used by another cell is refused. A key that also has a normal
   WoW binding is marked with `!`: the cell overrides it while the addon is
   loaded (by default `SHIFT-1`…`6` switch action bar pages).
3. **Layout.** In *Layout & pixel*: number of cells (1–20, default 20 in 10
   columns), columns, cell size, spacing, scale, how many queue positions are
   labelled, show/lock grid. The title bar above the grid moves it: right-click
   it to unlock, drag it with the left button, right-click again to lock. The
   position is saved and restored after /reload (out of combat only;
   `/fob reset` puts it back).
4. **Pixel.** Show/hide it, unlock it to drag it by its yellow frame, lock it
   again. Keep it away from other UI.
5. **Blizzard's bottom bar.** "Hide Blizzard's bottom bar" in *Layout & pixel*
   (or `/fob blizzardbar hide|show`) makes the main action bar, the micro menu
   and the bags invisible and click-through. The stance and experience bars
   stay; the action bar keys keep working. Applied out of combat.
6. **Features.** In *Features* (or `/fob features`,
   `/fob feature <name> on|off|<value>`): burst cue; interrupts (mode: kicks
   only, kicks first, crowd control first; fears); defensive column (hold
   immunities and big heals until health is low, healing items, pet cues,
   group heals, escape from loss of control); reminders (class buffs, flask,
   food, scroll, weapon enhancement, recovery, stealth, top-off heal). Group
   heals, loss-of-control escapes and the top-off heal above 35% are off by
   default.

Changes to cells, keys and layout are blocked in combat; the options window
closes when combat starts.

## Using it

- The status line shows the talent tree and context, for example
  `Arms (single target)`. With 2 enemies engaged the cleave list is used,
  with 3 or more the aoe list (enemies are counted from nameplates).
- The cell holding the first suggestion has a **gold frame and "1"**; the next
  positions have cyan frames and their numbers. The strip below the grid lists
  the queue in order with the cell of each entry (`c3`) or `--`; entries that
  are not ready yet are dimmed. With nothing to press in a fight, position 1 is
  **wait**.
- A ready **burst** cooldown has a **purple** frame (position 2).
- When the target casts, the **interrupt** icon left of the grid shows the
  spell, the enemy cast and the key; its cell gets a **red frame and "!"**.
- The **defensive column** right of the grid lists up to four cooldowns or
  items, held ones dimmed; the cell to press now gets an **orange frame and
  "D"**.
- Out of combat the **reminder row** below the strip shows what is missing;
  click an icon to use it. It hides itself in combat.
- If the suggestion is not on the grid, the status line says so; no other
  cell is highlighted instead. You start every pull and press every key.

## Diagnostic pixel (protocol v3, unchanged from HCOneButton)

| State | RGB |
|---|---|
| Cell *n* (1–20) holds the first ready suggestion | `R = n × 12, G = 96, B = 224` |
| Out of combat (default "pixel only in combat"), or no executable suggestion (none, wait, no priority list for the class, engine error, player casting or channeling, confirmed out of range) | `0, 0, 0` |
| Suggestion not on any cell | `255, 255, 255` |

Only the damage queue reaches the pixel: burst cue, interrupts, defensives and
reminders are shown on the panel only.

By default the pixel is black out of combat: you choose the pull and the
opening spell, and the pixel starts following the queue when combat begins
(`/fob pixel combat off` or the option to change this; the grid shows
suggestions in any case).

After you successfully cast the encoded action the pixel stays black for at
least 60 ms before the next suggestion, as in HCOneButton. Details:
[docs/PROTOCOL_COMPATIBILITY.md](docs/PROTOCOL_COMPATIBILITY.md).

### Checking the acknowledgement edge in game

1. `/fob log on`, then fight and press the suggested spell several times.
2. `/fob log show`: number of edges, shortest and average black time, casts
   whose spell ID was secret.
3. `/reload` (or log out) so the client writes
   `WTF\Account\<account>\SavedVariables\ForeverOneButton.lua`, then run
   `python scripts/analyze_log.py` for the full list of edges.
   The report also shows the sequence of visible pixel states (black, white,
   slot N with the cell's spell and key) with their durations, the number of
   recommendation cycles and any state shorter than 20 ms.
4. `/fob log off` when done. The log stores no secret values and does not
   change the pixel; times are those of the addon's colour writes.

## Commands

| Command | Effect |
|---|---|
| `/fob` | Options |
| `/fob status` | Engine state, talent tree, context, queue length, pixel state |
| `/fob bindings` | Cells, keys, missing keys and overridden bindings |
| `/fob assign <cell> spell <id\|name>` / `item <id>` | Put an action on a cell |
| `/fob clear <cell>` | Empty a cell |
| `/fob bind <cell> <key>` / `unbind <cell>` / `defaultkey <cell>` | Key for a cell |
| `/fob autofill on` / `off` / `now` / `reset` | Automatic fill; `reset` forgets the spells you removed |
| `/fob features` / `feature <name> on\|off\|<value>` | Engine features (burst, interrupts, defensives, reminders) |
| `/fob show` / `hide` / `lock` / `unlock` / `reset` | Grid visibility, position lock, default layout |
| `/fob pixel on` / `off` / `lock` / `unlock` / `reset` | Pixel visibility and position |
| `/fob pixel combat on` / `combat off` | Pixel only in combat (default on) or always |
| `/fob blizzardbar hide` / `show` | Hide or show Blizzard's bottom bar (stance and XP bars stay) |
| `/fob log on` / `off` / `show [lines]` / `clear` | Diagnostic log of pixel writes, casts and edges (off by default) |

## Troubleshooting

- **"No priority list for this class"**: the class has no Forever list in the
  data (all nine Forever classes have one).
- **Gold frame missing but the strip shows `1: --`**: the suggested action is
  not on a cell: all 20 cells are used or you removed it. Drag it onto a cell.
- **Cells stay empty**: `/fob status` shows the automatic fill state.
- **Always the single-target list in a group fight**: enable enemy nameplates;
  engaged enemies are counted from them.
- **A buff is suggested again in combat**: on Forever buffs cannot be read in
  combat; the engine relies on your own casts there.
- **"changes apply after combat"**: you reloaded in combat; cells and keys are
  applied when combat ends. Until then the pixel shows white, never a slot
  whose button is not ready.
- **"grid covers the pixel!"**: move the grid or the pixel.
- **A key does nothing**: `/fob bindings`; the cell may be beyond the visible
  cell count, empty, or the key may be taken by another addon's override.

## Limits

- Runtime behaviour on Forever (the engine's readings in combat, secure
  buttons, override bindings, the reminder row) is not verified in game yet;
  see [docs/FOREVER_API_COMPATIBILITY.md](docs/FOREVER_API_COMPATIBILITY.md).
- The priority lists are the imported data; only the warrior lists can be
  checked in game for now.
- Up to 20 cells: protocol v3 encodes slots 1–20 only.

## Development

```text
tests/run.ps1                                   # Lua parse + all Lua suites + Python suites
lua5.1 tests/test_<name>.lua                    # one Lua suite
python -m unittest discover -s tests -p "test_*.py"
python scripts/package.py build                 # dist/ForeverOneButton-<version>.zip, verified
python scripts/import_justac_data.py            # regenerate ForeverOneButton/Data/ (JustAC 6.0.0, hashes pinned)
python scripts/fetch_fixtures.py                # HCOneButton test fixtures (run.ps1 does it)
```

Documentation: [architecture](docs/ARCHITECTURE.md),
[protocol](docs/PROTOCOL_COMPATIBILITY.md),
[action panel](docs/ACTION_PANEL_DESIGN.md),
[bindings and options](docs/BINDINGS_AND_OPTIONS.md),
[Forever API](docs/FOREVER_API_COMPATIBILITY.md),
[tests](docs/TEST_REPORT.md), [milestones](docs/MILESTONES.md),
[repository audit](docs/REPOSITORY_AUDIT.md),
[Git configuration](docs/GIT_CONFIGURATION.md).

## License

GPL-3.0-or-later, Copyright (c) 2026 DoctorB. The files in
`ForeverOneButton/Data/` are imported from JustAC 6.0.0 (GPL-3.0-or-later,
wealdly), whose priority lists derive from wowsims (MIT); the diagnostic pixel
is ported from HCOneButton (MIT, same author). See
[ForeverOneButton/NOTICE.md](ForeverOneButton/NOTICE.md).
