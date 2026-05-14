const http = require('http');

async function doReq(options, data) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let rawData = '';
      res.on('data', (chunk) => { rawData += chunk; });
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(rawData) });
        } catch (e) {
          resolve({ status: res.statusCode, body: rawData });
        }
      });
    });
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

async function test() {
  const loginData = JSON.stringify({ email: 'test_real_2@example.com', password: 'password123', birthDate: '1990-01-01' });
  const regRes = await doReq({
    hostname: 'localhost', port: 3000, path: '/auth/register', method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Content-Length': loginData.length }
  }, loginData);
  console.log('Reg Result:', regRes.status, regRes.body.accessToken ? 'Got token' : regRes.body);

  const loginRes = await doReq({
    hostname: 'localhost', port: 3000, path: '/auth/login', method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Content-Length': loginData.length }
  }, loginData);
  if (!loginRes.body.accessToken) { console.error('No login token'); return; }
  
  const dailyRes = await doReq({
    hostname: 'localhost', port: 3000, path: '/me/recommendations/daily-suggestions', method: 'GET',
    headers: { 'Authorization': `Bearer ${loginRes.body.accessToken}` }
  });
  console.log('Daily Status:', dailyRes.status);
  console.log('Daily count:', dailyRes.body?.results?.length);
}
test();
