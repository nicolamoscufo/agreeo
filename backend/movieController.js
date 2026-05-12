const { tmdbGet } = require('./tmdbClient');
const movieRepository = require('./movieRepository');
const neo4jService = require('./neo4jService');

function parseTmdbId(value) {
  const tmdbId = Number.parseInt(value, 10);

  if (!Number.isInteger(tmdbId) || tmdbId <= 0) {
    return null;
  }

  return tmdbId;
}

function parseTmdbIds(value) {
  if (!Array.isArray(value)) {
    return [];
  }

  const seen = new Set();
  const tmdbIds = [];

  for (const item of value) {
    const tmdbId = parseTmdbId(item);
    if (tmdbId && !seen.has(tmdbId)) {
      seen.add(tmdbId);
      tmdbIds.push(tmdbId);
    }
  }

  return tmdbIds;
}

function parseStringList(value) {
  if (!Array.isArray(value)) {
    return [];
  }

  const seen = new Set();
  const items = [];

  for (const item of value) {
    const text = item == null ? '' : String(item).trim();
    if (text && !seen.has(text)) {
      seen.add(text);
      items.push(text);
    }
  }

  return items;
}

function imageUrl(path, size) {
  if (!path) {
    return '';
  }

  return `https://image.tmdb.org/t/p/${size}${path}`;
}

function normalizeRecommendationTitle(title) {
  return String(title || '')
    .normalize('NFKD')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()
    .replace(/\s+/g, ' ');
}

function diversifyRecommendations(candidates, limit = 30) {
  const ordered = Array.isArray(candidates) ? candidates.filter(Boolean) : [];
  const selected = [];
  const skipped = [];
  const seenTmdbIds = new Set();
  const seenTitles = new Set();
  const genreCounts = new Map();
  const hasGenreData = ordered.some(
    (candidate) => Array.isArray(candidate.genreIds) && candidate.genreIds.length > 0
  );
  const genreCap = hasGenreData ? Math.max(2, Math.ceil(limit / 8)) : null;

  function isDuplicate(candidate) {
    const tmdbKey = candidate.tmdbId == null ? null : String(candidate.tmdbId);
    const titleKey = normalizeRecommendationTitle(candidate.title || candidate.originalTitle);

    if (tmdbKey && seenTmdbIds.has(tmdbKey)) {
      return true;
    }

    return titleKey.length > 0 && seenTitles.has(titleKey);
  }

  function markSeen(candidate) {
    if (candidate.tmdbId != null) {
      seenTmdbIds.add(String(candidate.tmdbId));
    }

    const titleKey = normalizeRecommendationTitle(candidate.title || candidate.originalTitle);
    if (titleKey.length > 0) {
      seenTitles.add(titleKey);
    }
  }

  function candidateGenreIds(candidate) {
    if (!Array.isArray(candidate.genreIds)) {
      return [];
    }

    return [...new Set(candidate.genreIds.filter((id) => Number.isInteger(id)))];
  }

  function canTake(candidate) {
    if (!hasGenreData || !genreCap) {
      return true;
    }

    const genres = candidateGenreIds(candidate);
    if (genres.length === 0) {
      return true;
    }

    const lowestPressure = Math.min(
      ...genres.map((genreId) => genreCounts.get(genreId) || 0)
    );

    return lowestPressure < genreCap;
  }

  function applyGenreCounts(candidate) {
    for (const genreId of candidateGenreIds(candidate)) {
      genreCounts.set(genreId, (genreCounts.get(genreId) || 0) + 1);
    }
  }

  for (const candidate of ordered) {
    if (selected.length >= limit) {
      break;
    }

    if (isDuplicate(candidate)) {
      continue;
    }

    if (!canTake(candidate)) {
      skipped.push(candidate);
      continue;
    }

    markSeen(candidate);
    applyGenreCounts(candidate);
    selected.push(candidate);
  }

  if (selected.length < limit && skipped.length > 0) {
    for (const candidate of skipped) {
      if (selected.length >= limit) {
        break;
      }

      if (isDuplicate(candidate)) {
        continue;
      }

      markSeen(candidate);
      selected.push(candidate);
    }
  }

  if (!hasGenreData) {
    // TODO: add genre-aware reranking once canonical genre data is guaranteed everywhere.
  }

  return selected.slice(0, limit);
}

