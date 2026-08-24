# Riferimento tecnico Neo4j e catalogo completo delle query

## 1. Scopo e perimetro

Questo documento descrive come Agreeo usa Neo4j, dalla connessione al database fino alle query Cypher eseguite dal backend, dai job di importazione e dalla console diagnostica Flutter.

Il riferimento e' stato ricostruito dal codice eseguibile presente nel repository il 24 agosto 2026. Quando questo documento e il codice divergono, il codice e' la fonte di verita'. Le query molto lunghe sono riportate in forma normalizzata: indentazione e parti ripetitive delle proiezioni possono essere compatte, ma pattern, filtri, parametri, aggregazioni e formule restano quelli del sorgente.

### 1.1 Censimento

| Area | File | Template/query Cypher distinti |
|---|---|---:|
| Schema e manutenzione all'avvio | `backend/neo4jService.js` | 18 |
| Autenticazione e profilo | `backend/authController.js` | 10 |
| Profilo corrente | `backend/server.js` | 1 |
| Onboarding | `backend/movieController.js` | 1 |
| Film, libreria e raccomandazioni | `backend/movieRepository.js` | 36 |
| Social, Movie Night e notifiche | `backend/socialRepository.js` | 51 |
| Diagnostica Neo4j | `backend/neo4jDebugController.js` | 11 fissi + 1 query arbitraria |
| Import MovieLens | `backend/scripts/import_movielens.cypher` | 12 |
| Migrazione tag vettoriali | `backend/scripts/migrate_tags_to_vector.js` | 10 |
| Seed demo | `backend/scripts/seedInitialUsers.js` | 1 |
| Valutazione raccomandazioni | `backend/scripts/evaluate_recommendations.js` | 2 |
| Servizio embedding | `backend/embeddingService.js` | 2 |
| Health check Docker | `docker-compose.yml` | 1 |
| Preset della console Flutter | `neo4j_console_screen.dart` | 6 |

Le aree backend del censimento contengono **128 template fissi** e **un punto di esecuzione controllato per Cypher arbitrario**. Poiche' `E02` viene eseguita anche durante il mood search, le query fisse che possono servire richieste HTTP sono 129. Considerando job, health check e preset Flutter, il repository contiene **162 query/template fissi eseguibili**. Il numero di query realmente eseguite per una richiesta e' variabile: alcuni template sono in cicli, altri sono alternativi, condizionali o evitati dalla cache.

Sono esclusi dal conteggio gli esempi puramente didattici gia' presenti nei documenti e le stringhe Cypher simulate nei test.

## 2. Architettura di accesso

```text
Flutter
  |
  | HTTPS/JSON + JWT; nessuna credenziale Neo4j nel client
  v
Express controller
  |-- authController
  |-- movieController
  |-- socialController
  |-- neo4jDebugController
  v
Repository / Neo4jService
  |
  | Bolt, neo4j-driver 5.28
  v
Neo4j 5
```

Flutter non usa un driver Neo4j. Tutti gli accessi passano dal backend HTTP. La sola funzionalita' che accetta Cypher dal client e' la console diagnostica, protetta da JWT e dal flag `ENABLE_NEO4J_DEBUG`, ed eseguita in una read transaction.

### 2.1 Ruolo delle sorgenti dati

| Sorgente | Ruolo |
|---|---|
| TMDB | Catalogo UI, titoli, poster, backdrop, dettagli, cast, trailer e ricerca |
| MovieLens | Rating collaborativi, utenti sintetici, generi e tag |
| Neo4j | Identita' applicative, interazioni, grafo sociale, Movie Night, eventi di raccomandazione e ponte fra TMDB e MovieLens |

Il nodo canonico dell'app e' `(:Movie {tmdbId})`. Il dataset mantiene separato `(:MovieLensMovie {movieLensId})`; il collegamento e':

```cypher
(:MovieLensMovie)-[:MATCHES_TMDB]->(:Movie)
```

Questo evita di confondere gli ID dei due cataloghi e consente a piu' righe MovieLens di convergere sullo stesso film TMDB.

## 3. Modello del grafo

### 3.1 Nodi principali

| Label | Identificatore | Uso principale |
|---|---|---|
| `AppUser` | `uid` | Account, preferenze, socialita' e azioni sui film |
| `Movie` | `tmdbId` | Film canonico mostrato nell'app |
| `Genre` | `name` | Generi MovieLens, TMDB e preferenze utente |
| `MovieLensUser` | `movieLensUserId` | Utenti importati, mai autenticabili |
| `MovieLensMovie` | `movieLensId` | Film raw del dataset MovieLens |
| `Tag` | `name` | Tag materializzato, IDF ed embedding 384D |
| `RecommendationBatch` | `id` | Batch servito, variante sperimentale e scadenza |
| `DailySwipeQuota` | `key` | Quota per `uid:data UTC` |
| `MovieNight` | `id` | Evento di gruppo, vincoli, round e vincitore |
| `InAppNotification` | `id` | Notifica persistente dell'utente |

### 3.2 Relazioni principali

```cypher
(:AppUser)-[:LIKED|DISLIKED|WATCHLISTED|ALREADY_SEEN]->(:Movie)
(:AppUser)-[:SELECTED_FAVORITE {weight}]->(:Movie)
(:AppUser)-[:RATED_APP {rating, review}]->(:Movie)
(:AppUser)-[:PREFERS_GENRE]->(:Genre)

(:MovieLensUser)-[:RATED {rating, timestamp, ratedAt}]->(:MovieLensMovie)
(:MovieLensUser)-[:TAGGED {tag, timestamp, taggedAt}]->(:MovieLensMovie)
(:MovieLensMovie)-[:MATCHES_TMDB]->(:Movie)
(:MovieLensMovie)-[:IN_GENRE]->(:Genre)
(:MovieLensMovie)-[:HAS_TAG {frequency}]->(:Tag)
(:Movie)-[:IN_GENRE]->(:Genre)

(:AppUser)-[:REQUESTED_RECOMMENDATIONS]->(:RecommendationBatch)
(:RecommendationBatch)-[:INCLUDED {
  position, source, finalScore, servedAt,
  impressedAt, swipedAt, action, clientSource, clientPosition
}]->(:Movie)
(:AppUser)-[:HAS_DAILY_QUOTA]->(:DailySwipeQuota)

(:AppUser)-[:FRIEND]-(:AppUser)
(:AppUser)-[:SENT_FRIEND_REQUEST {requestId, status}]->(:AppUser)
(:AppUser)-[:BLOCKED]->(:AppUser)
(:AppUser)-[:REPORTED]->(:AppUser)

(:AppUser)-[:HOSTS]->(:MovieNight)
(:AppUser)-[:PARTICIPATES_IN {status, isHost}]->(:MovieNight)
(:MovieNight)-[:HAS_CANDIDATE {compatibilityScore, eliminated}]->(:Movie)
(:AppUser)-[:VOTED_IN {eventId, vote}]->(:Movie)

(:AppUser)-[:HAS_NOTIFICATION]->(:InAppNotification)
```

`FRIEND` viene interrogata senza direzione. `BLOCKED`, richieste, notifiche e le relazioni MovieLens sono orientate. Il voto porta `eventId` sulla relazione `VOTED_IN`; non esiste un nodo `Vote`.

## 4. Connessione, sessioni e transazioni

### 4.1 Configurazione di `Neo4jService`

| Variabile | Default/runtime |
|---|---|
| `NEO4J_URI` | `bolt://localhost:7687` |
| `NEO4J_USERNAME` | `neo4j` |
| `NEO4J_PASSWORD` | obbligatoria in `NODE_ENV=production`; altrimenti `password123` |
| `NEO4J_DATABASE` | database predefinito se assente |

Il driver usa:

```js
neo4j.driver(uri, neo4j.auth.basic(user, password), {
  maxConnectionPoolSize: 50,
  connectionAcquisitionTimeout: 30_000,
  maxTransactionRetryTime: 15_000,
})
```

La cifratura dipende dallo schema dell'URI, per esempio `neo4j+s://` o `bolt+s://`; non viene forzata nel codice.

### 4.2 API del service

| Metodo | Semantica |
|---|---|
| `verifyConnection()` | `driver.verifyConnectivity()`, senza Cypher |
| `initialize()` | verifica connessione, crea schema, materializza generi e applica retention |
| `run(query, params)` | nuova sessione, `session.run`, auto-commit, chiusura in `finally` |
| `executeRead(callback)` | managed `readTransaction`, retry del driver, sessione dedicata |
| `executeWrite(callback)` | managed `writeTransaction`, rollback atomico e retry del driver |
| `captureQueryTrace(callback)` | raccoglie query passate da `run`; non vede i `tx.run` diretti |
| `close()` | chiude driver e pool |

`run` non imposta esplicitamente l'access mode. Anche molte letture usano quindi una sessione con modalita' predefinita del driver. La console usa invece `executeRead` per imporre il routing read-only.

I callback di una managed transaction possono essere ritentati: devono evitare effetti esterni non idempotenti. Le chiamate TMDB, le emissioni Socket.IO e le notifiche non fanno parte di transazioni Neo4j distribuite.

### 4.3 Tracing

`captureQueryTrace` salva `query.trim()`, parametri, durata, numero record ed errore. Vengono rimossi solo gli spazi esterni, non viene normalizzata l'indentazione interna. Oscura soltanto chiavi chiamate esattamente `uid`; email, hash e token non sono redatti automaticamente. Le query eseguite con `tx.run` dentro `executeRead` o `executeWrite` non attraversano il tracer.

## 5. Query di schema e manutenzione all'avvio

Le query `N01-N18` sono in `Neo4jService.createConstraints()` e vengono lanciate da `start()` prima che Express accetti traffico. Sono auto-commit separate e sequenziali. Solo l'indice vettoriale e' best effort in questo percorso: il suo errore genera un warning; gli altri errori bloccano l'avvio.

### 5.1 Constraint e indici

| ID | Cypher | Funzione |
|---|---|---|
| N01 | `CREATE CONSTRAINT app_user_uid IF NOT EXISTS FOR (u:AppUser) REQUIRE u.uid IS UNIQUE` | Unicita' account |
| N02 | `CREATE CONSTRAINT app_user_email IF NOT EXISTS FOR (u:AppUser) REQUIRE u.emailNormalized IS UNIQUE` | Unicita' login normalizzato |
| N03 | `CREATE CONSTRAINT movie_tmdb_id IF NOT EXISTS FOR (m:Movie) REQUIRE m.tmdbId IS UNIQUE` | Catalogo TMDB canonico |
| N04 | `CREATE CONSTRAINT movielens_movie_id IF NOT EXISTS FOR (m:MovieLensMovie) REQUIRE m.movieLensId IS UNIQUE` | Film MovieLens raw |
| N05 | `CREATE CONSTRAINT movielens_user_id IF NOT EXISTS FOR (u:MovieLensUser) REQUIRE u.movieLensUserId IS UNIQUE` | Utenti MovieLens |
| N06 | `CREATE CONSTRAINT genre_name IF NOT EXISTS FOR (g:Genre) REQUIRE g.name IS UNIQUE` | Deduplicazione generi |
| N07 | `CREATE CONSTRAINT tag_name IF NOT EXISTS FOR (t:Tag) REQUIRE t.name IS UNIQUE` | Deduplicazione tag |
| N08 | ``CREATE VECTOR INDEX tag_embeddings IF NOT EXISTS FOR (t:Tag) ON (t.embedding) OPTIONS {indexConfig: {`vector.dimensions`: 384, `vector.similarity_function`: 'cosine'}}`` | Ricerca semantica |
| N09 | `CREATE CONSTRAINT movie_night_id IF NOT EXISTS FOR (m:MovieNight) REQUIRE m.id IS UNIQUE` | Eventi Movie Night |
| N10 | `CREATE CONSTRAINT recommendation_batch_id IF NOT EXISTS FOR (b:RecommendationBatch) REQUIRE b.id IS UNIQUE` | Batch di raccomandazione |
| N11 | `CREATE INDEX recommendation_batch_created_at IF NOT EXISTS FOR (b:RecommendationBatch) ON (b.createdAt)` | Retention e metriche |
| N12 | `CREATE CONSTRAINT daily_swipe_quota_key IF NOT EXISTS FOR (q:DailySwipeQuota) REQUIRE q.key IS UNIQUE` | Incremento quota concorrente |
| N13 | `CREATE INDEX movie_title IF NOT EXISTS FOR (m:Movie) ON (m.title)` | Titoli canonici |
| N14 | `CREATE INDEX movielens_movie_title IF NOT EXISTS FOR (m:MovieLensMovie) ON (m.title)` | Titoli raw |
| N15 | `CREATE INDEX movie_ml_rating_count IF NOT EXISTS FOR (m:Movie) ON (m.movieLensRatingCount)` | Pool esplorativo e shortlist |

I constraint unici creano anche backing index interni, visibili con `SHOW INDEXES`.

### 5.2 Manutenzione

**N16 - materializzazione dei generi canonici**

```cypher
MATCH (m:Movie)
WHERE size(coalesce(m.genres, [])) > 0
UNWIND m.genres AS genreName
MERGE (g:Genre {name: genreName})
MERGE (m)-[:IN_GENRE]->(g)
```

Rende interrogabile come grafo l'array legacy `Movie.genres`. E' idempotente per nodi e relazioni, ma non elimina collegamenti obsoleti e puo' scandire molti film a ogni avvio.

**N17 - retention dei batch**

```cypher
MATCH (batch:RecommendationBatch)
WHERE batch.createdAt < datetime() - duration({days: 90})
DETACH DELETE batch
```

**N18 - retention delle quote**

```cypher
MATCH (quota:DailySwipeQuota)
WHERE quota.day < date() - duration({days: 90})
DETACH DELETE quota
```

La retention delle quote non ha un indice esplicito su `day`.

## 6. Query account, profilo e onboarding

### A01 - verifica email in registrazione

- Funzione: `authController.register`
- Route: `POST /auth/register`
- Parametri: `emailNormalized`

```cypher
MATCH (u:AppUser {emailNormalized: $emailNormalized})
RETURN u.uid AS uid
LIMIT 1
```

Il controllo migliora il messaggio HTTP, ma non sostituisce il constraint `N02`, necessario contro registrazioni concorrenti.

### A02 - creazione account

```cypher
CREATE (u:AppUser {
  uid: $uid,
  email: $email,
  emailNormalized: $emailNormalized,
  displayName: $displayName,
  passwordHash: $passwordHash,
  createdAt: datetime(),
  onboardingCompleted: false,
  roles: $roles
})
RETURN u.uid AS uid,
       u.email AS email,
       u.displayName AS displayName,
       coalesce(u.bio, '') AS bio,
       coalesce(u.avatarUrl, '') AS avatarUrl,
       toString(u.createdAt) AS createdAt,
       coalesce(u.onboardingCompleted, false) AS onboardingCompleted,
       coalesce(u.roles, ['USER']) AS roles
```

Funzione e route: `register`, `POST /auth/register`. Parametri: UID generato, email originale e normalizzata, display name, hash bcrypt e ruoli. Il pre-check `A01` e `A02` sono auto-commit distinti.

### A03 - login

```cypher
MATCH (u:AppUser {emailNormalized: $emailNormalized})
RETURN u.passwordHash AS passwordHash,
       u.uid AS uid,
       u.email AS email,
       u.displayName AS displayName,
       coalesce(u.bio, '') AS bio,
       coalesce(u.avatarUrl, '') AS avatarUrl,
       toString(u.createdAt) AS createdAt,
       coalesce(u.onboardingCompleted, false) AS onboardingCompleted,
       coalesce(u.roles, ['USER']) AS roles
LIMIT 1
```

Funzione e route: `authController.login`, `POST /auth/login`. La verifica bcrypt e la firma dei JWT avvengono dopo la query.

### A04 - aggiornamento dinamico del profilo

```cypher
MATCH (u:AppUser {uid: $uid})
SET u.<campo-allowlisted> = $<campo> [, ...]
RETURN <proiezione account A02>
LIMIT 1
```

- Funzione: `authController.updateProfile`
- Route: `PATCH /me/profile`
- Campi ammessi: `displayName`, `bio`, `avatarUrl`

I nomi delle proprieta' sono interpolati, ma provengono da un'allowlist interna. I valori sono sempre parametri.

### A05 - aggiornamento privacy

```cypher
MATCH (u:AppUser {uid: $uid})
SET u.<privacy-key-allowlisted> = $<privacy-key> [, ...]
RETURN coalesce(u.canShowWatched, true) AS canShowWatched,
       coalesce(u.canShowReviews, true) AS canShowReviews,
       coalesce(u.canShowWatchlist, false) AS canShowWatchlist
LIMIT 1
```

- Funzione: `authController.updatePrivacy`
- Route: `PATCH /me/privacy`
- Campi ammessi: `canShowWatched`, `canShowReviews`, `canShowWatchlist`

### A06 - verifica password per UID

```cypher
MATCH (u:AppUser {uid: $uid})
RETURN u.passwordHash AS passwordHash
LIMIT 1
```

Helper: `verifyPasswordForUid`; usato da `POST /me/password` e `DELETE /me`.

### A07 - cambio password

```cypher
MATCH (u:AppUser {uid: $uid})
SET u.passwordHash = $passwordHash
```

Funzione e route: `changePassword`, `POST /me/password`. La verifica `A06` e l'update sono due auto-commit; l'assenza del nodo al momento dell'update non viene controllata dal summary. I token esistenti non vengono revocati.

