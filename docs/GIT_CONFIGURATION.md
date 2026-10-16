# Configurazione Git e GitHub

Riferimento: `C:\Work\hc-one-button` (`DoctorB/hc-one-button`, `main` @
`e973acb`). Destinazione: `C:\Work\forever-one-button`
(`DoctorB/forever-one-button`). Audit del 2026-10-15 con `git config
--show-scope --show-origin`, ispezione dei file versionati e API GitHub
(`gh`, account `DoctorB`, scope `repo`, `workflow`, `read:org`, `gist`).
Nessun token, credenziale o URL con segreti è stato stampato o copiato.

Esito: **applicato / già equivalente / non pertinente / bloccato** per ogni voce.

## 1. Checkout e origine

| Voce | Stato |
|---|---|
| Workspace | esisteva, non vuoto (`docs/` con la specifica), **non** era un repository Git. Non clonato sopra: `git init -b main` nella cartella, file esistenti preservati |
| Remoto | `origin` = `https://github.com/DoctorB/forever-one-button.git` (fetch e push). Il remote di HCOB e la sua `.git` non sono stati copiati |
| Repository remoto | esisteva, pubblico e **vuoto** (`isEmpty: true`) |
| Branch | `main` creato con il commit iniziale `0eb4942` e pubblicato; lavoro su `feat/forever-one-button` con tracking `origin/feat/forever-one-button`; la 0.2.0 è su `main` (`1e20891`); il motore interno (1.0.0) è su `feat/internal-engine` con tracking `origin/feat/internal-engine` |

## 2. Matrice delle impostazioni

| Impostazione | HCOneButton (valore, scope/evidenza) | Destinazione | Adattamento e motivazione | Esito |
|---|---|---|---|---|
| `core.filemode` | `false` (local) | `false` (local) | — | già equivalente |
| `core.symlinks` | `false` (system + local) | `false` (local) | — | già equivalente |
| `core.ignorecase` | `true` (local) | `true` (local) | — | già equivalente |
| `core.autocrlf` | `true` (**system**, `C:/Program Files/Git/etc/gitconfig`) | ereditato, non modificato | la configurazione system non si tocca; `.gitattributes` rende il repository indipendente da essa | non pertinente (system) |
| `pull.rebase` | `false` (system) | ereditato | — | non pertinente (system) |
| `init.defaultBranch` | `master` (system); HCOB usa comunque `main` | `main` esplicito (`git init -b main`) | allineato al branch effettivo di HCOB | applicato |
| `credential.helper` | `manager` (system) | ereditato | nessuna credenziale copiata | non pertinente |
| `user.name` / `user.email` | global (Luca Bottani) | ereditati dalla global | nessuna identità locale aggiunta | già equivalente |
| `core.editor` | global | ereditato | — | non pertinente |
| `push.*`, `merge.ff`, `pull.ff`, `fetch.prune`, `rebase.*` | non impostati | non impostati | — | già equivalente |
| Firma commit/tag (`commit.gpgsign`, `tag.gpgsign`, `gpg.format`) | non impostata; commit non firmati (`%G?` = `N`) | non impostata | nessuna chiave disponibile/necessaria | già equivalente |
| Tracking | `main` → `origin/main` | `main` → `origin/main`; `feat/forever-one-button` → origin | — | applicato |
| Hook | nessuno (`.git/hooks` solo `*.sample`), nessun `core.hooksPath` | nessuno | i controlli girano in CI e con `tests/run.ps1` | già equivalente |
| LFS / submodule | nessuno (`git lfs ls-files` vuoto, nessun `.gitmodules`) | nessuno | — | già equivalente |
| `.gitignore` | `.planning/`, `.prompt/`, `release/`, `__pycache__/`, `*.py[cod]` | `dist/`, `__pycache__/`, `*.py[cod]`, `.planning/`, `.prompt/` | `release/` di HCOB contiene pacchetti locali; qui l'output è `dist/` | applicato (adattato) |
| `.gitattributes` | assente; indice tutto LF (149 file), working tree misto per `autocrlf` system | `* text=auto eol=lf`, binari per png/jpg/zip | rende esplicito lo stato LF già presente nell'indice HCOB, senza dipendere dalla config system; verificato: 37/37 file `i/lf w/lf` | applicato (differenza motivata) |
| `.editorconfig`, `CODEOWNERS`, template issue/PR, `CONTRIBUTING` | assenti | assenti | — | già equivalente |
| Convenzione commit | Conventional Commits (`feat`, `fix`, `docs`, `chore`, `test` con scope) | stessa convenzione | — | applicato |
| Flusso | push diretto su `main`, nessun merge commit, nessuna PR; tag `v<versione>` sulle release | `main` iniziale, poi branch `feat/…` + PR verso `main` | la specifica (§4.6.6, Fase 6) chiede push dei branch di lavoro e PR; merge e tag/release richiedono autorizzazione | applicato (adattato) |
| Versionamento | `## Version` nel TOC, `CHANGELOG.md`, tag `vX.Y.Z` | `## Version: 1.0.0` nel TOC (= `ns.VERSION`, controllato da `tests/test_toc.lua`), `CHANGELOG.md`; **nessun tag** | tag e release non autorizzati in questo incarico | applicato senza tag |
| Changelog/release notes | `CHANGELOG.md`, `docs/releases/<ver>.md`, `docs/RELEASING.md` | `CHANGELOG.md`, `docs/RELEASING.md` | sezione del CHANGELOG = note pubbliche | applicato |
| Packaging | `scripts/curseforge_release.py prepare` (zip in `release/ci/`) | `scripts/package.py build` (zip in `dist/`, verificato, riproducibile) | nuovo nome/percorso, nessun upload | applicato (adattato) |
| Workflow CI | `curseforge-release.yml`: su `release` e `workflow_dispatch`, `permissions: contents: read`, allowlist attori, action pinnate (checkout `3d3c42e5…` v7.0.1, upload-artifact `043fb46d…` v7.0.1), Lua 5.1 via apt, `tests/run.ps1`, upload CurseForge con `CF_API_TOKEN` | `ci.yml`: su push (`main`, `feat/**`, `fix/**`), PR e dispatch; stesse action pinnate, `contents: read`, Lua 5.1, `tests/run.ps1`, build+verifica pacchetto, artifact | nessun upload, nessun secret, quindi nessuna allowlist necessaria; trigger su push/PR per avere controlli prima del merge | applicato (adattato) |

