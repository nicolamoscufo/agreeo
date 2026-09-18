const assert = require('node:assert/strict');
const test = require('node:test');
const neo4jService = require('./neo4jService');
const socketService = require('./socketService');
const { traceAction, getHistory } = require('./neo4jLiveTrace');
const controller = require('./neo4jDebugController');

function result(values = {}) {
  return {
    records: [{ get: (key) => values[key] }],
    summary: { counters: { updates: () => ({ relationshipsCreated: 1 }) } },
  };
}

function mockSession(t, writeTransaction) {
  const original = neo4jService.session;
  let closed = 0;
  neo4jService.session = () => ({
    run: async () => result(),
    writeTransaction,
    readTransaction: writeTransaction,
    close: async () => { closed++; },
  });
  t.after(() => { neo4jService.session = original; });
  return () => closed;
}

function debugEnabled(t, value = 'true') {
  const original = process.env.ENABLE_NEO4J_DEBUG;
  process.env.ENABLE_NEO4J_DEBUG = value;
  t.after(() => {
    if (original === undefined) delete process.env.ENABLE_NEO4J_DEBUG;
    else process.env.ENABLE_NEO4J_DEBUG = original;
  });
}

test('classifyQuery names M01, M03 and M18-M21 without mixing them up', () => {
  const { classifyQuery } = neo4jService;
  assert.match(classifyQuery(
    'MERGE (m:Movie {tmdbId: $tmdbId}) FOREACH (relationship IN CASE WHEN size($genres) > 0 | DELETE relationship)'
  ), /M01 · Movie upsert/);
  assert.match(classifyQuery(
    'MATCH (m:Movie {tmdbId: $tmdbId}) RETURN m.title'
  ), /M03 · Single movie read/);
  assert.match(classifyQuery(
    'MATCH (:AppUser {uid: $uid})-[r:LIKED]->(:Movie {tmdbId: $tmdbId}) DELETE r'
  ), /M18–M21 · Remove interaction/);
  assert.match(classifyQuery(
    'MATCH (u:AppUser {uid: $uid})-[old:DISLIKED]->(m:Movie {tmdbId: $tmdbId}) DELETE old'
  ), /M08 · Remove incompatible states/);
});

test('query completion remains pending until commit; snapshots and counters belong to the transaction', async (t) => {
  const queries = [];
  queries.captureState = true;
  const closed = mockSession(t, async (actions) => {
    const value = await actions({ run: async () => result({ debugState: { relationships: [{ type: 'LIKED' }] } }) });
    assert.equal(queries.transactions[0].status, 'pending');
    return value;
  });
  await neo4jService.captureQueryTrace(() => neo4jService.executeWrite(async (tx) => {
    await neo4jService.captureInteractionState(tx, 'alice', 550, 'before');
    await tx.run('MERGE (u)-[r:LIKED]->(m)', { uid: 'alice', nested: { passwordHash: 'hidden' } });
    await neo4jService.captureInteractionState(tx, 'alice', 550, 'after');
  }), queries);
  assert.equal(queries.transactions[0].status, 'committed');
  assert.deepEqual(queries.transactions[0].after.relationships, [{ type: 'LIKED' }]);
  assert.equal(queries[1].transactionId, queries.transactions[0].id);
  assert.equal(queries[1].params.uid, '<current-user>');
  assert.equal(queries[1].params.nested.passwordHash, '<redacted>');
  assert.equal(queries[1].counters.relationshipsCreated, 1);
  assert.equal(closed(), 1);
});

test('rollback is retained even when an earlier statement succeeded', async (t) => {
  mockSession(t, async (actions) => actions({ run: async () => result() }));
  const queries = [];
  await assert.rejects(neo4jService.captureQueryTrace(() => neo4jService.executeWrite(async (tx) => {
    await tx.run('CREATE (n)');
    throw new Error('quota exceeded');
  }), queries), /quota exceeded/);
  assert.equal(queries[0].status, 'completed');
  assert.equal(queries.transactions[0].status, 'rolled_back');
});

test('driver retry produces separate attempts and marks only the final attempt committed', async (t) => {
  mockSession(t, async (actions) => {
    const tx = { run: async () => result() };
    await actions(tx); // Simulate a transient failure during commit, followed by retry.
    return actions(tx);
  });
  const { queries } = await neo4jService.captureQueryTrace(() => neo4jService.executeWrite((tx) => tx.run('RETURN 1')));
  assert.deepEqual(queries.transactions.map((tx) => tx.status), ['rolled_back', 'committed']);
  assert.notEqual(queries[0].transactionId, queries[1].transactionId);
});

test('a failed commit acknowledgement is not reported as a confirmed rollback', async (t) => {
  mockSession(t, async (actions) => {
    await actions({ run: async () => result() });
    throw new Error('connection lost during commit');
  });
  const queries = [];
  await assert.rejects(neo4jService.captureQueryTrace(
    () => neo4jService.executeWrite((tx) => tx.run('CREATE (n)')), queries,
  ));
  assert.equal(queries.transactions[0].status, 'commit_unknown');
});

test('simultaneous requests keep their queries and history isolated by authenticated user', async (t) => {
  debugEnabled(t);
  mockSession(t, async (actions) => actions({ run: async () => result() }));
  const handler = traceAction('Like', async (req) => {
    await new Promise((resolve) => setTimeout(resolve, req.user.uid === 'alice' ? 10 : 0));
    await neo4jService.run(`RETURN '${req.user.uid}'`);
  });
  await Promise.all(['alice', 'bob'].map((uid) => handler(
    { user: { uid }, method: 'POST', path: '/me/movies/550/like', params: { tmdbId: '550' } },
    { statusCode: 200 },
    (error) => { throw error; },
  )));
  assert.equal(getHistory('alice')[0].queries[0].query, "RETURN 'alice'");
  assert.equal(getHistory('bob')[0].queries[0].query, "RETURN 'bob'");
  assert.deepEqual(getHistory('unknown'), []);
});

