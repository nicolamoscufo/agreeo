const assert = require('node:assert/strict');
const test = require('node:test');

const neo4jService = require('./neo4jService');
const socialRepository = require('./socialRepository');

function record(values) {
  return {
    get(key) {
      return values[key];
    },
  };
}

function movie(tmdbId, title, overrides = {}) {
  return {
    tmdbId,
    title,
    genres: ['Drama'],
    voteAverage: 7,
    releaseDate: '2024-01-01',
    ...overrides,
  };
}

function candidate(tmdbId, title, score) {
  return {
    movie: movie(tmdbId, title),
    compatibilityScore: score,
    explanationTags: [],
    scoreBreakdown: {
      watchlistSaves: 0,
      likes: 0,
      dislikes: 0,
      watched: 0,
      positiveRatings: 0,
      includedGenreMatches: 0,
      groupBonus: 0,
      groupPenalty: 0,
      total: score,
    },
  };
}

test('buildShortlist ranks group watchlist and like signals first', () => {
  const shortlist = socialRepository.buildShortlist({
    constraints: socialRepository.normalizeConstraints({}),
    participants: [{ userId: 'u1' }, { userId: 'u2' }],
    movies: [
      movie(1, 'Plain', { voteAverage: 8 }),
      movie(2, 'Saved'),
    ],
    states: {
      u1: {
        2: { inWatchlist: true, preference: 'liked' },
      },
      u2: {
        2: { inWatchlist: true },
      },
    },
    limit: 2,
  });

  assert.equal(shortlist[0].movie.tmdbId, 2);
  assert.equal(shortlist[0].scoreBreakdown.watchlistSaves, 2);
});

test('hasEveryoneVoted requires each joined participant for each candidate', () => {
  const event = {
    participants: [
      { userId: 'u1', status: 'joined' },
      { userId: 'u2', status: 'joined' },
      { userId: 'u3', status: 'pending' },
    ],
    shortlist: [candidate(1, 'A', 1), candidate(2, 'B', 1)],
    votes: [
      { userId: 'u1', movieId: 'tmdb-1' },
      { userId: 'u2', movieId: 'tmdb-1' },
      { userId: 'u1', movieId: 'tmdb-2' },
      { userId: 'u2', movieId: 'tmdb-2' },
    ],
  };

  assert.equal(socialRepository.hasEveryoneVoted(event), true);
  assert.equal(
    socialRepository.hasEveryoneVoted({
      ...event,
      votes: event.votes.slice(0, 3),
    }),
    false
  );
});

test('selectWinner combines vote score with shortlist compatibility', () => {
  const winner = socialRepository.selectWinner(
    [candidate(1, 'A', 10), candidate(2, 'B', 8)],
    [
      { movieId: 'tmdb-1', vote: 'neutral' },
      { movieId: 'tmdb-1', vote: 'neutral' },
      { movieId: 'tmdb-2', vote: 'like' },
      { movieId: 'tmdb-2', vote: 'like' },
    ]
  );

  assert.equal(winner.movie.tmdbId, 2);
});

test('acceptFriendRequest creates one undirected friendship relationship', async (t) => {
  const calls = [];
  const originalRun = neo4jService.run;

  t.after(() => {
    neo4jService.run = originalRun;
  });

  neo4jService.run = async (query, params) => {
    calls.push({ query, params });
    return { records: [record({ friendId: 'friend-1' })] };
  };

  const accepted = await socialRepository.acceptFriendRequest('user-1', 'request-1');

  assert.equal(accepted, true);
  assert.equal(calls.length, 1);
  assert.match(calls[0].query, /MERGE \(me\)-\[a:FRIEND\]-\(from\)/);
  assert.doesNotMatch(calls[0].query, /MERGE \(from\)-\[b:FRIEND\]->\(me\)/);
  assert.deepEqual(calls[0].params, { uid: 'user-1', requestId: 'request-1' });
});
