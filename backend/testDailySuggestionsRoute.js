const http = require('http');

async function test() {
  const loginData = JSON.stringify({ email: 'test1@example.com', password: 'password123' });
  const req = http.request({
    hostname: 'localhost',
    port: 3000,
    path: '/auth/login',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': loginData.length
    }
  }, (res) => {
    let rawData = '';
    res.on('data', (chunk) => { rawData += chunk; });
    res.on('end', () => {
      console.log('Login Status:', res.statusCode);
      try {
        const parsedData = JSON.parse(rawData);
        console.log('Login Response:', parsedData);
        if (parsedData.token) {
           getDaily(parsedData.token);
        }
      } catch (e) {
        console.error(e.message);
      }
    });
  });

  req.on('error', (e) => {
    console.error(`problem with request: ${e.message}`);
  });

  req.write(loginData);
  req.end();
}

function getDaily(token) {
   const req = http.request({
    hostname: 'localhost',
    port: 3000,
    path: '/me/recommendations/daily-suggestions',
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${token}`
    }
  }, (res) => {
    let rawData = '';
    res.on('data', (chunk) => { rawData += chunk; });
    res.on('end', () => {
      console.log('Daily Status:', res.statusCode);
      try {
        const parsedData = JSON.parse(rawData);
        console.log('Daily count:', parsedData.length);
      } catch (e) {
        console.error(e.message);
      }
    });
  });

  req.on('error', (e) => {
    console.error(`problem with request: ${e.message}`);
  });
  req.end();
}

test();
