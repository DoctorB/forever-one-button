# Checklist delle verifiche in gioco (pendenti)

Da eseguire sul client Forever (`_classic_beta_`, annotare `GetBuildInfo()`)
con JustAC installato. Nessuna di queste prove è stata eseguita. Annotare per
ognuna: data, build, personaggio (classe/livello), esito, screenshot o log.
Non stampare valori segreti.

Preparazione: copiare `dist/ForeverOneButton-<versione>.zip` in `AddOns`,
`/console taintLog 1`, `/reload`.

## A. Caricamento e stati

1. L'addon compare nella lista AddOns come *Forever One Button* senza "out of date".
2. Senza JustAC: griglia visibile, stato "JustAC not loaded", pixel nero.
3. Con JustAC: `/fob status` riporta `ok` e `SpellQueue minor 43`.
4. Nessun errore Lua (`/console scriptErrors 1`) al login e dopo `/reload`.

## B. Celle e binding

5. Al login le celle si riempiono da sole con le spell di JustAC (`/fob status`: `autofill: on, ok`); tasti `SHIFT-1…` visibili sulle celle. Imparare una spell o un rango nuovo (o mettere una spell in barra): compare nella prima cella libera / nella stessa cella, nessuna altra cella si sposta. Dopo `/reload` e su un altro personaggio: celle proprie.
5b. Trascinare una spell dal libro su una cella: icona visibile, `/fob bindings` la elenca.
6. Bind di un tasto dalla finestra opzioni; premere il tasto fuori combattimento: la spell viene lanciata **una volta** (provare con `ActionButtonUseKeyDown` 0 e 1).
7. Click sinistro sulla cella: lancia; click destro: nessun effetto.
8. Tasto già legato a un'azione WoW: compare `!`; togliendo il tasto l'azione WoW torna attiva.
9. In combattimento: il tasto funziona; `/fob assign`, `/fob bind`, opzioni → rifiutati senza errori `ADDON_ACTION_BLOCKED`.
10. `/reload` in combattimento: nessun errore; dopo il combattimento i tasti funzionano.

## C. JustAC e griglia

11. In combattimento contro un mob: la cella con l'azione in posizione 1 di JustAC ha bordo oro e "1"; la striscia segue l'ordine dell'icona principale di JustAC.
12. Azione suggerita non presente nella griglia: "--" e messaggio; nessuna cella oro.
13. Cambio specializzazione/talenti: icone aggiornate, nessun errore.

## D. Pixel

14. Ingrandire uno screenshot: quadrato 8×8 (× UI scale) nella posizione scelta, colore pieno.
15. Confrontare il colore con la tabella del README (es. cella 3 → `#2460E0`) con uno strumento di campionamento; nero senza suggerimento, bianco con suggerimento non associato.
15b. Fuori combattimento il quadrato è nero anche con un suggerimento visibile nella griglia; al primo colpo/aggro diventa il colore della cella; a fine combattimento torna nero subito.
16a. Log: `/fob log on`, combattimento premendo più volte la stessa spell suggerita (istantanea e con tempo di lancio), `/fob log show`, poi `/reload` e `python scripts/analyze_log.py`. Atteso: un fronte per ogni lancio riuscito, nessuno sotto 60 ms, `secret spell ID: 0`; se gli ID sono segreti non ci sono fronti (limite da segnalare). `/fob log off` alla fine.
16. Dopo aver lanciato l'azione codificata: breve nero (≥ 60 ms) visibile in una registrazione a ≥ 50 fps.
17. Spostare, scalare, nascondere la griglia: il quadrato non cambia; mettere la griglia sopra il quadrato: compare "grid covers the pixel!".
18. Cambiare UI scale del client: annotare la dimensione in pixel fisici (comportamento identico a HCOB).

## E. Secret values, taint, prestazioni

20. In combattimento e in istanza: nessun errore "secret value" nei log.
21. `Logs\taint.log`: nessuna voce che citi ForeverOneButton.
22. `/fstack` sul quadrato: nessun frame della griglia sopra di esso.
23. Prestazioni: con il profiler di addon del client annotare il costo medio di ForeverOneButton in combattimento.