test('handled HTTP errors are retained; history is bounded and disabled tracing is a no-op', async (t) => {
  debugEnabled(t);
  const req = { user: { uid: 'bounded' }, params: {}, method: 'POST', path: '/test' };
  const handler = traceAction('Dislike', async (_, res) => { res.statusCode = 429; });
  for (let i = 0; i < 35; i++) await handler(req, { statusCode: 200 }, () => {});
  assert.equal(getHistory('bounded').length, 30);
  assert.equal(getHistory('bounded')[0].status, 'error');
  process.env.ENABLE_NEO4J_DEBUG = 'false';
  await handler({ ...req, user: { uid: 'disabled' } }, {}, () => {});
  assert.deepEqual(getHistory('disabled'), []);
});

test('manual query forwards JSON parameters but binds uid to the authenticated user', async (t) => {
  debugEnabled(t);
  const original = neo4jService.executeRead;
  t.after(() => { neo4jService.executeRead = original; });
  let received;
  neo4jService.executeRead = async (actions) => actions({ run: async (query, params) => {
    received = { query, params };
    return { records: [], summary: {} };
  } });
  const res = { statusCode: 200, status(code) { this.statusCode = code; return this; }, json(body) { this.body = body; } };
  await controller.query({ user: { uid: 'alice' }, body: {
    query: 'RETURN $uid, $tmdbId', mode: 'profile', params: { uid: 'bob', tmdbId: 550 },
  } }, res);
  assert.equal(res.statusCode, 200);
  assert.deepEqual(received, { query: 'PROFILE RETURN $uid, $tmdbId', params: { uid: 'alice', tmdbId: 550 } });
  await controller.query({ body: { query: 'RETURN 1', params: [] } }, res);
  assert.equal(res.statusCode, 400);
});

test('a completed trace emits one push summary for the owning user', async (t) => {
  debugEnabled(t);
  mockSession(t, async (actions) => actions({ run: async () => result() }));
  const originalIo = socketService.getIo;
  const originalEmit = socketService.emitToUser;
  const events = [];
  socketService.getIo = () => ({});
  socketService.emitToUser = (uid, event, payload) => events.push({ uid, event, payload });
  t.after(() => {
    socketService.getIo = originalIo;
    socketService.emitToUser = originalEmit;
  });
  const handler = traceAction('Like', async (_req, res) => {
    await neo4jService.run('RETURN 1');
    res.statusCode = 200;
  });
  const req = { user: { uid: 'push-user' }, method: 'POST', path: '/me/movies/550/like', params: { tmdbId: '550' } };
  await handler(req, { statusCode: 200 }, () => {});
  assert.equal(events.length, 1);
  assert.equal(events[0].uid, 'push-user');
  assert.equal(events[0].event, 'neo4j_live_action');
  assert.equal(events[0].payload.action, 'Like');
  assert.equal(events[0].payload.transactionStatuses.length, 0);
  assert.equal(events[0].payload.queryCount, 1);
});

test('recommendation path returns the 11 segments of a real path, or a reason', async (t) => {
  debugEnabled(t);
  const original = neo4jService.run;
  t.after(() => { neo4jService.run = original; });
  const values = {
    user: 'Alice',
    seedTmdbId: 329865, seedTitle: 'Arrival',
    seedMovieLensId: 1, seedMovieLensTitle: 'Arrival (2016)',
    neighborId: 42, seedRating: 4.5, candidateRating: 5.0,
    candidateTmdbId: 438631, candidateTitle: 'Dune',
    candidateMovieLensId: 2, candidateMovieLensTitle: 'Dune (2021)',
  };
  let lastParams;
  neo4jService.run = async (_, params) => {
    lastParams = params;
    return result(values);
  };
  const res = { statusCode: 200, status(code) { this.statusCode = code; return this; }, json(body) { this.body = body; } };
  await controller.recommendationPath({ user: { uid: 'alice' } }, res);
  assert.deepEqual(lastParams, { uid: 'alice' });
  assert.equal(res.body.segments.length, 11);
  assert.equal(res.body.segments[1].label, 'LIKED');
  assert.equal(res.body.segments[6].kind, 'movielens-user');
  assert.equal(res.body.path.candidate.title, 'Dune');

  neo4jService.run = async () => ({ records: [], summary: {} });
  await controller.recommendationPath({ user: { uid: 'alice' } }, res);
  assert.equal(res.body.path, null);
  assert.ok(res.body.reason.includes('No path available'));

  await controller.recommendationPath({}, res);
  assert.equal(res.statusCode, 401);
});

test('live endpoint uses only the current user and does not recalculate recommendations', async (t) => {
  debugEnabled(t);
  const original = neo4jService.run;
  t.after(() => { neo4jService.run = original; });
  let calls = 0;
  neo4jService.run = async (_, params) => {
    calls++;
    assert.deepEqual(params, { uid: 'bob' });
    return result({ displayName: 'Bob', library: [] });
  };
  const res = { json(body) { this.body = body; } };
  await controller.live({ user: { sub: 'bob' } }, res);
  assert.equal(calls, 1);
  assert.equal(res.body.displayName, 'Bob');
  assert.ok(res.body.entries.every((entry) => entry.queries.every((q) => q.query !== "RETURN 'alice'")));
});
