const http = require('http');

async function test() {
  const loginData = JSON.stringify({ email: 'test_real_2@example.com', password: 'password123' });
  const loginRes = await new Promise(r => {
    const req = http.request({ hostname: 'localhost', port: 3000, path: '/auth/login', method: 'POST', headers: {'Content-Type':'application/json'}}, res => {
      let d = ''; res.on('data', c => d+=c); res.on('end', () => r({status: res.statusCode, body: JSON.parse(d)}));
    });
    req.write(loginData); req.end();
  });
  
  const token = loginRes.body.accessToken;
  const likeRes = await new Promise(r => {
    const req = http.request({ hostname: 'localhost', port: 3000, path: '/me/movies/550/like', method: 'POST', headers: {'Authorization':'Bearer '+token}}, res => {
      let d = ''; res.on('data', c => d+=c); res.on('end', () => r({status: res.statusCode, body: d}));
    });
    req.end();
  });
  console.log(likeRes);
}
test();
