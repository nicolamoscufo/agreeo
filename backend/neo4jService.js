const neo4j = require('neo4j-driver');
const { AsyncLocalStorage } = require('node:async_hooks');

const queryTraceStorage = new AsyncLocalStorage();
const tracedTransactions = new WeakMap();

function traceValue(value, key = '') {
  if (/password|token|secret|authorization/i.test(key)) return '<redacted>';
  if (key === 'uid') return '<current-user>';
  if (neo4j.isInt(value)) return value.inSafeRange() ? value.toNumber() : value.toString();
  if (Array.isArray(value)) {
    if (value.length > 20) return `<array:${value.length}>`;
    return value.map((entry) => traceValue(entry));
  }
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([entryKey, entryValue]) => [
        entryKey,
        traceValue(entryValue, entryKey),
      ])
    );
  }
  return value;
}

function classifyQuery(query) {
  if (query.includes('AS debugState')) return 'Diagnostic snapshot';
  if (query.includes('RETURN liked, disliked, watchlist, alreadySeen')) return 'M22 · User library';
  if (query.includes('DELETE old')) return 'M08 · Remove incompatible states';
  // \b avoids matching "DELETE relationship" in the M01 genre pruning.
  if (/\bDELETE\s+r\b/.test(query) && query.includes('tmdbId: $tmdbId')) return 'M18–M21 · Remove interaction';
  if (query.includes('MERGE (u)-[r:')) return 'M09 · Create interaction';
  if (query.includes('quota.used =')) return 'M06 · Daily quota';
  if (query.includes('AS existingSwipe')) return 'M05 · Batch check';
  if (query.includes('AS pendingContexts')) return 'M07 · Daily contexts';
  if (query.includes('included.swipedAt =')) return 'M10 · Swipe telemetry';
  if (query.includes('MERGE (m:Movie')) return 'M01 · Movie upsert';
  if (query.includes('MATCH (m:Movie {tmdbId: $tmdbId})')) return 'M03 · Single movie read';
  if (query.includes("'personalized' AS source")) return 'Collaborative filtering';
  if (query.includes("queryNodes('tag_embeddings'")) return 'Vector similarity search';
  if (query.includes('t.embedding AS embedding')) return 'User semantic profile';
  if (query.includes("'exploratory' AS source")) return 'Exploratory candidates';
  if (query.includes('RecommendationBatch') && query.includes('INCLUDED')) return 'Recommendation events';
  if (query.includes('PREFERS_GENRE')) return 'Genre preferences';
  if (query.includes('REQUESTED_RECOMMENDATIONS')) return 'Exposure signals';
  if (query.includes('WHERE m.tmdbId IN $tmdbIds')) return 'Movie hydration cache';
  return 'Neo4j query';
}

class Neo4jService {
  constructor() {
    const uri = process.env.NEO4J_URI || 'bolt://localhost:7687';
    const user = process.env.NEO4J_USERNAME || 'neo4j';
    let password = process.env.NEO4J_PASSWORD;
    const database = process.env.NEO4J_DATABASE || undefined;

    if (!password) {
      if (process.env.NODE_ENV === 'production') {
        throw new Error('NEO4J_PASSWORD must be set in production.');
      }
      // Local-dev fallback only; docker compose requires an explicit password.
      password = 'password123';
    }

    this._uri = uri;
    this._database = database;
    this._driver = neo4j.driver(uri, neo4j.auth.basic(user, password), {
      maxConnectionPoolSize: 50,
      connectionAcquisitionTimeout: 30_000,
      maxTransactionRetryTime: 15_000,
    });
  }

  get uri() {
    return this._uri;
  }

  async initialize() {
    await this.verifyConnection();
    await this.createConstraints();
  }

  async verifyConnection() {
    await this._driver.verifyConnectivity();
  }

  session() {
    if (this._database) {
      return this._driver.session({ database: this._database });
    }

    return this._driver.session();
  }

  async run(query, params = {}) {
    const session = this.session();
    try {
      return await this._tracedRun(session, query, params);
    } finally {
      await session.close();
    }
  }

