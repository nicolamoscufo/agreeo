const neo4jService = require('./neo4jService');

function toNativeNumber(value) {
  if (value == null) {
    return value;
  }

  if (typeof value === 'number') {
    return value;
  }

  if (typeof value.toNumber === 'function') {
    return value.toNumber();
  }

  return Number(value);
}

function normalizeMovieRecord(record) {
  if (!record) {
    return null;
  }

  return {
    tmdbId: toNativeNumber(record.get('tmdbId')),
    title: record.get('title') || '',
    originalTitle: record.get('originalTitle') || '',
    overview: record.get('overview') || '',
    posterPath: record.get('posterPath') || null,
    backdropPath: record.get('backdropPath') || null,
    posterUrl: record.get('posterUrl') || '',
    backdropUrl: record.get('backdropUrl') || '',
    releaseDate: record.get('releaseDate') || '',
    runtime: record.get('runtime') == null ? null : toNativeNumber(record.get('runtime')),
    director: record.get('director') || '',
    voteAverage: record.get('voteAverage') == null ? null : Number(record.get('voteAverage')),
    movieLensAvgRating:
      record.get('movieLensAvgRating') == null ? null : Number(record.get('movieLensAvgRating')),
    movieLensRatingCount:
      record.get('movieLensRatingCount') == null
        ? 0
        : toNativeNumber(record.get('movieLensRatingCount')),
  };
}

async function mergeTmdbMovie(movie) {
  await neo4jService.run(
    `
    MERGE (m:Movie {tmdbId: $tmdbId})
    SET
      m.title = $title,
      m.originalTitle = $originalTitle,
      m.overview = $overview,
      m.posterPath = $posterPath,
      m.backdropPath = $backdropPath,
      m.posterUrl = $posterUrl,
      m.backdropUrl = $backdropUrl,
      m.releaseDate = $releaseDate,
      m.runtime = $runtime,
      m.director = $director,
      m.voteAverage = $voteAverage,
      m.movieLensAvgRating = $movieLensAvgRating,
      m.movieLensRatingCount = $movieLensRatingCount
    `,
    {
      tmdbId: movie.tmdbId,
      title: movie.title || '',
      originalTitle: movie.originalTitle || movie.title || '',
      overview: movie.overview || '',
      posterPath: movie.posterPath || null,
      backdropPath: movie.backdropPath || null,
      posterUrl: movie.posterUrl || '',
      backdropUrl: movie.backdropUrl || '',
      releaseDate: movie.releaseDate || '',
      runtime: movie.runtime == null ? null : toNativeNumber(movie.runtime),
      director: movie.director || '',
      voteAverage: movie.voteAverage == null ? null : Number(movie.voteAverage),
      movieLensAvgRating:
        movie.movieLensAvgRating == null ? null : Number(movie.movieLensAvgRating),
      movieLensRatingCount:
        movie.movieLensRatingCount == null ? 0 : toNativeNumber(movie.movieLensRatingCount),
    }
  );
}

async function findMoviesByTmdbIds(tmdbIds) {
  const ids = Array.isArray(tmdbIds)
    ? tmdbIds.filter((tmdbId) => Number.isInteger(tmdbId))
    : [];

  if (ids.length === 0) {
    return [];
  }

  const result = await neo4jService.run(
    `
    MATCH (m:Movie)
    WHERE m.tmdbId IN $tmdbIds
    RETURN
      m.tmdbId AS tmdbId,
      m.title AS title,
      m.originalTitle AS originalTitle,
      m.overview AS overview,
      m.posterPath AS posterPath,
      m.backdropPath AS backdropPath,
      m.posterUrl AS posterUrl,
      m.backdropUrl AS backdropUrl,
      m.releaseDate AS releaseDate,
      m.runtime AS runtime,
      m.director AS director,
      m.voteAverage AS voteAverage,
      m.movieLensAvgRating AS movieLensAvgRating,
      m.movieLensRatingCount AS movieLensRatingCount
    ORDER BY m.tmdbId ASC
    `,
    { tmdbIds: ids }
  );

  return result.records.map((record) => normalizeMovieRecord(record)).filter(Boolean);
}

function toFiniteNumber(value, fallback = 0) {
  const numeric = value == null ? fallback : Number(value);
  return Number.isFinite(numeric) ? numeric : fallback;
}

function toPositiveInteger(value, fallback = 5, max = 100) {
  const numeric = Number.parseInt(String(value), 10);
  if (!Number.isInteger(numeric) || numeric <= 0) {
    return fallback;
  }
  return Math.min(numeric, max);
}

