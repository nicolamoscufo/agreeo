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
    return { records: [record({ friendId: 'friend-1', accepterName: 'User', senderName: 'Friend' })] };
  };

  const accepted = await socialRepository.acceptFriendRequest('user-1', 'request-1');

  assert.deepEqual(accepted, { friendId: 'friend-1', accepterName: 'User', senderName: 'Friend' });
  assert.equal(calls.length, 1);
  assert.match(calls[0].query, /MERGE \(me\)-\[a:FRIEND\]-\(from\)/);
  assert.doesNotMatch(calls[0].query, /MERGE \(from\)-\[b:FRIEND\]->\(me\)/);
  assert.deepEqual(calls[0].params, { uid: 'user-1', requestId: 'request-1' });
});

test('sendFriendRequest accepts an incoming reciprocal request', async (t) => {
  const calls = [];
  const originalRun = neo4jService.run;

  t.after(() => {
    neo4jService.run = originalRun;
  });

  neo4jService.run = async (query, params) => {
    calls.push({ query, params });
    if (calls.length === 1) {
      return { records: [record({ requestId: 'request-2' })] };
    }
    if (calls.length === 2) {
      return {
        records: [
          record({
            friend: {
              id: 'friend-2',
              name: 'Friend Two',
              avatarUrl: '',
              watchedCount: 0,
              reviewsCount: 0,
              privacySettings: {},
            },
          }),
        ],
      };
    }
    return { records: [] };
  };

  const result = await socialRepository.sendFriendRequest('user-1', 'friend-2');

  assert.equal(result.accepted, true);
  assert.equal(result.requestId, 'request-2');
  assert.equal(result.social.friends.length, 1);
  assert.match(calls[0].query, /MATCH \(to\)-\[r:SENT_FRIEND_REQUEST \{status: 'pending'\}\]->\(from\)/);
  assert.doesNotMatch(
    calls.map((call) => call.query).join('\n'),
    /MERGE \(from\)-\[r:SENT_FRIEND_REQUEST\]->\(to\)/
  );
});

test('removeFriend deletes only the FRIEND relationship', async (t) => {
  const calls = [];
  const originalRun = neo4jService.run;

  t.after(() => {
    neo4jService.run = originalRun;
  });

  neo4jService.run = async (query, params) => {
    calls.push({ query, params });
    return { records: [record({ friendId: 'friend-3' })] };
  };

  const removed = await socialRepository.removeFriend('user-1', 'friend-3');

  assert.equal(removed, true);
  assert.match(calls[0].query, /MATCH \(me\)-\[rel:FRIEND\]-\(friend\)/);
  assert.match(calls[0].query, /DELETE rel/);
  assert.deepEqual(calls[0].params, { uid: 'user-1', friendId: 'friend-3' });
});

test('blockFriend deletes friendship and creates BLOCKED relationship', async (t) => {
  const calls = [];
  const originalRun = neo4jService.run;

  t.after(() => {
    neo4jService.run = originalRun;
  });

  neo4jService.run = async (query, params) => {
    calls.push({ query, params });
    return { records: [record({ friendId: 'friend-4' })] };
  };

  const blocked = await socialRepository.blockFriend('user-1', 'friend-4');

  assert.equal(blocked, true);
  assert.match(calls[0].query, /DELETE friendRel/);
  assert.match(calls[0].query, /MERGE \(me\)-\[blocked:BLOCKED\]->\(target\)/);
  assert.deepEqual(calls[0].params, { uid: 'user-1', friendId: 'friend-4' });
});

test('cancelFriendRequest deletes only the pending outgoing request', async (t) => {
  const calls = [];
  const originalRun = neo4jService.run;

  t.after(() => {
    neo4jService.run = originalRun;
  });

  neo4jService.run = async (query, params) => {
    calls.push({ query, params });
    return { records: [record({ targetUserId: 'friend-5' })] };
  };

  const cancelled = await socialRepository.cancelFriendRequest('user-1', 'friend-5');

  assert.equal(cancelled, true);
  assert.match(
    calls[0].query,
    /MATCH \(me:AppUser \{uid: \$uid\}\)-\[r:SENT_FRIEND_REQUEST \{status: 'pending'\}\]->\(target:AppUser \{uid: \$targetUserId\}\)/
  );
  assert.match(calls[0].query, /DELETE r/);
  assert.deepEqual(calls[0].params, { uid: 'user-1', targetUserId: 'friend-5' });
});

