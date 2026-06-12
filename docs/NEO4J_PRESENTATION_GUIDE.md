# Agreeo — Presentation Guide (Neo4j focus)

> Study document for the Data Management exam.
> Goal: explain **what** to say, **in which order**, and above all **why**,
> using the real Cypher taken from the backend code.
>
> Timing rule of thumb: spend ~**70% of the time on Neo4j** (model, schema, indexes,
> queries, demo). The rest (app, architecture) only sets the context.

---

## 0. What to focus on (in order of importance)

1. **Why a graph** instead of SQL/documents → this is the question everything starts from.
2. **The data model**: the "two worlds" (TMDB and MovieLens) and the `MATCHES_TMDB` bridge.
3. **Constraints and indexes** (including the *vector index*) and the reasoning behind them.
4. **The 4 core queries** + the vector bonus: be able to read them line by line.
5. **The live demo** on the Neo4j Console (read-only) with `EXPLAIN`/`PROFILE`.

If the professor interrupts you, these are the things you MUST be solid on:
**index-free adjacency, MERGE vs CREATE, read/write transactions, what each index is for.**

---

## 1. What Agreeo is (30 seconds, then go technical)

An app to **decide as a group what movie to watch**. Everyone expresses their taste
with a "swipe" (like / dislike / watchlist), invites friends to a **Movie Night**,
and the system proposes a **shortlist** to vote on. Recommendations (personal and
group) are computed **inside Neo4j** by combining two datasets.

**Stack:**
- **Frontend:** Flutter (Riverpod state management).
- **Backend:** Node.js / Express + Socket.IO. It is the **only** component that talks
  to TMDB and to Neo4j (no direct access from the client).
- **Database:** **Neo4j 5** (graph database, Cypher query language).
- **Data:** **TMDB** (catalog: posters, search, details) + **MovieLens**
  (~87,000 movies, community ratings and tags, used for recommendations).

Real numbers after the MovieLens import (worth quoting):
- canonical `:Movie`: **87,425**
- raw `:MovieLensMovie`: **87,585**
- `:MATCHES_TMDB` relationships: **87,461**

---

## 2. The graph schema at a glance (ASCII)

```
            APP WORLD  (authenticated users + TMDB catalog)
            ---------------------------------------------------
              (:AppUser {uid})
                  |
                  |  LIKED / DISLIKED / WATCHLISTED
                  |  ALREADY_SEEN / SELECTED_FAVORITE
                  |  RATED_APP {rating, review}
                  v
              (:Movie {tmdbId})  ----IN_GENRE---->  (:Genre)
                  ^
                  |  MATCHES_TMDB        <-- THE BRIDGE (built from links.csv)
                  |
              (:MovieLensMovie {movieLensId})
                  |   \
        IN_GENRE  |    \  HAS_TAG {frequency}
                  v     v
              (:Genre)  (:Tag {embedding[384]})   <-- vector index (cosine)
                  ^
                  |  RATED {rating} / TAGGED
              (:MovieLensUser {movieLensUserId})
            ---------------------------------------------------
            DATASET WORLD  (imported MovieLens, ~87k movies)


   SOCIAL                                 MOVIE NIGHT
   ------                                 -----------
   (:AppUser)-[:FRIEND]-(:AppUser)        (:AppUser)-[:HOSTS]->(:MovieNight)
   (:AppUser)-[:SENT_FRIEND_REQUEST       (:AppUser)-[:PARTICIPATES_IN]->(:MovieNight)
              {status}]->(:AppUser)       (:MovieNight)-[:HAS_CANDIDATE]->(:Movie)
   (:AppUser)-[:BLOCKED]->(:AppUser)      (:AppUser)-[:VOTED_IN {vote}]->(:Movie)
```

---

## 3. Why Neo4j (the central motivation)

This is the most important part. Key idea:

> In Agreeo the data **is** relationships: likes, dislikes, watchlist, ratings, tags,
> friendships, similarity between users and between movies. Modelling them as
> **nodes and edges** is more natural than spreading them across join-heavy tables
> or wide documents.

Three arguments to make:

1. **Index-free adjacency.** In a graph every node "points" directly to its edges.
   Traversing a relationship costs ~`O(node degree)` and does **not** depend on the
   total number of rows in the database. In SQL the same thing would be a chain of
   `JOIN`s whose cost grows with table size.

