const { tmdbGet } = require('./tmdbClient');
const movieRepository = require('./movieRepository');
const neo4jService = require('./neo4jService');

function parseTmdbId(value) {
  const tmdbId = Number.parseInt(value, 10);
  if (!Number.isInteger(tmdbId) || tmdbId <= 0) return null;
  return tmdbId;
}

function parseTmdbIds(value) {
  if (!Array.isArray(value)) return [];
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
  if (!Array.isArray(value)) return [];
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
  if (!path) return '';
  return `https://image.tmdb.org/t/p/${size}${path}`;
}

function toFiniteNumber(value, fallback = 0) {
  const numeric = value == null ? fallback : Number(value);
  return Number.isFinite(numeric) ? numeric : fallback;
}

function buildDailySuggestionSettings() {
  const limitEnabled = String(process.env.ENABLE_DAILY_SWIPE_LIMIT || 'false').toLowerCase() === 'true';
  const configuredLimit = Number.parseInt(process.env.DAILY_SWIPE_LIMIT || '999999', 10);
  return {
    limitEnabled,
    configuredLimit: Number.isInteger(configuredLimit) && configuredLimit > 0 ? configuredLimit : 999999,
  };
}

function recommendationDebugEnabled() {
  return String(process.env.ENABLE_RECOMMENDATION_DEBUG || 'true').toLowerCase() !== 'false';
}

function dedupeByTmdbId(items) {
  const seen = new Set();
  const deduped = [];
  for (const item of Array.isArray(items) ? items : []) {
    if (!item || item.tmdbId == null) continue;
    const key = String(item.tmdbId);
    if (seen.has(key)) continue;
    seen.add(key);
    deduped.push(item);
  }
  return deduped;
}

function buildForYouReason(candidate, fallbackUsed) {
  if (candidate?.reason) {
    return candidate.reason;
  }
  if (fallbackUsed || candidate?.source === 'fallback') {
    return 'Fallback ranking based on onboarding preferences and reliable catalog quality.';
  }
  if (toFiniteNumber(candidate?.negativePenalty) > 0) {
    return 'Strong collaborative match with a light penalty from repeated negative genre feedback.';
  }
  return 'Strong collaborative match with your likes, favorites, and watchlist signals.';
}

function buildDailyPersonalizedReason(candidate, homeIds) {
  if (homeIds.has(candidate.tmdbId)) {
    return 'High-confidence personalized pick kept in the learning queue for fast taste confirmation.';
  }
  return 'Personalized candidate sampled slightly deeper in the ranked pool to learn taste without mirroring Home exactly.';
}

function toPositiveInteger(value, fallback = 30, max = 100) {
  const numeric = Number.parseInt(String(value), 10);
  if (!Number.isInteger(numeric) || numeric <= 0) {
    return fallback;
  }
  return Math.min(numeric, max);
}

function attachRecommendationMetadata(movie, recommendation) {
  return {
    ...movie,
    recommendation: {
      source: recommendation.source || 'fallback',
      similarUsers: recommendation.similarUsers ?? 0,
      avgSimilarRating: recommendation.avgSimilarRating ?? null,
      collaborativeScore: toFiniteNumber(recommendation.collaborativeScore),
      genreScore: toFiniteNumber(recommendation.genreScore),
      popularityScore: toFiniteNumber(recommendation.popularityScore),
      negativePenalty: toFiniteNumber(recommendation.negativePenalty),
      explorationBonus: toFiniteNumber(recommendation.explorationBonus),
      finalScore: toFiniteNumber(recommendation.finalScore),
      reason: recommendation.reason || '',
    },
  };
}