function normalizeRecommendationRecord(record, overrides = {}) {
  if (!record) {
    return null;
  }

  // Safe getter: avoid throwing if the record lacks a key (older/alternate queries).
  function safeGet(key) {
    try {
      if (Array.isArray(record.keys) && record.keys.indexOf(key) === -1) return undefined;
      return record.get(key);
    } catch (e) {
      return undefined;
    }
  }

  const tmdbId = safeGet('tmdbId');
  const title = safeGet('title') || '';
  const similarUsers = toNativeNumber(safeGet('similarUsers'));
  const avgSimilarRatingRaw = safeGet('avgSimilarRating');
  const collaborativeScoreRaw = safeGet('collaborativeScore');
  const genreScoreRaw = safeGet('genreScore');
  const popularityScoreRaw = safeGet('popularityScore');
  const negativePenaltyRaw = safeGet('negativePenalty');
  const explorationBonusRaw = safeGet('explorationBonus');
  const finalScoreRaw = safeGet('finalScore');
  const globalAvgRaw = safeGet('globalAvg');
  const ratingCountRaw = safeGet('ratingCount');
  const sourceRaw = safeGet('source');
  const reasonRaw = safeGet('reason');

  return {
    tmdbId: toNativeNumber(tmdbId),
    title,
    similarUsers: similarUsers == null ? 0 : similarUsers,
    avgSimilarRating: avgSimilarRatingRaw == null ? null : toFiniteNumber(avgSimilarRatingRaw, null),
    collaborativeScore: toFiniteNumber(collaborativeScoreRaw),
    genreScore: toFiniteNumber(genreScoreRaw),
    popularityScore: toFiniteNumber(popularityScoreRaw),
    negativePenalty: toFiniteNumber(negativePenaltyRaw),
    explorationBonus: toFiniteNumber(explorationBonusRaw),
    finalScore: toFiniteNumber(finalScoreRaw),
    globalAvg: globalAvgRaw == null ? null : toFiniteNumber(globalAvgRaw, null),
    ratingCount: ratingCountRaw == null ? 0 : toNativeNumber(ratingCountRaw),
    source: sourceRaw || overrides.source || 'personalized',
    reason: reasonRaw || overrides.reason || '',
  };
}

async function findMovieByTmdbId(tmdbId) {
  const result = await neo4jService.run(
    `
    MATCH (m:Movie {tmdbId: $tmdbId})
    RETURN
      m.tmdbId AS tmdbId,
      m.title AS title,
      m.originalTitle AS originalTitle,
      m.overview AS overview,
      m.posterPath AS posterPath,
      m.backdropPath AS backdropPath,
      m.posterUrl AS posterUrl,
      m.backdropUrl AS backdropUrl,
      m.releaseDate AS releaseDate,
      m.runtime AS runtime,
      m.director AS director,
      m.voteAverage AS voteAverage,
      m.movieLensAvgRating AS movieLensAvgRating,
      m.movieLensRatingCount AS movieLensRatingCount
    LIMIT 1
    `,
    { tmdbId }
  );

  return normalizeMovieRecord(result.records[0]);
}

async function setMovieRuntime(tmdbId, runtime) {
  const safeRuntime = runtime == null ? null : toNativeNumber(runtime);
  if (tmdbId == null || safeRuntime == null || !Number.isFinite(safeRuntime)) {
    return false;
  }

  await neo4jService.run(
    `
    MATCH (m:Movie {tmdbId: $tmdbId})
    SET m.runtime = $runtime
    `,
    {
      tmdbId,
      runtime: safeRuntime,
    }
  );

  return true;
}
async function likeMovie(uid, movie) {
  await mergeTmdbMovie(movie);
  const result = await neo4jService.run(
    `
    MATCH (u:AppUser {uid: $uid})
    MATCH (m:Movie {tmdbId: $tmdbId})
    MERGE (u)-[r:LIKED]->(m)
    ON CREATE SET r.createdAt = datetime()
    RETURN m.tmdbId AS tmdbId
    `,
    { uid, tmdbId: movie.tmdbId }
  );

  return result.records.length > 0;
}

async function dislikeMovie(uid, movie) {
  await neo4jService.run(
    `
    MATCH (u:AppUser {uid: $uid})-[old:LIKED]->(m:Movie {tmdbId: $tmdbId})
    DELETE old
    `,
    { uid, tmdbId: movie.tmdbId }
  );

  await mergeTmdbMovie(movie);

  const result = await neo4jService.run(
    `
    MATCH (u:AppUser {uid: $uid})
    MATCH (m:Movie {tmdbId: $tmdbId})
    MERGE (u)-[r:DISLIKED]->(m)
    ON CREATE SET r.createdAt = datetime()
    RETURN m.tmdbId AS tmdbId
    `,
    { uid, tmdbId: movie.tmdbId }
  );

  return result.records.length > 0;
}

