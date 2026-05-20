const http = require('http');

async function test() {
  const loginData = JSON.stringify({ email: 'test_daily_x2@example.com', password: 'password123' });
  await new Promise(r => {
    const req = http.request({ hostname: 'localhost', port: 3000, path: '/auth/register', method: 'POST', headers: {'Content-Type':'application/json'}}, res => {
      let d = ''; res.on('data', c => d+=c); res.on('end', () => r({status: res.statusCode, body: d}));
    });
    req.write(loginData); req.end();
  });
  const loginRes = await new Promise(r => {
    const req = http.request({ hostname: 'localhost', port: 3000, path: '/auth/login', method: 'POST', headers: {'Content-Type':'application/json'}}, res => {
      let d = ''; res.on('data', c => d+=c); res.on('end', () => r({status: res.statusCode, body: JSON.parse(d)}));
    });
    req.write(loginData); req.end();
  });
  
  const token = loginRes.body.accessToken;
  const res = await new Promise(r => {
    const req = http.request({ hostname: 'localhost', port: 3000, path: '/me/recommendations/daily-suggestions', method: 'GET', headers: {'Authorization':'Bearer '+token}}, res => {
      let d = ''; res.on('data', c => d+=c); res.on('end', () => r({status: res.statusCode, body: d}));
    });
    req.end();
  });
  console.log('Daily Status:', res.status, res.body.substring(0, 100));
}
test();