2. **Recommendations are paths.** "Find users similar to me and recommend their
   movies" is literally a path pattern:
   `(me)-[:LIKED]->(movie)<-[:RATED]-(similarUser)-[:RATED]->(recommendation)`.
   In Cypher you write it almost the way you draw it on a whiteboard.

3. **Flexible schema.** Adding a new interaction type (e.g. `SELECTED_FAVORITE`) is
   just a new edge type: no schema migrations, no proliferation of nullable columns.

**Sentence to say:** *"I chose a graph database because the domain is inherently
relational and the recommendation queries become explicit traversals instead of
multiple joins."*

---

## 4. The data model: the "two worlds" and the bridge

This is the **most important architectural choice** to justify.

There are **two user populations** and **two movie catalogs**, kept separate:

| World | Nodes | Key | Source |
|-------|-------|-----|--------|
| **App** (product) | `:AppUser`, `:Movie` | `uid`, `tmdbId` | authenticated users + TMDB |
| **Dataset** (recommendations) | `:MovieLensUser`, `:MovieLensMovie`, `:Tag` | `movieLensUserId`, `movieLensId`, `name` | MovieLens import |

And a **single point of contact** between the two worlds:

```cypher
(:MovieLensMovie)-[:MATCHES_TMDB]->(:Movie)
```

### Why `:AppUser` and `:MovieLensUser` are separate
- They are **different entities**: a real authenticated user ≠ a user imported from
  the dataset. They must never be merged.
- Keeping **authentication** identities apart from **dataset** identities avoids
  mixing sensitive data (email, password) with imported rows, and keeps the
  recommendation queries **explicit** about which population they touch.

### Why `:Movie` and `:MovieLensMovie` are separate
- TMDB is the **source of truth** for the UI catalog (posters, backdrops, search,
  details, trailers). So the "canonical" movie is `(:Movie {tmdbId})`.
- The MovieLens dataset **cannot** be the canonical catalog: in `links.csv` several
  `movieId` values can map to the **same** `tmdbId` (a direct import had already
  failed for exactly this reason). So the raw rows stay as `(:MovieLensMovie {movieLensId})`.
- The `MATCHES_TMDB` bridge reconciles the two safely.

### Why `tmdbId` is the canonical key and titles are NEVER matched
- The matching path is structural, not textual:
  `MovieLens movieId → links.csv → tmdbId → TMDB movie`.
- **Title matching** is unreliable: alternate titles, localizations, punctuation,
  remasters, franchises with duplicate names, year/version ambiguity. `links.csv`
  already provides a **structured**, clean bridge.

**Sentence to say:** *"I separated the two populations and the two catalogs because
they have different semantics; I stitch them back together with a single
`MATCHES_TMDB` relationship built from `links.csv`, avoiding fragile title matching."*

---

## 5. The graph schema (nodes, relationships, properties)

### Nodes
- `:AppUser {uid, email, emailNormalized, displayName, avatarUrl, bio, canShow*}`
- `:Movie {tmdbId, title, overview, posterPath, genres, movieLensAvgRating, movieLensRatingCount, ...}`
- `:MovieLensUser {movieLensUserId}`
- `:MovieLensMovie {movieLensId, title, totalTagCount, ...}`
- `:Tag {name, embedding}` ← `embedding` is a **384-dimension** vector
- `:Genre {name}`
- `:MovieNight {id, name, status, round, constraints..., inviteLink, winnerMovieId}`

### Relationships — user interactions (app world)
```cypher
(:AppUser)-[:LIKED]->(:Movie)
(:AppUser)-[:DISLIKED]->(:Movie)
(:AppUser)-[:WATCHLISTED]->(:Movie)
(:AppUser)-[:ALREADY_SEEN]->(:Movie)
(:AppUser)-[:SELECTED_FAVORITE]->(:Movie)
(:AppUser)-[:RATED_APP {rating, review, createdAt, updatedAt}]->(:Movie)
(:AppUser)-[:PREFERS_GENRE]->(:Genre)
```

### Relationships — social
```cypher
(:AppUser)-[:FRIEND {createdAt}]-(:AppUser)                       // undirected
(:AppUser)-[:SENT_FRIEND_REQUEST {requestId, status, createdAt}]->(:AppUser)
(:AppUser)-[:BLOCKED {createdAt}]->(:AppUser)
(:AppUser)-[:REPORTED {reportId, reason, status, createdAt}]->(:AppUser)
```