async function hydrateRecommendations(
  recommendations,
  {
    limit = 30,
    batchSize = 4,
    tmdbFetch = tmdbGet,
    findMovieByTmdbId = movieRepository.findMovieByTmdbId,
    logger = console,
  } = {}
) {
  const hydrated = [];
  const candidates = Array.isArray(recommendations) ? recommendations.filter(Boolean) : [];

  for (let index = 0; index < candidates.length && hydrated.length < limit; index += batchSize) {
    const batch = candidates.slice(index, index + batchSize);
    const batchHydrated = await Promise.all(
      batch.map(async (entry) => {
        try {
          const tmdbMovie = await tmdbFetch(`/movie/${entry.tmdbId}`);
          if (!tmdbMovie || typeof tmdbMovie !== 'object' || !Number.isInteger(tmdbMovie.id)) {
            logger.warn(`Skipping invalid TMDB recommendation ${entry.tmdbId}: invalid payload`);
            return null;
          }

          const neoMovie = await findMovieByTmdbId(entry.tmdbId);
          return {
            ...mapTmdbMovie(tmdbMovie, {
              ...(neoMovie || {}),
              movieLensAvgRating: entry.globalAvg ?? neoMovie?.movieLensAvgRating ?? null,
              movieLensRatingCount: entry.ratingCount ?? neoMovie?.movieLensRatingCount ?? 0,
            }),
            recommendation: {
              similarUsers: entry.similarUsers,
              avgSimilarRating: entry.avgSimilarRating,
            },
          };
        } catch (error) {
          const message = error instanceof Error ? error.message : String(error);
          if (message.includes('TMDB error 404')) {
            // TODO: mark stale TMDB ids in Neo4j if a safe invalidation mechanism is added.
            logger.warn(`Skipping stale TMDB recommendation ${entry.tmdbId}: ${message}`);
            return null;
          }

          logger.warn(`Skipping TMDB recommendation ${entry.tmdbId}: ${message}`);
          return null;
        }
      })
    );

    for (const movie of batchHydrated) {
      if (movie) {
        hydrated.push(movie);
      }
      if (hydrated.length >= limit) {
        break;
      }
    }
  }

  return hydrated.slice(0, limit);
}

function extractTrailerUrl(videos) {
  const entries = Array.isArray(videos?.results) ? videos.results : [];
  const trailer = entries.find(
    (entry) => entry.site === 'YouTube' && (entry.type === 'Trailer' || entry.type === 'Teaser')
  );

  return trailer?.key ? `https://www.youtube.com/watch?v=${trailer.key}` : '';
}

function mapMovieLens(neoMovie, fallbackAvg, fallbackCount) {
  const avgRating = neoMovie?.movieLensAvgRating ?? fallbackAvg ?? null;
  const ratingCount = neoMovie?.movieLensRatingCount ?? fallbackCount ?? 0;

  return {
    avgRating,
    ratingCount,
  };
}

function mapTmdbMovie(tmdbMovie, neoMovie = null) {
  return {
    tmdbId: tmdbMovie.id,
    title: tmdbMovie.title || tmdbMovie.name || '',
    originalTitle: tmdbMovie.original_title || tmdbMovie.original_name || tmdbMovie.title || '',
    overview: tmdbMovie.overview || '',
    posterPath: tmdbMovie.poster_path || null,
    backdropPath: tmdbMovie.backdrop_path || null,
    posterUrl: imageUrl(tmdbMovie.poster_path, 'w500'),
    backdropUrl: imageUrl(tmdbMovie.backdrop_path, 'w780'),
    releaseDate: tmdbMovie.release_date || tmdbMovie.first_air_date || '',
    voteAverage:
      tmdbMovie.vote_average == null ? null : Number(Number(tmdbMovie.vote_average).toFixed(1)),
    genreIds: Array.isArray(tmdbMovie.genre_ids)
      ? tmdbMovie.genre_ids.filter((id) => Number.isInteger(id))
      : Array.isArray(tmdbMovie.genres)
        ? tmdbMovie.genres
            .map((genre) => genre?.id)
            .filter((id) => Number.isInteger(id))
        : [],
    movieLens: mapMovieLens(neoMovie),
  };
}

