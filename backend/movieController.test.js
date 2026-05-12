const assert = require('node:assert/strict');
const test = require('node:test');

const { hydrateRecommendations } = require('./movieController');

test('hydrateRecommendations preserves order and skips stale TMDB ids', async () => {
  const warned = [];
  const hydrated = await hydrateRecommendations(
    [
      { tmdbId: 1, similarUsers: 2, avgSimilarRating: 4.5, globalAvg: 3.8, ratingCount: 120 },
      { tmdbId: 2, similarUsers: 2, avgSimilarRating: 4.4, globalAvg: 3.7, ratingCount: 90 },
      { tmdbId: 3, similarUsers: 1, avgSimilarRating: 4.1, globalAvg: 3.6, ratingCount: 80 },
    ],
    {
      limit: 30,
      batchSize: 2,
      tmdbFetch: async (path) => {
        if (path === '/movie/2') {
          throw new Error('TMDB error 404: missing');
        }

        return {
          id: Number(path.split('/').pop()),
          title: `Movie ${path.split('/').pop()}`,
          overview: 'Overview',
          poster_path: '/poster.jpg',
          backdrop_path: '/backdrop.jpg',
          release_date: '2024-01-01',
          vote_average: 7.5,
          genre_ids: [1],
        };
      },
      findMovieByTmdbId: async (tmdbId) => ({
        tmdbId,
        movieLensAvgRating: 3.3,
        movieLensRatingCount: 50,
      }),
      logger: { warn: (message) => warned.push(message) },
    }
  );

  assert.deepEqual(hydrated.map((movie) => movie.tmdbId), [1, 3]);
  assert.equal(warned.length, 1);
  assert.match(warned[0], /Skipping stale TMDB recommendation 2/);
});

test('hydrateRecommendations stops once the limit is reached', async () => {
  let fetchCount = 0;
  const hydrated = await hydrateRecommendations(
    Array.from({ length: 40 }, (_, index) => ({
      tmdbId: index + 1,
      similarUsers: 1,
      avgSimilarRating: 4.2,
      globalAvg: 3.5,
      ratingCount: 100,
    })),
    {
      limit: 30,
      batchSize: 4,
      tmdbFetch: async (path) => {
        fetchCount += 1;
        const tmdbId = Number(path.split('/').pop());
        return {
          id: tmdbId,
          title: `Movie ${tmdbId}`,
          overview: 'Overview',
          poster_path: '/poster.jpg',
          backdrop_path: '/backdrop.jpg',
          release_date: '2024-01-01',
          vote_average: 7.5,
          genre_ids: [1],
        };
      },
      findMovieByTmdbId: async (tmdbId) => ({ tmdbId }),
      logger: { warn: () => {} },
    }
  );

  assert.equal(hydrated.length, 30);
  assert.equal(fetchCount, 32);
});
