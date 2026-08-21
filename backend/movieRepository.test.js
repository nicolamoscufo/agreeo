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
  assert.match(calls[0].query, /MERGE \(m\)-\[:IN_GENRE\]->\(g\)/);
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

test('recordRecommendationBatch persists ranked source metadata', async (t) => {
  const calls = [];
  const originalRun = neo4jService.run;
  t.after(() => {
    neo4jService.run = originalRun;
  });
  neo4jService.run = async (query, params) => {
    calls.push({ query, params });
    return { records: [record({ includedCount: 2 })] };
  };

  const recorded = await movieRepository.recordRecommendationBatch('user-1', {
    batchId: 'batch-1',
    kind: 'daily',
    expiresAt: '2026-08-22T00:00:00.000Z',
    results: [
      { tmdbId: 10, recommendation: { source: 'hybrid', finalScore: 12.5 } },
      { tmdbId: 20, recommendation: { source: 'exploratory', finalScore: 8.0 } },
    ],
  });

  assert.equal(recorded, 2);
  assert.match(calls[1].query, /RecommendationBatch \{id: \$batchId\}/);
  assert.match(calls[1].query, /size\(movies\) = size\(\$items\)/);
  assert.match(calls[1].query, /MERGE \(batch\)-\[included:INCLUDED\]->\(movie\)/);
  assert.deepEqual(calls[1].params.items, [
    { tmdbId: 10, position: 0, source: 'hybrid', finalScore: 12.5 },
    { tmdbId: 20, position: 1, source: 'exploratory', finalScore: 8.0 },
  ]);
});

test('recommendation swipe is recorded atomically with the movie interaction', async (t) => {
  const calls = [];
  const originalExecuteWrite = neo4jService.executeWrite;
  t.after(() => {
    neo4jService.executeWrite = originalExecuteWrite;
  });
  neo4jService.executeWrite = async (actions) => actions({
    run: async (query, params) => {
      calls.push({ query, params });
      if (query.includes('existingSwipe')) {
        return { records: [record({ existingSwipe: null })] };
      }
      if (query.includes('DailySwipeQuota')) {
        return { records: [record({ usedToday: 4 })] };
      }
      if (query.includes('RETURN m.tmdbId AS tmdbId')) {
        return { records: [record({ tmdbId: 10 })] };
      }
      return { records: [] };
    },
  });

  const result = await movieRepository.likeMovie(
    'user-1',
    { tmdbId: 10, title: 'Movie', genres: ['Drama'] },
    {
      batchId: 'batch-1',
      action: 'like',
      source: 'daily-suggestion',
      position: 2,
      limitEnabled: true,
      limit: 20,
    }
  );

  assert.equal(result.updated, true);
  assert.deepEqual(result.dailyUsage, {
    usedToday: 4,
    remainingToday: 16,
    limit: 20,
  });
  assert.ok(calls.some(({ query }) => query.includes('included.swipedAt')));
});

test('recommendation swipe limit rejects before interaction writes', async (t) => {
  const calls = [];
  const originalExecuteWrite = neo4jService.executeWrite;
  t.after(() => {
    neo4jService.executeWrite = originalExecuteWrite;
  });
  neo4jService.executeWrite = async (actions) => actions({
    run: async (query) => {
      calls.push(query);
      if (query.includes('existingSwipe')) {
        return { records: [record({ existingSwipe: null })] };
      }
      return { records: [record({ usedToday: 21 })] };
    },
  });

  await assert.rejects(
    movieRepository.dislikeMovie(
      'user-1',
      { tmdbId: 10, title: 'Movie', genres: ['Drama'] },
      {
        batchId: 'batch-1',
        action: 'dislike',
        source: 'daily-suggestion',
        position: 2,
        limitEnabled: true,
        limit: 20,
      }
    ),
    (error) => error instanceof movieRepository.DailySwipeLimitError
  );
  assert.equal(calls.length, 2);
});

