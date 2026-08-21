const { createHash } = require('node:crypto');

function numberFromEnv(name, fallback, { min = -Infinity, max = Infinity, integer = false } = {}) {
  const parsed = integer
    ? Number.parseInt(String(process.env[name] ?? ''), 10)
    : Number.parseFloat(String(process.env[name] ?? ''));
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(max, Math.max(min, parsed));
}

function recommendationConfigForUser(uid) {
  const abEnabled = String(process.env.ENABLE_RECOMMENDATION_AB_TEST || 'false').toLowerCase() === 'true';
  const bucket = Number.parseInt(
    createHash('sha256').update(String(uid || 'anonymous')).digest('hex').slice(0, 8),
    16
  ) % 100;
  const variant = abEnabled && bucket >= 50 ? 'semantic-balanced-v1' : 'control-v1';

  return {
    variant,
    semanticTopK: numberFromEnv('SEMANTIC_TOP_K', 25, { min: 5, max: 200, integer: true }),
    semanticSimilarityThreshold: numberFromEnv('SEMANTIC_SIMILARITY_THRESHOLD', 0.35, { min: -1, max: 1 }),
    semanticNegativePenalty: numberFromEnv('SEMANTIC_NEGATIVE_PENALTY', 0.75, { min: 0, max: 5 }),
    semanticWeight: variant === 'semantic-balanced-v1'
      ? numberFromEnv('AB_SEMANTIC_WEIGHT', 1.0, { min: 0, max: 5 })
      : numberFromEnv('SEMANTIC_RRF_WEIGHT', 0.85, { min: 0, max: 5 }),
    reciprocalRankK: numberFromEnv('RECIPROCAL_RANK_K', 60, { min: 1, max: 500, integer: true }),
    collaborativeNeighborLimit: numberFromEnv('COLLABORATIVE_NEIGHBOR_LIMIT', 50, { min: 5, max: 200, integer: true }),
    supportShrinkage: numberFromEnv('COLLABORATIVE_SUPPORT_SHRINKAGE', 5.0, { min: 0.1, max: 100 }),
    dailyPersonalizedRatio: variant === 'semantic-balanced-v1' ? 0.6 : 0.65,
  };
}

module.exports = { recommendationConfigForUser };
