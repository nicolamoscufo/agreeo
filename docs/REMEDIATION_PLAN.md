# ðŸ› ï¸ Agreeo â€” Piano di Remediation e Hardening Production

> Piano operativo per risolvere i problemi emersi nell'audit di production-readiness
> e applicare i miglioramenti. Ordinato per prioritÃ : **Fase 1 (Critical, bloccanti)**
> â†’ **Fase 2 (Warning)** â†’ **Fase 3 (Info/Migliorie)**.
>
> Stato verdetto attuale: **CONDITIONAL** â†’ obiettivo **READY** al termine della Fase 1+2.
>
> Legenda checkbox: `[ ]` da fare Â· `[~]` in corso Â· `[x]` fatto.

---

## ðŸ“‹ Riepilogo esecutivo

| Fase | Tema | Item | Effort stimato | Blocca go-live |
|------|------|------|----------------|----------------|
| 1 | Critical security | 3 | ~1-1.5 gg | âœ… SÃ¬ |
| 2 | Warning (security, deploy, perf) | 10 | ~3-4 gg | âš ï¸ Parziale |
| 3 | Info / migliorie / cleanup | 10 | ~2-3 gg | âŒ No |

**Dipendenze nuove backend:** `helmet`, `express-rate-limit` (+ aggiornamento `neo4j-driver` a 5.x e `@xenova/transformers`).
**Dipendenze nuove frontend:** `flutter_secure_storage`.

---

# ðŸ”´ FASE 1 â€” CRITICAL (bloccano il go-live)

## 1.1 â€” Autenticazione Socket.IO falsificabile

**File:** [backend/socketService.js](../backend/socketService.js) Â· **Problema:** il client invia `userId` in chiaro e il server fa `join('user_'+userId)` senza verifica â†’ impersonazione totale. CORS `origin:'*'`.

**Azioni:**
- [x] Aggiungere un middleware `io.use()` che verifica il JWT passato nell'handshake (`socket.handshake.auth.token`) tramite `verify()` di `jwtUtils`.
- [x] Ricavare lo `userId` **dal token verificato** (`payload.uid || payload.sub`), non dal payload `authenticate`.
- [x] Rifiutare la connessione (`next(new Error('unauthorized'))`) se il token manca o Ã¨ invalido.
- [x] Restringere la CORS del socket alla stessa allowlist di Express (`CORS_ORIGINS`).
- [x] Mantenere l'evento `authenticate` solo come no-op di compatibilitÃ , oppure rimuoverlo dopo l'aggiornamento del client.

**Snippet di riferimento (backend/socketService.js):**
```js
const { verify } = require('./jwtUtils');

function init(server, { corsOrigins = [] } = {}) {
  io = socketIo(server, {
    cors: {
      origin: corsOrigins.length > 0 ? corsOrigins : true,
      methods: ['GET', 'POST', 'PATCH', 'DELETE'],
    },
  });

  io.use((socket, next) => {
    const token =
      socket.handshake.auth?.token ||
      socket.handshake.headers?.authorization?.replace('Bearer ', '');
    const payload = token ? verify(token) : null;
    if (!payload) return next(new Error('unauthorized'));
    socket.data.userId = payload.uid || payload.sub;
    next();
  });

  io.on('connection', (socket) => {
    socket.join(`user_${socket.data.userId}`);
    socket.on('disconnect', () => {});
  });
  return io;
}
```