test('active daily recommendation cannot bypass context enforcement', async (t) => {
  const calls = [];
  const originalExecuteWrite = neo4jService.executeWrite;
  t.after(() => {
    neo4jService.executeWrite = originalExecuteWrite;
  });
  neo4jService.executeWrite = async (actions) => actions({
    run: async (query) => {
      calls.push(query);
      return { records: [record({ pendingContexts: 1 })] };
    },
  });

  await assert.rejects(
    movieRepository.likeMovie('user-1', {
      tmdbId: 10,
      title: 'Movie',
      genres: ['Drama'],
    }),
    (error) => error instanceof movieRepository.InvalidRecommendationContextError
  );
  assert.equal(calls.length, 1);
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

  assert.equal(calls.length, 3);
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
  assert.doesNotMatch(personalizedQuery, /WHERE r2\.rating >= 4\.0/);
  assert.match(personalizedQuery, /LIMIT toInteger\(\$neighborLimit\)/);
  assert.match(personalizedQuery, /avg\(toFloat\(r2\.rating\)\) AS similarRating/);
  assert.match(personalizedQuery, /coalesce\(sum\(abs\(similarityScore\)\), 1\.0\) AS weightedPreference/);
  assert.match(personalizedQuery, /\$supportShrinkage/);
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
    neighborLimit: 50,
    supportShrinkage: 5.0,
    globalMeanRating: 3.5,
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
  assert.match(personalizedQuery, /reduce\(\s+uniqueGenres = \[\]/);
  assert.match(personalizedQuery, /g\.count >= \$dislikedGenreThreshold/);
  assert.match(personalizedQuery, /candidateMl:MovieLensMovie\)-\[:IN_GENRE\]->\(recMlGenre:Genre\)/);
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

  assert.equal(calls.length, 3);
  assert.doesNotMatch(calls[0].query, /coalesce\(m\.movieLensRatingCount, 0\) >= \$minFallbackRatingCount/);
});

