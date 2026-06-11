const neo4j = require('neo4j-driver');

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
      return await session.run(query, params);
    } finally {
      await session.close();
    }
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
  }

  async close() {
    await this._driver.close();
  }
}

module.exports = new Neo4jService();