test('cancelFriendRequest reports false when no pending request exists', async (t) => {
  const originalRun = neo4jService.run;

  t.after(() => {
    neo4jService.run = originalRun;
  });

  neo4jService.run = async () => ({ records: [] });

  assert.equal(await socialRepository.cancelFriendRequest('user-1', 'friend-5'), false);
});

test('getBlockedUsers lists BLOCKED targets and unblockFriend deletes the relationship', async (t) => {
  const calls = [];
  const originalRun = neo4jService.run;

  t.after(() => {
    neo4jService.run = originalRun;
  });

  neo4jService.run = async (query, params) => {
    calls.push({ query, params });
    if (calls.length === 1) {
      return {
        records: [
          record({
            user: {
              id: 'friend-6',
              name: 'Blocked Person',
              avatarUrl: '',
              bio: '',
              blockedAt: '2026-06-12T00:00:00Z',
            },
          }),
        ],
      };
    }
    return { records: [record({ targetUserId: 'friend-6' })] };
  };

  const blocked = await socialRepository.getBlockedUsers('user-1');
  assert.equal(blocked.length, 1);
  assert.equal(blocked[0].id, 'friend-6');
  assert.match(calls[0].query, /MATCH \(me:AppUser \{uid: \$uid\}\)-\[blocked:BLOCKED\]->\(target:AppUser\)/);

  const unblocked = await socialRepository.unblockFriend('user-1', 'friend-6');
  assert.equal(unblocked, true);
  assert.match(calls[1].query, /DELETE blocked/);
  assert.deepEqual(calls[1].params, { uid: 'user-1', targetUserId: 'friend-6' });
});

