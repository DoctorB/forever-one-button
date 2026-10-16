# Pubblicazione su CurseForge - contenuti del modulo

Testi pronti da incollare nel modulo di CurseForge (Create Project, poi Upload
File). CurseForge richiede titoli e descrizioni **in inglese**: i campi da
incollare sono in inglese, le note per chi pubblica in italiano.

Il caricamento è manuale: questo repository non ha workflow di upload né
secret CurseForge.

## 1. Progetto

| Campo | Valore |
|---|---|
| Game | World of Warcraft |
| Class | Addons |
| Name | `Forever One Button` |
| Summary | vedi sotto |
| Main category | Action Bars |
| Additional categories (max 4) | Combat, HUDs (solo categorie pertinenti: quelle non pertinenti fanno rimandare indietro il progetto) |
| License | MIT License |
| Logo | `docs/logo.png` (1254×1254 PNG, 1:1; minimo richiesto 400×400) |
| Source | `https://github.com/DoctorB/forever-one-button` |
| Issues | `https://github.com/DoctorB/forever-one-button/issues` |

### Summary

```text
Shows JustAC's suggestions on a grid of secure action buttons that you bind and press yourself, built for WoW Forever.
```

## 2. Description

Incollare nell'editor della descrizione in modalità Markdown (se l'editor è
solo visuale, incollare il testo e applicare i titoli a mano).

```markdown
# Forever One Button

**An Action Panel for WoW Forever, powered by Just Assisted Combat (JustAC).**

Forever One Button puts JustAC's suggestions on a grid of up to 20 action
buttons that you own: you choose the keys, you press every key, and the panel
shows which of your buttons JustAC wants next.

## Built on JustAC

Forever One Button has **no rotation logic of its own**. Every suggestion comes
from [Just Assisted Combat](https://www.curseforge.com/wow/addons/just-assisted-combat)
by wealdly, read through JustAC's public libraries:

- **Suggestions** come from JustAC's public spell queue
  (`JustAC-SpellQueue`, `GetCurrentSpellQueue`). The queue is shown exactly as
  JustAC builds it: never reordered, filtered or replaced.
- **Cells fill themselves from JustAC's ability pool**
  (`JustAC-BlizzardAPI`, `GetRotationSpells`), plus JustAC's gap closers such as
  Charge. Each spell takes the first free cell and **keeps it**: nothing is ever
  moved, so your muscle memory stays valid. A new rank replaces the old one in
  the same cell. Cells are saved per character.
- **The panel follows JustAC's queue.** The cell holding JustAC's first
  suggestion gets a gold frame and a "1"; the next suggestions get cyan frames
  and their position numbers. A strip below the grid lists the whole queue in
  JustAC order, with the cell that holds each entry.
- **Honest states.** If JustAC suggests something that is not on the grid, the
  panel says so instead of highlighting another cell. JustAC missing, waiting,
  empty or unreadable is always shown as such.

Configure *what* gets suggested in JustAC's own options (profiles, visibility,
custom queue). Forever One Button only decides *where* it appears and *which
key* runs it.

JustAC is a separate addon (GPL-3.0) and is not bundled. Install it alongside
this one; without it the grid still works as plain action buttons and shows
"JustAC not loaded".

## You press every key

Every cell is a secure action button that runs only when you click it or press
its key. There is no one-key spam button, no repeat and no automatic pulling.
You start every pull and choose every opener.

## Features

- Up to 20 cells (default 20 in 10 columns); columns, cell size, spacing and
  scale are adjustable.
- Default keys: `SHIFT-1`...`SHIFT-0` for cells 1-10 and `CTRL-SHIFT-1`...
  `CTRL-SHIFT-0` for cells 11-20. Rebind, unbind or reset any cell; conflicts
  with your normal WoW bindings are marked.
- Drag any spell or item onto a cell, or let the automatic fill do it.
- Movable panel: right-click the title bar to unlock, drag it, right-click to
  lock again. The position is saved.
- Optional: hide Blizzard's bottom bar (main bar, micro menu, bags) while the
  stance and experience bars stay and the action bar keys keep working.
- Layout, cell and key changes are blocked in combat and applied safely
  afterwards.
- Optional diagnostic square (8x8 pixels, HCOneButton protocol v3) that shows
  which cell holds JustAC's first suggestion. By default it is black outside
  combat, and it can be hidden.

## Getting started

1. Install **Forever One Button** and **Just Assisted Combat**.
2. Log in: the cells fill from JustAC's ability pool.
3. Type `/fob` to open the options (cells, keys, layout).
4. Fight: press the key of the cell with the gold frame.

## Commands

- `/fob` - options
- `/fob status` - JustAC state and current suggestion
- `/fob bindings` - cells and keys
- `/fob lock` / `/fob unlock` / `/fob reset` - panel position and layout
- `/fob autofill on|off|now|reset` - automatic fill from JustAC
- `/fob blizzardbar hide|show` - Blizzard's bottom bar

## Status

Alpha for the WoW Forever client. Feedback and bug reports are welcome on
[GitHub Issues](https://github.com/DoctorB/forever-one-button/issues).

## Credits

Suggestions by [Just Assisted Combat](https://www.curseforge.com/wow/addons/just-assisted-combat)
(wealdly). Forever One Button contains no JustAC code; it only calls JustAC's
public libraries at run time. MIT License.
```

