const assert = require('node:assert/strict');
const test = require('node:test');
const { randomUUID } = require('node:crypto');

const neo4jService = require('./neo4jService');
const movieRepository = require('./movieRepository');

test(
  'Neo4j recommendation batches enforce an atomic daily quota',
  {
    skip: process.env.NEO4J_INTEGRATION !== 'true',
    timeout: 120_000,
  },
  async (t) => {
    const uid = `integration-${randomUUID()}`;
    const tmdbIds = [99000001, 99000002];
    await neo4jService.initialize();
    const traceProbe = await neo4jService.captureQueryTrace(() =>
      neo4jService.run(
        'RETURN $uid AS uid, size($vector) AS dimensions',
        { uid, vector: new Array(384).fill(0) }
      )
    );
    assert.equal(traceProbe.queries.length, 1);
    assert.equal(traceProbe.queries[0].params.uid, '<current-user>');
    assert.equal(traceProbe.queries[0].params.vector, '<array:384>');
    assert.equal(traceProbe.queries[0].records, 1);
    t.after(async () => {
      await neo4jService.run(
        'MATCH (batch:RecommendationBatch {uid: $uid}) DETACH DELETE batch',
        { uid }
      );
      await neo4jService.run(
        'MATCH (quota:DailySwipeQuota {uid: $uid}) DETACH DELETE quota',
        { uid }
      );
      await neo4jService.run('MATCH (user:AppUser {uid: $uid}) DETACH DELETE user', { uid });
      await neo4jService.run('MATCH (movie:Movie) WHERE movie.tmdbId IN $tmdbIds DETACH DELETE movie', { tmdbIds });
      await neo4jService.close();
    });

    await neo4jService.run(
      `
      CREATE (:AppUser {
        uid: $uid,
        email: $email,
        emailNormalized: $email,
        displayName: 'Integration Test',
        createdAt: datetime()
      })
      `,
      { uid, email: `${uid}@example.invalid` }
    );
    for (const tmdbId of tmdbIds) {
      await movieRepository.mergeTmdbMovie({
        tmdbId,
        title: `Movie ${tmdbId}`,
        genres: ['Drama'],
      });
    }

    const expiresAt = new Date(Date.now() + 86_400_000).toISOString();
    // Exercise the live snapshots against the actual Neo4j engine before
    // creating Daily contexts for these movies.
    const probeMovie = { tmdbId: tmdbIds[0], title: 'Trace probe', genres: ['Drama'] };
    async function traceInteraction(action) {
      const queries = [];
      queries.captureState = true;
      await neo4jService.captureQueryTrace(action, queries);
      assert.equal(queries.transactions[0].status, 'committed');
      return queries.transactions[0];
    }
    const likeTrace = await traceInteraction(() => movieRepository.likeMovie(uid, probeMovie));
    assert.deepEqual(likeTrace.before.relationships, []);
    assert.deepEqual(likeTrace.after.relationships.map((r) => r.type), ['LIKED']);
    const watchTrace = await traceInteraction(() => movieRepository.watchlistMovie(uid, probeMovie));
    assert.deepEqual(watchTrace.after.relationships.map((r) => r.type).sort(), ['LIKED', 'WATCHLISTED']);
    const dislikeTrace = await traceInteraction(() => movieRepository.dislikeMovie(uid, probeMovie));
    assert.deepEqual(dislikeTrace.before.relationships.map((r) => r.type).sort(), ['LIKED', 'WATCHLISTED']);
    assert.deepEqual(dislikeTrace.after.relationships.map((r) => r.type), ['DISLIKED']);
    const removalTrace = await traceInteraction(() => movieRepository.removeDislike(uid, tmdbIds[0]));
    assert.deepEqual(removalTrace.after.relationships, []);

    const batches = [randomUUID(), randomUUID()];
    await Promise.all(tmdbIds.map((tmdbId, index) =>
      movieRepository.recordRecommendationBatch(uid, {
        batchId: batches[index],
        kind: 'daily',
        expiresAt,
        experimentVariant: 'integration',
        results: [{
          tmdbId,
          recommendation: { source: 'integration', finalScore: 1 },
        }],
      })
    ));

    const actions = await Promise.allSettled([
      movieRepository.likeMovie(uid, { tmdbId: tmdbIds[0], title: 'A', genres: ['Drama'] }, {
        batchId: batches[0], action: 'like', source: 'daily-suggestion', position: 0,
        limitEnabled: true, limit: 1,
      }),
      movieRepository.dislikeMovie(uid, { tmdbId: tmdbIds[1], title: 'B', genres: ['Drama'] }, {
        batchId: batches[1], action: 'dislike', source: 'daily-suggestion', position: 0,
        limitEnabled: true, limit: 1,
      }),
    ]);

    assert.equal(actions.filter((result) => result.status === 'fulfilled').length, 1);
    assert.equal(
      actions.filter(
        (result) => result.status === 'rejected' &&
          result.reason instanceof movieRepository.DailySwipeLimitError
      ).length,
      1
    );
    assert.equal(await movieRepository.getDailySwipeUsage(uid), 1);
  }
);