async function watchlistMovie(uid, movie) {
  await mergeTmdbMovie(movie);
  const result = await neo4jService.run(
    `
    MATCH (u:AppUser {uid: $uid})
    MATCH (m:Movie {tmdbId: $tmdbId})
    MERGE (u)-[r:WATCHLISTED]->(m)
    ON CREATE SET r.createdAt = datetime()
    RETURN m.tmdbId AS tmdbId
    `,
    { uid, tmdbId: movie.tmdbId }
  );

  return result.records.length > 0;
}

async function markMovieAsSeen(uid, movie) {
  await mergeTmdbMovie(movie);
  const result = await neo4jService.run(
    `
    MATCH (u:AppUser {uid: $uid})
    MATCH (m:Movie {tmdbId: $tmdbId})
    MERGE (u)-[r:ALREADY_SEEN]->(m)
    ON CREATE SET r.createdAt = datetime()
    RETURN m.tmdbId AS tmdbId
    `,
    { uid, tmdbId: movie.tmdbId }
  );

  return result.records.length > 0;
}

async function saveSelectedFavorites(uid, movies) {
  const selectedMovies = Array.isArray(movies)
    ? movies.filter((movie) => movie && Number.isInteger(movie.tmdbId))
    : [];

  for (const movie of selectedMovies) {
    await mergeTmdbMovie(movie);
  }

  const result = await neo4jService.run(
    `
    MATCH (u:AppUser {uid: $uid})
    UNWIND $tmdbIds AS tmdbId
    MATCH (m:Movie {tmdbId: tmdbId})
    MERGE (u)-[r:SELECTED_FAVORITE]->(m)
    ON CREATE SET r.createdAt = datetime()
    SET r.weight = $weight
    WITH count(DISTINCT m) AS selectedCount
    RETURN selectedCount
    `,
    {
      uid,
      tmdbIds: selectedMovies.map((movie) => movie.tmdbId),
      weight: 4.0,
    }
  );

  return result.records.length > 0;
}

async function savePreferredGenres(uid, genres) {
  const normalizedGenres = Array.isArray(genres)
    ? genres.map((genre) => String(genre).trim()).filter(Boolean)
    : [];

  const result = await neo4jService.run(
    `
    MATCH (u:AppUser {uid: $uid})
    UNWIND $genres AS genreName
    MERGE (g:Genre {name: genreName})
    MERGE (u)-[r:PREFERS_GENRE]->(g)
    ON CREATE SET r.createdAt = datetime()
    WITH count(DISTINCT g) AS preferredGenreCount
    RETURN preferredGenreCount
    `,
    { uid, genres: normalizedGenres }
  );

  return result.records.length > 0;
}

async function removeFromWatchlist(uid, tmdbId) {
  await neo4jService.run(
    `
    MATCH (:AppUser {uid: $uid})-[r:WATCHLISTED]->(:Movie {tmdbId: $tmdbId})
    DELETE r
    `,
    { uid, tmdbId }
  );
}

async function removeLike(uid, tmdbId) {
  await neo4jService.run(
    `
    MATCH (:AppUser {uid: $uid})-[r:LIKED]->(:Movie {tmdbId: $tmdbId})
    DELETE r
    `,
    { uid, tmdbId }
  );
}

async function removeDislike(uid, tmdbId) {
  await neo4jService.run(
    `
    MATCH (:AppUser {uid: $uid})-[r:DISLIKED]->(:Movie {tmdbId: $tmdbId})
    DELETE r
    `,
    { uid, tmdbId }
  );
}

async function removeSeen(uid, tmdbId) {
  await neo4jService.run(
    `
    MATCH (:AppUser {uid: $uid})-[r:ALREADY_SEEN]->(:Movie {tmdbId: $tmdbId})
    DELETE r
    `,
    { uid, tmdbId }
  );
}