### Relationships — MovieLens dataset + bridge
```cypher
(:MovieLensUser)-[:RATED {rating, timestamp}]->(:MovieLensMovie)
(:MovieLensUser)-[:TAGGED {tag, timestamp}]->(:MovieLensMovie)
(:MovieLensMovie)-[:HAS_TAG {frequency}]->(:Tag)
(:MovieLensMovie)-[:IN_GENRE]->(:Genre)
(:Movie)-[:IN_GENRE]->(:Genre)
(:MovieLensMovie)-[:MATCHES_TMDB]->(:Movie)                       // the bridge
```

### Relationships — Movie Night
```cypher
(:AppUser)-[:HOSTS]->(:MovieNight)
(:AppUser)-[:PARTICIPATES_IN {status, isHost, createdAt}]->(:MovieNight)
(:MovieNight)-[:HAS_CANDIDATE {compatibilityScore, explanationTags, eliminated}]->(:Movie)
(:AppUser)-[:VOTED_IN {eventId, vote, createdAt}]->(:Movie)
```

---

## 6. Constraints and indexes (and the WHY of each)

All created **at backend startup** in `neo4jService.createConstraints()`.
Key message: **"the schema is code"** → reproducible, versioned, idempotent
(`IF NOT EXISTS`).

### Uniqueness constraints (integrity + fast lookup)
```cypher
CREATE CONSTRAINT app_user_uid       IF NOT EXISTS FOR (u:AppUser)        REQUIRE u.uid IS UNIQUE;
CREATE CONSTRAINT app_user_email     IF NOT EXISTS FOR (u:AppUser)        REQUIRE u.emailNormalized IS UNIQUE;
CREATE CONSTRAINT movie_tmdb_id      IF NOT EXISTS FOR (m:Movie)          REQUIRE m.tmdbId IS UNIQUE;
CREATE CONSTRAINT movielens_movie_id IF NOT EXISTS FOR (m:MovieLensMovie) REQUIRE m.movieLensId IS UNIQUE;
CREATE CONSTRAINT movielens_user_id  IF NOT EXISTS FOR (u:MovieLensUser)  REQUIRE u.movieLensUserId IS UNIQUE;
CREATE CONSTRAINT genre_name         IF NOT EXISTS FOR (g:Genre)          REQUIRE g.name IS UNIQUE;
CREATE CONSTRAINT tag_name           IF NOT EXISTS FOR (t:Tag)            REQUIRE t.name IS UNIQUE;
CREATE CONSTRAINT movie_night_id     IF NOT EXISTS FOR (m:MovieNight)     REQUIRE m.id IS UNIQUE;
```
**Why:** a *uniqueness constraint* in Neo4j (a) guarantees **integrity** (no
duplicates) and (b) automatically creates a backing **index**, so key lookups
(`MATCH (m:Movie {tmdbId: $id})`) are `O(1)`. It is also what makes a `MERGE` on
that key safe (see Query 4).

### Range indexes (speed up filters and ORDER BY)
```cypher
CREATE INDEX movie_title           IF NOT EXISTS FOR (m:Movie)          ON (m.title);
CREATE INDEX movielens_movie_title IF NOT EXISTS FOR (m:MovieLensMovie) ON (m.title);
CREATE INDEX movie_ml_rating_count IF NOT EXISTS FOR (m:Movie)          ON (m.movieLensRatingCount);
```
**Why:** `movie_ml_rating_count` avoids a **full scan** when filtering/ordering by
popularity (used by Query 1 "top movies" and by shortlist generation). Show it in
the demo with `PROFILE`: with the index → fewer *db hits*.

### Vector index (semantic search)
```cypher
CREATE VECTOR INDEX tag_embeddings IF NOT EXISTS
FOR (t:Tag) ON (t.embedding)
OPTIONS { indexConfig: {
  `vector.dimensions`: 384,
  `vector.similarity_function`: 'cosine'
}};
```
**Why / details to mention:**
- Indexes the **tag embeddings** (384 dims) for semantic similarity search
  (ANN — *approximate nearest neighbour*).
- Requires **Neo4j ≥ 5.11**, so creation is **best-effort** (wrapped in `try/catch`):
  if the version doesn't support it, the server still starts and only the semantic
  search degrades. Worth highlighting this as a **robustness** choice.

---

## 7. The queries (the technical heart)

