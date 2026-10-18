# Architettura

Versione 1.0.0. Dalla 1.0.0 i suggerimenti vengono dal motore interno
(`Engine/`), alimentato da dati importati (`Data/`). JustAC non è più usato a
runtime: il TOC non ha `OptionalDeps` (`tests/test_toc.lua`) e
`Bridge/JustACAdapter.lua` è stato rimosso. Motivo del cambio: decisione del
proprietario del 2026-10-16, dopo che JustAC 6.0.0 in gioco alternava
all'infinito Postura difensiva e Postura da battaglia (`MILESTONES.md`).

## Flusso dati

```text
 Data/*.lua  (generati da scripts/import_justac_data.py dai dati di JustAC 6.0.0)
      |
      v  Engine/Trees.lua      albero con più punti -> lista st / cleave / aoe
      v  Engine/State.lua      stato di gioco (vero/falso/sconosciuto), Engine/Secret.lua
      v  Engine/Gates.lua      condizioni delle voci (solo "falso" blocca)
      v  Engine/Queue.lua      coda: voci pronte in ordine di lista, gap closer, wait, burst
 snapshot {status, tree, context, entries[i] = {kind, id, base, ready, burst}}
      |
      v  Bridge/Model.lua      polling 50 ms; osservazioni cast/portata/combattimento
      +--------------------------+-----------------------------+
      |                          |                             |
      v                          v                             v
 Panel/Grid.lua           Pixel/DiagnosticPixel.lua      Engine/Interrupts.lua  -> icona a sinistra
 segni 1..N, striscia     Queue.Head (posizione 1)       Engine/Defensives.lua  -> colonna a destra
 della coda                -> Actions.SlotFor -> colore  Engine/Precombat.lua   -> Panel/Reminders.lua
      ^                          |                                                 (fuori combattimento)
      |                          v
 Panel/Actions.lua        quadrato 8x8 su UIParent
 (associazioni cella/azione/tasto scelte dall'utente o dal riempimento automatico;
  attributi secure, override binding, solo fuori combattimento)
```

Il pixel riceve solo `Queue.Head` (posizione 1 della coda dei danni).
Interruzioni, difensivi e promemoria non passano mai dal pixel; il segno
"burst" è solo grafico (`Bridge/Model.lua`).

## Moduli e responsabilità

