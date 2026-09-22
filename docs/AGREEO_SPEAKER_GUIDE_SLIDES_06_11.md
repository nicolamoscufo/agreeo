# 🎙️ Agreeo Presentation Speaker Guide (Part 2: Slides 06 – 11)
## Complete Word-for-Word Oral Defense Script, Deep Technical Analysis & Examination Q&A

> **Document Type:** Official Oral Presentation Script & Architectural Defense Manual  
> **Speaker Role:** Speaker 2 (Platform Engineering, ACID Transactions, Group Concurrency, Query Engineering & Live Demo)  
> **Coverage:** Slide 06 through Slide 11 + Handover from Slide 05  
> **Language:** English  
> **System:** Agreeo — Graph-Native Social Decision & Movie Recommendation Engine  
> **Core Technologies:** Neo4j 5.x, Cypher, APOC Core, Node.js Backend, Flutter Recommendation Lab  

---

## 🧭 Speaker 2 Overview & Timing Breakdown

| Slide | Title / Theme | Allocated Time | Core Technical Mission |
| :---: | :--- | :---: | :--- |
| **05 $\to$ 06** | **Handover & Introduction** | 0:20 | Seamless transition from single-user AI recommendations to multi-user transactional engineering. |
| **06** | **Transactional Integrity: Atomic Daily Interaction [M06]** | 1:20 | Explain the 3-step swipe pipeline (`M06`, `M08`, `M09`), managed `executeWrite`, and implicit write locks. |
| **07** | **Social Graph: Symmetric Friendships & Invariants [S06]** | 1:00 | Contrast undirected double-linked storage ($O(1)$, 34-byte record) with SQL tables; database-level block invariants. |
| **08** | **Movie Night: Group Matrix [S40] & Voting Lock [S44]** | 1:30 | Explain read model matrix generation (`S40`), backend scoring formula, tie-breakers, and pessimistic event lock (`S44`). |
| **09** | **Query Engineering: Subquery Isolation & Plan Inspection** | 1:20 | Demolish the Cartesian product anti-pattern ($10^6 \to 1$ row); explain `EXPLAIN` vs `PROFILE` and `DbHits`. |
| **10** | **Integrity, Security & Honest Architectural Trade-offs** | 1:00 | 100% parameterization against Cypher injection, relationship allowlisting, defensive `UNWIND []`, and driver timeouts. |
| **11** | **Conclusions, Key Takeaways & Live Demo Launch** | 1:00 | The Graph as an in-engine computation platform; transition to in-app Recommendation Lab (`P05`, `P03`, `P04`). |
| **Total** | **Full Speaker 2 Section** | **~7:30** | Balanced, authoritative, academically rigorous presentation. |

---

<!-- ====================================================================== -->
# 🎬 THE HANDOVER TRANSITION (Slide 05 $\to$ Slide 06)
<!-- ====================================================================== -->

### 🗣️ Word-for-Word Spoken Transition (0:20)
> *"Thank you, [Colleague's Name]. Up to this point, we have explored how Agreeo's recommendation engine reasons and computes hyper-personalized recommendations for the individual user using collaborative filtering and vector semantic search.*
> 
> *Now, we turn to the second pillar of our system: **how Agreeo guarantees transactional integrity, orchestrates real-time group consensus, and optimizes execution performance under high concurrency**. We begin with the most frequent and latency-sensitive user action on our platform: **the Swipe** (Slide 6)."*

---

<!-- ====================================================================== -->
# 📌 SLIDE 06: Transactional Integrity: Atomic Daily Interaction
<!-- ====================================================================== -->

### 🎯 Key Objective
Prove that swiping is not a loose key-value write, but an **ACID transaction** that enforces business quota limits, cleanses mutually exclusive states, and records high-precision timestamps for collaborative filtering decay.

