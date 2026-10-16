# Forever One Button

<img src="docs/logo.png" alt="Forever One Button logo" width="160">

An Action Panel for **WoW Forever** that puts
[JustAC](https://github.com/wealdly/JustAC) suggestions on a grid of action
buttons you configure yourself, and keeps the HCOneButton **Diagnostic Pixel
protocol v3**.

- **JustAC decides.** The only source of suggestions is JustAC's public
  `JustAC-SpellQueue` / `GetCurrentSpellQueue`. Forever One Button has no
  rotation, no priorities and no fallback of its own.
- **You press every key.** Cells are secure action buttons that run only when
  you click them or press their key. There is no spam button, no repeat, no
  pull automation and no pull advisor.
- **The pixel keeps its contract.** The 8×8 diagnostic square encodes the cell
  holding JustAC's first suggestion exactly as HCOneButton protocol v3 does.

Status: **0.2.0, partial / runtime verification pending**. The offline suites
pass; the in-game checks listed in [docs/TEST_REPORT.md](docs/TEST_REPORT.md)
are still open.

## Requirements

- WoW Forever client (`_classic_beta_`, build 1.60.1.x, Interface `16001`).
- JustAC 5.9.0-beta2 or later (verified against SpellQueue minor 43). Without
  JustAC the grid works as plain action buttons and says "JustAC not loaded".

## Installation

1. Download `ForeverOneButton-<version>.zip` (or build it, see below).
2. Extract it into `World of Warcraft\_classic_beta_\Interface\AddOns\` so the
   folder `AddOns\ForeverOneButton\ForeverOneButton.toc` exists.
3. Install JustAC in the same `AddOns` folder.
4. Restart the client or `/reload`.

## Configuration

Open the options with `/fob`.

1. **Cells fill themselves.** Every spell JustAC can suggest for your
   character (the spells on your action bars, the known abilities of
   JustAC's Forever list and JustAC's gap closers such as Charge) takes the
   first free cell and **keeps it**. A new
   spell you learn goes to the next free cell; a new rank replaces the old one
   in the same cell. Nothing is ever moved. Cells are saved per character.
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
3. **Layout.** In *Layout & pixel*: number of cells (1–20, default 20 in 10 columns), columns, cell size,
   spacing, scale, how many JustAC positions are labelled, show/lock grid.
   The title bar above the grid moves it: right-click it to unlock, drag it
   with the left button, right-click again to lock. The position is saved and
   restored after /reload (out of combat only; `/fob reset` puts it back).
4. **Pixel.** Show/hide it, unlock it to drag it by its yellow frame, lock it
   again. Keep it away from other UI.

5. **Blizzard's bottom bar.** "Hide Blizzard's bottom bar" in *Layout & pixel*
   (or `/fob blizzardbar hide|show`) makes the main action bar, the micro menu
   and the bags invisible and click-through. The stance and experience bars
   stay; the action bar keys keep working. Applied out of combat.

Changes to cells, keys and layout are blocked in combat; the options window
closes when combat starts.

## Using it

- The cell holding JustAC's first suggestion has a **gold frame and "1"**; the
  next positions have cyan frames and their numbers. The strip below the grid
  lists JustAC's queue **in JustAC order** with the cell of each entry
  (`c3`) or `--` when no cell holds it.
- If JustAC suggests something that is not on the grid, the status line says
  so; no other cell is highlighted instead.
- You start every pull and press every key.

## Diagnostic pixel (protocol v3, unchanged from HCOneButton)

| State | RGB |
|---|---|
| Cell *n* (1–20) holds JustAC's first suggestion | `R = n × 12, G = 96, B = 224` |
| Out of combat (default "pixel only in combat"), or no executable suggestion (none, JustAC wait, JustAC missing/error/unreadable, player casting or channeling, confirmed out of range) | `0, 0, 0` |
| JustAC suggestion not on any cell | `255, 255, 255` |

By default the pixel is black out of combat: you choose the pull and the
opening spell, and the pixel starts following JustAC when combat begins
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
| `/fob status` | JustAC state, queue length, pixel state |
| `/fob bindings` | Cells, keys, missing keys and overridden bindings |
| `/fob assign <cell> spell <id\|name>` / `item <id>` | Put an action on a cell |
| `/fob clear <cell>` | Empty a cell |
| `/fob bind <cell> <key>` / `unbind <cell>` / `defaultkey <cell>` | Key for a cell |
| `/fob autofill on` / `off` / `now` / `reset` | Automatic fill; `reset` forgets the spells you removed |
| `/fob show` / `hide` / `lock` / `unlock` / `reset` | Grid visibility, position lock, default layout |
| `/fob pixel on` / `off` / `lock` / `unlock` / `reset` | Pixel visibility and position |
| `/fob pixel combat on` / `combat off` | Pixel only in combat (default on) or always |
| `/fob blizzardbar hide` / `show` | Hide or show Blizzard's bottom bar (stance and XP bars stay) |
| `/fob log on` / `off` / `show [lines]` / `clear` | Diagnostic log of pixel writes, casts and edges (off by default) |

## Troubleshooting

- **"JustAC not loaded"**: JustAC is missing or disabled for this character.
- **"JustAC: no suggestion" outside combat**: JustAC's own visibility options
  (for example "combat only") empty its queue; check them in JustAC.
- **Gold frame missing but the strip shows `1: --`**: the suggested action is
  not on a cell: all 20 cells are used, you removed it, or it is not in
  JustAC's pool. Drag it onto a cell.
- **Cells stay empty**: `/fob status` shows the automatic fill state; JustAC
  must be loaded.
- **"changes apply after combat"**: you reloaded in combat; cells and keys are
  applied when combat ends. Until then the pixel shows white, never a slot
  whose button is not ready.
- **"grid covers the pixel!"**: move the grid or the pixel.
- **A key does nothing**: `/fob bindings`; the cell may be beyond the visible
  cell count, empty, or the key may be taken by another addon's override.

## Limits

- Runtime behaviour on Forever (secure buttons, override bindings, secret
  values in combat, real screen capture) is not verified yet; see
  [docs/FOREVER_API_COMPATIBILITY.md](docs/FOREVER_API_COMPATIBILITY.md).
- Up to 20 cells: protocol v3 encodes slots 1–20 only.

## Development

```text
tests/run.ps1                                   # Lua parse + all Lua suites + Python suites
lua5.1 tests/test_<name>.lua                    # one Lua suite
python -m unittest discover -s tests -p "test_*.py"
python scripts/package.py build                 # dist/ForeverOneButton-<version>.zip, verified
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