## 3. File (Upload File)

| Campo | Valore |
|---|---|
| File | `dist/ForeverOneButton-0.2.0.zip` da `python scripts/package.py build` (zip verificato) |
| Display Name | `Forever One Button 0.2.0` |
| Release Type | **Alpha** (vedi note: la verifica in gioco è parziale). L'app CurseForge sincronizza un progetto solo dopo il primo file Release |
| Supported Version | la versione **Forever** corrispondente al client 1.60.1 (Interface `16001`) |
| Related Projects | `Just Assisted Combat` (slug `just-assisted-combat`, ID 1289544) come **Required Dependency**: l'app CurseForge lo installa insieme |
| Changelog | vedi sotto |

### Changelog

```markdown
First public alpha for WoW Forever.

- Action Panel of up to 20 secure action buttons; you bind and press every key.
- JustAC's suggestions shown on your cells (gold "1", cyan 2+) and in a queue
  strip, in JustAC order.
- Cells fill automatically from JustAC's ability pool and gap closers; nothing
  is ever moved; saved per character.
- Default keys SHIFT-1...0 and CTRL-SHIFT-1...0, rebindable.
- Movable panel: right-click the title bar to unlock or lock; position saved.
- Option to hide Blizzard's bottom bar (stance and XP bars stay).
- Optional diagnostic square (HCOneButton protocol v3), black out of combat by
  default.
```

## 4. Prima di pubblicare

- **Versione di JustAC.** L'integrazione è verificata su JustAC 5.9.0-beta2
  (GitHub `431e9a2`). JustAC 6.0.0 (CurseForge, 15/10/2026, installata nella
  beta il 16/10) è stata confrontata sul codice: stessi minor
  (`JustAC-SpellQueue` 43, `JustAC-BlizzardAPI` 36, `JustAC-SpellDB` 20),
  stesso `WAIT_SENTINEL`; `GetRotationSpells`, `ResolveKnownSpellID`,
  `GetGapCloserDefaults` e la lista dei gap closer identici (la lista è passata
  da `Data/ForeverDefaults.lua` a `Data/Forever/Defaults.lua`). Unica novità
  nella coda: `_StageForeverWait` mette il wait in posizione 1, spostando le
  altre voci, quando in combattimento nessuna voce è eseguibile; l'addon lo
  mostra già come "wait" (pixel nero). Resta da provare in gioco
  (`/fob status`) prima del caricamento.
- **Verifiche in gioco ancora aperte** ([TEST_REPORT.md](TEST_REPORT.md)):
  da qui il tipo Alpha.
- **Versione nel pacchetto.** `## Version: 0.2.0` nel TOC e in `CHANGELOG.md`
  (ancora "unreleased"); aggiornare la data nel CHANGELOG quando si pubblica.
