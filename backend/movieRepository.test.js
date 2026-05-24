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

  assert.equal(calls.length, 2);
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
  assert.match(personalizedQuery, /1\.0 \/ sqrt\(log\(toFloat\(coalesce\(seed\.movieLensRatingCount, seedMl\.movieLensRatingCount, 0\)\) \+ 10\.0\)\)/);
  assert.match(personalizedQuery, /count\(DISTINCT seed\) AS overlapCount/);
  assert.match(personalizedQuery, /coalesce\(sum\(similarityScore\), 1\.0\)\) \* log\(toFloat\(count\(DISTINCT similar\)\) \+ 1\.0\) \* 10\.0\) AS collaborativeScore/);
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
  assert.match(personalizedQuery, /OPTIONAL MATCH \(me\)-\[r:LIKED\|DISLIKED\|SELECTED_FAVORITE\|WATCHLISTED\]->\(m:Movie\)/);
  assert.match(personalizedQuery, /mMl:MovieLensMovie\)-\[:IN_GENRE\]->\(mlGenre:Genre\)/);
  assert.match(personalizedQuery, /OPTIONAL MATCH \(m\)-\[:IN_GENRE\]->\(movieGenre:Genre\)/);
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

  assert.equal(calls.length, 2);
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

test('getSemanticTagRecommendationCandidates queries user history, calculates taste vector and runs tag index vector search', async (t) => {
  const calls = [];
  const originalRun = neo4jService.run;

  t.after(() => {
    neo4jService.run = originalRun;
  });

  neo4jService.run = async (query, params) => {
    calls.push({ query, params });
    if (calls.length === 1) {
      // 1. Swiped tags query
      return {
        records: [
          record({
            embedding: new Array(384).fill(0.1),
            relType: 'LIKED',
            frequency: 2,
          }),
          record({
            embedding: new Array(384).fill(-0.2),
            relType: 'DISLIKED',
            frequency: 1,
          }),
        ],
      };
    }
    // 2. Vector search query
    return {
      records: [
        record({
          tmdbId: 101,
          title: 'Semantic Match 1',
          tagRelevanceScore: 0.8,
          matchedTags: [{ tag: 'space', frequency: 5 }],
          globalAvg: 4.2,
          ratingCount: 1500,
        }),
      ],
    };
  };

  const candidates = await movieRepository.getSemanticTagRecommendationCandidates('user-1', 10);

  assert.equal(candidates.length, 1);
  assert.equal(candidates[0].tmdbId, 101);
  assert.equal(candidates[0].title, 'Semantic Match 1');
  assert.equal(candidates[0].source, 'semantic-tag');
  
  // Verify calls
  assert.equal(calls.length, 2);
  assert.match(calls[0].query, /MATCH \(u:AppUser \{uid: \$uid\}\)-\[r:LIKED\|SELECTED_FAVORITE\|WATCHLISTED\|DISLIKED\]->\(m:Movie\)/);
  assert.match(calls[1].query, /CALL db\.index\.vector\.queryNodes\('tag_embeddings', toInteger\(\$topK\), \$userTasteVector\)/);
  
  // Taste vector verification
  // LIKED: 0.1 * 3.0 (liked weight) * 2 (frequency) = 0.6
  // DISLIKED: -0.2 * -3.0 (disliked weight) * 1 (frequency) = 0.6
  // Sum = 1.2
  // TotalWeight = (3 * 2) + (-3 * 1) = 6 - 3 = 3.
  // Vector dimension value = 1.2 / 3 = 0.4.
  const computedTasteVector = calls[1].params.userTasteVector;
  assert.equal(computedTasteVector.length, 384);
  assert.ok(Math.abs(computedTasteVector[0] - 0.4) < 0.0001);
  assert.equal(calls[1].params.limit, 10);
});