function summarizeRecommendationSources(results) {
  const counts = new Map();
  for (const movie of Array.isArray(results) ? results : []) {
    const source = movie?.recommendation?.source || 'unknown';
    counts.set(source, (counts.get(source) || 0) + 1);
  }

  return Array.from(counts.entries())
    .map(([source, count]) => ({ source, count }))
    .sort((left, right) => right.count - left.count || left.source.localeCompare(right.source));
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
  
  // Ora che idratiamo prima, i generi ci sono sempre!
  const hasGenreData = ordered.some(
    (candidate) => Array.isArray(candidate.genreIds) && candidate.genreIds.length > 0
  );
  const genreCap = hasGenreData ? Math.max(2, Math.ceil(limit / 8)) : null;

  function isDuplicate(candidate) {
    const tmdbKey = candidate.tmdbId == null ? null : String(candidate.tmdbId);
    const titleKey = normalizeRecommendationTitle(candidate.title || candidate.originalTitle);
    if (tmdbKey && seenTmdbIds.has(tmdbKey)) return true;
    return titleKey.length > 0 && seenTitles.has(titleKey);
  }

  function markSeen(candidate) {
    if (candidate.tmdbId != null) seenTmdbIds.add(String(candidate.tmdbId));
    const titleKey = normalizeRecommendationTitle(candidate.title || candidate.originalTitle);
    if (titleKey.length > 0) seenTitles.add(titleKey);
  }

  function candidateGenreIds(candidate) {
    if (!Array.isArray(candidate.genreIds)) return [];
    return [...new Set(candidate.genreIds.filter((id) => Number.isInteger(id)))];
  }

  function canTake(candidate) {
    if (!hasGenreData || !genreCap) return true;
    const genres = candidateGenreIds(candidate);
    if (genres.length === 0) return true;
    const lowestPressure = Math.min(...genres.map((genreId) => genreCounts.get(genreId) || 0));
    return lowestPressure < genreCap;
  }

  function applyGenreCounts(candidate) {
    for (const genreId of candidateGenreIds(candidate)) {
      genreCounts.set(genreId, (genreCounts.get(genreId) || 0) + 1);
    }
  }

  for (const candidate of ordered) {
    if (selected.length >= limit) break;
    if (isDuplicate(candidate)) continue;
    if (!canTake(candidate)) {
      skipped.push(candidate);
      continue;
    }
    markSeen(candidate);
    applyGenreCounts(candidate);
    selected.push(candidate);
  }

  // Fallback: se siamo stati troppo selettivi, peschiamo dagli scartati
  if (selected.length < limit && skipped.length > 0) {
    for (const candidate of skipped) {
      if (selected.length >= limit) break;
      if (isDuplicate(candidate)) continue;
      markSeen(candidate);
      selected.push(candidate);
    }
  }

  return selected.slice(0, limit);
}

async function hydrateRecommendations(
  recommendations,
  {
    limit = 30,
    batchSize = 6, // Aumentato per velocizzare le chiamate a TMDB
    tmdbFetch = tmdbGet,
    findMovieByTmdbId = movieRepository.findMovieByTmdbId,
    logger = console,
  } = {}
) {
  const hydratedEntries = await hydrateRecommendationEntries(recommendations, {
    limit,
    batchSize,
    tmdbFetch,
    findMovieByTmdbId,
    logger,
  });
  return hydratedEntries.map((entry) => entry.movie);
}

async function hydrateRecommendationEntries(
  recommendations,
  {
    limit = 30,
    batchSize = 6,
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
            return null;
          }

          const neoMovie = await findMovieByTmdbId(entry.tmdbId);
          const movie = {
            ...mapTmdbMovie(tmdbMovie, {
              ...(neoMovie || {}),
              movieLensAvgRating: entry.globalAvg ?? neoMovie?.movieLensAvgRating ?? null,
              movieLensRatingCount: entry.ratingCount ?? neoMovie?.movieLensRatingCount ?? 0,
            }),
            recommendation: {
              source: entry.source || 'personalized',
              similarUsers: entry.similarUsers,
              avgSimilarRating: entry.avgSimilarRating,
              collaborativeScore: toFiniteNumber(entry.collaborativeScore),
              genreScore: toFiniteNumber(entry.genreScore),
              popularityScore: toFiniteNumber(entry.popularityScore),
              negativePenalty: toFiniteNumber(entry.negativePenalty),
              explorationBonus: toFiniteNumber(entry.explorationBonus),
              finalScore: toFiniteNumber(entry.finalScore),
              reason: entry.reason || '',
            },
          };
          return { raw: entry, movie };
        } catch (error) {
          if (typeof logger?.warn === 'function') {
            logger.warn(`Skipping stale TMDB recommendation ${entry.tmdbId}: ${error instanceof Error ? error.message : error}`);
          }
          return null;
        }
      })
    );

    for (const item of batchHydrated) {
      if (item) hydrated.push(item);
      if (hydrated.length >= limit) break;
    }
  }

  return hydrated.slice(0, limit);
}

function extractTrailerUrl(videos) {
  const entries = Array.isArray(videos?.results) ? videos.results : [];
  const trailer = entries.find((entry) => entry.site === 'YouTube' && (entry.type === 'Trailer' || entry.type === 'Teaser'));
  return trailer?.key ? `https://www.youtube.com/watch?v=${trailer.key}` : '';
}

