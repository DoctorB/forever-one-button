# Binding e opzioni

## Associazioni

Ogni cella `n` (1–20) ha al più un'azione (`spell` o `item`) e un tasto. Il
pulsante secure `ForeverOneButtonCell<n>` esegue l'azione solo con il tasto
sinistro o con il tasto associato (`type1`). Il pixel codifica `n` quando la
posizione 1 della coda del motore (`Engine/Queue.lua`) è l'azione di quella
cella (o un altro rango della stessa spell).

### Riempimento automatico (decisione del proprietario, 2026-10-15)

L'utente ha chiesto che le spell imparate finiscano da sole nelle celle,
sempre nello stesso slot, limitandosi a quelle che l'addon può suggerire.

| Regola | Comportamento |
|---|---|
| Sorgente | il pool del motore (`Panel/AutoFill.lua` `ReadPool`), in ordine fisso: le voci della lista dell'albero attivo (`Engine/Trees.lua`) nei contesti st, cleave, aoe, escluse le abilità con ruolo non offensivo nei dati (`Defaults.abilityRoles`); poi i **gap closer** della classe (`Defaults.gapClosers`: Carica, Intercettare…; aggiunti dopo il primo test in gioco del 2026-10-15, in cui la Carica era suggerita senza una cella); poi le interruzioni conosciute (`Data/Interrupts.lua`, solo `kind = interrupt`); poi i difensivi della classe (`Defaults.defensive`). Solo spell conosciute, al rango premuto (`Engine/Ranks.lua`: rango sulle barre, altrimenti il più alto conosciuto). Classe senza lista: nessun pool ("no priority list for this class") |
| Oggetto di cura | con `healingItems` attivo, una cella automatica per il miglior oggetto di cura posseduto (`Consumables.healingItems`, migliore per primo); uno migliore la sostituisce nella stessa cella; un oggetto di cura messo a mano non viene toccato; svuotare la cella automatica la esclude (`item:healing`) |
| Quando | login, `SPELLS_CHANGED` (spell o rango nuovo), `PLAYER_SPECIALIZATION_CHANGED`, `ACTIONBAR_SLOT_CHANGED`, `BAG_UPDATE_DELAYED`; raffiche raggruppate in una lettura dopo 0,5 s; in combattimento rimandato a `PLAYER_REGEN_ENABLED` |
| Posizione | una spell del pool che non è già in griglia va nella **prima cella libera** (ordine del pool) e **non viene più spostata** |
| Ranghi | un rango nuovo (stesso nome localizzato) sostituisce il vecchio **nella stessa cella**, se la cella è automatica |
| Override | una spell il cui override è già in una cella (o viceversa) non viene duplicata |
| Scelte dell'utente | le celle riempite a mano non vengono mai toccate; svuotare una cella (`Clear`) o sostituirne la spell la toglie dal riempimento automatico (per nome, tutti i ranghi); `/fob autofill reset` annulla queste esclusioni |
| Più di 20 spell | le celle finiscono: le spell in eccesso vengono contate e mostrate ("N spells did not fit"); se il motore le suggerisce il pixel è bianco |
| Indipendenza dalla coda | la coda/il suggerimento corrente non viene mai consultato: lo prova `tests/test_autofill.lua` |
| Disattivazione | opzione "Fill cells automatically from the priority list" o `/fob autofill off` |

Il pool dipende dall'albero con più punti (`tests/test_autofill_pool.lua`:
pool Arms e Protection del Guerriero); le celle già collocate non vengono
spostate.

### Tasti

| Situazione | Tasto effettivo |
|---|---|
| L'utente ha scelto un tasto | quel tasto |
| L'utente ha rimosso il tasto (`Unbind`) | nessuno, nemmeno quello di default |
| Altrimenti | default: celle 1–10 `SHIFT-1…SHIFT-0`, celle 11–20 `CTRL-SHIFT-1…CTRL-SHIFT-0` (schema di HCOneButton), salvo che l'utente abbia dato quel tasto a un'altra cella |

