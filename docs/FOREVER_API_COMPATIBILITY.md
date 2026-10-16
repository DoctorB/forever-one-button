# Compatibilità con le API di WoW Forever

Legenda: **verificato** = osservato sul client target con il metodo indicato;
**indiretto** = verificato su Forever da un altro addon dello stesso autore o
dedotto dal codice JustAC che gira sulla stessa build; **non verificato** =
da provare in gioco (`RUNTIME_CHECKLIST.md`). I test offline usano mock e non
sono prova di compatibilità.

## Target

| Voce | Valore | Stato | Evidenza |
|---|---|---|---|
| Prodotto | WoW Forever, client `_classic_beta_` (`wow_classic_beta`) | verificato | `.build.info` locale; `WOW_PROJECT_ID` 18 (probe ChatGuard) |
| Build | 1.60.1.70374 | verificato | `.build.info` letto il 2026-10-15; `forever-chatguard/docs/compatibility.md` (probe 2026-10-14) |
| Interface | `16001` | verificato | `GetBuildInfo()` nel probe ChatGuard; anche nel TOC di JustAC 5.9.0-beta2 |
| Lua | 5.1, libreria `bit`, niente `goto`/`//`/`utf8` | verificato | probe ChatGuard |
| Installazione | `World of Warcraft\_classic_beta_\Interface\AddOns\ForeverOneButton\` | verificato (cartella AddOns presente, JustAC vi è installato) | ispezione locale |
| Combat log | `COMBAT_LOG_EVENT_UNFILTERED` vietato | verificato | `hc-one-button/docs/FOREVER_FEASIBILITY.md` — non usato qui |
| Secret values | HP e potere secret anche fuori combattimento | verificato | idem — non usati qui |
| `issecretvalue`, `canaccessvalue`, `canaccesstable` | presenti | verificato | probe ChatGuard |

## API usate da Forever One Button

| API | Uso | Stato | Note / gestione |
|---|---|---|---|
| `CreateFrame`, texture, font string, `UIParent` | UI | verificato (ChatGuard) | — |
| `BasicFrameTemplateWithInset`, `UIPanelButtonTemplate`, `UICheckButtonTemplate` | opzioni | verificato (ChatGuard) | nessun altro template usato fuori dai pulsanti |
| `SecureActionButtonTemplate`, attributi `type1`/`spell`/`item`, `useOnKeyDown` | celle | non verificato | presente nel motore moderno; usato da JustAC? no. Da provare: click e tasto eseguono una volta |
| `RegisterForClicks("AnyDown","AnyUp")` | celle | non verificato | come HCOB su Era |
| `SetOverrideBindingClick`, `ClearOverrideBindings`, `GetBindingAction` | binding | non verificato | protette in combattimento: usate solo fuori |
| `GetCVarBool("ActionButtonUseKeyDown")` | celle | non verificato | `SafeCall` |
| `InCombatLockdown`, `PLAYER_REGEN_*` | combattimento; pixel solo in combattimento | verificato (ChatGuard: `InCombatLockdown` presente) | eventi non verificati |
| `LibStub`, `JustAC-SpellQueue` | coda | indiretto | JustAC 5.9.0-beta2 dichiara Interface 16001 e ha regole Forever (`Data/Forever*.lua`) |
| `C_Spell.GetSpellName/GetSpellTexture/GetOverrideSpell/GetSpellInfo/IsSpellInRange` | icone, nomi, override, portata | indiretto | usate da JustAC su Forever; tutte via `SafeCall`; risultati segreti → `nil` |
| `C_Item.GetItemNameByID/GetItemIconByID/GetItemSpell` | item | non verificato | `SafeCall`/`pcall` |
| `UnitCastingInfo`, `UnitChannelInfo` (`player`) | nero durante cast/canale | indiretto | JustAC: "Own-channel info is plain in combat (validated 2026-07-24)" su retail; un valore secret non-nil è trattato come cast in corso |
| `UNIT_SPELLCAST_SUCCEEDED` (unit event) | fronte ACK | non verificato | `spellID` controllato con `issecretvalue` prima del confronto |
| `SPELLS_CHANGED`, `PLAYER_SPECIALIZATION_CHANGED`, `ACTIONBAR_SLOT_CHANGED` | icone, riempimento automatico | non verificato | registrazione in `pcall` (nome evento sconosciuto non blocca il caricamento) |
| `JustAC-BlizzardAPI.GetRotationSpells()` | pool per il riempimento automatico | indiretto | funzione pubblica della libreria JustAC (minor 36); su Forever restituisce `ForeverPool` (barre + lista Forever conosciuta); voci segrete → nessuna modifica |
| `JustAC-SpellDB.GetGapCloserDefaults()`, `JustAC-BlizzardAPI.ResolveKnownSpellID()` | gap closer per il riempimento automatico | indiretto | funzioni pubbliche delle librerie JustAC; errori o valori segreti → lista ignorata, il pool resta valido |
| Frame della barra in basso di Blizzard (`ActionButton1..12`, `MainMenuBarArtFrame`, micro-menu, borse; `StanceBar*`, `MainMenuExpBar`/`StatusTrackingBarManager` mantenuti) | opzione "nascondi barra Blizzard" | **verificato** (2026-10-15, proprietario: barra principale, micro-menu e borse nascosti; posture ed esperienza visibili) | layout moderno: `MainActionBar` con `MainActionBarButtonContainer1..12`, `StanceBar` e `StatusTrackingBarManager` figli di `UIParent`; nomi candidati classici e moderni, solo quelli esistenti vengono toccati; `SetAlpha`/`EnableMouse` solo fuori combattimento; `/fob probe frames` registra quali esistono |
| `SavedVariablesPerCharacter` | celle per personaggio | verificato (2026-10-15) | il primo test in gioco ha riempito e conservato le celle |
| `UNIT_SPELLCAST_SUCCEEDED` in combattimento | fronte ACK | **verificato** (2026-10-15, log diagnostico) | 18 eventi, nessuno `spellID` segreto; 9 lanci della spell codificata, 8 fronti chiusi + 1 riavviato |
| `GetCursorInfo`, `ClearCursor` | drag & drop | non verificato | firma moderna `("spell", index, book, spellID)`; valori controllati |
| `GameTooltip`, `UISpecialFrames`, `SlashCmdList` | UI | verificato (ChatGuard per `UISpecialFrames` e slash) | — |
| `C_Timer.After`, `GetTime` | ACK | verificato (ChatGuard) | — |

## Secret values: politica

1. Ogni valore proveniente dal client o da JustAC passa da `ns.IsSecret`
   (`issecretvalue`) prima di confronti, aritmetica, uso come chiave o
   `tostring`; i risultati di API passano da `ns.SafeCall` (pcall + scarto dei
   valori segreti).
2. Un valore segreto non viene mai "declassificato": diventa *sconosciuto*.
   Sconosciuto non crea mai una raccomandazione: per la posizione 1 → nero;
   per la portata → nessuna soppressione; per un cast → cast in corso.
3. Nessun valore segreto viene stampato o salvato.

I test simulano i valori segreti con userdata che falliscono su confronto,
aritmetica, concatenazione e `tostring`: provano che il codice non li tocca
nei percorsi simulati, **non** che i veri valori Forever si comportino così.

## Frame protetti e taint

- Pulsanti secure creati al caricamento senza attributi; configurazione solo
  fuori combattimento (anche `RegisterForClicks`), differita dopo un reload in
  combattimento. Il mock fallisce su qualsiasi operazione protetta in combattimento.
- Nessuna operazione protetta nel percorso di refresh (50 ms): solo texture e testi.
- Taint: non verificabile offline. **Pendente** in gioco (`/console taintLog 1`).

## Verifiche runtime pendenti

Elenco completo e procedura: `docs/RUNTIME_CHECKLIST.md`.