```cypher
// STEP 1: Query [M06] - Atomic Daily Quota Increment
MATCH (u:AppUser {uid: $uid})
MERGE (quota:DailySwipeQuota {key: $quotaKey})
ON CREATE SET quota.uid = $uid,
              quota.day = date($day),
              quota.used = 0,
              quota.createdAt = datetime()
MERGE (u)-[:HAS_DAILY_QUOTA]->(quota)
SET quota.used = coalesce(quota.used, 0) + $increment
RETURN quota.used AS usedToday;

// STEP 2: Query [M08] - Invariant State Cleanup (Mutual Exclusion)
MATCH (u:AppUser {uid: $uid})-[r:LIKED|DISLIKED|WATCHLISTED|ALREADY_SEEN]->(m:Movie {tmdbId: $tmdbId})
WHERE type(r) <> $newAction
DELETE r;

// STEP 3: Query [M09] - Materialize Action Edge
MATCH (u:AppUser {uid: $uid}), (m:Movie {tmdbId: $tmdbId})
MERGE (u)-[r:LIKED]->(m)
SET r.createdAt = datetime();
```

---

### 🗣️ Word-for-Word Spoken Script for Slide 06 (1:20)
> *"On a modern mobile client, users swipe cards rapidly—often several dozen times per minute. If each swipe were handled as an isolated write, the system would immediately suffer from race conditions on daily quotas and corrupt the graph with conflicting states—such as a film simultaneously marked as 'Liked' and 'Disliked'.*
> 
> *To prevent this, every swipe in Agreeo runs inside a strict, managed ACID transaction executing a three-step pipeline:*
> 
> *1. **Atomic Quota Increment (Query M06):** Before touching the movie, the query matches a dedicated `DailySwipeQuota` node identified by the deterministic key `uid:YYYY-MM-DD`. By updating `quota.used = coalesce(quota.used, 0) + 1`, Neo4j acquires an **implicit exclusive write lock** on the counter. If the user exceeds the daily threshold—such as 50 free swipes—the backend throws an exception, and the entire transaction rolls back instantly.*
> 
> *2. **State Cleanup & Mutual Exclusion (Query M08):** We enforce the domain rule that a user cannot hold conflicting opinions on the same film. If an incoming swipe is 'Like', Query M08 purges any existing 'Dislike' edge via `DELETE r`, ensuring the graph remains mathematically sound.*
> 
> *3. **Edge Materialization (Query M09):** Finally, we materialize the new interaction edge with `MERGE` and stamp it with `datetime()`. This timestamp is critical, as it feeds directly into the exponential temporal decay formula of Query M23.*
> 
> *All three queries execute inside Neo4j's **`executeWrite`** managed transaction pattern, guaranteeing automatic rollback on errors and automatic retry on transient concurrency conflicts."*

---

### 🔬 Deep Technical Breakdown & Examination Q&A (Slide 06)

#### Q1: "What is an 'implicit lock' in Query M06, and how does it differ from explicit locking?"
* **Answer:** An **implicit lock** is acquired automatically by the Neo4j Storage Engine whenever any write operation (`SET`, `CREATE`, `DELETE`, `MERGE`) modifies a record in memory or disk. In Query M06, when Neo4j executes `SET quota.used = ...`, the kernel's Lock Manager immediately grants an **Exclusive Write Lock** on that `DailySwipeQuota` node ID. Any concurrent swipe from the same user is queued in FIFO order until the transaction commits. It is *implicit* because the Cypher query did not ask for a lock; the database engine applied it automatically to preserve ACID Isolation.

#### Q2: "Can `ALREADY_SEEN` and `LIKED` coexist on the same movie?"
* **Answer:** **Yes, absolutely!** They answer two completely orthogonal domain questions:
  * **Viewing Status:** Did you watch it? (`ALREADY_SEEN` vs `WATCHLISTED`)
  * **Taste Preference:** Did you like it? (`LIKED` vs `DISLIKED`)
  In `backend/movieRepository.js`, `likeMovie` only purges `DISLIKED` (leaving `ALREADY_SEEN` intact), and `markMovieAsSeen` only purges `WATCHLISTED` (leaving `LIKED` intact). In contrast, `LIKED` and `DISLIKED` are mutually exclusive, as are `WATCHLISTED` and `ALREADY_SEEN`.

