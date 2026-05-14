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

async function findMoviesByTmdbIds(tmdbIds) {
  if (!Array.isArray(tmdbIds) || tmdbIds.length === 0) {
    return [];
  }

  const result = await neo4jService.run(
    `
    UNWIND $tmdbIds AS tmdbId
    MATCH (m:Movie {tmdbId: tmdbId})
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
      m.director AS director,
      m.voteAverage AS voteAverage,
      m.movieLensAvgRating AS movieLensAvgRating,
      m.movieLensRatingCount AS movieLensRatingCount
    `,
    { tmdbIds }
  );

  return result.records.map(normalizeMovieRecord).filter(Boolean);
}

async function mergeTmdbMovie(movie) {
  const result = await neo4jService.run(
    `
    MERGE (m:Movie {tmdbId: $tmdbId})
    ON CREATE SET
      m.source = 'tmdb',
      m.createdAt = datetime()
    SET
      m.title = $title,
      m.originalTitle = $originalTitle,
      m.overview = $overview,
      m.posterPath = $posterPath,
      m.backdropPath = $backdropPath,
      m.posterUrl = $posterUrl,
      m.backdropUrl = $backdropUrl,
      m.releaseDate = $releaseDate,
      m.director = $director,
      m.voteAverage = $voteAverage,
      m.updatedAt = datetime()
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
      m.director AS director,
      m.voteAverage AS voteAverage,
      m.movieLensAvgRating AS movieLensAvgRating,
      m.movieLensRatingCount AS movieLensRatingCount
    `,
    {
      tmdbId: movie.tmdbId,
      title: movie.title,
      originalTitle: movie.originalTitle,
      overview: movie.overview,
      posterPath: movie.posterPath,
      backdropPath: movie.backdropPath,
      posterUrl: movie.posterUrl,
      backdropUrl: movie.backdropUrl,
      releaseDate: movie.releaseDate,
      director: movie.director,
      voteAverage: movie.voteAverage,
    }
  );

  return normalizeMovieRecord(result.records[0]);
}

