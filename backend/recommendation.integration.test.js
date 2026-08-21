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
