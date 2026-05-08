const neo4j = require('neo4j-driver');

class Neo4jService {
  constructor() {
    const uri = process.env.NEO4J_URI || 'bolt://localhost:7687';
    const user = process.env.NEO4J_USERNAME || 'neo4j';
    const password = process.env.NEO4J_PASSWORD || 'password';
    this._uri = uri;
    this._driver = neo4j.driver(uri, neo4j.auth.basic(user, password));
  }

  get uri() {
    return this._uri;
  }

  async verifyConnection() {
    await this._driver.verifyConnectivity();
  }

  async run(query, params = {}) {
    const session = this._driver.session();
    try {
      const result = await session.run(query, params);
      return result;
    } finally {
      await session.close();
    }
  }

  async close() {
    await this._driver.close();
  }
}

module.exports = new Neo4jService();
