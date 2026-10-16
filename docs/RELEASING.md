# Rilascio: GitHub → CurseForge

Un solo meccanismo di upload: il workflow `.github/workflows/release.yml`,
avviato dal push di un tag `v*`. Non attivare il webhook di packaging di
CurseForge e non aggiungere `.pkgmeta`: due meccanismi sullo stesso tag
potrebbero caricare file diversi. Stesso schema di Forever ChatGuard: script
Python con la sola libreria standard (`scripts/release.py`, che riusa lo ZIP
riproducibile di `scripts/package.py`), pacchetto verificabile byte per byte
(SHA-256 nel `manifest.json`).

## Prerequisiti (una tantum)

1. **Progetto CurseForge** creato con i dati di `docs/CURSEFORGE_LISTING.md`
   (World of Warcraft → Addons, licenza GPLv3). Annotare l'**ID del progetto**
   (numero nella pagina del progetto, "Project ID").
2. Repository `DoctorB/forever-one-button`, **Settings → Secrets and variables → Actions**:
   - secret `CF_API_TOKEN`: token API di CurseForge dell'autore
     (curseforge.com → account → API Tokens; lo stesso usato per gli altri progetti va bene);
   - variable `CF_PROJECT_ID`: l'ID numerico del progetto appena creato
     (non quello di HC One Button o di Forever ChatGuard).
   Non incollare il token in chat, issue, file o log.
3. Facoltativo, consigliato prima del primo upload: **Actions → CurseForge catalog
   check → Run workflow**. Sola lettura: mostra la versione di gioco che l'upload
   userà. Il tipo di versione di WoW Forever è fissato nello script
   (`FOREVER_VERSION_TYPE = 88568`, unico tipo con `1.60.1`, id 17053, rilevato
   da Forever ChatGuard il 2026-10-14); dal TOC `16001` si ricava `1.60.1`. Lo
   script rifiuta di caricare se quel tipo non contiene **una sola** versione
   con quel nome: non ripiega mai su Classic, Hardcore o Retail.

## Pubblicare una versione

1. Prove in gioco sulla build da pubblicare (`docs/RUNTIME_CHECKLIST.md`).
2. Aggiornare insieme `## Version` nel TOC, `ns.VERSION` in `Core/Init.lua` e la
   sezione `## <versione>` di `CHANGELOG.md` (è il testo pubblico delle note).
   Versioni di prova con suffisso: `1.0.0-beta.1` → CurseForge **beta**,
   pre-release su GitHub; `1.0.0-alpha.1` → **alpha**; senza suffisso → **release**.
3. Commit, push su `main`, CI verde.
4. Tag annotato sul commit verificato e push del tag:
   `git tag -a v1.0.0-beta.1 -m "Forever One Button 1.0.0-beta.1"` →
   `git push origin v1.0.0-beta.1`.
5. Il workflow (solo per l'attore `DoctorB`): ripete tutti i test sul commit del
   tag → controllo di paternità dei commit → tag = TOC = runtime = changelog →
   costruisce e verifica lo ZIP → rifiuta upload doppi → crea la release GitHub
   con lo stesso ZIP → registra `curseforge-attempt.json` → carica su
   CurseForge → allega `curseforge-receipt.json`.

## Verifica remota

- Run del workflow verde; ZIP, note e manifest negli artifact.
- Release GitHub con ZIP e ricevuta; lo SHA-256 dello ZIP è nel `manifest.json`.
- Su CurseForge distinguere: **caricato** (ricevuta con file ID), **in revisione**
  (moderazione), **pubblicato e scaricabile**. Una ricevuta non significa
  disponibilità pubblica.

## Recupero da errore

- **Fallimento prima di "Record the upload attempt"**: correggere la causa e
  lanciare *Run workflow* con lo stesso `tag`. Nessun rischio di doppio upload.
- **Fallimento durante o dopo l'upload senza ricevuta** (timeout, risposta
  ambigua): un timeout non prova che l'upload sia fallito. Aprire la pagina Files
  del progetto CurseForge.
  - Se il file c'è: non rilanciare; annotare il file ID nella release GitHub.
  - Se non c'è: *Run workflow* con lo stesso `tag` e `confirm_curseforge_checked = true`.
- **Ricevuta presente**: quella versione è caricata; il workflow rifiuta ogni nuovo upload.
- **Contenuto sbagliato già pubblicato**: mai spostare o riusare un tag pubblicato;
  rilascio correttivo con una nuova versione (es. `v1.0.1`).
- Se la release GitHub esiste già con uno ZIP diverso, il workflow si ferma:
  nessuna sostituzione silenziosa.

## Cosa contiene lo ZIP

Solo la cartella `ForeverOneButton/` con TOC, i file elencati nel TOC,
`LICENSE`, `NOTICE.md` e `README.md` (`scripts/package.py`). Esclusi `.git`,
`.github`, test, documenti interni, script, dati locali, segreti e log.
Timestamp e ordine deterministici: input identici producono lo stesso SHA-256.
