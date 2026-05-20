const neo4jService = require('./neo4jService');
const socialRepository = require('./socialRepository');

async function test() {
  await neo4jService.initialize();
  
  // create users
  await neo4jService.run(`MERGE (u:AppUser {uid: '123'}) SET u.displayName = 'User 123'`);
  await neo4jService.run(`MERGE (u:AppUser {uid: '456'}) SET u.displayName = 'User 456'`);
  
  // make friends
  await neo4jService.run(`MATCH (u1:AppUser {uid: '123'}), (u2:AppUser {uid: '456'}) MERGE (u1)-[:FRIEND]-(u2)`);
  
  const res = await socialRepository.getFriends('123');
  console.log(JSON.stringify(res, null, 2));
  process.exit(0);
}

test();
