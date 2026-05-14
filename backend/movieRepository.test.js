const assert = require('node:assert/strict');
const test = require('node:test');

const neo4jService = require('./neo4jService');
const movieRepository = require('./movieRepository');

function record(values) {
  return {
    get(key) {
      return values[key];
    },
  };
}

test('saveSelectedFavorites persists SELECTED_FAVORITE relationships by tmdbId', async (t) => {
  const calls = [];
  const originalRun = neo4jService.run;

  t.after(() => {
    neo4jService.run = originalRun;
  });

  neo4jService.run = async (query, params) => {
    calls.push({ query, params });
    return { records: [record({ selectedCount: 2 })] };
  };

  const saved = await movieRepository.saveSelectedFavorites('user-1', [
    {
      tmdbId: 329865,
      title: 'Arrival',
      originalTitle: 'Arrival',
      overview: '',
      posterPath: null,
      backdropPath: null,
      posterUrl: '',
      backdropUrl: '',
      releaseDate: '2016-11-10',
      voteAverage: 7.6,
    },
    {
      tmdbId: 693134,
      title: 'Dune: Part Two',
      originalTitle: 'Dune: Part Two',
      overview: '',
      posterPath: null,
      backdropPath: null,
      posterUrl: '',
      backdropUrl: '',
      releaseDate: '2024-02-27',
      voteAverage: 8.1,
    },
  ]);

  assert.equal(saved, true);
  assert.equal(calls.length, 3);
  assert.match(calls[0].query, /MERGE \(m:Movie \{tmdbId: \$tmdbId\}\)/);
  assert.match(calls[2].query, /MATCH \(m:Movie \{tmdbId: tmdbId\}\)/);
  assert.match(calls[2].query, /MERGE \(u\)-\[r:SELECTED_FAVORITE\]->\(m\)/);
  assert.match(calls[2].query, /SET r\.weight = \$weight/);
  assert.match(calls[2].query, /RETURN selectedCount/);
  assert.deepEqual(calls[2].params, {
    uid: 'user-1',
    tmdbIds: [329865, 693134],
    weight: 4.0,
  });
});

test('savePreferredGenres persists onboarding genres as PREFERS_GENRE', async (t) => {
  const calls = [];
  const originalRun = neo4jService.run;

  t.after(() => {
    neo4jService.run = originalRun;
  });

  neo4jService.run = async (query, params) => {
    calls.push({ query, params });
    return { records: [record({ preferredGenreCount: 2 })] };
  };

  const saved = await movieRepository.savePreferredGenres('user-1', [
    'Drama',
    'Sci-Fi',
    'Drama',
    '',
  ]);

  assert.equal(saved, true);
  assert.equal(calls.length, 1);
  assert.match(calls[0].query, /MERGE \(g:Genre \{name: genreName\}\)/);
  assert.match(calls[0].query, /MERGE \(u\)-\[r:PREFERS_GENRE\]->\(g\)/);
  assert.match(calls[0].query, /RETURN preferredGenreCount/);
  assert.deepEqual(calls[0].params, {
    uid: 'user-1',
    genres: ['Drama', 'Sci-Fi', 'Drama'],
  });
});

test('getRecommendations excludes selected favorites from personalized recommendations', async (t) => {
  const calls = [];
  const originalRun = neo4jService.run;

  t.after(() => {
    neo4jService.run = originalRun;
  });

  neo4jService.run = async (query, params) => {
    calls.push({ query, params });
    return { records: [] };
  };

  await movieRepository.getRecommendations('user-1');

  assert.equal(calls.length, 1);
  assert.match(calls[0].query, /LIKED\|SELECTED_FAVORITE\|WATCHLISTED/);
  assert.match(
    calls[0].query,
    /LIKED\|DISLIKED\|WATCHLISTED\|ALREADY_SEEN\|SELECTED_FAVORITE/
  );
});

test('getRecommendations ranks candidates by weighted collaborative score', async (t) => {
  const calls = [];
  const originalRun = neo4jService.run;

  t.after(() => {
    neo4jService.run = originalRun;
  });

  neo4jService.run = async (query, params) => {
    calls.push({ query, params });
    return { records: [] };
  };

  await movieRepository.getRecommendations('user-1');

  const personalizedQuery = calls[0].query;
  assert.match(personalizedQuery, /CASE type\(signal\)/);
  assert.match(personalizedQuery, /WHEN 'SELECTED_FAVORITE' THEN coalesce\(signal\.weight, \$selectedFavoriteWeight\)/);
  assert.match(personalizedQuery, /WHEN 'LIKED' THEN \$likedWeight/);
  assert.match(personalizedQuery, /WHEN 'WATCHLISTED' THEN \$watchlistedWeight/);
  assert.match(personalizedQuery, /\* \(toFloat\(r1\.rating\) - 3\.0\)/);
  assert.match(personalizedQuery, /1\.0 \/ log\(toFloat\(coalesce\(seed\.movieLensRatingCount, seedMl\.movieLensRatingCount, 0\)\) \+ 2\.0\)/);
  assert.match(personalizedQuery, /count\(DISTINCT seed\) AS overlapCount/);
  assert.match(personalizedQuery, /sum\(similarityScore \* \(toFloat\(r2\.rating\) - 3\.0\)\) AS collaborativeScore/);
  assert.match(personalizedQuery, /collaborativeScore - negativePenalty AS finalScore/);
  assert.match(personalizedQuery, /ORDER BY\s+finalScore DESC/);
  assert.match(personalizedQuery, /LIMIT 80/);
  assert.deepEqual(calls[0].params, {
    uid: 'user-1',
    selectedFavoriteWeight: 4.0,
    likedWeight: 3.0,
    watchlistedWeight: 1.25,
    dislikedGenreThreshold: 2,
    dislikedGenrePenalty: 1.5,
  });
});

