# Milestone

| Fase | Stato | Evidenza di uscita | Pendente |
|---|---|---|---|
| 0 — Baseline | completata | `REPOSITORY_AUDIT.md`, `GIT_CONFIGURATION.md`; repository inizializzato e pubblicato | ripristino della voce `lfs` nella config locale HCOB (azione dell'utente, `GIT_CONFIGURATION.md` §5) |
| 1 — Audit e specifica | completata | matrice in `PROTOCOL_COMPATIBILITY.md`, inventario in `ACTION_PANEL_DESIGN.md`, esclusioni in `ARCHITECTURE.md`, fixture con provenienza | — |
| 2 — Scheletro e adapter JustAC | completata | `ForeverOneButton.toc`, `Bridge/JustACAdapter.lua`, `test_justac_adapter.lua` | caricamento sul client |
| 3 — Telemetria e pixel | completata offline | `Pixel/DiagnosticPixel.lua`, `test_pixel_differential.lua`, `test_original_regression.lua`, `test_protocol_v3.lua` | cattura reale a schermo |
| 4 — Action Panel e binding | completata offline | `Panel/*`, `UI/Options.lua`, `test_panel_bindings.lua`, `test_options_whitelist.lua`, `test_grid_pixel_isolation.lua`, `test_no_decisions.lua` | prove visive e secure in gioco |
| 5 — Verifica su Forever | **non eseguita** | procedura in `RUNTIME_CHECKLIST.md` | tutte le voci A–E |
| 6 — Packaging e consegna | completata (senza release) | `dist/ForeverOneButton-0.2.0.zip` verificato, CI verde, branch `feat/forever-one-button`, PR verso `main` | merge, tag, release: richiedono autorizzazione |

## Criteri di accettazione

| # | Criterio | Valutazione | Evidenza |
|---|---|---|---|
| 1 | JustAC unico Advisor, `GetCurrentSpellQueue` sorgente verificata | **soddisfatto** (offline) | adapter + `PROTOCOL_COMPATIBILITY.md` §4; scansione/tripwire |
| 2 | Ordine e semantica della coda; conversioni documentate | **soddisfatto** | `test_justac_adapter`, §4 conversioni |
| 3 | Nessuna logica decisionale HCOB | **soddisfatto** | `ARCHITECTURE.md` prova; `test_no_decisions` |
| 4 | UI da zero a griglia; inventario tracciato | **soddisfatto** (offline) | `ACTION_PANEL_DESIGN.md` |
| 5 | Encoding e layout dimostrati dal codice originale con test differenziali | **soddisfatto** per il producer | `test_pixel_differential`, fixture con hash |
| 7 | Invalidità/assenza senza fallback né raccomandazioni obsolete | **soddisfatto** (offline) | `test_protocol_v3`, `test_no_decisions` |
| 8 | API Forever, combattimento, secret values secondo evidenze del target | **parziale** | politiche implementate e testate su mock; prove sul client pendenti |
| 9 | Suite e prove runtime | **parziale** | suite verdi; runtime elencate come mancanti |
| 10 | Opzioni solo binding e UI/pixel, con whitelist | **soddisfatto** (più `autoFill`, chiesto dal proprietario) | `BINDINGS_AND_OPTIONS.md`, `test_options_whitelist` |
| 11 | Nessuno spam, pull, input automatico | **soddisfatto** | `test_no_decisions`, nessun `OnClick`, mock delle API di esecuzione |
| 12 | Griglia non altera contratto pixel | **soddisfatto offline**; cattura reale pendente | `test_grid_pixel_isolation` |
| 13 | Nomi coerenti | **soddisfatto** | `test_toc` |
| 14 | Pacchetto completo e pulito | **soddisfatto** | `test_package`, verifica del pacchetto |
| 15 | Git/GitHub allineati con matrice e prerequisiti | **soddisfatto** con un'anomalia documentata | `GIT_CONFIGURATION.md` |

Conclusione: consegna **parziale / verifica pendente**.

## Decisioni rinviate

- **Disposizione fissa per classe (tutte le spell imparate, ordine deterministico, max 20 celle)** - rinviata dal proprietario il 2026-10-15 all'uscita ufficiale di WoW Forever (oggi in beta). Resta il riempimento automatico dal pool di JustAC piu i gap closer (correzione della Carica mancante, evidenza nel log del primo test). Per riprendere: eseguire `/fob probe spellbook` (gia incluso, sola lettura) su ogni classe disponibile, verificare se il libro incantesimi elenca le spell future e le abilita da talento, poi derivare la disposizione dai dati del client (`BINDINGS_AND_OPTIONS.md`).
