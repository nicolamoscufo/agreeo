const { tmdbGet } = require('./tmdbClient');
const movieRepository = require('./movieRepository');

function parseTmdbId(value) {
  const tmdbId = Number.parseInt(value, 10);

  if (!Number.isInteger(tmdbId) || tmdbId <= 0) {
    return null;
  }

  return tmdbId;
}

function imageUrl(path, size) {
  if (!path) {
    return '';
  }

  return `https://image.tmdb.org/t/p/${size}${path}`;
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
    const detailed = await Promise.all(
      recommendations.map(async (entry) => {
        try {
          const tmdbMovie = await tmdbGet(`/movie/${entry.tmdbId}`);
          const neoMovie = await movieRepository.findMovieByTmdbId(entry.tmdbId);
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
          // TMDB often returns 404 for old MovieLens IDs (deleted or moved to TV shows)
          if (error.message && error.message.includes('TMDB error 404')) {
            return null;
          }
          console.warn(`Skipping TMDB recommendation ${entry.tmdbId}:`, error.message || error);
          return null;
        }
      })
    );

    return res.json({
      results: detailed.filter(Boolean),
    });
  } catch (error) {
    return handleError(res, error, 'Failed to load recommendations');
  }
};