#### Q3: "What are the core benefits of the `executeWrite` pattern?"
* **Answer:**
  1. **Automatic Transaction Boundary:** Issues `tx.commit()` on success, `tx.rollback()` on exception.
  2. **Transient Error Retry:** If a lock deadlock occurs under high concurrency, the driver transparently retries the entire callback using exponential backoff without crashing the application.
  3. **Cluster Routing:** Automatically routes write transactions to the cluster Leader node while routing `executeRead` to Follower read replicas.
  4. **Connection Pool Safety:** Ensures session cleanup in `finally` blocks, preventing socket leaks.

---

<!-- ====================================================================== -->
# 📌 SLIDE 07: Social Graph: Symmetric Friendships & Invariants
<!-- ====================================================================== -->

### 🎯 Key Objective
Demonstrate how the graph model represents bidirectional friendships using **undirected physical edge storage** ($O(1)$, zero row duplication), and enforces atomic social safety constraints directly within Cypher.

```cypher
// Query [S06] - Atomic Friendship Acceptance & Block Invariants
MATCH (from:AppUser {uid: $uid})
MATCH (to:AppUser   {uid: $targetUserId})
WHERE from.uid <> to.uid
  AND NOT (from)-[:FRIEND]-(to)
  AND NOT (from)-[:BLOCKED]->(to)
  AND NOT (to)-[:BLOCKED]->(from)
MATCH (to)-[r:SENT_FRIEND_REQUEST {status: 'pending'}]->(from)
SET r.status = 'accepted', r.updatedAt = datetime()
MERGE (from)-[a:FRIEND]-(to)          // Undirected: single physical edge
ON CREATE SET a.createdAt = datetime()
RETURN r.requestId;
```

---

### 🗣️ Word-for-Word Spoken Script for Slide 07 (1:00)
> *"Moving to Slide 7, we examine Agreeo's social graph layer through Query S06, which illustrates two fundamental advantages of native graph databases over relational systems:*
> 
> *First is **Undirected Physical Storage**: In a relational SQL database, modeling a symmetric friendship between User A and User B requires either storing two duplicate rows in a join table (`A, B` and `B, A`)—wasting 50% of storage—or writing verbose queries with `OR` conditions. In Neo4j, we declare `MERGE (from)-[:FRIEND]-(to)` without directional arrows. The storage engine allocates **a single 34-byte physical record** with double-linked pointers. Both users traverse the friendship symmetrically in constant time $O(1)$ with zero data duplication.*
> 
> *Second is **Database-Level Invariant Enforcement**: Rather than checking whether a user is blocked using application-level `if` statements in JavaScript—which introduces severe race conditions—we enforce the safety barrier directly in the Cypher transaction: `WHERE NOT (from)-[:BLOCKED]->(to) AND NOT (to)-[:BLOCKED]->(from)`. If a block exists in either direction, the query halts at zero rows, making it physically impossible to instantiate a friendship.*
> 
> *Upon passing all invariants, the pending request is promoted to 'accepted' and the symmetric friendship is materialized atomically."*

---

### 🔬 Deep Technical Breakdown & Examination Q&A (Slide 07)

#### Q1: "How does Neo4j physically store an undirected relationship?"
* **Answer:** Under the hood in `neostore.relationshipstore.db`, every relationship record is 34 bytes long and contains fixed-size pointers: `firstNode`, `secondNode`, `relationshipType`, `firstPrevRelPointer`, `firstNextRelPointer`, `secondPrevRelPointer`, `secondNextRelPointer`, and `propertyPointer`. When Cypher matches `(a)-[:FRIEND]-(b)`, the query planner ignores direction and chases pointers from either node's relationship chain in $O(\text{degree})$ time.