| File | Responsabilità | Non fa |
|---|---|---|
| `Core/Init.lua` | namespace privato (`...`), costanti (`MAX_SLOTS = 20`, `STATUS` = `ok`/`missing`/`error`, `ENTRY`, `WAIT_ID`), helper per secret values (`IsSecret`, `Readable`, `SafeCall`) | nessuna globale oltre a quelle elencate sotto |
| `Core/Diagnostics.lua` | log diagnostico opzionale (spento di default) di scritture pixel, lanci, ACK, suggerimenti e combattimento in `ForeverOneButtonLog`; riepilogo dei fronti | non modifica il protocollo, nessun pixel aggiuntivo, valori segreti registrati come "secret" |
| `Core/Settings.lua` | `ForeverOneButtonDB`, `ForeverOneButtonCharDB`, sanitizzazione con whitelist, limiti, `FEATURES` con i default | nessuna importazione da HCOB o JustAC |
| `Core/Probe.lua` | `/fob probe spellbook` e `/fob probe frames`, sola lettura | — |
| `Data/Rotations.lua`, `Defaults.lua`, `Interrupts.lua`, `Consumables.lua`, `CCBreakers.lua` | tabelle generate: liste di priorità per classe/albero/contesto con condizioni, catene di ranghi, abilità di classe, difensivi, gap closer, burst, buff, interruzioni, consumabili, oggetti di cura, breaker | nessuna funzione, nessuna chiamata (`tests/test_data.lua`) |
| `Engine/Secret.lua` | risposte sì/no su valori segreti: curve a soglia (`UnitHealthPercent`/`UnitPowerPercent` + `C_StringUtil.TruncateWhenZero`) e `DurationObject` di cooldown su un widget Cooldown nascosto | nessuna funzione restituisce un numero; una soglia per decisione |
| `Engine/Ranks.lua` | rango 1 ↔ ranghi, rango più alto conosciuto | — |
| `Engine/State.lua` | domande sullo stato (salute/potere sotto soglia, usabile, cooldown, portata, bersaglio, nemici ingaggiati, postura, buff, stack, swing) con risposta vero/falso/sconosciuto | nessun valore segreto confrontato in Lua |
| `Engine/Gates.lua` | 19 tipi di condizione (`stealth`, `known`, `starved`, `unconfirmed`, `targets`, `totem`, `near`, `swing`, `resource`, `power`, `execute`, `health`, `stack`, `cd`, `buff`, `dot`, `tick`, `any`, `all`), a tre valori | uno sconosciuto non blocca mai: blocca solo `false` |
| `Engine/Dots.lua` | DoT considerato attivo se lanciato dal giocatore sul bersaglio corrente entro la durata | — |
| `Engine/Trees.lua` | albero dei talenti con più punti, altrimenti default della classe; contesto st/cleave/aoe da 1/2/3+ nemici ingaggiati; forma d'orso per i druidi feral | — |
| `Engine/Queue.lua` | coda dei danni (sotto) e `Queue.Head` | nessuna spell fuori dalla lista attiva, salvo i gap closer |
| `Engine/Interrupts.lua` | interruzione suggerita quando il bersaglio lancia o canalizza | non entra nella coda né nel pixel |
| `Engine/Defensives.lua` | fino a 4 difensivi/oggetti di cura per fascia di salute; cue per pet, cure di gruppo, breaker | non entra nella coda né nel pixel |
| `Engine/Precombat.lua` | fino a 6 promemoria fuori combattimento: buff di classe, consumabili, furtività, cura di rabbocco, cibo/bevanda/benda | vuoto in combattimento, in sella, da morto |
| `Panel/Keys.lua` | normalizzazione dei tasti (riuso tecnico HCOB), tasti rifiutati, etichette brevi | — |
| `Panel/Actions.lua` | assegnazioni, tasti effettivi (utente/default), conflitti, applicazione secure, `SlotFor` | non assegna né rilega nulla in base alla coda |
| `Panel/AutoFill.lua` | riempimento automatico stabile dal pool: lista dell'albero attivo (st, cleave, aoe) + gap closer + interruzioni + difensivi, più una cella automatica per il miglior oggetto di cura; fuori combattimento | non legge la coda né il suggerimento corrente; non sposta mai una spell già collocata |
| `Panel/Grid.lua` | griglia, segni (oro posizione 1, ciano 2+, viola burst), striscia coda, stato con albero e contesto, icona di interruzione a sinistra (rosso, "!" sulla cella), colonna difensiva a destra (arancione, "D" sulla cella), controllo sovrapposizione | nessun `OnClick` Lua sui pulsanti, nessuna azione |
| `Panel/Reminders.lua` | riga di pulsanti secure per i promemoria, sotto la striscia | configurata solo fuori combattimento; nascosta in combattimento da `RegisterStateDriver`; nessun tasto; agisce solo al clic del giocatore |
| `Pixel/DiagnosticPixel.lua` | encoder/renderer v3, fronte ACK, posizione/visibilità | nessun pixel di debug, nessuna informazione aggiuntiva |
| `Bridge/Model.lua` | ciclo di refresh, rilevazione cambi, cast/portata/combattimento, invio a griglia, pixel, colonna difensiva, icona di interruzione, promemoria (al più 1 volta al secondo) | nessuna decisione propria |
| `UI/Options.lua` | finestra opzioni: pagine *Layout & pixel*, *Cells & keys*, *Combat*, *Reminders* (ogni pagina entro l'altezza della finestra); cattura tasti | — |
| `UI/BlizzardBar.lua` | opzione "nascondi barra Blizzard" | — |
| `Core/Commands.lua` | `/fob` | nessun comando spam/pull |
| `Core/Events.lua` | ciclo di vita, differimento dopo il combattimento, ACK | nessun evento genera input |

Globali create: `ForeverOneButtonDB`, `ForeverOneButtonCharDB`,
`ForeverOneButtonLog`, `SLASH_FOREVERONEBUTTON1/2`,
`SlashCmdList.FOREVERONEBUTTON` e i frame con nome `ForeverOneButton*`
(i pulsanti hanno bisogno di un nome per i binding `CLICK`). Verificato in
`tests/test_toc.lua`.

## La coda (`Engine/Queue.lua`)

1. Classe senza lista → stato `missing` ("no priority list for this class").
   Un errore nella costruzione → stato `error` (`Bridge/Model.lua`).
2. Lista: albero scelto da `Trees.Pick`, contesto da `Trees.Context`
   (1 nemico st, 2 cleave, 3+ aoe; lista mancante → la più semplice).
3. **Candidati: solo le voci della lista attiva** (più i gap closer della
   classe). Esclusi: abilità con ruolo non offensivo nei dati
   (`abilityRoles`), la postura/forma già attiva, Attacco mentre si attacca
   già, e fuori combattimento le spell già offerte nella riga dei promemoria.
   Una spell che la lista non nomina, come l'altra postura, non viene mai
   suggerita: è la correzione del ciclo Postura difensiva ↔ Postura da
   battaglia osservato in gioco con JustAC 6.0.0 il 2026-10-16
   (`tests/test_queue.lua`: "Arms in Battle Stance never suggests Defensive Stance").
4. Una voce è pronta se conosciuta, usabile, fuori cooldown, a portata, non
   trattenuta da una condizione e non un DoT già attivo. Prima le pronte in
   ordine di lista, poi le altre ("in arrivo", attenuate nella striscia).
5. Gap closer (Carica, Intercettare…) in posizione 1 se il bersaglio è
   attaccabile e confermato oltre 8 m, non nei 3 s dopo il lancio.
6. Niente di pronto in combattimento (o con un bersaglio attaccabile) →
   posizione 1 = wait (pixel nero).
7. Burst (`Settings.FEATURES.burstCue`, in combattimento): il primo trigger
   di burst pronto della classe (`Defaults.burstTriggers`) passa in
   posizione 2 (resta in 1 se è già primo) e viene segnato in viola; mai su
   un bersaglio singolo non boss sotto il 20 %.
8. Al più 10 voci; una coda invariata restituisce lo stesso snapshot.

`Queue.Head` restituisce l'ID della posizione 1 solo se è una spell o un item
pronto; wait, coda vuota, voce non pronta, stato `missing`/`error` → `nil` →
nero.

## Ciclo di vita

| Momento | Cosa succede |
|---|---|
| Caricamento file | creazione frame (pulsanti secure senza attributi né click registrati); layout della riga promemoria se fuori combattimento |
| `ADDON_LOADED` (proprio) | `Settings.Load()`: sanitizzazione di `ForeverOneButtonDB` e `ForeverOneButtonCharDB`; caricamento del log |
| `PLAYER_LOGIN` | posizione/visibilità pixel, layout griglia, attributi e binding (differiti se in combattimento), avvio polling, riempimento automatico, barra Blizzard |
| Polling 50 ms | costruzione della coda, osservazioni, aggiornamento pixel/griglia solo se qualcosa è cambiato; colonna difensiva e icona di interruzione se cambiano; promemoria fuori combattimento al più ogni secondo |
| `PLAYER_REGEN_DISABLED` | chiusura opzioni e cattura tasti, fine trascinamento; refresh immediato (pixel attivo) |
| `PLAYER_REGEN_ENABLED` | applicazione di layout/attributi/binding/riempimento rimasti in sospeso; promemoria subito; refresh immediato (pixel nero) |
| `SPELLS_CHANGED`, `PLAYER_SPECIALIZATION_CHANGED`, `ACTIONBAR_SLOT_CHANGED`, `BAG_UPDATE_DELAYED` | icone e mapping; richiesta di riempimento automatico (raggruppata, 0,5 s; rimandata dopo il combattimento) |
| `PLAYER_TALENT_UPDATE`, `TRAIT_CONFIG_UPDATED`, `UPDATE_SHAPESHIFT_FORM`, `SPELLS_CHANGED` | albero da ricalcolare (`Trees.Invalidate`) |
| `UNIT_SPELLCAST_SUCCEEDED` (player) | fronte ACK del pixel; lanci ricordati per DoT, buff, debounce e oggetti di cura usati |
| `PLAYER_SWING` | durata dello swing (condizione `swing`) |

Perché il polling: risorse, cooldown e portata cambiano senza eventi
utilizzabili. Costo misurato sul mock (`tests/test_bench.lua`, 2026-10-16):
6–7 µs e 0,49 KB per refresh con coda invariata; 61–63 µs e 4,6 KB nel caso
peggiore (coda diversa ad ogni refresh, posizione 1 non associata); motore
reale (Guerriero Arms in combattimento) circa 197 µs e 15,4 KB per refresh.
Sul client va misurato (`docs/TEST_REPORT.md`).

## Combattimento e taint

- Operazioni protette (`SetAttribute`, `RegisterForClicks`,
  `SetOverrideBindingClick`, `ClearOverrideBindings`, `Show/Hide/SetPoint/SetScale`
  della griglia, dei pulsanti e della riga promemoria, `RegisterStateDriver`)
  solo fuori combattimento; il mock dei test solleva un errore se avvengono in
  combattimento. Dopo un `/reload` in combattimento il layout della riga
  promemoria è rimandato.
- In combattimento cambiano solo regioni non protette (icone, testi, bordi,
  icona di interruzione, colonna difensiva). La riga promemoria viene nascosta
  dal client (state driver `[combat] hide; show`) e non viene riconfigurata.
- Codice insicuro: nessun hook su frame Blizzard, nessuna modifica di frame
  secure altrui.

## Prova dell'esclusione delle decisioni HCOneButton e dell'automazione

1. **Nessun codice decisionale copiato.** Dai sorgenti HCOB sono riusati solo:
   il producer pixel (presentazione/encoding), la normalizzazione dei tasti e
   la lettura del CVar `ActionButtonUseKeyDown` (integrazione API). Classificazione
   in `ACTION_PANEL_DESIGN.md` §1.
2. **Il producer era un modulo misto?** No: `DiagnosticPixel.lua` riceve uno
   spell ID già deciso. L'unica dipendenza da altri moduli HCOB
   (`SurvivalStrip.ManualUsePending`, `ActionPanel.idToSlot`) è stata rimossa o
   sostituita; il chiamante (`UI/Advisor.lua` → `Advisor/Engine`) non è portato.
3. **Decisioni solo in `Engine/`.** Le decisioni su cosa suggerire stanno
   solo in `Engine/`, dai dati importati in `Data/`. Nessun codice di JustAC
   è incluso (`ForeverOneButton/NOTICE.md`).
4. **Scansione statica** (`tests/test_no_decisions.lua`): il codice spedito
   fuori da `Data/`, senza commenti, non contiene simboli HCOB, Advisor,
   Readiness, Survival, spam/pull/auto-attack/auto-bind, API di esecuzione
   (`CastSpell*`, `UseAction`, `RunMacro`, `UseItemByName`, `AttackTarget`,
   `TargetNearest`, …), `SetBinding`/`SaveBindings`, `macrotext`,
   `C_Timer.NewTicker`, `AssistedCombat`/`GetNextCastSpell`, `JustAC`,
   `LibStub`; il lessico decisionale (`Engine`, `Recommend`, `Rotation`,
   `Priority`, `Threat`) compare solo in `Engine/` (la lettura delle liste
   importate `ns.Data.Rotations` è ammessa). Timer: esattamente 4 usi
   (`C_Timer.After` nel pixel e nel riempimento automatico, `OnUpdate` del
   modello impostato/rimosso).
5. **Tripwire runtime**: lo stesso test definisce `HCOneButton`, `HCOB_DB` e i
   punti di ingresso dell'Advisor come funzioni che falliscono se chiamate, poi
   esercita assenza di lista, errore del motore, code diverse, combattimento,
   cast e comandi (anche quelli delle funzioni escluse): nessuna chiamata,
   nessun `OnClick` Lua sulle celle. Anche i pulsanti della riga promemoria non
   hanno gestori di clic Lua (`tests/test_reminders.lua`).
6. **Pacchetto**: `scripts/package.py verify` rifiuta codice con riferimenti a
   HCOB_DB, Advisor/Engine di HCOB, spam button, pull advisor, auto pull.