For each: *what it does* → *Cypher* → *what to highlight*.
These are the **presets** of the in-app Console, in increasing order of complexity.

### Query 1 — Top movies (simple lookup + ordering)
```cypher
MATCH (m:Movie)
WHERE m.movieLensRatingCount >= 100
RETURN m.title              AS title,
       m.movieLensAvgRating AS avgRating,
       m.movieLensRatingCount AS votes
ORDER BY avgRating DESC, votes DESC
LIMIT 20;
```
**Highlight:** the base case. The filter on `movieLensRatingCount` (≥100) drops
movies with too few votes; the **range index** makes `WHERE` + `ORDER BY`
efficient. Great for showing `EXPLAIN`/`PROFILE` with and without the index.

### Query 2 — Bridge TMDB ↔ MovieLens (traversal)
```cypher
MATCH (m:Movie {tmdbId: $tmdbId})<-[:MATCHES_TMDB]-(ml:MovieLensMovie)
OPTIONAL MATCH (ml)-[:IN_GENRE]->(g:Genre)
OPTIONAL MATCH (ml)<-[r:RATED]-(:MovieLensUser)
RETURN m.title                 AS title,
       collect(DISTINCT g.name) AS genres,
       avg(r.rating)           AS movieLensAvg,
       count(r)                AS movieLensVotes;
```
**Highlight:** I start from a **single** `:Movie` node (`O(1)` lookup thanks to the
`tmdbId` constraint), take **one hop** across the `MATCHES_TMDB` bridge, and from
there reach the whole **MovieLens signal** (genres, ratings). This is the data
enrichment: TMDB catalog + community signal. It shows the power of traversal well.

### Query 3 — Collaborative filtering (the recommendation)
**Faithful but condensed** version (the real one adds more weights and a penalty):
```cypher
// 1) Find MovieLens users who loved the movies I like
MATCH (me:AppUser {uid: $uid})-[signal:LIKED|SELECTED_FAVORITE|WATCHLISTED]->(seed:Movie)
MATCH (seed)<-[:MATCHES_TMDB]-(seedMl:MovieLensMovie)<-[r1:RATED]-(similar:MovieLensUser)
WHERE r1.rating >= 4.0
WITH me, similar,
     sum(
       (CASE type(signal)
          WHEN 'SELECTED_FAVORITE' THEN 4.0
          WHEN 'LIKED'             THEN 3.0
          WHEN 'WATCHLISTED'       THEN 1.5 END)
       * exp(-0.005 * duration.inDays(signal.createdAt, datetime()).days)   // recency
       * (toFloat(r1.rating) - 3.0)                                          // above/below average
       * (1.0 / sqrt(log(coalesce(seed.movieLensRatingCount, 0) + 10.0)))    // rarity
     ) AS similarityScore
WHERE similarityScore > 0

// 2) Recommend THEIR highly-rated movies that I have NOT seen yet
MATCH (similar)-[r2:RATED]->(recMl:MovieLensMovie)-[:MATCHES_TMDB]->(rec:Movie)
WHERE r2.rating >= 4.0
  AND NOT (me)-[:LIKED|DISLIKED|WATCHLISTED|ALREADY_SEEN|SELECTED_FAVORITE]->(rec)
WITH rec,
     (sum(similarityScore * (toFloat(r2.rating) - 3.0)) / sum(similarityScore))
       * log(count(DISTINCT similar) + 1.0) * 10.0 AS collaborativeScore
RETURN rec.title, collaborativeScore
ORDER BY collaborativeScore DESC
LIMIT 20;
```
**The scoring formula (be able to explain every factor):**
- **Signal weight:** `SELECTED_FAVORITE = 4.0`, `LIKED = 3.0`, `WATCHLISTED = 1.5`
  (a favorite counts more than a like).
- **Recency / time decay:** `exp(-0.005 * days)` → older interactions weigh less.
- **`rating - 3.0`:** centers the score on the average (a 5 pushes up, a 2 pushes down).
- **Rarity:** `1 / sqrt(log(numVotes + 10))` → an overlap on a niche movie is more
  informative than on a blockbuster everyone has seen.
- **`collaborativeScore`:** weighted average of the similar users' ratings, times
  `log(#similarUsers + 1)` (more witnesses = more confidence), scaled ×10.
- In the full version: a **penalty on genres the user rejects** (disliked genres),
  subtracted from the final score.

