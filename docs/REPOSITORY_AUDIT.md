# Audit dei repository (Fase 0)

Data: 2026-10-15. Tutti i repository di riferimento sono stati usati in sola
lettura (eccezione involontaria documentata in `GIT_CONFIGURATION.md` §5).

## Repository

| Repository | Percorso | Origine | Branch / commit | Stato locale | Licenza | Istruzioni |
|---|---|---|---|---|---|---|
| Forever One Button (destinazione) | `C:\Work\forever-one-button` | `https://github.com/DoctorB/forever-one-button.git` | `main` `0eb4942`; lavoro su `feat/forever-one-button` | prima: cartella non Git con la sola specifica | MIT | specifica del proprietario (non inclusa nel repository) |
| HCOneButton (riferimento) | `C:\Work\hc-one-button` | `https://github.com/DoctorB/hc-one-button.git` | `main` = `origin/main` = `e973acba84e3911ddb6a68655d247426df7bdf4f` (1.29.18) | un file non tracciato preesistente: `docs/FOREVER_FEASIBILITY.md` (lasciato intatto) | MIT, (c) 2026 DoctorB | `docs/RELEASING.md` |
| JustAC (riferimento) | `C:\Work\JustAC` (clonato durante l'audit) | `https://github.com/wealdly/JustAC.git` | `main` `431e9a220dc3cf4bbfe8c05818a1de88ee40fa14` (tag `v5.9.0-beta2`, 2026-10-08) | pulito | GPL-3.0-or-later, (C) 2024-2026 wealdly | `AGENTS.md`, `Documentation/STYLE_GUIDE_JUSTAC.md` |
| JustAC installato | `…\_classic_beta_\Interface\AddOns\JustAC` | — | 5.9.0-beta2 | identico a `431e9a2` per tutti i file dell'addon (`diff -r`); `LICENSE` differisce solo per CRLF | — | — |
| Forever ChatGuard (evidenza Forever) | `C:\Work\forever-chatguard` | `https://github.com/DoctorB/forever-chatguard.git` | `5ad4ac4` | 2 png non tracciati | — | target solo Forever |
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

- Runtime: JustAC (opzionale nel TOC; senza, stato esplicito). Nessuna
  libreria incorporata.
- Nessun codice JustAC incluso (solo chiamata runtime all'API pubblica):
  nessun obbligo GPL sul pacchetto.
- Codice HCOB riusato (MIT, stesso autore) con attribuzione in
  `ForeverOneButton/NOTICE.md`.

## Fixture con provenienza

| Fixture | Origine | Blob Git | Acquisizione |
|---|---|---|---|
| `tests/fixtures/hcob/DiagnosticPixel.lua` | `HCOneButton/UI/DiagnosticPixel.lua` @ `e973acb` | `3c6b405084612743396d68cbf1938de8bdcd8464` | `scripts/fetch_fixtures.py`: `git show e973acb:<path>` dal checkout locale o GitHub allo stesso commit, hash verificato; non versionata (`.gitignore`); controllata anche da `tests/test_fixtures.py` |
| `tests/fixtures/hcob/diagnostic_pixel_edge.lua` | `tests/diagnostic_pixel_edge.lua` @ `e973acb` | `ac792476979bc27dbaa91665e89e2a060645086f` | idem |
| Campione `2687 6603 284 6546` | contesto storico della specifica | — | solo input in `tests/test_justac_adapter.lua`, nessuna aspettativa RGB inventata |