#### Q2: "Why does `SENT_FRIEND_REQUEST` have an arrow (`->`), while `FRIEND` does not?"
* **Answer:** Because a friend request is **asymmetric** (Alice sent it to Bob; Bob did not send it to Alice). The arrow models the workflow direction. Once accepted, the friendship is **symmetric and mutual**, so it is materialized without arrows (`-[:FRIEND]-`).

---

<!-- ====================================================================== -->
# 📌 SLIDE 08: Movie Night: Group Matrix & Concurrent Voting
<!-- ====================================================================== -->

### 🎯 Key Objective
Present Agreeo's flagship social feature: real-time collaborative decision making. Explain the **Read Model** (Query `S40` batch matrix generation), the **Backend Scoring Formula**, and the **Write Model** (Query `S44` with Pessimistic Event Write Lock).

```cypher
// READ MODEL: Query [S40] - Group Social Compatibility Matrix
MATCH (u:AppUser) WHERE u.uid IN $userIds
MATCH (m:Movie)   WHERE m.tmdbId IN $candidateIds
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
       max(rated.rating) AS rating;

// WRITE MODEL: Query [S44] - Concurrent Voting with Pessimistic Lock
MATCH (user:AppUser {uid: $uid})-[part:PARTICIPATES_IN]->(event:MovieNight {id: $eventId})
MATCH (event)-[rel:HAS_CANDIDATE]->(movie:Movie {tmdbId: $tmdbId})
WHERE part.status = 'joined'
  AND (rel.eliminated IS NULL OR NOT rel.eliminated)
MERGE (user)-[v:VOTED_IN {eventId: $eventId}]->(movie)
ON CREATE SET v.createdAt = datetime()
SET v.vote = $vote,
    v.updatedAt = datetime(),
    event.status = 'voting',
    event.updatedAt = datetime() // FORCES EXCLUSIVE WRITE LOCK ON EVENT NODE!
RETURN movie.tmdbId AS tmdbId
LIMIT 1;
```

---

### 🗣️ Word-for-Word Spoken Script for Slide 08 (1:30)
> *"On Slide 8, we present Agreeo's flagship group feature: **'Movie Night'**, where friends synchronize their tastes in real time to pick what to watch together. This architecture cleanly decouples an intensive Read Model from a highly concurrent Write Model:*
> 
> *On the **Read side (Query S40)**, we generate the **Group Social Compatibility Matrix**. By matching the set of participants against candidate movies without edge constraints, Cypher generates the coordinates of a 2D matrix ($U \times M$). Then, a chain of `OPTIONAL MATCH` clauses acts like left joins, extracting likes, dislikes, watchlists, and seen states across all friends in a **single database round-trip**.*
> 
> *Our Node.js backend processes this raw matrix to compute a **Compatibility Score** for each film: rewarding watchlist saves with **+4 points**, likes with **+3 points**, but imposing an aggressive **-15 point veto penalty** on dislikes to ensure no participant's evening is ruined.*
> 
> *On the **Write side (Query S44)**, when four friends cast ballots simultaneously on their mobile screens, we face high write concurrency. We eliminate race conditions and lost updates by taking an explicit **Pessimistic Write Lock**: the statement `SET event.updatedAt = datetime()` forces Neo4j's Lock Manager to place an exclusive write lock on the root `(:MovieNight)` node.*
> 
> *Incoming ballots are queued automatically in a **FIFO wait queue** at the database kernel level, guaranteeing deterministic tallying without complex external distributed mutexes."*

---

### 🔬 Deep Technical Breakdown & Examination Q&A (Slide 08)

