# Checklist delle verifiche in gioco (pendenti)

Da eseguire sul client Forever (`_classic_beta_`, annotare `GetBuildInfo()`).
Dalla 1.0.0 JustAC non serve: disattivarlo durante le prove, così i
suggerimenti visibili sono solo quelli del motore interno. Il primo test del
2026-10-15 (0.2.0, con JustAC) ha coperto solo parte di B e D
(`TEST_REPORT.md`); con il motore interno nessuna di queste prove è stata
eseguita. Annotare per ognuna: data, build, personaggio (classe/livello),
esito, screenshot o log. Non stampare valori segreti.

Preparazione: copiare `dist/ForeverOneButton-<versione>.zip` in `AddOns`,
`/console taintLog 1`, `/reload`.

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

Esito al 2026-10-16 (Guerriero Fury livello 13, `TEST_REPORT.md`): 24, 25, 27,
32 (cibo), 33 verificati; 26 (Carica) visto nei lanci, non come suggerimento
in posizione 1; 28, 29, 30 non verificati (nessun incantatore, Death Wish non
appresa, nessuna pozione); 31 parzialmente (cella svuotata senza pozioni).

Esito al 2026-10-19: 34 e 35 verificati in gioco dal proprietario sulla build 1.1.0 ("funziona").

Esito al 2026-10-20: 36 verificato in gioco dal proprietario sulla build 1.1.1 ("funziona").
