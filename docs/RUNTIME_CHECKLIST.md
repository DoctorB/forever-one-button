# Checklist delle verifiche in gioco (pendenti)

Da eseguire sul client Forever ufficiale (`_forever_`, annotare `GetBuildInfo()`;
le prove fino al 2026-10-22 sono sul beta `_classic_beta_`).
Dalla 1.0.0 JustAC non serve: disattivarlo durante le prove, così i
suggerimenti visibili sono solo quelli del motore interno. Il primo test del
2026-10-15 (0.2.0, con JustAC) ha coperto solo parte di B e D
(`TEST_REPORT.md`); con il motore interno nessuna di queste prove è stata
eseguita. Annotare per ognuna: data, build, personaggio (classe/livello),
esito, screenshot o log. Non stampare valori segreti.

Preparazione: copiare `dist/ForeverOneButton-<versione>.zip` in `AddOns`,
`/console taintLog 1`, `/reload`. Sul client ufficiale `taintLog` e
`scriptErrors` non restano salvati: ridarli a ogni sessione e controllarli con
`/run print(GetCVar("taintLog"), GetCVar("scriptErrors"))`.

## A. Caricamento e stati

1. L'addon compare nella lista AddOns come *Forever One Button* senza "out of date".
2. `/fob status`: `suggestions: ok`, con albero e contesto (es. `tree arms, context st`); su una classe senza lista: `missing (no priority list for this class)`, pixel nero.
3. Nessun errore Lua (`/console scriptErrors 1`) al login e dopo `/reload`.

## B. Celle e binding

5. Al login le celle si riempiono da sole con le spell del motore (`/fob status`: `autofill: on, ok`); tasti `SHIFT-1…` visibili sulle celle. Imparare una spell o un rango nuovo (o mettere una spell in barra): compare nella prima cella libera / nella stessa cella, nessuna altra cella si sposta. Dopo `/reload` e su un altro personaggio: celle proprie.
5b. Trascinare una spell dal libro su una cella: icona visibile, `/fob bindings` la elenca.
6. Bind di un tasto dalla finestra opzioni; premere il tasto fuori combattimento: la spell viene lanciata **una volta** (provare con `ActionButtonUseKeyDown` 0 e 1).
7. Click sinistro sulla cella: lancia; click destro: nessun effetto.
8. Tasto già legato a un'azione WoW: compare `!`; togliendo il tasto l'azione WoW torna attiva.
9. In combattimento: il tasto funziona; `/fob assign`, `/fob bind`, opzioni → rifiutati senza errori `ADDON_ACTION_BLOCKED`.
10. `/reload` in combattimento: nessun errore; dopo il combattimento i tasti funzionano e la riga promemoria compare.

## C. Motore e griglia

11. In combattimento contro un mob: la cella con l'azione in posizione 1 ha bordo oro e "1"; la striscia mostra albero, contesto e coda; le voci non pronte sono attenuate.
12. Azione suggerita non presente nella griglia: "--" e messaggio; nessuna cella oro.
13. Cambio talenti (più punti in un altro albero): `/fob status` mostra il nuovo albero; icone aggiornate, nessun errore.

## D. Pixel

