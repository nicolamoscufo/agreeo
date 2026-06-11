# Piano di Pulizia Strutturale del Workspace — Agreeo

> Data analisi: 2026-06-11 · Branch: `main`
> Obiettivo: rimuovere file inutilizzati/generati, eliminare duplicati, riorganizzare la
> documentazione e portare la struttura del repo a uno stato pulito e manutenibile.
> Ogni fase è un commit separato, così ogni passo è verificabile e reversibile.

---

## Sintesi dei problemi rilevati

| # | Problema | Impatto |
|---|----------|---------|
| 1 | ~30 file già cancellati nel working tree ma **non ancora committati** (script di test usa-e-getta, report obsoleti) | Stato git confuso, rischio di ripristini accidentali |
| 2 | `backend/data/tag_embeddings_cache.json` (12,5 MB) + `tag_embeddings_multilingual_cache.json` (12,4 MB) **tracciati in git** | ~25 MB di cache rigenerabili nel repo |
| 3 | `.graphify/` (~120 file di cache AST, `graph.json` 1,6 MB) e parte di `.vexp/` **tracciati** nonostante siano nel `.gitignore` | Artefatti di tooling locale versionati; ogni run sporca `git status` |
| 4 | Duplicati identici: `agreeo_logo.png` (root = `docs/agreeo_logo.png`), `backend/scripts/import_movielens.cypher` (= copia in `backend/data/ml-latest-small/`) | Ridondanza, ambiguità su quale sia la fonte |
| 5 | `NEO4J_TMDB_MOVIELENS_ARCHITECTURE.md` esiste in root (vers. 11/05, **stantia**) e in `docs/` (vers. 22/05, referenziata dal README) | Doc divergente: la copia root è obsoleta |
| 6 | Doc sparsi in root: `AVVIO.md`, `design.md`, `.agent-socket-io.md`, `agreeo_neo4j_project_context.md`, `REMEDIATION_PLAN.md` | Root affollata; `docs/` è la home naturale |
| 7 | File spazzatura in `backend/`: `struttura_backend.txt` (394 KB, dump albero), `page1.json`, `page2.json`, `server.log` | Rumore tracciato in git |
| 8 | `package.json` + `package-lock.json` in **root** con sola dipendenza `graphifyy` (tool locale) | Fa sembrare il repo un progetto Node alla radice |
| 9 | `DM2526 Instructions on projects (1).pdf` (2,7 MB) tracciato in root | Binario pesante con nome non normalizzato |
| 10 | `.vscode/mcp.json.vexp-bak` (backup), `.vscode/UI_FONT.md` (doc fuori posto) | Residui di tooling |
| 11 | `design_reference/` (9 .jsx + 1 .html + `scraps/` con 56 PNG, 2,4 MB) **non tracciato** e senza policy | Materiale di riferimento Daylight a rischio perdita / oppure da ignorare |
| 12 | Dir vuota residua `lib/features/debug/` dopo la cancellazione della debug screen; naming stantio `lib/models/neo4j/` (Neo4j ora vive solo nel backend) | Struttura `lib/` non allineata alla realtà |
| 13 | File nuovi utili **non tracciati**: `.mcp.json`, `docs/BACKEND_CONTRACT.md`, `docs/PRODUCTION_READINESS_PLAN.md`, `docs/ROUTING_MAP.md`, 4 nuovi file Dart in `lib/` | Rischio perdita di lavoro |
| 14 | **Dipendenze pubspec morte**: `crypto` (0 usi, serviva al client Neo4j eliminato), `flutter_card_swiper` (0 usi, lo swipe è stato reimplementato custom), `cupertino_icons` (0 usi di `CupertinoIcons`) | Download e build inutili, pubspec che mente |
| 15 | Script backend one-off fuori posto: `backend/migrate_tags_to_vector.js` e `backend/seedInitialUsers.js` non sono richiamati da nessun modulo, npm script o Dockerfile | Sembrano parte del runtime ma sono tooling operativo |

---

## Fase 0 — Mettere in sicurezza il lavoro in corso

Prima di toccare qualsiasi cosa, consolidare lo stato attuale (le ~50 modifiche + ~30
cancellazioni già fatte appartengono alla migrazione Daylight, non a questa pulizia).

