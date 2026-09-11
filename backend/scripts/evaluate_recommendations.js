require('dotenv').config();
const neo4jService = require('../neo4jService');

function mean(values) {
  return values.length === 0
    ? 0
    : values.reduce((sum, value) => sum + value, 0) / values.length;
}

function dcg(relevances, limit) {
  return relevances.slice(0, limit).reduce(
    (score, relevance, index) => score + relevance / Math.log2(index + 2),
    0
  );
}

async function evaluate() {
  const days = Math.max(1, Math.min(365, Number.parseInt(process.argv[2] || '30', 10) || 30));
  const result = await neo4jService.run(
    `
    MATCH (batch:RecommendationBatch)-[included:INCLUDED]->(movie:Movie)
    WHERE batch.createdAt >= datetime() - duration({days: $days})
    RETURN
      batch.id AS batchId,
      coalesce(batch.experimentVariant, 'control-v1') AS variant,
      coalesce(included.source, 'unknown') AS source,
      included.position AS position,
      included.action AS action,
      movie.tmdbId AS tmdbId
    ORDER BY batchId, position
    `,
    { days }
  );
  const totalMoviesResult = await neo4jService.run(
    'MATCH (movie:Movie) WHERE movie.tmdbId IS NOT NULL RETURN count(movie) AS totalMovies'
  );
  const totalMovies = totalMoviesResult.records[0].get('totalMovies').toNumber();
  const batches = new Map();
  const uniqueRecommended = new Set();

  for (const record of result.records) {
    const batchId = record.get('batchId');
    const item = {
      variant: record.get('variant'),
      source: record.get('source'),
      position: Number(record.get('position')?.toNumber?.() ?? record.get('position') ?? 0),
      action: record.get('action'),
      tmdbId: Number(record.get('tmdbId')?.toNumber?.() ?? record.get('tmdbId')),
    };
    if (!batches.has(batchId)) batches.set(batchId, []);
    batches.get(batchId).push(item);
    uniqueRecommended.add(item.tmdbId);
  }

  const groups = new Map();
  for (const items of batches.values()) {
    items.sort((left, right) => left.position - right.position);
    const key = items[0]?.variant || 'control-v1';
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(items);
  }

  const byVariant = {};
  for (const [variant, variantBatches] of groups) {
    const precisionAt10 = [];
    const reciprocalRanks = [];
    const ndcgAt10 = [];
    for (const items of variantBatches) {
      const relevance = items.map((item) =>
        ['like', 'watchlist', 'seen'].includes(item.action) ? 1 : 0
      );
      precisionAt10.push(
        relevance.slice(0, 10).reduce((sum, value) => sum + value, 0) /
          Math.max(1, Math.min(10, relevance.length))
      );
      const firstRelevant = relevance.findIndex((value) => value > 0);
      reciprocalRanks.push(firstRelevant < 0 ? 0 : 1 / (firstRelevant + 1));
      const ideal = [...relevance].sort((left, right) => right - left);
      const idealDcg = dcg(ideal, 10);
      ndcgAt10.push(idealDcg === 0 ? 0 : dcg(relevance, 10) / idealDcg);
    }
    byVariant[variant] = {
      batches: variantBatches.length,
      precisionAt10: mean(precisionAt10),
      meanReciprocalRank: mean(reciprocalRanks),
      ndcgAt10: mean(ndcgAt10),
    };
  }

  console.log(JSON.stringify({
    days,
    batches: batches.size,
    catalogCoverage: totalMovies === 0 ? 0 : uniqueRecommended.size / totalMovies,
    uniqueRecommendedMovies: uniqueRecommended.size,
    byVariant,
  }, null, 2));
}

evaluate()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => neo4jService.close());
