# Action Panel: audit della panel originale e progetto della griglia

Fonte dell'audit: `hc-one-button` @ `e973acb`, sola lettura. Riferimenti
`file:riga` relativi a `HCOneButton/`. L'inventario è uno strumento di
tracciabilità, non un mandato di parità.

Legenda destinazione: **R** riprogettato, **T** riusato tecnicamente,
**E** escluso per requisito.

## 1. Inventario della panel originale e destinazione

| Elemento originale | Comportamento originale | file:riga | Dipende da decisioni? | Dest. | Nella nuova UI / motivazione | Prova |
|---|---|---|---|---|---|---|
| Contenitore `HCOneButtonAdvisorActions` | Barra 376 px sotto la HUD, strata HIGH | UI/ActionPanel.lua:796-807 | no | R | `ForeverOneButtonGrid`, strata MEDIUM, dimensione dalla griglia | `test_panel_bindings` |
| Ancoraggio alla HUD/BASE | Segue il pulsante BASE tramite CoreShell | ActionPanel.lua:800; CoreHUD.lua:132 | no | R | posizione propria, trascinabile da una barra quando sbloccata | `test_grid_pixel_isolation` |
| Layout 10 colonne × 2 righe, 32 px | fisso | ActionPanel.lua:785-797 | no | R | scacchiera configurabile: celle 1–20, colonne, dimensione, spaziatura; colori alternati | `test_panel_bindings` |
| 20 pulsanti secure `HCOneButtonAdvisorAction1..20` | SecureActionButton, parent UIParent | ActionPanel.lua:808-818 | no | R + T | `ForeverOneButtonCell1..20`, figli della griglia (la scala della griglia si applica senza toccare il pixel); `RegisterForClicks("AnyDown","AnyUp")` e `useOnKeyDown` dal CVar riusati | `test_panel_bindings` |
| Tabella slot→spell per classe | lista fissa per classe, mai compattata | ActionPanel.lua:34-44 | **sì** (scelta del contenuto da parte dell'autore HCOB) | E → R | tabella HCOB esclusa; al suo posto (richiesta del proprietario, 2026-10-15) riempimento automatico stabile dal pool del motore (lista dell'albero attivo st/cleave/aoe, gap closer, interruzioni, difensivi, più una cella per il miglior oggetto di cura): prima cella libera, mai spostata, ranghi nella stessa cella, celle per personaggio; drag & drop e `/fob assign` restano | `test_autofill`, `test_autofill_pool` |
| Macro per slot (`/cast [harm]`, `/startattack`, `@player`) | `type1=macro`, `macrotext1` | ActionPanel.lua:549-583; Core/Macros.lua:103-110 | **misto** (scelte di targeting e auto-attack) | E | `type1=spell`/`item` con l'azione esatta; nessuna macro, nessun `/startattack` | scansione `macrotext`/`startattack` |
| Icona e stato (non appresa, non usabile) | alpha/desaturazione | :823-826, 745-750 | no | R | icona dell'azione; cella vuota con punto interrogativo trasparente | `test_panel_bindings` |
| Evidenziazione raccomandata (glow oro pulsante) | guidata dall'Advisor | :828-831, 856-862, 708-722 | **sì** | R | bordo oro, "1" e glow pulsante attorno alla cella della posizione 1 della coda del **motore** (`Engine/Queue.lua`), prima icona della striscia più grande e incorniciata; posizioni 2…N pronte in ciano con il loro numero, voci non pronte con numero grigio e senza bordo; bordo viola per il trigger di burst pronto (richiesta del proprietario, 2026-10-19) | `test_panel_bindings`, `test_queue` |
| Colori bordo per cooldown/portata/usabilità | priorità di stati | :752-765 | misto | E (parziale R) | tinta rossa "fuori portata" sulla cella della posizione 1, dallo stesso dato che rende nero il pixel; bordo rosso e "!" sulla cella dell'interruzione, bordo arancione e "D" sulla cella del difensivo; voci non pronte attenuate e desaturate nella striscia; icona blu senza risorse, grigia se non usabile ora (2026-10-19) | `test_protocol_v3`, `test_interrupts`, `test_defensives` |
| Swipe cooldown e testo CD | `CooldownFrameTemplate` | :833-845 | no | R | richiesta del proprietario (2026-10-19): swipe e icona desaturata durante il cooldown reale (GCD escluso), numeri del client se attivi; il `DurationObject` o i tempi del client passano al widget senza essere letti; con tempi segreti o subito dopo il lancio vale il cooldown base dal lancio visto (oggetti: due minuti dall'uso); numero di pezzi sulle celle oggetto | `test_cooldowns` |
| "R" fuori portata | da `Advisor.Engine.SpellRange` | :847-850 | misto (helper dell'Engine) | R | `C_Spell.IsSpellInRange` diretto, solo `false` leggibile | `test_protocol_v3` |
| Tooltip | nome, binding, stato | :863-887 | no | R | cella, azione, tasto o "No key bound", posizione nella coda, "Burst cooldown ready", suggerimento drag; tooltip dei promemoria con nome, motivo e "Click to use (out of combat)" | manuale (checklist) |
| Etichette tasto | solo nel tooltip | :867-869 | no | R | tasto abbreviato sempre visibile; "no key" rosso se manca | `test_panel_bindings` |
| PostClick → `RecordTuningInput` | telemetria per il tuner adattivo | :888-893 | alimenta il tuner (decisionale) | E | nessun hook sui click | `test_no_decisions` (nessun `OnClick`) |
| Drag della HUD (BASE) | sposta tutto, bloccato in combattimento | CoreHUD.lua:345-349 | no | R | drag della sola griglia, bloccato in combattimento e quando bloccata | `test_grid_pixel_isolation` |
| Scala `scale × actionScale` con coda in combattimento | pendingHUDScale | CoreHUD.lua:220-290 | no | R | una sola `scale` della griglia; cambi rifiutati in combattimento | `test_panel_bindings` |
| Visibilità (`visible`, `showAdvisor`, `secureActions`) | legata all'Advisor | ActionPanel.lua:770-780 | misto | R | `grid.shown`, indipendente da tutto il resto | idem |
| Finestra binding (20 righe, cattura tastiera/mouse/rotella, ESC, chiusura in combattimento) | | ActionPanel.lua:281-547 | no | R | pagina "Cells & keys": 20 righe, Bind/Unbind/Clear, cattura tastiera, tasti mouse 3-5, rotella; chiusura in combattimento | `test_options_whitelist` |
| Auto-bind con `SetBindingClick` + `SaveBindings` | sovrascrive binding esistenti e li salva | ActionPanel.lua:119-209; Systems/Bindings.lua:16-37 | no, ma invasivo | E (R) | binding override (`SetOverrideBindingClick`) per celle con un'azione; nessun salvataggio nei binding del client | `test_panel_bindings` |
| Tasti di default SHIFT-1…CTRL-SHIFT-0 | | ActionPanel.lua:51-57 | no | T | stesso schema come default (richiesta del proprietario); `Unbind` lo toglie, `Default` lo ripristina | idem |
| Conflitti: duplicato interno rifiutato; sovrascrittura avvisata | | :196-224 | no | R | duplicato interno rifiutato con la cella in conflitto; binding WoW esistente segnalato (`!`, report, messaggio), mai sostituito con un altro tasto | idem |
| Migrazione binding da addon precedente | | Systems/Bindings.lua:39-55 | no | E | nessuna importazione | `test_options_whitelist` |
| WindowManager (un dialogo per volta) | | UI/WindowManager.lua | no | E | una sola finestra, chiusura con ESC (`UISpecialFrames`) | — |
| Opzioni HCOB (auto-bind, scala, reset) | | UI/Options.lua:303-381 | misto | R | whitelist (`BINDINGS_AND_OPTIONS.md`) | idem |
| Comandi `/hcob actions …`, `scale`, `show/hide`, `lock/unlock` | | Core/Commands.lua | misto | R | `/fob` con comandi di binding, UI/pixel e funzioni del motore (`/fob features`, `/fob feature`); nessun comando spam/pull | `test_no_decisions`, `test_options_whitelist` |
| Pulsante BASE "spam" e varianti modificatori | | CoreHUD.lua:7-27; Macros.lua:124-221 | **sì** | E | assente | scansione `spam` |
| Pull readiness / "PULL READY" / pre-pull Rend | | Advisor/Readiness.lua; Engine.lua:549-553; Macros.lua:72-83 | **sì** | E | assente; l'utente avvia ogni pull | scansione `pull`, `Readiness` |
| Avviso riavvio auto-attack | | Classes/Rogue.lua:161; UI/Advisor.lua:80-141 | **sì** | E | assente | scansione `AutoAttack` |
| Survival Strip (consumabili) e gestione manual-use del pixel | | UI/SurvivalStrip.lua | misto | E (R) | codice HCOB assente e rimosso dal pixel; riprogettato dai dati importati: miglior oggetto di cura nella colonna difensiva e in una cella automatica, consumabili e cibo/bevanda/benda nella riga promemoria fuori combattimento; mai nel pixel | `PROTOCOL_COMPATIBILITY.md`, `test_defensives`, `test_reminders` |
| Diagnostic Pixel | | UI/DiagnosticPixel.lua | no (riceve una decisione già presa) | T | porting con contratto invariato | `test_pixel_differential` |
| Persistenza `HCOB_DB.*` | | Core/Utils.lua | — | E | `ForeverOneButtonDB` dedicato, senza importazione | `test_options_whitelist` |

## 2. Progetto della nuova griglia

```text
        [ Forever One Button (locked) - right-click to unlock ]      <- barra del titolo
 +----+ +------+------+------+------+------+------+ +----+
 | !! | |1    1|2     |3    3|4     |5    !|6    D| | d1 |   numero cella in alto a sinistra,
 | s5 | | icon | icon | icon |  ?   | icon | icon | | s6 |   posizione / "!" / "D" in alto a destra,
 +----+ |   s1 |   s2 |no key|      |   s5 |   s6 | +----+   tasto in basso a destra
 icona  +------+------+------+------+------+------+ | d2 |
 inter- |7     |8     |9     |10    |11    |12    | +----+   colonna difensiva (max 4)
 ruzione+------+------+------+------+------+------+
        | Arms (single target)                     |      stato: albero (contesto)
        | [ic] 1: c1   [ic] 2: c3   [ic] 3: --      |      coda in ordine del motore
        [rm1][rm2][rm3]                                    riga promemoria (fuori combattimento)
```

- Ordine visuale delle celle (numero 1–20, riga per riga) separato dall'ordine
  della coda: il numero di posizione appare sulla cella e la striscia elenca la
  coda nell'ordine del motore con la cella corrispondente; le voci non ancora
  pronte sono attenuate.
- Suggerimento non associabile: "--" nella striscia e messaggio di stato;
  nessuna altra cella evidenziata; pixel bianco.
- Nessuna lista per la classe, errore del motore, coda vuota, wait: stato
  esplicito; tutti i segni vengono rimossi (nessuna raccomandazione vecchia
  resta visibile); pixel nero.
- Burst: bordo viola sulla cella del trigger in posizione 2 (o 1).
- Interruzione: icona a sinistra della griglia con la spell da usare, il cast
  nemico nell'angolo e il tasto della cella; la cella ha bordo rosso e "!"
  se la coda non la segna già. Nascosta a fine cast.
- Difensivi: colonna a destra con fino a 4 icone e i loro tasti; le voci in
  attesa (immunità o grandi cure trattenute) sono attenuate; la prima voce
  pronta ha bordo arancione e "D" sulla cella.
- Promemoria: riga di pulsanti secure sotto la striscia, solo fuori
  combattimento; cliccati dal giocatore, senza tasto.
- Quadrato pixel: frame separato con parent UIParent e anchor proprio; la
  griglia (con icona di interruzione, colonna difensiva e riga promemoria) ne
  segnala la sovrapposizione ("grid covers the pixel!"). Default: griglia al
  centro in basso, pixel nell'angolo in alto a sinistra.

## 3. Stati e flussi di configurazione

1. Assegnazione: drag & drop (fuori combattimento) o `/fob assign`. Un'azione
   già presente in un'altra cella viene rifiutata, indicando quale.
2. Tasto: Bind → cattura → validazione (tasti rifiutati: BUTTON1/2, ESC,
   modificatori da soli) → conflitto interno rifiutato → binding override.
3. Celle oltre il numero visibile: conservano l'assegnazione salvata ma non
   eseguono e non hanno binding; per il pixel sono "non associate".
4. Reload in combattimento: pulsanti creati senza configurazione; tutto viene
   applicato a `PLAYER_REGEN_ENABLED`; nel frattempo bianco, mai uno slot.
   Anche il layout della riga promemoria e il suo state driver sono rimandati.
5. Riga promemoria: aggiornata al più una volta al secondo fuori
   combattimento (subito dopo la fine di un combattimento); in combattimento
   il client la nasconde e nessun pulsante viene riconfigurato. Una spell
   offerta come promemoria non compare nella coda fuori combattimento.

## 4. Prove funzionali e visive

| Prova | Tipo | Stato |
|---|---|---|
| Layout, scacchiera, passo regolare, 20 celle max | automatica (mock) | PASS |
| Segni di posizione, striscia, non associati, stati di errore | automatica | PASS |
| Nessuna modifica di celle/tasti/binding indotta dalla coda (50 cambi) | automatica | PASS |
| Griglia (tutte le opzioni ai limiti, spostamento, nascosta, scala diretta) non altera il pixel | automatica | PASS |
| Icona di interruzione, segno "!", nascosta a fine cast | automatica | PASS |
| Colonna difensiva, segno "D", voce in attesa attenuata, cella automatica dell'oggetto di cura | automatica | PASS |
| Riga promemoria: pulsanti secure, nascosta in combattimento, nessuna riconfigurazione in combattimento, nessun gestore di clic Lua | automatica | PASS |
| Leggibilità di icone e tasti, aspetto reale, tooltip, colori viola/rosso/arancione | manuale sul client | **pendente** (`RUNTIME_CHECKLIST.md`) |
| Cattura reale del quadrato con griglia in varie configurazioni | manuale sul client | **pendente** |