**Frontend:** [lib/services/real_time_service.dart:33-45](../lib/services/real_time_service.dart#L33-L45) â€” passare il token nell'handshake invece di emettere `authenticate`:
- [x] Recuperare l'access token (`AuthService.readToken()`) prima di `io.io(...)`.
- [x] `OptionBuilder().setAuth({'token': token})` e rimuovere `_socket!.emit('authenticate', ...)`.
- [x] Gestire il reconnect dopo refresh del token (riconnettere con il nuovo token su `onConnectError`/401).

**Verifica:** connessione senza token rifiutata; connessione con token di utente A non riceve eventi di utente B.

---

## 1.2 â€” Fallback del segreto JWT a `CHANGE_ME`

**File:** [backend/jwtUtils.js:3-16](../backend/jwtUtils.js#L3-L16) Â· **Problema:** con `NODE_ENV != production` accetta `JWT_SECRET=CHANGE_ME`; il `docker-compose.yml` locale non imposta `NODE_ENV=production`.

**Azioni:**
- [x] Rendere `JWT_SECRET` **sempre obbligatorio**: fallire l'avvio se assente, `CHANGE_ME`, o piÃ¹ corto di 32 caratteri â€” indipendentemente da `NODE_ENV`.
- [x] Impostare `NODE_ENV=production` anche in [docker-compose.yml](../docker-compose.yml) (servizio `backend`).
- [x] Aggiornare `.env.example` / `backend/.env.example` con una nota esplicita sul requisito di lunghezza/casualitÃ .
- [x] Rigenerare il `JWT_SECRET` reale in [.env](../.env) (attualmente `CHANGE_ME`) con valore casuale â‰¥ 32 byte.

**Snippet (backend/jwtUtils.js):**
```js
function resolveSecret() {
  const secret = process.env.JWT_SECRET;
  if (!secret || secret === 'CHANGE_ME' || secret.length < 32) {
    throw new Error(
      'JWT_SECRET must be set to a strong random value (>= 32 chars).'
    );
  }
  return secret;
}
```

**Verifica:** avvio fallisce con secret debole/mancante; token firmati con secret forte.

---

## 1.3 â€” Rate limiting assente + endpoint pubblici che scrivono su DB / consumano TMDB

**File:** [backend/server.js:32-41](../backend/server.js#L32-L41) Â· **Problema:** nessun rate limit (brute-force su `/auth/*`); endpoint film pubblici scrivono su Neo4j e chiamano TMDB ad ogni richiesta.

**Azioni:**
- [x] `npm i express-rate-limit`.
- [x] Limiter aggressivo su `/auth/login` e `/auth/register` (es. 10 richieste / 15 min per IP).
- [x] Limiter globale piÃ¹ permissivo su tutte le rotte API (es. 100-300 / 15 min per IP).
- [x] Valutare se gli endpoint `/movies/*` pubblici debbano essere protetti da auth o serviti con cache (vedi 2.5 / 3.x perf).
- [x] Configurare `app.set('trust proxy', 1)` se dietro reverse proxy / nginx (necessario per il rilevamento IP corretto).

**Snippet (backend/server.js):**
```js
const rateLimit = require('express-rate-limit');

const authLimiter = rateLimit({ windowMs: 15 * 60_000, max: 10, standardHeaders: true });
const apiLimiter  = rateLimit({ windowMs: 15 * 60_000, max: 300, standardHeaders: true });

app.set('trust proxy', 1);
app.use(apiLimiter);
app.post('/auth/register', authLimiter, authController.register);
app.post('/auth/login', authLimiter, authController.login);
```

**Verifica:** superato il limite su `/auth/login` â†’ risposta `429`.

---

# ðŸŸ¡ FASE 2 â€” WARNING (da risolvere prima della prod)

## 2.1 â€” Header HTTP di sicurezza (helmet)
**File:** [backend/server.js](../backend/server.js)
- [x] `npm i helmet` e `app.use(helmet())` come primo middleware.
- [x] Verificare che CSP/altri header non rompano nulla (l'API serve JSON; il frontend Ã¨ servito da nginx separato).

## 2.2 â€” Stack/messaggi d'errore esposti al client
**File:** [backend/movieController.js:810-815](../backend/movieController.js#L810-L815) (`handleError`), e i `catch` di [authController.js](../backend/authController.js), [socialController.js:29-32](../backend/socialController.js#L29-L32).
- [x] In produzione restituire un messaggio generico (`'Internal server error'`), loggare il dettaglio solo server-side.
- [x] Uniformare tutti gli handler di errore a non propagare `error.message` nel body quando `NODE_ENV=production`.

```js
function handleError(res, error, fallbackMessage) {
  console.error(fallbackMessage, error);
  const isProd = process.env.NODE_ENV === 'production';
  return res.status(500).json({
    error: isProd ? fallbackMessage : (error instanceof Error ? error.message : fallbackMessage),
  });
}
```

## 2.3 â€” Graceful shutdown
**File:** [backend/server.js:187-205](../backend/server.js#L187-L205)
- [x] Handler `SIGTERM`/`SIGINT`: chiudere in ordine Socket.IO â†’ server HTTP â†’ `neo4jService.close()`.
- [x] Timeout di sicurezza (force exit dopo N secondi) per evitare hang.

```js
async function shutdown(signal) {
  console.log(`Received ${signal}, shutting down...`);
  io?.close?.();
  server.close(async () => {
    await neo4jService.close();
    process.exit(0);
  });
  setTimeout(() => process.exit(1), 10_000).unref();
}
['SIGTERM', 'SIGINT'].forEach((sig) => process.on(sig, () => shutdown(sig)));
```
- [x] Esporre `neo4jService.close()` (giÃ  presente) e chiusura io (aggiungere export `getIo()` giÃ  disponibile).

## 2.4 â€” VulnerabilitÃ  dipendenze (npm audit)
**Contesto:** 5 vuln (1 critical `protobufjs` CVSS 9.8 via `@xenova/transformers`, 3 high, 1 moderate `qs`).
- [x] `npm audit fix` per `qs` (non-breaking).
- [x] Aggiornare/pinnare `@xenova/transformers` all'ultima versione che risolve `protobufjs`; **testare la generazione embeddings** dopo l'update (Ã¨ codice caldo: [backend/embeddingService.js](../backend/embeddingService.js)).
- [x] Se l'update introduce breaking change, valutare lazy-load del modello in un servizio isolato o pinning di `protobufjs` via `overrides` in `package.json`.
- [x] Aggiungere `npm audit --audit-level=high` come step CI (vedi 3.9).

## 2.5 â€” Driver Neo4j obsoleto + pool/retry non configurati
**File:** [backend/neo4jService.js:1-13](../backend/neo4jService.js#L1-L13), `package.json` (`neo4j-driver@4.4.3`).
- [x] Aggiornare a `neo4j-driver@5.x` (allineato alle feature 5 giÃ  usate: vector index, subquery `CALL{}`/`EXISTS{}`).
- [x] Configurare il pool e i timeout nel costruttore del driver.
- [x] Verificare che `verifyConnectivity`, `session()`, `writeTransaction`/`readTransaction` restino compatibili (API 5 retro-compatibile sui metodi usati).

```js
this._driver = neo4j.driver(uri, neo4j.auth.basic(user, password), {
  maxConnectionPoolSize: 50,
  connectionAcquisitionTimeout: 30_000,
  maxTransactionRetryTime: 15_000,
});
```

## 2.6 â€” Full graph scan su `MATCH (m:Movie)`
**File:** [backend/movieRepository.js:1172](../backend/movieRepository.js#L1172) (`getCandidatePoolStats`), [backend/movieRepository.js:861](../backend/movieRepository.js#L861) (`getExploratoryCandidates`).
- [x] `PROFILE` delle due query per misurare db-hits sul catalogo attuale.
- [x] In `getExploratoryCandidates` sfruttare l'indice `movie_ml_rating_count` (giÃ  esistente) anteponendo il filtro `m.movieLensRatingCount >= $minRatingCount` in modo indicizzabile.
- [x] Valutare di sostituire le `EXISTS{}` per-nodo in `getCandidatePoolStats` con conteggi aggregati su relazioni.
- [x] Documentare i risultati PROFILE prima/dopo nel commit.

## 2.7 â€” N+1 verso TMDB in `enrichMovies`
**File:** [backend/movieController.js:581-607](../backend/movieController.js#L581-L607) (`enrichMovies` â†’ `resolveMovieRuntime` per ogni film).
- [x] Saltare la chiamata `/movie/:id` quando il runtime Ã¨ giÃ  presente sul nodo Neo4j (`neoMovie.runtime != null`).
- [x] Per i mancanti, idratare in batch con `runWithConcurrency` (giÃ  disponibile in [socialRepository.js:1004](../backend/socialRepository.js#L1004)) invece di `Promise.all` non bounded.
- [x] Confermare che popular/search/recommendations/daily non facciano piÃ¹ 1 round-trip TMDB per risultato quando i dati sono in cache.

## 2.8 â€” Android cleartext traffic in release
**File:** [android/app/src/main/AndroidManifest.xml:7](../android/app/src/main/AndroidManifest.xml#L7) (`usesCleartextTraffic="true"`).
- [x] Rimuovere `usesCleartextTraffic` dal manifest `main` (release).
- [x] Mantenerlo solo in `debug`/`profile` (giÃ  presenti i manifest specifici) o usare un `network_security_config.xml` che consente cleartext solo verso `10.0.2.2`/`localhost`.
- [x] Garantire che il `BACKEND_BASE_URL` di produzione sia `https://`.

## 2.9 â€” Policy password + storage token sul device
**File:** [backend/authController.js:49](../backend/authController.js#L49), [lib/services/auth_service.dart:128-143](../lib/services/auth_service.dart#L128-L143).
- [x] Alzare il minimo password (â‰¥ 8) e aggiungere un controllo di complessitÃ  minimo lato backend (e validazione UI lato Flutter).
- [x] `flutter pub add flutter_secure_storage` e migrare `auth_accessToken`/`auth_refreshToken` da `SharedPreferences` a secure storage (Keychain/Keystore).
- [x] Mantenere fallback/migrazione per utenti giÃ  loggati (leggere da prefs una volta, riscrivere in secure storage, ripulire prefs).

## 2.10 â€” Password Neo4j di default `password123`
**File:** [docker-compose.yml:6,14,32](../docker-compose.yml#L6), [.env.example](../.env.example), [backend/.env.example](../backend/.env.example).
- [x] Nel compose locale, rendere `NEO4J_PASSWORD` obbligatoria (`${NEO4J_PASSWORD:?Set NEO4J_PASSWORD}`) come giÃ  fatto in [docker-compose.azure.yml](../docker-compose.azure.yml).
- [x] Rimuovere il valore `password123` dai `.env.example` (sostituire con placeholder `change_me_strong_password`).
- [x] Aggiornare il default in [backend/neo4jService.js:7](../backend/neo4jService.js#L7) per non incoraggiare il fallback (o lasciarlo solo per dev locale documentato).

---

# ðŸ”µ FASE 3 â€” INFO / MIGLIORIE / CLEANUP

## 3.1 â€” Debug endpoint disattivato di default in prod
**File:** [backend/movieController.js:170-172](../backend/movieController.js#L170-L172) (`recommendationDebugEnabled`).
- [x] Cambiare il default di `ENABLE_RECOMMENDATION_DEBUG` a `false`; abilitarlo esplicitamente solo in dev.

## 3.2 â€” Ripristinare il limite di swipe giornaliero
**File:** [backend/movieController.js:1239-1250](../backend/movieController.js#L1239-L1250) (logica "for testing" con `MAX_SAFE_INTEGER`).
- [x] Rispettare `buildDailySuggestionSettings()` (limit/enabled) invece di forzare illimitato.
- [x] Rimuovere i commenti "for testing".

## 3.3 â€” Health check
**File:** [backend/server.js:171-185](../backend/server.js#L171-L185).
- [x] Aggiungere `GET /health` liveness leggero (no DB) per orchestratore.
- [x] Mantenere `/health/db` readiness ma rimuovere `neo4jUri` dalla risposta (info disclosure).

## 3.4 â€” Logging strutturato
**File:** trasversale (`console.*` ovunque; richieste loggate in [server.js:27-30](../backend/server.js#L27-L30); mood query in [movieController.js:1426-1504](../backend/movieController.js#L1426-L1504)).
- [ ] Introdurre `pino` (o winston) con livelli (`info`/`warn`/`error`) e log JSON.
- [x] Non loggare input utente in chiaro (query di ricerca/mood) nÃ© URL completi con eventuali parametri sensibili.
- [x] Rimuovere i blocchi `console.log` decorativi del mood-search o abbassarli a `debug`.

## 3.5 â€” Hardening interpolazione Cypher (difesa in profonditÃ )
**File:** `LIMIT ${safeLimit}` ([movieRepository.js:937,1039,...](../backend/movieRepository.js#L937)), `removeRels.join('|')` ([movieRepository.js:285](../backend/movieRepository.js#L285)).
- [x] Dove possibile, passare `LIMIT $limit` come parametro (`toInteger($limit)`) invece di interpolare.
- [x] Lasciare commento esplicito sulle whitelist per i tipi di relazione interpolati (giÃ  sicuri perchÃ© costanti).

## 3.6 â€” Allineare README e documentazione
**File:** [README.md](../README.md).
- [x] Rimuovere i riferimenti a Firebase ("initializes Firebase on startup", `google-services.json`, `flutterfire configure`) non piÃ¹ validi.
- [x] Aggiornare la sezione "Project structure" alla reale architettura feature-first (`lib/features/*`, `lib/shared/*`).
- [ ] Verificare coerenza con [docs/BACKEND_CONTRACT.md](BACKEND_CONTRACT.md) e [docs/ROUTING_MAP.md](ROUTING_MAP.md).

## 3.7 â€” Cleanup file spuri versionati
- [x] Rimuovere da git: `backend/page1.json`, `backend/page2.json`, `backend/struttura_backend.txt`, `backend/server.log`, `DM2526 Instructions on projects (1).pdf` (2,6 MB).
- [x] Aggiungere `*.log` e file temporanei al `.gitignore` (giÃ  presente `*.log` generico â€” verificare che `backend/server.log` sia ignorato).
- [x] Completare la rimozione degli script usa-e-getta giÃ  marcati come deleted in `git status` (commit della pulizia).

## 3.8 â€” AccessibilitÃ  frontend
**File:** trasversale `lib/` (solo [movie_night_voting_screen.dart](../lib/features/friends/presentation/movie_night_voting_screen.dart) usa `Semantics`).
- [x] Aggiungere `semanticLabel` ai poster (`AgPoster`/`cached_network_image`) e alle icone interattive.
- [x] Verificare label dei campi form (auth, onboarding, edit profile).
- [ ] Controllo contrasto sui token tema ([lib/shared/theme/agreeo_tokens.dart](../lib/shared/theme/agreeo_tokens.dart)) per WCAG AA.

## 3.9 â€” CI: lint + test + audit
**File:** [.github/](../.github/) (oggi solo `copilot-instructions.md`, nessun workflow).
- [x] Workflow GitHub Actions: `flutter analyze` + `flutter test` (frontend) e `node --test` + `npm audit --audit-level=high` (backend) su PR.
- [ ] Bloccare il merge su fallimento test/audit critico.

## 3.10 â€” Rimuovere `TmdbService` client se dead code
**File:** [lib/services/tmdb_service.dart](../lib/services/tmdb_service.dart) (istanziato solo nei test; espone `api_key` via `--dart-define`).
- [x] Confermare che non sia usato a runtime (il catalogo passa dal backend).
- [x] Se morto, rimuoverlo (e il relativo test) per evitare il rischio di leak della chiave nel bundle web.

---

## âœ… Checklist di accettazione "READY"

- [x] Fase 1 completata (1.1, 1.2, 1.3) e verificata.
- [x] Fase 2 completata (2.1â€“2.10).
- [x] `npm audit` â†’ 0 vulnerabilitÃ  critical/high.
- [x] `flutter analyze` pulito + `flutter test` verde.
- [x] `node --test` backend verde (oggi 23/23) con i nuovi test per: auth Socket.IO, rate limiting, secret JWT obbligatorio.
- [ ] Smoke test deploy con `docker-compose.azure.yml`: avvio, `/health`, login, swipe, movie night, realtime con token valido.
- [x] Nessun segreto/credenziale di default residua nei file versionati.

---

## ðŸ“Œ Note sull'ordine di esecuzione

1. **Prima** Fase 1 (sblocca la sicurezza di base) â€” puÃ² andare in un'unica PR.
2. **Poi** 2.1â€“2.4 (security/deploy a basso rischio), quindi 2.5â€“2.7 (perf/DB, richiedono PROFILE e test), infine 2.8â€“2.10 (client/config).
3. La Fase 3 Ã¨ incrementale e non blocca: il cleanup (3.6/3.7) e la CI (3.9) conviene farli presto per igiene del repo.

Ogni item cita file e righe puntuali per facilitare l'intervento. Aggiornare i checkbox man mano.