### A08-A10 - cancellazione account

Le tre query sono eseguite in un'unica `executeWrite`; la verifica password `A06` resta esterna.

```cypher
// A08
MATCH (batch:RecommendationBatch {uid: $uid})
DETACH DELETE batch

// A09
MATCH (quota:DailySwipeQuota {uid: $uid})
DETACH DELETE quota

// A10
MATCH (u:AppUser {uid: $uid})
DETACH DELETE u
```

Funzione e route: `authController.deleteAccount`, `DELETE /me`. L'ultimo `DETACH DELETE` rimuove interazioni, preferenze, relazioni sociali, partecipazioni e notifiche incidenti. Il refresh token non consulta Neo4j e non esiste una denylist JWT.

### A11 - profilo corrente

```cypher
MATCH (u:AppUser {uid: $uid})
RETURN u.uid AS uid,
       u.email AS email,
       u.displayName AS displayName,
       coalesce(u.bio, '') AS bio,
       coalesce(u.avatarUrl, '') AS avatarUrl,
       toString(u.createdAt) AS createdAt,
       coalesce(u.onboardingCompleted, false) AS onboardingCompleted,
       coalesce(u.roles, ['USER']) AS roles
LIMIT 1
```

Route inline: `GET /me` in `server.js`. La proiezione duplica quella di `authController` e puo' divergere se aggiornata in un solo punto.

### A12 - stato onboarding

```cypher
MATCH (u:AppUser {uid: $uid})
SET u.onboardingCompleted = $completed
RETURN <proiezione account A11>
LIMIT 1
```

Funzione e route: `movieController.updateOnboarding`, `PATCH /me/onboarding`. Prima di `A12`, il controller puo' eseguire le query `M16` e `M17` per generi e film preferiti. Non esiste una transazione comune; un errore finale non annulla le preferenze gia' salvate.

## 7. Catalogo film, interazioni e raccomandazioni

### 7.1 Proiezione film condivisa

Le letture complete usano normalmente questa forma, poi `normalizeMovieRecord` converte i `neo4j.Integer` e applica i default:

```cypher
RETURN m.tmdbId AS tmdbId,
       m.title AS title,
       m.originalTitle AS originalTitle,
       m.overview AS overview,
       m.posterPath AS posterPath,
       m.backdropPath AS backdropPath,
       m.posterUrl AS posterUrl,
       m.backdropUrl AS backdropUrl,
       m.releaseDate AS releaseDate,
       m.runtime AS runtime,
       m.director AS director,
       m.voteAverage AS voteAverage,
       m.movieLensAvgRating AS movieLensAvgRating,
       m.movieLensRatingCount AS movieLensRatingCount,
       m.genres AS genres,
       m.tmdbHydrated AS tmdbHydrated
```

### M01 - upsert di un film TMDB

Funzione: `movieRepository.mergeTmdbMovie`. Chiamata da idratazione, interazioni e onboarding; usa `tx.run` se riceve una transazione.

```cypher
MERGE (m:Movie {tmdbId: $tmdbId})
SET m.title = coalesce($title, m.title),
    m.originalTitle = coalesce($originalTitle, m.originalTitle),
    m.overview = CASE
      WHEN $overview <> '' THEN $overview
      ELSE coalesce(m.overview, '')
    END,
    m.posterPath = coalesce($posterPath, m.posterPath),
    m.backdropPath = coalesce($backdropPath, m.backdropPath),
    m.posterUrl = CASE WHEN $posterUrl <> '' THEN $posterUrl ELSE coalesce(m.posterUrl, '') END,
    m.backdropUrl = CASE WHEN $backdropUrl <> '' THEN $backdropUrl ELSE coalesce(m.backdropUrl, '') END,
    m.releaseDate = CASE WHEN $releaseDate <> '' THEN $releaseDate ELSE coalesce(m.releaseDate, '') END,
    m.runtime = coalesce($runtime, m.runtime),
    m.director = CASE WHEN $director <> '' THEN $director ELSE coalesce(m.director, '') END,
    m.voteAverage = coalesce($voteAverage, m.voteAverage),
    m.movieLensAvgRating = coalesce($movieLensAvgRating, m.movieLensAvgRating),
    m.movieLensRatingCount = coalesce($movieLensRatingCount, m.movieLensRatingCount),
    m.genres = CASE WHEN size($genres) > 0 THEN $genres ELSE coalesce(m.genres, []) END,
    m.tmdbHydrated = coalesce(m.tmdbHydrated, false) OR $tmdbHydrated
FOREACH (genreName IN $genres |
  MERGE (g:Genre {name: genreName})
  MERGE (m)-[:IN_GENRE]->(g)
)
WITH m
OPTIONAL MATCH (m)-[stale:IN_GENRE]->(staleGenre:Genre)
FOREACH (relationship IN CASE
  WHEN size($genres) > 0 AND NOT staleGenre.name IN $genres THEN [stale]
  ELSE []
END | DELETE relationship)
```

Una lista generi vuota non cancella i generi esistenti. Una lista non vuota sincronizza le relazioni `IN_GENRE`.

### M02 - lettura batch per TMDB ID

```cypher
MATCH (m:Movie)
WHERE m.tmdbId IN $tmdbIds
RETURN <proiezione film condivisa>
ORDER BY m.tmdbId ASC
```

Funzione: `findMoviesByTmdbIds`. Serve cataloghi pubblici, mood search, For You, Daily e debug prima o dopo l'idratazione TMDB.

### M03 - lettura singolo film

```cypher
MATCH (m:Movie {tmdbId: $tmdbId})
RETURN <proiezione film condivisa>
LIMIT 1
```

Funzione: `findMovieByTmdbId`; route diretta `GET /movies/:tmdbId` e rilettura dopo like, dislike, watchlist o seen.

### M04 - aggiornamento runtime

```cypher
MATCH (m:Movie {tmdbId: $tmdbId})
SET m.runtime = $runtime
```

Funzione: `setMovieRuntime`. Il metodo restituisce `true` per input valido anche se nessun nodo viene aggiornato.

### 7.2 Write transaction delle interazioni

`likeMovie`, `dislikeMovie`, `watchlistMovie` e `markMovieAsSeen` convergono su `setMovieInteraction`. Nella stessa `executeWrite` vengono eseguite `M05-M06` quando e' presente un contesto di raccomandazione, oppure `M07` quando e' assente; seguono `M08`, `M01` e `M09`, mentre `M10` viene eseguita soltanto con contesto valido e `M09` riuscita. I tipi dinamici sono validati contro:

```text
LIKED, DISLIKED, WATCHLISTED, ALREADY_SEEN, SELECTED_FAVORITE
```

### M05 - verifica del contesto Daily

```cypher
MATCH (u:AppUser {uid: $uid})-[:REQUESTED_RECOMMENDATIONS]->
      (batch:RecommendationBatch {id: $batchId, kind: 'daily'})
WHERE batch.expiresAt > datetime()
MATCH (batch)-[included:INCLUDED]->(:Movie {tmdbId: $tmdbId})
RETURN included.swipedAt AS existingSwipe
```

Zero righe produce `InvalidRecommendationContextError` e HTTP 400.

### M06 - incremento atomico della quota

```cypher
MATCH (u:AppUser {uid: $uid})
MERGE (quota:DailySwipeQuota {key: $quotaKey})
ON CREATE SET quota.uid = $uid,
              quota.day = date($day),
              quota.used = 0,
              quota.createdAt = datetime()
MERGE (u)-[:HAS_DAILY_QUOTA]->(quota)
SET quota.used = coalesce(quota.used, 0) + $increment
RETURN quota.used AS usedToday
```

`quotaKey` e' `uid:YYYY-MM-DD` in UTC. `$increment` vale `0` se la stessa inclusione era gia' stata contata, altrimenti `1`. Il superamento del limite lancia `DailySwipeLimitError`; il rollback include l'incremento.

### M07 - ricerca di contesti Daily omessi

```cypher
MATCH (:AppUser {uid: $uid})-[:REQUESTED_RECOMMENDATIONS]->
      (batch:RecommendationBatch {kind: 'daily'})-[included:INCLUDED]->
      (:Movie {tmdbId: $tmdbId})
WHERE batch.expiresAt > datetime()
  AND included.swipedAt IS NULL
RETURN count(included) AS pendingContexts
```

Viene usata quando il client non invia `recommendationBatchId`, per impedire di aggirare quota e telemetria.

### M08 - rimozione degli stati incompatibili

```cypher
MATCH (u:AppUser {uid: $uid})
      -[old:LIKED|DISLIKED|WATCHLISTED|ALREADY_SEEN]->
      (m:Movie {tmdbId: $tmdbId})
DELETE old
```

Nel sorgente i tipi effettivi sono il sottoinsieme `${removeRels.join('|')}` validato dall'allowlist. La matrice e': like rimuove dislike; dislike rimuove like e watchlist; watchlist rimuove dislike e seen; seen rimuove watchlist.

### M09 - creazione dell'interazione

```cypher
MATCH (u:AppUser {uid: $uid})
MATCH (m:Movie {tmdbId: $tmdbId})
MERGE (u)-[r:<newRel-validata>]->(m)
ON CREATE SET r.createdAt = datetime()
RETURN m.tmdbId AS tmdbId
```

### M10 - registrazione dello swipe sul batch

```cypher
MATCH (:AppUser {uid: $uid})-[:REQUESTED_RECOMMENDATIONS]->
      (batch:RecommendationBatch {id: $batchId})
MATCH (batch)-[included:INCLUDED]->(:Movie {tmdbId: $tmdbId})
SET included.swipedAt = coalesce(included.swipedAt, datetime()),
    included.action = $action,
    included.clientSource = $source,
    included.clientPosition = $position
```

Il primo timestamp viene conservato; azione e metadati client possono essere aggiornati da una ripetizione.

### 7.3 Batch, impressioni e metriche

### M11 - retention per utente prima di un nuovo batch

```cypher
MATCH (batch:RecommendationBatch {uid: $uid})
WHERE batch.createdAt < datetime() - duration({days: 90})
DETACH DELETE batch
```

Funzione: `recordRecommendationBatch`. E' un auto-commit separato da `M12`.

### M12 - salvataggio del batch e delle inclusioni

```cypher
MATCH (u:AppUser {uid: $uid})
MATCH (movie:Movie)
WHERE movie.tmdbId IN [item IN $items | item.tmdbId]
WITH u, collect(movie) AS movies
WHERE size(movies) = size($items)
MERGE (batch:RecommendationBatch {id: $batchId})
ON CREATE SET batch.uid = $uid,
              batch.kind = $kind,
              batch.experimentVariant = $experimentVariant,
              batch.createdAt = datetime(),
              batch.expiresAt = datetime($expiresAt)
MERGE (u)-[:REQUESTED_RECOMMENDATIONS]->(batch)
WITH batch, movies
UNWIND $items AS item
WITH batch, item,
     head([movie IN movies WHERE movie.tmdbId = item.tmdbId]) AS movie
MERGE (batch)-[included:INCLUDED]->(movie)
ON CREATE SET included.servedAt = datetime()
SET included.position = item.position,
    included.source = item.source,
    included.finalScore = item.finalScore
RETURN count(included) AS includedCount
```

Parametri: `uid`, UUID del batch, `kind`, scadenza, variante A/B e lista `{tmdbId, position, source, finalScore}`. Il controllo `size` impedisce batch parziali. L'unicita' di `RecommendationBatch.id` e' garantita da `N10`.

### M13 - impressioni client

```cypher
MATCH (:AppUser {uid: $uid})-[:REQUESTED_RECOMMENDATIONS]->
      (batch:RecommendationBatch {id: $batchId})
WHERE batch.expiresAt > datetime()
UNWIND $items AS item
MATCH (batch)-[included:INCLUDED]->(:Movie {tmdbId: item.tmdbId})
WITH included, item, included.impressedAt IS NULL AS isNew
SET included.impressedAt = coalesce(included.impressedAt, datetime()),
    included.clientPosition = coalesce(item.position, included.clientPosition)
RETURN count(DISTINCT included) AS matchedCount,
       sum(CASE WHEN isNew THEN 1 ELSE 0 END) AS recordedCount
```

Funzione e route: `recordRecommendationImpressions`, `POST /me/recommendations/:batchId/impressions`. Le nuove impressioni invalidano la cache perche' alimentano la penalita' di esposizione.

### M14 - quota usata oggi

```cypher
MATCH (:AppUser {uid: $uid})
OPTIONAL MATCH (quota:DailySwipeQuota {key: $quotaKey})
RETURN coalesce(quota.used, 0) AS usedToday
```

Funzione: `getDailySwipeUsage`; route `GET /me/recommendations/daily-suggestions`.

### M15 - metriche per fonte e variante

```cypher
MATCH (u:AppUser {uid: $uid})-[:REQUESTED_RECOMMENDATIONS]->
      (batch:RecommendationBatch)-[included:INCLUDED]->(:Movie)
WHERE batch.createdAt >= datetime() - duration({days: $days})
WITH coalesce(included.source, 'unknown') AS source,
     coalesce(batch.experimentVariant, 'control-v1') AS experimentVariant,
     count(included) AS served,
     sum(CASE WHEN included.impressedAt IS NOT NULL THEN 1 ELSE 0 END) AS impressed,
     sum(CASE WHEN included.swipedAt IS NOT NULL THEN 1 ELSE 0 END) AS swiped,
     sum(CASE WHEN included.action = 'like' THEN 1 ELSE 0 END) AS liked,
     sum(CASE WHEN included.action = 'dislike' THEN 1 ELSE 0 END) AS disliked,
     sum(CASE WHEN included.action = 'watchlist' THEN 1 ELSE 0 END) AS watchlisted,
     sum(CASE WHEN included.action = 'seen' THEN 1 ELSE 0 END) AS seen
RETURN source, experimentVariant, served, impressed, swiped,
       liked, disliked, watchlisted, seen
ORDER BY served DESC
```

Funzione: `getRecommendationMetrics`; route `/me/recommendations/metrics` e `/me/recommendations/debug-stats`. Il tasso `swiped / served` e' calcolato in JavaScript. Le route sono attive solo con `ENABLE_RECOMMENDATION_DEBUG=true`.

### 7.4 Onboarding e libreria

### M16 - film preferiti selezionati

```cypher
MATCH (u:AppUser {uid: $uid})
UNWIND $tmdbIds AS tmdbId
MATCH (m:Movie {tmdbId: tmdbId})
MERGE (u)-[r:SELECTED_FAVORITE]->(m)
ON CREATE SET r.createdAt = datetime()
SET r.weight = $weight
WITH count(DISTINCT m) AS selectedCount
RETURN selectedCount
```

Funzione: `saveSelectedFavorites`; route `PATCH /me/onboarding`; peso corrente `4.0`. Prima della query ogni film viene upsertato con `M01`, fuori da una transazione comune. La semantica e' additiva: non rimuove preferiti precedenti.

### M17 - sostituzione dei generi preferiti

```cypher
MATCH (u:AppUser {uid: $uid})
OPTIONAL MATCH (u)-[stale:PREFERS_GENRE]->(g:Genre)
WHERE NOT g.name IN $genres
DELETE stale
WITH DISTINCT u
UNWIND $genres AS genreName
MERGE (g:Genre {name: genreName})
MERGE (u)-[r:PREFERS_GENRE]->(g)
ON CREATE SET r.createdAt = datetime()
WITH count(DISTINCT g) AS preferredGenreCount
RETURN preferredGenreCount
```

Funzione: `savePreferredGenres`; route `PATCH /me/onboarding`. Con `$genres=[]`, le vecchie relazioni vengono eliminate ma `UNWIND []` sopprime la riga di ritorno: il metodo puo' segnalare `saved=false` dopo una modifica effettiva.

### M18-M21 - rimozione delle interazioni

```cypher
// M18 removeFromWatchlist
MATCH (:AppUser {uid: $uid})-[r:WATCHLISTED]->(:Movie {tmdbId: $tmdbId})
DELETE r

// M19 removeLike
MATCH (:AppUser {uid: $uid})-[r:LIKED]->(:Movie {tmdbId: $tmdbId})
DELETE r

// M20 removeDislike
MATCH (:AppUser {uid: $uid})-[r:DISLIKED]->(:Movie {tmdbId: $tmdbId})
DELETE r

// M21 removeSeen
MATCH (:AppUser {uid: $uid})-[r:ALREADY_SEEN]->(:Movie {tmdbId: $tmdbId})
DELETE r
```

Route: i quattro `DELETE /me/movies/:tmdbId/...`. Non restituiscono il numero cancellato; la cache viene invalidata anche quando la relazione non esiste.

### M22 - libreria completa

