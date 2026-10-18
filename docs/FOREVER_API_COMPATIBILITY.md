# Compatibilità con le API di WoW Forever

Legenda: **verificato** = osservato sul client target con il metodo indicato;
**indiretto** = verificato su Forever da un altro addon dello stesso autore, o
usato anche dal codice di JustAC 6.0.0 installato sulla stessa build (ricerca
nei sorgenti installati, 2026-10-16: l'API compare, non è provato che si
comporti come atteso); **non verificato** = da provare in gioco
(`RUNTIME_CHECKLIST.md`). I test offline usano mock e non sono prova di
compatibilità.

## Target

| Voce | Valore | Stato | Evidenza |
|---|---|---|---|
| Prodotto | WoW Forever, client `_classic_beta_` (`wow_classic_beta`) | verificato | `.build.info` locale; `WOW_PROJECT_ID` 18 (probe ChatGuard) |
| Build | 1.60.1.70374 | verificato | `.build.info` letto il 2026-10-15; `forever-chatguard/docs/compatibility.md` (probe 2026-10-14) |
| Interface | `16001` | verificato | `GetBuildInfo()` nel probe ChatGuard; anche nel TOC di JustAC 5.9.0-beta2 |
| Lua | 5.1, libreria `bit`, niente `goto`/`//`/`utf8` | verificato | probe ChatGuard |
| Installazione | `World of Warcraft\_classic_beta_\Interface\AddOns\ForeverOneButton\` | verificato (cartella AddOns presente) | ispezione locale |
| Combat log | `COMBAT_LOG_EVENT_UNFILTERED` vietato | verificato | `hc-one-button/docs/FOREVER_FEASIBILITY.md` — non usato qui |
| Secret values | HP e potere secret anche fuori combattimento | verificato | idem — il motore non li confronta mai (`Engine/Secret.lua`) |
| `issecretvalue`, `canaccessvalue`, `canaccesstable` | presenti | verificato | probe ChatGuard |

## API usate da Forever One Button

### Interfaccia, celle e pixel

| API | Uso | Stato | Note / gestione |
|---|---|---|---|
| `CreateFrame`, texture, font string, `UIParent` | UI | verificato (ChatGuard) | — |
| `BasicFrameTemplateWithInset`, `UIPanelButtonTemplate`, `UICheckButtonTemplate` | opzioni | verificato (ChatGuard) | nessun altro template usato fuori dai pulsanti |
| `SecureActionButtonTemplate`, attributi `type1`/`spell`/`item`, `useOnKeyDown` | celle, riga promemoria | non verificato | da provare: click e tasto eseguono una volta |
| `RegisterForClicks("AnyDown","AnyUp")` / `("AnyUp")` | celle / promemoria | non verificato | come HCOB su Era |
| `RegisterStateDriver(row, "visibility", "[combat] hide; show")` | riga promemoria nascosta in combattimento | indiretto | applicato solo fuori combattimento; da provare in gioco |
| `SetOverrideBindingClick`, `ClearOverrideBindings`, `GetBindingAction` | binding | non verificato | protette in combattimento: usate solo fuori |
| `GetCVarBool("ActionButtonUseKeyDown")` | celle | non verificato | `SafeCall` |
| `InCombatLockdown`, `PLAYER_REGEN_*` | combattimento; pixel solo in combattimento | verificato (ChatGuard: `InCombatLockdown`; primo test in gioco 2026-10-15: pixel nero fuori e attivo all'ingaggio) | — |
| `C_Spell.GetSpellName/GetSpellTexture/GetOverrideSpell/GetSpellInfo` | icone, nomi, override | indiretto | tutte via `SafeCall`; risultati segreti → `nil` |
| `C_Item.GetItemNameByID/GetItemIconByID/GetItemSpell` | item | non verificato | `SafeCall`/`pcall` |
| `UnitCastingInfo`, `UnitChannelInfo` (`player`) | nero durante cast/canale | indiretto | un valore secret non-nil è trattato come cast in corso |
| `UNIT_SPELLCAST_SUCCEEDED` in combattimento | fronte ACK; lanci ricordati dal motore | **verificato** (2026-10-15, log diagnostico) | 18 eventi, nessuno `spellID` segreto; 9 lanci della spell codificata, 8 fronti chiusi + 1 riavviato |
| `SPELLS_CHANGED`, `PLAYER_SPECIALIZATION_CHANGED`, `ACTIONBAR_SLOT_CHANGED`, `BAG_UPDATE_DELAYED` | icone, riempimento automatico | non verificato | registrazione in `pcall` (nome evento sconosciuto non blocca il caricamento) |
| Frame della barra in basso di Blizzard (`ActionButton1..12`, `MainMenuBarArtFrame`, micro-menu, borse; `StanceBar*`, `MainMenuExpBar`/`StatusTrackingBarManager` mantenuti) | opzione "nascondi barra Blizzard" | **verificato** (2026-10-15, proprietario: barra principale, micro-menu e borse nascosti; posture ed esperienza visibili) | layout moderno: `MainActionBar` con `MainActionBarButtonContainer1..12`, `StanceBar` e `StatusTrackingBarManager` figli di `UIParent`; nomi candidati classici e moderni, solo quelli esistenti vengono toccati; `SetAlpha`/`EnableMouse` solo fuori combattimento; `/fob probe frames` registra quali esistono |
| `SavedVariablesPerCharacter` | celle per personaggio | verificato (2026-10-15) | il primo test in gioco ha riempito e conservato le celle |
| `GetCursorInfo`, `ClearCursor` | drag & drop | non verificato | firma moderna `("spell", index, book, spellID)`; valori controllati |
| `GameTooltip`, `UISpecialFrames`, `SlashCmdList` | UI | verificato (ChatGuard per `UISpecialFrames` e slash) | — |
| `C_Timer.After`, `GetTime` | ACK, riempimento automatico | verificato (ChatGuard) | — |

### Motore dei suggerimenti (`Engine/`)

Tutte le chiamate sono in `pcall`; un risultato segreto o assente diventa
"sconosciuto" (`nil`), che non blocca e non crea suggerimenti. Nessuna di
queste API è stata ancora provata in gioco con il motore interno.

| API | Uso | Stato | Note / gestione |
|---|---|---|---|
| `C_CurveUtil.CreateCurve`, `Enum.LuaCurveType.Linear`, `UnitHealthPercent(unit, false, curve)`, `UnitPowerPercent(unit, type, false, curve)` | salute/potere sotto una soglia (`Engine/Secret.lua`) | indiretto | curva a gradino autoverificata su input in chiaro prima dell'uso; senza API → sconosciuto |
| `C_StringUtil.TruncateWhenZero` | lettura zero/non zero del risultato segreto, tramite una font string nascosta | indiretto | prova di andata e ritorno in chiaro: se la lettura non funziona → sconosciuto |
| `C_Spell.GetSpellCooldownDuration`, `Cooldown:SetCooldownFromDurationObject`, `IsShown` | cooldown in corso su un widget Cooldown nascosto | indiretto | ripiego su `C_Spell.GetSpellCooldown` in chiaro (GCD escluso) |
| `UnitHealth`, `UnitHealthMax`, `UnitPower`, `UnitPowerMax` | valori in chiaro quando il client li dà | indiretto | `UnitPowerMax` per convertire soglie assolute di rabbia/energia |
| `C_Spell.IsSpellUsable`, `C_Spell.IsSpellInRange`, `C_Spell.IsCurrentSpell` | usabile/risorse, portata, Attacco già attivo | indiretto | portata: solo un `false` leggibile conta |
| `IsPlayerSpell`, `IsSpellKnown` | ranghi conosciuti | indiretto | ultima risposta leggibile tenuta in cache |
| `C_ClassTalents.GetActiveConfigID/GetTraitTreeForSpec`, `C_SpecializationInfo`, `C_Traits.GetGroupDisplayInfoByTreeID/GetGroupCurrencyInfo` | punti per albero dei talenti (`Engine/Trees.lua`) | indiretto | dati illeggibili → albero di default della classe; ricalcolo a `PLAYER_TALENT_UPDATE`, `TRAIT_CONFIG_UPDATED` |
| `GetNumShapeshiftForms`, `GetShapeshiftFormInfo`, `GetShapeshiftForm`, `GetShapeshiftFormID`, `UPDATE_SHAPESHIFT_FORM` | postura/forma attiva, forma d'orso | indiretto | la postura attiva non è mai candidata |
| `UnitExists`, `UnitCanAttack`, `UnitIsDeadOrGhost`, `UnitClassification`, `UnitLevel`, `UnitGUID` (`target`) | bersaglio attaccabile, boss, DoT sul bersaglio corrente | indiretto | — |
| `UnitThreatSituation` sulle nameplate `nameplate1..40` | nemici ingaggiati (st/cleave/aoe) | indiretto | nameplate spente → 0, letto come un bersaglio |
| `C_UnitAuras.GetPlayerAuraBySpellID`, `C_UnitAuras.GetUnitAuraBySpellID` | buff, stack, promemoria | indiretto | in combattimento le aure del giocatore sono considerate illeggibili: vale il lancio recente o la scadenza ricordata |
| `IsStealthed`, `GetComboPoints`, `GetTotemInfo` | condizioni `stealth`, `resource`, `totem` | indiretto | — |
| `PLAYER_SWING` (durata, tipo) | condizione `swing` | indiretto | payload letto come fa JustAC 6.0.0 su Forever; durata segreta ignorata |
| `UnitCastingInfo`, `UnitChannelInfo` (`target`), `UnitIsMinion` | interruzioni | indiretto | flag "non interrompibile" segreto → interrompibile; mob "minus" e minion esclusi |
| `C_Item.GetItemCount`/`GetItemCount`, `C_Container.GetItemCooldown`, `GetSpellBaseCooldown` | oggetti di cura, difensivi a lungo cooldown | indiretto (`C_Container.GetItemCooldown`: non verificato, non presente nei sorgenti JustAC) | cooldown degli oggetti segreto in combattimento: un uso visto nel combattimento conta come cooldown fino alla fine |
| `C_LossOfControl.GetActiveLossOfControlDataCount/GetActiveLossOfControlData` | liberazione dal controllo (spento di default) | indiretto | — |
| `C_Item.GetWeaponEnchantInfo`, `Enum.ItemEnchantType`, `GetWeaponEnchantInfo`, `GetInventoryItemID`, `C_Item.GetItemInfoInstant`, `C_Item.IsUsableItem` | promemoria arma e consumabili | indiretto | — |
| `IsMounted`, `IsInGroup`, `UnitIsConnected`, unità `party1..4`, `pet` | promemoria, cure di gruppo, pet | indiretto | — |

## Secret values: politica

1. Ogni valore proveniente dal client passa da `ns.IsSecret`
   (`issecretvalue`) prima di confronti, aritmetica, uso come chiave o
   `tostring`; i risultati di API passano da `ns.SafeCall` o da `pcall` con
   scarto dei valori segreti.
2. Un valore segreto non viene mai "declassificato": diventa *sconosciuto*,
   oppure il client risponde a una sola domanda sì/no su di esso
   (`Engine/Secret.lua`: una soglia per decisione, nessuna funzione che
   restituisca un numero). Sconosciuto non crea mai una raccomandazione e non
   blocca una voce della lista; per la portata → nessuna soppressione; per un
   cast → cast in corso.
3. Nessun valore segreto viene stampato o salvato.

I test simulano i valori segreti con userdata che falliscono su confronto,
aritmetica, concatenazione e `tostring` (`tests/test_state.lua` anche per le
curve e `TruncateWhenZero`): provano che il codice non li tocca nei percorsi
simulati, **non** che i veri valori Forever si comportino così.

## Frame protetti e taint

- Pulsanti secure (celle e riga promemoria) creati al caricamento senza
  attributi; configurazione solo fuori combattimento (anche
  `RegisterForClicks` e lo state driver), differita dopo un reload in
  combattimento. Il mock fallisce su qualsiasi operazione protetta in combattimento.
- Nessuna operazione protetta nel percorso di refresh (50 ms): solo texture e testi.
- Taint: non verificabile offline. **Pendente** in gioco (`/console taintLog 1`).

## Verifiche runtime pendenti

Elenco completo e procedura: `docs/RUNTIME_CHECKLIST.md`.
