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

async function removeFromWatchlist(uid, tmdbId) {
  await neo4jService.run(
    `
    MATCH (:AppUser {uid: $uid})-[r:WATCHLISTED]->(:Movie {tmdbId: $tmdbId})
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

async function getRecommendations(uid) {
  const personalized = await neo4jService.run(
    `
    MATCH (me:AppUser {uid: $uid})-[:LIKED|SELECTED_FAVORITE]->(liked:Movie)
    MATCH (liked)<-[:MATCHES_TMDB]-(likedMl:MovieLensMovie)<-[r1:RATED]-(similar:MovieLensUser)
    WHERE r1.rating >= 4.0

    MATCH (similar)-[r2:RATED]->(recMl:MovieLensMovie)-[:MATCHES_TMDB]->(rec:Movie)
    WHERE r2.rating >= 4.0
      AND rec.tmdbId IS NOT NULL
      AND NOT (me)-[:LIKED|DISLIKED|WATCHLISTED]->(rec)

    RETURN
      rec.tmdbId AS tmdbId,
      rec.title AS title,
      count(DISTINCT similar) AS similarUsers,
      avg(r2.rating) AS avgSimilarRating,
      rec.movieLensAvgRating AS globalAvg,
      rec.movieLensRatingCount AS ratingCount
    ORDER BY
      similarUsers DESC,
      avgSimilarRating DESC,
      ratingCount DESC
    LIMIT 30
    `,
    { uid }
  );

  if (personalized.records.length > 0) {
    return personalized.records.map((record) => ({
      tmdbId: toNativeNumber(record.get('tmdbId')),
      title: record.get('title') || '',
      similarUsers: toNativeNumber(record.get('similarUsers')),
      avgSimilarRating: Number(record.get('avgSimilarRating')),
      globalAvg: record.get('globalAvg') == null ? null : Number(record.get('globalAvg')),
      ratingCount: record.get('ratingCount') == null ? 0 : toNativeNumber(record.get('ratingCount')),
    }));
  }

  const fallback = await neo4jService.run(
    `
    MATCH (m:Movie)
    WHERE m.tmdbId IS NOT NULL
      AND m.movieLensRatingCount >= 50
    RETURN
      m.tmdbId AS tmdbId,
      m.title AS title,
      m.movieLensAvgRating AS globalAvg,
      m.movieLensRatingCount AS ratingCount
    ORDER BY m.movieLensAvgRating DESC, m.movieLensRatingCount DESC
    LIMIT 30
    `
  );

  return fallback.records.map((record) => ({
    tmdbId: toNativeNumber(record.get('tmdbId')),
    title: record.get('title') || '',
    similarUsers: 0,
    avgSimilarRating: null,
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
  removeFromWatchlist,
  getUserLibrary,
  getRecommendations,
};