```cypher
MATCH (u:AppUser {uid: $uid})
CALL {
  WITH u
  MATCH (u)-[r:LIKED]->(m:Movie)
  RETURN collect({
    tmdbId: m.tmdbId, title: m.title, originalTitle: m.originalTitle,
    overview: m.overview, posterPath: m.posterPath,
    backdropPath: m.backdropPath, runtime: m.runtime,
    posterUrl: m.posterUrl, backdropUrl: m.backdropUrl,
    releaseDate: m.releaseDate, voteAverage: m.voteAverage,
    movieLensAvgRating: m.movieLensAvgRating,
    movieLensRatingCount: m.movieLensRatingCount,
    genres: coalesce(m.genres, []),
    tmdbHydrated: coalesce(m.tmdbHydrated, false),
    createdAt: toString(r.createdAt)
  }) AS liked
}
CALL {
  WITH u
  MATCH (u)-[r:DISLIKED]->(m:Movie)
  RETURN collect({/* stessi campi */ createdAt: toString(r.createdAt)}) AS disliked
}
CALL {
  WITH u
  MATCH (u)-[r:WATCHLISTED]->(m:Movie)
  RETURN collect({/* stessi campi */ createdAt: toString(r.createdAt)}) AS watchlist
}
CALL {
  WITH u
  MATCH (u)-[r:ALREADY_SEEN]->(m:Movie)
  RETURN collect({/* stessi campi */ createdAt: toString(r.createdAt)}) AS alreadySeen
}
RETURN liked, disliked, watchlist, alreadySeen
```

Funzione e route: `getUserLibrary`, `GET /me/library`. Le quattro liste non hanno un `ORDER BY`, quindi l'ordine non e' garantito. `director` non e' incluso nella mappa.

### 7.5 Motore personalizzato

### M23 - collaborative filtering pesato

Funzione: `getPersonalizedRecommendationCandidates`. E' la query principale della sorgente collaborativa.

```cypher
MATCH (me:AppUser {uid: $uid})
CALL {
  WITH me
  OPTIONAL MATCH
    (me)-[r:LIKED|DISLIKED|SELECTED_FAVORITE|WATCHLISTED]->(m:Movie)
  OPTIONAL MATCH
    (m)<-[:MATCHES_TMDB]-(mMl:MovieLensMovie)-[:IN_GENRE]->(mlGenre:Genre)
  OPTIONAL MATCH (m)-[:IN_GENRE]->(movieGenre:Genre)
  WITH r, reduce(
    uniqueGenres = [],
    genreName IN collect(DISTINCT mlGenre.name) + collect(DISTINCT movieGenre.name) |
    CASE
      WHEN genreName IS NULL OR genreName IN uniqueGenres THEN uniqueGenres
      ELSE uniqueGenres + genreName
    END
  ) AS genreNames
  UNWIND genreNames AS genreName
  WITH genreName,
       sum(CASE WHEN type(r) = 'DISLIKED' THEN 1 ELSE 0 END) AS dislikedCount,
       count(r) AS totalInteractions
  RETURN [g IN collect({
    name: genreName,
    count: dislikedCount,
    total: totalInteractions
  }) WHERE g.name IS NOT NULL AND g.count >= $dislikedGenreThreshold]
  AS dislikedGenres
}
MATCH (me)-[signal:LIKED|SELECTED_FAVORITE|WATCHLISTED]->(seed:Movie)
MATCH (seed)<-[:MATCHES_TMDB]-(seedMl:MovieLensMovie)
      <-[r1:RATED]-(similar:MovieLensUser)
WHERE r1.rating >= 4.0
WITH me, dislikedGenres, similar,
     count(DISTINCT seed) AS overlapCount,
     sum(
       CASE type(signal)
         WHEN 'SELECTED_FAVORITE' THEN coalesce(signal.weight, $selectedFavoriteWeight)
         WHEN 'LIKED' THEN $likedWeight
         WHEN 'WATCHLISTED' THEN $watchlistedWeight
         ELSE 1.0
       END
       * exp(-0.005 * duration.inDays(
           coalesce(signal.createdAt, signal.updatedAt, datetime()), datetime()
         ).days)
       * (toFloat(r1.rating) - 3.0)
       * (1.0 / sqrt(log(toFloat(coalesce(
           seed.movieLensRatingCount, seedMl.movieLensRatingCount, 0
         )) + 10.0)))
     ) AS similarityScore
WHERE similarityScore > 0
ORDER BY similarityScore DESC
LIMIT toInteger($neighborLimit)
MATCH (similar)-[r2:RATED]->(recMl:MovieLensMovie)
      -[:MATCHES_TMDB]->(rec:Movie)
WHERE rec.tmdbId IS NOT NULL
  AND NOT (me)-[:LIKED|DISLIKED|WATCHLISTED|ALREADY_SEEN|SELECTED_FAVORITE]->(rec)
WITH rec,
     similar,
     avg(toFloat(r2.rating)) AS similarRating,
     max(similarityScore) AS similarityScore,
     max(overlapCount) AS overlapCount,
     dislikedGenres
OPTIONAL MATCH (rec)<-[:MATCHES_TMDB]-
               (candidateMl:MovieLensMovie)-[:IN_GENRE]->(recMlGenre:Genre)
OPTIONAL MATCH (rec)-[:IN_GENRE]->(recMovieGenre:Genre)
WITH rec, similar, similarRating, similarityScore, overlapCount,
     dislikedGenres,
     collect(DISTINCT recMlGenre.name)
       + collect(DISTINCT recMovieGenre.name) AS candidateGenreNames
WITH rec, similar, similarRating, similarityScore, overlapCount,
     [entry IN coalesce(dislikedGenres, [])
      WHERE entry.name IN candidateGenreNames | entry] AS matchingDislikedGenres
WITH rec, similar, similarRating, similarityScore, overlapCount,
     reduce(penalty = 0.0, entry IN matchingDislikedGenres |
       penalty + ($dislikedGenrePenalty * toFloat(entry.count)
         * (toFloat(entry.count) / toFloat(entry.total)))) AS negativePenalty
WITH rec,
     count(DISTINCT similar) AS similarUsers,
     avg(similarRating) AS avgSimilarRating,
     avg(overlapCount) AS avgOverlapCount,
     sum(similarityScore * (similarRating - 3.0)) /
       coalesce(sum(abs(similarityScore)), 1.0) AS weightedPreference,
     max(negativePenalty) AS negativePenalty
WITH rec, similarUsers, avgSimilarRating, avgOverlapCount, negativePenalty,
     toFloat(similarUsers) /
       (toFloat(similarUsers) + $supportShrinkage) AS supportWeight,
     weightedPreference
WITH rec, similarUsers, avgSimilarRating, avgOverlapCount, negativePenalty,
     (
       weightedPreference * supportWeight
       + (toFloat(coalesce(rec.movieLensAvgRating, $globalMeanRating)) - 3.0)
         * (1.0 - supportWeight)
     ) * log(similarUsers + 1.0) * 10.0 AS collaborativeScore
WITH rec, similarUsers, avgSimilarRating, avgOverlapCount,
     negativePenalty, collaborativeScore,
     collaborativeScore - negativePenalty AS finalScore
WHERE finalScore > 0
RETURN rec.tmdbId AS tmdbId,
       rec.title AS title,
       similarUsers,
       avgSimilarRating,
       collaborativeScore,
       0.0 AS genreScore,
       log(coalesce(rec.movieLensRatingCount, 0) + 1) AS popularityScore,
       avgOverlapCount,
       negativePenalty,
       0.0 AS explorationBonus,
       finalScore,
       rec.movieLensAvgRating AS globalAvg,
       rec.movieLensRatingCount AS ratingCount,
       'personalized' AS source
ORDER BY finalScore DESC, collaborativeScore DESC,
         similarUsers DESC, avgSimilarRating DESC, ratingCount DESC
LIMIT 80
```

Pesi correnti: favorite `4`, like `3`, watchlist `1.25`; rating MovieLens centrati su `3`; decay temporale esponenziale; attenuazione dei seed popolari; shrinkage verso la media globale; penalita' per generi ripetutamente disliked.

### M24 - estrazione del profilo semantico

```cypher
MATCH (u:AppUser {uid: $uid})
      -[r:LIKED|SELECTED_FAVORITE|WATCHLISTED|DISLIKED]->(m:Movie)
MATCH (m)<-[:MATCHES_TMDB]-(ml:MovieLensMovie)-[h:HAS_TAG]->(t:Tag)
WHERE t.embedding IS NOT NULL
RETURN t.embedding AS embedding,
       type(r) AS relType,
       coalesce(h.frequency, 1) AS frequency,
       coalesce(t.idf, 1.0) AS idf
```

Funzione: `getSemanticTagRecommendationCandidates`. JavaScript costruisce centroidi positivi e negativi normalizzati, usando favorite `4`, like `3`, watchlist `1.5`, dislike `3` e il peso `log1p(frequency) * idf`.

### M25 - vector search dei film

```cypher
CALL db.index.vector.queryNodes(
  'tag_embeddings', toInteger($topK), $positiveTasteVector
)
YIELD node AS tagNode, score AS similarity
MATCH (tagNode)<-[h:HAS_TAG]-(ml:MovieLensMovie)-[:MATCHES_TMDB]->(m:Movie)
MATCH (me:AppUser {uid: $uid})
WHERE NOT (me)-[:LIKED|DISLIKED|WATCHLISTED|ALREADY_SEEN|SELECTED_FAVORITE]->(m)
WITH ml, m,
     tagNode.name AS tag,
     h.frequency AS tagFrequency,
     coalesce(tagNode.idf, 1.0) AS tagIdf,
     2.0 * similarity - 1.0 AS positiveSimilarity,
     CASE WHEN $hasNegativeTaste
       THEN 2.0 * vector.similarity.cosine(
         tagNode.embedding, $negativeTasteVector
       ) - 1.0
       ELSE 0.0
     END AS negativeSimilarity
WHERE positiveSimilarity >= $similarityThreshold
WITH ml, m,
     sum(tagIdf * log(toFloat(tagFrequency) + 1.0)
         * positiveSimilarity ^ 3) AS positiveRawScore,
     sum(tagIdf * log(toFloat(tagFrequency) + 1.0)
         * CASE WHEN negativeSimilarity > 0
           THEN negativeSimilarity ^ 3 ELSE 0.0 END) AS negativeRawScore,
     collect({
       tag: tag,
       frequency: tagFrequency,
       similarity: positiveSimilarity
     }) AS matchedTags
WITH m,
     sum((positiveRawScore - $negativeTastePenalty * negativeRawScore)
         / sqrt(toFloat(coalesce(ml.totalTagCount, 1.0)))) AS tagRelevanceScore,
     sum(negativeRawScore) AS negativeTagPenalty,
     reduce(tags = [], entries IN collect(matchedTags) | tags + entries) AS matchedTags
WHERE tagRelevanceScore > 0
RETURN m.tmdbId AS tmdbId,
       m.title AS title,
       tagRelevanceScore,
       negativeTagPenalty,
       matchedTags,
       m.movieLensAvgRating AS globalAvg,
       m.movieLensRatingCount AS ratingCount
ORDER BY tagRelevanceScore DESC, globalAvg DESC, ratingCount DESC
LIMIT toInteger($limit)
```

La trasformazione `2 * score - 1` converte lo score Neo4j nella scala usata dall'app. Lo score cubico premia match forti; `sqrt(totalTagCount)` limita il vantaggio dei film con molti tag.

### M26 - esposizioni senza azione

```cypher
MATCH (:AppUser {uid: $uid})-[:REQUESTED_RECOMMENDATIONS]->
      (batch:RecommendationBatch)-[included:INCLUDED]->(movie:Movie)
WHERE batch.createdAt >= datetime() - duration({days: 30})
  AND included.impressedAt IS NOT NULL
  AND included.swipedAt IS NULL
RETURN movie.tmdbId AS tmdbId,
       count(included) AS exposureCount
```

Helper interno: `getUnactedRecommendationExposures`. Nel rank fusion, lo score viene diviso per `1 + 0.15 * exposureCount`.

### M27 - candidati esplorativi Daily

```cypher
MATCH (me:AppUser {uid: $uid})
CALL {
  WITH me
  OPTIONAL MATCH (me)-[:PREFERS_GENRE]->(preferred:Genre)
  RETURN collect(DISTINCT preferred.name) AS preferredGenres
}
CALL {
  WITH me
  OPTIONAL MATCH (me)-[:LIKED|SELECTED_FAVORITE|WATCHLISTED]->(positiveMovie:Movie)
  OPTIONAL MATCH (positiveMovie)<-[:MATCHES_TMDB]-(:MovieLensMovie)-[:IN_GENRE]->(mlGenre:Genre)
  OPTIONAL MATCH (positiveMovie)-[:IN_GENRE]->(directGenre:Genre)
  RETURN [g IN collect(DISTINCT mlGenre.name) + collect(DISTINCT directGenre.name)
          WHERE g IS NOT NULL] AS positiveGenres
}
CALL {
  WITH me
  OPTIONAL MATCH (me)-[:DISLIKED]->(negativeMovie:Movie)
  OPTIONAL MATCH (negativeMovie)<-[:MATCHES_TMDB]-(:MovieLensMovie)-[:IN_GENRE]->(mlGenre:Genre)
  OPTIONAL MATCH (negativeMovie)-[:IN_GENRE]->(directGenre:Genre)
  RETURN [g IN collect(DISTINCT mlGenre.name) + collect(DISTINCT directGenre.name)
          WHERE g IS NOT NULL] AS negativeGenres
}
MATCH (m:Movie)
WHERE m.movieLensRatingCount >= $minRatingCount
  AND m.tmdbId IS NOT NULL
  AND NOT (me)-[:LIKED|DISLIKED|WATCHLISTED|ALREADY_SEEN|SELECTED_FAVORITE]->(m)
  AND NOT m.tmdbId IN $excludedTmdbIds
OPTIONAL MATCH (m)<-[:MATCHES_TMDB]-(:MovieLensMovie)-[:IN_GENRE]->(mlGenre:Genre)
OPTIONAL MATCH (m)-[:IN_GENRE]->(directGenre:Genre)
WITH m, preferredGenres, positiveGenres, negativeGenres,
     reduce(
       uniqueGenres = [],
       genre IN collect(DISTINCT mlGenre.name) + collect(DISTINCT directGenre.name) |
       CASE
         WHEN genre IS NULL OR genre IN uniqueGenres THEN uniqueGenres
         ELSE uniqueGenres + genre
       END
     ) AS candidateGenres,
     toFloat(coalesce(m.movieLensRatingCount, 0)) AS ratingCount,
     toFloat(coalesce(m.movieLensAvgRating, $globalMeanRating)) AS avgRating
WITH m, ratingCount, avgRating,
     size([g IN candidateGenres WHERE g IN preferredGenres OR g IN positiveGenres]) AS familiarGenres,
     size([g IN candidateGenres WHERE
       NOT g IN preferredGenres AND NOT g IN positiveGenres AND NOT g IN negativeGenres
     ]) AS exploratoryGenres,
     size([g IN candidateGenres WHERE g IN negativeGenres]) AS matchedNegativeGenres
RETURN m.tmdbId AS tmdbId,
       m.title AS title,
       0 AS similarUsers,
       null AS avgSimilarRating,
       0.0 AS collaborativeScore,
       familiarGenres * 15.0 AS genreScore,
       avgRating * 10.0 + log(ratingCount + 1.0) AS popularityScore,
       matchedNegativeGenres * 25.0 AS negativePenalty,
       exploratoryGenres * 40.0 AS explorationBonus,
       familiarGenres * 15.0
         + avgRating * 10.0
         + log(ratingCount + 1.0)
         + exploratoryGenres * 40.0
         - matchedNegativeGenres * 25.0 AS finalScore,
       m.movieLensAvgRating AS globalAvg,
       m.movieLensRatingCount AS ratingCount,
       'exploratory' AS source,
       CASE
         WHEN exploratoryGenres > 0
           THEN 'Explores genres outside your strongest current bubble.'
         ELSE 'Popular unseen title kept to test uncertain taste edges.'
       END AS reason
ORDER BY finalScore DESC, explorationBonus DESC, ratingCount DESC
LIMIT toInteger($limit)
```

Questa query bilancia familiarita', novita', popolarita' e segnali negativi. Il filtro diretto su `movieLensRatingCount` puo' usare `N15`.

### 7.6 Query diagnostiche del motore

### M28 - profilo quantitativo

```cypher
MATCH (me:AppUser {uid: $uid})
CALL { WITH me OPTIONAL MATCH (me)-[:PREFERS_GENRE]->(g:Genre)
       RETURN collect(DISTINCT g.name) AS onboardingGenres }
CALL { WITH me OPTIONAL MATCH (me)-[:SELECTED_FAVORITE]->(m:Movie)
       RETURN count(DISTINCT m) AS favoriteMoviesCount }
CALL { WITH me OPTIONAL MATCH (me)-[:LIKED]->(m:Movie)
       RETURN count(DISTINCT m) AS likedMoviesCount }
CALL { WITH me OPTIONAL MATCH (me)-[:DISLIKED]->(m:Movie)
       RETURN count(DISTINCT m) AS dislikedMoviesCount }
CALL { WITH me OPTIONAL MATCH (me)-[:ALREADY_SEEN]->(m:Movie)
       RETURN count(DISTINCT m) AS alreadySeenCount }
CALL { WITH me OPTIONAL MATCH (me)-[:WATCHLISTED]->(m:Movie)
       RETURN count(DISTINCT m) AS watchlistCount }
RETURN me.uid AS uid, onboardingGenres, favoriteMoviesCount,
       likedMoviesCount, dislikedMoviesCount, alreadySeenCount, watchlistCount
LIMIT 1
```

### M29 - generi positivi