test('generateShortlist calculates group taste vector and queries candidate movies using vector index', async (t) => {
  const calls = [];
  const originalRun = neo4jService.run;
  const originalExecuteRead = neo4jService.executeRead;

  t.after(() => {
    neo4jService.run = originalRun;
    neo4jService.executeRead = originalExecuteRead;
  });

  // getMovieNight (called without an ambient tx) now runs inside a read
  // transaction; route that tx's run() back through the mocked neo4jService.run.
  neo4jService.executeRead = async (actions) =>
    actions({ run: (query, params) => neo4jService.run(query, params) });

  neo4jService.run = async (query, params) => {
    calls.push({ query, params });
    if (query.includes('MATCH (:AppUser {uid: $uid})-[:PARTICIPATES_IN]->(event:MovieNight')) {
      // 1. getMovieNight event query
      return {
        records: [
          record({
            event: {
              id: 'mn-1',
              name: 'Sci-Fi Vibe Night',
              hostUserId: 'host-1',
              dateTime: null,
              constraints: {
                includedGenres: [],
                excludedGenres: [],
                maxDurationMinutes: 180,
                minimumRating: 7.0,
                language: null,
              },
              inviteLink: '',
              status: 'waiting',
              winnerMovieId: null,
              round: 1,
              createdAt: '2024-01-01',
              updatedAt: '2024-01-01',
            },
          }),
        ],
      };
    } else if (query.includes('MATCH (user:AppUser)-[part:PARTICIPATES_IN]->(:MovieNight')) {
      // loadParticipants
      return {
        records: [
          record({
            participant: {
              userId: 'host-1',
              name: 'Host One',
              avatarUrl: '',
              status: 'joined',
              isHost: true,
            },
          }),
          record({
            participant: {
              userId: 'user-2',
              name: 'User Two',
              avatarUrl: '',
              status: 'joined',
              isHost: false,
            },
          }),
        ],
      };
    } else if (query.includes('MATCH (event:MovieNight {id: $eventId})-[candidate:HAS_CANDIDATE]->(m:Movie)')) {
      // loadShortlist
      return {
        records: [
          record({
            candidate: {
              movie: {
                tmdbId: 501,
                title: 'Interstellar',
                originalTitle: 'Interstellar',
                overview: 'Awesome space movie',
                posterPath: '/path.jpg',
                backdropPath: '/back.jpg',
                posterUrl: 'http://posters/path.jpg',
                backdropUrl: 'http://backdrops/back.jpg',
                releaseDate: '2014-11-07',
                runtime: 169,
                voteAverage: 8.4,
                genres: ['Sci-Fi', 'Adventure'],
                movieLensAvgRating: 4.1,
                movieLensRatingCount: 3000,
              },
              compatibilityScore: 10.0,
              explanationTags: ['High rating'],
              scoreBreakdownJson: '{}',
            },
          }),
        ],
      };
    } else if (query.includes('MATCH (user:AppUser)-[vote:VOTED_IN]->(m:Movie)')) {
      // loadVotes
      return { records: [] };
    } else if (query.includes('MATCH (u:AppUser)\n      WHERE u.uid IN $userIds')) {
      // 2. group taste vector tags query
      return {
        records: [
          record({
            embedding: new Array(384).fill(0.2),
            relType: 'LIKED',
            frequency: 1,
          }),
        ],
      };
    } else if (query.includes('queryNodes')) {
      // 3. vector search query for candidates
      return {
        records: [
          record({
            movie: {
              tmdbId: 501,
              title: 'Interstellar',
              originalTitle: 'Interstellar',
              overview: 'Awesome space movie',
              posterPath: '/path.jpg',
              backdropPath: '/back.jpg',
              posterUrl: 'http://posters/path.jpg',
              backdropUrl: 'http://backdrops/back.jpg',
              releaseDate: '2014-11-07',
              runtime: 169,
              voteAverage: 8.4,
              genres: ['Sci-Fi', 'Adventure'],
              movieLensAvgRating: 4.1,
              movieLensRatingCount: 3000,
            },
          }),
        ],
      };
    } else if (query.includes('MATCH (u:AppUser)\n    WHERE u.uid IN $userIds\n    MATCH (m:Movie)')) {
      // 4. loadUserMovieStates
      return {
        records: [
          record({
            userId: 'host-1',
            tmdbId: 501,
            liked: true,
            disliked: false,
            inWatchlist: false,
            watched: true,
            rating: 5,
          }),
          record({
            userId: 'user-2',
            tmdbId: 501,
            liked: false,
            disliked: false,
            inWatchlist: true,
            watched: false,
            rating: null,
          }),
        ],
      };
    } else if (query.includes('UNWIND $candidates AS candidate')) {
      // save candidates shortlist relation
      return { records: [] };
    } else if (query.includes('OPTIONAL MATCH (:AppUser)-[vote:VOTED_IN]->(:Movie)\n    WHERE vote.eventId = $eventId')) {
      // clearVotesOnly
      return { records: [] };
    }
    return { records: [] };
  };

  const shortlist = await socialRepository.generateShortlist('host-1', 'mn-1');

  // Verify the shortlist matches our mock movie
  assert.equal(shortlist.shortlist.length, 1);
  assert.equal(shortlist.shortlist[0].movie.tmdbId, 501);
  assert.equal(shortlist.shortlist[0].movie.title, 'Interstellar');

  // Verify group taste vector calculations and index query
  const vectorQueryCall = calls.find((c) => c.query.includes('queryNodes'));
  assert.ok(vectorQueryCall);
  const computedGroupTasteVector = vectorQueryCall.params.groupTasteVector;
  assert.equal(computedGroupTasteVector.length, 384);
  // Weight is LIKED (3.0) * freq (1) = 3.0, embedding component is 0.2, so the
  // weighted sum is 0.6. The vector is intentionally NOT magnitude-normalized:
  // the index uses cosine similarity, which is invariant to positive scaling.
  assert.ok(Math.abs(computedGroupTasteVector[0] - 0.6) < 0.0001);
});