1. Aggiungere i file nuovi che fanno parte del lavoro in corso:
   - `lib/features/home/presentation/random_pick_sheet.dart`
   - `lib/features/movie_details/presentation/review_editor_sheet.dart`
   - `lib/features/profile/presentation/edit_profile_sheet.dart`
   - `lib/features/profile/presentation/settings_screen.dart`
   - `docs/BACKEND_CONTRACT.md`, `docs/PRODUCTION_READINESS_PLAN.md`, `docs/ROUTING_MAP.md`
   - `.mcp.json` (config MCP di progetto: va versionata)
2. Committare **tutte** le modifiche e cancellazioni pendenti come commit della migrazione
   (es. `feat: Daylight UI migration + rimozione script di test legacy`).
3. Verifica gate: `flutter analyze` e `flutter test` devono passare prima del commit.

> Da qui in poi il working tree è pulito: ogni fase successiva = 1 commit atomico.

---

## Fase 1 — Untracking degli artefatti generati (il guadagno più grosso)

File **rigenerabili** che restano su disco ma escono dal versionamento
(`git rm -r --cached`, sono già coperti o vanno aggiunti al `.gitignore`):

| Path | Dimensione | Note |
|------|-----------|------|
| `.graphify/` (tutto) | ~5 MB+ | Già nel `.gitignore`; tracciato perché aggiunto prima della regola |
| `.vexp/.gitattributes`, `.vexp/.gitignore`, `.vexp/manifest.json` | piccoli | Idem |
| `backend/data/tag_embeddings_cache.json` | 12,5 MB | Cache embedding rigenerabile da `embeddingService.js` |
| `backend/data/tag_embeddings_multilingual_cache.json` | 12,4 MB | Idem |
| `backend/page1.json`, `backend/page2.json` | 32 B | Output di prova (32 byte): **eliminare** proprio |
| `backend/struttura_backend.txt` | 394 KB | Dump albero directory: **eliminare** |

Aggiunte al `.gitignore`:

```gitignore
# Cache embedding rigenerabili
backend/data/tag_embeddings*.json
```

**Decisione richiesta — dataset MovieLens**: `backend/data/ml-latest-small/` (~3,2 MB)
è tracciato; il `.gitignore` ignora solo `backend/data/movielens/` (path sbagliato).
Opzioni:
- **(A) Mantenerlo tracciato** (consigliato per un progetto di corso: setup riproducibile
  senza download esterni) e correggere/rimuovere la regola `.gitignore` ormai inutile.
- (B) Untrack + documentare in `docs/RICOSTRUZIONE_AMBIENTE.md` lo script di download.

> Nota: rimuovere i blob da HEAD non riduce la storia git. Una riscrittura della storia
> (BFG/filter-repo) è **fuori scope** — non vale il rischio per un repo a sviluppatore singolo.

---

## Fase 2 — Eliminazione duplicati e file root obsoleti

Cancellazioni (con `git rm`):

| File | Motivo |
|------|--------|
| `NEO4J_TMDB_MOVIELENS_ARCHITECTURE.md` (root) | Duplicato **stantio** (11/05) di `docs/NEO4J_TMDB_MOVIELENS_ARCHITECTURE.md` (22/05, referenziato dal README) |
| `agreeo_logo.png` (root, 315 KB) | Hash identico a `docs/agreeo_logo.png`; non è un asset Flutter (pubspec non ha sezione `assets`) |
| `backend/data/ml-latest-small/import_movielens.cypher` | Hash identico a `backend/scripts/import_movielens.cypher` (la fonte canonica è `scripts/`) |
| `package.json` + `package-lock.json` (root) | Contengono solo la dipendenza del tool locale `graphifyy`; il backend ha il proprio `package.json`. Aggiungere `/node_modules/` resta coperto |
| `.agent-socket-io.md` | Prompt per agente ormai consumato (Socket.io è implementato: `backend/socketService.js` esiste) |
| `design.md` | Design "Cinema Popcorn" (dark) superato dalla migrazione Daylight |
| `backend/server.log` | Log locale (già ignorato da `*.log`, non tracciato: semplice delete) |
| `.vscode/mcp.json.vexp-bak` | Backup residuo del tooling vexp |

**Decisione richiesta — PDF del corso** `DM2526 Instructions on projects (1).pdf` (2,7 MB):
- **(A) Spostarlo in `docs/` rinominandolo** `docs/DM2526_project_instructions.pdf` (consigliato:
  è il mandato del progetto, utile averlo nel repo).
- (B) Rimuoverlo dal repo e tenerlo solo in locale.

---

