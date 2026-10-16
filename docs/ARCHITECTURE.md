# Architettura

## Flusso dati

```text
JustAC-SpellQueue.GetCurrentSpellQueue()          (JustAC, unico Advisor)
                 |
                 v  Bridge/JustACAdapter.lua      copia per posizione, stati espliciti
       snapshot immutabile {status, entries[i] = {kind, id}}
                 |
                 v  Bridge/Model.lua              polling 50 ms; osservazioni cast/portata
        +--------+-------------------+
        |                            |
        v                            v
 Panel/Grid.lua               Pixel/DiagnosticPixel.lua   (porting del producer HCOB v3)
 segni posizione 1..N,          posizione 1 -> Actions.SlotFor -> colore
 striscia della coda                 |
        ^                            v
        |                    quadrato 8x8 su UIParent
 Panel/Actions.lua  <--- associazioni cella/azione/tasto scelte dall'utente
 (attributi secure, override binding, solo fuori combattimento)
```

## Moduli e responsabilità

| File | Responsabilità | Non fa |
|---|---|---|
| `Core/Diagnostics.lua` | log diagnostico opzionale (spento di default) di scritture pixel, lanci, ACK, suggerimenti e combattimento in `ForeverOneButtonLog`; riepilogo dei fronti | non modifica il protocollo, nessun pixel aggiuntivo, valori segreti registrati come "secret" |
| `Core/Init.lua` | namespace privato (`...`), costanti (`MAX_SLOTS = 20`, stati), helper per secret values (`IsSecret`, `Readable`, `SafeCall`) | nessuna globale oltre a quelle elencate sotto |
| `Core/Settings.lua` | `ForeverOneButtonDB`, sanitizzazione con whitelist, limiti | nessuna importazione da HCOB o JustAC |
| `Panel/Keys.lua` | normalizzazione dei tasti (riuso tecnico HCOB), tasti rifiutati, etichette brevi | — |
| `Bridge/JustACAdapter.lua` | acquisizione libreria, lettura, snapshot, classificazione voci | non riordina, non filtra, non scrive nella tabella JustAC, non usa API interne |
| `Panel/Actions.lua` | assegnazioni, tasti effettivi (utente/default), conflitti, applicazione secure, `SlotFor` | non assegna né rilega nulla in base alla coda |
| `Panel/AutoFill.lua` | riempimento automatico stabile dal pool di abilità di JustAC (`JustAC-BlizzardAPI.GetRotationSpells`), fuori combattimento | non legge la coda né il suggerimento corrente; non sposta mai una spell già collocata |
| `Pixel/DiagnosticPixel.lua` | encoder/renderer v3, fronte ACK, posizione/visibilità | nessun pixel di debug, nessuna informazione aggiuntiva |
| `Panel/Grid.lua` | griglia, segni, striscia coda, stato, controllo sovrapposizione | nessun `OnClick` Lua sui pulsanti, nessuna azione |
| `Bridge/Model.lua` | ciclo di refresh, rilevazione cambi, cast/portata | nessuna rotazione |
| `UI/Options.lua` | finestra opzioni (solo whitelist), cattura tasti | — |
| `Core/Commands.lua` | `/fob` | nessun comando spam/pull/priorità |
| `Core/Events.lua` | ciclo di vita, differimento dopo il combattimento, ACK | nessun evento genera input |

Globali create: `ForeverOneButtonDB`, `ForeverOneButtonCharDB`, `SLASH_FOREVERONEBUTTON1/2`,
`SlashCmdList.FOREVERONEBUTTON` e i frame con nome `ForeverOneButton*`
(i pulsanti hanno bisogno di un nome per i binding `CLICK`). Verificato in
`tests/test_toc.lua`.

## Ciclo di vita

