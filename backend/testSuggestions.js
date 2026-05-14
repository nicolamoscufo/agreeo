const neo4jService = require('./neo4jService.js');
const movieRepository = require('./movieRepository.js');

async function test() {
  const uid = 'test-uid-123';
  await neo4jService.run(`MERGE (u:AppUser {uid: $uid, email: 'test@test.com'})`, {uid});
  
  // Test explanatory candidates
  console.log("Fetching exploratory candidates...");
  const explore = await movieRepository.getExploratoryCandidates(uid, {limit: 5});
  console.log("Exploratory:", explore.map(e => e.title));
  
  const daily = await movieRepository.getRecommendationCandidates(uid);
  console.log("Daily candidates length:", daily.candidates.length);
  
  process.exit(0);
}
test().catch(console.error);