## Fase 3 — Riorganizzazione della documentazione

Tutta la doc descrittiva converge in `docs/`; in root restano solo i file che gli
strumenti si aspettano lì (`README.md`, `AGENTS.md`, config).

Spostamenti (`git mv`):

| Da | A |
|----|---|
| `AVVIO.md` | `docs/AVVIO.md` (aggiornare il link nel `README.md` se presente) |
| `agreeo_neo4j_project_context.md` | `docs/AGREEO_PROJECT_CONTEXT.md` |
| `REMEDIATION_PLAN.md` | `docs/REMEDIATION_PLAN.md` |
| `.vscode/UI_FONT.md` | `docs/UI_FONT.md` |

Struttura `docs/` risultante:

```
docs/
├── AVVIO.md                              # come avviare il progetto
├── AGREEO_PROJECT_CONTEXT.md             # contesto generale per agenti/manutentori
├── BACKEND_CONTRACT.md                   # contratto API frontend↔backend
├── NEO4J_TMDB_MOVIELENS_ARCHITECTURE.md  # architettura dati
├── PRODUCTION_READINESS_PLAN.md
├── REMEDIATION_PLAN.md
├── RICOSTRUZIONE_AMBIENTE.md
├── ROUTING_MAP.md
├── WORKSPACE_CLEANUP_PLAN.md             # questo file
├── UI_FONT.md
├── agreeo_logo.png
└── screenshots/iphone_xr/                # rinumerare 06_*/07_* duplicati (cosmetico)
```

Dopo lo spostamento: `grep` su tutto il repo dei vecchi path (`AVVIO.md`,
`agreeo_neo4j_project_context`, ecc.) per aggiornare i riferimenti incrociati
(README, AGENTS.md, `.github/copilot-instructions.md`, doc tra loro).

---

## Fase 4 — Allineamento struttura `lib/`

1. **Rimuovere la dir vuota** `lib/features/debug/` (la `recommendation_debug_screen.dart`
   è già cancellata; git non traccia dir vuote ma localmente resta).
2. **Rinominare `lib/models/neo4j/neo4j_models.dart` → `lib/models/api_models.dart`**
   (o fonderlo in `app_models.dart`). Motivo: Neo4j non è più acceduto dal client
   (`neo4j_service.dart` e `neo4j_config.dart` sono stati rimossi); i modelli restano ma il
   nome mente. Usati solo da 2 file:
   - `lib/services/auth_service.dart`
   - `lib/shared/services/backend_auth_session_service.dart`
   Aggiornare i 2 import e rimuovere la dir `lib/models/neo4j/`.
3. **Rimuovere le dipendenze morte da `pubspec.yaml`** (verificato: 0 import in `lib/` e `test/`):
   - `crypto` — era usata dal vecchio `neo4j_service.dart` lato client, ora eliminato;
   - `flutter_card_swiper` — lo swipe è implementato custom (vedi commit *"stabilize swipe card"*);
   - `cupertino_icons` — nessun uso di `CupertinoIcons` nel codebase.
   Poi `flutter pub get` per rigenerare `pubspec.lock`.
