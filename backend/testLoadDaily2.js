require('dotenv').config({ path: '../backend/.env' });
const { initNeo4j, closeNeo4j } = require('../backend/neo4jService.js');
const controller = require('../backend/movieController.js');

async function run() {
  await initNeo4j();
  let fakeReq = { user: { id: "test-uid-123" } };
  let statusSet = 200;
  let fakeRes = { 
    json: (data) => console.log('Final Output Results:', data.results?.length, data.results),
    status: (s) => { statusSet = s; return fakeRes; }
  };
  await controller.loadDailySuggestions(fakeReq, fakeRes);
  await closeNeo4j();
}
run();