  async _tracedRun(runner, query, params = {}, transaction = null) {
    const trace = queryTraceStorage.getStore();
    const traceEntry = trace && trace.length < 100
      ? {
          order: trace.length + 1,
          name: classifyQuery(query),
          query: query.trim(),
          params: traceValue(params),
          durationMs: null,
          records: null,
          error: null,
          transactionId: transaction?.id || null,
          status: 'running',
          counters: {},
        }
      : null;
    if (traceEntry) trace.push(traceEntry);
    const startedAt = Date.now();

    try {
      const result = await runner.run(query, params);
      if (traceEntry) {
        traceEntry.durationMs = Date.now() - startedAt;
        traceEntry.records = result.records.length;
        traceEntry.status = 'completed';
        traceEntry.counters = traceValue(Object.fromEntries(
          Object.entries(result.summary?.counters?.updates?.() || {})
            .filter(([, count]) => count > 0)
        ));
      }
      return result;
    } catch (error) {
      if (traceEntry) {
        traceEntry.durationMs = Date.now() - startedAt;
        traceEntry.error = error instanceof Error ? error.message : String(error);
        traceEntry.status = 'error';
      }
      throw error;
    }
  }

  async captureQueryTrace(actions, queries = []) {
    const value = await queryTraceStorage.run(queries, actions);
    return { value, queries };
  }

  async _executeTransaction(actions, write) {
    const session = this.session();
    const trace = queryTraceStorage.getStore();
    let attempt = null;
    let callbackCompleted = false;
    try {
      const value = await session[write ? 'writeTransaction' : 'readTransaction'](async (tx) => {
        if (!trace) return actions(tx);
        if (attempt) attempt.status = 'rolled_back';
        callbackCompleted = false;
        trace.transactions ||= [];
        attempt = {
          id: `tx-${trace.transactions.length + 1}`,
          mode: write ? 'write' : 'read',
          status: 'pending',
        };
        trace.transactions.push(attempt);
        const currentAttempt = attempt;
        // Preserve the driver's transaction API while intercepting only run().
        const tracedTx = new Proxy(tx, {
          get: (target, property) => property === 'run'
            ? (query, params) => this._tracedRun(target, query, params, currentAttempt)
            : typeof target[property] === 'function'
              ? target[property].bind(target)
              : target[property],
        });
        tracedTransactions.set(tracedTx, currentAttempt);
        const value = await actions(tracedTx);
        callbackCompleted = true;
        return value;
      });
      if (attempt) attempt.status = 'committed';
      return value;
    } catch (error) {
      // A lost commit acknowledgement is not proof of a rollback.
      if (attempt) attempt.status = callbackCompleted ? 'commit_unknown' : 'rolled_back';
      throw error;
    } finally {
      await session.close();
    }
  }

  async executeWrite(actions) {
    return this._executeTransaction(actions, true);
  }

  async executeRead(actions) {
    return this._executeTransaction(actions, false);
  }

  async captureInteractionState(tx, uid, tmdbId, phase) {
    const trace = queryTraceStorage.getStore();
    if (!trace?.captureState) return;
    const attempt = tracedTransactions.get(tx);
    const result = await tx.run(`
        MATCH (u:AppUser {uid: $uid})
        OPTIONAL MATCH (m:Movie {tmdbId: $tmdbId})
        OPTIONAL MATCH (u)-[r:LIKED|DISLIKED|WATCHLISTED|ALREADY_SEEN|SELECTED_FAVORITE]->(m)
        WITH u, m, collect(CASE WHEN r IS NOT NULL THEN {
          type: type(r), createdAt: toString(r.createdAt)
        } END) AS relationships
        OPTIONAL MATCH (q:DailySwipeQuota {key: $quotaKey})
        OPTIONAL MATCH (u)-[:REQUESTED_RECOMMENDATIONS]->(:RecommendationBatch {id: $batchId})-[i:INCLUDED]->(m)
        RETURN {title: m.title, relationships: relationships,
          quotaUsed: coalesce(q.used, 0), batchAction: i.action,
          swipedAt: toString(i.swipedAt)} AS debugState
      `, { uid, tmdbId, quotaKey: `${uid}:${new Date().toISOString().slice(0, 10)}`, batchId: trace.batchId || '' });
    if (attempt) attempt[phase] = traceValue(result.records[0]?.get('debugState') || {});
  }

