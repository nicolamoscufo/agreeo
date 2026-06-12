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

  function safeGet(key) {
    try {
      if (Array.isArray(record.keys) && record.keys.indexOf(key) === -1) return undefined;
      return record.get(key);
    } catch (e) {
      return undefined;
    }
  }

  const movie = {
    tmdbId: toNativeNumber(safeGet('tmdbId')),
    title: safeGet('title') || '',
    originalTitle: safeGet('originalTitle') || '',
    overview: safeGet('overview') || '',
    posterPath: safeGet('posterPath') || null,
    backdropPath: safeGet('backdropPath') || null,
    posterUrl: (safeGet('posterPath') && (!safeGet('posterUrl') || !(safeGet('posterUrl') || '').startsWith('http')))
      ? `https://image.tmdb.org/t/p/w780${safeGet('posterPath')}`
      : (safeGet('posterUrl') || ''),
    backdropUrl: (safeGet('backdropPath') && (!safeGet('backdropUrl') || !(safeGet('backdropUrl') || '').startsWith('http')))
      ? `https://image.tmdb.org/t/p/w1280${safeGet('backdropPath')}`
      : (safeGet('backdropUrl') || ''),
    releaseDate: safeGet('releaseDate') || '',
    runtime: safeGet('runtime') == null ? null : toNativeNumber(safeGet('runtime')),
    director: safeGet('director') || '',
    voteAverage: safeGet('voteAverage') == null ? null : Number(safeGet('voteAverage')),
    movieLensAvgRating:
      safeGet('movieLensAvgRating') == null ? null : Number(safeGet('movieLensAvgRating')),
    movieLensRatingCount:
      safeGet('movieLensRatingCount') == null
        ? 0
        : toNativeNumber(safeGet('movieLensRatingCount')),
    genres: safeGet('genres') || [],
    tmdbHydrated: safeGet('tmdbHydrated') === true,
  };

  const tagRelevanceScoreVal = safeGet('tagRelevanceScore');
  if (tagRelevanceScoreVal !== undefined) {
    movie.tagRelevanceScore = toNativeNumber(tagRelevanceScoreVal);
  }

  const matchedTagsVal = safeGet('matchedTags');
  if (matchedTagsVal !== undefined) {
    movie.matchedTags = Array.isArray(matchedTagsVal)
      ? matchedTagsVal.map(mt => ({
          tag: mt.tag,
          frequency: toNativeNumber(mt.frequency)
        }))
      : matchedTagsVal;
  }

  return movie;
}