test('getRecommendations applies a safe disliked-genre penalty', async (t) => {
  const calls = [];
  const originalRun = neo4jService.run;

  t.after(() => {
    neo4jService.run = originalRun;
  });

  neo4jService.run = async (query, params) => {
    calls.push({ query, params });
    return { records: [] };
  };

  await movieRepository.getRecommendations('user-1');

  const personalizedQuery = calls[0].query;
  assert.match(personalizedQuery, /OPTIONAL MATCH \(me\)-\[:DISLIKED\]->\(disliked:Movie\)/);
  assert.match(personalizedQuery, /dislikedMl:MovieLensMovie\)-\[:IN_GENRE\]->\(mlGenre:Genre\)/);
  assert.match(personalizedQuery, /OPTIONAL MATCH \(disliked\)-\[:IN_GENRE\]->\(movieGenre:Genre\)/);
  assert.match(personalizedQuery, /g\.count >= \$dislikedGenreThreshold/);
  assert.match(personalizedQuery, /OPTIONAL MATCH \(recMl\)-\[:IN_GENRE\]->\(recMlGenre:Genre\)/);
  assert.match(personalizedQuery, /OPTIONAL MATCH \(rec\)-\[:IN_GENRE\]->\(recMovieGenre:Genre\)/);
  assert.match(personalizedQuery, /\$dislikedGenrePenalty \* toFloat\(entry\.count\)/);
  assert.match(personalizedQuery, /max\(negativePenalty\) AS negativePenalty/);
});

test('getRecommendations does not query a cold-start fallback', async (t) => {
  const calls = [];
  const originalRun = neo4jService.run;

  t.after(() => {
    neo4jService.run = originalRun;
  });

  neo4jService.run = async (query, params) => {
    calls.push({ query, params });
    return { records: [] };
  };

  await movieRepository.getRecommendations('user-1');

  assert.equal(calls.length, 1);
  assert.doesNotMatch(calls[0].query, /coalesce\(m\.movieLensRatingCount, 0\) >= \$minFallbackRatingCount/);
});

test('getExploratoryCandidates inlines an integer Cypher limit', async (t) => {
  const calls = [];
  const originalRun = neo4jService.run;

  t.after(() => {
    neo4jService.run = originalRun;
  });

  neo4jService.run = async (query, params) => {
    calls.push({ query, params });
    return { records: [] };
  };

  await movieRepository.getExploratoryCandidates('user-1', {
    excludedTmdbIds: [10, 20],
    limit: 18,
  });

  assert.match(calls[0].query, /LIMIT 18/);
  assert.equal(Object.prototype.hasOwnProperty.call(calls[0].params, 'limit'), false);
});

test('debug signal queries inline integer Cypher limits', async (t) => {
  const calls = [];
  const originalRun = neo4jService.run;

  t.after(() => {
    neo4jService.run = originalRun;
  });

  neo4jService.run = async (query, params) => {
    calls.push({ query, params });
    return { records: [] };
  };

  await movieRepository.getTopPositiveGenreSignals('user-1', 5);
  await movieRepository.getTopNegativeGenreSignals('user-1', 5);
  await movieRepository.getTopPositiveMovies('user-1', 5);
  await movieRepository.getTopNegativeMovies('user-1', 5);

  assert.match(calls[0].query, /LIMIT 5/);
  assert.match(calls[1].query, /LIMIT 5/);
  assert.match(calls[2].query, /LIMIT 5/);
  assert.match(calls[3].query, /LIMIT 5/);
  assert.deepEqual(calls.map((entry) => Object.prototype.hasOwnProperty.call(entry.params, 'limit')), [false, false, false, false]);
});

test('diversifyRecommendations removes duplicates and caps genre repetition', async () => {
  const { diversifyRecommendations } = require('./movieController');

  const diversified = diversifyRecommendations(
    [
      { tmdbId: 1, title: 'Alpha', genreIds: [1] },
      { tmdbId: 1, title: 'Alpha', genreIds: [1] },
      { tmdbId: 2, title: 'Alpha!', genreIds: [1] },
      { tmdbId: 3, title: 'Beta', genreIds: [1] },
      { tmdbId: 4, title: 'Gamma', genreIds: [2] },
      { tmdbId: 5, title: 'Delta', genreIds: [2] },
    ],
    4
  );

  assert.deepEqual(diversified.map((movie) => movie.tmdbId), [1, 3, 4, 5]);
});

test('diversifyRecommendations still dedupes when genre data is missing', async () => {
  const { diversifyRecommendations } = require('./movieController');

  const diversified = diversifyRecommendations(
    [
      { tmdbId: 10, title: 'The One' },
      { tmdbId: 11, title: 'The One!' },
      { tmdbId: 12, title: 'The Two' },
    ],
    3
  );

  assert.deepEqual(diversified.map((movie) => movie.tmdbId), [10, 12]);
});
