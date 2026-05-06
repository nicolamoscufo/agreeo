const neo4jService = require('./neo4jService');
const bcrypt = require('bcrypt');

(async () => {
  try {
    const email = 'demo@example.com';
    const password = 'password';
    const hash = await bcrypt.hash(password, 10);
    const uid = 'u-demo';
    const cypher = `
      MERGE (u:User {email: $email})
      ON CREATE SET u.userId = $uid, u.passwordHash = $passwordHash, u.createdAt = datetime(), u.roles = ['USER']
      ON MATCH SET u.passwordHash = $passwordHash
      RETURN u.userId AS userId
    `;
    await neo4jService.run(cypher, { email, uid, passwordHash: hash });
    console.log('Seeded user', email);
    process.exit(0);
  } catch (e) {
    console.error('Seed failed', e);
    process.exit(1);
  }
})();
