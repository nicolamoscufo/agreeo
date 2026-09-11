const neo4j = require('neo4j-driver');
const { AsyncLocalStorage } = require('node:async_hooks');

const queryTraceStorage = new AsyncLocalStorage();

function traceValue(value, key = '') {
  if (key === 'uid') return '<current-user>';
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
    const trace = queryTraceStorage.getStore();
    const traceEntry = trace
      ? {
          order: trace.length + 1,
          name: classifyQuery(query),
          query: query.trim(),
          params: traceValue(params),
          durationMs: null,
          records: null,
          error: null,
        }
      : null;
    if (traceEntry) trace.push(traceEntry);
    const startedAt = Date.now();

    try {
      const result = await session.run(query, params);
      if (traceEntry) {
        traceEntry.durationMs = Date.now() - startedAt;
        traceEntry.records = result.records.length;
      }
      return result;
    } catch (error) {
      if (traceEntry) {
        traceEntry.durationMs = Date.now() - startedAt;
        traceEntry.error = error instanceof Error ? error.message : String(error);
      }
      throw error;
    } finally {
      await session.close();
    }
  }

  async captureQueryTrace(actions) {
    const queries = [];
    const value = await queryTraceStorage.run(queries, actions);
    return { value, queries };
  }

  async executeWrite(actions) {
    const session = this.session();

    try {
      return await session.writeTransaction(async (tx) => {
        return await actions(tx);
      });
    } finally {
      await session.close();
    }
  }

  async executeRead(actions) {
    const session = this.session();

    try {
      return await session.readTransaction(async (tx) => {
        return await actions(tx);
      });
    } finally {
      await session.close();
    }
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