## 3. Impostazioni GitHub

| Impostazione | HCOneButton | Destinazione prima | Destinazione dopo | Esito |
|---|---|---|---|---|
| Visibilità | public | public | public | già equivalente |
| Branch predefinito | `main` | (vuoto) | `main` | applicato (dal primo push) |
| Protezione branch / rulesets | nessuna (404, `[]`) | nessuna | nessuna | già equivalente; nessun controllo obbligatorio configurato per non introdurre regole assenti in HCOB. Possibile in futuro: richiedere `CI / test` su `main` |
| Merge consentiti | merge, squash, rebase | idem | idem | già equivalente |
| `delete_branch_on_merge`, `allow_auto_merge`, `allow_update_branch` | false | false | false | già equivalente |
| Titoli merge/squash | `MERGE_MESSAGE` / `COMMIT_OR_PR_TITLE` | idem | idem | già equivalente |
| Issues / wiki / projects / discussions | sì / sì / sì / no | idem | idem | già equivalente |
| Actions abilitate, azioni consentite | `all`, SHA pinning non obbligatorio | idem | idem | già equivalente |
| Permessi `GITHUB_TOKEN` di default | `read`, approvazione PR no | idem | idem | già equivalente |
| Ambienti | nessuno | nessuno | nessuno | già equivalente |
| Secret Actions | `CF_API_TOKEN` (solo nome letto) | `CF_API_TOKEN` (secret) e `CF_PROJECT_ID` (variable), da impostare dal proprietario | usati solo da `release.yml` e `curseforge-catalog.yml` | da impostare (`docs/RELEASING.md`) |
| Variabili Actions | nessuna | nessuna | nessuna | già equivalente |
| Secret scanning + push protection | abilitati | abilitati | abilitati | già equivalente |
| Dependabot / vulnerability alerts | disabilitati | disabilitati | disabilitati | già equivalente |
| Descrizione | presente | vuota | "WoW Forever Action Panel grid that shows JustAC suggestions…" | applicato; al 2026-10-16 non più attuale (JustAC non è usato dalla 1.0.0): da aggiornare, non modificata |
| Licenza rilevata | MIT | nessuna (repo vuoto) | MIT (da `main`, 2026-10-16) | su `feat/internal-engine` `LICENSE` è GPL-3.0-or-later: GitHub la rileverà dopo il merge in `main` |
| Collaboratori diretti | `DoctorB` (admin), `DrCalibano` (write) | `DoctorB` | `DoctorB` | **non applicato**: nessun accesso concesso automaticamente (specifica §4.6.4). Se desiderato, il proprietario può invitare `DrCalibano` |
| Pages, autolink | assenti | assenti | assenti | già equivalente |