async function mergeTmdbMovie(movie, tx = null) {
  // IMPORTANT: only overwrite a property when the incoming payload actually
  // carries a value. Interaction payloads (like/dislike/watchlist/seen) come
  // from TMDB and do NOT include MovieLens stats, so an unconditional SET would
  // wipe the imported movieLensAvgRating/movieLensRatingCount and degrade
  // recommendations over time. We therefore coalesce against the existing node.
  const run = (q, p) => (tx ? tx.run(q, p) : neo4jService.run(q, p));
  const genres = Array.isArray(movie.genres) ? movie.genres.filter(Boolean) : [];

  await run(
    `
    MERGE (m:Movie {tmdbId: $tmdbId})
    SET
      m.title = coalesce($title, m.title),
      m.originalTitle = coalesce($originalTitle, m.originalTitle),
      m.overview = CASE WHEN $overview <> '' THEN $overview ELSE coalesce(m.overview, '') END,
      m.posterPath = coalesce($posterPath, m.posterPath),
      m.backdropPath = coalesce($backdropPath, m.backdropPath),
      m.posterUrl = CASE WHEN $posterUrl <> '' THEN $posterUrl ELSE coalesce(m.posterUrl, '') END,
      m.backdropUrl = CASE WHEN $backdropUrl <> '' THEN $backdropUrl ELSE coalesce(m.backdropUrl, '') END,
      m.releaseDate = CASE WHEN $releaseDate <> '' THEN $releaseDate ELSE coalesce(m.releaseDate, '') END,
      m.runtime = coalesce($runtime, m.runtime),
      m.director = CASE WHEN $director <> '' THEN $director ELSE coalesce(m.director, '') END,
      m.voteAverage = coalesce($voteAverage, m.voteAverage),
      m.movieLensAvgRating = coalesce($movieLensAvgRating, m.movieLensAvgRating),
      m.movieLensRatingCount = coalesce($movieLensRatingCount, m.movieLensRatingCount),
      m.genres = CASE WHEN size($genres) > 0 THEN $genres ELSE coalesce(m.genres, []) END,
      m.tmdbHydrated = coalesce(m.tmdbHydrated, false) OR $tmdbHydrated
    `,
    {
      tmdbId: movie.tmdbId,
      title: movie.title || null,
      originalTitle: movie.originalTitle || movie.title || null,
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
        movie.movieLensRatingCount == null ? null : toNativeNumber(movie.movieLensRatingCount),
      genres,
      tmdbHydrated: movie.tmdbHydrated === true || genres.length > 0,
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
      m.movieLensRatingCount AS movieLensRatingCount,
      m.genres AS genres,
      m.tmdbHydrated AS tmdbHydrated
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
      m.movieLensRatingCount AS movieLensRatingCount,
      m.genres AS genres,
      m.tmdbHydrated AS tmdbHydrated
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
// Relationship types interpolated into Cypher must come from this whitelist:
// they cannot be parameterized, so this guard is the defense in depth against
// accidental injection if a caller ever forwards user-controlled values.
const INTERACTION_REL_TYPES = new Set([
  'LIKED',
  'DISLIKED',
  'WATCHLISTED',
  'ALREADY_SEEN',
  'SELECTED_FAVORITE',
]);

function assertInteractionRelTypes(...types) {
  for (const type of types) {
    if (!INTERACTION_REL_TYPES.has(type)) {
      throw new Error(`Unsupported interaction relationship type: ${type}`);
    }
  }
}

// Sets a single exclusive preference relationship for a user/movie pair,
// removing any conflicting relationships first. All steps run inside one write
// transaction so the graph never ends up in a half-updated state.
async function setMovieInteraction(uid, movie, { newRel, removeRels }) {
  assertInteractionRelTypes(newRel, ...removeRels);
  return neo4jService.executeWrite(async (tx) => {
    if (removeRels.length > 0) {
      await tx.run(
        `
        MATCH (u:AppUser {uid: $uid})-[old:${removeRels.join('|')}]->(m:Movie {tmdbId: $tmdbId})
        DELETE old
        `,
        { uid, tmdbId: movie.tmdbId }
      );
    }

    await mergeTmdbMovie(movie, tx);

    const result = await tx.run(
      `
      MATCH (u:AppUser {uid: $uid})
      MATCH (m:Movie {tmdbId: $tmdbId})
      MERGE (u)-[r:${newRel}]->(m)
      ON CREATE SET r.createdAt = datetime()
      RETURN m.tmdbId AS tmdbId
      `,
      { uid, tmdbId: movie.tmdbId }
    );

    return result.records.length > 0;
  });
}

async function likeMovie(uid, movie) {
  return setMovieInteraction(uid, movie, { newRel: 'LIKED', removeRels: ['DISLIKED'] });
}

async function dislikeMovie(uid, movie) {
  return setMovieInteraction(uid, movie, { newRel: 'DISLIKED', removeRels: ['LIKED', 'WATCHLISTED'] });
}

async function watchlistMovie(uid, movie) {
  return setMovieInteraction(uid, movie, { newRel: 'WATCHLISTED', removeRels: ['DISLIKED', 'ALREADY_SEEN'] });
}

async function markMovieAsSeen(uid, movie) {
  return setMovieInteraction(uid, movie, { newRel: 'ALREADY_SEEN', removeRels: ['WATCHLISTED'] });
}

async function saveSelectedFavorites(uid, movies) {
  const selectedMovies = Array.isArray(movies)
    ? movies.filter((movie) => movie && Number.isInteger(movie.tmdbId))
    : [];

  await Promise.all(selectedMovies.map((movie) => mergeTmdbMovie(movie)));

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

  // Replace semantics: drop preferences no longer selected so the profile
  // genre editor can remove genres, not only add them.
  const result = await neo4jService.run(
    `
    MATCH (u:AppUser {uid: $uid})
    OPTIONAL MATCH (u)-[stale:PREFERS_GENRE]->(g:Genre)
    WHERE NOT g.name IN $genres
    DELETE stale
    WITH DISTINCT u
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
        runtime: m.runtime,
        posterUrl: m.posterUrl,
        backdropUrl: m.backdropUrl,
        releaseDate: m.releaseDate,
        voteAverage: m.voteAverage,
        movieLensAvgRating: m.movieLensAvgRating,
        movieLensRatingCount: m.movieLensRatingCount,
        genres: coalesce(m.genres, []),
        tmdbHydrated: coalesce(m.tmdbHydrated, false),
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
        runtime: m.runtime,
        posterUrl: m.posterUrl,
        backdropUrl: m.backdropUrl,
        releaseDate: m.releaseDate,
        voteAverage: m.voteAverage,
        movieLensAvgRating: m.movieLensAvgRating,
        movieLensRatingCount: m.movieLensRatingCount,
        genres: coalesce(m.genres, []),
        tmdbHydrated: coalesce(m.tmdbHydrated, false),
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
        runtime: m.runtime,
        posterUrl: m.posterUrl,
        backdropUrl: m.backdropUrl,
        releaseDate: m.releaseDate,
        voteAverage: m.voteAverage,
        movieLensAvgRating: m.movieLensAvgRating,
        movieLensRatingCount: m.movieLensRatingCount,
        genres: coalesce(m.genres, []),
        tmdbHydrated: coalesce(m.tmdbHydrated, false),
        createdAt: toString(r.createdAt)
      }) AS watchlist
    }
    CALL {
      WITH u
      MATCH (u)-[r:ALREADY_SEEN]->(m:Movie)
      RETURN collect({
        tmdbId: m.tmdbId,
        title: m.title,
        originalTitle: m.originalTitle,
        overview: m.overview,
        posterPath: m.posterPath,
        backdropPath: m.backdropPath,
        runtime: m.runtime,
        posterUrl: m.posterUrl,
        backdropUrl: m.backdropUrl,
        releaseDate: m.releaseDate,
        voteAverage: m.voteAverage,
        movieLensAvgRating: m.movieLensAvgRating,
        movieLensRatingCount: m.movieLensRatingCount,
        genres: coalesce(m.genres, []),
        tmdbHydrated: coalesce(m.tmdbHydrated, false),
        createdAt: toString(r.createdAt)
      }) AS alreadySeen
    }
    RETURN liked, disliked, watchlist, alreadySeen
    `,
    { uid }
  );

  if (result.records.length === 0) {
    return {
      liked: [],
      disliked: [],
      watchlist: [],
      alreadySeen: [],
    };
  }

  const record = result.records[0];

  return {
    liked: record.get('liked').map((entry) => ({
      ...entry,
      tmdbId: toNativeNumber(entry.tmdbId),
      movieLensRatingCount: entry.movieLensRatingCount == null ? 0 : toNativeNumber(entry.movieLensRatingCount),
      genres: Array.isArray(entry.genres) ? entry.genres : [],
      tmdbHydrated: entry.tmdbHydrated === true,
    })),
    disliked: record.get('disliked').map((entry) => ({
      ...entry,
      tmdbId: toNativeNumber(entry.tmdbId),
      movieLensRatingCount: entry.movieLensRatingCount == null ? 0 : toNativeNumber(entry.movieLensRatingCount),
      genres: Array.isArray(entry.genres) ? entry.genres : [],
      tmdbHydrated: entry.tmdbHydrated === true,
    })),
    watchlist: record.get('watchlist').map((entry) => ({
      ...entry,
      tmdbId: toNativeNumber(entry.tmdbId),
      movieLensRatingCount: entry.movieLensRatingCount == null ? 0 : toNativeNumber(entry.movieLensRatingCount),
      genres: Array.isArray(entry.genres) ? entry.genres : [],
      tmdbHydrated: entry.tmdbHydrated === true,
    })),
    alreadySeen: record.get('alreadySeen').map((entry) => ({
      ...entry,
      tmdbId: toNativeNumber(entry.tmdbId),
      movieLensRatingCount: entry.movieLensRatingCount == null ? 0 : toNativeNumber(entry.movieLensRatingCount),
      genres: Array.isArray(entry.genres) ? entry.genres : [],
      tmdbHydrated: entry.tmdbHydrated === true,
    })),
  };
}

async function getPersonalizedRecommendationCandidates(uid) {
  const personalized = await neo4jService.run(
    `
    MATCH (me:AppUser {uid: $uid})

    // PASSO A: FIX DEL BUG DELLA SUBQUERY e calcolo del Soft Dislike Ratio.
    CALL {
      WITH me
      OPTIONAL MATCH (me)-[r:LIKED|DISLIKED|SELECTED_FAVORITE|WATCHLISTED]->(m:Movie)
      OPTIONAL MATCH (m)<-[:MATCHES_TMDB]-(mMl:MovieLensMovie)-[:IN_GENRE]->(mlGenre:Genre)
      OPTIONAL MATCH (m)-[:IN_GENRE]->(movieGenre:Genre)
      WITH r, collect(DISTINCT mlGenre.name) + collect(DISTINCT movieGenre.name) AS genreNames
      UNWIND CASE WHEN size(genreNames) = 0 THEN [null] ELSE genreNames END AS genreName
      WITH genreName,
           sum(CASE WHEN type(r) = 'DISLIKED' THEN 1 ELSE 0 END) AS dislikedCount,
           count(r) AS totalInteractions
      // Filtriamo la lista finale mantenendo sia count (dislike) che total (interazioni totali):
      WITH [g IN collect({name: genreName, count: dislikedCount, total: totalInteractions}) 
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
        (
          CASE type(signal)
            WHEN 'SELECTED_FAVORITE' THEN coalesce(signal.weight, $selectedFavoriteWeight)
            WHEN 'LIKED' THEN $likedWeight
            WHEN 'WATCHLISTED' THEN $watchlistedWeight
            ELSE 1.0
          END
          * exp(-0.005 * duration.inDays(coalesce(signal.createdAt, signal.updatedAt, datetime()), datetime()).days)
        )
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
        penalty + ($dislikedGenrePenalty * toFloat(entry.count) * (toFloat(entry.count) / toFloat(entry.total)))
      ) AS negativePenalty

    WITH
      rec,
      count(DISTINCT similar) AS similarUsers,
      avg(r2.rating) AS avgSimilarRating,
      ((sum(similarityScore * (toFloat(r2.rating) - 3.0)) / coalesce(sum(similarityScore), 1.0)) * log(toFloat(count(DISTINCT similar)) + 1.0) * 10.0) AS collaborativeScore,
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

async function getSemanticTagRecommendationCandidates(uid, limit = 50) {
  const safeLimit = toPositiveInteger(limit, 50, 200);
  const tagsResult = await neo4jService.run(
    `
    MATCH (u:AppUser {uid: $uid})-[r:LIKED|SELECTED_FAVORITE|WATCHLISTED|DISLIKED]->(m:Movie)
    MATCH (m)<-[:MATCHES_TMDB]-(ml:MovieLensMovie)-[h:HAS_TAG]->(t:Tag)
    WHERE t.embedding IS NOT NULL
    RETURN t.embedding AS embedding, type(r) AS relType, coalesce(h.frequency, 1) AS frequency
    `,
    { uid }
  );

  if (tagsResult.records.length === 0) {
    return [];
  }

  const userTasteVector = new Array(384).fill(0);
  let totalWeight = 0;

  for (const record of tagsResult.records) {
    const embedding = record.get('embedding');
    if (!Array.isArray(embedding) || embedding.length !== 384) continue;

    const relType = record.get('relType');
    const frequency = toNativeNumber(record.get('frequency')) || 1;

    let relWeight = 1.0;
    if (relType === 'SELECTED_FAVORITE') {
      relWeight = 4.0;
    } else if (relType === 'LIKED') {
      relWeight = 3.0;
    } else if (relType === 'WATCHLISTED') {
      relWeight = 1.5;
    } else if (relType === 'DISLIKED') {
      relWeight = -3.0;
    }

    const weight = relWeight * frequency;

    for (let i = 0; i < 384; i++) {
      userTasteVector[i] += embedding[i] * weight;
    }
    totalWeight += weight;
  }

  if (totalWeight <= 0) {
    return [];
  }

  // No magnitude normalization needed: the vector index uses cosine similarity,
  // which is invariant to scaling the query vector by a positive scalar.

  const vectorResult = await neo4jService.run(
    `
    CALL db.index.vector.queryNodes('tag_embeddings', toInteger($topK), $userTasteVector)
    YIELD node AS tagNode, score AS similarity
    MATCH (tagNode)<-[h:HAS_TAG]-(ml:MovieLensMovie)-[:MATCHES_TMDB]->(m:Movie)
    
    MATCH (me:AppUser {uid: $uid})
    WHERE NOT (me)-[:LIKED|DISLIKED|WATCHLISTED|ALREADY_SEEN|SELECTED_FAVORITE]->(m)
    
    WITH ml, m, tagNode.name AS tag, h.frequency AS tagFrequency, similarity
    WITH ml, m, tag, tagFrequency, (2.0 * similarity - 1.0) AS stdSimilarity
    WHERE stdSimilarity >= $similarityThreshold
    
    WITH ml, m, sum(tagFrequency * (stdSimilarity ^ 3)) AS rawScore, collect({ tag: tag, frequency: tagFrequency, similarity: stdSimilarity }) AS matchedTags
    WITH m, rawScore / sqrt(toFloat(coalesce(ml.totalTagCount, 1.0))) AS tagRelevanceScore, matchedTags
    WHERE tagRelevanceScore > 0
    
    RETURN
      m.tmdbId AS tmdbId,
      m.title AS title,
      tagRelevanceScore,
      matchedTags,
      m.movieLensAvgRating AS globalAvg,
      m.movieLensRatingCount AS ratingCount
    ORDER BY tagRelevanceScore DESC, m.movieLensAvgRating DESC, m.movieLensRatingCount DESC
    LIMIT toInteger($limit)
    `,
    {
      uid,
      userTasteVector,
      topK: 25,
      similarityThreshold: 0.35,
      limit: safeLimit,
    }
  );

  return vectorResult.records.map((rec) => {
    const rawScore = toFiniteNumber(rec.get('tagRelevanceScore'));
    const finalScore = rawScore * 10.0;

    return {
      tmdbId: toNativeNumber(rec.get('tmdbId')),
      title: rec.get('title'),
      similarUsers: 0,
      avgSimilarRating: null,
      collaborativeScore: 0.0,
      genreScore: 0.0,
      popularityScore: Math.log(toNativeNumber(rec.get('ratingCount')) + 1.0),
      negativePenalty: 0.0,
      explorationBonus: 0.0,
      finalScore,
      globalAvg: rec.get('globalAvg') == null ? null : toFiniteNumber(rec.get('globalAvg')),
      ratingCount: toNativeNumber(rec.get('ratingCount')),
      source: 'semantic-tag',
      reason: 'Matches themes and vibes you enjoy based on your ratings.',
      tagRelevanceScore: rawScore,
      matchedTags: Array.isArray(rec.get('matchedTags'))
        ? rec.get('matchedTags').map(mt => ({
            tag: mt.tag,
            frequency: toNativeNumber(mt.frequency)
          }))
        : [],
    };
  });
}

async function getRecommendationCandidates(uid) {
  const personalized = await getPersonalizedRecommendationCandidates(uid);
  const semantic = await getSemanticTagRecommendationCandidates(uid);

  const combined = [];
  const seen = new Set();

  for (const c of personalized) {
    seen.add(c.tmdbId);
    combined.push(c);
  }

  for (const c of semantic) {
    if (seen.has(c.tmdbId)) {
      const existing = combined.find(x => x.tmdbId === c.tmdbId);
      if (existing) {
        existing.finalScore += c.finalScore;
        existing.reason = `${existing.reason} Also matches themes you like.`;
        existing.source = 'hybrid';
      }
    } else {
      seen.add(c.tmdbId);
      combined.push(c);
    }
  }

  combined.sort((a, b) => b.finalScore - a.finalScore);

  if (combined.length > 0) {
    return {
      candidates: combined,
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

    // The bare range predicate (no coalesce) lets the planner use the
    // movie_ml_rating_count index; with $minRatingCount > 0 it is equivalent
    // because NULL fails both forms. PROFILE: 19.611 -> 453 db hits.
    MATCH (m:Movie)
    WHERE m.movieLensRatingCount >= $minRatingCount
      AND m.tmdbId IS NOT NULL
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
    LIMIT toInteger($limit)
    `,
    {
      uid,
      excludedTmdbIds,
      globalMeanRating: 3.5,
      minRatingCount: 25,
      limit: safeLimit,
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
    WITH signal, movie, [genre IN collect(DISTINCT mlGenre.name) + collect(DISTINCT movieGenre.name) WHERE genre IS NOT NULL] AS genreNames
    UNWIND genreNames AS genreName
    WITH genreName,
      CASE type(signal)
        WHEN 'SELECTED_FAVORITE' THEN coalesce(signal.weight, 4.0)
        WHEN 'LIKED' THEN 3.0
        WHEN 'WATCHLISTED' THEN 1.25
        ELSE 1.0
      END AS signalWeight
    RETURN genreName AS name, sum(signalWeight) AS score
    ORDER BY score DESC, name ASC
    LIMIT toInteger($limit)
    `,
    { uid, limit: safeLimit }
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
    WITH movie, [genre IN collect(DISTINCT mlGenre.name) + collect(DISTINCT movieGenre.name) WHERE genre IS NOT NULL] AS genreNames
    UNWIND genreNames AS genreName
    RETURN genreName AS name, count(*) AS score
    ORDER BY score DESC, name ASC
    LIMIT toInteger($limit)
    `,
    { uid, limit: safeLimit }
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
    LIMIT toInteger($limit)
    `,
    { uid, limit: safeLimit }
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
    LIMIT toInteger($limit)
    `,
    { uid, limit: safeLimit }
  );

  return result.records.map((record) => ({
    tmdbId: toNativeNumber(record.get('tmdbId')),
    title: record.get('title') || '',
    signalType: record.get('signalType') || '',
    score: toFiniteNumber(record.get('score')),
  }));
}

async function getTopPositiveTagSignals(uid, limit = 10) {
  const safeLimit = toPositiveInteger(limit, 10, 50);
  const result = await neo4jService.run(
    `
    MATCH (me:AppUser {uid: $uid})-[signal:LIKED|SELECTED_FAVORITE|WATCHLISTED]->(movie:Movie)
    MATCH (movie)<-[:MATCHES_TMDB]-(ml:MovieLensMovie)-[h:HAS_TAG]->(t:Tag)
    WITH t.name AS name,
      (CASE type(signal)
        WHEN 'SELECTED_FAVORITE' THEN coalesce(signal.weight, 4.0)
        WHEN 'LIKED' THEN 3.0
        WHEN 'WATCHLISTED' THEN 1.5
        ELSE 1.0
      END * coalesce(h.frequency, 1)) AS tagWeight
    RETURN name, sum(tagWeight) AS score
    ORDER BY score DESC, name ASC
    LIMIT toInteger($limit)
    `,
    { uid, limit: safeLimit }
  );

  return result.records.map((record) => ({
    name: record.get('name') || '',
    score: toFiniteNumber(record.get('score')),
  }));
}

async function getTopNegativeTagSignals(uid, limit = 10) {
  const safeLimit = toPositiveInteger(limit, 10, 50);
  const result = await neo4jService.run(
    `
    MATCH (me:AppUser {uid: $uid})-[signal:DISLIKED]->(movie:Movie)
    MATCH (movie)<-[:MATCHES_TMDB]-(ml:MovieLensMovie)-[h:HAS_TAG]->(t:Tag)
    WITH t.name AS name,
      (3.0 * coalesce(h.frequency, 1)) AS tagWeight
    RETURN name, sum(tagWeight) AS score
    ORDER BY score DESC, name ASC
    LIMIT toInteger($limit)
    `,
    { uid, limit: safeLimit }
  );

  return result.records.map((record) => ({
    name: record.get('name') || '',
    score: toFiniteNumber(record.get('score')),
  }));
}

async function getCandidatePoolStats(uid) {
  const result = await neo4jService.run(
    `
    // Aggregates over the user's interaction relationships (small degree)
    // instead of evaluating three EXISTS{} per Movie node, which required
    // ~7x the db hits on the full catalog. PROFILE: 68.638 -> 9.809 db hits.
    MATCH (me:AppUser {uid: $uid})
    OPTIONAL MATCH (me)-[r:ALREADY_SEEN|DISLIKED|LIKED|WATCHLISTED|SELECTED_FAVORITE]->(m:Movie)
    WHERE m.tmdbId IS NOT NULL
    WITH m,
      max(CASE WHEN type(r) = 'ALREADY_SEEN' THEN 1 ELSE 0 END) AS seen,
      max(CASE WHEN type(r) = 'DISLIKED' THEN 1 ELSE 0 END) AS disliked,
      max(CASE WHEN type(r) IN ['LIKED', 'WATCHLISTED', 'SELECTED_FAVORITE'] THEN 1 ELSE 0 END) AS swiped
    WITH
      sum(CASE WHEN m IS NOT NULL AND seen = 1 THEN 1 ELSE 0 END) AS filteredAlreadySeen,
      sum(CASE WHEN m IS NOT NULL AND seen = 0 AND disliked = 1 THEN 1 ELSE 0 END) AS filteredDisliked,
      sum(CASE WHEN m IS NOT NULL AND seen = 0 AND disliked = 0 AND swiped = 1 THEN 1 ELSE 0 END) AS filteredAlreadySwiped
    CALL {
      MATCH (cand:Movie)
      WHERE cand.tmdbId IS NOT NULL
      RETURN count(cand) AS totalCandidatesConsidered
    }
    RETURN
      totalCandidatesConsidered,
      filteredAlreadySeen,
      filteredDisliked,
      filteredAlreadySwiped,
      totalCandidatesConsidered - filteredAlreadySeen - filteredDisliked - filteredAlreadySwiped AS remainingAfterFiltering
    `,
    { uid }
  );

  if (result.records.length === 0) {
    return {
      totalCandidatesConsidered: 0,
      filteredAlreadySeen: 0,
      filteredDisliked: 0,
      filteredAlreadySwiped: 0,
      remainingAfterFiltering: 0,
    };
  }

  const record = result.records[0];
  return {
    totalCandidatesConsidered: toNativeNumber(record.get('totalCandidatesConsidered')),
    filteredAlreadySeen: toNativeNumber(record.get('filteredAlreadySeen')),
    filteredDisliked: toNativeNumber(record.get('filteredDisliked')),
    filteredAlreadySwiped: toNativeNumber(record.get('filteredAlreadySwiped')),
    remainingAfterFiltering: toNativeNumber(record.get('remainingAfterFiltering')),
  };
}

async function findMoviesBySemanticTags(tagsWithWeights, uid) {
  if (!tagsWithWeights || tagsWithWeights.length === 0) {
    return [];
  }

  const tags = tagsWithWeights.map(t => t.tag);
  const tagWeights = {};
  tagsWithWeights.forEach(t => {
    tagWeights[t.tag] = t.similarity;
  });

  const result = await neo4jService.run(
    `
    MATCH (ml:MovieLensMovie)-[:MATCHES_TMDB]->(m:Movie)
    MATCH (ml)-[h:HAS_TAG]->(t:Tag)
    WHERE t.name IN $tags
    WITH ml, m, t.name AS tag, h.frequency AS tagFrequency
    WITH ml, m, sum(tagFrequency * (toFloat($tagWeights[tag]) ^ 3)) AS rawScore, collect({ tag: tag, frequency: tagFrequency }) AS matchedTags
    WITH m, rawScore / sqrt(toFloat(coalesce(ml.totalTagCount, 1.0))) AS tagRelevanceScore, matchedTags
    WHERE tagRelevanceScore > 0

    OPTIONAL MATCH (me:AppUser {uid: $uid})
    WITH m, tagRelevanceScore, matchedTags, me
    WHERE me IS NULL OR NOT (me)-[:LIKED|DISLIKED|WATCHLISTED|ALREADY_SEEN|SELECTED_FAVORITE]->(m)

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
      m.movieLensRatingCount AS movieLensRatingCount,
      m.genres AS genres,
      m.tmdbHydrated AS tmdbHydrated,
      tagRelevanceScore,
      matchedTags
    ORDER BY tagRelevanceScore DESC, m.movieLensAvgRating DESC, m.movieLensRatingCount DESC
    LIMIT 30
    `,
    {
      tags,
      tagWeights,
      uid: uid || null,
    }
  );

  return result.records.map((record) => normalizeMovieRecord(record)).filter(Boolean);
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
  getSemanticTagRecommendationCandidates,
  getRecommendationCandidates,
  getRecommendations,
  getExploratoryCandidates,
  getRecommendationUserProfile,
  getTopPositiveGenreSignals,
  getTopNegativeGenreSignals,
  getTopPositiveMovies,
  getTopNegativeMovies,
  getTopPositiveTagSignals,
  getTopNegativeTagSignals,
  getCandidatePoolStats,
  findMoviesBySemanticTags,
};