function mapTmdbMovieDetails(tmdbMovie, neoMovie = null) {
  const base = mapTmdbMovie(tmdbMovie, neoMovie);

  return {
    ...base,
    runtime: Number.isInteger(tmdbMovie.runtime) ? tmdbMovie.runtime : null,
    genres: Array.isArray(tmdbMovie.genres)
      ? tmdbMovie.genres
          .map((genre) => genre?.name)
          .filter((name) => typeof name === 'string' && name.trim() !== '')
      : [],
    cast: Array.isArray(tmdbMovie.credits?.cast)
      ? tmdbMovie.credits.cast.slice(0, 10).map((member) => ({
          id: member.id,
          name: member.name || '',
          character: member.character || '',
          profilePath: member.profile_path || null,
          profileUrl: imageUrl(member.profile_path, 'w185'),
        }))
      : [],
    trailerUrl: extractTrailerUrl(tmdbMovie.videos),
    trailers: Array.isArray(tmdbMovie.videos?.results)
      ? tmdbMovie.videos.results
          .filter((entry) => entry.site === 'YouTube')
          .map((entry) => ({
            id: entry.id,
            key: entry.key,
            name: entry.name || '',
            type: entry.type || '',
            url: entry.key ? `https://www.youtube.com/watch?v=${entry.key}` : '',
          }))
      : [],
    images: {
      backdrops: Array.isArray(tmdbMovie.images?.backdrops)
        ? tmdbMovie.images.backdrops.slice(0, 10).map((image) => ({
            filePath: image.file_path || null,
            url: imageUrl(image.file_path, 'w780'),
          }))
        : [],
      posters: Array.isArray(tmdbMovie.images?.posters)
        ? tmdbMovie.images.posters.slice(0, 10).map((image) => ({
            filePath: image.file_path || null,
            url: imageUrl(image.file_path, 'w500'),
          }))
        : [],
    },
  };
}

function mapRepositoryMovieToResponse(movie) {
  return {
    tmdbId: movie.tmdbId,
    title: movie.title,
    originalTitle: movie.originalTitle || movie.title,
    overview: movie.overview || '',
    posterPath: movie.posterPath,
    backdropPath: movie.backdropPath,
    posterUrl: movie.posterUrl || '',
    backdropUrl: movie.backdropUrl || '',
    releaseDate: movie.releaseDate || '',
    voteAverage: movie.voteAverage,
    genreIds: [],
    movieLens: {
      avgRating: movie.movieLensAvgRating ?? null,
      ratingCount: movie.movieLensRatingCount ?? 0,
    },
  };
}

function mapInteractionMovie(tmdbMovie) {
  return {
    tmdbId: tmdbMovie.id,
    title: tmdbMovie.title || tmdbMovie.name || '',
    originalTitle: tmdbMovie.original_title || tmdbMovie.original_name || tmdbMovie.title || '',
    overview: tmdbMovie.overview || '',
    posterPath: tmdbMovie.poster_path || null,
    backdropPath: tmdbMovie.backdrop_path || null,
    posterUrl: imageUrl(tmdbMovie.poster_path, 'w500'),
    backdropUrl: imageUrl(tmdbMovie.backdrop_path, 'w780'),
    releaseDate: tmdbMovie.release_date || tmdbMovie.first_air_date || '',
    voteAverage:
      tmdbMovie.vote_average == null ? null : Number(Number(tmdbMovie.vote_average).toFixed(1)),
  };
}

async function enrichMovies(tmdbMovies) {
  const tmdbIds = tmdbMovies
    .map((movie) => movie?.id)
    .filter((id) => Number.isInteger(id));
  const neoMovies = await movieRepository.findMoviesByTmdbIds(tmdbIds);
  const byTmdbId = new Map(neoMovies.map((movie) => [movie.tmdbId, movie]));

  return tmdbMovies.map((movie) => mapTmdbMovie(movie, byTmdbId.get(movie.id) || null));
}

async function fetchInteractionMovie(tmdbId) {
  const tmdbMovie = await tmdbGet(`/movie/${tmdbId}`);
  return mapInteractionMovie(tmdbMovie);
}

function requestUid(req) {
  return req.user?.uid || req.user?.sub;
}

function handleError(res, error, fallbackMessage) {
  console.error(fallbackMessage, error);
  return res.status(500).json({
    error: error instanceof Error ? error.message : fallbackMessage,
  });
}

