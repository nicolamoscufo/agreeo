const TMDB_BASE_URL = 'https://api.themoviedb.org/3';

async function tmdbGet(path, query = {}) {
  const token = process.env.TMDB_ACCESS_TOKEN;

  if (!token) {
    throw new Error('Missing TMDB_ACCESS_TOKEN');
  }

  const url = new URL(`${TMDB_BASE_URL}${path}`);

  for (const [key, value] of Object.entries(query)) {
    if (value !== undefined && value !== null && value !== '') {
      url.searchParams.set(key, String(value));
    }
  }

  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${token}`,
      accept: 'application/json',
    },
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`TMDB error ${response.status}: ${body}`);
  }

  return response.json();
}

module.exports = {
  tmdbGet,
};
