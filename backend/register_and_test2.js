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
  const loginData = JSON.stringify({ email: 'test_real_2@example.com', password: 'password123' });
  const loginRes = await doReq({
    hostname: 'localhost', port: 3000, path: '/auth/login', method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Content-Length': loginData.length }
  }, loginData);
  if (!loginRes.body.accessToken) { console.error('No login token'); return; }
  
  const h = { 'Authorization': `Bearer ${loginRes.body.accessToken}` };
  
  const r1 = await doReq({ hostname: 'localhost', port: 3000, path: '/me/recommendations', method: 'GET', headers: h });
  console.log('For You (legacy) Status:', r1.status, 'Count:', r1.body?.results?.length);

  const r2 = await doReq({ hostname: 'localhost', port: 3000, path: '/me/recommendations/daily-suggestions', method: 'GET', headers: h });
  console.log('Daily Status:', r2.status, 'Count:', r2.body?.results?.length);
}
test();