exports.popular = async (_, res) => {
  try {
    const response = await tmdbGet('/movie/popular', { language: 'en-US', page: 1 });
    const results = Array.isArray(response.results) ? response.results : [];
    const movies = await enrichMovies(results);

    return res.json({
      results: movies,
    });
  } catch (error) {
    return handleError(res, error, 'Failed to load popular movies');
  }
};

exports.search = async (req, res) => {
  const query = typeof req.query.query === 'string' ? req.query.query.trim() : '';

  if (!query) {
    return res.status(400).json({
      error: 'Missing query parameter',
    });
  }

  try {
    const response = await tmdbGet('/search/movie', {
      query,
      language: 'en-US',
      include_adult: false,
      page: 1,
    });
    const results = Array.isArray(response.results) ? response.results : [];
    const movies = await enrichMovies(results);

    return res.json({
      results: movies,
    });
  } catch (error) {
    return handleError(res, error, 'Failed to search movies');
  }
};

exports.details = async (req, res) => {
  const tmdbId = parseTmdbId(req.params.tmdbId);

  if (!tmdbId) {
    return res.status(400).json({
      error: 'Invalid tmdbId',
    });
  }

  try {
    const [tmdbMovie, neoMovie] = await Promise.all([
      tmdbGet(`/movie/${tmdbId}`, {
        language: 'en-US',
        append_to_response: 'credits,videos,images',
        include_image_language: 'en,null',
      }),
      movieRepository.findMovieByTmdbId(tmdbId),
    ]);

    return res.json({
      movie: mapTmdbMovieDetails(tmdbMovie, neoMovie),
    });
  } catch (error) {
    return handleError(res, error, 'Failed to load movie details');
  }
};

exports.like = async (req, res) => {
  const uid = requestUid(req);
  const tmdbId = parseTmdbId(req.params.tmdbId);

  if (!uid || !tmdbId) {
    return res.status(400).json({ error: 'Invalid request' });
  }

  try {
    const movie = await fetchInteractionMovie(tmdbId);
    const liked = await movieRepository.likeMovie(uid, movie);

    if (!liked) {
      return res.status(404).json({ error: 'App user not found' });
    }

    const neoMovie = await movieRepository.findMovieByTmdbId(tmdbId);

    return res.json({
      ok: true,
      movie: mapRepositoryMovieToResponse(neoMovie || movie),
    });
  } catch (error) {
    return handleError(res, error, 'Failed to like movie');
  }
};

exports.dislike = async (req, res) => {
  const uid = requestUid(req);
  const tmdbId = parseTmdbId(req.params.tmdbId);

  if (!uid || !tmdbId) {
    return res.status(400).json({ error: 'Invalid request' });
  }

  try {
    const movie = await fetchInteractionMovie(tmdbId);
    const disliked = await movieRepository.dislikeMovie(uid, movie);

    if (!disliked) {
      return res.status(404).json({ error: 'App user not found' });
    }

    const neoMovie = await movieRepository.findMovieByTmdbId(tmdbId);

    return res.json({
      ok: true,
      movie: mapRepositoryMovieToResponse(neoMovie || movie),
    });
  } catch (error) {
    return handleError(res, error, 'Failed to dislike movie');
  }
};

exports.watchlist = async (req, res) => {
  const uid = requestUid(req);
  const tmdbId = parseTmdbId(req.params.tmdbId);

  if (!uid || !tmdbId) {
    return res.status(400).json({ error: 'Invalid request' });
  }

  try {
    const movie = await fetchInteractionMovie(tmdbId);
    const watchlisted = await movieRepository.watchlistMovie(uid, movie);

    if (!watchlisted) {
      return res.status(404).json({ error: 'App user not found' });
    }

    const neoMovie = await movieRepository.findMovieByTmdbId(tmdbId);

    return res.json({
      ok: true,
      movie: mapRepositoryMovieToResponse(neoMovie || movie),
    });
  } catch (error) {
    return handleError(res, error, 'Failed to add movie to watchlist');
  }
};

