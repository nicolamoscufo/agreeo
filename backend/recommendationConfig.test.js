const assert = require('node:assert/strict');
const test = require('node:test');

const { recommendationConfigForUser } = require('./recommendationConfig');

test('recommendation A/B assignment is deterministic and split', (t) => {
  const previous = process.env.ENABLE_RECOMMENDATION_AB_TEST;
  process.env.ENABLE_RECOMMENDATION_AB_TEST = 'true';
  t.after(() => {
    if (previous == null) delete process.env.ENABLE_RECOMMENDATION_AB_TEST;
    else process.env.ENABLE_RECOMMENDATION_AB_TEST = previous;
  });

  const first = recommendationConfigForUser('user-1');
  assert.equal(recommendationConfigForUser('user-1').variant, first.variant);
  const variants = new Set(
    Array.from({ length: 100 }, (_, index) =>
      recommendationConfigForUser(`user-${index}`).variant
    )
  );
  assert.deepEqual(
    [...variants].sort(),
    ['control-v1', 'semantic-balanced-v1']
  );
});

test('recommendation environment values are bounded', (t) => {
  const previousTopK = process.env.SEMANTIC_TOP_K;
  const previousThreshold = process.env.SEMANTIC_SIMILARITY_THRESHOLD;
  process.env.SEMANTIC_TOP_K = '9999';
  process.env.SEMANTIC_SIMILARITY_THRESHOLD = '-9';
  t.after(() => {
    if (previousTopK == null) delete process.env.SEMANTIC_TOP_K;
    else process.env.SEMANTIC_TOP_K = previousTopK;
    if (previousThreshold == null) delete process.env.SEMANTIC_SIMILARITY_THRESHOLD;
    else process.env.SEMANTIC_SIMILARITY_THRESHOLD = previousThreshold;
  });

  const config = recommendationConfigForUser('user');
  assert.equal(config.semanticTopK, 200);
  assert.equal(config.semanticSimilarityThreshold, -1);
});