**Highlight:** this is **user-based collaborative filtering** done entirely in Cypher,
using the bridge to move from my world (AppUser/Movie) to the dataset world
(MovieLensUser/MovieLensMovie) and back. The `NOT (me)-[...]->(rec)` clause with
**pattern negation** excludes what I've already seen.

### Query 4 — Friendships as graph writes
The most "database-y" part on the **write** side. When I send a friend request, if an
**opposite pending** request already exists, I accept it **atomically** in the same
query:
```cypher
MATCH (from:AppUser {uid: $uid})
MATCH (to:AppUser   {uid: $targetUserId})
WHERE from.uid <> to.uid
  AND NOT (from)-[:FRIEND]-(to)
  AND NOT (from)-[:BLOCKED]->(to)
  AND NOT (to)-[:BLOCKED]->(from)
MATCH (to)-[r:SENT_FRIEND_REQUEST {status: 'pending'}]->(from)
SET r.status = 'accepted', r.updatedAt = datetime()
MERGE (from)-[a:FRIEND]-(to)          // UNDIRECTED edge, stored only once
ON CREATE SET a.createdAt = datetime()
RETURN r.requestId;
```
**Highlight (exam concepts):**
- **`MERGE` = upsert:** "find-or-create". Guarantees **idempotency**: re-running the
  query creates no duplicates. `ON CREATE SET` sets properties only on first
  creation. It is safe because a uniqueness constraint exists on the node keys.
- **Undirected `:FRIEND` edge:** `MERGE (from)-[:FRIEND]-(to)` (no arrow) → friendship
  is **symmetric**, stored **once**, and queryable in both directions with
  `(a)-[:FRIEND]-(b)`.
- **Guard clauses with pattern negation:** `NOT (from)-[:BLOCKED]->(to)` enforces the
  **domain invariants** (not friends if blocked) **inside the query**, not in the
  application code → fewer race conditions.
- It runs inside a **write transaction** (ACID): all or nothing.

### Bonus — Semantic vector search (outside the course syllabus)
Present this as an "extra" that showcases Neo4j 5 capabilities.
```cypher
CALL db.index.vector.queryNodes('tag_embeddings', $topK, $tasteVector)
YIELD node AS tag, score AS similarity
MATCH (tag)<-[h:HAS_TAG]-(ml:MovieLensMovie)-[:MATCHES_TMDB]->(m:Movie)
MATCH (me:AppUser {uid: $uid})
WHERE NOT (me)-[:LIKED|DISLIKED|WATCHLISTED|ALREADY_SEEN|SELECTED_FAVORITE]->(m)
WITH m, sum(h.frequency * ((2.0*similarity - 1.0) ^ 3)) AS score
RETURN m.title, score
ORDER BY score DESC
LIMIT 20;
```
**Highlight:** I build a **"Taste Vector"** by summing (with weights) the tag
embeddings of the movies I like; `db.index.vector.queryNodes` performs an **ANN
search by cosine similarity** on the vector index; then I climb back to the movies
via `MATCHES_TMDB`. This is "search by mood".

---

## 8. Movie Night as a subgraph (a modelling example)

A group event is a complete, queryable **subgraph**:
```cypher
(host)-[:HOSTS]->(mn:MovieNight)
(user)-[:PARTICIPATES_IN {status, isHost}]->(mn)
(mn)-[:HAS_CANDIDATE {compatibilityScore}]->(:Movie)
(user)-[:VOTED_IN {eventId, vote}]->(:Movie)
```
- The **shortlist** comes from a **Group Taste Vector**: a weighted sum of the tag
  embeddings over **all** joined participants
  (`SELECTED_FAVORITE +4`, `LIKED +3`, `WATCHLISTED +1.5`, `DISLIKED -3`).
- **Votes** and the event **state** are synced in **real time** via Socket.IO.
- Point to make: the same idea as the personal vector filter, **extended to a group**.

---

## 9. The live demo (in-app Neo4j Console)

The demo is done **live**. What to show and say, in order:

1. **Info tab** — Neo4j version/edition, node/relationship counts, nodes per label.
   *"One single database, two worlds: AppUser/Movie from TMDB, MovieLensUser/MovieLensMovie/Tag from the dataset."*
2. **Schema tab** — the real `(:From)-[:REL]->(:To)` patterns: show the `MATCHES_TMDB`
   bridge and the interaction relationships.