async function getUserLibrary(uid) {
  const result = await neo4jService.run(
    `
    MATCH (u:AppUser {uid: $uid})
    CALL {
      WITH u
      MATCH (u)-[r:LIKED]->(m:Movie)
      RETURN collect({
        tmdbId: m.tmdbId,
        title: m.title,
        originalTitle: m.originalTitle,
        overview: m.overview,
        posterPath: m.posterPath,
        backdropPath: m.backdropPath,
       runtime: record.get('runtime') == null ? null : toNativeNumber(record.get('runtime')),
        posterUrl: m.posterUrl,
        backdropUrl: m.backdropUrl,
        releaseDate: m.releaseDate,
        voteAverage: m.voteAverage,
        movieLensAvgRating: m.movieLensAvgRating,
        movieLensRatingCount: m.movieLensRatingCount,
        createdAt: toString(r.createdAt)
      }) AS liked
    }
    CALL {
      WITH u
      MATCH (u)-[r:DISLIKED]->(m:Movie)
      RETURN collect({
        tmdbId: m.tmdbId,
        title: m.title,
        originalTitle: m.originalTitle,
        overview: m.overview,
        posterPath: m.posterPath,
        backdropPath: m.backdropPath,
        posterUrl: m.posterUrl,
        backdropUrl: m.backdropUrl,
        releaseDate: m.releaseDate,
        voteAverage: m.voteAverage,
        movieLensAvgRating: m.movieLensAvgRating,
        movieLensRatingCount: m.movieLensRatingCount,
        createdAt: toString(r.createdAt)
      }) AS disliked
    }
    CALL {
      WITH u
      MATCH (u)-[r:WATCHLISTED]->(m:Movie)
      RETURN collect({
        tmdbId: m.tmdbId,
        title: m.title,
        originalTitle: m.originalTitle,
        overview: m.overview,
        posterPath: m.posterPath,
        backdropPath: m.backdropPath,
        posterUrl: m.posterUrl,
        backdropUrl: m.backdropUrl,
        releaseDate: m.releaseDate,
        voteAverage: m.voteAverage,
        movieLensAvgRating: m.movieLensAvgRating,
        movieLensRatingCount: m.movieLensRatingCount,
        createdAt: toString(r.createdAt)
      }) AS watchlist
    }
    RETURN liked, disliked, watchlist
    `,
    { uid }
  );

  if (result.records.length === 0) {
    return {
      liked: [],
      disliked: [],
      watchlist: [],
    };
  }

  const record = result.records[0];

  return {
    liked: record.get('liked').map((entry) => ({
      ...entry,
      tmdbId: toNativeNumber(entry.tmdbId),
      movieLensRatingCount: entry.movieLensRatingCount == null ? 0 : toNativeNumber(entry.movieLensRatingCount),
    })),
    disliked: record.get('disliked').map((entry) => ({
      ...entry,
      tmdbId: toNativeNumber(entry.tmdbId),
      movieLensRatingCount: entry.movieLensRatingCount == null ? 0 : toNativeNumber(entry.movieLensRatingCount),
    })),
    watchlist: record.get('watchlist').map((entry) => ({
      ...entry,
      tmdbId: toNativeNumber(entry.tmdbId),
      movieLensRatingCount: entry.movieLensRatingCount == null ? 0 : toNativeNumber(entry.movieLensRatingCount),
    })),
  };
}

