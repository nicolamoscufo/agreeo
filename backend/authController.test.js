const assert = require('node:assert/strict');
const test = require('node:test');

const bcrypt = require('bcryptjs');

const neo4jService = require('./neo4jService');
const authController = require('./authController');

function record(values) {
  return {
    get(key) {
      return values[key];
    },
  };
}

function userRecord(overrides = {}) {
  return record({
    uid: 'u1',
    email: 'anton@example.com',
    displayName: 'Anton',
    bio: '',
    avatarUrl: '',
    createdAt: '2026-01-01T00:00:00Z',
    onboardingCompleted: true,
    roles: ['USER'],
    ...overrides,
  });
}

function mockReq(body = {}) {
  return { user: { uid: 'u1' }, body };
}

function mockRes() {
  return {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
  };
}

function stubRun(t, handler) {
  const calls = [];
  const originalRun = neo4jService.run;
  t.after(() => {
    neo4jService.run = originalRun;
  });
  neo4jService.run = async (query, params) => {
    calls.push({ query, params });
    return handler(query, params, calls.length);
  };
  return calls;
}

test('updateProfile rejects an empty payload', async (t) => {
  const calls = stubRun(t, () => ({ records: [] }));

  const res = mockRes();
  await authController.updateProfile(mockReq({}), res);

  assert.equal(res.statusCode, 400);
  assert.equal(calls.length, 0);
});

test('updateProfile validates displayName, bio and avatarUrl', async (t) => {
  stubRun(t, () => ({ records: [] }));

  for (const body of [
    { displayName: '   ' },
    { displayName: 'x'.repeat(61) },
    { bio: 'x'.repeat(281) },
    { avatarUrl: 'javascript:alert(1)' },
    { avatarUrl: 'data:text/html;base64,AAAA' },
  ]) {
    const res = mockRes();
    await authController.updateProfile(mockReq(body), res);
    assert.equal(res.statusCode, 400, JSON.stringify(body));
  }
});

test('updateProfile SETs only the provided fields and returns the user', async (t) => {
  const calls = stubRun(t, () => ({
    records: [userRecord({ bio: 'New bio', avatarUrl: 'data:image/jpeg;base64,AAAA' })],
  }));

  const res = mockRes();
  await authController.updateProfile(
    mockReq({ bio: '  New bio  ', avatarUrl: 'data:image/jpeg;base64,AAAA' }),
    res
  );

  assert.equal(res.statusCode, 200);
  assert.equal(calls.length, 1);
  assert.match(calls[0].query, /SET u\.bio = \$bio, u\.avatarUrl = \$avatarUrl/);
  assert.ok(!calls[0].query.includes('u.displayName ='));
  assert.equal(calls[0].params.bio, 'New bio');
  assert.equal(res.body.user.bio, 'New bio');
  assert.equal(res.body.user.avatarUrl, 'data:image/jpeg;base64,AAAA');
});

test('updateProfile accepts clearing the avatar with an empty string', async (t) => {
  const calls = stubRun(t, () => ({ records: [userRecord()] }));

  const res = mockRes();
  await authController.updateProfile(mockReq({ avatarUrl: '' }), res);

  assert.equal(res.statusCode, 200);
  assert.equal(calls[0].params.avatarUrl, '');
});

test('updatePrivacy rejects an empty payload and non-boolean values', async (t) => {
  const calls = stubRun(t, () => ({ records: [] }));

  for (const body of [{}, { canShowWatched: 'yes' }, { canShowReviews: 1 }]) {
    const res = mockRes();
    await authController.updatePrivacy(mockReq(body), res);
    assert.equal(res.statusCode, 400, JSON.stringify(body));
  }
  assert.equal(calls.length, 0);
});

test('updatePrivacy SETs only the provided flags and returns the full privacy state', async (t) => {
  const calls = stubRun(t, () => ({
    records: [
      record({
        canShowWatched: true,
        canShowReviews: true,
        canShowWatchlist: true,
      }),
    ],
  }));

  const res = mockRes();
  await authController.updatePrivacy(mockReq({ canShowWatchlist: true }), res);

  assert.equal(res.statusCode, 200);
  assert.equal(calls.length, 1);
  assert.match(calls[0].query, /SET u\.canShowWatchlist = \$canShowWatchlist/);
  assert.ok(!calls[0].query.includes('u.canShowWatched ='));
  assert.equal(calls[0].params.canShowWatchlist, true);
  assert.deepEqual(res.body.privacy, {
    canShowWatched: true,
    canShowReviews: true,
    canShowWatchlist: true,
  });
});

test('changePassword rejects a weak new password without touching the database', async (t) => {
  const calls = stubRun(t, () => ({ records: [] }));

  const res = mockRes();
  await authController.changePassword(
    mockReq({ currentPassword: 'oldpass1', newPassword: 'short' }),
    res
  );

  assert.equal(res.statusCode, 400);
  assert.equal(calls.length, 0);
});

test('changePassword returns 403 when the current password is wrong', async (t) => {
  const passwordHash = await bcrypt.hash('rightpass1', 10);
  const calls = stubRun(t, () => ({ records: [record({ passwordHash })] }));

  const res = mockRes();
  await authController.changePassword(
    mockReq({ currentPassword: 'wrongpass1', newPassword: 'newpass123' }),
    res
  );

  assert.equal(res.statusCode, 403);
  assert.equal(calls.length, 1);
});

test('changePassword stores a new bcrypt hash on success', async (t) => {
  const passwordHash = await bcrypt.hash('rightpass1', 10);
  const calls = stubRun(t, (query, params, callIndex) =>
    callIndex === 1 ? { records: [record({ passwordHash })] } : { records: [] }
  );

  const res = mockRes();
  await authController.changePassword(
    mockReq({ currentPassword: 'rightpass1', newPassword: 'newpass123' }),
    res
  );

  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.body, { ok: true });
  assert.equal(calls.length, 2);
  assert.match(calls[1].query, /SET u\.passwordHash = \$passwordHash/);
  assert.ok(await bcrypt.compare('newpass123', calls[1].params.passwordHash));
});

test('deleteAccount requires the password and verifies it', async (t) => {
  const passwordHash = await bcrypt.hash('rightpass1', 10);
  const calls = stubRun(t, () => ({ records: [record({ passwordHash })] }));

  const missing = mockRes();
  await authController.deleteAccount(mockReq({}), missing);
  assert.equal(missing.statusCode, 400);

  const wrong = mockRes();
  await authController.deleteAccount(mockReq({ password: 'wrongpass1' }), wrong);
  assert.equal(wrong.statusCode, 403);
  assert.equal(calls.length, 1);
});

test('deleteAccount detaches and deletes the user node on success', async (t) => {
  const passwordHash = await bcrypt.hash('rightpass1', 10);
  const calls = stubRun(t, (query, params, callIndex) =>
    callIndex === 1 ? { records: [record({ passwordHash })] } : { records: [] }
  );

  const res = mockRes();
  await authController.deleteAccount(mockReq({ password: 'rightpass1' }), res);

  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.body, { ok: true });
  assert.equal(calls.length, 2);
  assert.match(calls[1].query, /DETACH DELETE u/);
  assert.equal(calls[1].params.uid, 'u1');
});
