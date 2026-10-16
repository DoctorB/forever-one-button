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
| Additional categories (max 4) | Combat, HUDs, Class (solo categorie pertinenti: quelle non pertinenti fanno rimandare indietro il progetto) |
| License | GNU General Public License version 3 (GPLv3) |
| Logo | `docs/logo.png` (1254×1254 PNG, 1:1; minimo richiesto 400×400) |
| Source | `https://github.com/DoctorB/forever-one-button` |
| Issues | `https://github.com/DoctorB/forever-one-button/issues` |

### Summary

```text
An action panel for WoW Forever with its own rotation engine: priority lists for every class, burst, interrupts, defensives and reminders on buttons you press yourself.
```

## 2. Description

Incollare nell'editor della descrizione in modalità Markdown (se l'editor è
solo visuale, incollare il testo e applicare i titoli a mano).

```markdown
# Forever One Button

**An action panel for WoW Forever with its own suggestion engine.**

Forever One Button puts the right ability on a grid of up to 20 action
buttons that you own: you choose the keys, you press every key, and the panel
shows which of your buttons to press next. No other addon is needed.

## A complete engine for every class

- **Priority lists for all nine classes** and every talent tree, for single
  target, cleave and aoe. The list follows the tree you spent the most
  talent points in.
- **Conditions that work on Forever**: rage, energy and mana thresholds,
  buffs and DoTs, cooldowns, stances and forms, combo points, swing timer,
  execute range, number of engaged enemies. When the game keeps a value
  hidden in combat, the engine never guesses: an unknown value never blocks
  a suggestion.
- **Only your tree's list is suggested**, so the panel never bounces between
  stances.
- **Ranks handled**: the rank on your action bars, or the highest you know.
- **Charge** and other gap closers when you are out of melee; a clear **wait**
  when nothing can be pressed yet.

## More than a rotation

- **Burst cue**: when a big cooldown is ready, it moves to position 2 with a
  purple frame.
- **Interrupts**: when your target casts, an icon shows the right interrupt
  (Pummel, Shield Bash, Kick, Counterspell...) with the enemy's cast and your
  key; crowd control is offered on casts that cannot be kicked.
- **Defensives**: a column orders your defensive cooldowns, healing potions
  and healthstones by how hurt you are, and holds the big ones until you
  really need them. Pet heal and revive for hunters and warlocks; optional
  group heals and escapes from crowd control.
- **Reminders out of combat**: a clickable row for missing class buffs,
  flasks and elixirs, Well Fed food, scrolls, weapon stones and oils, shaman
  imbues, stealth, and food, drink or bandages after a fight.

## You press every key

Every cell is a secure action button that runs only when you click it or
press its key. There is no one-key spam button, no repeat and no automatic
pulling. You start every pull and choose every opener.

## The panel

- Up to 20 cells (default 20 in 10 columns); columns, cell size, spacing and
  scale are adjustable.
- Cells fill themselves from your priority list, gap closers, interrupts,
  defensives and your best healing item. Nothing is ever moved, so your
  muscle memory stays valid; new ranks replace old ones in the same cell.
  Drag any spell or item onto a cell to change it.
- Default keys: `SHIFT-1`...`SHIFT-0` for cells 1-10 and `CTRL-SHIFT-1`...
  `CTRL-SHIFT-0` for cells 11-20. Rebind, unbind or reset any cell.
- Gold frame for the next ability, cyan for the ones after it, purple for
  burst, red "!" for the interrupt, orange "D" for the defensive to use.
- Movable panel: right-click the title bar to unlock, drag it, right-click to
  lock again. The position is saved.
- Optional: hide Blizzard's bottom bar while the stance and experience bars
  stay and the action bar keys keep working.
- Every feature can be switched in the options (`/fob`, Features page).

## Getting started

1. Install **Forever One Button**.
2. Log in: the cells fill from your priority list.
3. Type `/fob` to open the options (cells, keys, layout, features).
4. Fight: press the key of the cell with the gold frame.

## Commands

- `/fob` - options
- `/fob status` - talent tree, context and current suggestion
- `/fob bindings` - cells and keys
- `/fob features` - feature switches; `/fob feature <name> on|off`
- `/fob lock` / `/fob unlock` / `/fob reset` - panel position and layout
- `/fob autofill on|off|now|reset` - automatic fill
- `/fob blizzardbar hide|show` - Blizzard's bottom bar

## Feedback

Bug reports and suggestions are welcome on
[GitHub Issues](https://github.com/DoctorB/forever-one-button/issues).

## Credits

The priority lists and class data come from
[Just Assisted Combat](https://www.curseforge.com/wow/addons/just-assisted-combat)
by wealdly (GPL-3.0), whose lists derive from the wowsims rotations
(MIT, wowsims team). Forever One Button is free software under the GNU
General Public License version 3.
```

## 3. File (Upload File)

| Campo | Valore |
|---|---|
| File | `dist/ForeverOneButton-1.0.0.zip` da `python scripts/package.py build` (zip verificato) |
| Display Name | `Forever One Button 1.0.0` |
| Release Type | **Release** se la prova in gioco (sezione 4) è passata, altrimenti **Beta**. L'app CurseForge sincronizza un progetto solo dopo il primo file Release |
| Supported Version | la versione **Forever** corrispondente al client 1.60.1 (Interface `16001`) |
| Related Projects | nessuno: l'addon non ha dipendenze |
| Changelog | vedi sotto |

### Changelog

```markdown
1.0.0 - first public release for WoW Forever.

- Built-in suggestion engine: priority lists for all nine classes and their
  talent trees (single target, cleave, aoe), conditions that work with
  Forever's hidden combat values; only your tree's list is suggested.
- Burst cue: a ready big cooldown moves to position 2 (purple).
- Interrupts: icon with the enemy cast and your key; crowd control on
  shielded casts.
- Defensive column: cooldowns, potions and healthstones ordered by how hurt
  you are; pet heal and revive.
- Clickable reminders out of combat: class buffs, consumables, weapon
  enhancements, stealth, food, drink and bandages.
- Action panel of up to 20 secure buttons that fill themselves and never
  move; you bind and press every key.
- Movable panel, optional hiding of Blizzard's bottom bar.
```

## 4. Prima di pubblicare

- **Prova in gioco** (fase 10, [RUNTIME_CHECKLIST.md](RUNTIME_CHECKLIST.md)):
  rotazione del guerriero senza giro di posture, Charge fuori mischia,
  interruzione su un lancio, burst in posizione 2, colonna difese sotto il
  50%, riga dei promemoria fuori dal combattimento. Da qui la scelta tra
  Release e Beta.
- **Licenza**: su CurseForge selezionare GPLv3, la stessa del file
  `LICENSE` nel pacchetto.
- **Versione nel pacchetto**: `## Version: 1.0.0` nel TOC; aggiornare la data
  della sezione 1.0.0 in `CHANGELOG.md` quando si pubblica.