async function getPersonalizedRecommendationCandidates(uid) {
  const personalized = await neo4jService.run(
    `
    MATCH (me:AppUser {uid: $uid})

    // PASSO A: FIX DEL BUG DELLA SUBQUERY. Usiamo la list comprehension per non far morire la query.
    CALL {
      WITH me
      OPTIONAL MATCH (me)-[:DISLIKED]->(disliked:Movie)
      OPTIONAL MATCH (disliked)<-[:MATCHES_TMDB]-(dislikedMl:MovieLensMovie)-[:IN_GENRE]->(mlGenre:Genre)
      OPTIONAL MATCH (disliked)-[:IN_GENRE]->(movieGenre:Genre)
      WITH disliked, collect(DISTINCT mlGenre.name) + collect(DISTINCT movieGenre.name) AS genreNames
      UNWIND CASE WHEN size(genreNames) = 0 THEN [null] ELSE genreNames END AS genreName
      WITH genreName, count(DISTINCT disliked) AS dislikedCount
      // Non usiamo WHERE qui per non perdere le righe. Filtriamo la lista finale:
      WITH [g IN collect({name: genreName, count: dislikedCount}) 
            WHERE g.name IS NOT NULL AND g.count >= $dislikedGenreThreshold | g] AS dislikedGenres
      RETURN dislikedGenres
    }

    MATCH (me)-[signal:LIKED|SELECTED_FAVORITE|WATCHLISTED]->(seed:Movie)

    MATCH (seed)<-[:MATCHES_TMDB]-(seedMl:MovieLensMovie)<-[r1:RATED]-(similar:MovieLensUser)
    WHERE r1.rating >= 4.0
    WITH
      me,
      dislikedGenres,
      similar,
      count(DISTINCT seed) AS overlapCount,
      sum(
        CASE type(signal)
          WHEN 'SELECTED_FAVORITE' THEN coalesce(signal.weight, $selectedFavoriteWeight)
          WHEN 'LIKED' THEN $likedWeight
          WHEN 'WATCHLISTED' THEN $watchlistedWeight
          ELSE 1.0
        END
        * (toFloat(r1.rating) - 3.0)
        * (1.0 / sqrt(log(toFloat(coalesce(seed.movieLensRatingCount, seedMl.movieLensRatingCount, 0)) + 10.0)))
      ) AS similarityScore
    WHERE similarityScore > 0

    MATCH (similar)-[r2:RATED]->(recMl:MovieLensMovie)-[:MATCHES_TMDB]->(rec:Movie)
    WHERE r2.rating >= 4.0
      AND rec.tmdbId IS NOT NULL 

      AND NOT (me)-[:LIKED|DISLIKED|WATCHLISTED|ALREADY_SEEN|SELECTED_FAVORITE]->(rec)

    OPTIONAL MATCH (recMl)-[:IN_GENRE]->(recMlGenre:Genre)
    OPTIONAL MATCH (rec)-[:IN_GENRE]->(recMovieGenre:Genre)
    WITH
      rec,
      similar,
      r2,
      similarityScore,
      overlapCount,
      dislikedGenres,
      collect(DISTINCT recMlGenre.name) + collect(DISTINCT recMovieGenre.name) AS candidateGenreNames
    WITH
      rec,
      similar,
      r2,
      similarityScore,
      overlapCount,
      [entry IN coalesce(dislikedGenres, []) WHERE entry.name IN candidateGenreNames | entry] AS matchingDislikedGenres
    WITH
      rec,
      similar,
      r2,
      similarityScore,
      overlapCount,
      reduce(penalty = 0.0, entry IN matchingDislikedGenres |
        penalty + ($dislikedGenrePenalty * toFloat(entry.count))
      ) AS negativePenalty

    WITH
      rec,
      count(DISTINCT similar) AS similarUsers,
      avg(r2.rating) AS avgSimilarRating,
      sum(similarityScore * (toFloat(r2.rating) - 3.0)) AS collaborativeScore,
      avg(overlapCount) AS avgOverlapCount,
      max(negativePenalty) AS negativePenalty
    WITH
      rec,
      similarUsers,
      avgSimilarRating,
      collaborativeScore,
      avgOverlapCount,
      negativePenalty,
      collaborativeScore - negativePenalty AS finalScore

    RETURN
      rec.tmdbId AS tmdbId,
      rec.title AS title,
      similarUsers,
      avgSimilarRating,
      collaborativeScore,
      0.0 AS genreScore,
      log(toFloat(coalesce(rec.movieLensRatingCount, 0)) + 1.0) AS popularityScore,
      avgOverlapCount,
      negativePenalty,
      0.0 AS explorationBonus,
      finalScore,
      rec.movieLensAvgRating AS globalAvg,
      rec.movieLensRatingCount AS ratingCount,
      'personalized' AS source
    
    ORDER BY
      finalScore DESC,
      collaborativeScore DESC,
      similarUsers DESC,
      avgSimilarRating DESC,
      ratingCount DESC
    LIMIT 80
    `,
    {
      uid,
      selectedFavoriteWeight: 4.0,
      likedWeight: 3.0,
      watchlistedWeight: 1.25,
      dislikedGenreThreshold: 2,
      dislikedGenrePenalty: 1.5,
    }
  );

  return personalized.records
    .map((record) =>
      normalizeRecommendationRecord(record, {
        source: 'personalized',
        reason: 'High collaborative overlap with your strongest positive signals.',
      })
    )
    .filter(Boolean);
}

async function getRecommendationCandidates(uid) {
  const personalized = await getPersonalizedRecommendationCandidates(uid);
  if (personalized.length > 0) {
    return {
      candidates: personalized,
      fallbackUsed: false,
      fallbackReason: null,
      fallbackStrategy: null,
    };
  }

  return {
    candidates: [],
    fallbackUsed: false,
    fallbackReason: null,
    fallbackStrategy: null,
  };
}

async function getRecommendations(uid) {
  const { candidates } = await getRecommendationCandidates(uid);
  return candidates;
}