#### Q1: "Who calculates the compatibility score, Cypher or the Backend?"
* **Answer:** **The Node.js backend** (`calculateCompatibility` in `backend/socialRepository.js:1489`). 
  * **Why this separation?**
    1. **Separation of Concerns:** Neo4j is optimized for graph traversal (Query `S40`); Node.js is optimized for business logic and arithmetic scoring.
    2. **Maintainability:** Algorithmic weights (e.g. changing the dislike veto from -15 to -20) can be modified without altering database queries.
    3. **UI Explainability:** The backend generates descriptive human-readable tags (e.g. *"Saved by 3 friends"*, *"Liked by majority"*) while calculating scores.
    4. **CPU Offloading:** Sorting 150 candidate objects in Node.js RAM takes $< 1\text{ ms}$, sparing database CPU cycles.

#### Q2: "What happens if group voting ends in a tie?"
* **Answer:** The system triggers an automated **Tie-Breaker workflow** (`startTieBreaker`):
  1. Non-tied candidates are marked with `SET rel.eliminated = true`.
  2. The room advances to Round 2 (`SET event.round = 2`).
  3. Previous votes on tied movies are cleared, launching a head-to-head runoff.
  4. If tied again after `MAX_TIE_BREAKER_ROUNDS = 2`, a **deterministic fallback** elects the movie with the most group watchlist saves $\to$ most likes $\to$ highest TMDB score.

---

<!-- ====================================================================== -->
# 📌 SLIDE 09: Query Engineering: Cardinality & Plan Inspection
<!-- ====================================================================== -->

### 🎯 Key Objective
Demonstrate master-level query optimization by contrasting the catastrophic **Cartesian Explosion Anti-Pattern** ($1,000,000$ rows) with **Query `[M22]` Subquery Isolation** ($1$ row), and explaining **Plan Inspection** with `EXPLAIN` and `PROFILE`.

```cypher
// THE SOLUTION: Query [M22] - Subquery Isolation (Constant Cardinality = 1)
MATCH (u:AppUser {uid: $uid})
CALL {
  WITH u
  MATCH (u)-[:LIKED]->(m:Movie)
  RETURN collect(m.tmdbId) AS likedIds
}
CALL {
  WITH u
  MATCH (u)-[:DISLIKED]->(m:Movie)
  RETURN collect(m.tmdbId) AS dislikedIds
}
CALL {
  WITH u
  MATCH (u)-[:WATCHLISTED]->(m:Movie)
  RETURN collect(m.tmdbId) AS watchlistIds
}
CALL {
  WITH u
  MATCH (u)-[:ALREADY_SEEN]->(m:Movie)
  RETURN collect(m.tmdbId) AS seenIds
}
RETURN likedIds, dislikedIds, watchlistIds, seenIds;

// THE ANTI-PATTERN: Produces 100 * 20 * 50 * 10 = 1,000,000 Intermediate Rows!
MATCH (u:AppUser {uid: $uid})
OPTIONAL MATCH (u)-[:LIKED]->(m1:Movie)
OPTIONAL MATCH (u)-[:DISLIKED]->(m2:Movie)
OPTIONAL MATCH (u)-[:WATCHLISTED]->(m3:Movie)
OPTIONAL MATCH (u)-[:ALREADY_SEEN]->(m4:Movie)
RETURN collect(m1), collect(m2), collect(m3), collect(m4);
```

---