test('getRecommendationCandidates combines collaborative and semantic candidates as a hybrid pool', async (t) => {
  const calls = [];
  const originalRun = neo4jService.run;

  t.after(() => {
    neo4jService.run = originalRun;
  });

  neo4jService.run = async (query, params) => {
    calls.push({ query, params });
    if (query.includes('personalized')) {
      // Collaborative filtering query
      return {
        records: [
          record({
            tmdbId: 100,
            title: 'Movie A',
            similarUsers: 5,
            avgSimilarRating: 4.5,
            collaborativeScore: 10.0,
            genreScore: 0.0,
            popularityScore: 2.0,
            negativePenalty: 0.0,
            explorationBonus: 0.0,
            finalScore: 10.0,
            globalAvg: 4.0,
            ratingCount: 500,
            source: 'personalized',
          }),
          record({
            tmdbId: 200,
            title: 'Movie B',
            similarUsers: 2,
            avgSimilarRating: 4.0,
            collaborativeScore: 5.0,
            genreScore: 0.0,
            popularityScore: 1.5,
            negativePenalty: 0.0,
            explorationBonus: 0.0,
            finalScore: 5.0,
            globalAvg: 3.8,
            ratingCount: 200,
            source: 'personalized',
          }),
        ],
      };
    } else if (query.includes('MATCH (u:AppUser {uid: $uid})-[r:LIKED')) {
      // Swiped tags query
      return {
        records: [
          record({
            embedding: new Array(384).fill(0.1),
            relType: 'LIKED',
            frequency: 1,
          }),
        ],
      };
    } else if (query.includes('queryNodes')) {
      // Vector search query
      return {
        records: [
          record({
            tmdbId: 200,
            title: 'Movie B',
            tagRelevanceScore: 0.8, // raw tag score. in JS it gets multiplied by 10 => 8.0 finalScore
            matchedTags: [{ tag: 'space', frequency: 3 }],
            globalAvg: 3.8,
            ratingCount: 200,
          }),
          record({
            tmdbId: 300,
            title: 'Movie C',
            tagRelevanceScore: 1.2, // raw tag score. in JS it gets multiplied by 10 => 12.0 finalScore
            matchedTags: [{ tag: 'time', frequency: 2 }],
            globalAvg: 4.1,
            ratingCount: 100,
          }),
        ],
      };
    }
    return { records: [] };
  };

  const response = await movieRepository.getRecommendationCandidates('user-1');
  const candidates = response.candidates;

  // Expected combined & sorted candidates:
  // 1. Movie B (hybrid): 5.0 (personalized) + 8.0 (semantic) = 13.0
  // 2. Movie C (semantic): 12.0
  // 3. Movie A (personalized): 10.0
  assert.equal(candidates.length, 3);
  assert.deepEqual(candidates.map(c => c.tmdbId), [200, 300, 100]);
  
  const movieB = candidates[0];
  assert.equal(movieB.finalScore, 13.0);
  assert.equal(movieB.source, 'hybrid');
  assert.match(movieB.reason, /High collaborative overlap.*Also matches themes you like/);
});

test('getTopPositiveTagSignals and getTopNegativeTagSignals query and compute tag weights', async (t) => {
  const calls = [];
  const originalRun = neo4jService.run;

  t.after(() => {
    neo4jService.run = originalRun;
  });

  neo4jService.run = async (query, params) => {
    calls.push({ query, params });
    return {
      records: [
        record({
          name: 'sci-fi',
          score: 12.5,
        }),
      ],
    };
  };

  const posSignals = await movieRepository.getTopPositiveTagSignals('user-1', 5);
  const negSignals = await movieRepository.getTopNegativeTagSignals('user-1', 5);

  assert.equal(posSignals.length, 1);
  assert.equal(posSignals[0].name, 'sci-fi');
  assert.equal(posSignals[0].score, 12.5);

  assert.equal(negSignals.length, 1);
  assert.equal(negSignals[0].name, 'sci-fi');
  assert.equal(negSignals[0].score, 12.5);

  assert.equal(calls.length, 2);
  assert.match(calls[0].query, /LIKED\|SELECTED_FAVORITE\|WATCHLISTED/);
  assert.match(calls[0].query, /LIMIT 5/);
  assert.match(calls[1].query, /DISLIKED/);
  assert.match(calls[1].query, /LIMIT 5/);
});