async function getExploratoryCandidates(uid, { excludedTmdbIds = [], limit = 30 } = {}) {
  const safeLimit = toPositiveInteger(limit, 30, 80);
  const result = await neo4jService.run(
    `
    MATCH (me:AppUser {uid: $uid})

    CALL {
      WITH me
      OPTIONAL MATCH (me)-[:PREFERS_GENRE]->(preferred:Genre)
      RETURN collect(DISTINCT preferred.name) AS preferredGenres
    }

    CALL {
      WITH me
      OPTIONAL MATCH (me)-[:LIKED|SELECTED_FAVORITE|WATCHLISTED]->(positiveMovie:Movie)
      OPTIONAL MATCH (positiveMovie)<-[:MATCHES_TMDB]-(positiveMl:MovieLensMovie)-[:IN_GENRE]->(positiveMlGenre:Genre)
      OPTIONAL MATCH (positiveMovie)-[:IN_GENRE]->(positiveMovieGenre:Genre)
      WITH collect(DISTINCT positiveMlGenre.name) + collect(DISTINCT positiveMovieGenre.name) AS rawPositiveGenres
      RETURN [genre IN rawPositiveGenres WHERE genre IS NOT NULL] AS positiveGenres
    }

    CALL {
      WITH me
      OPTIONAL MATCH (me)-[:DISLIKED]->(negativeMovie:Movie)
      OPTIONAL MATCH (negativeMovie)<-[:MATCHES_TMDB]-(negativeMl:MovieLensMovie)-[:IN_GENRE]->(negativeMlGenre:Genre)
      OPTIONAL MATCH (negativeMovie)-[:IN_GENRE]->(negativeMovieGenre:Genre)
      WITH collect(DISTINCT negativeMlGenre.name) + collect(DISTINCT negativeMovieGenre.name) AS rawNegativeGenres
      RETURN [genre IN rawNegativeGenres WHERE genre IS NOT NULL] AS negativeGenres
    }

    MATCH (m:Movie)
    WHERE m.tmdbId IS NOT NULL
      AND coalesce(m.movieLensRatingCount, 0) >= $minRatingCount
      AND NOT (me)-[:LIKED|DISLIKED|WATCHLISTED|ALREADY_SEEN|SELECTED_FAVORITE]->(m)
      AND NOT m.tmdbId IN $excludedTmdbIds

    OPTIONAL MATCH (m)<-[:MATCHES_TMDB]-(ml:MovieLensMovie)-[:IN_GENRE]->(mlGenre:Genre)
    OPTIONAL MATCH (m)-[:IN_GENRE]->(movieGenre:Genre)
    WITH
      m,
      preferredGenres,
      positiveGenres,
      negativeGenres,
      [genre IN collect(DISTINCT mlGenre.name) + collect(DISTINCT movieGenre.name) WHERE genre IS NOT NULL] AS candidateGenres,
      toFloat(coalesce(m.movieLensRatingCount, 0)) AS ratingCount,
      toFloat(coalesce(m.movieLensAvgRating, $globalMeanRating)) AS avgRating
    WITH
      m,
      ratingCount,
      avgRating,
      size([genre IN candidateGenres WHERE genre IN preferredGenres OR genre IN positiveGenres]) AS familiarGenres,
      size([genre IN candidateGenres WHERE NOT genre IN preferredGenres AND NOT genre IN positiveGenres]) AS exploratoryGenres,
      size([genre IN candidateGenres WHERE genre IN negativeGenres]) AS matchedNegativeGenres

    RETURN
      m.tmdbId AS tmdbId,
      m.title AS title,
      0 AS similarUsers,
      null AS avgSimilarRating,
      0.0 AS collaborativeScore,
      (familiarGenres * 15.0) AS genreScore,
      (avgRating * 10.0) + log(ratingCount + 1.0) AS popularityScore,
      (matchedNegativeGenres * 25.0) AS negativePenalty,
      (exploratoryGenres * 40.0) AS explorationBonus,
      ((familiarGenres * 15.0) + (avgRating * 10.0) + log(ratingCount + 1.0) + (exploratoryGenres * 40.0) - (matchedNegativeGenres * 25.0)) AS finalScore,
      m.movieLensAvgRating AS globalAvg,
      m.movieLensRatingCount AS ratingCount,
      'exploratory' AS source,
      CASE
        WHEN exploratoryGenres > 0 THEN 'Explores genres outside your strongest current bubble.'
        ELSE 'Popular unseen title kept to test uncertain taste edges.'
      END AS reason
    ORDER BY
      explorationBonus DESC,
      finalScore DESC,
      ratingCount DESC
    LIMIT ${safeLimit}
    `,
    {
      uid,
      excludedTmdbIds,
      globalMeanRating: 3.5,
      minRatingCount: 25,
    }
  );

  return result.records.map((record) => normalizeRecommendationRecord(record)).filter(Boolean);
}