function extractDirector(credits) {
  const crew = Array.isArray(credits?.crew) ? credits.crew : [];
  const director = crew.find((member) => member.job === 'Director');
  return director?.name || '';
}

function mapMovieLens(neoMovie, fallbackAvg, fallbackCount) {
  const avgRating = neoMovie?.movieLensAvgRating ?? fallbackAvg ?? null;
  const ratingCount = neoMovie?.movieLensRatingCount ?? fallbackCount ?? 0;
  return { avgRating, ratingCount };
}

function mapTmdbMovie(tmdbMovie, neoMovie = null) {
  return {
    tmdbId: tmdbMovie.id,
    title: tmdbMovie.title || tmdbMovie.name || '',
    originalTitle: tmdbMovie.original_title || tmdbMovie.original_name || tmdbMovie.title || '',
    overview: tmdbMovie.overview || '',
    posterPath: tmdbMovie.poster_path || null,
    backdropPath: tmdbMovie.backdrop_path || null,
    posterUrl: imageUrl(tmdbMovie.poster_path, 'w780'),
    backdropUrl: imageUrl(tmdbMovie.backdrop_path, 'w780'),
    releaseDate: tmdbMovie.release_date || tmdbMovie.first_air_date || '',
    voteAverage: tmdbMovie.vote_average == null ? null : Number(Number(tmdbMovie.vote_average).toFixed(1)),
    genreIds: Array.isArray(tmdbMovie.genre_ids)
      ? tmdbMovie.genre_ids.filter((id) => Number.isInteger(id))
      : Array.isArray(tmdbMovie.genres)
        ? tmdbMovie.genres.map((genre) => genre?.id).filter((id) => Number.isInteger(id))
        : [],
    genres: Array.isArray(tmdbMovie.genres)
      ? tmdbMovie.genres.map((genre) => genre?.name).filter((name) => typeof name === 'string' && name.trim() !== '')
      : [],
    movieLens: mapMovieLens(neoMovie),
  };
}

