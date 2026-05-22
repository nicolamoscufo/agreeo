const TMDB_GENRE_IDS_BY_NAME = {
  action: 28,
  adventure: 12,
  animation: 16,
  comedy: 35,
  crime: 80,
  documentary: 99,
  drama: 18,
  family: 10751,
  fantasy: 14,
  history: 36,
  horror: 27,
  music: 10402,
  mystery: 9648,
  romance: 10749,
  science_fiction: 878,
  'science fiction': 878,
  'sci-fi': 878,
  tv_movie: 10770,
  'tv movie': 10770,
  thriller: 53,
  war: 10752,
  western: 37,
  'slice of life': 18,
};

const TMDB_GENRE_NAMES_BY_ID = Object.fromEntries(
  Object.entries(TMDB_GENRE_IDS_BY_NAME).map(([name, id]) => [id, name])
);
TMDB_GENRE_NAMES_BY_ID[18] = 'drama';

function mapGenreNameToId(name) {
  if (!name) return null;
  const clean = String(name).trim().toLowerCase();
  return TMDB_GENRE_IDS_BY_NAME[clean] || null;
}

module.exports = {
  TMDB_GENRE_IDS_BY_NAME,
  TMDB_GENRE_NAMES_BY_ID,
  mapGenreNameToId,
};