| Momento | Cosa succede |
|---|---|
| Caricamento file | creazione frame (pulsanti secure senza attributi né click registrati) |
| `ADDON_LOADED` (proprio) | `Settings.Load()`: sanitizzazione di `ForeverOneButtonDB` |
| `PLAYER_LOGIN` | posizione/visibilità pixel, layout griglia, attributi e binding (differiti se in combattimento), avvio polling |
| Polling 50 ms | lettura JustAC, osservazioni, aggiornamento pixel/griglia solo se qualcosa è cambiato |
| `PLAYER_REGEN_DISABLED` | chiusura opzioni e cattura tasti |
| `PLAYER_REGEN_ENABLED` | applicazione di layout/attributi/binding rimasti in sospeso |
| `SPELLS_CHANGED`, `PLAYER_SPECIALIZATION_CHANGED`, `ACTIONBAR_SLOT_CHANGED` | icone e mapping; richiesta di riempimento automatico (raggruppata, 0,5 s; rimandata dopo il combattimento) |
| `UNIT_SPELLCAST_SUCCEEDED` (player) | fronte ACK del pixel |
| JustAC caricato tardi | rilevato alla lettura successiva, senza reload |
| JustAC scompare/errore | stato esplicito, segni rimossi, pixel nero alla lettura successiva |

Perché il polling: JustAC non espone callback sulla coda (il suo renderer
stesso fa polling, `JustAC.lua:2322`). L'intervallo coincide con il throttle
fuori combattimento di JustAC: chiamare più spesso restituirebbe la tabella in
cache. Costo misurato sul mock: 3,1 µs per refresh e 0 KB allocati con coda
invariata; 55–64 µs e 3,6 KB nel caso peggiore (coda diversa ad ogni refresh,
posizione 1 non associata, scansione degli override). Sul client va misurato
(`docs/TEST_REPORT.md`).

## Combattimento e taint

- Operazioni protette (`SetAttribute`, `RegisterForClicks`,
  `SetOverrideBindingClick`, `ClearOverrideBindings`, `Show/Hide/SetPoint/SetScale`
  della griglia e dei pulsanti) solo fuori combattimento; il mock dei test
  solleva un errore se avvengono in combattimento.
- In combattimento cambiano solo regioni non protette (icone, testi, bordi).
- Codice insicuro: nessun hook su frame Blizzard, nessuna modifica di frame
  secure altrui.

## Prova dell'esclusione delle decisioni HCOneButton

1. **Nessun codice decisionale copiato.** Dai sorgenti HCOB sono riusati solo:
   il producer pixel (presentazione/encoding), la normalizzazione dei tasti e
   la lettura del CVar `ActionButtonUseKeyDown` (integrazione API). Classificazione
   in `ACTION_PANEL_DESIGN.md` §1.
2. **Il producer era un modulo misto?** No: `DiagnosticPixel.lua` riceve uno
   spell ID già deciso. L'unica dipendenza da altri moduli HCOB
   (`SurvivalStrip.ManualUsePending`, `ActionPanel.idToSlot`) è stata rimossa o
   sostituita; il chiamante (`UI/Advisor.lua` → `Advisor/Engine`) non è portato.
3. **Scansione statica** (`tests/test_no_decisions.lua`): il codice spedito,
   senza commenti, non contiene simboli HCOB, Advisor, Engine, priorità,
   spam/pull, API di esecuzione (`CastSpell*`, `UseAction`, `RunMacro`, …),
   `SetBinding`/`SaveBindings`, `macrotext`, `C_AssistedCombat`/`GetNextCastSpell`
   né API interne di JustAC, con un'unica eccezione verificata: la lettura del
   pool `JustAC-BlizzardAPI.GetRotationSpells` in `Panel/AutoFill.lua`
   (richiesta del proprietario; decide quali spell hanno una cella, non cosa
   premere).
4. **Tripwire runtime**: lo stesso test definisce `HCOneButton`, `HCOB_DB` e i
   punti di ingresso dell'Advisor come funzioni che falliscono se chiamate, poi
   esercita assenza/errore/dati non validi di JustAC, combattimento, cast,
   comandi (anche quelli delle funzioni escluse): nessuna chiamata.
5. **Pacchetto**: `scripts/package.py verify` rifiuta codice con riferimenti a
   HCOB_DB, Advisor/Engine, spam button, pull advisor, auto pull.
