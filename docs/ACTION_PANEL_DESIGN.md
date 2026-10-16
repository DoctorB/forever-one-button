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
| Tabella slot→spell per classe | lista fissa per classe, mai compattata | ActionPanel.lua:34-44 | **sì** (scelta del contenuto da parte dell'autore HCOB) | E → R | tabella HCOB esclusa; al suo posto (richiesta del proprietario, 2026-10-15) riempimento automatico stabile dal pool di abilità di JustAC: prima cella libera, mai spostata, ranghi nella stessa cella, celle per personaggio; drag & drop e `/fob assign` restano | `test_autofill` |
| Macro per slot (`/cast [harm]`, `/startattack`, `@player`) | `type1=macro`, `macrotext1` | ActionPanel.lua:549-583; Core/Macros.lua:103-110 | **misto** (scelte di targeting e auto-attack) | E | `type1=spell`/`item` con l'azione esatta; nessuna macro, nessun `/startattack` | scansione `macrotext`/`startattack` |
| Icona e stato (non appresa, non usabile) | alpha/desaturazione | :823-826, 745-750 | no | R | icona dell'azione; cella vuota con punto interrogativo trasparente | `test_panel_bindings` |
| Evidenziazione raccomandata (glow oro pulsante) | guidata dall'Advisor | :828-831, 856-862, 708-722 | **sì** | R | bordo oro + "1" sulla cella della posizione 1 **JustAC**; posizioni 2…N in ciano con il loro numero | `test_panel_bindings` |
| Colori bordo per cooldown/portata/usabilità | priorità di stati | :752-765 | misto | E (parziale R) | solo tinta rossa "fuori portata" sulla cella della posizione 1, dallo stesso dato che rende nero il pixel; cooldown/usabilità non mostrati (dati potenzialmente segreti, non necessari) | `test_protocol_v3` |
| Swipe cooldown e testo CD | `CooldownFrameTemplate` | :833-845 | no | E | non necessario al mandato; evita letture di cooldown possibili secret | — |
| "R" fuori portata | da `Advisor.Engine.SpellRange` | :847-850 | misto (helper dell'Engine) | R | `C_Spell.IsSpellInRange` diretto, solo `false` leggibile | `test_protocol_v3` |
| Tooltip | nome, binding, stato | :863-887 | no | R | cella, azione, tasto o "No key bound", posizione JustAC, suggerimento drag | manuale (checklist) |
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
| Comandi `/hcob actions …`, `scale`, `show/hide`, `lock/unlock` | | Core/Commands.lua | misto | R | `/fob` con soli comandi di binding e UI/pixel | `test_no_decisions` |
| Pulsante BASE "spam" e varianti modificatori | | CoreHUD.lua:7-27; Macros.lua:124-221 | **sì** | E | assente | scansione `spam` |
| Pull readiness / "PULL READY" / pre-pull Rend | | Advisor/Readiness.lua; Engine.lua:549-553; Macros.lua:72-83 | **sì** | E | assente; l'utente avvia ogni pull | scansione `pull`, `Readiness` |
| Avviso riavvio auto-attack | | Classes/Rogue.lua:161; UI/Advisor.lua:80-141 | **sì** | E | assente | scansione `AutoAttack` |
| Survival Strip (consumabili) e gestione manual-use del pixel | | UI/SurvivalStrip.lua | misto | E | assente; rimosso anche dal pixel | `PROTOCOL_COMPATIBILITY.md` |
| Diagnostic Pixel | | UI/DiagnosticPixel.lua | no (riceve una decisione già presa) | T | porting con contratto invariato | `test_pixel_differential` |
| Persistenza `HCOB_DB.*` | | Core/Utils.lua | — | E | `ForeverOneButtonDB` dedicato, senza importazione | `test_options_whitelist` |

## 2. Progetto della nuova griglia

```text
 [ Forever One Button - drag to move, /fob lock ]   <- solo se sbloccata
 +------+------+------+------+------+------+
 |1    1|2     |3    3|4     |5     |6     |   numero cella in alto a sinistra
 | icon | icon | icon |  ?   | icon | icon |   posizione JustAC in alto a destra
 |   s1 |   s2 |no key|      |  cs5 |   F6 |   tasto in basso a destra
 +------+------+------+------+------+------+
 |7     |8     |9     |10    |11    |12    |   caselle a colori alternati
 +------+------+------+------+------+------+
 | JustAC suggestion is not on the grid (--)        |  stato
 | [ic] 1: --   [ic] 2: c1   [ic] 3: c3              |  coda in ordine JustAC
```

- Ordine visuale delle celle (numero 1–20, riga per riga) separato dall'ordine
  JustAC: il numero di posizione appare sulla cella e la striscia elenca la
  coda nell'ordine JustAC con la cella corrispondente.
- Suggerimento non associabile: "--" nella striscia e messaggio di stato;
  nessuna altra cella evidenziata; pixel bianco.
- JustAC assente, errore, dati non validi/non leggibili, coda vuota, wait:
  stato esplicito; tutti i segni vengono rimossi (nessuna raccomandazione
  vecchia resta visibile); pixel nero.
- Quadrato pixel: frame separato con parent UIParent e anchor proprio; la
  griglia ne segnala la sovrapposizione ("grid covers the pixel!"). Default:
  griglia al centro in basso, pixel nell'angolo in alto a sinistra.

## 3. Stati e flussi di configurazione

1. Assegnazione: drag & drop (fuori combattimento) o `/fob assign`. Un'azione
   già presente in un'altra cella viene rifiutata, indicando quale.
2. Tasto: Bind → cattura → validazione (tasti rifiutati: BUTTON1/2, ESC,
   modificatori da soli) → conflitto interno rifiutato → binding override.
3. Celle oltre il numero visibile: conservano l'assegnazione salvata ma non
   eseguono e non hanno binding; per il pixel sono "non associate".
4. Reload in combattimento: pulsanti creati senza configurazione; tutto viene
   applicato a `PLAYER_REGEN_ENABLED`; nel frattempo bianco, mai uno slot.

## 4. Prove funzionali e visive

| Prova | Tipo | Stato |
|---|---|---|
| Layout, scacchiera, passo regolare, 20 celle max | automatica (mock) | PASS |
| Segni di posizione, striscia, non associati, stati di errore | automatica | PASS |
| Nessuna modifica di celle/tasti/binding indotta dalla coda (50 cambi) | automatica | PASS |
| Griglia (tutte le opzioni ai limiti, spostamento, nascosta, scala diretta) non altera il pixel | automatica | PASS |
| Leggibilità di icone e tasti, aspetto reale, tooltip | manuale sul client | **pendente** (`RUNTIME_CHECKLIST.md`) |
| Cattura reale del quadrato con griglia in varie configurazioni | manuale sul client | **pendente** |
