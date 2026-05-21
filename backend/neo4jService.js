const neo4j = require('neo4j-driver');

class Neo4jService {
  constructor() {
    const uri = process.env.NEO4J_URI || 'bolt://localhost:7687';
    const user = process.env.NEO4J_USERNAME || 'neo4j';
    const password = process.env.NEO4J_PASSWORD || 'password123';
    const database = process.env.NEO4J_DATABASE || undefined;

    this._uri = uri;
    this._database = database;
    this._driver = neo4j.driver(uri, neo4j.auth.basic(user, password));
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
  }

  async close() {
    await this._driver.close();
  }
}

module.exports = new Neo4jService();