async function getRecommendationUserProfile(uid) {
  const result = await neo4jService.run(
    `
    MATCH (me:AppUser {uid: $uid})
    CALL {
      WITH me
      OPTIONAL MATCH (me)-[:PREFERS_GENRE]->(genre:Genre)
      RETURN collect(DISTINCT genre.name) AS onboardingGenres
    }
    CALL {
      WITH me
      OPTIONAL MATCH (me)-[:SELECTED_FAVORITE]->(movie:Movie)
      RETURN count(DISTINCT movie) AS favoriteMoviesCount
    }
    CALL {
      WITH me
      OPTIONAL MATCH (me)-[:LIKED]->(movie:Movie)
      RETURN count(DISTINCT movie) AS likedMoviesCount
    }
    CALL {
      WITH me
      OPTIONAL MATCH (me)-[:DISLIKED]->(movie:Movie)
      RETURN count(DISTINCT movie) AS dislikedMoviesCount
    }
    CALL {
      WITH me
      OPTIONAL MATCH (me)-[:ALREADY_SEEN]->(movie:Movie)
      RETURN count(DISTINCT movie) AS alreadySeenCount
    }
    CALL {
      WITH me
      OPTIONAL MATCH (me)-[:WATCHLISTED]->(movie:Movie)
      RETURN count(DISTINCT movie) AS watchlistCount
    }
    RETURN
      me.uid AS uid,
      onboardingGenres,
      favoriteMoviesCount,
      likedMoviesCount,
      dislikedMoviesCount,
      alreadySeenCount,
      watchlistCount
    LIMIT 1
    `,
    { uid }
  );

  if (result.records.length === 0) {
    return null;
  }

  const record = result.records[0];
  const favoriteMoviesCount = toNativeNumber(record.get('favoriteMoviesCount'));
  const likedMoviesCount = toNativeNumber(record.get('likedMoviesCount'));
  const dislikedMoviesCount = toNativeNumber(record.get('dislikedMoviesCount'));
  const alreadySeenCount = toNativeNumber(record.get('alreadySeenCount'));
  const watchlistCount = toNativeNumber(record.get('watchlistCount'));

  return {
    uid: record.get('uid') || uid,
    onboardingGenres: record.get('onboardingGenres') || [],
    favoriteMoviesCount,
    likedMoviesCount,
    dislikedMoviesCount,
    alreadySeenCount,
    watchlistCount,
    totalFeedbackActions:
      favoriteMoviesCount + likedMoviesCount + dislikedMoviesCount + alreadySeenCount + watchlistCount,
  };
}

async function getTopPositiveGenreSignals(uid, limit = 5) {
  const safeLimit = toPositiveInteger(limit, 5, 20);
  const result = await neo4jService.run(
    `
    MATCH (me:AppUser {uid: $uid})-[signal:LIKED|SELECTED_FAVORITE|WATCHLISTED]->(movie:Movie)
    OPTIONAL MATCH (movie)<-[:MATCHES_TMDB]-(ml:MovieLensMovie)-[:IN_GENRE]->(mlGenre:Genre)
    OPTIONAL MATCH (movie)-[:IN_GENRE]->(movieGenre:Genre)
    WITH
      CASE type(signal)
        WHEN 'SELECTED_FAVORITE' THEN coalesce(signal.weight, 4.0)
        WHEN 'LIKED' THEN 3.0
        WHEN 'WATCHLISTED' THEN 1.25
        ELSE 1.0
      END AS signalWeight,
      [genre IN collect(DISTINCT mlGenre.name) + collect(DISTINCT movieGenre.name) WHERE genre IS NOT NULL] AS genreNames
    UNWIND genreNames AS genreName
    RETURN genreName AS name, sum(signalWeight) AS score
    ORDER BY score DESC, name ASC
    LIMIT ${safeLimit}
    `,
    { uid }
  );

  return result.records.map((record) => ({
    name: record.get('name') || '',
    score: toFiniteNumber(record.get('score')),
  }));
}

async function getTopNegativeGenreSignals(uid, limit = 5) {
  const safeLimit = toPositiveInteger(limit, 5, 20);
  const result = await neo4jService.run(
    `
    MATCH (me:AppUser {uid: $uid})-[:DISLIKED]->(movie:Movie)
    OPTIONAL MATCH (movie)<-[:MATCHES_TMDB]-(ml:MovieLensMovie)-[:IN_GENRE]->(mlGenre:Genre)
    OPTIONAL MATCH (movie)-[:IN_GENRE]->(movieGenre:Genre)
    WITH [genre IN collect(DISTINCT mlGenre.name) + collect(DISTINCT movieGenre.name) WHERE genre IS NOT NULL] AS genreNames
    UNWIND genreNames AS genreName
    RETURN genreName AS name, count(*) AS score
    ORDER BY score DESC, name ASC
    LIMIT ${safeLimit}
    `,
    { uid }
  );

  return result.records.map((record) => ({
    name: record.get('name') || '',
    score: toFiniteNumber(record.get('score')),
  }));
}

async function getTopPositiveMovies(uid, limit = 5) {
  const safeLimit = toPositiveInteger(limit, 5, 20);
  const result = await neo4jService.run(
    `
    MATCH (me:AppUser {uid: $uid})-[signal:LIKED|SELECTED_FAVORITE|WATCHLISTED]->(movie:Movie)
    RETURN
      movie.tmdbId AS tmdbId,
      movie.title AS title,
      type(signal) AS signalType,
      CASE type(signal)
        WHEN 'SELECTED_FAVORITE' THEN coalesce(signal.weight, 4.0)
        WHEN 'LIKED' THEN 3.0
        WHEN 'WATCHLISTED' THEN 1.25
        ELSE 1.0
      END AS score
    ORDER BY score DESC, movie.title ASC
    LIMIT ${safeLimit}
    `,
    { uid }
  );

  return result.records.map((record) => ({
    tmdbId: toNativeNumber(record.get('tmdbId')),
    title: record.get('title') || '',
    signalType: record.get('signalType') || '',
    score: toFiniteNumber(record.get('score')),
  }));
}