async function likeMovie(uid, movie) {
  await neo4jService.run(
    `
    MATCH (u:AppUser {uid: $uid})-[old:DISLIKED]->(m:Movie {tmdbId: $tmdbId})
    DELETE old
    `,
    { uid, tmdbId: movie.tmdbId }
  );

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

async function saveSelectedFavorites(uid, movies, weight = 4.0) {
  const selectedMovies = Array.isArray(movies) ? movies : [];

  for (const movie of selectedMovies) {
    await mergeTmdbMovie(movie);
  }

  const tmdbIds = selectedMovies
    .map((movie) => movie?.tmdbId)
    .filter((tmdbId) => Number.isInteger(tmdbId) && tmdbId > 0);

  const result = await neo4jService.run(
    `
    MATCH (u:AppUser {uid: $uid})
    OPTIONAL MATCH (u)-[old:SELECTED_FAVORITE]->(:Movie)
    DELETE old
    WITH u
    CALL {
      WITH u
      UNWIND $tmdbIds AS tmdbId
      MATCH (m:Movie {tmdbId: tmdbId})
      MERGE (u)-[r:SELECTED_FAVORITE]->(m)
      ON CREATE SET r.createdAt = datetime()
      SET r.weight = $weight
      RETURN count(r) AS selectedCount
    }
    RETURN selectedCount
    `,
    { uid, tmdbIds, weight }
  );

  return result.records.length > 0;
}

async function savePreferredGenres(uid, genres) {
  const normalizedGenres = Array.isArray(genres)
    ? genres
        .map((genre) => (genre == null ? '' : String(genre).trim()))
        .filter((genre) => genre.length > 0)
    : [];

  const result = await neo4jService.run(
    `
    MATCH (u:AppUser {uid: $uid})
    OPTIONAL MATCH (u)-[old:PREFERS_GENRE]->(:Genre)
    DELETE old
    WITH u
    CALL {
      WITH u
      UNWIND $genres AS genreName
      MERGE (g:Genre {name: genreName})
      MERGE (u)-[r:PREFERS_GENRE]->(g)
      ON CREATE SET r.createdAt = datetime()
      RETURN count(r) AS preferredGenreCount
    }
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

/**
 * Ottiene le raccomandazioni dei film per un utente specifico.
 * Implementa un algoritmo di Filtraggio Collaborativo tramite Neo4j
 * e prevede un fallback sui film più popolari (per risolvere il "cold start").
 * * @param {string} uid - L'ID univoco dell'utente nell'app.
 * @returns {Array} - Un array di oggetti contenenti i dati dei film raccomandati.
 */
/**
 * Ottiene le raccomandazioni dei film per un utente specifico.
 * Implementa un algoritmo di Filtraggio Collaborativo tramite Neo4j
 * e prevede un fallback sui film più popolari (per risolvere il "cold start").
 * * @param {string} uid - L'ID univoco dell'utente nell'app.
 * @returns {Array} - Un array di oggetti contenenti i dati dei film raccomandati.
 */
async function getRecommendations(uid) {
  
  // ==========================================
  // FASE 1: QUERY DI RACCOMANDAZIONE PERSONALIZZATA
  // ==========================================
  
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
        * (1.0 / log(toFloat(coalesce(seed.movieLensRatingCount, seedMl.movieLensRatingCount, 0)) + 2.0))
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
      avgOverlapCount,
      negativePenalty,
      finalScore,
      rec.movieLensAvgRating AS globalAvg,
      rec.movieLensRatingCount AS ratingCount
    
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

  if (personalized.records.length > 0) {
    return personalized.records.map((record) => ({
      tmdbId: toNativeNumber(record.get('tmdbId')),
      title: record.get('title') || '',
      similarUsers: toNativeNumber(record.get('similarUsers')),
      avgSimilarRating: Number(record.get('avgSimilarRating')),
      collaborativeScore: Number(record.get('collaborativeScore')),
      avgOverlapCount: Number(record.get('avgOverlapCount')),
      negativePenalty: Number(record.get('negativePenalty')),
      finalScore: Number(record.get('finalScore')),
      globalAvg: record.get('globalAvg') == null ? null : Number(record.get('globalAvg')),
      ratingCount: record.get('ratingCount') == null ? 0 : toNativeNumber(record.get('ratingCount')),
    }));
  }

  // ==========================================
  // FASE 2: QUERY DI FALLBACK (COLD START)
  // ==========================================
  
  const fallback = await neo4jService.run(
    `
    // FIX DEL BUG COLD START: Usiamo OPTIONAL MATCH in modo che proceda anche se il nodo utente non esiste ancora!
    OPTIONAL MATCH (me:AppUser {uid: $uid})
    CALL {
      WITH me
      OPTIONAL MATCH (me)-[:PREFERS_GENRE]->(preferred:Genre)
      RETURN collect(DISTINCT preferred.name) AS preferredGenres
    }
    CALL {
      WITH me
      OPTIONAL MATCH (me)-[:SELECTED_FAVORITE]->(favorite:Movie)
      OPTIONAL MATCH (favorite)<-[:MATCHES_TMDB]-(favoriteMl:MovieLensMovie)-[:IN_GENRE]->(favoriteMlGenre:Genre)
      OPTIONAL MATCH (favorite)-[:IN_GENRE]->(favoriteMovieGenre:Genre)
      RETURN collect(DISTINCT favoriteMlGenre.name) + collect(DISTINCT favoriteMovieGenre.name) AS favoriteGenres
    }

    MATCH (m:Movie)
    WHERE m.tmdbId IS NOT NULL
      AND coalesce(m.movieLensRatingCount, 0) >= $minFallbackRatingCount
      // NOT EXISTS evaluta a TRUE in automatico se 'me' è null (perfetto per i nuovi utenti)
      AND NOT EXISTS {
        MATCH (me)-[:LIKED|DISLIKED|WATCHLISTED|ALREADY_SEEN|SELECTED_FAVORITE]->(m)
      }

    OPTIONAL MATCH (m)<-[:MATCHES_TMDB]-(ml:MovieLensMovie)-[:IN_GENRE]->(mlGenre:Genre)
    OPTIONAL MATCH (m)-[:IN_GENRE]->(movieGenre:Genre)
    WITH
      m,
      preferredGenres,
      favoriteGenres,
      collect(DISTINCT mlGenre.name) + collect(DISTINCT movieGenre.name) AS candidateGenres
    WITH
      m,
      preferredGenres,
      favoriteGenres,
      candidateGenres,
      size([genre IN candidateGenres WHERE genre IN preferredGenres]) AS matchedPreferredGenres,
      size([genre IN candidateGenres WHERE genre IN favoriteGenres]) AS matchedFavoriteGenres,
      toFloat(coalesce(m.movieLensRatingCount, 0)) AS ratingCount,
      toFloat(coalesce(m.movieLensAvgRating, $globalMeanRating)) AS avgRating
    WITH
      m,
      matchedPreferredGenres,
      matchedFavoriteGenres,
      ratingCount,
      ((ratingCount / (ratingCount + $bayesianPriorWeight)) * avgRating) +
        (($bayesianPriorWeight / (ratingCount + $bayesianPriorWeight)) * $globalMeanRating) AS bayesianScore,
      CASE
        WHEN size(preferredGenres) > 0 THEN matchedPreferredGenres * 100.0 + matchedFavoriteGenres * 10.0
        WHEN size(favoriteGenres) > 0 THEN matchedFavoriteGenres * 80.0
        ELSE 0.0
      END AS preferenceScore
    
    RETURN
      m.tmdbId AS tmdbId,
      m.title AS title,
      0 AS similarUsers,
      null AS avgSimilarRating,
      (preferenceScore + bayesianScore + log(ratingCount + 1.0)) AS collaborativeScore,
      0.0 AS avgOverlapCount,
      0.0 AS negativePenalty,
      (preferenceScore + bayesianScore + log(ratingCount + 1.0)) AS finalScore,
      m.movieLensAvgRating AS globalAvg,
      m.movieLensRatingCount AS ratingCount
    
    ORDER BY
      finalScore DESC,
      preferenceScore DESC,
      bayesianScore DESC,
      ratingCount DESC
    LIMIT 80
    `,
    {
      uid,
      minFallbackRatingCount: 50,
      bayesianPriorWeight: 100.0,
      globalMeanRating: 3.5,
    }
  );

  return fallback.records.map((record) => ({
    tmdbId: toNativeNumber(record.get('tmdbId')),
    title: record.get('title') || '',
    similarUsers: toNativeNumber(record.get('similarUsers')),
    avgSimilarRating: record.get('avgSimilarRating'),
    collaborativeScore: Number(record.get('collaborativeScore')),
    avgOverlapCount: Number(record.get('avgOverlapCount')),
    negativePenalty: Number(record.get('negativePenalty')),
    finalScore: Number(record.get('finalScore')),
    globalAvg: record.get('globalAvg') == null ? null : Number(record.get('globalAvg')),
    ratingCount: record.get('ratingCount') == null ? 0 : toNativeNumber(record.get('ratingCount')),
  }));
}

module.exports = {
  findMovieByTmdbId,
  findMoviesByTmdbIds,
  mergeTmdbMovie,
  likeMovie,
  dislikeMovie,
  watchlistMovie,
  saveSelectedFavorites,
  savePreferredGenres,
  removeFromWatchlist,
  removeLike,
  removeDislike,
  getUserLibrary,
  getRecommendations,
};