```cypher
MATCH (me:AppUser {uid: $uid})
      -[signal:LIKED|SELECTED_FAVORITE|WATCHLISTED]->(movie:Movie)
OPTIONAL MATCH (movie)<-[:MATCHES_TMDB]-(:MovieLensMovie)-[:IN_GENRE]->(mlGenre:Genre)
OPTIONAL MATCH (movie)-[:IN_GENRE]->(directGenre:Genre)
WITH signal,
     [g IN collect(DISTINCT mlGenre.name) + collect(DISTINCT directGenre.name)
      WHERE g IS NOT NULL] AS genreNames
UNWIND genreNames AS genreName
WITH genreName, CASE type(signal)
  WHEN 'SELECTED_FAVORITE' THEN coalesce(signal.weight, 4)
  WHEN 'LIKED' THEN 3
  WHEN 'WATCHLISTED' THEN 1.25
  ELSE 1 END AS signalWeight
RETURN genreName AS name, sum(signalWeight) AS score
ORDER BY score DESC, name ASC
LIMIT toInteger($limit)
```

### M30 - generi negativi

```cypher
MATCH (me:AppUser {uid: $uid})-[:DISLIKED]->(movie:Movie)
OPTIONAL MATCH (movie)<-[:MATCHES_TMDB]-(:MovieLensMovie)-[:IN_GENRE]->(mlGenre:Genre)
OPTIONAL MATCH (movie)-[:IN_GENRE]->(directGenre:Genre)
WITH movie,
     [g IN collect(DISTINCT mlGenre.name) + collect(DISTINCT directGenre.name)
      WHERE g IS NOT NULL] AS genreNames
UNWIND genreNames AS genreName
RETURN genreName AS name, count(*) AS score
ORDER BY score DESC, name ASC
LIMIT toInteger($limit)
```

### M31 - film positivi

```cypher
MATCH (me:AppUser {uid: $uid})
      -[signal:LIKED|SELECTED_FAVORITE|WATCHLISTED]->(movie:Movie)
RETURN movie.tmdbId AS tmdbId,
       movie.title AS title,
       type(signal) AS signalType,
       CASE type(signal)
         WHEN 'SELECTED_FAVORITE' THEN coalesce(signal.weight, 4)
         WHEN 'LIKED' THEN 3
         WHEN 'WATCHLISTED' THEN 1.25
         ELSE 1
       END AS score
ORDER BY score DESC, movie.title ASC
LIMIT toInteger($limit)
```

### M32 - film negativi

```cypher
MATCH (me:AppUser {uid: $uid})-[signal:DISLIKED]->(movie:Movie)
RETURN movie.tmdbId AS tmdbId,
       movie.title AS title,
       type(signal) AS signalType,
       1.0 AS score
ORDER BY movie.title ASC
LIMIT toInteger($limit)
```

### M33 - tag positivi

```cypher
MATCH (me:AppUser {uid: $uid})
      -[signal:LIKED|SELECTED_FAVORITE|WATCHLISTED]->(movie:Movie)
MATCH (movie)<-[:MATCHES_TMDB]-(ml:MovieLensMovie)-[h:HAS_TAG]->(t:Tag)
WITH t.name AS name,
     CASE type(signal)
       WHEN 'SELECTED_FAVORITE' THEN coalesce(signal.weight, 4)
       WHEN 'LIKED' THEN 3
       WHEN 'WATCHLISTED' THEN 1.5
       ELSE 1
     END * coalesce(h.frequency, 1) AS tagWeight
RETURN name, sum(tagWeight) AS score
ORDER BY score DESC, name ASC
LIMIT toInteger($limit)
```

### M34 - tag negativi

```cypher
MATCH (me:AppUser {uid: $uid})-[signal:DISLIKED]->(movie:Movie)
MATCH (movie)<-[:MATCHES_TMDB]-(ml:MovieLensMovie)-[h:HAS_TAG]->(t:Tag)
WITH t.name AS name, 3.0 * coalesce(h.frequency, 1) AS tagWeight
RETURN name, sum(tagWeight) AS score
ORDER BY score DESC, name ASC
LIMIT toInteger($limit)
```

### M35 - statistiche del pool

```cypher
MATCH (me:AppUser {uid: $uid})
OPTIONAL MATCH
  (me)-[r:ALREADY_SEEN|DISLIKED|LIKED|WATCHLISTED|SELECTED_FAVORITE]->(m:Movie)
WHERE m.tmdbId IS NOT NULL
WITH m,
     max(CASE WHEN type(r) = 'ALREADY_SEEN' THEN 1 ELSE 0 END) AS seen,
     max(CASE WHEN type(r) = 'DISLIKED' THEN 1 ELSE 0 END) AS disliked,
     max(CASE WHEN type(r) IN ['LIKED','WATCHLISTED','SELECTED_FAVORITE']
              THEN 1 ELSE 0 END) AS swiped
WITH sum(CASE WHEN m IS NOT NULL AND seen = 1 THEN 1 ELSE 0 END) AS filteredAlreadySeen,
     sum(CASE WHEN m IS NOT NULL AND seen = 0 AND disliked = 1 THEN 1 ELSE 0 END) AS filteredDisliked,
     sum(CASE WHEN m IS NOT NULL AND seen = 0 AND disliked = 0 AND swiped = 1
              THEN 1 ELSE 0 END) AS filteredAlreadySwiped
CALL {
  MATCH (cand:Movie)
  WHERE cand.tmdbId IS NOT NULL
  RETURN count(cand) AS totalCandidatesConsidered
}
RETURN totalCandidatesConsidered,
       filteredAlreadySeen,
       filteredDisliked,
       filteredAlreadySwiped,
       totalCandidatesConsidered - filteredAlreadySeen
         - filteredDisliked - filteredAlreadySwiped AS remainingAfterFiltering
```

`totalCandidatesConsidered` e' una stima diagnostica del catalogo, non il pool esatto del collaborativo o del semantico.

### M36 - mood search per tag espliciti

```cypher
MATCH (ml:MovieLensMovie)-[:MATCHES_TMDB]->(m:Movie)
MATCH (ml)-[h:HAS_TAG]->(t:Tag)
WHERE t.name IN $tags
WITH ml, m, t.name AS tag, h.frequency AS tagFrequency
WITH ml, m,
     sum(tagFrequency * (toFloat($tagWeights[tag]) ^ 3)) AS rawScore,
     collect({tag: tag, frequency: tagFrequency}) AS matchedTags
WITH m,
     rawScore / sqrt(toFloat(coalesce(ml.totalTagCount, 1))) AS tagRelevanceScore,
     matchedTags
WHERE tagRelevanceScore > 0
OPTIONAL MATCH (me:AppUser {uid: $uid})
WITH m, tagRelevanceScore, matchedTags, me
WHERE me IS NULL
   OR NOT (me)-[:LIKED|DISLIKED|WATCHLISTED|ALREADY_SEEN|SELECTED_FAVORITE]->(m)
RETURN <proiezione film condivisa>,
       tagRelevanceScore,
       matchedTags
ORDER BY tagRelevanceScore DESC,
         m.movieLensAvgRating DESC,
         m.movieLensRatingCount DESC
LIMIT 30
```

Funzione e route: `findMoviesBySemanticTags`, `GET /movies/mood-search`. `$tagWeights[tag]` legge una mappa parametrizzata, non interpola testo Cypher. Piu' nodi MovieLens collegati allo stesso film possono produrre duplicati per TMDB ID.

### 7.7 Fusione, cache e route

`computeRecommendationCandidates` lancia in parallelo `M23`, `M24-M25` e `M26`. Il codice fonde collaborativo e semantico con Reciprocal Rank Fusion:

```text
collaborativo = 1 / (K + rank)
semantico     = semanticWeight / (K + rank)
score         = somma dei contributi / (1 + 0.15 * esposizioni ignorate)
finalScore    = score * 1000
```

La cache e' in memoria, per UID, con TTL configurabile e deduplicazione delle computazioni in-flight. Viene invalidata da interazioni, rimozioni, nuove impressioni e salvataggi onboarding riusciti. Un calcolo gia' in flight non viene cancellato e puo' ripopolare la cache dopo un'invalidazione.

| Route | Funzioni/query Neo4j principali |
|---|---|
| `GET /movies/popular`, `/random`, `/recommendations`, `/daily-suggestions`, `/search` | `M02`, eventualmente `M04`; sono feed TMDB pubblici, non il motore personalizzato |
| `GET /movies/:tmdbId` | `M03`, eventualmente `M04` |
| `GET /movies/mood-search` | `E02`, `M36`, `M02`, eventuale `M01` |
| `POST /me/movies/:tmdbId/{like,dislike,watchlist,seen}` | `M04`; `M05-M06` oppure `M07`; `M08`, `M01`, `M09`; `M10` solo con contesto; infine `M03` |
| `DELETE /me/movies/:tmdbId/...` | `M18-M21` |
| `GET /me/library` | `M22`, eventuali `M01` |
| `GET /me/recommendations`, `/for-you` | `M23-M26`, `M02`, eventuali `M01` |
| `GET /me/recommendations/daily-suggestions` | `M14`, `M23-M27`, `M02`, eventuale `M01`, `M11-M12` |
| `POST /me/recommendations/:batchId/impressions` | `M13` |
| `GET /me/recommendations/metrics` | `M15` |
| `GET /me/recommendations/debug-stats` | `M15`, `M23-M35` e idratazione |

## 8. Catalogo social, Movie Night e notifiche

`socialRepository.js` contiene 51 statement Cypher in 39 funzioni. Tutti i valori applicativi sono parametri. Le sole interpolazioni testuali sono il frammento di proiezione `movieMapCypher('m')` e il tipo relazione in `loadFriendMovies`, limitato a `ALREADY_SEEN` o `WATCHLISTED`.

La proiezione film social, indicata di seguito come `<MOVIE_MAP(m)>`, e':

```cypher
{
  tmdbId: m.tmdbId,
  title: coalesce(m.title, ''),
  originalTitle: coalesce(m.originalTitle, m.title, ''),
  overview: coalesce(m.overview, ''),
  posterPath: m.posterPath,
  backdropPath: m.backdropPath,
  posterUrl: coalesce(m.posterUrl, ''),
  backdropUrl: coalesce(m.backdropUrl, ''),
  releaseDate: coalesce(m.releaseDate, ''),
  runtime: coalesce(m.runtime, 0),
  voteAverage: coalesce(m.voteAverage, m.movieLensAvgRating * 2.0, 0.0),
  genres: coalesce(m.genres, []),
  movieLensAvgRating: m.movieLensAvgRating,
  movieLensRatingCount: coalesce(m.movieLensRatingCount, 0),
  tmdbHydrated: coalesce(m.tmdbHydrated, false)
}
```

### 8.1 Amicizie, blocchi e profili

### S01 - elenco amici

```cypher
MATCH (me:AppUser {uid: $uid})-[:FRIEND]-(friend:AppUser)
WHERE NOT (me)-[:BLOCKED]->(friend)
  AND NOT (friend)-[:BLOCKED]->(me)
WITH DISTINCT friend
OPTIONAL MATCH (friend)-[:ALREADY_SEEN]->(watched:Movie)
OPTIONAL MATCH (friend)-[:RATED_APP]->(reviewed:Movie)
WITH friend,
     count(DISTINCT watched) AS watchedCount,
     count(DISTINCT reviewed) AS reviewsCount
RETURN {
  id: friend.uid,
  name: coalesce(friend.displayName, friend.email, 'Agreeo user'),
  avatarUrl: coalesce(friend.avatarUrl, ''),
  bio: coalesce(friend.bio, ''),
  watchedCount: watchedCount,
  reviewsCount: reviewsCount,
  privacySettings: {
    canShowWatched: coalesce(friend.canShowWatched, true),
    canShowReviews: coalesce(friend.canShowReviews, true),
    canShowWatchlist: coalesce(friend.canShowWatchlist, false)
  }
} AS friend
ORDER BY toLower(coalesce(friend.displayName, friend.email, '')) ASC
```

Funzione: `getFriends`; route `GET /friends`. I `DISTINCT` evitano conteggi gonfiati dal prodotto degli `OPTIONAL MATCH`.

### S02 - richieste ricevute

```cypher
MATCH (me:AppUser {uid: $uid})
MATCH (from:AppUser)-[r:SENT_FRIEND_REQUEST {status: 'pending'}]->(me)
OPTIONAL MATCH (from)-[:ALREADY_SEEN]->(watched:Movie)
OPTIONAL MATCH (from)-[:RATED_APP]->(reviewed:Movie)
WITH r, me, from,
     count(DISTINCT watched) AS watchedCount,
     count(DISTINCT reviewed) AS reviewsCount
RETURN {
  id: r.requestId,
  status: coalesce(r.status, 'pending'),
  createdAt: toString(r.createdAt),
  toUserId: me.uid,
  fromUser: {
    id: from.uid,
    name: coalesce(from.displayName, from.email, 'Agreeo user'),
    avatarUrl: coalesce(from.avatarUrl, ''),
    bio: coalesce(from.bio, ''),
    watchedCount: watchedCount,
    reviewsCount: reviewsCount,
    privacySettings: {
      canShowWatched: coalesce(from.canShowWatched, true),
      canShowReviews: coalesce(from.canShowReviews, true),
      canShowWatchlist: coalesce(from.canShowWatchlist, false)
    }
  }
} AS request
ORDER BY r.createdAt DESC
```

Seconda query di `getFriends`; non filtra esplicitamente utenti bloccati.

### S03 - ricerca utenti

```cypher
MATCH (me:AppUser {uid: $uid})
MATCH (candidate:AppUser)
WITH me, candidate,
     toLower(coalesce(candidate.displayName, candidate.email, '')) AS rawSearchText
WITH me, candidate,
     reduce(s = rawSearchText, pair IN $accentMap |
       replace(s, pair[0], pair[1])) AS searchText
WHERE candidate.uid <> me.uid
  AND NOT (me)-[:BLOCKED]->(candidate)
  AND NOT (candidate)-[:BLOCKED]->(me)
  AND (size($tokens) = 0 OR
       all(token IN $tokens WHERE
         any(word IN split(searchText, ' ') WHERE word STARTS WITH token)))
OPTIONAL MATCH (me)-[friendRel:FRIEND]-(candidate)
OPTIONAL MATCH (me)-[pending:SENT_FRIEND_REQUEST {status: 'pending'}]->(candidate)
OPTIONAL MATCH (candidate)-[incoming:SENT_FRIEND_REQUEST {status: 'pending'}]->(me)
OPTIONAL MATCH (candidate)-[:ALREADY_SEEN]->(watched:Movie)
OPTIONAL MATCH (candidate)-[:RATED_APP]->(reviewed:Movie)
WITH candidate, searchText,
     count(DISTINCT friendRel) AS friendCount,
     count(DISTINCT pending) AS pendingCount,
     count(DISTINCT incoming) AS incomingCount,
     head(collect(DISTINCT incoming.requestId)) AS incomingRequestId,
     count(DISTINCT watched) AS watchedCount,
     count(DISTINCT reviewed) AS reviewsCount
RETURN {
  id: candidate.uid,
  name: coalesce(candidate.displayName, candidate.email, 'Agreeo user'),
  avatarUrl: coalesce(candidate.avatarUrl, ''),
  bio: coalesce(candidate.bio, ''),
  watchedCount: watchedCount,
  reviewsCount: reviewsCount,
  isFriend: friendCount > 0,
  pending: pendingCount > 0,
  incomingPending: incomingCount > 0,
  incomingRequestId: incomingRequestId,
  privacySettings: {
    canShowWatched: coalesce(candidate.canShowWatched, true),
    canShowReviews: coalesce(candidate.canShowReviews, true),
    canShowWatchlist: coalesce(candidate.canShowWatchlist, false)
  }
} AS friend
ORDER BY CASE
    WHEN size($tokens) = 0 THEN 0
    WHEN searchText = $normalized THEN 0
    WHEN searchText STARTS WITH $normalized THEN 1
    WHEN any(word IN split(searchText, ' ')
             WHERE word STARTS WITH $firstToken) THEN 2
    ELSE 3
  END,
  toLower(coalesce(candidate.displayName, candidate.email, ''))
LIMIT 25
```

Funzione e route: `searchFriends`, `GET /friends/search`. `$accentMap` normalizza gli accenti elencati e soltanto `.`, `-`, `_`, apostrofo semplice e backtick; altra punteggiatura puo' produrre un testo diverso dalla normalizzazione JavaScript. Una query vuota restituisce fino a 25 utenti non bloccati.

### S04 - auto-accept di una richiesta reciproca

```cypher
MATCH (from:AppUser {uid: $uid})
MATCH (to:AppUser {uid: $targetUserId})
WHERE from.uid <> to.uid
  AND NOT (from)-[:FRIEND]-(to)
  AND NOT (from)-[:BLOCKED]->(to)
  AND NOT (to)-[:BLOCKED]->(from)
MATCH (to)-[r:SENT_FRIEND_REQUEST {status: 'pending'}]->(from)
SET r.status = 'accepted', r.updatedAt = datetime()
MERGE (from)-[a:FRIEND]-(to)
ON CREATE SET a.createdAt = datetime()
RETURN r.requestId AS requestId
LIMIT 1
```

Prima query di `sendFriendRequest`, route `POST /friends/requests`.

### S05 - creazione o riattivazione richiesta