  async createConstraints() {
    await this.run(`
      CREATE CONSTRAINT app_user_uid IF NOT EXISTS
      FOR (u:AppUser)
      REQUIRE u.uid IS UNIQUE
    `);

    await this.run(`
      CREATE CONSTRAINT app_user_email IF NOT EXISTS
      FOR (u:AppUser)
      REQUIRE u.emailNormalized IS UNIQUE
    `);

    await this.run(`
      CREATE CONSTRAINT movie_tmdb_id IF NOT EXISTS
      FOR (m:Movie)
      REQUIRE m.tmdbId IS UNIQUE
    `);

    await this.run(`
      CREATE CONSTRAINT movielens_movie_id IF NOT EXISTS
      FOR (m:MovieLensMovie)
      REQUIRE m.movieLensId IS UNIQUE
    `);

    await this.run(`
      CREATE CONSTRAINT movielens_user_id IF NOT EXISTS
      FOR (u:MovieLensUser)
      REQUIRE u.movieLensUserId IS UNIQUE
    `);

    await this.run(`
      CREATE CONSTRAINT genre_name IF NOT EXISTS
      FOR (g:Genre)
      REQUIRE g.name IS UNIQUE
    `);

    await this.run(`
      CREATE CONSTRAINT tag_name IF NOT EXISTS
      FOR (t:Tag)
      REQUIRE t.name IS UNIQUE
    `);

    // The vector index requires Neo4j 5.11+. Treat its creation as best-effort:
    // if the deployment doesn't support it, the server should still start
    // (only semantic mood-search / tag-based recommendations are degraded)
    // instead of crashing the whole process.
    try {
      await this.run(`
        CREATE VECTOR INDEX tag_embeddings IF NOT EXISTS
        FOR (t:Tag) ON (t.embedding)
        OPTIONS {indexConfig: {
          \`vector.dimensions\`: 384,
          \`vector.similarity_function\`: 'cosine'
        }}
      `);
    } catch (error) {
      console.warn(
        '[Neo4jService] Could not create vector index "tag_embeddings" (semantic search will be unavailable):',
        error instanceof Error ? error.message : String(error)
      );
    }

    await this.run(`
      CREATE CONSTRAINT movie_night_id IF NOT EXISTS
      FOR (m:MovieNight)
      REQUIRE m.id IS UNIQUE
    `);

    await this.run(`
      CREATE CONSTRAINT recommendation_batch_id IF NOT EXISTS
      FOR (b:RecommendationBatch)
      REQUIRE b.id IS UNIQUE
    `);

    await this.run(`
      CREATE INDEX recommendation_batch_created_at IF NOT EXISTS
      FOR (b:RecommendationBatch)
      ON (b.createdAt)
    `);

    await this.run(`
      CREATE CONSTRAINT daily_swipe_quota_key IF NOT EXISTS
      FOR (q:DailySwipeQuota)
      REQUIRE q.key IS UNIQUE
    `);

    await this.run(`
      CREATE INDEX movie_title IF NOT EXISTS
      FOR (m:Movie)
      ON (m.title)
    `);

    await this.run(`
      CREATE INDEX movielens_movie_title IF NOT EXISTS
      FOR (m:MovieLensMovie)
      ON (m.title)
    `);

    // Speeds up popularity-based filtering/ordering used by the exploratory
    // and group-shortlist candidate queries.
    await this.run(`
      CREATE INDEX movie_ml_rating_count IF NOT EXISTS
      FOR (m:Movie)
      ON (m.movieLensRatingCount)
    `);

    // Older TMDB cache writes stored genre names only as a property. Keep the
    // graph representation used by recommendation queries in sync on startup.
    await this.run(`
      MATCH (m:Movie)
      WHERE size(coalesce(m.genres, [])) > 0
      UNWIND m.genres AS genreName
      MERGE (g:Genre {name: genreName})
      MERGE (m)-[:IN_GENRE]->(g)
    `);

    // Recommendation events are operational analytics, not permanent user
    // profile data. Keep a bounded window for diagnostics and ranking metrics.
    await this.run(`
      MATCH (batch:RecommendationBatch)
      WHERE batch.createdAt < datetime() - duration({days: 90})
      DETACH DELETE batch
    `);

    await this.run(`
      MATCH (quota:DailySwipeQuota)
      WHERE quota.day < date() - duration({days: 90})
      DETACH DELETE quota
    `);
  }

  async close() {
    await this._driver.close();
  }
}

module.exports = new Neo4jService();
module.exports.classifyQuery = classifyQuery;
