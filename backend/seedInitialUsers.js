require('dotenv').config();

const neo4jService = require('./neo4jService');
const bcrypt = require('bcryptjs');

(async () => {
  try {
    await neo4jService.initialize();

    const email = 'demo@example.com';
    const emailNormalized = email.trim().toLowerCase();
    const password = 'password';
    const passwordHash = await bcrypt.hash(password, 10);
    const uid = 'u_demo';

    const cypher = `
      MERGE (u:AppUser {emailNormalized: $emailNormalized})
      ON CREATE SET
        u.uid = $uid,
        u.email = $email,
        u.displayName = $displayName,
        u.passwordHash = $passwordHash,
        u.createdAt = datetime(),
        u.onboardingCompleted = false,
        u.roles = ['USER']
      ON MATCH SET
        u.passwordHash = $passwordHash
      RETURN u.uid AS uid
    `;

    await neo4jService.run(cypher, {
      uid,
      email,
      emailNormalized,
      displayName: 'demo',
      passwordHash,
    });

    console.log('Seeded user', email);
    process.exit(0);
  } catch (e) {
    console.error('Seed failed', e);
    process.exit(1);
  }
})();