14. Ingrandire uno screenshot: quadrato 8×8 (× UI scale) nella posizione scelta, colore pieno.
15. Confrontare il colore del quadrato nello screenshot con la tabella del README (es. cella 3 → `#2460E0`); nero senza suggerimento o con wait, bianco con suggerimento non associato.
15b. Fuori combattimento il quadrato è nero anche con un suggerimento visibile nella griglia; al primo colpo/aggro diventa il colore della cella; a fine combattimento torna nero subito.
15c. Con l'icona di interruzione, la colonna difensiva o il bordo viola visibili il quadrato segue solo la posizione 1 della coda.
16a. Log: `/fob log on`, combattimento premendo più volte la stessa spell suggerita (istantanea e con tempo di lancio), `/fob log show`, poi `/reload` e `python scripts/analyze_log.py`. Atteso: un fronte per ogni lancio riuscito, nessuno sotto 60 ms, `secret spell ID: 0`; se gli ID sono segreti non ci sono fronti (limite da segnalare). `/fob log off` alla fine.
16b. Con il pixel reader avviato con `--diag-log` durante la prova 16a: nel suo log ogni riga `ack` di un lancio riuscito ha `blackMs` ≥ 60 (a meno di un campione) e `accepted: true`. Prima della 1.1.3 il log del 2026-10-21 (build 70450) mostrava neri di 43–58 ms (orologio del nero sull'inizio del frame).
16. Dopo aver lanciato l'azione codificata: breve nero (≥ 60 ms) visibile in una registrazione a ≥ 50 fps.
17. Spostare, scalare, nascondere la griglia: il quadrato non cambia; mettere la griglia sopra il quadrato: compare "grid covers the pixel!".
18. Cambiare UI scale del client: annotare la dimensione in pixel fisici (comportamento identico a HCOB).

## E. Secret values, taint, prestazioni

20. In combattimento e in istanza: nessun errore "secret value" nei log.
21. `Logs\taint.log`: nessuna voce che citi ForeverOneButton.
22. `/fstack` sul quadrato: nessun frame della griglia sopra di esso.
23. Prestazioni: con il profiler di addon del client annotare il costo medio di ForeverOneButton in combattimento.

## F. Motore interno (Guerriero, 1.0.0)

24. `/fob status` riporta albero e contesto corretti: albero con più punti (senza punti: default della classe); `context st` con un nemico, `cleave` con due, `aoe` con tre o più (nameplate attive).
25. Nessun ciclo di posture: Arms in Postura da battaglia non vede mai Postura difensiva in coda; Protection vede Postura difensiva solo finché non è attiva; nessuna alternanza nel log (`head`).
26. Carica fuori dalla mischia: con un bersaglio ostile oltre 8 m la Carica è in posizione 1; non viene riproposta nei 3 s dopo il lancio; in mischia non compare.
27. Senza nulla di pronto (rabbia esaurita) in combattimento: striscia "wait", pixel nero.
28. Il bersaglio lancia un incantesimo: icona di Pummel o Shield Bash a sinistra della griglia con il cast nell'angolo e il tasto; bordo rosso e "!" sulla cella; icona nascosta a fine cast; nessun cambiamento del pixel.
29. Burst: con Death Wish pronta in combattimento (Arms), la sua cella è in posizione 2 con bordo viola; non su un mob singolo non boss sotto il 20 %; `/fob feature burstCue off` lo disattiva.
30. Colonna difensiva: sotto il 50 % di salute in combattimento compaiono i difensivi (es. Last Stand, Shield Wall) a destra della griglia, bordo arancione e "D" sulla cella della prima voce pronta; sopra l'80 % fuori combattimento la colonna è nascosta.
31. Oggetto di cura: con una pozione di cura nelle borse una cella automatica la contiene; con una pozione migliore la cella cambia oggetto; dopo l'uso in combattimento la voce resta "in cooldown" fino alla fine del combattimento e la cella è desaturata con lo swipe dei due minuti.
32. Riga promemoria: fuori combattimento, con un elisir di forza o una pietra per armi nelle borse e nessun effetto di quella categoria attivo, compare sotto la striscia (il Guerriero non ha buff di classe nei dati); il clic lancia la spell o usa l'oggetto; nessun tasto la attiva; all'ingaggio la riga sparisce e riappare dopo il combattimento; nessun errore `ADDON_ACTION_BLOCKED`.
33. Dopo un combattimento con salute sotto il 70 %: la riga propone cibo (o una benda se non c'è cibo e non si è "Recently Bandaged"); mentre si mangia non viene riproposto.
34. Cooldown sulle celle (2026-10-19): dopo Bloodrage (o un'altra abilità con cooldown) la cella diventa subito desaturata con lo swipe e il suo numero di coda passa in grigio senza bordo; resta così fino alla fine del cooldown anche in combattimento; il GCD non desatura le altre celle. Senza rabbia sufficiente l'icona è blu, in postura sbagliata o con Execute non disponibile grigia. Dopo una pozione la cella oggetto è desaturata, con il numero di pezzi aggiornato.
35. Suggerimento evidente: la cella in posizione 1 ha bordo oro, "1" grande e glow pulsante; la prima icona della striscia è più grande e incorniciata; con "wait" nessun glow.
36. Bersagli immuni (2026-10-20): con il Paladino, Esorcismo non è mai proposto su bestie o umanoidi (cella grigia) ed è proposto su non morti e demoni; una spell rifiutata dal client con "Invalid target" non viene più proposta su quel tipo di creatura fino al /reload (riga `refused` nel log diagnostico).
38. Hamstring su un bersaglio in fuga (branch `feat/hamstring-fleeing`, 2026-11-06): con un Guerriero Arms o Fury sotto il 60, Hamstring ha una cella (verificato il 2026-11-06); quando un umanoide scappa ("%s attempts to run away in fear!" in chat) Hamstring è in posizione 1 per quel bersaglio, una volta per fuga, e sparisce dopo il lancio. Annotare la lingua del messaggio in chat (con un client non inglese conta qualsiasi emote del bersaglio sotto il 35 % di salute). Pendente: a livello 8 i mob morivano prima di scappare.
37. Icona (2026-10-21): dopo un riavvio completo del client, nella lista AddOns della selezione personaggio "Forever One Button" mostra l'infinito dorato su fondo blu (`## IconTexture`, `Media/icon.tga`) invece del punto di domanda.
39. Cura di emergenza in movimento (branch `fix/emergency-heal-moving`, 2026-11-10, dalle share dell'8/11): Paladino sotto la soglia di salute in combattimento, con Holy Light su una cella. Correndo, Holy Light non va in posizione 1 (al suo posto la pozione se ha una cella, altrimenti la rotazione); fermandosi torna subito in posizione 1. Nel log diagnostico: righe `moving|1` / `moving|0` e nessun "Can't do that while moving" per Holy Light. Se `GetUnitSpeed` o il tempo di lancio non sono leggibili su Forever, il comportamento resta quello di prima (Holy Light anche correndo): annotarlo.

Esito al 2026-10-16 (Guerriero Fury livello 13, `TEST_REPORT.md`): 24, 25, 27,
32 (cibo), 33 verificati; 26 (Carica) visto nei lanci, non come suggerimento
in posizione 1; 28, 29, 30 non verificati (nessun incantatore, Death Wish non
appresa, nessuna pozione); 31 parzialmente (cella svuotata senza pozioni).

Esito al 2026-10-19: 34 e 35 verificati in gioco dal proprietario sulla build 1.1.0 ("funziona").

Esito al 2026-10-20: 36 verificato in gioco dal proprietario sulla build 1.1.1 ("funziona").

Esito al 2026-10-21: 37 verificato in gioco dal proprietario sulla build dell'icona, pubblicata come 1.1.2 ("funziona").

Esito al 2026-11-06, client ufficiale 1.60.1.70790, 1.1.5, Guerriero Arms
livello 7 (contesto `arms+leveling`, `st`), pixel reader senza `--diag-log`,
log dell'addon (`scripts/analyze_log.py`), 11 combattimenti, 63 lanci:
- 3: nessun errore Lua (proprietario, `scriptErrors 1`).
- 16a: 36 lanci suggeriti (Heroic Strike 15, Rend 14, Thunder Clap 5,
  Battle Shout 2), nessuna cella visibile meno di 50 ms, nessuno stato del
  pixel sotto 20 ms; ID segreti 0. Nessun fronte dopo il lancio, come atteso
  dalla 1.1.5: la spell premuta è in attesa (`C_Spell.IsCurrentSpell`) e
  lascia il pixel prima del lancio. Le istantanee partono 25–150 ms dopo che
  il pixel le lascia (3 su 21 a 460–500 ms); Heroic Strike al colpo
  successivo (0,5–2,5 s). Lo script ora dà il verdetto su questo schema.
- 20: nessun ID segreto nei lanci (solo mondo aperto, non istanza).
- 21: verificata in mondo aperto. Con `GetCVar("taintLog")` e
  `GetCVar("scriptErrors")` a `1` (controllati in gioco), 27 combattimenti e
  138 lanci, poi `/reload` alle 21:44: `Logs\taint.log` non esiste, quindi
  nessuna contaminazione registrata. Nota: Forever non salva queste due
  impostazioni in `Config.wtf`; vanno date a ogni sessione.
- 16b: non eseguita (reader senza `--diag-log`; il proprietario lo
  considera a posto).
- Rabbia al massimo con Heroic Strike grigio (segnalazione 1.1.5): non
  vista dal proprietario; il log non registra la rabbia.

Esito al 2026-11-07, client ufficiale 1.60.1.70862, 1.1.5 (ramo Hamstring),
Ladro livelli 1-10 (contesto `combat+leveling`, `st`), log dell'addon: il
buffer da 5000 righe teneva solo gli ultimi 76 minuti (dal livello 8 circa),
68 combattimenti, 480 lanci:
- 16a: 327 lanci suggeriti (Sinister Strike 279, Eviscerate 48), dal pixel
  al lancio mediana 96-115 ms, massimo 685 ms; ID segreti 0; verdetto OK.
- Eviscerate a 5 punti combo o con 2+ sotto il 20% di salute del bersaglio,
  come da lista; Minor Healing Potion suggerita 5 volte, bevuta 4.
- Slice and Dice (livello 10) mai suggerito né lanciato: da verificare.
  Verificato il 2026-11-08 (1.1.6, Ladro, 117 combattimenti): suggerito con
  1+ punti combo e buff assente, lanciato 107 volte.
- 2026-11-08: Slice and Dice compare durante il GCD subito dopo Sinister
  Strike e il lettore pixel lo preme ogni 20 ms (151 raffiche, 3081
  "Ability is not ready yet"); a fine GCD il pixel alterna Sinister Strike,
  Slice and Dice e nero ogni 50-100 ms e in 61 raffiche su 151 parte
  Sinister Strike. Causa da leggere nel log: dopo la 1.1.6 ogni riga `queue`
  dice perché ogni voce aspetta (`5171-res`, `1757-cd`...), riassunto da
  `scripts/analyze_log.py` ("readiness per spell").
  Causa trovata il 2026-11-08 (log inviato con /fob share, Ladro 13): la
  spell premuta durante il GCD resta "current" (in coda nel client), FOB
  la saltava e suggeriva la successiva (`5171-cur` -> head 1757), il
  lettore la premeva e il client la metteva al posto di Slice and Dice.
  Corretto: una spell in coda trattiene quelle sotto (`held`) per al
  massimo 1,5 s. Verificato in gioco il 2026-11-08: Slice and Dice
  lanciato 14 volte su 14 suggerimenti, nessun "Another action is in
  progress" e nessun Sinister Strike al posto di Slice and Dice.
- 5 momenti in cui Sinister Strike compare e sparisce ogni 50-150 ms per
  0,5-2,4 s prima di partire (pressione rifiutata dal gioco, motivo non
  registrato): dalla 1.1.6 il log registra `error` e `failed`.
- Hamstring sul bersaglio in fuga (Guerriero): pubblicato in 1.1.6 senza
  aver ancora visto un mob in fuga in gioco.

Condivisione del log (`/fob share`, branch feat/share-log), 2026-11-08,
client 1.60.1.70862, Ladro 13 in locanda:
- Finestra: riga compressa con `C_EncodingUtil` (19.873 righe, 143 KB),
  incollata su trace.lucabottani.dev e ricevuta intera (analisi identica
  a quella del file).
- Promemoria in chat al rientro in locanda con il link [Share the log]; il
  link apre la finestra; "I sent it" ha tolto 19.887 righe e il log salvato
  è vuoto, `remindedAt` scritto.
- Correzione della spell in coda (`held`) verificata il 2026-11-08 (log
  condiviso, Ladro 13, 13 combattimenti): Slice and Dice parte in 14
  raffiche su 14 (prima 86 su 151, 61 volte Sinister Strike al suo posto),
  "Another action is in progress" 0 (prima 254). Restano gli "Ability is
  not ready yet": pressioni del lettore pixel durante il GCD, non di FOB.
