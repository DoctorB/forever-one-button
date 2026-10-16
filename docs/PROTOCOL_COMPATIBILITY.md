# Compatibilità del protocollo pixel e mapping JustAC

Stato: **contratto del producer riprodotto e provato offline**.

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
| Colore "slot" | Slot fisso della panel 1–20 (README passi 5–6) | `RenderDiagnosticPixel` → `HCOB.UI.ActionPanel.idToSlot[spellId]` | `R = slot*12/255`, `G = 96/255`, `B = 224/255`, `A = 1` via `SetColorTexture`; a 8 bit: R = 12…240, G = 96, B = 224 | tutta l'area 8×8 | slot assente → bianco | cella della griglia che esegue l'azione in posizione 1 della coda JustAC (`Actions.SlotFor`) | `DiagnosticPixel.lua:46-49` (fixture); `test_pixel_differential.lua`, `test_protocol_v3.lua` (esempi esadecimali del README) |
| Nero | Nessuna raccomandazione eseguibile, incluso fuori portata e cast/canale in corso (README passo 4 e tabella *Special states*) | `RenderDiagnosticPixel(nil)` | `0,0,0,1` | idem | stato di default alla creazione | fuori combattimento (opzione `pixel.combatOnly`, attiva di default, decisione del proprietario 2026-10-15: l'utente sceglie ingaggio e spell di apertura), coda vuota, `WAIT_SENTINEL` di JustAC, JustAC assente/errore/dati non validi/non leggibili, posizione 1 segreta, cast o canale del giocatore, fuori portata confermato, finestra ACK | `DiagnosticPixel.lua:41-44`; `test_protocol_v3.lua` |
| Bianco | Raccomandazione senza slot deterministico | `RenderDiagnosticPixel` ramo `else` | `1,1,1,1` | idem | — | posizione 1 JustAC (spell o item) che nessuna cella applicata contiene | `DiagnosticPixel.lua:50-51`; test "unmapped" |
| Fronte ACK | `colore → nero → colore` = due cicli distinti; ≥ 3 campioni neri a 50 Hz (README) | `AcknowledgeDiagnosticPixelCast`, `ACK_GAP_SECONDS = 0.060`, `SchedulePixelRelease` | nero per 60 ms, poi ultimo valore desiderato; token annulla timer vecchi | idem | — | `UNIT_SPELLCAST_SUCCEEDED` del player; confronto per ID esatto o nome localizzato (come l'originale); item tramite `C_Item.GetItemSpell` | `DiagnosticPixel.lua:21-98`; differenziale con 3000 operazioni casuali |
| Soppressione "manual use" | Nero durante l'uso manuale di consumabili HCOB | `ManualUsePending()` (SurvivalStrip) | nero | — | — | **assente**: la Survival Strip è esclusa; nessuno stato equivalente da rappresentare | `DiagnosticPixel.lua:33-36` |
| Dimensione | Area campionabile | `SetSize(8, 8)` | 8×8 unità UI, nessuna scala propria | — | — | invariata | test statico in `test_pixel_differential.lua` |
| Parent / scala | Esclusa dalla scala HUD (README passo 2) | parent `UIParent` | scala effettiva = scala di UIParent | — | — | invariata; nessun antenato della griglia (prova in `test_grid_pixel_isolation.lua`) | idem |
| Strata / livelli | Sopra la UI | `SetFrameStrata("TOOLTIP")`, texture `OVERLAY` con `SetAllPoints` | — | — | — | invariati; griglia in `MEDIUM` | test statici |
| Mouse | Nessuna interazione | `EnableMouse(false)` | — | — | — | invariato; il trascinamento usa una maniglia separata che disegna solo bordi esterni da 2 px | `test_grid_pixel_isolation.lua` |
| Ancoraggio | "immediatamente a destra del frame Advisor, 4 px" (README passo 2) | `SetPoint("TOPLEFT", advisor, "TOPRIGHT", 4, 0)`; `advisor` 282×82, scala HUD | coordinate UIParent | ancorato all'Advisor HCOB | — | **adattato**: anchor indipendente `ForeverOneButtonPixelAnchor` (default `TOPLEFT` di UIParent +16/−16), posizionabile dall'utente; non esiste un Advisor | vedi §4 |
| Visibilità | Mostrato se HUD visibile e `diagPixel ~= false` | `CoreHUD.lua:302` | — | — | — | `pixel.enabled` (default acceso), indipendente dalla griglia | `test_grid_pixel_isolation.lua` |
| Frequenza | Campionamento previsto a 50 Hz (commento originale) | aggiornamento a ogni refresh dell'Advisor (0,12 s in combattimento / 0,30 s fuori, `Core/Events.lua`) | — | — | — | refresh a 50 ms (throttle out-of-combat di JustAC); colore riscritto solo quando cambia lo stato | `Bridge/Model.lua` |
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

## 4. Mapping JustAC → protocollo

Contratto JustAC verificato in `wealdly/JustAC` @ `431e9a220dc3cf4bbfe8c05818a1de88ee40fa14`
(5.9.0-beta2, 2026-10-08), identico alla copia installata nella beta.

| Aspetto | Evidenza JustAC | Uso nel bridge |
|---|---|---|
| Acquisizione | `LibStub:NewLibrary("JustAC-SpellQueue", 43)` (`SpellQueue.lua:4`); caricata con JustAC, nessuna dipendenza esterna | `LibStub:GetLibrary(name, true)` ad ogni lettura: gestisce assenza e caricamento tardivo |
| Firma | `function SpellQueue.GetCurrentSpellQueue()` (`:2333`), chiamata con il punto, nessun argomento, un valore di ritorno | `pcall(lib.GetCurrentSpellQueue)` |
| Risultato | la tabella di modulo `lastSpellIDs` (`:29`), condivisa e mutata in place (`wipe` + append, `:1963-1999`, `:2371`) | copia per posizione fino al primo `nil`, con `rawget`; mai scritta |
| Elementi | spell ID > 0; `-itemID` per gli item della Custom Queue (`:1393-1396`); `WAIT_SENTINEL = -999999999` in posizione 1 (`:10`, `:2328`) | spell → `SlotFor(id)`; item → cella item `-id`; wait → nero |
| ID visualizzati | la coda contiene l'ID "display" (override) (`ClaimSpellID`, `BlizzardAPI.GetDisplaySpellID`, `SpellQuery.lua:564`); su Forever le spell hanno ranghi e JustAC sceglie il rango premuto (`PressedRank`, `SpellQuery.lua:287-300`) | una cella spell corrisponde se l'ID è uguale, se `C_Spell.GetOverrideSpell(cella)` è uguale, o altrimenti se il nome localizzato è uguale (altro rango della stessa spell) |
| Posizioni | su retail 1 = scelta dell'Assisted Combat; **su Forever l'Assisted Combat è spento e la posizione 1 viene dal motore Forever di JustAC** (`BlizzardAPI.HasGamePick()` falso, `Documentation/FOREVER_ENGINE_DESIGN.md:10`); 2+ = coda JustAC (`:2401-2427`) | il pixel codifica solo la posizione 1, come l'originale codificava solo la raccomandazione principale; la griglia etichetta le posizioni 1…N senza riordinare |
| Throttle e durata | 0,03 s in combattimento, 0,05 s fuori (`:2355`); tra due build ritorna la stessa tabella | polling a 0,05 s; snapshot riusato se identico |
| Aggiornamenti | nessuna callback pubblica: JustAC stesso fa polling in `OnUpdateTick` (`JustAC.lua:2322`) | polling (motivato in `ARCHITECTURE.md`) |
| Coda congelata | modalità manuale (`isManualMode`) e canale in corso restituiscono l'ultima coda (`:2335`, `:2345`); build vuota conserva la precedente (`:1966-1969`) | semantica di JustAC preservata: è ciò che JustAC stesso mostra; durante il canale il pixel è comunque nero (stato del protocollo) |
| Visibilità | se le regole di visibilità di JustAC nascondono la coda, la tabella viene svuotata (`:2361-2373`) | coda vuota → nero, "no suggestion" |

Conversioni introdotte, tutte necessarie al protocollo e nessuna decisionale:
(1) ID JustAC → numero di cella (lookup nelle associazioni, compresa
l'equivalenza dei ranghi per nome: HCOneButton otteneva lo stesso effetto con
ID di rango 1 nella tabella e pulsanti `/cast Nome`; nel test differenziale
l'originale riceve la stessa equivalenza tramite la sua `idToSlot`);
(2) `WAIT_SENTINEL`, posizione 1 non leggibile, cast/canale, fuori portata
confermato → nero, perché il protocollo li definisce "nessuna raccomandazione
eseguibile"; (3) posizione 1 non associata → bianco.

## 5. Policy per dati assenti, segreti o non rappresentabili

| Caso | Pixel | Griglia | Motivo |
|---|---|---|---|
| Fuori combattimento (`InCombatLockdown()` falso) con `pixel.combatOnly` | nero; pubblicazione immediata a `PLAYER_REGEN_DISABLED`, nero immediato a `PLAYER_REGEN_ENABLED` | suggerimenti mostrati | cambia solo il momento: encoder e colori invariati; nero è uno stato già previsto dal v3 |
| JustAC assente / metodo assente / errore / risultato non tabella | nero | stato esplicito, nessun segno sulle celle | nessun consiglio sostitutivo |
| Voce non numerica, frazionaria o zero | snapshot intero `INVALID` → nero | "unexpected data" | non mostrare dati corrotti |
| Tabella o posizione 1 segreta (`issecretvalue`) / tabella non accessibile (`canaccesstable`) | nero | "?" in coda, "unreadable" | il valore non viene confrontato né usato; non si afferma un'azione eseguibile |
| Cast/canale con nome segreto | nero | "casting" | un valore segreto non-nil indica comunque un cast in corso |
| Portata segreta o `nil` | nessuna soppressione | — | solo un `false` leggibile conta come fuori portata |
| Pulsanti non ancora configurati (reload in combattimento) | bianco, mai uno slot | "changes apply after combat" | lo slot deve indicare un pulsante che esegue davvero l'azione |

## 6. Prove

| Prova | Comando | Esito |
|---|---|---|
| Regressione HCOB immutata sulla fixture | `lua5.1 tests/test_original_regression.lua` | PASS |
| Differenziale producer originale ↔ porting (casi scriptati, 20 slot, 3000 operazioni casuali, flusso completo di scritture colore) | `lua5.1 tests/test_pixel_differential.lua` | PASS: 2272 operazioni, 1593 scritture identiche |
| Encoding end-to-end coda JustAC → colore a 8 bit, esempi del README, stati speciali | `lua5.1 tests/test_protocol_v3.lua` | PASS |
| Provenienza fixture (hash blob Git) | `python -m unittest tests/test_fixtures.py` | PASS |
| Cattura reale a schermo | — | **non eseguita**: client non pilotabile da qui |

## 7. Difetti e limiti dell'originale (documentati, non corretti)

- Il README dichiara "8×8 frame unscaled": in realtà la dimensione segue la
  scala di UIParent (impostazione "UI Scale" del client); in pixel fisici il
  quadrato è 8 × scala. Riprodotto identico.
- `ACK_GAP_SECONDS` e il riconoscimento per nome localizzato possono
  riconoscere come "stessa spell" un'altra spell con lo stesso nome. Riprodotto.