function mapTmdbMovieDetails(tmdbMovie, neoMovie = null) {
  const base = mapTmdbMovie(tmdbMovie, neoMovie);
  return {
    ...base,
    director: extractDirector(tmdbMovie.credits),
    runtime: Number.isInteger(tmdbMovie.runtime) ? tmdbMovie.runtime : null,
    genres: Array.isArray(tmdbMovie.genres)
      ? tmdbMovie.genres.map((g) => g?.name).filter((n) => typeof n === 'string' && n.trim() !== '')
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
      ? tmdbMovie.videos.results.filter((e) => e.site === 'YouTube').map((e) => ({
          id: e.id,
          key: e.key,
          name: e.name || '',
          type: e.type || '',
          url: e.key ? `https://www.youtube.com/watch?v=${e.key}` : '',
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
    director: movie.director || '',
    voteAverage: movie.voteAverage,
    genres: Array.isArray(movie.genres) ? movie.genres : [],
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
    voteAverage: tmdbMovie.vote_average == null ? null : Number(Number(tmdbMovie.vote_average).toFixed(1)),
    director: extractDirector(tmdbMovie.credits),
  };
}

async function enrichMovies(tmdbMovies) {
  const tmdbIds = tmdbMovies.map((movie) => movie?.id).filter((id) => Number.isInteger(id));
  const neoMovies = await movieRepository.findMoviesByTmdbIds(tmdbIds);
  const byTmdbId = new Map(neoMovies.map((movie) => [movie.tmdbId, movie]));
  return tmdbMovies.map((movie) => mapTmdbMovie(movie, byTmdbId.get(movie.id) || null));
}

async function loadPopularFallbackMovies({
  limit = 30,
  pages = [1],
  excludeTmdbIds = [],
  source = 'popular-fallback',
  reason = 'No ranked recommendation candidates were available, so popular unseen titles were used as a safe fallback.',
  explorationBonus = 0,
} = {}) {
  const safeLimit = toPositiveInteger(limit, 30, 80);
  const seenTmdbIds = new Set(
    excludeTmdbIds
      .filter((tmdbId) => Number.isInteger(tmdbId))
      .map((tmdbId) => String(tmdbId))
  );
  const results = [];

  for (const page of pages) {
    if (results.length >= safeLimit) {
      break;
    }

    const response = await tmdbGet('/movie/popular', { language: 'en-US', page });
    const movies = await enrichMovies(Array.isArray(response.results) ? response.results : []);

    for (const movie of movies) {
      if (!movie || !Number.isInteger(movie.tmdbId)) {
        continue;
      }

      const key = String(movie.tmdbId);
      if (seenTmdbIds.has(key)) {
        continue;
      }

      seenTmdbIds.add(key);
      results.push(
        attachRecommendationMetadata(movie, {
          source,
          popularityScore: toFiniteNumber(movie.voteAverage),
          explorationBonus,
          finalScore: toFiniteNumber(movie.voteAverage) + explorationBonus,
          reason,
        })
      );

      if (results.length >= safeLimit) {
        break;
      }
    }
  }

  return results.slice(0, safeLimit);
}

async function fetchInteractionMovie(tmdbId) {
  const tmdbMovie = await tmdbGet(`/movie/${tmdbId}`, { append_to_response: 'credits' });
  return mapInteractionMovie(tmdbMovie);
}

function requestUid(req) {
  return req.user?.uid || req.user?.sub;
}

function buildTasteLearningPersonalizedPool(candidates) {
  const ordered = Array.isArray(candidates) ? candidates.filter(Boolean) : [];
  const deeperSlice = ordered.slice(Math.min(3, ordered.length));
  return deeperSlice.length > 0 ? deeperSlice.concat(ordered.slice(0, Math.min(3, ordered.length))) : ordered;
}

function buildDailySuggestionQueue(personalizedCandidates, exploratoryCandidates, { limit = 30, personalizedRatio = 0.65 } = {}) {
  const homeTopIds = new Set(
    (Array.isArray(personalizedCandidates) ? personalizedCandidates : [])
      .slice(0, limit)
      .map((candidate) => candidate?.tmdbId)
      .filter((tmdbId) => tmdbId != null)
  );
  const personalizedPool = buildTasteLearningPersonalizedPool(personalizedCandidates);
  const exploratoryPool = Array.isArray(exploratoryCandidates) ? exploratoryCandidates.filter(Boolean) : [];
  const seen = new Set();
  const queue = [];
  const personalizedTarget = Math.max(0, Math.round(limit * personalizedRatio));
  const exploratoryTarget = Math.max(0, limit - personalizedTarget);

  function takeFrom(pool, target, source, reasonBuilder) {
    let taken = 0;
    for (const candidate of pool) {
      if (queue.length >= limit || taken >= target || !candidate || candidate.tmdbId == null) {
        continue;
      }
      const key = String(candidate.tmdbId);
      if (seen.has(key)) {
        continue;
      }
      seen.add(key);
      taken += 1;
      queue.push({
        ...candidate,
        source,
        reason: reasonBuilder(candidate, homeTopIds),
        appearsInHomeRecommendations: homeTopIds.has(candidate.tmdbId),
      });
    }
  }

  // Home optimizes for best ranking; the daily queue samples slightly deeper plus exploration.
  takeFrom(
    personalizedPool,
    personalizedTarget,
    'daily-personalized',
    (candidate, ids) => buildDailyPersonalizedReason(candidate, ids)
  );
  takeFrom(
    exploratoryPool,
    exploratoryTarget,
    'exploratory',
    (candidate) => candidate.reason || 'Exploratory pick chosen to learn from less-proven genres and popular unseen titles.'
  );

  if (queue.length < limit) {
    takeFrom(
      personalizedPool,
      limit - queue.length,
      'daily-personalized',
      (candidate, ids) => buildDailyPersonalizedReason(candidate, ids)
    );
  }
  if (queue.length < limit) {
    takeFrom(
      exploratoryPool,
      limit - queue.length,
      'exploratory',
      (candidate) => candidate.reason || 'Exploratory pick chosen to learn from less-proven genres and popular unseen titles.'
    );
  }

  return queue;
}

async function loadForYouRecommendations(uid, { limit = 30 } = {}) {
  const safeLimit = toPositiveInteger(limit, 30, 80);
  const recommendationData = await movieRepository.getRecommendationCandidates(uid);
  const enrichedCandidates = recommendationData.candidates.map((candidate) => ({
    ...candidate,
    reason: buildForYouReason(candidate, recommendationData.fallbackUsed),
  }));

  if (enrichedCandidates.length === 0) {
    return {
      results: await loadPopularFallbackMovies({
        limit: safeLimit,
        pages: [1, 2],
        source: 'popular-fallback',
        reason: 'No personalized graph candidates were available yet, so popular movies were used as a temporary fallback.',
      }),
      meta: {
        fallbackUsed: true,
        fallbackReason: 'No recommendation candidates were returned from Neo4j.',
        fallbackStrategy: 'TMDB popular fallback.',
      },
      candidates: [],
    };
  }

  const hydratedPool = await hydrateRecommendations(enrichedCandidates, {
    limit: Math.max(safeLimit * 2, 60),
    batchSize: 6,
    logger: console,
  });

  const rankedResults = diversifyRecommendations(hydratedPool, safeLimit);
  if (rankedResults.length === 0) {
    return {
      results: await loadPopularFallbackMovies({
        limit: safeLimit,
        pages: [1, 2],
        source: 'popular-fallback',
        reason: 'The ranked recommendation pool could not be hydrated, so popular movies were used as a temporary fallback.',
      }),
      meta: {
        fallbackUsed: true,
        fallbackReason: 'Recommendation hydration returned no usable movies.',
        fallbackStrategy: 'TMDB popular fallback after hydration failure.',
      },
      candidates: enrichedCandidates,
    };
  }

  return {
    results: rankedResults,
    meta: {
      fallbackUsed: recommendationData.fallbackUsed,
      fallbackReason: recommendationData.fallbackReason,
      fallbackStrategy: recommendationData.fallbackStrategy,
    },
    candidates: enrichedCandidates,
  };
}

async function loadDailySuggestions(uid, { limit = 30 } = {}) {
  const safeLimit = toPositiveInteger(limit, 60, 200);
  const forYouData = await movieRepository.getRecommendationCandidates(uid);
  const personalizedCandidates = forYouData.candidates.map((candidate) => ({
    ...candidate,
    reason: buildForYouReason(candidate, forYouData.fallbackUsed),
  }));
  const exploratoryCandidates = await movieRepository.getExploratoryCandidates(uid, {
    excludedTmdbIds: personalizedCandidates.slice(0, 8).map((candidate) => candidate.tmdbId).filter((tmdbId) => tmdbId != null),
    limit: Math.max(Math.round(safeLimit * 0.6), 18),
  });
  const queueCandidates = buildDailySuggestionQueue(personalizedCandidates, exploratoryCandidates, { limit: safeLimit });

  if (queueCandidates.length === 0) {
    const fallbackResults = await loadPopularFallbackMovies({
      limit: safeLimit,
      pages: [2, 3, 1],
      excludeTmdbIds: personalizedCandidates.map((candidate) => candidate.tmdbId).filter((tmdbId) => tmdbId != null),
      source: 'exploratory-fallback',
      explorationBonus: 8,
      reason: 'No learning candidates were available yet, so a broader popular queue was generated to collect fresh taste signals.',
    });

    return {
      results: fallbackResults,
      meta: {
        fallbackUsed: true,
        fallbackReason: 'No daily learning candidates were returned from Neo4j.',
        fallbackStrategy: 'TMDB popular exploration fallback.',
        personalizedCandidateCount: 0,
        exploratoryCandidateCount: fallbackResults.length,
        personalizedRatio: 0.0,
      },
      homeCandidates: personalizedCandidates,
      queueCandidates: fallbackResults,
      exploratoryCandidates,
    };
  }

  const hydrated = await hydrateRecommendations(queueCandidates, {
    limit: safeLimit,
    batchSize: 6,
    logger: console,
  });

  const finalResults = diversifyRecommendations(hydrated, safeLimit);
  if (finalResults.length === 0) {
    const fallbackResults = await loadPopularFallbackMovies({
      limit: safeLimit,
      pages: [2, 3, 1],
      excludeTmdbIds: personalizedCandidates.map((candidate) => candidate.tmdbId).filter((tmdbId) => tmdbId != null),
      source: 'exploratory-fallback',
      explorationBonus: 8,
      reason: 'The learning queue could not be hydrated, so a broader popular queue was generated to keep swipe feedback flowing.',
    });

    return {
      results: fallbackResults,
      meta: {
        fallbackUsed: true,
        fallbackReason: 'Daily suggestion hydration returned no usable movies.',
        fallbackStrategy: 'TMDB popular exploration fallback.',
        personalizedCandidateCount: 0,
        exploratoryCandidateCount: fallbackResults.length,
        personalizedRatio: 0.0,
      },
      homeCandidates: personalizedCandidates,
      queueCandidates: fallbackResults,
      exploratoryCandidates,
    };
  }

  return {
    results: finalResults,
    meta: {
      fallbackUsed: forYouData.fallbackUsed,
      fallbackReason: forYouData.fallbackReason,
      fallbackStrategy: forYouData.fallbackStrategy,
      personalizedCandidateCount: queueCandidates.filter((candidate) => candidate.source === 'daily-personalized').length,
      exploratoryCandidateCount: queueCandidates.filter((candidate) => candidate.source === 'exploratory').length,
      personalizedRatio: 0.65,
    },
    homeCandidates: personalizedCandidates,
    queueCandidates,
    exploratoryCandidates,
  };
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
    return res.json({ results: movies });
  } catch (error) {
    return handleError(res, error, 'Failed to load popular movies');
  }
};

exports.search = async (req, res) => {
  const query = typeof req.query.query === 'string' ? req.query.query.trim() : '';
  if (!query) return res.status(400).json({ error: 'Missing query parameter' });

  try {
    const response = await tmdbGet('/search/movie', { query, language: 'en-US', include_adult: false, page: 1 });
    const results = Array.isArray(response.results) ? response.results : [];
    const movies = await enrichMovies(results);
    return res.json({ results: movies });
  } catch (error) {
    return handleError(res, error, 'Failed to search movies');
  }
};

exports.details = async (req, res) => {
  const tmdbId = parseTmdbId(req.params.tmdbId);
  if (!tmdbId) return res.status(400).json({ error: 'Invalid tmdbId' });

  try {
    const [tmdbMovie, neoMovie] = await Promise.all([
      tmdbGet(`/movie/${tmdbId}`, { language: 'en-US', append_to_response: 'credits,videos,images', include_image_language: 'en,null' }),
      movieRepository.findMovieByTmdbId(tmdbId),
    ]);
    return res.json({ movie: mapTmdbMovieDetails(tmdbMovie, neoMovie) });
  } catch (error) {
    return handleError(res, error, 'Failed to load movie details');
  }
};

exports.like = async (req, res) => {
  const uid = requestUid(req);
  const tmdbId = parseTmdbId(req.params.tmdbId);
  if (!uid || !tmdbId) return res.status(400).json({ error: 'Invalid request' });

  try {
    const movie = await fetchInteractionMovie(tmdbId);
    const liked = await movieRepository.likeMovie(uid, movie);
    if (!liked) return res.status(404).json({ error: 'App user not found' });
    const neoMovie = await movieRepository.findMovieByTmdbId(tmdbId);
    return res.json({ ok: true, movie: mapRepositoryMovieToResponse(neoMovie || movie) });
  } catch (error) {
    return handleError(res, error, 'Failed to like movie');
  }
};

exports.dislike = async (req, res) => {
  const uid = requestUid(req);
  const tmdbId = parseTmdbId(req.params.tmdbId);
  if (!uid || !tmdbId) return res.status(400).json({ error: 'Invalid request' });

  try {
    const movie = await fetchInteractionMovie(tmdbId);
    const disliked = await movieRepository.dislikeMovie(uid, movie);
    if (!disliked) return res.status(404).json({ error: 'App user not found' });
    const neoMovie = await movieRepository.findMovieByTmdbId(tmdbId);
    return res.json({ ok: true, movie: mapRepositoryMovieToResponse(neoMovie || movie) });
  } catch (error) {
    return handleError(res, error, 'Failed to dislike movie');
  }
};

exports.watchlist = async (req, res) => {
  const uid = requestUid(req);
  const tmdbId = parseTmdbId(req.params.tmdbId);
  if (!uid || !tmdbId) return res.status(400).json({ error: 'Invalid request' });

  try {
    const movie = await fetchInteractionMovie(tmdbId);
    const watchlisted = await movieRepository.watchlistMovie(uid, movie);
    if (!watchlisted) return res.status(404).json({ error: 'App user not found' });
    const neoMovie = await movieRepository.findMovieByTmdbId(tmdbId);
    return res.json({ ok: true, movie: mapRepositoryMovieToResponse(neoMovie || movie) });
  } catch (error) {
    return handleError(res, error, 'Failed to add movie to watchlist');
  }
};

exports.markSeen = async (req, res) => {
  const uid = requestUid(req);
  const tmdbId = parseTmdbId(req.params.tmdbId);
  if (!uid || !tmdbId) return res.status(400).json({ error: 'Invalid request' });

  try {
    const movie = await fetchInteractionMovie(tmdbId);
    const seen = await movieRepository.markMovieAsSeen(uid, movie);
    if (!seen) return res.status(404).json({ error: 'App user not found' });
    const neoMovie = await movieRepository.findMovieByTmdbId(tmdbId);
    return res.json({ ok: true, movie: mapRepositoryMovieToResponse(neoMovie || movie) });
  } catch (error) {
    return handleError(res, error, 'Failed to mark movie as seen');
  }
};

exports.updateOnboarding = async (req, res) => {
  const uid = requestUid(req);
  if (!uid) return res.status(401).json({ error: 'Missing user context' });

  const completed = req.body.completed === true;
  const selectedFavoriteTmdbIds = parseTmdbIds(req.body.selectedFavoriteTmdbIds);
  const favoriteGenres = parseStringList(req.body.favoriteGenres);
  const shouldPersistFavorites = Object.prototype.hasOwnProperty.call(req.body, 'selectedFavoriteTmdbIds');
  const shouldPersistGenres = Object.prototype.hasOwnProperty.call(req.body, 'favoriteGenres');

  try {
    if (shouldPersistGenres) {
      const saved = await movieRepository.savePreferredGenres(uid, favoriteGenres);
      if (!saved) return res.status(404).json({ error: 'App user not found' });
    }

    if (shouldPersistFavorites) {
      const selectedFavoriteMovies = await Promise.all(selectedFavoriteTmdbIds.map((tmdbId) => fetchInteractionMovie(tmdbId)));
      const saved = await movieRepository.saveSelectedFavorites(uid, selectedFavoriteMovies, 4.0);
      if (!saved) return res.status(404).json({ error: 'App user not found' });
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

    if (result.records.length === 0) return res.status(404).json({ error: 'User not found' });
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
  if (isNaN(tmdbId)) return res.status(400).json({ error: 'Valid tmdbId parameter is required' });

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
  if (isNaN(tmdbId)) return res.status(400).json({ error: 'Valid tmdbId parameter is required' });

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
  if (!uid || !tmdbId) return res.status(400).json({ error: 'Invalid request' });

  try {
    await movieRepository.removeFromWatchlist(uid, tmdbId);
    return res.status(204).send();
  } catch (error) {
    return handleError(res, error, 'Failed to remove movie from watchlist');
  }
};

exports.removeSeen = async (req, res) => {
  const uid = requestUid(req);
  const tmdbId = parseTmdbId(req.params.tmdbId);
  if (!uid || !tmdbId) return res.status(400).json({ error: 'Invalid request' });

  try {
    await movieRepository.removeSeen(uid, tmdbId);
    return res.status(204).send();
  } catch (error) {
    return handleError(res, error, 'Failed to remove seen movie');
  }
};

exports.library = async (req, res) => {
  const uid = requestUid(req);
  if (!uid) return res.status(401).json({ error: 'Missing user context' });

  try {
    const library = await movieRepository.getUserLibrary(uid);
    return res.json(library);
  } catch (error) {
    return handleError(res, error, 'Failed to load user library');
  }
};

exports.recommendationsForYou = async (req, res) => {
  const uid = requestUid(req);

  if (!uid) {
    return res.status(401).json({ error: 'Missing user context' });
  }

  try {
    const response = await loadForYouRecommendations(uid, { limit: 30 });
    return res.json({ results: response.results, meta: response.meta });
  } catch (error) {
    return handleError(res, error, 'Failed to load recommended movies');
  }
};

exports.dailySuggestions = async (req, res) => {
  const uid = requestUid(req);

  if (!uid) {
    return res.status(401).json({ error: 'Missing user context' });
  }

  try {
    const settings = buildDailySuggestionSettings();
    const requestedLimit = toPositiveInteger(req.query.limit, 60, 200);
    const queueLimit = settings.limitEnabled
      ? toPositiveInteger(Math.min(settings.configuredLimit, requestedLimit), 60, 200)
      : requestedLimit;
    const response = await loadDailySuggestions(uid, { limit: queueLimit });
    return res.json({
      results: response.results,
      meta: {
        ...response.meta,
        swipeLimitEnabled: settings.limitEnabled,
        swipeLimit: settings.configuredLimit,
      },
    });
  } catch (error) {
    return handleError(res, error, 'Failed to load daily suggestions');
  }
};

exports.recommendationDebugStats = async (req, res) => {
  const uid = requestUid(req);
  if (!uid) {
    return res.status(401).json({ error: 'Missing user context' });
  }
  if (!recommendationDebugEnabled()) {
    return res.status(404).json({ error: 'Recommendation debug is disabled.' });
  }

  try {
    const [
      userProfile,
      positiveGenres,
      negativeGenres,
      positiveMovies,
      negativeMovies,
      candidatePoolStats,
      forYouData,
      dailySuggestionData,
    ] = await Promise.all([
      movieRepository.getRecommendationUserProfile(uid),
      movieRepository.getTopPositiveGenreSignals(uid),
      movieRepository.getTopNegativeGenreSignals(uid),
      movieRepository.getTopPositiveMovies(uid),
      movieRepository.getTopNegativeMovies(uid),
      movieRepository.getCandidatePoolStats(uid),
      loadForYouRecommendations(uid, { limit: 12 }),
      loadDailySuggestions(uid, { limit: 20 }),
    ]);

    const positiveGenreNames = new Set(positiveGenres.map((entry) => entry.name));
    const negativeGenreNames = new Set(negativeGenres.map((entry) => entry.name));
    const forYouSourceBreakdown = summarizeRecommendationSources(forYouData.results);
    const dailySourceBreakdown = summarizeRecommendationSources(dailySuggestionData.results);
    const forYouSample = forYouData.results.slice(0, 8).map((movie) => {
      const recommendation = movie.recommendation || {};
      const movieGenres = Array.isArray(movie.genres) ? movie.genres : [];
      const derivedGenreScore =
        movieGenres.filter((genre) => positiveGenreNames.has(genre)).length * 10 -
        movieGenres.filter((genre) => negativeGenreNames.has(genre)).length * 5;
      return {
        tmdbId: movie.tmdbId,
        title: movie.title,
        finalScore: toFiniteNumber(recommendation.finalScore),
        genreScore: derivedGenreScore,
        popularityScore: toFiniteNumber(recommendation.popularityScore),
        collaborativeScore: toFiniteNumber(recommendation.collaborativeScore),
        negativePenalty: toFiniteNumber(recommendation.negativePenalty),
        explorationBonus: toFiniteNumber(recommendation.explorationBonus),
        reason: recommendation.reason || buildForYouReason(recommendation, forYouData.meta.fallbackUsed),
      };
    });

    const forYouIds = new Set(forYouData.results.map((movie) => movie.tmdbId).filter((tmdbId) => tmdbId != null));
    const dailyBreakdown = dailySuggestionData.results.slice(0, 12).map((movie) => {
      const recommendation = movie.recommendation || {};
      return {
        tmdbId: movie.tmdbId,
        title: movie.title,
        source: recommendation.source || 'daily-personalized',
        appearedInHomeRecommendations: forYouIds.has(movie.tmdbId),
        reason: recommendation.reason || '',
      };
    });

    return res.json({
      userProfileSignals: userProfile,
      recommendationSignals: {
        topPositiveGenres: positiveGenres,
        topNegativeGenres: negativeGenres,
        influentialPositiveMovies: positiveMovies,
        penalizedNegativeMovies: negativeMovies,
        usesCollaborativeFiltering: true,
        usesMovieLensData: true,
        usesNeo4j: true,
        usesTmdbHydration: true,
        responseMode: forYouData.meta.fallbackUsed ? 'fallback' : 'personalized',
      },
      forYouFeedStats: {
        resultCount: forYouData.results.length,
        fallbackUsed: forYouData.meta.fallbackUsed,
        fallbackReason: forYouData.meta.fallbackReason,
        fallbackStrategy: forYouData.meta.fallbackStrategy,
        sourceBreakdown: forYouSourceBreakdown,
      },
      candidatePoolStats,
      scoringStats: {
        sampleRecommendations: forYouSample,
      },
      dailySuggestionsStats: {
        personalizedCandidateCount: dailySuggestionData.meta.personalizedCandidateCount,
        exploratoryCandidateCount: dailySuggestionData.meta.exploratoryCandidateCount,
        personalizedPercentage: Math.round(dailySuggestionData.meta.personalizedRatio * 100),
        exploratoryPercentage: Math.round((1 - dailySuggestionData.meta.personalizedRatio) * 100),
        fallbackUsed: dailySuggestionData.meta.fallbackUsed,
        fallbackReason: dailySuggestionData.meta.fallbackReason,
        fallbackStrategy: dailySuggestionData.meta.fallbackStrategy,
        sourceBreakdown: dailySourceBreakdown,
        sampleQueue: dailyBreakdown,
      },
      fallbackStats: {
        used: forYouData.meta.fallbackUsed,
        reason: forYouData.meta.fallbackReason,
        strategy: forYouData.meta.fallbackStrategy,
        candidateCount: forYouData.candidates.length,
      },
      debugConfig: buildDailySuggestionSettings(),
    });
  } catch (error) {
    return handleError(res, error, 'Failed to load recommendation debug stats');
  }
};

exports.recommendations = exports.recommendationsForYou;

exports.diversifyRecommendations = diversifyRecommendations;
exports.normalizeRecommendationTitle = normalizeRecommendationTitle;
exports.hydrateRecommendations = hydrateRecommendations;
exports.hydrateRecommendationEntries = hydrateRecommendationEntries;