```cypher
MATCH (from:AppUser {uid: $uid})
MATCH (to:AppUser {uid: $targetUserId})
WHERE from.uid <> to.uid
  AND NOT (from)-[:FRIEND]-(to)
  AND NOT (from)-[:BLOCKED]->(to)
  AND NOT (to)-[:BLOCKED]->(from)
MERGE (from)-[r:SENT_FRIEND_REQUEST]->(to)
ON CREATE SET r.requestId = $requestId, r.createdAt = datetime()
SET r.status = 'pending', r.updatedAt = datetime()
RETURN {
  id: r.requestId,
  status: r.status,
  createdAt: toString(r.createdAt),
  toUserId: to.uid,
  fromUser: {
    id: from.uid,
    name: coalesce(from.displayName, from.email, 'Agreeo user'),
    avatarUrl: coalesce(from.avatarUrl, ''),
    watchedCount: 0,
    reviewsCount: 0,
    privacySettings: {
      canShowWatched: coalesce(from.canShowWatched, true),
      canShowReviews: coalesce(from.canShowReviews, true),
      canShowWatchlist: coalesce(from.canShowWatchlist, false)
    }
  }
} AS request
LIMIT 1
```

Seconda query di `sendFriendRequest`. `S04` e `S05` non condividono una transazione. Un vecchio arco declined/accepted puo' essere riusato mantenendo `requestId` e `createdAt`.

### S06 - accettazione esplicita

```cypher
MATCH (me:AppUser {uid: $uid})
MATCH (from:AppUser)-[
  r:SENT_FRIEND_REQUEST {requestId: $requestId, status: 'pending'}
]->(me)
SET r.status = 'accepted', r.updatedAt = datetime()
MERGE (me)-[a:FRIEND]-(from)
ON CREATE SET a.createdAt = datetime()
RETURN from.uid AS friendId,
       coalesce(me.displayName, me.email, 'Someone') AS accepterName,
       coalesce(from.displayName, from.email, 'Someone') AS senderName
LIMIT 1
```

Funzione e route: `acceptFriendRequest`, `POST /friends/requests/:id/accept`.

### S07 - rifiuto

```cypher
MATCH (me:AppUser {uid: $uid})<-[
  r:SENT_FRIEND_REQUEST {requestId: $requestId, status: 'pending'}
]-(from:AppUser)
SET r.status = 'declined', r.updatedAt = datetime()
RETURN from.uid AS friendId,
       coalesce(me.displayName, me.email, 'Someone') AS declinerName
LIMIT 1
```

Funzione e route: `declineFriendRequest`, `POST /friends/requests/:id/decline`.

### S08 - rimozione amicizia

```cypher
MATCH (me:AppUser {uid: $uid})
MATCH (friend:AppUser {uid: $friendId})
MATCH (me)-[rel:FRIEND]-(friend)
DELETE rel
RETURN friend.uid AS friendId
LIMIT 1
```

Funzione e route: `removeFriend`, `DELETE /friends/:id`.

### S09 - blocco

```cypher
MATCH (me:AppUser {uid: $uid})
MATCH (target:AppUser {uid: $friendId})
WHERE me.uid <> target.uid
OPTIONAL MATCH (me)-[friendRel:FRIEND]-(target)
DELETE friendRel
WITH me, target
OPTIONAL MATCH (me)-[outgoing:SENT_FRIEND_REQUEST {status: 'pending'}]->(target)
SET outgoing.status = 'declined', outgoing.updatedAt = datetime()
WITH me, target
OPTIONAL MATCH (target)-[incoming:SENT_FRIEND_REQUEST {status: 'pending'}]->(me)
SET incoming.status = 'declined', incoming.updatedAt = datetime()
WITH me, target
MERGE (me)-[blocked:BLOCKED]->(target)
ON CREATE SET blocked.createdAt = datetime()
SET blocked.updatedAt = datetime()
RETURN target.uid AS friendId
LIMIT 1
```

Funzione e route: `blockFriend`, `POST /friends/:id/block`. Rimozione amicizia, rifiuto richieste e creazione blocco sono atomici nello stesso statement.

### S10 - annullamento richiesta inviata

```cypher
MATCH (me:AppUser {uid: $uid})-[
  r:SENT_FRIEND_REQUEST {status: 'pending'}
]->(target:AppUser {uid: $targetUserId})
DELETE r
RETURN target.uid AS targetUserId
LIMIT 1
```

Funzione e route: `cancelFriendRequest`, `DELETE /friends/requests/outgoing/:userId`. L'arco viene eliminato per generare un nuovo `requestId` al prossimo invio.

### S11 - elenco bloccati

```cypher
MATCH (me:AppUser {uid: $uid})-[blocked:BLOCKED]->(target:AppUser)
RETURN {
  id: target.uid,
  name: coalesce(target.displayName, target.email, 'Agreeo user'),
  avatarUrl: coalesce(target.avatarUrl, ''),
  bio: coalesce(target.bio, ''),
  blockedAt: toString(blocked.createdAt)
} AS user
ORDER BY toLower(coalesce(target.displayName, target.email, '')) ASC
```

Funzione e route: `getBlockedUsers`, `GET /friends/blocked`.

### S12 - sblocco

```cypher
MATCH (me:AppUser {uid: $uid})-[blocked:BLOCKED]->
      (target:AppUser {uid: $targetUserId})
DELETE blocked
RETURN target.uid AS targetUserId
LIMIT 1
```

Funzione e route: `unblockFriend`, `DELETE /friends/:id/block`. Non ripristina amicizie o richieste.

### S13 - segnalazione

```cypher
MATCH (me:AppUser {uid: $uid})
MATCH (target:AppUser {uid: $targetUserId})
WHERE me.uid <> target.uid
CREATE (me)-[report:REPORTED {
  reportId: $reportId,
  reason: $reason,
  context: $context,
  contentId: $contentId,
  status: 'open',
  createdAt: datetime()
}]->(target)
RETURN report.reportId AS reportId
LIMIT 1
```

Funzione e route: `reportUser`, `POST /friends/:id/report`. `CREATE` consente piu' segnalazioni fra la stessa coppia.

### S14 - intestazione e autorizzazione profilo amico

```cypher
MATCH (me:AppUser {uid: $uid})-[:FRIEND]-
      (friend:AppUser {uid: $friendId})
WHERE NOT (me)-[:BLOCKED]->(friend)
  AND NOT (friend)-[:BLOCKED]->(me)
OPTIONAL MATCH (friend)-[:ALREADY_SEEN]->(watchedCountMovie:Movie)
OPTIONAL MATCH (friend)-[:RATED_APP]->(reviewedCountMovie:Movie)
WITH friend,
     count(DISTINCT watchedCountMovie) AS watchedCount,
     count(DISTINCT reviewedCountMovie) AS reviewsCount
RETURN {
  id: friend.uid,
  name: coalesce(friend.displayName, friend.email, 'Agreeo user'),
  avatarUrl: coalesce(friend.avatarUrl, ''),
  bio: coalesce(friend.bio, ''),
  watchedCount: watchedCount,
  reviewsCount: reviewsCount,
  privacySettings: {
    canShowWatched: coalesce(friend.canShowWatched, true),
    canShowReviews: coalesce(friend.canShowReviews, true),
    canShowWatchlist: coalesce(friend.canShowWatchlist, false)
  }
} AS friend
LIMIT 1
```

Funzione e route: `getFriendProfile`, `GET /friends/:id/profile`. I flag decidono in JavaScript se lanciare `S15` e `S16`; i conteggi dell'intestazione non vengono nascosti.

### S15 - film visti o watchlist dell'amico

```cypher
MATCH (:AppUser {uid: $friendId})-[r:<ALREADY_SEEN|WATCHLISTED>]->(m:Movie)
RETURN <MOVIE_MAP(m)> AS movie
ORDER BY r.createdAt DESC
LIMIT 20
```

Helper: `loadFriendMovies`. Il tipo e' allowlisted. L'autorizzazione dipende da `S14`, eseguita separatamente.

### S16 - recensioni dell'amico

```cypher
MATCH (:AppUser {uid: $friendId})-[r:RATED_APP]->(m:Movie)
RETURN {
  movie: <MOVIE_MAP(m)>,
  rating: coalesce(r.rating, 0),
  reviewPreview: coalesce(r.review, ''),
  date: toString(coalesce(r.updatedAt, r.createdAt))
} AS review
ORDER BY coalesce(r.updatedAt, r.createdAt) DESC
LIMIT 20
```

Helper: `loadFriendReviews`, chiamato da `getFriendProfile` se `canShowReviews` e' vero.

### 8.2 Eventi, inviti e letture Movie Night

### S17 - creazione evento

```cypher
MATCH (host:AppUser {uid: $uid})
CREATE (event:MovieNight {
  id: $eventId,
  name: $name,
  contentType: 'movie',
  dateTime: $dateTime,
  includedGenres: $includedGenres,
  excludedGenres: $excludedGenres,
  maxDurationMinutes: $maxDurationMinutes,
  minimumRating: $minimumRating,
  language: $language,
  inviteLink: $inviteLink,
  status: 'waiting',
  winnerMovieId: null,
  round: 1,
  createdAt: datetime(),
  updatedAt: datetime()
})
MERGE (host)-[hosts:HOSTS]->(event)
ON CREATE SET hosts.createdAt = datetime()
MERGE (host)-[part:PARTICIPATES_IN]->(event)
ON CREATE SET part.createdAt = datetime()
SET part.status = 'joined',
    part.isHost = true,
    part.updatedAt = datetime()
RETURN event.id AS eventId
```

Funzione e route: `createMovieNight`, `POST /movie-nights`. L'host viene creato contemporaneamente come partecipante joined.

### S18 - invito batch degli amici

```cypher
MATCH (:AppUser {uid: $uid})-[:HOSTS]->
      (event:MovieNight {id: $eventId})
UNWIND $friendIds AS friendId
MATCH (me:AppUser {uid: $uid})
MATCH (friend:AppUser {uid: friendId})
WHERE (me)-[:FRIEND]-(friend)
MERGE (friend)-[part:PARTICIPATES_IN]->(event)
ON CREATE SET part.createdAt = datetime()
SET part.status = coalesce(part.status, 'pending'),
    part.isHost = false,
    part.updatedAt = datetime()
```

Funzione e route: `inviteFriends`, `POST /movie-nights/:id/invite`; usata anche durante la creazione. Uno stato `joined` esistente viene conservato.

Il filtro `FRIEND` vale soltanto per la creazione di `PARTICIPATES_IN`. Il controller invia `S48` e l'evento Socket.IO agli ID originali non filtrati: un UID esistente puo' quindi ricevere notifica e payload anche se `S18` non lo ha invitato.

### S19 - ingresso nell'evento

```cypher
MATCH (user:AppUser {uid: $uid})
MATCH (event:MovieNight {id: $eventId})
WHERE coalesce(event.status, 'waiting') IN ['draft', 'waiting']
MERGE (user)-[part:PARTICIPATES_IN]->(event)
ON CREATE SET part.createdAt = datetime(), part.isHost = false
SET part.status = 'joined',
    part.isHost = coalesce(part.isHost, false),
    part.updatedAt = datetime(),
    event.updatedAt = datetime()
RETURN event.id AS eventId
LIMIT 1
```

Funzione e route: `joinMovieNight`, `POST /movie-nights/:id/join`. Non richiede un invito: conoscere l'ID e' sufficiente mentre l'evento e' waiting/draft.

### S20-S24 - uscita atomica da Movie Night

`leaveMovieNight` esegue da una a cinque query nella stessa `executeWrite`.

```cypher
// S20: verifica partecipazione e ruolo
MATCH (user:AppUser {uid: $uid})-[part:PARTICIPATES_IN]->
      (event:MovieNight {id: $eventId})
RETURN coalesce(part.isHost, false) AS isHost
LIMIT 1
```

```cypher
// S21: elimina voti, partecipazione e ownership dell'utente
MATCH (user:AppUser {uid: $uid})
OPTIONAL MATCH (user)-[vote:VOTED_IN]->(:Movie)
WHERE vote.eventId = $eventId
DELETE vote
WITH user
MATCH (user)-[part:PARTICIPATES_IN]->(event:MovieNight {id: $eventId})
OPTIONAL MATCH (user)-[hosts:HOSTS]->(event)
DELETE part, hosts
SET event.updatedAt = datetime()
```

```cypher
// S22: se esce l'host, promuove il partecipante migliore
MATCH (event:MovieNight {id: $eventId})<-
      [part:PARTICIPATES_IN]-(candidate:AppUser)
WITH event, candidate, part
ORDER BY CASE WHEN part.status = 'joined' THEN 0 ELSE 1 END,
         coalesce(part.createdAt, datetime())
LIMIT 1
MERGE (candidate)-[h:HOSTS]->(event)
ON CREATE SET h.createdAt = datetime()
SET part.isHost = true, event.updatedAt = datetime()
RETURN candidate.uid AS newHostId
```

```cypher
// S23: se non rimane nessuno, elimina tutti i voti dell'evento
OPTIONAL MATCH (:AppUser)-[vote:VOTED_IN]->(:Movie)
WHERE vote.eventId = $eventId
DELETE vote
```

```cypher
// S24: elimina l'evento vuoto
MATCH (event:MovieNight {id: $eventId})
DETACH DELETE event
```

S22 preferisce un partecipante joined e poi il piu' anziano. Se rimangono solo pending, uno di essi puo' diventare host senza cambio di status.

### S25 - elenco Movie Night aggregato

```cypher
MATCH (me:AppUser {uid: $uid})-[:PARTICIPATES_IN]->(event:MovieNight)
OPTIONAL MATCH (host:AppUser)-[:HOSTS]->(event)
WITH event, host
ORDER BY event.updatedAt DESC
LIMIT 50
RETURN {
  id: event.id,
  name: event.name,
  hostUserId: host.uid,
  dateTime: event.dateTime,
  constraints: {
    includedGenres: coalesce(event.includedGenres, []),
    excludedGenres: coalesce(event.excludedGenres, []),
    maxDurationMinutes: event.maxDurationMinutes,
    minimumRating: event.minimumRating,
    language: event.language
  },
  inviteLink: coalesce(event.inviteLink, ''),
  status: coalesce(event.status, 'waiting'),
  winnerMovieId: event.winnerMovieId,
  round: coalesce(event.round, 1),
  createdAt: toString(event.createdAt),
  updatedAt: toString(event.updatedAt)
} AS event,
[(user:AppUser)-[part:PARTICIPATES_IN]->(event) | {
  userId: user.uid,
  name: coalesce(user.displayName, user.email, 'Agreeo user'),
  avatarUrl: coalesce(user.avatarUrl, ''),
  status: coalesce(part.status, 'pending'),
  isHost: coalesce(part.isHost, false)
}] AS participants,
[(event)-[candidate:HAS_CANDIDATE]->(m:Movie)
 WHERE event.status = 'completed'
    OR candidate.eliminated IS NULL OR NOT candidate.eliminated | {
  movie: <MOVIE_MAP(m)>,
  compatibilityScore: coalesce(candidate.compatibilityScore, 0.0),
  explanationTags: coalesce(candidate.explanationTags, []),
  scoreBreakdownJson: coalesce(candidate.scoreBreakdownJson, '{}'),
  eliminated: coalesce(candidate.eliminated, false)
}] AS shortlist,
[(vUser:AppUser)-[vote:VOTED_IN]->(vMovie:Movie)
 WHERE vote.eventId = event.id | {
  eventId: vote.eventId,
  userId: vUser.uid,
  movieId: 'tmdb-' + toString(vMovie.tmdbId),
  vote: vote.vote,
  createdAt: toString(coalesce(vote.updatedAt, vote.createdAt))
}] AS votes
```

Funzione e route: `listMovieNights`, `GET /movie-nights`. Le pattern comprehension evitano round trip aggiuntivi.

### S26 - intestazione di un evento

```cypher
MATCH (:AppUser {uid: $uid})-[:PARTICIPATES_IN]->
      (event:MovieNight {id: $eventId})
OPTIONAL MATCH (host:AppUser)-[:HOSTS]->(event)
RETURN {
  id: event.id,
  name: event.name,
  hostUserId: host.uid,
  dateTime: event.dateTime,
  constraints: {
    includedGenres: coalesce(event.includedGenres, []),
    excludedGenres: coalesce(event.excludedGenres, []),
    maxDurationMinutes: event.maxDurationMinutes,
    minimumRating: event.minimumRating,
    language: event.language
  },
  inviteLink: coalesce(event.inviteLink, ''),
  status: coalesce(event.status, 'waiting'),
  winnerMovieId: event.winnerMovieId,
  round: coalesce(event.round, 1),
  createdAt: toString(event.createdAt),
  updatedAt: toString(event.updatedAt)
} AS event
LIMIT 1
```

Prima query di `getMovieNight`, route `GET /movie-nights/:id`. Il richiedente deve essere partecipante, anche pending.

### S27 - partecipanti

```cypher
MATCH (user:AppUser)-[part:PARTICIPATES_IN]->
      (:MovieNight {id: $eventId})
RETURN {
  userId: user.uid,
  name: coalesce(user.displayName, user.email, 'Agreeo user'),
  avatarUrl: coalesce(user.avatarUrl, ''),
  status: coalesce(part.status, 'pending'),
  isHost: coalesce(part.isHost, false)
} AS participant
ORDER BY coalesce(part.isHost, false) DESC,
         toLower(coalesce(user.displayName, user.email, '')) ASC
```

Helper `loadParticipants`, chiamato da `getMovieNight`.

### S28 - shortlist attiva