3. **Indexes tab** — `SHOW INDEXES` + `SHOW CONSTRAINTS`: highlight the **vector
   index** (384 / cosine).
4. **Query tab** — run the presets in order: Top movies → Bridge → Collaborative
   filtering → (Bonus) Vector search. Then **re-run one query with `PROFILE`** to
   show the execution plan, *estimated rows* and **db hits** (compare with/without
   the index).

**Safety point to state:** the console queries run inside a **read transaction**
(`session.readTransaction`). If you try a write, it is **Neo4j itself** that rejects
it with `Neo.ClientError.Statement.AccessMode`, with no server-side parsing needed.
Plus: results capped at 200 rows, endpoints behind JWT, and an opt-in flag.

---

## 10. Data Management concepts to master (for the Q&A)

- **Index-free adjacency:** why traversal doesn't depend on the total database size.
- **Graph vs Relational:** recommendations as paths vs chains of JOINs.
- **`MATCH` / `MERGE` / `CREATE`:** `MATCH` reads; `CREATE` always creates (duplicate
  risk); `MERGE` is "find-or-create" (idempotent) → used for upserts and for edges
  that must not be duplicated.
- **`OPTIONAL MATCH`:** the graph's "left join" (returns `null` if the pattern is
  missing) → used for counts that can be zero.
- **Pattern negation:** `WHERE NOT (a)-[:REL]->(b)` for exclusions and invariants.
- **Uniqueness constraint:** integrity + implicit index + prerequisite for a safe
  `MERGE`.
- **Index types:** *range* (filters/ordering) vs *vector* (semantic similarity).
- **Transactions:** read vs write transaction; **ACID** properties; automatic driver
  retries (`maxTransactionRetryTime`).
- **Driver / connection pool:** `maxConnectionPoolSize: 50`, a session opened and
  closed per query, transaction functions with retries.
- **`EXPLAIN` vs `PROFILE`:** `EXPLAIN` estimates the plan without executing;
  `PROFILE` executes and reports the real **db hits**.

---

## 11. Likely professor questions (+ short answers)

- **"Why a graph and not a relational DB?"** → Relational domain; recommendations as
  traversals; index-free adjacency; flexible schema.
- **"How do you avoid duplicate friendships?"** → `MERGE` on an undirected edge +
  uniqueness constraint on the nodes; idempotency.
- **"How do you avoid recommending an already-seen movie?"** → pattern negation
  `NOT (me)-[:LIKED|DISLIKED|ALREADY_SEEN|...]->(rec)`.
- **"What are the indexes for here?"** → uniqueness (`O(1)` lookup, integrity), range
  (ORDER BY popularity), vector (semantic similarity). I prove it with `PROFILE`.
- **"Why two kinds of Movie/User?"** → different semantics; `links.csv` maps several
  `movieId` to one `tmdbId`; no title matching; `MATCHES_TMDB` as the bridge.
- **"Is it safe to run queries from the app?"** → read transaction, writes rejected
  by Neo4j (`AccessMode`), row limit, JWT, opt-in flag.
- **"What guarantees write consistency?"** → ACID write transaction; guard clauses in
  Cypher rather than in app code.

---

## 12. Suggested running order (≈10–12 min)

1. What Agreeo is + stack (1 min)
2. **Why Neo4j** (1.5 min) ← don't rush
3. **The two worlds + the bridge** (2 min)
4. **Schema + constraints/indexes** (2 min)
5. **The 4 queries** (3 min) ← the heart
6. Movie Night + (bonus) vector search (1 min)
7. **Live demo** on the Console with `PROFILE` (2 min)
8. Closing/takeaway (30 s)

**Final takeaway to say:** *"One single graph, two worlds stitched together by
`MATCHES_TMDB`; the right indexes (uniqueness, range, vector) for integrity and
performance; and recommendations — personal and group — expressed as traversals and
vector operations directly in Cypher."*

---

## References in the repo (if you want to re-read the code)
- `backend/neo4jService.js` — driver, transactions, **constraints and indexes** at startup.
- `backend/socialRepository.js` — friendships (Query 4), Movie Night, group taste vector.
- `backend/movieRepository.js` — **collaborative filtering** and **vector search**.
- `docs/NEO4J_TMDB_MOVIELENS_ARCHITECTURE.md` — motivation for the two worlds and the bridge.
- `docs/NEO4J_CONSOLE.md` — the debug console and the demo script.