## 4. Verifiche dopo l'applicazione

| Verifica | Comando | Esito |
|---|---|---|
| fetch/push su DoctorB/forever-one-button | `git remote -v` | OK |
| tracking | `git branch -vv` | `main` → `origin/main`, `feat/forever-one-button` → `origin/feat/forever-one-button` |
| fine riga | `git ls-files --eol` | 37/37 `i/lf w/lf` |
| ignore | `git status --short --ignored` | solo `dist/` ignorato |
| hook | `ls .git/hooks` | solo esempi |
| CI remota | `gh run list` | run `38696430512` su `feat/forever-one-button`: **success** (tutti gli step) |
| HCOneButton invariato | `git -C ../hc-one-button rev-parse HEAD`, `status` | HEAD `e973acb`; unico file non tracciato preesistente `docs/FOREVER_FEASIBILITY.md` intatto; vedi §5 |
| Config global/system invariata | `stat` di `~/.gitconfig` e `etc/gitconfig` | ultima modifica 2026-10-06, nessun comando di scrittura eseguito |
| Branch del motore (2026-10-16) | `git branch -vv` | `feat/internal-engine` → `origin/feat/internal-engine` (`37e2656`), `main` → `origin/main` (`1e20891`) |
| Fine riga (2026-10-16) | `git ls-files --eol` | 83 file `i/lf w/lf`, 2 binari (`-text`) |
| CI remota (2026-10-16) | `gh run list --branch feat/internal-engine` | run `38873883869` su `37e2656`: **success** |

## 5. Anomalia e azione residua su HCOneButton

Durante l'audit, il comando di sola lettura `git lfs ls-files` ha **scritto**
nella config locale di HCOneButton la voce `lfs.repositoryformatversion = 0`
(comportamento di git-lfs al primo uso; assente nell'elenco letto subito
prima). Il ripristino non è stato eseguito. Effetto pratico nullo (è il valore di default di LFS), ma lo stato
non è identico all'originale. Per ripristinarlo:

```text
git -C C:\Work\hc-one-button config --local --unset lfs.repositoryformatversion
git -C C:\Work\hc-one-button config --local --remove-section lfs
```

Nello stesso intervallo `FETCH_HEAD` e `objects/pack` di HCOneButton sono stati
aggiornati da un processo esterno (fetch/manutenzione automatica); ref e `HEAD` sono invariati.

## 6. Prerequisiti mancanti / azioni residue

- Merge della PR verso `main`: richiede autorizzazione del proprietario.
- Merge di `feat/internal-engine` (1.0.0): richiede autorizzazione del proprietario.
- Tag `v1.0.0` e release: non autorizzati; da fare dopo le verifiche in gioco.
- Descrizione del repository GitHub: ancora riferita a JustAC; da aggiornare.
- Pubblicazione CurseForge: workflow `release.yml` (tag `v*`, come Forever
  ChatGuard) pronto; servono il progetto CurseForge, il secret `CF_API_TOKEN`
  e la variable `CF_PROJECT_ID` (`docs/RELEASING.md`).
- Controllo obbligatorio su `main` (`CI / test`): opzionale, assente in HCOB.