4. Verifica gate: `flutter analyze` pulito + `flutter test` verdi + smoke test dello swipe
   (è l'area dove una dipendenza rimossa per errore si manifesterebbe subito).

> Esito dell'analisi codice legacy sul frontend: **nessun file Dart orfano** in `lib/` —
> ogni file è importato da almeno un altro. Il grosso del codice legacy (tema Cinema
> Popcorn, `movie_widgets.dart`, `primitives.dart`, client Neo4j, debug screen) è già
> stato eliminato dalla migrazione Daylight e viene consolidato nel commit di Fase 0.

---

## Fase 4-bis — Script operativi backend

`backend/migrate_tags_to_vector.js` (migrazione embeddings) e `backend/seedInitialUsers.js`
(seed utenti demo) non sono `require`-ati da nessun modulo né richiamati da npm script,
Dockerfile o docker-compose: sono tooling one-off, non runtime. **Non vanno eliminati**
(servono a ricostruire l'ambiente) ma spostati dove già vive il tooling analogo:

| Da | A |
|----|---|
| `backend/migrate_tags_to_vector.js` | `backend/scripts/migrate_tags_to_vector.js` |
| `backend/seedInitialUsers.js` | `backend/scripts/seedInitialUsers.js` |

Attenzione ai path relativi interni (`require('./neo4jService')`, `dotenv`, path delle
cache in `backend/data/`): dopo lo spostamento aggiornare i `require` in `../` ed
eseguire entrambi gli script a vuoto/dry-run per conferma. Documentarne l'uso in
`docs/RICOSTRUZIONE_AMBIENTE.md`. (In alternativa minimale: lasciarli dove sono e
aggiungere due `npm script` espliciti — `npm run seed`, `npm run migrate:embeddings` —
così almeno il loro ruolo è dichiarato.)

---

## Fase 5 — Policy per `design_reference/`

Attualmente non tracciata e non ignorata: ogni `git status` la mostra, e i riferimenti
Daylight (i 9 `.jsx` + `Agreeo Daylight Grid.html`) rischiano di perdersi.

Scelta consigliata (ibrida):
1. **Tracciare** i file di riferimento: `design_reference/*.jsx`, `design_reference/*.html`
   (~140 KB, sono la specifica del design corrente).
2. **Ignorare** gli screenshot di lavorazione: aggiungere a `.gitignore`:
   ```gitignore
   design_reference/scraps/
   ```
3. (Opzionale) Quando la migrazione Daylight sarà conclusa e verificata, eliminare
   `scraps/` da disco (2,4 MB di PNG di confronto usa-e-getta).

---

## Fase 6 — Verifica finale

1. `git status` → working tree pulito, nessun file generato che riappare.
2. `flutter analyze` → 0 errori.
3. `flutter test` → verdi (7 file di test in `test/`).
4. Backend: `npm test` in `backend/` (test di `movieRepository`, `socialRepository`,
   `movieController`) → verdi.
5. Avvio fumo: backend su Docker (`docker-compose up`) + `flutter run`, login e home caricano.
6. Controllo link: aprire `README.md` e i doc spostati, verificare che i link relativi risolvano.

---

## Struttura finale attesa (root)

```
agreeo/
├── .clinerules/          # regole Cline per gli MCP server (si tengono)
├── .github/
├── .vscode/              # senza *.vexp-bak e UI_FONT.md
├── android/ ios/ linux/ macos/ web/ windows/   # piattaforme Flutter (vedi nota)
├── backend/              # senza dump/log/cache tracciate
├── deploy/azure/
├── design_reference/     # solo .jsx/.html tracciati, scraps/ ignorata
├── docs/                 # TUTTA la documentazione
├── lib/                  # senza features/debug/, modelli rinominati
├── test/
├── tools/mcp/
├── .dockerignore  .env.example  .env.azure.example  .gitignore  .mcp.json  .metadata
├── AGENTS.md  README.md
├── analysis_options.yaml  devtools_options.yaml
├── docker-compose.yml  docker-compose.azure.yml  Dockerfile
├── pubspec.yaml  pubspec.lock  vexp.toml
```

> **Nota piattaforme**: `linux/`, `macos/`, `windows/`, `web/` sono scaffold Flutter standard.
> Se i target di consegna sono solo Android/iOS si potrebbero rimuovere, ma il costo di
> mantenerli è ~0 e la rimozione complica eventuali demo desktop/web → **si tengono**.

## Fuori repo (manuale, a discrezione)

- `C:\Users\Anton\Downloads\Agreeo (3)\` risulta **vuota** → eliminabile da Esplora file.
- `build/` e `.dart_tool/` sono ignorati; un `flutter clean` periodico libera spazio disco.

---

## Riepilogo commit previsti

| # | Commit | Contenuto |
|---|--------|-----------|
| 0 | `feat: Daylight UI migration + rimozione script legacy` | Tutto il pending attuale |
| 1 | `chore: untrack generated artifacts (graphify, vexp, embedding caches)` | Fase 1 |
| 2 | `chore: remove duplicate and obsolete root files` | Fase 2 |
| 3 | `docs: consolidate documentation under docs/` | Fase 3 |
| 4 | `refactor: rename lib/models/neo4j to api models, drop empty debug feature, prune unused deps` | Fase 4 |
| 4b | `chore: move one-off backend scripts under backend/scripts/` | Fase 4-bis |
| 5 | `chore: track design_reference sources, ignore scraps` | Fase 5 |

Riduzione contenuto tracciato a HEAD: **~33 MB** (25 MB cache embedding + ~5 MB .graphify
+ 1,6 MB graph.json + 0,4 MB dump + 0,3 MB logo duplicato + eventuale PDF 2,7 MB).
