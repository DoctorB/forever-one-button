# Report dei test

Stato complessivo: **parziale / verifica pendente**. Tutte le prove offline
passano in locale (Windows) e in CI (Linux). Nessuna prova in gioco è stata
eseguita.

## Ambienti

| Ambiente | Dettagli |
|---|---|
| Locale | Windows 11, Lua 5.1.5, Python 3.14 (`py`), Windows PowerShell 5.1; 2026-10-15 |
| CI | GitHub Actions `ubuntu-24.04`, `lua5.1` da apt, `python3`, `pwsh`; workflow `CI` |

## Comandi

```text
powershell -NoProfile -ExecutionPolicy Bypass -File tests/run.ps1   # tutto
python scripts/package.py build                                     # pacchetto + verifica
```

## Risultati automatici

| Suite | Cosa prova | Esito |
|---|---|---|
| `luac -p` su 12 file addon e 11 suite | sintassi Lua 5.1 | 12/12, 11/11 |
| `test_justac_adapter.lua` | libreria assente/tardiva, metodo assente, errore, risultati non conformi (numero, stringa, frazione, zero, secret, tabella non accessibile), coda vuota/1/n, duplicati, item, `WAIT_SENTINEL` (registrato e live), buchi, voci segrete, isolamento dello snapshot dalla mutazione in place, nessuna scrittura nella tabella JustAC, riuso dello snapshot invariato, minor non verificato, chiamata con punto senza argomenti, campione `2687 6603 284 6546` | PASS |
| `test_original_regression.lua` | regressione HCOB `diagnostic_pixel_edge.lua` immutata sul producer originale congelato | PASS |
| `test_pixel_differential.lua` | producer originale vs porting: setup del frame, casi della regressione, 20 slot, 3000 operazioni casuali, flusso completo di colori | PASS (2272 operazioni, 1593 scritture identiche) |
| `test_protocol_v3.lua` | coda JustAC → colore a 8 bit per 20 celle, esempi esadecimali del README, solo posizione 1 codificata, nero per vuoto/wait/non leggibile/errore/cast/canale segreto/fuori portata, portata segreta o nil ≠ fuori portata, JustAC che scompare (nessun segno obsoleto), item e ACK via spell dell'item, override → cella base, pixel solo in combattimento (nero fuori, pubblicazione immediata a inizio combattimento, ACK in combattimento, nero immediato a fine combattimento, opzione disattivabile, griglia sempre attiva); decoder derivato dalla specifica | PASS |
| `test_grid_pixel_isolation.lua` | catena di ancoraggio del pixel senza griglia, ogni opzione griglia ai limiti, spostamento, nascondere, scala diretta della griglia: rettangolo/scala/visibilità/strata/colore del pixel invariati; dimensione 8×8 × scala UIParent; rilevazione sovrapposizione; maniglia che non copre il pixel | PASS |
| `test_panel_bindings.lua` | scacchiera, nomi pulsanti, `type1`, duplicati, slot 21, tasti normalizzati/rifiutati/in conflitto, binding WoW coperto, tasto mancante, tasto su cella vuota, segni di posizione e striscia in ordine JustAC, suggerimento non associato, 50 cambi di coda senza modifiche a celle/tasti/binding, rifiuti in combattimento (anche drag & drop), celle nascoste, persistenza e reload, reload in combattimento con applicazione differita e pixel bianco nel frattempo, `useOnKeyDown`/click registrati | PASS |
| `test_autofill.lua` | nessun pool senza JustAC, ordine del pool, prima cella libera, nessuno spostamento al cambio di ordine, raffiche raggruppate, rango nuovo nella stessa cella e vecchio rango mappato sulla stessa cella, override non duplicati, spell rimosse non reinserite, celle manuali intatte, overflow oltre 20, rinvio in combattimento, coda JustAC mai consultata, pool segreto, disattivazione, celle per personaggio, migrazione 0.1.0, tabella JustAC non modificata | PASS |
| `test_options_whitelist.lua` | sanitizzazione (chiavi sconosciute, spam/pull/priority eliminati, limiti, duplicati), dati HCOB non importati né modificati, controlli della finestra (4 checkbox, 6 opzioni numeriche, 20 righe), nessun controllo escluso, cattura tasti (modificatori, ESC, rotella), chiusura in combattimento | PASS |
| `test_no_decisions.lua` | scansione statica del codice spedito (HCOB/Advisor/spam/pull/API di esecuzione/`SetBinding`/`macrotext`/`C_AssistedCombat`/API interne JustAC), timer presenti, tripwire su `HCOneButton`/`HCOB_DB`/punti di ingresso dell'Advisor durante assenza/errore/dati errati di JustAC, combattimento, cast e tutti i comandi; nessun `OnClick` Lua; mock che conta ogni API di esecuzione | PASS |
| `test_diagnostics.lua` | log spento di default, "spam" della stessa spell in combattimento → un fronte nero ≥ 60 ms per ogni lancio riuscito con ritorno allo stesso colore, lancio estraneo e ID segreto registrati senza errori, persistenza dopo reload, limite di dimensione, report in chat | PASS |
| `test_analyze_log.py` | analisi del file SavedVariables: fronti, durate, fronti troppo corti o non chiusi, ID segreti | PASS |
| `test_toc.lua` | Interface 16001, titolo, SavedVariables, OptionalDeps JustAC, versione = runtime, file elencati esistenti e nessun file orfano, globali consentite | PASS |
| `test_bench.lua` | costo del refresh e memoria | PASS (vedi sotto) |
| `test_fixtures.py` | hash blob Git delle fixture = `e973acb` (scaricate da `scripts/fetch_fixtures.py` all'avvio di `tests/run.ps1`) | PASS |
| `test_package.py` | contenuto completo, radice unica, niente test/fixture, LF, riproducibilità byte per byte, rifiuto di voci extra/fuori radice/contenuti vietati | PASS |
| `scripts/package.py build` | `dist/ForeverOneButton-0.2.0.zip`, 16 voci verificate | PASS |
| CI `38696430512` | stesse suite su Linux | success |

### Prestazioni (mock, Lua 5.1 interpretato)

| Caso | Tempo per refresh | Allocazione per refresh |
|---|---|---|
| Coda invariata (caso comune) | ~3–4 µs | 0 KB |
| Coda diversa ad ogni refresh, posizione 1 non associata (scansione override di 20 celle) | ~55–64 µs | 3,6 KB |
| Memoria trattenuta dopo 20 000 refresh | 25 KB (stabile) | — |

Soglia: < 500 µs, cioè < 1 % dell'intervallo di polling di 50 ms (motivato dal
throttle di JustAC). Non è un requisito dell'originale; il costo sul client va
misurato (checklist E23).