```cypher
MATCH (event:MovieNight {id: $eventId})-[candidate:HAS_CANDIDATE]->(m:Movie)
WHERE event.status = 'completed'
   OR candidate.eliminated IS NULL
   OR NOT candidate.eliminated
RETURN {
  movie: <MOVIE_MAP(m)>,
  compatibilityScore: coalesce(candidate.compatibilityScore, 0.0),
  explanationTags: coalesce(candidate.explanationTags, []),
  scoreBreakdownJson: coalesce(candidate.scoreBreakdownJson, '{}'),
  eliminated: coalesce(candidate.eliminated, false)
} AS candidate
ORDER BY candidate.compatibilityScore DESC, m.title ASC
```

Helper `loadShortlist`.

### S29 - voti dell'evento

```cypher
MATCH (user:AppUser)-[vote:VOTED_IN]->(m:Movie)
WHERE vote.eventId = $eventId
RETURN {
  eventId: vote.eventId,
  userId: user.uid,
  movieId: 'tmdb-' + toString(m.tmdbId),
  vote: vote.vote,
  createdAt: toString(coalesce(vote.updatedAt, vote.createdAt))
} AS vote
ORDER BY vote.createdAt ASC
```

Helper `loadVotes`. Senza una transazione ambientale, `S26-S29` condividono una `executeRead` e quindi lo stesso snapshot. Quando `getMovieNight` riceve `tx`, per esempio da `submitVote`, condividono invece la `executeWrite` del chiamante. `S27-S29` sono lanciate in parallelo sulla stessa transazione.

### S30 - aggiornamento evento

```cypher
MATCH (:AppUser {uid: $uid})-[:HOSTS]->
      (event:MovieNight {id: $eventId})
SET event.updatedAt = datetime()
FOREACH (_ IN CASE WHEN $name IS NULL THEN [] ELSE [1] END |
  SET event.name = $name)
FOREACH (_ IN CASE WHEN $dateTimeProvided THEN [1] ELSE [] END |
  SET event.dateTime = $dateTime)
FOREACH (_ IN CASE WHEN $status <> '' THEN [1] ELSE [] END |
  SET event.status = $status)
FOREACH (_ IN CASE WHEN $constraintsProvided THEN [1] ELSE [] END |
  SET event.includedGenres = $includedGenres,
      event.excludedGenres = $excludedGenres,
      event.maxDurationMinutes = $maxDurationMinutes,
      event.minimumRating = $minimumRating,
      event.language = $language,
      event.status = 'waiting',
      event.winnerMovieId = null)
RETURN event.id AS eventId
LIMIT 1
```

Funzione e route: `updateMovieNight`, `PATCH /movie-nights/:id`. Solo l'host fa match. I passaggi successivi, come pulizia e rigenerazione shortlist, sono auto-commit separati.

Se la stessa richiesta contiene sia `status` sia `constraints`, il blocco constraints viene eseguito per ultimo e salva `status='waiting'`. JavaScript rigenera comunque la shortlist quando il valore richiesto di `status` e' `voting`: il risultato puo' essere una shortlist nuova con evento ancora waiting.

### S31 - pulizia shortlist e voti

```cypher
MATCH (event:MovieNight {id: $eventId})
OPTIONAL MATCH (event)-[candidate:HAS_CANDIDATE]->(:Movie)
DELETE candidate
WITH event
OPTIONAL MATCH (:AppUser)-[vote:VOTED_IN]->(:Movie)
WHERE vote.eventId = $eventId
DELETE vote
SET event.winnerMovieId = null
```

Helper `clearShortlistAndVotes`, chiamato quando cambiano i vincoli.

### S32 - link di invito

```cypher
MATCH (:AppUser {uid: $uid})-[:HOSTS]->
      (event:MovieNight {id: $eventId})
SET event.inviteLink = $inviteLink,
    event.updatedAt = datetime()
RETURN event.inviteLink AS inviteLink
LIMIT 1
```

Funzione e route: `createInviteLink`, `POST /movie-nights/:id/invite-link`.

### 8.3 Generazione della shortlist

### S33 - persistenza dell'arricchimento TMDB

```cypher
MATCH (m:Movie {tmdbId: $tmdbId})
SET m.posterPath = $posterPath,
    m.backdropPath = $backdropPath,
    m.posterUrl = $posterUrl,
    m.backdropUrl = $backdropUrl,
    m.overview = coalesce($overview, m.overview),
    m.genres = $genres,
    m.runtime = $runtime,
    m.tmdbHydrated = true
```

Helper `enrichCandidateFromTmdb`, eseguito per candidato con concorrenza massima 4. Gli errori individuali non annullano la shortlist.

### S34 - embedding del gusto di gruppo

```cypher
MATCH (u:AppUser)
WHERE u.uid IN $userIds
MATCH (u)-[r:LIKED|SELECTED_FAVORITE|WATCHLISTED|DISLIKED]->(m:Movie)
MATCH (m)<-[:MATCHES_TMDB]-(ml:MovieLensMovie)-[h:HAS_TAG]->(t:Tag)
WHERE t.embedding IS NOT NULL
RETURN t.embedding AS embedding,
       type(r) AS relType,
       coalesce(h.frequency, 1) AS frequency
```

Prima query Cypher inline di `generateShortlist`, dopo la lettura `S26-S29` e soltanto se esiste almeno un partecipante joined. La route e' `POST /movie-nights/:id/shortlist`. JavaScript usa favorite `+4`, like `+3`, watchlist `+1.5`, dislike `-3`; accetta solo vettori 384D.

### S35 - sostituzione shortlist persistita

```cypher
MATCH (event:MovieNight {id: $eventId})
OPTIONAL MATCH (event)-[old:HAS_CANDIDATE]->(:Movie)
DELETE old
WITH event
UNWIND $candidates AS candidate
MATCH (m:Movie {tmdbId: candidate.tmdbId})
MERGE (event)-[rel:HAS_CANDIDATE]->(m)
SET rel.compatibilityScore = candidate.compatibilityScore,
    rel.explanationTags = candidate.explanationTags,
    rel.scoreBreakdownJson = candidate.scoreBreakdownJson,
    event.updatedAt = datetime(),
    event.winnerMovieId = null
```

Con lista vuota gli archi vecchi sono eliminati, ma `UNWIND []` impedisce i `SET` finali. I candidati senza nodo `Movie` vengono scartati.

`generateShortlist` non richiede `HOSTS` ne' `part.status='joined'` per il richiedente: la lettura `S26` autorizza anche un partecipante pending. Un invitato pending puo' quindi sostituire la shortlist con `S35` e cancellare tutti i voti con `S36`.

### S36 - pulizia dei soli voti

```cypher
OPTIONAL MATCH (:AppUser)-[vote:VOTED_IN]->(:Movie)
WHERE vote.eventId = $eventId
DELETE vote
```

Helper `clearVotesOnly`, eseguito dopo `S35` ma in una chiamata separata.

### S37 - upsert dei risultati TMDB Discover

```cypher
MERGE (m:Movie {tmdbId: $tmdbId})
SET m.title = $title,
    m.originalTitle = $originalTitle,
    m.overview = $overview,
    m.posterPath = $posterPath,
    m.backdropPath = $backdropPath,
    m.posterUrl = $posterUrl,
    m.backdropUrl = $backdropUrl,
    m.releaseDate = $releaseDate,
    m.voteAverage = $voteAverage,
    m.genres = $genres,
    m.tmdbHydrated = true
```

Prima query di `loadCandidateMovies`, eseguita una volta per risultato TMDB valido. A differenza di `M01`, sovrascrive i metadati e non materializza `IN_GENRE`.

### S38 - candidati via vector index

```cypher
CALL db.index.vector.queryNodes(
  'tag_embeddings', toInteger($topK), $groupTasteVector
)
YIELD node AS tagNode, score AS similarity
MATCH (tagNode)<-[h:HAS_TAG]-(ml:MovieLensMovie)-[:MATCHES_TMDB]->(m:Movie)
WITH m, ml, tagNode.name AS tag, h.frequency AS tagFrequency, similarity
WITH m, ml, tag, tagFrequency, 2.0 * similarity - 1.0 AS stdSimilarity
WHERE stdSimilarity >= $similarityThreshold
WITH m, ml,
     [g IN coalesce(m.genres, []) WHERE g IS NOT NULL]
       + collect(DISTINCT tag) AS rawGenres,
     sum(tagFrequency * (stdSimilarity ^ 3)) AS tagScore
WITH m, ml, [g IN rawGenres WHERE g IS NOT NULL] AS genres, tagScore
WHERE ($maxDurationMinutes IS NULL
       OR coalesce(m.runtime, 0) = 0
       OR coalesce(m.runtime, 0) <= $maxDurationMinutes)
  AND ($minimumRating IS NULL
       OR coalesce(m.voteAverage, m.movieLensAvgRating * 2.0, 0.0)
          >= $minimumRating)
  AND (size($includedGenres) = 0
       OR any(g IN genres WHERE g IN $includedGenres))
  AND none(g IN genres WHERE g IN $excludedGenres)
RETURN {
  tmdbId: m.tmdbId,
  title: coalesce(m.title, ''),
  originalTitle: coalesce(m.originalTitle, m.title, ''),
  overview: coalesce(m.overview, ''),
  posterPath: m.posterPath,
  backdropPath: m.backdropPath,
  posterUrl: coalesce(m.posterUrl, ''),
  backdropUrl: coalesce(m.backdropUrl, ''),
  releaseDate: coalesce(m.releaseDate, ''),
  runtime: coalesce(m.runtime, 0),
  voteAverage: coalesce(m.voteAverage, m.movieLensAvgRating * 2.0, 0.0),
  genres: genres,
  movieLensAvgRating: m.movieLensAvgRating,
  movieLensRatingCount: coalesce(m.movieLensRatingCount, 0)
} AS movie
ORDER BY tagScore DESC,
         coalesce(m.movieLensRatingCount, 0) DESC,
         m.title ASC
LIMIT toInteger($limit)
```

Seconda query di `loadCandidateMovies`. I nomi dei tag vengono aggiunti a `genres`, percio' i vincoli inclusi/esclusi operano su un insieme misto. `constraints.language` non viene applicato in `S38-S39` ne' come filtro TMDB Discover; la richiesta TMDB usa sempre `language=en-US`. Il vincolo lingua dell'evento non influenza quindi la shortlist.

### S39 - candidati fallback senza vettore

```cypher
MATCH (m:Movie)
WHERE m.tmdbId IS NOT NULL
OPTIONAL MATCH (m)<-[:MATCHES_TMDB]-
               (:MovieLensMovie)-[:IN_GENRE]->(genre:Genre)
WITH m,
     [g IN coalesce(m.genres, []) WHERE g IS NOT NULL]
       + collect(DISTINCT genre.name) AS rawGenres
WITH m, [g IN rawGenres WHERE g IS NOT NULL] AS genres
WHERE ($maxDurationMinutes IS NULL
       OR coalesce(m.runtime, 0) = 0
       OR coalesce(m.runtime, 0) <= $maxDurationMinutes)
  AND ($minimumRating IS NULL
       OR coalesce(m.voteAverage, m.movieLensAvgRating * 2.0, 0.0)
          >= $minimumRating)
  AND (size($includedGenres) = 0
       OR any(g IN genres WHERE g IN $includedGenres))
  AND none(g IN genres WHERE g IN $excludedGenres)
RETURN {
  tmdbId: m.tmdbId,
  title: coalesce(m.title, ''),
  originalTitle: coalesce(m.originalTitle, m.title, ''),
  overview: coalesce(m.overview, ''),
  posterPath: m.posterPath,
  backdropPath: m.backdropPath,
  posterUrl: coalesce(m.posterUrl, ''),
  backdropUrl: coalesce(m.backdropUrl, ''),
  releaseDate: coalesce(m.releaseDate, ''),
  runtime: coalesce(m.runtime, 0),
  voteAverage: coalesce(m.voteAverage, m.movieLensAvgRating * 2.0, 0.0),
  genres: genres,
  movieLensAvgRating: m.movieLensAvgRating,
  movieLensRatingCount: coalesce(m.movieLensRatingCount, 0)
} AS movie
ORDER BY coalesce(m.movieLensRatingCount, 0) DESC,
         coalesce(m.voteAverage, m.movieLensAvgRating * 2.0, 0.0) DESC,
         m.title ASC
LIMIT toInteger($limit)
```

Terza query di `loadCandidateMovies`. Un runtime `0` e' considerato sconosciuto e supera il vincolo massimo.

### S40 - matrice utente-film per la compatibilita'

```cypher
MATCH (u:AppUser)
WHERE u.uid IN $userIds
MATCH (m:Movie)
WHERE m.tmdbId IN $tmdbIds
OPTIONAL MATCH (u)-[liked:LIKED]->(m)
OPTIONAL MATCH (u)-[disliked:DISLIKED]->(m)
OPTIONAL MATCH (u)-[watchlisted:WATCHLISTED]->(m)
OPTIONAL MATCH (u)-[seen:ALREADY_SEEN]->(m)
OPTIONAL MATCH (u)-[rated:RATED_APP]->(m)
RETURN u.uid AS userId,
       m.tmdbId AS tmdbId,
       count(liked) > 0 AS liked,
       count(disliked) > 0 AS disliked,
       count(watchlisted) > 0 AS inWatchlist,
       count(seen) > 0 AS watched,
       max(rated.rating) AS rating
```

Helper: `loadUserMovieStates`. I due `MATCH ... IN` formano il prodotto utenti per candidati. Lo scoring JavaScript assegna watchlist `+4`, like `+3`, rating almeno 4 `+1`, dislike `-15`, visto `-1`, poi bonus e penalita' di gruppo.

### 8.4 Voti, tie-break e risultato

### S41 - elimina voti dei film in parita'

```cypher
OPTIONAL MATCH (:AppUser)-[vote:VOTED_IN]->(m:Movie)
WHERE vote.eventId = $eventId
  AND m.tmdbId IN $tiedTmdbIds
DELETE vote
```

Helper `clearVotesForTiedMovies`, eseguito nella transazione di `submitVote`.

### S42 - elimina logicamente i candidati non in parita'

```cypher
MATCH (event:MovieNight {id: $eventId})-[rel:HAS_CANDIDATE]->(m:Movie)
WHERE NOT m.tmdbId IN $tiedTmdbIds
SET rel.eliminated = true
```

Prima query di `startTieBreaker`.

### S43 - incrementa il round

```cypher
MATCH (event:MovieNight {id: $eventId})
SET event.round = coalesce(event.round, 1) + 1,
    event.updatedAt = datetime()
```

Seconda query di `startTieBreaker`, seguita da `S41`.

### S44 - inserimento o aggiornamento del voto

```cypher
MATCH (user:AppUser {uid: $uid})-[part:PARTICIPATES_IN]->
      (event:MovieNight {id: $eventId})
MATCH (event)-[rel:HAS_CANDIDATE]->
      (movie:Movie {tmdbId: $tmdbId})
WHERE part.status = 'joined'
  AND (rel.eliminated IS NULL OR NOT rel.eliminated)
MERGE (user)-[v:VOTED_IN {eventId: $eventId}]->(movie)
ON CREATE SET v.createdAt = datetime()
SET v.vote = $vote,
    v.updatedAt = datetime(),
    event.status = 'voting',
    event.updatedAt = datetime()
RETURN movie.tmdbId AS tmdbId
LIMIT 1
```

Funzione e route: `submitVote`, `POST /movie-nights/:id/votes`. Valori diversi da `like`, `dislike`, `alreadySeen` e `neutral` vengono convertiti in `neutral`. `S44` non filtra `event.status`: un partecipante joined puo' avviare o riaprire la votazione, anche da waiting o completed, se il candidato non e' eliminato. Il `SET` sull'evento agisce anche come lock di scrittura per serializzare voti concorrenti sullo stesso evento.

### S45 - completamento e vincitore

```cypher
MATCH (event:MovieNight {id: $eventId})
SET event.status = 'completed',
    event.winnerMovieId = $winnerMovieId,
    event.updatedAt = datetime()
```

Eseguita dentro la stessa `executeWrite` di `S44` quando tutti i partecipanti joined hanno votato tutti i candidati attivi e non e' richiesto un altro tie-break. Il vincitore e' memorizzato come stringa `tmdb-<id>`, non come relazione.

### S46 - cancellazione voto

```cypher
MATCH (user:AppUser {uid: $uid})-[
  vote:VOTED_IN {eventId: $eventId}
]->(movie:Movie {tmdbId: $tmdbId})
DELETE vote
```

Funzione e route: `deleteVote`, `DELETE /movie-nights/:id/votes/:movieId`. Non controlla il numero di relazioni eliminate.

### S47 - riapertura votazione

```cypher
MATCH (event:MovieNight {id: $eventId})
SET event.status = 'voting',
    event.winnerMovieId = null,
    event.updatedAt = datetime()
```

Seconda query di `deleteVote`, separata da `S46`. Viene eseguita anche se `S46` non ha trovato un voto. Non verifica direttamente ownership o partecipazione: un utente puo' modificare un evento valido con parametri sintatticamente validi anche se la successiva lettura gli verra' negata. E' uno dei principali caveat di autorizzazione del catalogo social.

### 8.5 Notifiche

### S48 - creazione notifica

```cypher
MATCH (u:AppUser {uid: $recipientId})
CREATE (n:InAppNotification {
  id: $id,
  type: $type,
  title: $title,
  message: $message,
  entityId: $entityId,
  extraData: $extraDataStr,
  read: false,
  createdAt: datetime()
})
CREATE (u)-[:HAS_NOTIFICATION]->(n)
RETURN n.id AS id
```

