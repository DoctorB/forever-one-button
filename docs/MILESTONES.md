# Milestone

## Fasi fino alla 0.2.0

| Fase | Stato | Evidenza di uscita | Pendente |
|---|---|---|---|
| 0 — Baseline | completata | `REPOSITORY_AUDIT.md`, `GIT_CONFIGURATION.md`; repository inizializzato e pubblicato | ripristino della voce `lfs` nella config locale HCOB (azione dell'utente, `GIT_CONFIGURATION.md` §5) |
| 1 — Audit e specifica | completata | matrice in `PROTOCOL_COMPATIBILITY.md`, inventario in `ACTION_PANEL_DESIGN.md`, esclusioni in `ARCHITECTURE.md`, fixture con provenienza | — |
| 2 — Scheletro e adapter JustAC | completata, poi sostituita | `ForeverOneButton.toc`, `Bridge/JustACAdapter.lua` (rimosso nella 1.0.0 con `test_justac_adapter.lua`) | — |
| 3 — Telemetria e pixel | completata offline | `Pixel/DiagnosticPixel.lua`, `test_pixel_differential.lua`, `test_original_regression.lua`, `test_protocol_v3.lua` | cattura reale a schermo |
| 4 — Action Panel e binding | completata offline | `Panel/*`, `UI/Options.lua`, `test_panel_bindings.lua`, `test_options_whitelist.lua`, `test_grid_pixel_isolation.lua`, `test_no_decisions.lua` | prove visive e secure in gioco |
| 5 — Verifica su Forever | **parziale** | primo test in gioco del 2026-10-15 (`TEST_REPORT.md`); procedura in `RUNTIME_CHECKLIST.md` | le altre voci A–F |
| 6 — Packaging e consegna | completata (senza release) | `dist/ForeverOneButton-0.2.0.zip` verificato, CI verde, branch `feat/forever-one-button`, PR verso `main` | merge, tag, release: richiedono autorizzazione |

## Fasi della 1.0.0 (motore interno)

Decisione del proprietario del 2026-10-16: JustAC viene sostituito da un
motore interno. Motivo: in gioco JustAC 6.0.0 suggeriva in ciclo Postura
difensiva e Postura da battaglia al Guerriero. JustAC resta la fonte dei dati
importati (liste di priorità derivate da wowsims).

| Fase | Stato | Evidenza di uscita | Pendente |
|---|---|---|---|
| 1 — Dati e licenza | completata | `Data/*.lua` generati da `scripts/import_justac_data.py` (+ `scripts/import_justac_data.lua`) dai file di JustAC 6.0.0 con SHA-256 fissati; licenza GPL-3.0-or-later, attribuzioni in `ForeverOneButton/NOTICE.md`; `test_data.lua` | — |
| 2 — Stato | completata offline | `Engine/Secret.lua`, `Ranks.lua`, `State.lua`; `test_state.lua` | comportamento reale dei valori segreti |
| 3 — Motore di rotazione | completata offline | `Engine/Gates.lua`, `Dots.lua`, `Trees.lua`, `Queue.lua`; `test_gates.lua`, `test_queue.lua` (nessun ciclo di posture) | — |
| 4 — Collegamento e rimozione di JustAC | completata | `Bridge/Model.lua` legge `Engine/Queue.lua`; `Panel/AutoFill.lua` dal pool del motore; nessun `OptionalDeps`; `test_autofill_pool.lua`, `test_toc.lua`, `test_no_decisions.lua` (`JustAC`, `LibStub` vietati nel codice) | — |
| 5 — Burst | completata offline | `Queue.lua` `ApplyBurst`, bordo viola in `Panel/Grid.lua`, `Settings.FEATURES`, pagina *Features*, `/fob features`/`/fob feature` | — |
| 6 — Interruzioni | completata offline | `Engine/Interrupts.lua`, icona a sinistra della griglia; `test_interrupts.lua` | — |
| 7 — Difensivi | completata offline | `Engine/Defensives.lua`, colonna a destra, cella automatica dell'oggetto di cura; `test_defensives.lua` | — |
| 8 — Promemoria | completata offline | `Engine/Precombat.lua`, `Panel/Reminders.lua`; `test_reminders.lua` | — |
| 9 — Documentazione | completata | documenti in `docs/` aggiornati | — |
| 10 — Test in gioco con il Guerriero | **pendente** | `RUNTIME_CHECKLIST.md` §F | tutte le voci F |

## Criteri di accettazione

I criteri 1–3 chiedevano "JustAC unico Advisor, nessuna logica decisionale
propria". Con la decisione del 2026-10-16 sono riformulati: le decisioni
stanno solo in `Engine/` e vengono dai dati importati; restano esclusi input
automatico, spam e pull.

| # | Criterio | Valutazione | Evidenza |
|---|---|---|---|
| 1 | Decisioni solo in `Engine/`, dai dati importati in `Data/` (generati con hash fissati) | **soddisfatto** (offline) | `test_no_decisions` (lessico decisionale solo in `Engine/`), `test_data`, `ARCHITECTURE.md` |
| 2 | Ordine e semantica della coda; conversioni verso il protocollo documentate | **soddisfatto** (offline) | `test_queue`, `PROTOCOL_COMPATIBILITY.md` §4 |
| 3 | Nessuna logica decisionale HCOB; nessun input automatico, spam o pull | **soddisfatto** | `ARCHITECTURE.md` prova; `test_no_decisions`; `test_reminders` (nessun gestore di clic Lua) |
| 4 | UI da zero a griglia; inventario tracciato | **soddisfatto** (offline) | `ACTION_PANEL_DESIGN.md` |
| 5 | Encoding e layout dimostrati dal codice originale con test differenziali | **soddisfatto** per il producer | `test_pixel_differential`, fixture con hash |
| 7 | Invalidità/assenza senza fallback né raccomandazioni obsolete | **soddisfatto** (offline) | `test_protocol_v3`, `test_no_decisions` |
| 8 | API Forever, combattimento, secret values secondo evidenze del target | **parziale** | politiche implementate e testate su mock; API del motore non provate in gioco |
| 9 | Suite e prove runtime | **parziale** | 23 suite Lua e 7 test Python verdi; runtime elencate come mancanti |
| 10 | Opzioni con whitelist | **soddisfatto** (più `autoFill`, `hideBlizzardBar` e `features`, chiesti dal proprietario) | `BINDINGS_AND_OPTIONS.md`, `test_options_whitelist` |
| 11 | Nessuno spam, pull, input automatico | **soddisfatto** | `test_no_decisions`, nessun `OnClick`, mock delle API di esecuzione; promemoria solo al clic del giocatore |
| 12 | Griglia non altera contratto pixel | **soddisfatto offline**; cattura reale pendente | `test_grid_pixel_isolation` |
| 13 | Nomi coerenti | **soddisfatto** | `test_toc` |
| 14 | Pacchetto completo e pulito | **soddisfatto** | `test_package`, `dist/ForeverOneButton-1.0.0.zip` (34 voci verificate) |
| 15 | Git/GitHub allineati con matrice e prerequisiti | **soddisfatto** con un'anomalia documentata | `GIT_CONFIGURATION.md` |

Conclusione: consegna **parziale / verifica in gioco pendente**.

## Decisioni rinviate

- **Disposizione fissa per classe (tutte le spell imparate, ordine deterministico, max 20 celle)** - rinviata dal proprietario il 2026-10-15 all'uscita ufficiale di WoW Forever (oggi in beta). Resta il riempimento automatico dal pool del motore (lista dell'albero attivo, gap closer, interruzioni, difensivi, oggetto di cura). Per riprendere: eseguire `/fob probe spellbook` (già incluso, sola lettura) su ogni classe disponibile, verificare se il libro incantesimi elenca le spell future e le abilità da talento, poi derivare la disposizione dai dati del client (`BINDINGS_AND_OPTIONS.md`).