test('getExploratoryCandidates passes the limit as a query parameter', async (t) => {
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

  assert.match(calls[0].query, /LIMIT toInteger\(\$limit\)/);
  assert.match(
    calls[0].query,
    /NOT genre IN preferredGenres AND NOT genre IN positiveGenres AND NOT genre IN negativeGenres/
  );
  assert.match(calls[0].query, /reduce\(\s+uniqueGenres = \[\]/);
  assert.match(calls[0].query, /ORDER BY\s+finalScore DESC,\s+explorationBonus DESC/);
  assert.equal(calls[0].params.limit, 18);
});

test('debug signal queries pass the limit as a query parameter', async (t) => {
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

  for (const call of calls) {
    assert.match(call.query, /LIMIT toInteger\(\$limit\)/);
    assert.equal(call.params.limit, 5);
  }
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

test('diversifyRecommendations backfills a homogeneous ranked pool', async () => {
  const { diversifyRecommendations } = require('./movieController');
  const candidates = Array.from({ length: 8 }, (_, index) => ({
    tmdbId: index + 1,
    title: `Movie ${index + 1}`,
    genreIds: [1],
  }));

  const diversified = diversifyRecommendations(candidates, 8);

  assert.deepEqual(
    diversified.map((movie) => movie.tmdbId),
    candidates.map((movie) => movie.tmdbId)
  );
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
  assert.match(calls[1].query, /CALL db\.index\.vector\.queryNodes\('tag_embeddings', toInteger\(\$topK\), \$positiveTasteVector\)/);
  assert.match(calls[1].query, /vector\.similarity\.cosine\(tagNode\.embedding, \$negativeTasteVector\)/);
  
  const positiveTasteVector = calls[1].params.positiveTasteVector;
  const negativeTasteVector = calls[1].params.negativeTasteVector;
  assert.equal(positiveTasteVector.length, 384);
  assert.equal(negativeTasteVector.length, 384);
  assert.ok(Math.abs(positiveTasteVector[0] - (1 / Math.sqrt(384))) < 0.0001);
  assert.ok(Math.abs(negativeTasteVector[0] + (1 / Math.sqrt(384))) < 0.0001);
  assert.equal(calls[1].params.hasNegativeTaste, true);
  assert.equal(calls[1].params.limit, 10);
});

test('getSemanticTagRecommendationCandidates requires positive taste evidence', async (t) => {
  const calls = [];
  const originalRun = neo4jService.run;

  t.after(() => {
    neo4jService.run = originalRun;
  });

  neo4jService.run = async (query) => {
    calls.push(query);
    return {
      records: [
        record({
          embedding: new Array(384).fill(0.1),
          relType: 'DISLIKED',
          frequency: 1,
        }),
      ],
    };
  };

  const candidates = await movieRepository.getSemanticTagRecommendationCandidates('user-1');

  assert.deepEqual(candidates, []);
  assert.equal(calls.length, 1);
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

  // Reciprocal-rank fusion keeps source scales independent and rewards overlap.
  assert.equal(candidates.length, 3);
  assert.deepEqual(candidates.map(c => c.tmdbId), [200, 100, 300]);
  
  const movieB = candidates[0];
  assert.ok(movieB.finalScore > candidates[1].finalScore);
  assert.equal(movieB.source, 'hybrid');
  assert.equal(movieB.collaborativeRankingScore, 5.0);
  assert.equal(movieB.semanticScore, 8.0);
  assert.equal(movieB.collaborativeRank, 2);
  assert.equal(movieB.semanticRank, 1);
  assert.deepEqual(movieB.matchedTags, [{ tag: 'space', frequency: 3 }]);
  assert.match(movieB.reason, /High collaborative overlap.*Also matches themes you like/);
});

test('getRecommendationCandidates keeps collaborative results when semantic search fails', async (t) => {
  const originalRun = neo4jService.run;

  t.after(() => {
    neo4jService.run = originalRun;
  });

  neo4jService.run = async (query) => {
    if (query.includes("'personalized' AS source")) {
      return {
        records: [
          record({
            tmdbId: 100,
            title: 'Movie A',
            similarUsers: 3,
            collaborativeScore: 8,
            finalScore: 8,
            source: 'personalized',
          }),
        ],
      };
    }
    throw new Error('vector index unavailable');
  };

  const response = await movieRepository.getRecommendationCandidates('user-1');

  assert.deepEqual(response.candidates.map((candidate) => candidate.tmdbId), [100]);
});

test('concurrent recommendation requests share one in-flight computation', async (t) => {
  const originalRun = neo4jService.run;
  const originalNodeEnv = process.env.NODE_ENV;
  const originalTestContext = process.env.NODE_TEST_CONTEXT;
  process.env.NODE_ENV = 'production';
  delete process.env.NODE_TEST_CONTEXT;
  const uid = 'in-flight-user';
  movieRepository.invalidateRecommendationCache(uid);
  t.after(() => {
    neo4jService.run = originalRun;
    movieRepository.invalidateRecommendationCache(uid);
    if (originalNodeEnv == null) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = originalNodeEnv;
    if (originalTestContext == null) delete process.env.NODE_TEST_CONTEXT;
    else process.env.NODE_TEST_CONTEXT = originalTestContext;
  });

  let collaborativeCalls = 0;
  neo4jService.run = async (query) => {
    if (query.includes("'personalized' AS source")) {
      collaborativeCalls += 1;
      await new Promise((resolve) => setTimeout(resolve, 30));
    }
    return { records: [] };
  };

  const [first, second] = await Promise.all([
    movieRepository.getRecommendationCandidates(uid, { bypassCache: true }),
    movieRepository.getRecommendationCandidates(uid, { bypassCache: true }),
  ]);

  assert.equal(collaborativeCalls, 1);
  assert.deepEqual(
    new Set([first.cacheStatus, second.cacheStatus]),
    new Set(['computed', 'shared-in-flight'])
  );
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
  assert.match(calls[0].query, /LIMIT toInteger\(\$limit\)/);
  assert.equal(calls[0].params.limit, 5);
  assert.match(calls[1].query, /DISLIKED/);
  assert.match(calls[1].query, /LIMIT toInteger\(\$limit\)/);
  assert.equal(calls[1].params.limit, 5);
});