### 🗣️ Word-for-Word Spoken Script for Slide 09 (1:20)
> *"Turning to Slide 9, we enter the domain of query engineering and physical execution plan inspection.*
> 
> *In graph database engines, execution cost and memory consumption are not determined by how many rows you return at the end, but by **intermediate row cardinality**—the volume of transient tuples accumulated in RAM during the pipeline.*
> 
> *On the left, we highlight the most dangerous anti-pattern in Cypher: chaining multiple unconstrained `OPTIONAL MATCH` clauses. If an active user has 100 likes, 20 dislikes, 50 watchlist items, and 10 seen movies, these streams do not add together—they multiply. The pipeline explodes into **1,000,000 intermediate rows** in JVM heap memory! Even though there are only 180 actual movies, the database suffers severe Garbage Collection pauses and risks Out-of-Memory crashes.*
> 
> *On the right, we present our optimized architecture in **Query M22**: we isolate each relationship stream inside an autonomous `CALL { WITH u ... }` subquery. Each subquery executes in an isolated sandbox at cardinality 1, immediately compacting items into an array with `collect()`.*
> 
> *This transforms computational complexity from multiplicative ($O(L \times D \times W \times S)$) to linear ($O(L + D + W + S)$). Intermediate cardinality collapses from **one million rows down to exactly one single row**.*
> 
> *We verify this empirically via **Plan Inspection** using `PROFILE`, ensuring execution begins with an index seek `NodeIndexSeek`, traverses via physical pointers `Expand`, and achieves a 99.9% reduction in `DbHits`, completely eliminating the `CartesianProduct` operator."*

---

### 🔬 Deep Technical Breakdown & Examination Q&A (Slide 09)

#### Q1: "What exactly is a `DbHit` in Neo4j?"
* **Answer:** A **DbHit (Database Hit)** is the fundamental unit of work between the Cypher query runtime and Neo4j's storage engine. A DbHit is triggered whenever the engine fetches a node record, traverses a relationship pointer in the double-linked chain, reads a property block, or queries an index. It is **storage cache-agnostic**: DbHits are counted whether the data is already cached in RAM (Page Cache) or read from SSD disk, making it the true metric of algorithmic efficiency.

#### Q2: "What is the difference between `EXPLAIN` and `PROFILE`?"
* **Answer:**
  * **`EXPLAIN` (Static Analysis):** Compiles the query and outputs the *estimated* plan using count store statistics **without running the query**. It takes $< 2\text{ ms}$, touches zero data, and is safe for inspecting destructive write queries (`DELETE`, `MERGE`) or checking for runaway Cartesian products before execution.
  * **`PROFILE` (Runtime Telemetry):** **Actually executes the query** on disk and RAM. It measures true wall-clock time in milliseconds and displays exact `Rows` and actual `DbHits` for every physical operator.

#### Q3: "Where can we test `EXPLAIN` and `PROFILE` in Agreeo?"
* **Answer:** Inside Agreeo's built-in **Recommendation Lab** mobile console (`Settings -> Developer -> Recommendation Lab -> Query tab`). The UI provides dedicated toggle chips for `[ EXPLAIN ]` and `[ PROFILE ]` that render execution plan trees live!

---

<!-- ====================================================================== -->
# 📌 SLIDE 10: Integrity, Security & Production Trade-offs
<!-- ====================================================================== -->

### 🎯 Key Objective
Showcase defensive security engineering: 100% parameterization against Cypher injection, relationship allowlisting, mitigating the `UNWIND []` pipeline abortion trap, and driver-level circuit breakers.

```cypher
// SECURITY: Parameterized Execution vs Cypher Injection
MATCH (u:AppUser {emailNormalized: $emailNormalized})
RETURN u.uid AS uid, u.email AS email, u.passwordHash AS passwordHash;

// DEFENSIVE PATTERN: Protecting Pipeline from UNWIND [] Abort
WITH $incomingList AS list
UNWIND (CASE WHEN size(list) > 0 THEN list ELSE [null] END) AS item
WITH item WHERE item IS NOT NULL
MATCH (m:Movie {tmdbId: item.id})
MERGE (m)-[:TAGGED]->(...);
```

---