## Difetti trovati e corretti durante i test

1. Dopo un `/reload` in combattimento la creazione delle celle impostava un
   attributo secure (`useOnKeyDown`) e un `Hide` protetto: spostati
   nell'applicazione fuori combattimento, insieme a `RegisterForClicks`.
2. Allocazioni a ogni refresh anche con coda invariata: lo snapshot
   (immutabile) viene ora riusato.

## Prima prova in gioco (2026-10-15, log diagnostico)

Client 1.60.1.70374, Guerriero livello 12, 2 combattimenti, analizzato con
`scripts/analyze_log.py`:

| Verifica | Esito |
|---|---|
| Pixel nero fuori combattimento, attivo subito all'ingaggio, nero subito all'uscita | OK |
| `UNIT_SPELLCAST_SUCCEEDED` del player in combattimento, `spellID` leggibile | OK (18 lanci, 0 segreti) |
| Fronte ACK dopo ogni lancio riuscito della spell codificata | OK: 9 lanci riconosciuti, 8 fronti + 1 riavviato (due Auto Attack a 30 ms) |
| Durata del fronte | 57,8–94,9 ms sull'orologio di precisione; un fronte < 60 ms è un artefatto della misura (il timer e lo schermo usano il tempo di frame `GetTime`, come in HCOneButton). Da ora il log registra il tempo di frame e l'analisi lo usa: da riconfermare con un nuovo log |
| Carica suggerita da JustAC (`head|100`) senza cella | **difetto**: corretto aggiungendo i gap closer al riempimento automatico |

## Prove non eseguite (limiti)

| Prova | Motivo | Riferimento |
|---|---|---|
| Cattura reale del pixel a schermo | richiede il client in esecuzione con un personaggio | `RUNTIME_CHECKLIST.md` D |
| Caricamento dell'addon sul client, errori Lua | idem | A |
| Pulsanti secure, binding override, `ActionButtonUseKeyDown` su Forever | idem | B |
| Valori segreti reali in combattimento/istanza | i mock non provano il comportamento del client | E20 |
| Taint | idem | E21 |
| Costo reale in combattimento | idem | E23 |

## Confronto con la baseline

HCOB: 1 regressione pixel (`diagnostic_pixel_edge.lua`) + controlli di
codifica in `action_panel_layout.lua`. Qui la
regressione originale gira immutata e il porting è confrontato con il
producer originale sull'intero flusso di colori.

## Rischi concreti

- API secure/binding non ancora provate su Forever: un comportamento diverso
  renderebbe le celle non eseguibili (il pixel resterebbe comunque corretto
  rispetto a ciò che le celle fanno solo dopo l'applicazione).