| Operazione | Comando / UI | Regole |
|---|---|---|
| Assegnare | drag & drop sulla cella; `/fob assign <n> spell <id\|nome>`, `/fob assign <n> item <id>` | fuori combattimento; un'azione in una sola cella |
| Svuotare | `Clear`; `/fob clear <n>` | fuori combattimento; esclude la spell dal riempimento automatico |
| Tasto | `Bind` + tasto; `/fob bind <n> <tasto>` | normalizzato `CTRL-ALT-SHIFT-X`; rifiutati BUTTON1, BUTTON2, ESCAPE, modificatori da soli; tasto scelto per un'altra cella rifiutato; se è il default di un'altra cella, quella lo perde (segnalato) |
| Nessun tasto | `Unbind`; `/fob unbind <n>` | — |
| Tasto di default | `Default`; `/fob defaultkey <n>` | — |
| Elenco | pagina *Cells & keys* (`d` = default, `!` = binding WoW coperto, `auto`); `/fob bindings` | — |
| Automatico | `/fob autofill on\|off\|now\|reset` | — |
| Funzioni del motore | pagine *Combat* e *Reminders*; `/fob features` (elenco con i valori), `/fob feature <nome> on\|off\|<valore>` | nome senza distinzione di maiuscole; valori fuori dalla whitelist rifiutati, numeri riportati nei limiti |

### Conflitti

- **Interni**: rifiutati; nessuna cella o tasto alternativo viene scelto.
- **Con binding WoW o di altri addon**: il tasto viene applicato come
  *override* (`SetOverrideBindingClick`); il binding coperto è indicato con `!`.
  Non viene modificato né salvato: togliendo il tasto o disattivando l'addon
  torna attivo. Nota: con il client standard `SHIFT-1…6` cambiano pagina della
  barra azioni; i default delle celle 1–6 le coprono finché l'addon è attivo
  (come faceva HCOneButton).
- **Binding mancanti**: "no key" rosso sulla cella.

### Persistenza

| Tabella | Ambito | Contenuto |
|---|---|---|
| `ForeverOneButtonDB` | account, `schema = 2` | `keys[n]` (stringa o `false`), `grid`, `pixel`, `autoFill`, `hideBlizzardBar`, `features` |
| `ForeverOneButtonCharDB` | personaggio, `schema = 1` | `cells[n] = {kind, id, auto}`, `dismissed[nome] = true` |

Al caricamento entrambe vengono ricostruite dalla whitelist (chiavi sconosciute
scartate, valori riportati nei limiti; `features` contiene esattamente le
chiavi di `Settings.FEATURES`). Migrazione da 0.1.0: le celle salvate
sull'account passano al primo personaggio che entra con celle vuote; layout
12×6 non modificato → nuovo default 20×10. Nulla viene importato da
HCOneButton o JustAC. I binding override non vengono salvati nei file dei
binding del client: vengono riapplicati a ogni login.

### Combattimento

Assegnazioni, tasti, riempimento automatico, layout e visibilità della griglia
non cambiano in combattimento (rifiutati o rimandati a fine combattimento); la
finestra opzioni si chiude a `PLAYER_REGEN_DISABLED`. Nessuna riassegnazione
in base alla raccomandazione. Le impostazioni delle funzioni del motore
cambiano solo ciò che il pannello mostra.

### Riga promemoria

I pulsanti `ForeverOneButtonReminder1..6` (`Panel/Reminders.lua`) sono
pulsanti secure senza tasto: nessun binding, nessuna voce in `keys`. Azione
(`type1` = `spell` o `item`) impostata solo fuori combattimento; agiscono solo
al clic del giocatore; in combattimento la riga è nascosta dal client.

## Whitelist delle opzioni