### 🗣️ Word-for-Word Spoken Script for Slide 10 (1:00)
> *"On Slide 10, we address our security architecture and conduct an honest review of production engineering trade-offs.*
> 
> *From a security standpoint, **100% of user-supplied inputs** are bound via parameterized queries (`$params`). This completely separates the Cypher Abstract Syntax Tree from user literals, rendering Cypher injection mathematically impossible. Furthermore, because relationship types cannot be parameterized in native Cypher, our backend enforces a strict compile-time **allowlist** (`INTERACTION_REL_TYPES`), blocking any unauthorized relationship interpolation.*
> 
> *In the spirit of robust systems engineering, we also highlight two practical production caveats:*
> 
> *First is the **`UNWIND []` Pipeline Abortion Trap**: In Cypher semantics, executing `UNWIND` on an empty collection immediately terminates the query pipeline, discarding all downstream operations without raising an error. We mitigated this by engineering the **Defensive UNWIND Pattern**: wrapping incoming arrays in a conditional `CASE` expression guarantees the row stream stays alive even when external APIs return empty lists.*
> 
> *Second, regarding read queries: while `executeRead` blocks write mutations, it is **not a full sandbox**—it does not prevent unindexed scans from exhausting CPU cores. Nor does adding `LIMIT` bound query cost if global aggregations occur upstream. To guarantee cluster resilience, we enforce **strict query timeouts at the driver level**, terminating any runaway transaction exceeding our 5-second ceiling."*

---

<!-- ====================================================================== -->
# 📌 SLIDE 11: Conclusions, Key Takeaways & Live Demo
<!-- ====================================================================== -->

### 🎯 Key Objective
Deliver the grand architectural conclusion: Neo4j is an **In-Engine Computation Platform**, not a passive entity store. Seamlessly launch the interactive Live Demo.

```cypher
// PRESET [P05] - Bridge Verification
MATCH (ml:MovieLensMovie)-[:MATCHES_TMDB]->(m:Movie)
RETURN m.title AS tmdbTitle, m.tmdbId AS tmdbId, ml.movieLensId AS mlId
LIMIT 10;

// PRESET [P03] - Didactic Traversal with PROFILE
PROFILE
MATCH (me:AppUser)-[:LIKED]->(:Movie)<-[:MATCHES_TMDB]-(seed:MovieLensMovie)
MATCH (seed)<-[r1:RATED]-(sim:MovieLensUser)-[r2:RATED]->(rec:MovieLensMovie)-[:MATCHES_TMDB]->(m:Movie)
WHERE r1.rating >= 4.0 AND r2.rating >= 4.0
  AND NOT (me)-[:LIKED|ALREADY_SEEN]->(m)
RETURN m.title AS suggestion,
       count(DISTINCT sim) AS similarUsers,
       round(avg(r2.rating), 2) AS avgRating
ORDER BY similarUsers DESC, avgRating DESC
LIMIT 10;

// PRESET [P04] - Degree Centrality & Genre Aggregation
MATCH (g:Genre)<-[:IN_GENRE]-(m:Movie)
RETURN g.name AS genre, count(m) AS movieCount
ORDER BY movieCount DESC LIMIT 10;
```

---

### 🗣️ Word-for-Word Spoken Script for Slide 11 (1:00)
> *"To conclude our presentation with Slide 11, Agreeo demonstrates that a native graph database like Neo4j is far more than a passive entity store: **it functions as an in-engine, high-performance computation platform**.*
> 
> *By leveraging Index-Free Adjacency, we unified three traditionally fragmented workloads directly inside the database kernel:
> 1. Multi-hop collaborative filtering with temporal decay;
> 2. Dense vector semantic search via HNSW cosine indexing;
> 3. ACID transactional social workflows and concurrent group decision consensus.*
> 
> *To see this architecture in action, we now invite you to our **Live Demonstration**: we will transition to Agreeo's in-app **Recommendation Lab** to execute our benchmark presets (`P05`, `P03`, `P04`) and inspect their live physical execution plans using `PROFILE`.*
> 
> *Thank you very much for your time and attention. We now welcome your questions."*

---

*Compiled by the Agreeo Systems Architecture Team for Academic Examination & Systems Defense.*
