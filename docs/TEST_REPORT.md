# Report dei test

Stato complessivo: **parziale / verifica pendente**. Versione 1.0.0 (motore
interno). Tutte le prove offline passano in locale (Windows); in CI (Linux)
sono verdi fino al commit `37e2656`. Il motore interno non è ancora stato
provato in gioco; l'unica prova in gioco (2026-10-15) riguarda la 0.2.0 con
JustAC.

## Ambienti

| Ambiente | Dettagli |
|---|---|
| Locale | Windows 11, Lua 5.1.5, Python 3.14 (`py`), Windows PowerShell 5.1; 2026-10-16 |
| CI | GitHub Actions `ubuntu-24.04`, `lua5.1` da apt, `python3`, `pwsh`; workflow `CI` |

## Comandi

```text
powershell -NoProfile -ExecutionPolicy Bypass -File tests/run.ps1   # tutto (scarica le fixture HCOB con scripts/fetch_fixtures.py)
python scripts/package.py build                                     # pacchetto + verifica
```

## Risultati automatici (2026-10-16)

| Suite | Cosa prova | Esito |
|---|---|---|
| `scripts/fetch_fixtures.py` | fixture HCOB scaricate e verificate | 2 verificate |
| `luac -p` su 30 file addon e 23 suite | sintassi Lua 5.1 | 30/30, 23/23 |
| `test_data.lua` | i 5 file `Data/` hanno intestazione di licenza e copyright, una sola tabella, nessuna funzione né chiamata; liste per ogni classe con condizioni e spell ID validi; albero di default del Guerriero, Arms finisce con Postura da battaglia, Protection con Postura difensiva; gap closer, trigger di burst, difensivi del Guerriero; Pummel e Shield Bash (Forever); oggetti di cura; breaker per la paura | PASS |
| `test_state.lua` | `Secret.IsZero` in chiaro e segreto, soglie salute/potere in chiaro e segrete (anche vicine e per la rabbia), sconosciuto senza bersaglio o senza API delle curve, memo di 0,1 s; ranghi (base, più alto conosciuto, rango sulle barre); usabile/risorse, cooldown (GCD escluso), portata, bersaglio, boss, nemici ingaggiati dalle nameplate, posture, buff (aura, scadenza ricordata, lancio recente), stack, swing, combo, furtività, totem | PASS |
| `test_gates.lua` | tutti i tipi di condizione, operatori, `any`/`all` a tre valori, tipo sconosciuto e `tick` senza opinione, solo `false` blocca | PASS |
| `test_queue.lua` | stato, albero di default e albero con più punti, ordine della lista Arms, testa, snapshot riusato, rango 2, rabbia insufficiente, DoT attivo e nuovo bersaglio, wait senza testa del pixel, Carica come gap closer e debounce, Execute, contesto aoe, **Postura difensiva da Postura da battaglia per Protection, Postura da battaglia per Arms in Postura difensiva, Arms in Postura da battaglia mai Postura difensiva**, burst in posizione 2 (non fuori combattimento, non con l'opzione spenta, non su un bersaglio non boss morente, sì su un boss), classe senza lista | PASS |
| `test_autofill_pool.lua` | pool Arms e Protection del Guerriero dal motore, ordine delle celle (Battle Shout 1, Carica 8, Shield Wall 11), nulla oltre il pool, nessun pool senza lista | PASS |
| `test_interrupts.lua` | nessun cast, Pummel/Shield Bash (scudo, cooldown, portata), flag segreto = interrompibile, debounce, cast schermato con o senza controllo, modalità `kickOnly`/`kickPrefer`/`ccPrefer`, paure, boss, mob banali e minion, canale, opzione spenta; icona, cast nell'angolo, tasto, segno "!" e rimozione a fine cast | PASS |
| `test_defensives.lua` | fasce di salute, ordine per livello, oggetto trattenuto finché non serve, cooldown, pozione usata nel combattimento, fuori combattimento sotto il 50 %, salute sconosciuta, breaker, pet (cura, resurrezione); colonna, segno "D", voce attenuata, nascosta in salute; cella automatica della pozione, sostituzione con una migliore, esclusione dopo `Clear` | PASS |
| `test_reminders.lua` | buff di classe mancanti o in scadenza (solo / in gruppo, membro del gruppo), bevanda, consumabili filtrati per classe, categoria spenta, pietra per armi, imbue dello sciamano, cibo/benda/"Recently Bandaged", furtività, mai in combattimento o in sella, opzione spenta; riga nascosta in combattimento dal client, pulsanti spell/item, spell offerta esclusa dalla coda, nessuna riconfigurazione in combattimento, aggiornamento dopo il combattimento, nessun gestore di clic Lua | PASS |
| `test_original_regression.lua` | regressione HCOB `diagnostic_pixel_edge.lua` immutata sul producer originale congelato | PASS |
| `test_pixel_differential.lua` | producer originale vs porting: setup del frame, casi della regressione, 20 slot, 3000 operazioni casuali, flusso completo di colori | PASS (2272 operazioni, 1593 scritture identiche) |
| `test_protocol_v3.lua` | coda → colore a 8 bit per 20 celle, esempi esadecimali del README, solo posizione 1 codificata, nero per vuoto/wait/errore del motore/nessuna lista/cast/canale segreto/fuori portata, portata segreta o nil ≠ fuori portata, item e ACK via spell dell'item, override → cella base, pixel solo in combattimento (nero fuori, pubblicazione immediata a inizio combattimento, ACK in combattimento, nero immediato a fine combattimento, opzione disattivabile, griglia sempre attiva); decoder derivato dalla specifica | PASS |
| `test_grid_pixel_isolation.lua` | catena di ancoraggio del pixel senza griglia, ogni opzione griglia ai limiti, spostamento, nascondere, scala diretta della griglia: rettangolo/scala/visibilità/strata/colore del pixel invariati; dimensione 8×8 × scala UIParent; rilevazione sovrapposizione; maniglia che non copre il pixel | PASS |
| `test_grid_move.lua` | barra del titolo, blocco/sblocco col tasto destro, trascinamento, posizione salvata e ripristinata, fine del trascinamento all'ingaggio | PASS |
| `test_panel_bindings.lua` | scacchiera, nomi pulsanti, `type1`, duplicati, slot 21, tasti normalizzati/rifiutati/in conflitto, binding WoW coperto, tasto mancante, tasto su cella vuota, segni di posizione e striscia in ordine di coda, suggerimento non associato, cambi di coda senza modifiche a celle/tasti/binding, rifiuti in combattimento (anche drag & drop), celle nascoste, persistenza e reload, reload in combattimento con applicazione differita e pixel bianco nel frattempo, `useOnKeyDown`/click registrati | PASS |
| `test_autofill.lua` | nessun pool, ordine del pool, prima cella libera, nessuno spostamento, raffiche raggruppate, rango nuovo nella stessa cella e vecchio rango mappato sulla stessa cella, override non duplicati, spell rimosse non reinserite, celle manuali intatte, overflow oltre 20, rinvio in combattimento, coda mai consultata, disattivazione, celle per personaggio, migrazione 0.1.0 | PASS |
| `test_options_whitelist.lua` | sanitizzazione (chiavi sconosciute, spam/pull/priority eliminati, limiti, duplicati), whitelist e default di `features`, `/fob feature` senza distinzione di maiuscole, valori rifiutati, dati HCOB non importati né modificati, controlli della finestra (checkbox, 6 opzioni numeriche, 20 righe, pagina *Features*), nessun controllo escluso, cattura tasti (modificatori, ESC, rotella), chiusura in combattimento | PASS |
| `test_no_decisions.lua` | scansione statica del codice spedito (HCOB/Advisor/spam/pull/API di esecuzione/`SetBinding`/`macrotext`/`AssistedCombat`/`JustAC`/`LibStub`; lessico decisionale solo in `Engine/`), 4 timer, tripwire su `HCOneButton`/`HCOB_DB`/punti di ingresso dell'Advisor durante assenza di lista, errore del motore, code diverse, combattimento, cast e tutti i comandi; nessun `OnClick` Lua | PASS |
| `test_diagnostics.lua` | log spento di default, stessa spell lanciata più volte in combattimento → un fronte nero ≥ 60 ms per ogni lancio riuscito con ritorno allo stesso colore, lancio estraneo e ID segreto registrati senza errori, persistenza dopo reload, limite di dimensione, report in chat | PASS |
| `test_probe.lua` | `/fob probe spellbook`: abilità di classe dai dati importati, gap closer, spell future, passive, ID segreto; nessuna cella o binding modificato | PASS |
| `test_blizzard_bar.lua`, `test_blizzard_bar_modern.lua` | barra Blizzard nascosta e ripristinata (layout classico e moderno), posture ed esperienza visibili, nessun binding toccato, rinvio in combattimento | PASS |
| `test_toc.lua` | Interface 16001, titolo, SavedVariables, nessun `OptionalDeps`, versione = runtime (1.0.0), file elencati esistenti e nessun file orfano, globali consentite | PASS |
| `test_bench.lua` | costo del refresh e memoria | PASS (vedi sotto) |
| `test_analyze_log.py` (3 test) | analisi del file SavedVariables: fronti, durate, fronti troppo corti o non chiusi, ID segreti | PASS |
| `test_fixtures.py` (1 test) | hash blob Git delle fixture = `e973acb` | PASS |
| `test_package.py` (3 test) | contenuto completo, radice unica, niente test/fixture, LF, riproducibilità byte per byte, rifiuto di voci extra/fuori radice/contenuti vietati | PASS |
| `scripts/package.py build` | `dist/ForeverOneButton-1.0.0.zip`, 34 voci verificate | PASS |
| CI `38873883869` (commit `37e2656`) | stesse suite su Linux, prima del passaggio della versione a 1.0.0 | success |

Totale: 23 suite Lua su 23 e 7 test Python su 7.

### Prestazioni (mock, Lua 5.1 interpretato)

| Caso | Tempo per refresh | Allocazione per refresh |
|---|---|---|
| Coda invariata (caso comune; coda simulata) | ~6–7 µs | 0,49 KB |
| Coda diversa ad ogni refresh, posizione 1 non associata (scansione override di 20 celle; coda simulata) | ~61–63 µs | 4,6 KB |
| Motore reale: Guerriero Arms in combattimento, tutte le spell della lista conosciute | ~197 µs | 15,4 KB |
| Memoria trattenuta dopo 20 000 refresh | 25,4 KB (stabile) | — |

Soglie: < 500 µs per refresh con coda simulata (< 1 % dell'intervallo di
polling di 50 ms) e < 2500 µs per il motore reale (< 5 %). Non è un requisito
dell'originale; il costo sul client va misurato (checklist E23).

## Difetti trovati e corretti durante i test

1. Dopo un `/reload` in combattimento la creazione delle celle impostava un
   attributo secure (`useOnKeyDown`) e un `Hide` protetto: spostati
   nell'applicazione fuori combattimento, insieme a `RegisterForClicks`.
2. Allocazioni a ogni refresh anche con coda invariata: lo snapshot
   (immutabile) viene ora riusato.

## Prima prova in gioco (2026-10-15, 0.2.0 con JustAC, log diagnostico)

Client 1.60.1.70374, Guerriero livello 12, 2 combattimenti, analizzato con
`scripts/analyze_log.py`:

| Verifica | Esito |
|---|---|
| Pixel nero fuori combattimento, attivo subito all'ingaggio, nero subito all'uscita | OK |
| `UNIT_SPELLCAST_SUCCEEDED` del player in combattimento, `spellID` leggibile | OK (18 lanci, 0 segreti) |
| Fronte ACK dopo ogni lancio riuscito della spell codificata | OK: 9 lanci riconosciuti, 8 fronti + 1 riavviato (due Auto Attack a 30 ms) |
| Durata del fronte | 57,8–94,9 ms sull'orologio di precisione; un fronte < 60 ms è un artefatto della misura (il timer e lo schermo usano il tempo di frame `GetTime`, come in HCOneButton). Da ora il log registra il tempo di frame e l'analisi lo usa: da riconfermare con un nuovo log |
| Carica suggerita (`head|100`) senza cella | **difetto**: corretto aggiungendo i gap closer al riempimento automatico |

Seconda prova in gioco (2026-10-16, JustAC 6.0.0, log diagnostico di un
combattimento di 34 s): dopo Bloodrage e Battle Shout la posizione 1 di JustAC
ha alternato per tutto il combattimento Defensive Stance (71) → wait → Battle
Stance (2457) → wait, 15 lanci per ciascuna postura, mai Heroic Strike, Rend o
Sunder; le icone di JustAC mostravano lo stesso ciclo (conferma del
proprietario). L'addon riportava fedelmente la coda: celle, tasti e 33 lanci
riconosciuti corretti, pixel nero fuori combattimento, mai bianco. È il motivo
della sostituzione di JustAC con il motore interno; la correzione è provata
solo offline (`test_queue.lua`), non ancora in gioco.

## Prove in gioco del motore interno (2026-10-16, 1.0.0)

Guerriero livello 13, talenti Fury, client 1.60.1.70425, log diagnostico
(righe `queue`, `head`, `pixel`, `cast`, `defense`, `interrupt`), una decina di
combattimenti contro uno o più mob.

| Verifica | Esito | Evidenza |
|---|---|---|
| Albero e contesto | **verificato**: `fury`, `st` con un nemico, `aoe` con tre, ritorno a `st` | righe `queue` |
| Liste di livellamento | **verificato**: `fury+leveling`; Bloodrage, Battle Shout, Rend (anche su bersagli nuovi), Sunder una volta per bersaglio, Thunder Clap in aoe, Heroic Strike, Overpower dopo una schivata | righe `head` e `cast` |
| Nessun ciclo di posture | **verificato**: nessuna postura in coda in Postura da battaglia | righe `head` |
| Pixel | **verificato**: ogni suggerimento pronto codificato (celle 2, 3, 4, 6, 7, 8), nero dopo ogni lancio riconosciuto, nero in "wait" e fuori combattimento | righe `pixel` |
| Riga promemoria | **verificato**: il clic sul cibo fa mangiare | conferma del proprietario, lanci 433 / 1248380 |
| Cella automatica dell'oggetto di cura | **verificato**: svuotata senza pozioni nelle borse | conferma del proprietario |
| "Wait" | 64-71 % del tempo contro mob singoli: rabbia esaurita a questo livello | righe `head` |
| Interruzioni | **non verificato**: nessun nemico incantatore nella zona | nessuna riga `interrupt` |
| Colonna difensiva sotto il 50 % | **non verificato**: nessuna pozione nelle borse, nessun difensivo noto al livello 13 | righe `defense` = `none` |
| Burst | **non verificato**: Death Wish si impara al livello 30 | — |

Difetti trovati in gioco e corretti lo stesso giorno:

| Difetto | Causa | Correzione |
|---|---|---|
| Coda vuota per 18 s dopo l'ingaggio | spell conosciute lette con risposta segreta in combattimento | `d84e209`: ultima risposta in chiaro conservata |
| Errore della coda per 10-20 s a ogni ingaggio (`attempt to compare local 'back'`) | il controllo in chiaro riusava la FontString che aveva contenuto un segreto | `fbae03a`: FontString separata |
| Sunder suggerito dopo ogni lancio; DoT mai riconosciuti | debuff del bersaglio illeggibili e GUID del bersaglio segreto in combattimento | `f9f733f`: applicazioni proprie contate, bersaglio riconosciuto anche senza GUID |
| Fury in Postura difensiva senza via d'uscita | Postura berserker non ancora appresa | `f9f733f`: Postura da battaglia come ripiego |
| Molti "wait" con le liste di livello 60 | liste wowsims per personaggi di livello 60 | `9237417`: liste di livellamento; `39603da`: Heroic Strike senza soglia prima di Bloodthirst |
| Clic sui promemoria senza effetto | registrato solo il rilascio, il client agisce alla pressione | `462e863` |
| Colonna difensiva vuota con una pozione nelle borse | conteggi delle borse segreti in combattimento | `3c7935f`: ultimo conteggio in chiaro conservato |
| Cella della pozione rimasta senza pozioni | la cella automatica non veniva mai svuotata | `1de7b0d` |

## Prove non eseguite (limiti)

| Prova | Motivo | Riferimento |
|---|---|---|
| Interruzioni, colonna difensiva sotto il 50 %, burst, altre classi | vedi la tabella sopra; solo il Guerriero è giocabile | `RUNTIME_CHECKLIST.md` F |
| API del motore su Forever (curve, `TruncateWhenZero`, `DurationObject`, talenti, nameplate) | provate indirettamente dal Guerriero (coda, soglie, nameplate funzionanti); casi limite non coperti | `FOREVER_API_COMPATIBILITY.md` |
| Cattura reale del pixel a schermo | richiede il client in esecuzione con un personaggio | `RUNTIME_CHECKLIST.md` D |
| Pulsanti secure, binding override, `ActionButtonUseKeyDown`, state driver della riga promemoria su Forever | idem | B, F |
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
- Il motore legge molti valori che su Forever possono essere segreti: se le
  risposte del client (curve, `TruncateWhenZero`, `DurationObject`) non
  funzionano, le condizioni diventano "sconosciute" e non bloccano le voci;
  la coda resta in ordine di lista ma può proporre voci che una condizione
  avrebbe trattenuto.