exports.updateOnboarding = async (req, res) => {
  const uid = requestUid(req);

  if (!uid) {
    return res.status(401).json({ error: 'Missing user context' });
  }

  const completed = req.body.completed === true;
  const selectedFavoriteTmdbIds = parseTmdbIds(req.body.selectedFavoriteTmdbIds);
  const favoriteGenres = parseStringList(req.body.favoriteGenres);
  const shouldPersistFavorites = Object.prototype.hasOwnProperty.call(
    req.body,
    'selectedFavoriteTmdbIds'
  );
  const shouldPersistGenres = Object.prototype.hasOwnProperty.call(req.body, 'favoriteGenres');

  try {
    if (shouldPersistGenres) {
      const saved = await movieRepository.savePreferredGenres(uid, favoriteGenres);

      if (!saved) {
        return res.status(404).json({ error: 'App user not found' });
      }
    }

    if (shouldPersistFavorites) {
      const selectedFavoriteMovies = await Promise.all(
        selectedFavoriteTmdbIds.map((tmdbId) => fetchInteractionMovie(tmdbId))
      );
      const saved = await movieRepository.saveSelectedFavorites(uid, selectedFavoriteMovies, 4.0);

      if (!saved) {
        return res.status(404).json({ error: 'App user not found' });
      }
    }

    const result = await neo4jService.run(
      `
      MATCH (u:AppUser {uid: $uid})
      SET u.onboardingCompleted = $completed
      RETURN
        u.uid AS uid,
        u.email AS email,
        u.displayName AS displayName,
        toString(u.createdAt) AS createdAt,
        coalesce(u.onboardingCompleted, false) AS onboardingCompleted,
        coalesce(u.roles, ['USER']) AS roles
      LIMIT 1
      `,
      { uid, completed }
    );

    if (result.records.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const record = result.records[0];

    return res.json({
      user: {
        uid: record.get('uid'),
        email: record.get('email'),
        displayName: record.get('displayName'),
        createdAt: record.get('createdAt'),
        onboardingCompleted: record.get('onboardingCompleted') === true,
        roles: record.get('roles') || ['USER'],
      },
    });
  } catch (error) {
    return handleError(res, error, 'Failed to update onboarding');
  }
};

exports.removeLike = async (req, res) => {
  const uid = requestUid(req);
  const tmdbId = parseTmdbId(req.params.tmdbId);

  if (isNaN(tmdbId)) {
    return res.status(400).json({ error: 'Valid tmdbId parameter is required' });
  }

  try {
    await movieRepository.removeLike(uid, tmdbId);
    return res.status(204).send();
  } catch (error) {
    return handleError(res, error, 'Failed to remove like');
  }
};

exports.removeDislike = async (req, res) => {
  const uid = requestUid(req);
  const tmdbId = parseTmdbId(req.params.tmdbId);

  if (isNaN(tmdbId)) {
    return res.status(400).json({ error: 'Valid tmdbId parameter is required' });
  }

  try {
    await movieRepository.removeDislike(uid, tmdbId);
    return res.status(204).send();
  } catch (error) {
    return handleError(res, error, 'Failed to remove dislike');
  }
};

exports.removeFromWatchlist = async (req, res) => {
  const uid = requestUid(req);
  const tmdbId = parseTmdbId(req.params.tmdbId);

  if (!uid || !tmdbId) {
    return res.status(400).json({ error: 'Invalid request' });
  }

  try {
    await movieRepository.removeFromWatchlist(uid, tmdbId);
    return res.status(204).send();
  } catch (error) {
    return handleError(res, error, 'Failed to remove movie from watchlist');
  }
};

exports.library = async (req, res) => {
  const uid = requestUid(req);

  if (!uid) {
    return res.status(401).json({ error: 'Missing user context' });
  }

  try {
    const library = await movieRepository.getUserLibrary(uid);
    return res.json(library);
  } catch (error) {
    return handleError(res, error, 'Failed to load user library');
  }
};

exports.recommendations = async (req, res) => {
  const uid = requestUid(req);

  if (!uid) {
    return res.status(401).json({ error: 'Missing user context' });
  }

  try {
    const recommendations = await movieRepository.getRecommendations(uid);
    const detailed = await hydrateRecommendations(recommendations, {
      limit: 30,
      batchSize: 4,
      logger: console,
    });
    const diversified = diversifyRecommendations(detailed, 30);

    return res.json({
      results: diversified,
    });
  } catch (error) {
    return handleError(res, error, 'Failed to load recommendations');
  }
};

exports.diversifyRecommendations = diversifyRecommendations;
exports.normalizeRecommendationTitle = normalizeRecommendationTitle;
exports.hydrateRecommendations = hydrateRecommendations;
