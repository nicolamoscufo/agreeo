require('dotenv').config({ path: './.env' });
const controller = require('./movieController.js');

async function run() {
  let fakeReq = { user: { uid: 'test-uid-123' }, query: {} };
  let statusSet = 200;
  let fakeRes = { 
    json: (data) => console.log("DATA:", data),
    status: (s) => { statusSet = s; return fakeRes; }
  };
  await controller.dailySuggestions(fakeReq, fakeRes);
  process.exit(0);
}
run();