Funzione: `createNotification`; usata da richieste/accettazioni di amicizia, inviti, avvio voto, tie-break e completamento. Ogni notifica e' una scrittura separata dalla mutazione che la origina. `extraData` e' JSON testuale.

### S49 - elenco notifiche

```cypher
MATCH (u:AppUser {uid: $uid})-[:HAS_NOTIFICATION]->(n:InAppNotification)
RETURN n.id AS id,
       n.type AS type,
       n.title AS title,
       n.message AS message,
       n.entityId AS entityId,
       n.extraData AS extraData,
       n.read AS read,
       toString(n.createdAt) AS createdAt
ORDER BY n.createdAt DESC
```

Funzione e route: `listNotifications`, `GET /notifications`. Non esistono paginazione o limite.

### S50 - notifica letta

```cypher
MATCH (u:AppUser {uid: $uid})-[:HAS_NOTIFICATION]->
      (n:InAppNotification {id: $notificationId})
SET n.read = true
RETURN n.id AS id
```

Funzione e route: `markNotificationAsRead`, `POST /notifications/:id/read`. Il pattern garantisce ownership ed e' idempotente.

### S51 - nome visualizzato

```cypher
MATCH (u:AppUser {uid: $uid})
RETURN coalesce(u.displayName, u.email, 'Someone') AS displayName
LIMIT 1
```

Helper `getUserDisplayName`, usato per testi di notifiche e inviti. Se non trova il nodo, JavaScript restituisce comunque `Someone`.

### 8.6 Confini transazionali social

| Workflow | Transazione |
|---|---|
| `leaveMovieNight` | `S20-S24` in una `executeWrite` atomica |
| `getMovieNight` | Senza transazione ambientale, `S26-S29` condividono una `executeRead`; con `tx` condividono la transazione del chiamante, inclusa la `executeWrite` di `submitVote` |
| `submitVote` | `S44`, snapshot evento, eventuali `S41-S43` o `S45`, snapshot finale nella stessa `executeWrite` |
| `sendFriendRequest` | `S04` e `S05` auto-commit separati |
| `getFriendProfile` | `S14`, `S15`, `S16` separati; possibile cambiamento di autorizzazione tra le letture |
| `create/update/invite/join` Movie Night | mutazione, notifiche e rilettura separate |
| `generateShortlist` | letture, TMDB, upsert, persistenza e pulizia voti separate |
| `deleteVote` | `S46`, `S47` e rilettura separate |

### 8.7 Route social

| Route | Handler/funzioni principali |
|---|---|
| `GET /friends` | `listFriends` -> `getFriends` (`S01-S02`) |
| `GET /friends/search` | `searchFriends` (`S03`) |
| `POST /friends/requests` | Ramo reciproco: `S04`, refresh `S01-S02`, `S51` due volte e `S48` due volte; ramo normale: `S04`, `S05`, `S48` |
| `POST /friends/requests/:id/accept` | `acceptFriendRequest` (`S06`, `S48`, refresh `S01-S02`) |
| `POST /friends/requests/:id/decline` | `declineFriendRequest` (`S07`, refresh) |
| `DELETE /friends/requests/outgoing/:userId` | `cancelFriendRequest` (`S10`, refresh) |
| `GET /friends/blocked` | `getBlockedUsers` (`S11`) |
| `DELETE /friends/:id` | `removeFriend` (`S08`, poi refresh `S01-S02`) |
| `POST /friends/:id/block` | `blockFriend` (`S09`, poi refresh `S01-S02`) |
| `DELETE /friends/:id/block` | `unblockFriend` (`S12`, poi `S11`) |
| `POST /friends/:id/report` | `reportUser` (`S13`) |
| `GET /friends/:id/profile` | `getFriendProfile` (`S14-S16`) |
| `GET /movie-nights` | `listMovieNights` (`S25`) |
| `POST /movie-nights` | `S17`, `S18` opzionale, snapshot `S26-S29`, `S51` e `S48`; con inviti lo snapshot puo' essere ripetuto |
| `GET /movie-nights/:id` | `getMovieNight` (`S26-S29`) |
| `PATCH /movie-nights/:id` | Snapshot `S26-S29`, `S30`, `S31` opzionale; eventuale generazione con snapshot, `S34`, `S37`, `S38` o `S39`, `S40`, `S33`, `S35-S36`; snapshot finale e `S48` opzionale |
| `POST /movie-nights/:id/invite` | `S18`, snapshot `S26-S29`, `S51`, `S48` |
| `POST /movie-nights/:id/join` | `S19`, poi snapshot `S26-S29` |
| `DELETE /movie-nights/:id/participants/me` | Snapshot `S26-S29`, poi `S20-S24` transazionali |
| `POST /movie-nights/:id/invite-link` | `S32`, poi snapshot `S26-S29` |
| `POST /movie-nights/:id/shortlist` | Snapshot iniziale/finale `S26-S29` e, secondo i dati, `S34`, `S37`, `S38` o `S39`, `S40`, `S33`, `S35-S36` |
| `POST /movie-nights/:id/votes` | `S44`; se riesce, snapshot `S26-S29`. Solo quando tutti hanno votato: `S42-S43-S41` oppure `S45`, nuovo snapshot e `S48` per ogni partecipante |
| `DELETE /movie-nights/:id/votes/:movieId` | `S46-S47`, poi snapshot `S26-S29` |
| `GET /movie-nights/:id/result` | `getMovieNightResult` -> snapshot `S26-S29` |
| `GET /notifications` | `listNotifications` (`S49`) |
| `POST /notifications/:id/read` | `markNotificationAsRead` (`S50`) |

## 9. Import MovieLens

`backend/scripts/import_movielens.cypher` viene eseguito da `neo4j-init` tramite `cypher-shell`. Le prime sei query definiscono schema; le successive importano i quattro CSV e calcolano gli aggregati.

### I01-I06 - schema dell'import

```cypher
// I01
CREATE CONSTRAINT movielens_movie_id IF NOT EXISTS
FOR (m:MovieLensMovie) REQUIRE m.movieLensId IS UNIQUE;

// I02
CREATE CONSTRAINT movie_tmdb_id IF NOT EXISTS
FOR (m:Movie) REQUIRE m.tmdbId IS UNIQUE;

// I03
CREATE CONSTRAINT movielens_user_id IF NOT EXISTS
FOR (u:MovieLensUser) REQUIRE u.movieLensUserId IS UNIQUE;

// I04
CREATE CONSTRAINT genre_name IF NOT EXISTS
FOR (g:Genre) REQUIRE g.name IS UNIQUE;

// I05
CREATE INDEX movie_title IF NOT EXISTS
FOR (m:Movie) ON (m.title);

// I06
CREATE INDEX movielens_movie_title IF NOT EXISTS
FOR (m:MovieLensMovie) ON (m.title);
```

Duplicano intenzionalmente parte di `N03-N06` e `N13-N14`, cosi' l'import puo' essere eseguito prima del backend.

### I07 - `movies.csv`

```cypher
LOAD CSV WITH HEADERS FROM 'file:///movies.csv' AS row
CALL {
  WITH row
  MERGE (m:MovieLensMovie {movieLensId: toInteger(row.movieId)})
  SET m.movieLensTitle = row.title,
      m.title = row.title,
      m.source = 'movielens'
  WITH m, split(row.genres, '|') AS genres
  UNWIND genres AS genreName
  WITH m, genreName
  WHERE genreName IS NOT NULL
    AND genreName <> ''
    AND genreName <> '(no genres listed)'
  MERGE (g:Genre {name: genreName})
  MERGE (m)-[:IN_GENRE]->(g)
} IN TRANSACTIONS OF 1000 ROWS
```

Crea film raw e generi. Non rimuove generi scomparsi da una successiva versione del CSV e non normalizza case o spazi.

### I08 - `links.csv`

```cypher
LOAD CSV WITH HEADERS FROM 'file:///links.csv' AS row
CALL {
  WITH row
  MATCH (ml:MovieLensMovie {movieLensId: toInteger(row.movieId)})
  SET ml.imdbId = row.imdbId,
      ml.imdbFullId = CASE
        WHEN row.imdbId IS NULL OR trim(row.imdbId) = '' THEN null
        ELSE 'tt' + row.imdbId
      END
  WITH row, ml
  WHERE row.tmdbId IS NOT NULL AND trim(row.tmdbId) <> ''
  MERGE (m:Movie {tmdbId: toInteger(row.tmdbId)})
  ON CREATE SET m.title = ml.title,
                m.source = 'tmdb_movielens_link',
                m.createdFromMovieLens = true
  SET m.imdbId = row.imdbId,
      m.imdbFullId = CASE
        WHEN row.imdbId IS NULL OR trim(row.imdbId) = '' THEN null
        ELSE 'tt' + row.imdbId
      END
  MERGE (ml)-[:MATCHES_TMDB]->(m)
} IN TRANSACTIONS OF 1000 ROWS
```

`links.csv` e' l'unico matching usato: non viene fatto title matching. Piu' `MovieLensMovie` possono puntare allo stesso `Movie`.

### I09 - `ratings.csv`

```cypher
LOAD CSV WITH HEADERS FROM 'file:///ratings.csv' AS row
CALL {
  WITH row
  MERGE (u:MovieLensUser {movieLensUserId: toInteger(row.userId)})
  MATCH (m:MovieLensMovie {movieLensId: toInteger(row.movieId)})
  MERGE (u)-[r:RATED]->(m)
  SET r.rating = toFloat(row.rating),
      r.timestamp = toInteger(row.timestamp),
      r.ratedAt = datetime({epochSeconds: toInteger(row.timestamp)})
} IN TRANSACTIONS OF 10000 ROWS
```

Una riga duplicata per coppia utente-film aggiorna la stessa relazione; l'ultima prevale.

### I10 - `tags.csv`

```cypher
LOAD CSV WITH HEADERS FROM 'file:///tags.csv' AS row
CALL {
  WITH row
  MERGE (u:MovieLensUser {movieLensUserId: toInteger(row.userId)})
  MATCH (m:MovieLensMovie {movieLensId: toInteger(row.movieId)})
  MERGE (u)-[t:TAGGED {tag: row.tag}]->(m)
  SET t.timestamp = toInteger(row.timestamp),
      t.taggedAt = datetime({epochSeconds: toInteger(row.timestamp)})
} IN TRANSACTIONS OF 10000 ROWS
```

Il testo tag fa parte dell'identita' della relazione; case e spazi differenti restano distinti.

### I11 - aggregati sui film raw

```cypher
MATCH (m:MovieLensMovie)<-[r:RATED]-(:MovieLensUser)
WITH m, count(r) AS ratingCount, avg(r.rating) AS avgRating
SET m.movieLensRatingCount = ratingCount,
    m.movieLensAvgRating = round(avgRating * 100) / 100.0
```

### I12 - aggregati sui film canonici

```cypher
MATCH (:MovieLensUser)-[r:RATED]->
      (:MovieLensMovie)-[:MATCHES_TMDB]->(m:Movie)
WITH m, count(r) AS ratingCount, avg(r.rating) AS avgRating
SET m.movieLensRatingCount = ratingCount,
    m.movieLensAvgRating = round(avgRating * 100) / 100.0
```

Se piu' film raw convergono sullo stesso TMDB ID, gli aggregati vengono uniti. Film rimasti senza rating non vengono azzerati.

### 9.1 Idempotenza dell'import

Constraint, nodi e relazioni usano `IF NOT EXISTS` o `MERGE`; rieseguire lo script non duplica il modello previsto. Non e' pero' una sincronizzazione: non elimina dati rimossi dai CSV, vecchi generi, bridge, rating o tag, e non azzera aggregati diventati orfani.

## 10. Tag, embedding e vector index

### 10.1 Modello embedding

`embeddingService.js` usa di default `Xenova/multilingual-e5-small`, revisione pin `761b726dd34fb83930e26aab4e9ac3899aa1fa78`, feature extraction con mean pooling e normalizzazione. I tag usano il prefisso E5 `passage:`, le ricerche `query:`. Tutto il pipeline, la validazione e l'indice assumono **384 dimensioni**.

### E01 - caricamento tag per la cache embedding

```cypher
MATCH ()-[r:TAGGED]->()
WHERE r.tag IS NOT NULL
RETURN DISTINCT r.tag AS tag
```

Funzione: `embeddingService.initialize`. Il file cache e' `backend/data/tag_embeddings_<revision-prefix>.json`; il nome modello non fa parte del filename.

### E02 - ricerca di tag simili

```cypher
CALL db.index.vector.queryNodes(
  'tag_embeddings', toInteger($topK), $queryEmbedding
)
YIELD node AS tagNode, score AS similarity
RETURN tagNode.name AS tag,
       similarity,
       tagNode.embedding AS embedding
```

Funzione: `embeddingService.findSimilarTags`. La soglia e' applicata in JavaScript dopo i top K e lo score viene convertito con `2 * score - 1`.

### 10.2 Migrazione semantica

`backend/scripts/migrate_tags_to_vector.js` e' eseguito da `semantic-init` dopo l'import. Le query `V01-V10` sono:

### V01 - polling stato indice

```cypher
SHOW INDEXES YIELD name, type, state
WHERE name = 'tag_embeddings'
RETURN name, type, state
```

Massimo 30 tentativi ogni 2 secondi; controlla nome, tipo `VECTOR` e stato `ONLINE`, non dimensioni o similarity function.

### V02-V03 - schema semantico

```cypher
// V02
CREATE CONSTRAINT tag_name IF NOT EXISTS
FOR (t:Tag) REQUIRE t.name IS UNIQUE

// V03
CREATE VECTOR INDEX tag_embeddings IF NOT EXISTS
FOR (t:Tag) ON (t.embedding)
OPTIONS {indexConfig: {
  `vector.dimensions`: 384,
  `vector.similarity_function`: 'cosine'
}}
```

Nel job Docker un errore non e' best effort: fa fallire `semantic-init` e impedisce l'avvio del backend dipendente.

### V04 - tag raw distinti

```cypher
MATCH ()-[r:TAGGED]->()
WHERE r.tag IS NOT NULL
RETURN DISTINCT r.tag AS tag
```

### V05 - cardinalita' attesa `HAS_TAG`

```cypher
MATCH (:MovieLensUser)-[r:TAGGED]->(m:MovieLensMovie)
WHERE r.tag IS NOT NULL
WITH DISTINCT m, r.tag AS tag
RETURN count(*) AS expectedRelationshipCount
```

### V06 - upsert embedding in batch

```cypher
UNWIND $batch AS entry
MERGE (t:Tag {name: entry.tag})
SET t.embedding = entry.embedding
```

Eseguita `ceil(numeroTag / 100)` volte.

### V07 - materializzazione `HAS_TAG`

```cypher
MATCH (:MovieLensUser)-[r:TAGGED]->(m:MovieLensMovie)
WHERE r.tag IS NOT NULL
WITH m, r.tag AS tag, count(r) AS freq
MATCH (t:Tag {name: tag})
MERGE (m)-[h:HAS_TAG]->(t)
SET h.frequency = freq
RETURN count(h) AS relCount
```

La frequenza e' il numero di relazioni `TAGGED` materializzate per coppia film-tag. L'import compatta duplicati per utente/film/tag.

### V08 - document frequency e IDF

```cypher
MATCH (t:Tag)
OPTIONAL MATCH (m:MovieLensMovie)-[:HAS_TAG]->(t)
WITH t, count(DISTINCT m) AS documentFrequency
CALL {
  MATCH (allMovies:MovieLensMovie)
  RETURN count(allMovies) AS totalMovies
}
SET t.documentFrequency = documentFrequency,
    t.idf = log((toFloat(totalMovies) + 1.0) /
                (toFloat(documentFrequency) + 1.0)) + 1.0
RETURN count(t) AS tagCount
```

### V09 - totale tag per film

```cypher
MATCH (m:MovieLensMovie)
OPTIONAL MATCH (m)-[h:HAS_TAG]->(:Tag)
WITH m, sum(coalesce(h.frequency, 0)) AS totalTagCount
SET m.totalTagCount = totalTagCount
RETURN count(m) AS movieCount
```

### V10 - verifica embedding

```cypher
MATCH (t:Tag)
WHERE t.name IN $tags
  AND t.embedding IS NOT NULL
RETURN count(t) AS embeddedTagCount
```

La migrazione e' un upsert, ma non elimina `Tag` o `HAS_TAG` obsoleti. Il numero runtime e' `8 + ceil(tag/100) + tentativi V01`.

## 11. Query operative aggiuntive

### O01 - seed utente demo

File: `backend/scripts/seedInitialUsers.js`.

```cypher
MERGE (u:AppUser {emailNormalized: $emailNormalized})
ON CREATE SET u.uid = $uid,
              u.email = $email,
              u.displayName = $displayName,
              u.passwordHash = $passwordHash,
              u.createdAt = datetime(),
              u.onboardingCompleted = false,
              u.roles = ['USER']
ON MATCH SET u.passwordHash = $passwordHash
RETURN u.uid AS uid
```

Credenziali hardcoded: `demo@example.com` / `password`. E' pensato come seed locale, ma non ha guardie su `NODE_ENV` o host e opera sulla connessione Neo4j configurata; ogni esecuzione rigenera e riscrive l'hash.

### O02 - batch per valutazione offline

