const https = require('https');

function post(url, data) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const body = JSON.stringify(data);
    const req = https.request({
      hostname: u.hostname,
      path: u.pathname,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body)
      }
    }, (res) => {
      let chunks = '';
      res.on('data', c => chunks += c);
      res.on('end', () => {
        try {
          resolve(JSON.parse(chunks));
        } catch (e) {
          reject(new Error('Invalid JSON: ' + chunks));
        }
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

function get(url, token) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const req = https.request({
      hostname: u.hostname,
      path: u.pathname + u.search,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${token}`
      }
    }, (res) => {
      let chunks = '';
      res.on('data', c => chunks += c);
      res.on('end', () => {
        try {
          resolve(JSON.parse(chunks));
        } catch (e) {
          reject(new Error('Invalid JSON: ' + chunks));
        }
      });
    });
    req.on('error', reject);
    req.end();
  });
}

async function run() {
  try {
    console.log('Logging in as "محمد"...');
    const loginRes = await post('https://marekt-scan.vercel.app/api/auth/login', {
      username: 'محمد',
      password: '123'
    });
    console.log('Login response:', loginRes);
    if (!loginRes.success) {
      console.log('Trying alternative password "123456"...');
      const loginRes2 = await post('https://marekt-scan.vercel.app/api/auth/login', {
        username: 'محمد',
        password: '123456'
      });
      console.log('Login response 2:', loginRes2);
      if (!loginRes2.success) return;
      loginRes.token = loginRes2.token;
    }

    console.log('Fetching transactions...');
    const tx = await get('https://marekt-scan.vercel.app/api/transactions?limit=30', loginRes.token);
    console.log('Transactions response:', tx);
  } catch (err) {
    console.error('Fatal error:', err);
  }
}

run();