| Opzione | Valori (default) | Motivazione |
|---|---|---|
| `cells[n]` | spell/item | associazione pulsante → azione |
| `keys[n]` | tasto / nessuno / default | associazione pulsante → tasto |
| `autoFill` | sì/no (sì) | riempimento automatico richiesto dal proprietario |
| `features.*` | vedi sotto | funzioni del motore oltre la lista di priorità |
| `hideBlizzardBar` | sì/no (no) | richiesta del proprietario (2026-10-15): rende invisibili e non cliccabili barra azioni principale di Blizzard (pulsanti, grafica, frecce di pagina), micro-menu e borse; barra delle posture e barra dell'esperienza restano; nessun frame spostato, nessun binding toccato, quindi i tasti funzionano; solo fuori combattimento; un frame che contiene una barra mantenuta non viene toccato; effetto verificato in gioco dal proprietario il 2026-10-15 (`FOREVER_API_COMPATIBILITY.md`; `/fob probe frames` elenca i frame presenti) |
| `grid.slots` | 1–20 (20) | quante celle mostrare; 20 è il limite del protocollo v3 |
| `grid.columns` | 1–20 (10) | forma della scacchiera |
| `grid.cellSize` | 24–64 (40) | leggibilità di icone e tasti |
| `grid.spacing` | 0–12 (4) | separazione tra celle |
| `grid.scale` | 0,5–2,0 (1,0) | adattamento alla risoluzione; non tocca il pixel |
| `grid.queueDepth` | 1–5 (3) | quante posizioni della coda etichettare; pura presentazione |
| `grid.shown` | sì/no (sì) | visibilità della griglia |
| `grid.locked`, `grid.point` | (bloccata, centro −220) | posizione della griglia; barra del titolo sempre visibile: clic destro sblocca/blocca, trascinamento sinistro sposta |
| `pixel.enabled` | sì/no (sì) | mostrare il quadrato (come `/hcob diagpixel on/off`) |
| `pixel.locked`, `pixel.point` | (bloccato, alto-sinistra +16/−16) | posizione del quadrato |
| `pixel.combatOnly` | sì/no (sì) | richiesta del proprietario: fuori combattimento il pixel è nero (ingaggio e spell di apertura li sceglie l'utente); cambia solo quando si pubblica, non cosa |

### Funzioni del motore (`Settings.FEATURES`, `Core/Settings.lua`)

Default come JustAC 6.0.0, da cui vengono i dati. Scelgono cosa mostra il
pannello, mai cosa fa una cella o quando viene premuto un tasto.

| Funzione | Valori (default) | Effetto |
|---|---|---|
| `burstCue` | sì/no (sì) | trigger di burst pronto in posizione 2, bordo viola |
| `interrupts` | sì/no (sì) | icona di interruzione quando il bersaglio lancia o canalizza; "!" sulla cella |
| `interruptMode` | `kickOnly`, `kickPrefer`, `ccPrefer` (`kickPrefer`) | solo interruzioni; interruzioni e, sui cast schermati, controllo; controllo per primo |
| `interruptFears` | sì/no (no) | le paure valgono come controllo |
| `defensives` | sì/no (sì) | colonna difensiva; "D" sulla cella |
| `holdEmergencies` | sì/no (sì) | immunità trattenute fino a salute < 25 %, oggetti e grandi cure a lungo cooldown fino a < 50 % |
| `healingItems` | sì/no (sì) | miglior pozione o pietra della salute nella colonna e in una cella automatica |
| `petCues` | sì/no (sì) | cura, resurrezione ed evocazione del pet |
| `petHealBelow` | 10–90 (50) | soglia di salute del pet |
| `groupHeals` | sì/no (no) | cure di gruppo con alleati feriti |
| `ccBreak` | sì/no (no) | liberazione dalla perdita di controllo |
| `precombat` | sì/no (sì) | riga promemoria fuori combattimento |
| `classBuffs`, `flask`, `food`, `scroll`, `weaponEnchant` | sì/no (sì) | categorie dei promemoria: buff di classe, fiasca/elisir, cibo Well Fed, pergamena, pietra/olio/imbue dell'arma |
| `recovery` | sì/no (sì) | mangiare, bere o bendarsi dopo un combattimento |
| `stealthReminder` | sì/no (sì) | furtività (ladro, druido feral) |
| `topoffHeal` | sì/no (no) | cura di rabbocco sotto `topoffBelow` (sotto il 35 % sempre) |
| `topoffBelow` | 40–99 (90) | soglia della cura di rabbocco |

Escluse deliberatamente: auto-bind che scrive i binding del client, macro,
modifica delle liste di priorità, esecuzione automatica di qualsiasi spell,
spam/BASE, pull, colori/dimensione/strata del pixel (contratto v3), opzioni o
profili di altri addon.

Prove: `tests/test_autofill.lua`, `tests/test_autofill_pool.lua`,
`tests/test_options_whitelist.lua`, `tests/test_panel_bindings.lua`,
`tests/test_reminders.lua`.
