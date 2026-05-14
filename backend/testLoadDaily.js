require('dotenv').config({ path: '../backend/.env' });
const { initNeo4j, closeNeo4j } = require('../backend/neo4jService.js');
const repo = require('../backend/movieRepository.js');
const controller = require('../backend/movieController.js');

async function run() {
  await initNeo4j();
  let fakeReq = { user: { id: "test_user_id" } };
  let fakeRes = { 
    json: (data) => console.log('Final Output:', data),
    status: (s) => ({ json: (d) => console.log('Status', s, d) })
  };
  await controller.loadDailySuggestions(fakeReq, fakeRes);
  await closeNeo4j();
}
run();
