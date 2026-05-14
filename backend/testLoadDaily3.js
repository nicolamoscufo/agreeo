require('dotenv').config({ path: './.env' });
const controller = require('./movieController.js');

async function run() {
  let fakeReq = { user: { id: "test-uid-123" } };
  let statusSet = 200;
  let fakeRes = { 
    json: (data) => console.log('Final Output Results:', data.results?.length, data.results),
    status: (s) => { statusSet = s; return fakeRes; }
  };
  await controller.loadDailySuggestions(fakeReq, fakeRes);
  process.exit(0);
}
run();
