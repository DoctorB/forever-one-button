# Compatibilità del protocollo pixel e mapping della coda

Stato: **contratto del producer riprodotto e provato offline**. Il protocollo
v3 è invariato nella 1.0.0: codifica solo la posizione 1 della coda dei danni
del motore interno (`Engine/Queue.lua`); interruzioni, difensivi, segno di
burst e promemoria non arrivano mai al quadrato.

## 1. Fonti e confini

| Ruolo | Dove | Identificazione | Stato |
|---|---|---|---|
| Producer originale (addon) | `hc-one-button/HCOneButton/UI/DiagnosticPixel.lua` | commit `e973acba84e3911ddb6a68655d247426df7bdf4f`, blob `3c6b405084612743396d68cbf1938de8bdcd8464` (file modificato l'ultima volta in `6baa93c`) | letto; scaricato al commit fissato in `tests/fixtures/hcob/DiagnosticPixel.lua` da `scripts/fetch_fixtures.py` (non versionato) |
| Chiamanti del producer | `UI/Advisor.lua:183` (`UpdateDiagnosticPixel`), `Core/Events.lua:144-145` (ACK), `UI/SurvivalStrip.lua:36`, `UI/CoreHUD.lua:302` (show/hide) | stesso commit | letti |
| Regressione originale | `hc-one-button/tests/diagnostic_pixel_edge.lua` | blob `ac792476979bc27dbaa91665e89e2a060645086f` | congelata ed eseguita immutata (`tests/test_original_regression.lua`) |
| Specifica pubblicata del protocollo | `hc-one-button/README.md`, sezione *Diagnostic Pixel* | stesso commit | letta |

Confine effettivo: Forever One Button contiene il solo **producer** (encoder +
renderer del colore). Nei test esiste un decoder scritto dalla specifica
pubblicata (`DecodeV3` in `tests/test_protocol_v3.lua`), usato per verificare
l'encoding.

## 2. Matrice del protocollo

| Elemento | Significato | Sorgente originale | Encoding e unità | Posizione e geometria | Stato non valido/vuoto | Nuova sorgente | Evidenza |
|---|---|---|---|---|---|---|---|
| Colore "slot" | Slot fisso della panel 1–20 (README passi 5–6) | `RenderDiagnosticPixel` → `HCOB.UI.ActionPanel.idToSlot[spellId]` | `R = slot*12/255`, `G = 96/255`, `B = 224/255`, `A = 1` via `SetColorTexture`; a 8 bit: R = 12…240, G = 96, B = 224 | tutta l'area 8×8 | slot assente → bianco | cella della griglia che esegue l'azione in posizione 1 della coda del motore (`Queue.Head` → `Actions.SlotFor`) | `DiagnosticPixel.lua:46-49` (fixture); `test_pixel_differential.lua`, `test_protocol_v3.lua` (esempi esadecimali del README) |
| Nero | Nessuna raccomandazione eseguibile, incluso fuori portata e cast/canale in corso (README passo 4 e tabella *Special states*) | `RenderDiagnosticPixel(nil)` | `0,0,0,1` | idem | stato di default alla creazione | fuori combattimento (opzione `pixel.combatOnly`, attiva di default, decisione del proprietario 2026-10-15: l'utente sceglie ingaggio e spell di apertura), coda vuota, wait del motore, posizione 1 non pronta, stato `missing` (nessuna lista per la classe) o `error`, cast o canale del giocatore, fuori portata confermato, finestra ACK | `DiagnosticPixel.lua:41-44`; `test_protocol_v3.lua` |
| Bianco | Raccomandazione senza slot deterministico | `RenderDiagnosticPixel` ramo `else` | `1,1,1,1` | idem | — | posizione 1 del motore (spell o item pronto) che nessuna cella applicata contiene | `DiagnosticPixel.lua:50-51`; test "unmapped" |
| Fronte ACK | `colore → nero → colore` = due cicli distinti; ≥ 3 campioni neri a 50 Hz (README) | `AcknowledgeDiagnosticPixelCast`, `ACK_GAP_SECONDS = 0.060`, `SchedulePixelRelease` | nero per 60 ms, poi ultimo valore desiderato; token annulla timer vecchi | idem | — | `UNIT_SPELLCAST_SUCCEEDED` del player; confronto per ID esatto o nome localizzato (come l'originale); item tramite `C_Item.GetItemSpell` | `DiagnosticPixel.lua:21-98`; differenziale con 3000 operazioni casuali |
| Soppressione "manual use" | Nero durante l'uso manuale di consumabili HCOB | `ManualUsePending()` (SurvivalStrip) | nero | — | — | **assente**: la Survival Strip è esclusa; nessuno stato equivalente da rappresentare | `DiagnosticPixel.lua:33-36` |
| Dimensione | Area campionabile | `SetSize(8, 8)` | 8×8 unità UI, nessuna scala propria | — | — | invariata | test statico in `test_pixel_differential.lua` |
| Parent / scala | Esclusa dalla scala HUD (README passo 2) | parent `UIParent` | scala effettiva = scala di UIParent | — | — | invariata; nessun antenato della griglia (prova in `test_grid_pixel_isolation.lua`) | idem |
| Strata / livelli | Sopra la UI | `SetFrameStrata("TOOLTIP")`, texture `OVERLAY` con `SetAllPoints` | — | — | — | invariati; griglia in `MEDIUM` | test statici |
| Mouse | Nessuna interazione | `EnableMouse(false)` | — | — | — | invariato; il trascinamento usa una maniglia separata che disegna solo bordi esterni da 2 px | `test_grid_pixel_isolation.lua` |
| Ancoraggio | "immediatamente a destra del frame Advisor, 4 px" (README passo 2) | `SetPoint("TOPLEFT", advisor, "TOPRIGHT", 4, 0)`; `advisor` 282×82, scala HUD | coordinate UIParent | ancorato all'Advisor HCOB | — | **adattato**: anchor indipendente `ForeverOneButtonPixelAnchor` (default `TOPLEFT` di UIParent +16/−16), posizionabile dall'utente; non esiste un Advisor | vedi §4 |
| Visibilità | Mostrato se HUD visibile e `diagPixel ~= false` | `CoreHUD.lua:302` | — | — | — | `pixel.enabled` (default acceso), indipendente dalla griglia | `test_grid_pixel_isolation.lua` |
| Frequenza | Campionamento previsto a 50 Hz (commento originale) | aggiornamento a ogni refresh dell'Advisor (0,12 s in combattimento / 0,30 s fuori, `Core/Events.lua`) | — | — | — | refresh a 50 ms (`Model.POLL_SECONDS`); colore riscritto solo quando cambia lo stato | `Bridge/Model.lua` |
| Header, versione, checksum, marker, bitfield, byte order | — | **assenti** nell'originale (il protocollo v3 è solo colore) | — | — | — | nessuno aggiunto | lettura integrale del producer |
| Pixel multipli / ordine dei pixel | — | **assenti**: un solo quadrato | — | — | — | uno solo | idem |
| Atomicità / frame parziali | Ogni stato è un colore pieno; il fronte nero separa cicli | un solo `SetColorTexture` per stato, nessuna sincronizzazione esplicita | — | — | — | identico; nessun marker inventato | differenziale |
| Classe / spell nel colore | Il colore non codifica né classe né spell (protocollo "slot-only") | — | — | — | — | identico: nessuna informazione aggiuntiva | README HCOB |
| Telemetria accessoria | — | nessun altro canale nel producer | — | — | — | nessuna | — |

## 3. Semantica dello slot

Nel producer originale lo slot è la posizione fissa della panel per classe
(`ActionPanel.actions[CLASS][slot]`), associata all'azione dalla tabella
pubblicata nel README HCOB. In Forever One Button lo slot è il **numero della
cella della griglia** (1–20) che contiene l'azione scelta dall'utente, ed è
esattamente il pulsante che il tasto dell'utente attiva.

Il tipo di informazione resta lo stesso ("quale pulsante della panel esegue
la raccomandazione"); cambia la tabella slot → azione, che ora è quella
configurata dall'utente invece della tabella per classe di HCOB.

## 4. Mapping coda del motore → protocollo

Dalla 1.0.0 la coda è costruita da `Engine/Queue.lua` (descrizione completa in
`ARCHITECTURE.md`, "La coda"); prima veniva da JustAC, che non è più usato a
runtime.

| Aspetto | Comportamento del motore | Uso nel modello e nel pixel |
|---|---|---|
| Costruzione | `Queue.Build(previous)` a ogni refresh (`Bridge/Model.lua`, 50 ms), in `pcall` | un errore produce lo stato `error`: nessun segno, nero |
| Risultato | `{status, detail, tree, context, entries, count}`; una coda invariata restituisce lo stesso oggetto | confronto per identità: pixel e griglia aggiornati solo ai cambi |
| Elementi | `{kind, id, base, ready}`; `kind` = `spell` (ID al rango premuto, `Engine/Ranks.lua`), `item` (`-itemID`) o `wait` (`WAIT_ID = -999999999`, lo stesso valore registrato dalla 0.1.0) | spell → `SlotFor(id)`; item → cella item `-id`; wait → nero |
| Posizione 1 | `Queue.Head`: l'ID della posizione 1 solo se è una spell o un item **pronto**; le voci pronte precedono sempre quelle non pronte, quindi è la prima voce pronta della lista (o il gap closer) | il pixel codifica solo questa posizione, come l'originale codificava solo la raccomandazione principale |
| Wait | niente di pronto in combattimento o con un bersaglio attaccabile → posizione 1 = wait | `Head` = `nil` → nero |
| Posizioni 2+ | voci pronte restanti, poi quelle in arrivo; il trigger di burst pronto può essere spostato in posizione 2 | solo griglia e striscia; mai nel pixel |
| ID visualizzati | rango più alto conosciuto | una cella spell corrisponde se l'ID è uguale, se `C_Spell.GetOverrideSpell(cella)` è uguale, o altrimenti se il nome localizzato è uguale (altro rango della stessa spell) |
| Cura d'emergenza | salute sotto `emergencyHealBelow` (30 %) in combattimento: `Defensives.EmergencyHeal` (spell di cura pronta con una cella, altrimenti l'oggetto di cura con una cella) va in posizione 1 e sostituisce il wait | pixel = sua cella; la portata del bersaglio non si applica; salute non leggibile → mai |
| Fuori dalla coda | interruzioni (`Engine/Interrupts.lua`), il resto dei difensivi (`Engine/Defensives.lua`), promemoria (`Engine/Precombat.lua`) | mostrati accanto alla griglia; nessuno di essi viene passato a `Pixel.Update` |

Conversioni introdotte, tutte necessarie al protocollo e nessuna decisionale:
(1) ID della coda → numero di cella (lookup nelle associazioni, compresa
l'equivalenza dei ranghi per nome: HCOneButton otteneva lo stesso effetto con
ID di rango 1 nella tabella e pulsanti `/cast Nome`; nel test differenziale
l'originale riceve la stessa equivalenza tramite la sua `idToSlot`);
(2) wait, posizione 1 non pronta, cast/canale, fuori portata confermato →
nero, perché il protocollo li definisce "nessuna raccomandazione eseguibile";
(3) posizione 1 non associata → bianco.

## 5. Policy per dati assenti, segreti o non rappresentabili

| Caso | Pixel | Griglia | Motivo |
|---|---|---|---|
| Fuori combattimento (`InCombatLockdown()` falso) con `pixel.combatOnly` | nero; pubblicazione immediata a `PLAYER_REGEN_DISABLED`, nero immediato a `PLAYER_REGEN_ENABLED` | suggerimenti mostrati | cambia solo il momento: encoder e colori invariati; nero è uno stato già previsto dal v3 |
| Nessuna lista per la classe (`missing`) / errore del motore (`error`) | nero | stato esplicito, nessun segno sulle celle | nessun consiglio sostitutivo |
| Salute, potere, cooldown, aure segreti | — | — | il motore non li confronta: risposte sì/no del client (`Engine/Secret.lua`) o "sconosciuto"; uno sconosciuto non blocca e non crea una voce |
| Cast/canale con nome segreto | nero | "casting" | un valore segreto non-nil indica comunque un cast in corso |
| Portata segreta o `nil` | nessuna soppressione | — | solo un `false` leggibile conta come fuori portata |
| Pulsanti non ancora configurati (reload in combattimento) | bianco, mai uno slot | "changes apply after combat" | lo slot deve indicare un pulsante che esegue davvero l'azione |

## 6. Prove

| Prova | Comando | Esito |
|---|---|---|
| Regressione HCOB immutata sulla fixture | `lua5.1 tests/test_original_regression.lua` | PASS |
| Differenziale producer originale ↔ porting (casi scriptati, 20 slot, 3000 operazioni casuali, flusso completo di scritture colore) | `lua5.1 tests/test_pixel_differential.lua` | PASS: 2272 operazioni, 1593 scritture identiche |
| Encoding end-to-end coda → colore a 8 bit, esempi del README, stati speciali | `lua5.1 tests/test_protocol_v3.lua` | PASS |
| Provenienza fixture (hash blob Git) | `python -m unittest tests/test_fixtures.py` | PASS |
| `Queue.Head`: wait senza testa, posizione 1 pronta | `lua5.1 tests/test_queue.lua` | PASS |
| Cattura reale a schermo | — | **non eseguita** |

## 7. Difetti e limiti dell'originale (documentati, non corretti)

- Il README dichiara "8×8 frame unscaled": in realtà la dimensione segue la
  scala di UIParent (impostazione "UI Scale" del client); in pixel fisici il
  quadrato è 8 × scala. Riprodotto identico.
- `ACK_GAP_SECONDS` e il riconoscimento per nome localizzato possono
  riconoscere come "stessa spell" un'altra spell con lo stesso nome. Riprodotto.

