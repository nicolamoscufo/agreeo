const assert = require('node:assert/strict');
const test = require('node:test');

// Strong test secret so jwtUtils can be required (it fails fast otherwise).
const TEST_SECRET = 'unit_test_secret_with_more_than_32_characters!';
process.env.JWT_SECRET = TEST_SECRET;

const { sign, resolveSecret } = require('./jwtUtils');
const { authMiddleware } = require('./socketService');

test('jwtUtils refuses a missing, default or short JWT_SECRET', () => {
  try {
    for (const badSecret of [undefined, 'CHANGE_ME', 'too_short']) {
      if (badSecret === undefined) {
        delete process.env.JWT_SECRET;
      } else {
        process.env.JWT_SECRET = badSecret;
      }
      assert.throws(
        () => resolveSecret(),
        /JWT_SECRET/,
        `expected failure for JWT_SECRET=${String(badSecret)}`
      );
    }
  } finally {
    process.env.JWT_SECRET = TEST_SECRET;
  }

  assert.equal(resolveSecret(), TEST_SECRET);
});

test('socket auth middleware rejects connections without a valid JWT', () => {
  const makeSocket = (auth = {}, headers = {}) => ({
    handshake: { auth, headers },
    data: {},
  });

  let error = null;
  authMiddleware(makeSocket(), (err) => {
    error = err;
  });
  assert.ok(error instanceof Error, 'missing token must be rejected');

  error = null;
  authMiddleware(makeSocket({ token: 'not-a-jwt' }), (err) => {
    error = err;
  });
  assert.ok(error instanceof Error, 'invalid token must be rejected');
});

test('socket auth middleware derives the user from the verified JWT', () => {
  const token = sign({ sub: 'user-a', uid: 'user-a' });

  const socket = { handshake: { auth: { token } }, data: {} };
  let error = new Error('next not called');
  authMiddleware(socket, (err) => {
    error = err;
  });

  assert.equal(error, undefined);
  assert.equal(socket.data.userId, 'user-a');

  // A client claiming a different userId is irrelevant: the room is always
  // derived from the token, never from client-provided payloads.
  const headerSocket = {
    handshake: { auth: {}, headers: { authorization: `Bearer ${token}` } },
    data: {},
  };
  authMiddleware(headerSocket, () => {});
  assert.equal(headerSocket.data.userId, 'user-a');
});

test('express-rate-limit returns 429 above the configured threshold', async () => {
  const express = require('express');
  const rateLimit = require('express-rate-limit');

  const app = express();
  app.use(
    rateLimit({ windowMs: 60_000, max: 3, standardHeaders: true, legacyHeaders: false })
  );
  app.get('/ping', (_, res) => res.json({ ok: true }));

  const server = await new Promise((resolve) => {
    const s = app.listen(0, () => resolve(s));
  });

  try {
    const { port } = server.address();
    const statuses = [];
    for (let i = 0; i < 4; i += 1) {
      const response = await fetch(`http://127.0.0.1:${port}/ping`);
      statuses.push(response.status);
    }
    assert.deepEqual(statuses, [200, 200, 200, 429]);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