```cypher
MATCH (batch:RecommendationBatch)-[included:INCLUDED]->(movie:Movie)
WHERE batch.createdAt >= datetime() - duration({days: $days})
RETURN batch.id AS batchId,
       coalesce(batch.experimentVariant, 'control-v1') AS variant,
       coalesce(included.source, 'unknown') AS source,
       included.position AS position,
       included.action AS action,
       movie.tmdbId AS tmdbId
ORDER BY batchId, position
```

### O03 - dimensione catalogo per coverage

```cypher
MATCH (movie:Movie)
WHERE movie.tmdbId IS NOT NULL
RETURN count(movie) AS totalMovies
```

`evaluate_recommendations.js` calcola in JavaScript precision sui risultati disponibili fino a un massimo di 10, MRR, NDCG@10, catalog coverage e risultati per variante. Per batch con meno di 10 elementi, il denominatore della precisione e' la lunghezza del batch, non 10. Le azioni rilevanti sono `like`, `watchlist`, `seen`.

### O04 - health check Docker

```cypher
RETURN 1
```

Viene eseguita da `cypher-shell` nel health check del container Neo4j. Verifica autenticazione ed esecuzione minima, non schema o stato degli indici.

## 12. Console Neo4j e diagnostica

Le route sotto `/debug/neo4j` richiedono JWT e `ENABLE_NEO4J_DEBUG=true`. Non esiste un controllo di ruolo amministratore: quando il flag e' attivo, ogni utente autenticato puo' usarle.

### 12.1 Overview

`GET /debug/neo4j/overview` lancia `D01-D06` in parallelo, poi una `D07` per label e una `D08` per tipo relazione. Con `L` label e `R` tipi, il costo e' `6 + L + R` query.

```cypher
// D01 - versione ed edition
CALL dbms.components()
YIELD name, versions, edition
RETURN name, versions[0] AS version, edition

// D02 - nodi totali
MATCH (n)
RETURN count(n) AS count

// D03 - relazioni totali
MATCH ()-[r]->()
RETURN count(r) AS count

// D04 - label
CALL db.labels()
YIELD label
RETURN label
ORDER BY label

// D05 - tipi relazione
CALL db.relationshipTypes()
YIELD relationshipType
RETURN relationshipType
ORDER BY relationshipType

// D06 - numero property key
CALL db.propertyKeys()
YIELD propertyKey
RETURN count(propertyKey) AS count

// D07 - ripetuta per ogni label restituita da D04
MATCH (n:`<label>`) RETURN count(n) AS count

// D08 - ripetuta per ogni tipo restituito da D05
MATCH ()-[r:`<relationshipType>`]->() RETURN count(r) AS count
```

Gli identificatori di `D07-D08` vengono dai metadati del database, non dalla request, e sono racchiusi fra backtick.

### 12.2 Schema topologico

### D09

```cypher
MATCH (a)-[r]->(b)
WITH labels(a) AS fromLabels,
     type(r) AS relType,
     labels(b) AS toLabels,
     count(*) AS count
RETURN fromLabels, relType, toLabels, count
ORDER BY count DESC
```

Route: `GET /debug/neo4j/schema`. Restituisce i pattern realmente presenti, non quelli solo definiti dai constraint.

### 12.3 Indici e constraint

`GET /debug/neo4j/indexes` esegue `D10-D11` in parallelo.

```cypher
// D10
SHOW INDEXES
YIELD name, type, entityType, labelsOrTypes, properties,
      state, populationPercent, indexProvider, options
RETURN name, type, entityType, labelsOrTypes, properties,
       state, populationPercent, indexProvider, options
ORDER BY type, name

// D11
SHOW CONSTRAINTS
YIELD name, type, entityType, labelsOrTypes, properties
RETURN name, type, entityType, labelsOrTypes, properties
ORDER BY name
```

`D10` mostra anche dimensioni e funzione di similarita' del vector index.

### 12.4 Query arbitraria read-only

### D12

```cypher
<testo inserito dall'utente>

// oppure
EXPLAIN <testo>

// oppure
PROFILE <testo>
```

- Route: `POST /debug/neo4j/query`
- Funzione: `neo4jDebugController.query`
- Transazione: `neo4jService.executeRead`
- Parametri Cypher separati: non supportati
- Righe restituite al client: massimo 200, taglio applicato dopo l'esecuzione
- Modalita' speciali: `explain`, `profile`

Non esistono parser, allowlist di keyword, denylist o timeout per query. La protezione dalle scritture dipende dall'access mode READ e dai privilegi dell'utente Neo4j del backend. `PROFILE` esegue davvero la lettura e puo' essere costoso. Gli errori Cypher sono restituiti con codice driver e possono rivelare dettagli dello schema.

La serializzazione converte `neo4j.Integer` in number quando sicuro e in stringa altrimenti; gestisce inoltre nodi, relazioni, path, valori temporali e piani `EXPLAIN/PROFILE`.

### 12.5 Percorso Flutter

`Neo4jDebugService` non contiene credenziali o Bolt. Chiama:

```text
getOverview()           -> GET  /debug/neo4j/overview
getSchema()             -> GET  /debug/neo4j/schema
getIndexes()            -> GET  /debug/neo4j/indexes
runQuery(query, mode)   -> POST /debug/neo4j/query
getRecommendationEngine() -> GET /me/recommendations/debug-stats
```

Usa il JWT, tenta un refresh una volta su HTTP 401 e applica un timeout client di 30 secondi. Il timeout HTTP non garantisce la cancellazione della query sul server. L'ultimo endpoint richiede `ENABLE_RECOMMENDATION_DEBUG=true`, indipendentemente da `ENABLE_NEO4J_DEBUG`.

### 12.6 Preset della schermata Recommendation Lab

La tab Query definisce sei query dimostrative. Sono inoltrate a `D12`, non eseguite direttamente da Flutter su Neo4j.

**P01 - top film MovieLens**

```cypher
MATCH (m:Movie)
WHERE m.movieLensRatingCount IS NOT NULL
RETURN m.title AS titolo,
       m.movieLensAvgRating AS rating,
       m.movieLensRatingCount AS voti
ORDER BY voti DESC
LIMIT 10
```

**P02 - like per utente**

```cypher
MATCH (u:AppUser)-[:LIKED]->(m:Movie)
RETURN u.displayName AS utente,
       count(m) AS like,
       collect(m.title)[..5] AS esempi
ORDER BY like DESC
LIMIT 10
```

**P03 - collaborative filtering semplificato**

```cypher
MATCH (me:AppUser)-[:LIKED]->(:Movie)<-[:MATCHES_TMDB]-(seed:MovieLensMovie)
MATCH (seed)<-[r1:RATED]-(sim:MovieLensUser)-[r2:RATED]->
      (rec:MovieLensMovie)-[:MATCHES_TMDB]->(m:Movie)
WHERE r1.rating >= 4.0
  AND r2.rating >= 4.0
  AND NOT (me)-[:LIKED|ALREADY_SEEN]->(m)
RETURN m.title AS consiglio,
       count(DISTINCT sim) AS utentiSimili,
       round(avg(r2.rating), 2) AS ratingMedio
ORDER BY utentiSimili DESC, ratingMedio DESC
LIMIT 10
```

E' didattica e non coincide con `M23`: non usa UID, pesi, decay, shrinkage o penalita' complete.

**P04 - tag vicini a `funny`**

```cypher
MATCH (t:Tag {name: 'funny'})
CALL db.index.vector.queryNodes('tag_embeddings', 8, t.embedding)
YIELD node, score
RETURN node.name AS tag, round(score, 3) AS similarita
ORDER BY score DESC
```

Mostra lo score Neo4j non trasformato, arrotondato a tre decimali, mentre il codice applicativo usa `2 * score - 1`.

**P05 - bridge MovieLens/TMDB**

```cypher
MATCH (ml:MovieLensMovie)-[:MATCHES_TMDB]->(m:Movie)
RETURN m.title AS titolo,
       m.tmdbId AS tmdbId,
       ml.movieLensId AS movieLensId
LIMIT 10
```

**P06 - tag frequenti**

```cypher
MATCH (ml:MovieLensMovie)-[h:HAS_TAG]->(t:Tag)
RETURN t.name AS tag,
       sum(h.frequency) AS frequenza
ORDER BY frequenza DESC
LIMIT 15
```

Il placeholder `MATCH (n) RETURN n LIMIT 10` mostrato nell'editor non viene eseguito automaticamente e non e' incluso nei sei preset.

## 13. Docker e ambiente locale

### 13.1 Ordine dei servizi

```text
neo4j healthy
  -> neo4j-init completa I01-I12
  -> semantic-init completa V01-V10
  -> backend esegue N01-N18 e si avvia
  -> frontend usa il backend HTTP
```

`neo4j` espone HTTP/Browser su `7474` e Bolt su `7687`, persiste `/data` nel volume `neo4j_data` e monta il dataset in `/var/lib/neo4j/import`. Il backend nel Compose usa `bolt://neo4j:7687` e database `neo4j`.

### 13.2 Variabili piu' importanti

| Gruppo | Variabili |
|---|---|
| Connessione | `NEO4J_URI`, `NEO4J_USERNAME`, `NEO4J_PASSWORD`, `NEO4J_DATABASE` |
| Debug | `ENABLE_NEO4J_DEBUG`, `ENABLE_RECOMMENDATION_DEBUG` |
| Limite Daily | `ENABLE_DAILY_SWIPE_LIMIT`, `DAILY_SWIPE_LIMIT` |
| Motore | soglie collaborative, semantiche, RRF, A/B e cache documentate in `.env.example` |
| Embedding | `EMBEDDING_MODEL_ID`, `EMBEDDING_MODEL_REVISION` |
| Dataset | `MOVIELENS_DATA_DIR` |

Il root `.env.example` copre piu' parametri del template `backend/.env.example`. Il dataset Docker predefinito e' `ml-latest-small`; conteggi storici di circa 87.000 film non descrivono quel dataset e non devono essere presentati come risultato garantito del setup standard.

## 14. Flussi end-to-end da presentare

### 14.1 Registrazione e onboarding

```text
POST /auth/register
  -> A01 cerca email
  -> bcrypt
  -> A02 crea AppUser
  -> JWT

PATCH /me/onboarding
  -> M17 sostituisce PREFERS_GENRE
  -> TMDB + M01/M04 idratano i preferiti
  -> M16 crea SELECTED_FAVORITE
  -> A12 aggiorna onboardingCompleted
```

Le operazioni onboarding non sono atomiche tra loro.

### 14.2 Swipe Daily

```text
GET Daily
  -> M14 quota odierna
  -> M23 collaborativo
  -> M24-M25 semantico
  -> M26 esposizioni ignorate
  -> RRF in JavaScript
  -> M27 componente esplorativa
  -> M02/M01 idratazione
  -> M11 retention + M12 batch

POST impressioni
  -> M13

POST like/dislike/watchlist/seen
  -> M05 contesto batch
  -> M06 quota
  -> M08 rimuove conflitti
  -> M01 upsert film
  -> M09 nuova relazione
  -> M10 azione sull'inclusione
```

Le query effettivamente scelte fra `M05-M10`, insieme a `M01`, condividono una write transaction: `M05-M06` sono alternative a `M07`, mentre `M10` richiede un contesto valido. Il batch e' cio' che rende verificabili fonte, posizione, impressione e azione.

### 14.3 Collaborative filtering

```text
AppUser --segnale positivo--> Movie
Movie <-MATCHES_TMDB- MovieLensMovie
MovieLensMovie <-RATED- MovieLensUser simile
MovieLensUser simile -RATED-> altro MovieLensMovie
altro MovieLensMovie -MATCHES_TMDB-> candidato Movie
```

`M23` pesa intensita' e recenza del segnale, rating dell'utente MovieLens, rarita' del seed, supporto dei vicini e generi disliked.

### 14.4 Raccomandazione semantica

```text
azioni AppUser
  -> tag HAS_TAG dei film coinvolti
  -> centroide positivo e negativo 384D
  -> tag_embeddings cosine search
  -> MovieLensMovie dei tag vicini
  -> MATCHES_TMDB
  -> Movie candidati
```

`V07-V09` materializzano frequenza, IDF e totale tag in anticipo; `M24-M25` possono quindi calcolare lo score senza attraversare tutte le relazioni `TAGGED` a ogni richiesta.

### 14.5 Movie Night

```text
S17 crea evento e host
S18 invita partecipanti
S34 costruisce gusto semantico del gruppo
S38/S39 genera candidati
S40 legge preferenze di ogni partecipante
JavaScript calcola compatibilityScore
S35 salva la shortlist
S44 salva ogni voto
S41-S43 gestiscono tie-break oppure S45 salva il vincitore
S48 crea notifiche
```

Questo flusso mostra il vantaggio del grafo: preferenze individuali, dataset esterno, candidati e voto di gruppo sono collegati senza tabelle ponte applicative separate.

## 15. Sicurezza, prestazioni e caveat

### 15.1 Sicurezza

- Le query applicative parametrizzano tutti i valori.
- I tipi relazione dinamici sono allowlisted.
- I campi dinamici di profilo e privacy sono allowlisted.
- Flutter non possiede credenziali Neo4j.
- La console e' read-transaction, ma non ha controllo admin, parser, timeout server o limite preventivo.
- `ENABLE_NEO4J_DEBUG` deve rimanere disabilitato fuori da demo e sviluppo.
- `S35-S36` possono essere attivate anche da un partecipante pending; la generazione shortlist non richiede ruolo host.
- `S44` puo' riportare a voting un evento waiting o completed; voti non riconosciuti diventano `neutral`.
- `S47` puo' riaprire un evento anche quando `S46` non ha eliminato un voto.
- La cancellazione account non revoca refresh token gia' firmati.

### 15.2 Prestazioni

- I constraint coprono gli identificatori usati dai lookup principali.
- `N11` supporta retention e metriche dei batch.
- `N15` supporta il pool esplorativo.
- `tag_embeddings` evita una scansione lineare degli embedding.
- `M23` e' la query runtime piu' complessa: attraversa seed, utenti MovieLens, rating e candidati, con aggregazioni e ordinamenti.
- `S25` riduce i round trip con pattern comprehension, ma puo' produrre payload ampi.
- `S49` non pagina le notifiche.
- `N16`, `N18`, `D02`, `D03` e `D09` possono scandire porzioni ampie del grafo.
- Il limite 200 della console e' applicato dopo la materializzazione del risultato.

### 15.3 Coerenza e atomicita'

- `setMovieInteraction`, `leaveMovieNight` e `submitVote` hanno confini transazionali espliciti.
- Batch retention/creazione, onboarding, generazione shortlist, notifiche e cancellazione voto sono workflow multi-auto-commit.
- Non esiste una transazione distribuita tra TMDB, Neo4j e Socket.IO.
- `M17` con una lista vuota modifica il grafo ma puo' restituire nessuna riga.
- `S35` con candidati vuoti elimina la shortlist ma non esegue i `SET` successivi.
- Import e migrazione sono upsert idempotenti, non sincronizzazioni distruttive.

### 15.4 Disallineamenti da non nascondere in presentazione

- `GET /movies/recommendations` e' un feed TMDB top-rated arricchito; il vero motore e' sotto `/me/recommendations`.
- Il preset collaborativo `P03` e' didattico e molto piu' semplice di `M23`.
- Il preset vector `P04` cerca tag simili, mentre `M25` e `S38` producono film.
- Lo startup tollera il fallimento dell'indice vettoriale, ma il job Docker `semantic-init` no.
- `ml-latest-small` non produce i conteggi storici da circa 87.000 film.
- I pesi watchlist sono `1.25` nel collaborativo/generi e `1.5` nel semantico/tag.
- La lingua di una Movie Night viene salvata, ma `S38-S39` non la applicano nel filtro Cypher.

## 16. File sorgente di riferimento

| Area | File |
|---|---|
| Driver, schema, sessioni | `backend/neo4jService.js` |
| Auth, profilo, privacy | `backend/authController.js` |
| Route | `backend/server.js` |
| Film e raccomandazioni | `backend/movieController.js`, `backend/movieRepository.js` |
| Social e Movie Night | `backend/socialController.js`, `backend/socialRepository.js` |
| Console backend | `backend/neo4jDebugController.js` |
| Console Flutter | `lib/services/neo4j_debug_service.dart`, `lib/features/debug/presentation/neo4j_console_screen.dart` |
| Import | `backend/scripts/import_movielens.cypher` |
| Embedding | `backend/embeddingService.js`, `backend/scripts/migrate_tags_to_vector.js` |
| Valutazione | `backend/scripts/evaluate_recommendations.js` |
| Ambiente | `docker-compose.yml`, `.env.example`, `backend/.env.example` |

## 17. Scaletta tecnica breve per la presentazione

1. Mostrare i due mondi separati: `AppUser/Movie` e `MovieLensUser/MovieLensMovie`.
2. Evidenziare il bridge `MATCHES_TMDB` e spiegare perche' evita il title matching.
3. Mostrare una query semplice indicizzata, per esempio `M03`.
4. Mostrare il percorso collaborativo di `M23`.
5. Mostrare `Tag.embedding`, `HAS_TAG`, vector index e `M25`.
6. Mostrare `RecommendationBatch-INCLUDED` per spiegare osservabilita', limite Daily e metriche.
7. Mostrare il sottografo Movie Night e il passaggio da shortlist a voto.
8. Chiudere con transazioni, parametri, constraint e limiti reali del sistema.
