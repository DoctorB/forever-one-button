# Audit dei repository (Fase 0)

Data: 2026-10-15, aggiornato il 2026-10-16 per la 1.0.0 (motore interno,
dati importati da JustAC 6.0.0, licenza GPL-3.0-or-later). Tutti i repository
di riferimento sono stati usati in sola lettura (eccezione involontaria
documentata in `GIT_CONFIGURATION.md` §5).

## Repository

| Repository | Percorso | Origine | Branch / commit | Stato locale | Licenza | Istruzioni |
|---|---|---|---|---|---|---|
| Forever One Button (destinazione) | `C:\Work\forever-one-button` | `https://github.com/DoctorB/forever-one-button.git` | `main` `0eb4942`; lavoro su `feat/forever-one-button` | prima: cartella non Git con la sola specifica | MIT fino alla 0.2.0; GPL-3.0-or-later dalla 1.0.0 (`LICENSE`, `ForeverOneButton/LICENSE`, `ForeverOneButton/NOTICE.md`) | specifica del proprietario (non inclusa nel repository) |
| HCOneButton (riferimento) | `C:\Work\hc-one-button` | `https://github.com/DoctorB/hc-one-button.git` | `main` = `origin/main` = `e973acba84e3911ddb6a68655d247426df7bdf4f` (1.29.18) | un file non tracciato preesistente: `docs/FOREVER_FEASIBILITY.md` (lasciato intatto) | MIT, (c) 2026 DoctorB | `docs/RELEASING.md` |
| JustAC (riferimento) | `C:\Work\JustAC` (clonato durante l'audit) | `https://github.com/wealdly/JustAC.git` | `main` `431e9a220dc3cf4bbfe8c05818a1de88ee40fa14` (tag `v5.9.0-beta2`, 2026-10-08) | pulito | GPL-3.0-or-later, (C) 2024-2026 wealdly | `AGENTS.md`, `Documentation/STYLE_GUIDE_JUSTAC.md` |
| JustAC installato | `…\_classic_beta_\Interface\AddOns\JustAC` | — | 5.9.0-beta2 al 2026-10-15; **6.0.0** al 2026-10-16 (`## Version: 6.0.0` nel TOC) | alla 5.9.0-beta2 identico a `431e9a2` per tutti i file dell'addon (`diff -r`); i 5 file di dati della 6.0.0 usati dall'importazione hanno gli SHA-256 fissati in `scripts/import_justac_data.py` | GPL-3.0-or-later | — |
| Forever ChatGuard (evidenza Forever) | `C:\Work\forever-chatguard` | `https://github.com/DoctorB/forever-chatguard.git` | `5ad4ac4` | 2 png non tracciati | — | target solo Forever |
| wowsims per Forever (origine delle liste di JustAC) | — | `https://github.com/ElliotWood/Forever` | `96719dc69ff3e93de4a8b0eff4653e7df269a604` | non clonato: citato dalle intestazioni dei dati di JustAC | MIT, (c) 2022 wowsims team | — |
| `hc-navigator` | — | — | — | **fuori ambito** su indicazione dell'utente (usa un protocollo pixel diverso, di posizione) | — | — |
| `C:\Work\ale\hc-one-button` | — | non Git | HCOB 1.27.5 | copia vecchia dell'addon | — | — |

## Target Forever

| Voce | Valore | Evidenza |
|---|---|---|
| Client | `World of Warcraft\_classic_beta_\WowB.exe`, prodotto `wow_classic_beta` | `.build.info` |
| Build | 1.60.1.70374 | `.build.info` (2026-10-15) |
| Interface | 16001 | probe ChatGuard; TOC JustAC |
| Restrizioni | combat log vietato, HP/potere secret | `hc-one-button/docs/FOREVER_FEASIBILITY.md` (probe su 1.60.1.70338) |

## Strumenti

| Strumento | Versione | Uso |
|---|---|---|
| Lua | 5.1.5 (`%LOCALAPPDATA%\Programs\Lua51`) | suite Lua, `luac -p` |
| Python | `py` launcher, 3.14 | packaging, test Python |
| Git | 2.56.0.windows.2 | — |
| GitHub CLI | `gh`, autenticato come `DoctorB` | audit/impostazioni remote, CI |
| PowerShell | Windows PowerShell 5.1 (locale), pwsh (CI) | `tests/run.ps1` |

## Dipendenze del prodotto

- Runtime: nessuna. Dalla 1.0.0 JustAC non è più usato (nessun
  `OptionalDeps` nel TOC, verificato da `tests/test_toc.lua`). Nessuna
  libreria incorporata.
- Dati importati: `ForeverOneButton/Data/*.lua` generati da
  `scripts/import_justac_data.py` (con `scripts/import_justac_data.lua`) dai
  file di dati di JustAC 6.0.0 (GPL-3.0-or-later, (C) 2024-2026 wealdly); lo
  script rifiuta file con SHA-256 diversi da quelli fissati. Le liste di
  priorità di JustAC derivano da wowsims (`ElliotWood/Forever` @ `96719dc`,
  MIT). Nessun codice di JustAC è incluso. Il progetto è
  rilasciato sotto GPL-3.0-or-later; attribuzioni e licenza MIT di wowsims in
  `ForeverOneButton/NOTICE.md`.
- Codice HCOB riusato (MIT, stesso autore) con attribuzione in
  `ForeverOneButton/NOTICE.md`.

## Fixture con provenienza

| Fixture | Origine | Blob Git | Acquisizione |
|---|---|---|---|
| `tests/fixtures/hcob/DiagnosticPixel.lua` | `HCOneButton/UI/DiagnosticPixel.lua` @ `e973acb` | `3c6b405084612743396d68cbf1938de8bdcd8464` | `scripts/fetch_fixtures.py`: `git show e973acb:<path>` dal checkout locale o GitHub allo stesso commit, hash verificato; non versionata (`.gitignore`); controllata anche da `tests/test_fixtures.py` |
| `tests/fixtures/hcob/diagnostic_pixel_edge.lua` | `tests/diagnostic_pixel_edge.lua` @ `e973acb` | `ac792476979bc27dbaa91665e89e2a060645086f` | idem |
| Campione `2687 6603 284 6546` | contesto storico della specifica | — | solo input di una coda simulata in `tests/test_no_decisions.lua` (prima in `tests/test_justac_adapter.lua`, rimosso), nessuna aspettativa RGB inventata |
| File di dati di JustAC 6.0.0 | `Data/Forever/Rotations.lua`, `Defaults.lua`, `Consumables.lua`, `Data/InterruptAbilities.lua`, `Data/CCBreakers.lua` | SHA-256 in `scripts/import_justac_data.py` | letti dall'installazione locale di JustAC; i file generati sono versionati in `ForeverOneButton/Data/` |