async function getTopNegativeMovies(uid, limit = 5) {
  const safeLimit = toPositiveInteger(limit, 5, 20);
  const result = await neo4jService.run(
    `
    MATCH (me:AppUser {uid: $uid})-[signal:DISLIKED]->(movie:Movie)
    RETURN
      movie.tmdbId AS tmdbId,
      movie.title AS title,
      type(signal) AS signalType,
      1.0 AS score
    ORDER BY movie.title ASC
    LIMIT ${safeLimit}
    `,
    { uid }
  );

  return result.records.map((record) => ({
    tmdbId: toNativeNumber(record.get('tmdbId')),
    title: record.get('title') || '',
    signalType: record.get('signalType') || '',
    score: toFiniteNumber(record.get('score')),
  }));
}

async function getCandidatePoolStats(uid) {
  const result = await neo4jService.run(
    `
    MATCH (me:AppUser {uid: $uid})
    MATCH (m:Movie)
    WHERE m.tmdbId IS NOT NULL
    WITH
      me,
      m,
      EXISTS { MATCH (me)-[:ALREADY_SEEN]->(m) } AS alreadySeen,
      EXISTS { MATCH (me)-[:DISLIKED]->(m) } AS disliked,
      EXISTS { MATCH (me)-[:LIKED|WATCHLISTED|SELECTED_FAVORITE]->(m) } AS alreadySwiped,
      (
        coalesce(m.posterUrl, '') = '' AND
        coalesce(m.posterPath, '') = '' AND
        coalesce(m.backdropUrl, '') = '' AND
        coalesce(m.backdropPath, '') = ''
      ) AS missingMetadata
    RETURN
      count(m) AS totalCandidatesConsidered,
      sum(CASE WHEN alreadySeen THEN 1 ELSE 0 END) AS filteredAlreadySeen,
      sum(CASE WHEN NOT alreadySeen AND disliked THEN 1 ELSE 0 END) AS filteredDisliked,
      sum(CASE WHEN NOT alreadySeen AND NOT disliked AND alreadySwiped THEN 1 ELSE 0 END) AS filteredAlreadySwiped,
      sum(CASE WHEN NOT alreadySeen AND NOT disliked AND NOT alreadySwiped AND missingMetadata THEN 1 ELSE 0 END) AS filteredMissingMetadata,
      sum(CASE WHEN NOT alreadySeen AND NOT disliked AND NOT alreadySwiped AND NOT missingMetadata THEN 1 ELSE 0 END) AS remainingAfterFiltering
    `,
    { uid }
  );

  if (result.records.length === 0) {
    return {
      totalCandidatesConsidered: 0,
      filteredAlreadySeen: 0,
      filteredDisliked: 0,
      filteredAlreadySwiped: 0,
      filteredMissingMetadata: 0,
      remainingAfterFiltering: 0,
    };
  }

  const record = result.records[0];
  return {
    totalCandidatesConsidered: toNativeNumber(record.get('totalCandidatesConsidered')),
    filteredAlreadySeen: toNativeNumber(record.get('filteredAlreadySeen')),
    filteredDisliked: toNativeNumber(record.get('filteredDisliked')),
    filteredAlreadySwiped: toNativeNumber(record.get('filteredAlreadySwiped')),
    filteredMissingMetadata: toNativeNumber(record.get('filteredMissingMetadata')),
    remainingAfterFiltering: toNativeNumber(record.get('remainingAfterFiltering')),
  };
}

module.exports = {
  findMovieByTmdbId,
  findMoviesByTmdbIds,
  mergeTmdbMovie,
  setMovieRuntime,
  likeMovie,
  dislikeMovie,
  watchlistMovie,
  markMovieAsSeen,
  saveSelectedFavorites,
  savePreferredGenres,
  removeFromWatchlist,
  removeLike,
  removeDislike,
  removeSeen,
  getUserLibrary,
  getPersonalizedRecommendationCandidates,
  getRecommendationCandidates,
  getRecommendations,
  getExploratoryCandidates,
  getRecommendationUserProfile,
  getTopPositiveGenreSignals,
  getTopNegativeGenreSignals,
  getTopPositiveMovies,
  getTopNegativeMovies,
  getCandidatePoolStats,
};
