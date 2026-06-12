const { randomUUID } = require('crypto');
const neo4jService = require('./neo4jService');
const { tmdbGet } = require('./tmdbClient');

function toNativeNumber(value) {
  if (value == null) return value;
  if (typeof value === 'number') return value;
  if (typeof value.toNumber === 'function') return value.toNumber();
  return Number(value);
}

function toFiniteNumber(value, fallback = 0) {
  const numeric = value == null ? fallback : Number(value);
  return Number.isFinite(numeric) ? numeric : fallback;
}

function toPositiveInteger(value, fallback = 100, max = 500) {
  const numeric = Number.parseInt(String(value), 10);
  if (!Number.isInteger(numeric) || numeric <= 0) return fallback;
  return Math.min(numeric, max);
}

function native(value) {
  if (value == null) return value;
  if (typeof value.toNumber === 'function') return value.toNumber();
  if (Array.isArray(value)) return value.map(native);
  if (typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, native(item)]));
  }
  return value;
}

function cleanString(value) {
  return value == null ? '' : String(value).trim();
}

function normalizeSearchText(value) {
  return cleanString(value)
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

function searchTokens(value) {
  const normalized = normalizeSearchText(value);
  return normalized ? normalized.split(/\s+/).filter(Boolean) : [];
}

// Diacritic + punctuation folding applied inside Cypher (which has no NFD /
// regex-replace) so the DB-side searchText matches the JS-normalized tokens.
// Each entry is [from, to]; input is already lower-cased before folding.
const CYPHER_ACCENT_MAP = [
  ['à', 'a'], ['á', 'a'], ['â', 'a'], ['ã', 'a'], ['ä', 'a'], ['å', 'a'],
  ['è', 'e'], ['é', 'e'], ['ê', 'e'], ['ë', 'e'],
  ['ì', 'i'], ['í', 'i'], ['î', 'i'], ['ï', 'i'],
  ['ò', 'o'], ['ó', 'o'], ['ô', 'o'], ['õ', 'o'], ['ö', 'o'], ['ø', 'o'],
  ['ù', 'u'], ['ú', 'u'], ['û', 'u'], ['ü', 'u'],
  ['ç', 'c'], ['ñ', 'n'], ['ý', 'y'], ['ÿ', 'y'], ['ß', 'ss'],
  ['.', ' '], ['-', ' '], ['_', ' '], ["'", ' '], ['`', ' '],
];

function cleanStringList(value) {
  if (!Array.isArray(value)) return [];
  const seen = new Set();
  const items = [];
  for (const item of value) {
    const text = cleanString(item);
    if (text && !seen.has(text)) {
      seen.add(text);
      items.push(text);
    }
  }
  return items;
}

function normalizeConstraints(raw = {}) {
  const maxDuration = Number.parseInt(String(raw.maxDurationMinutes ?? ''), 10);
  const minimumRating = Number.parseFloat(String(raw.minimumRating ?? ''));
  const language = cleanString(raw.language);
  return {
    includedGenres: cleanStringList(raw.includedGenres),
    excludedGenres: cleanStringList(raw.excludedGenres),
    maxDurationMinutes: Number.isInteger(maxDuration) && maxDuration > 0 ? maxDuration : null,
    minimumRating: Number.isFinite(minimumRating) && minimumRating > 0 ? minimumRating : null,
    language: language || null,
  };
}

function randomId(prefix) {
  const id = typeof randomUUID === 'function'
    ? randomUUID()
    : `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;
  return `${prefix}_${id}`;
}

function defaultPrivacy(user = {}) {
  return {
    canShowWatched: user.canShowWatched !== false,
    canShowReviews: user.canShowReviews !== false,
    canShowWatchlist: user.canShowWatchlist === true,
  };
}

function normalizeFriend(raw) {
  const friend = native(raw) || {};
  return {
    id: friend.id || friend.uid || '',
    name: friend.name || friend.displayName || friend.email || 'Agreeo user',
    avatarUrl: friend.avatarUrl || friend.photoUrl || '',
    watchedCount: toNativeNumber(friend.watchedCount) || 0,
    reviewsCount: toNativeNumber(friend.reviewsCount) || 0,
    privacySettings: friend.privacySettings || defaultPrivacy(friend),
    isFriend: friend.isFriend === true,
    pending: friend.pending === true,
    bio: friend.bio || '',
  };
}

function normalizeMovie(raw) {
  const movie = native(raw) || {};
  const tmdbId = toNativeNumber(movie.tmdbId);
  return {
    tmdbId,
    title: movie.title || '',
    originalTitle: movie.originalTitle || movie.title || '',
    overview: movie.overview || '',
    posterPath: movie.posterPath || null,
    backdropPath: movie.backdropPath || null,
    posterUrl: (movie.posterPath && (!movie.posterUrl || !movie.posterUrl.startsWith('http')))
      ? `https://image.tmdb.org/t/p/w780${movie.posterPath}`
      : (movie.posterUrl || ''),
    backdropUrl: (movie.backdropPath && (!movie.backdropUrl || !movie.backdropUrl.startsWith('http')))
      ? `https://image.tmdb.org/t/p/w1280${movie.backdropPath}`
      : (movie.backdropUrl || ''),
    releaseDate: movie.releaseDate || '',
    runtime: movie.runtime == null ? 0 : toNativeNumber(movie.runtime),
    voteAverage: movie.voteAverage == null ? null : Number(movie.voteAverage),
    genres: Array.isArray(movie.genres) ? movie.genres.filter(Boolean) : [],
    movieLens: {
      avgRating: movie.movieLensAvgRating == null ? null : Number(movie.movieLensAvgRating),
      ratingCount: movie.movieLensRatingCount == null ? 0 : toNativeNumber(movie.movieLensRatingCount),
    },
    tmdbHydrated: movie.tmdbHydrated === true,
  };
}

function movieMapCypher(alias = 'm') {
  return `{
    tmdbId: ${alias}.tmdbId,
    title: coalesce(${alias}.title, ''),
    originalTitle: coalesce(${alias}.originalTitle, ${alias}.title, ''),
    overview: coalesce(${alias}.overview, ''),
    posterPath: ${alias}.posterPath,
    backdropPath: ${alias}.backdropPath,
    posterUrl: coalesce(${alias}.posterUrl, ''),
    backdropUrl: coalesce(${alias}.backdropUrl, ''),
    releaseDate: coalesce(${alias}.releaseDate, ''),
    runtime: coalesce(${alias}.runtime, 0),
    voteAverage: coalesce(${alias}.voteAverage, ${alias}.movieLensAvgRating * 2.0, 0.0),
    genres: coalesce(${alias}.genres, []),
    movieLensAvgRating: ${alias}.movieLensAvgRating,
    movieLensRatingCount: coalesce(${alias}.movieLensRatingCount, 0),
    tmdbHydrated: coalesce(${alias}.tmdbHydrated, false)
  }`;
}

async function getFriends(uid) {
  const friendsResult = await neo4jService.run(
    `
    MATCH (me:AppUser {uid: $uid})-[:FRIEND]-(friend:AppUser)
    WHERE NOT (me)-[:BLOCKED]->(friend) AND NOT (friend)-[:BLOCKED]->(me)
    WITH DISTINCT friend
    OPTIONAL MATCH (friend)-[:ALREADY_SEEN]->(watched:Movie)
    OPTIONAL MATCH (friend)-[:RATED_APP]->(reviewed:Movie)
    WITH friend, count(DISTINCT watched) AS watchedCount, count(DISTINCT reviewed) AS reviewsCount
    RETURN {
      id: friend.uid,
      name: coalesce(friend.displayName, friend.email, 'Agreeo user'),
      avatarUrl: coalesce(friend.avatarUrl, ''),
      bio: coalesce(friend.bio, ''),
      watchedCount: watchedCount,
      reviewsCount: reviewsCount,
      privacySettings: {
        canShowWatched: coalesce(friend.canShowWatched, true),
        canShowReviews: coalesce(friend.canShowReviews, true),
        canShowWatchlist: coalesce(friend.canShowWatchlist, false)
      }
    } AS friend
    ORDER BY toLower(coalesce(friend.displayName, friend.email, '')) ASC
    `,
    { uid }
  );

  const requestsResult = await neo4jService.run(
    `
    MATCH (me:AppUser {uid: $uid})
    MATCH (from:AppUser)-[r:SENT_FRIEND_REQUEST {status: 'pending'}]->(me)
    OPTIONAL MATCH (from)-[:ALREADY_SEEN]->(watched:Movie)
    OPTIONAL MATCH (from)-[:RATED_APP]->(reviewed:Movie)
    WITH r, me, from, count(DISTINCT watched) AS watchedCount, count(DISTINCT reviewed) AS reviewsCount
    RETURN {
      id: r.requestId,
      status: coalesce(r.status, 'pending'),
      createdAt: toString(r.createdAt),
      toUserId: me.uid,
      fromUser: {
        id: from.uid,
        name: coalesce(from.displayName, from.email, 'Agreeo user'),
        avatarUrl: coalesce(from.avatarUrl, ''),
        bio: coalesce(from.bio, ''),
        watchedCount: watchedCount,
        reviewsCount: reviewsCount,
        privacySettings: {
          canShowWatched: coalesce(from.canShowWatched, true),
          canShowReviews: coalesce(from.canShowReviews, true),
          canShowWatchlist: coalesce(from.canShowWatchlist, false)
        }
      }
    } AS request
    ORDER BY r.createdAt DESC
    `,
    { uid }
  );

  return {
    friends: friendsResult.records.map((record) => normalizeFriend(record.get('friend'))),
    incomingRequests: requestsResult.records.map((record) => native(record.get('request'))),
  };
}

async function searchFriends(uid, query) {
  const tokens = searchTokens(query);
  const result = await neo4jService.run(
    `
    MATCH (me:AppUser {uid: $uid})
    MATCH (candidate:AppUser)
    WITH me, candidate, toLower(coalesce(candidate.displayName, candidate.email, '')) AS rawSearchText
    WITH me, candidate, reduce(s = rawSearchText, pair IN $accentMap | replace(s, pair[0], pair[1])) AS searchText
    WHERE candidate.uid <> me.uid
      AND NOT (me)-[:BLOCKED]->(candidate)
      AND NOT (candidate)-[:BLOCKED]->(me)
      AND (size($tokens) = 0 OR all(token IN $tokens WHERE any(word IN split(searchText, ' ') WHERE word STARTS WITH token)))
    OPTIONAL MATCH (me)-[friendRel:FRIEND]-(candidate)
    OPTIONAL MATCH (me)-[pending:SENT_FRIEND_REQUEST {status: 'pending'}]->(candidate)
    OPTIONAL MATCH (candidate)-[incoming:SENT_FRIEND_REQUEST {status: 'pending'}]->(me)
    OPTIONAL MATCH (candidate)-[:ALREADY_SEEN]->(watched:Movie)
    OPTIONAL MATCH (candidate)-[:RATED_APP]->(reviewed:Movie)
    WITH candidate, searchText, count(DISTINCT friendRel) AS friendCount, count(DISTINCT pending) AS pendingCount, count(DISTINCT incoming) AS incomingCount, head(collect(DISTINCT incoming.requestId)) AS incomingRequestId, count(DISTINCT watched) AS watchedCount, count(DISTINCT reviewed) AS reviewsCount
    RETURN {
      id: candidate.uid,
      name: coalesce(candidate.displayName, candidate.email, 'Agreeo user'),
      avatarUrl: coalesce(candidate.avatarUrl, ''),
      bio: coalesce(candidate.bio, ''),
      watchedCount: watchedCount,
      reviewsCount: reviewsCount,
      isFriend: friendCount > 0,
      pending: pendingCount > 0,
      incomingPending: incomingCount > 0,
      incomingRequestId: incomingRequestId,
      privacySettings: {
        canShowWatched: coalesce(candidate.canShowWatched, true),
        canShowReviews: coalesce(candidate.canShowReviews, true),
        canShowWatchlist: coalesce(candidate.canShowWatchlist, false)
      }
    } AS friend
    ORDER BY
      CASE
        WHEN size($tokens) = 0 THEN 0
        WHEN searchText = $normalized THEN 0
        WHEN searchText STARTS WITH $normalized THEN 1
        WHEN any(word IN split(searchText, ' ') WHERE word STARTS WITH $firstToken) THEN 2
        ELSE 3
      END ASC,
      toLower(coalesce(candidate.displayName, candidate.email, '')) ASC
    LIMIT 25
    `,
    { uid, normalized: tokens.join(' '), firstToken: tokens[0] || '', tokens, accentMap: CYPHER_ACCENT_MAP }
  );

  return result.records.map((record) => normalizeFriend(record.get('friend')));
}

async function sendFriendRequest(uid, targetUserId) {
  const reciprocalResult = await neo4jService.run(
    `
    MATCH (from:AppUser {uid: $uid})
    MATCH (to:AppUser {uid: $targetUserId})
    WHERE from.uid <> to.uid
      AND NOT (from)-[:FRIEND]-(to)
      AND NOT (from)-[:BLOCKED]->(to)
      AND NOT (to)-[:BLOCKED]->(from)
    MATCH (to)-[r:SENT_FRIEND_REQUEST {status: 'pending'}]->(from)
    SET r.status = 'accepted', r.updatedAt = datetime()
    MERGE (from)-[a:FRIEND]-(to)
    ON CREATE SET a.createdAt = datetime()
    RETURN r.requestId AS requestId
    LIMIT 1
    `,
    { uid, targetUserId }
  );

  if (reciprocalResult.records.length > 0) {
    return {
      accepted: true,
      requestId: reciprocalResult.records[0].get('requestId'),
      social: await getFriends(uid),
    };
  }

  const requestId = randomId('fr');
  const result = await neo4jService.run(
    `
    MATCH (from:AppUser {uid: $uid})
    MATCH (to:AppUser {uid: $targetUserId})
    WHERE from.uid <> to.uid
      AND NOT (from)-[:FRIEND]-(to)
      AND NOT (from)-[:BLOCKED]->(to)
      AND NOT (to)-[:BLOCKED]->(from)
    MERGE (from)-[r:SENT_FRIEND_REQUEST]->(to)
    ON CREATE SET r.requestId = $requestId, r.createdAt = datetime()
    SET r.status = 'pending', r.updatedAt = datetime()
    RETURN {
      id: r.requestId,
      status: r.status,
      createdAt: toString(r.createdAt),
      toUserId: to.uid,
      fromUser: {
        id: from.uid,
        name: coalesce(from.displayName, from.email, 'Agreeo user'),
        avatarUrl: coalesce(from.avatarUrl, ''),
        watchedCount: 0,
        reviewsCount: 0,
        privacySettings: {
          canShowWatched: coalesce(from.canShowWatched, true),
          canShowReviews: coalesce(from.canShowReviews, true),
          canShowWatchlist: coalesce(from.canShowWatchlist, false)
        }
      }
    } AS request
    LIMIT 1
    `,
    { uid, targetUserId, requestId }
  );

  return result.records.length === 0
    ? null
    : { accepted: false, request: native(result.records[0].get('request')) };
}

async function acceptFriendRequest(uid, requestId) {
  const result = await neo4jService.run(
    `
    MATCH (me:AppUser {uid: $uid})
    MATCH (from:AppUser)-[r:SENT_FRIEND_REQUEST {requestId: $requestId, status: 'pending'}]->(me)
    SET r.status = 'accepted', r.updatedAt = datetime()
    MERGE (me)-[a:FRIEND]-(from)
    ON CREATE SET a.createdAt = datetime()
    RETURN from.uid AS friendId, coalesce(me.displayName, me.email, 'Someone') AS accepterName, coalesce(from.displayName, from.email, 'Someone') AS senderName
    LIMIT 1
    `,
    { uid, requestId }
  );

  return result.records.length > 0 ? {
    friendId: result.records[0].get('friendId'),
    accepterName: result.records[0].get('accepterName'),
    senderName: result.records[0].get('senderName')
  } : null;
}

async function declineFriendRequest(uid, requestId) {
  const result = await neo4jService.run(
    `
    MATCH (me:AppUser {uid: $uid})<-[r:SENT_FRIEND_REQUEST {requestId: $requestId, status: 'pending'}]-(from:AppUser)
    SET r.status = 'declined', r.updatedAt = datetime()
    RETURN from.uid AS friendId, coalesce(me.displayName, me.email, 'Someone') AS declinerName
    LIMIT 1
    `,
    { uid, requestId }
  );

  return result.records.length > 0 ? {
    friendId: result.records[0].get('friendId'),
    declinerName: result.records[0].get('declinerName')
  } : null;
}


async function removeFriend(uid, friendId) {
  const result = await neo4jService.run(
    `
    MATCH (me:AppUser {uid: $uid})
    MATCH (friend:AppUser {uid: $friendId})
    MATCH (me)-[rel:FRIEND]-(friend)
    DELETE rel
    RETURN friend.uid AS friendId
    LIMIT 1
    `,
    { uid, friendId }
  );

  return result.records.length > 0;
}

async function blockFriend(uid, friendId) {
  const result = await neo4jService.run(
    `
    MATCH (me:AppUser {uid: $uid})
    MATCH (target:AppUser {uid: $friendId})
    WHERE me.uid <> target.uid
    OPTIONAL MATCH (me)-[friendRel:FRIEND]-(target)
    DELETE friendRel
    WITH me, target
    OPTIONAL MATCH (me)-[outgoing:SENT_FRIEND_REQUEST {status: 'pending'}]->(target)
    SET outgoing.status = 'declined', outgoing.updatedAt = datetime()
    WITH me, target
    OPTIONAL MATCH (target)-[incoming:SENT_FRIEND_REQUEST {status: 'pending'}]->(me)
    SET incoming.status = 'declined', incoming.updatedAt = datetime()
    WITH me, target
    MERGE (me)-[blocked:BLOCKED]->(target)
    ON CREATE SET blocked.createdAt = datetime()
    SET blocked.updatedAt = datetime()
    RETURN target.uid AS friendId
    LIMIT 1
    `,
    { uid, friendId }
  );

  return result.records.length > 0;
}

async function cancelFriendRequest(uid, targetUserId) {
  // Delete (rather than mark cancelled) so a later MERGE in sendFriendRequest
  // recreates a clean pending request.
  const result = await neo4jService.run(
    `
    MATCH (me:AppUser {uid: $uid})-[r:SENT_FRIEND_REQUEST {status: 'pending'}]->(target:AppUser {uid: $targetUserId})
    DELETE r
    RETURN target.uid AS targetUserId
    LIMIT 1
    `,
    { uid, targetUserId }
  );

  return result.records.length > 0;
}

async function getBlockedUsers(uid) {
  const result = await neo4jService.run(
    `
    MATCH (me:AppUser {uid: $uid})-[blocked:BLOCKED]->(target:AppUser)
    RETURN {
      id: target.uid,
      name: coalesce(target.displayName, target.email, 'Agreeo user'),
      avatarUrl: coalesce(target.avatarUrl, ''),
      bio: coalesce(target.bio, ''),
      blockedAt: toString(blocked.createdAt)
    } AS user
    ORDER BY toLower(coalesce(target.displayName, target.email, '')) ASC
    `,
    { uid }
  );

  return result.records.map((record) => native(record.get('user')));
}

async function unblockFriend(uid, targetUserId) {
  const result = await neo4jService.run(
    `
    MATCH (me:AppUser {uid: $uid})-[blocked:BLOCKED]->(target:AppUser {uid: $targetUserId})
    DELETE blocked
    RETURN target.uid AS targetUserId
    LIMIT 1
    `,
    { uid, targetUserId }
  );

  return result.records.length > 0;
}

async function getFriendProfile(uid, friendId) {
  const friendResult = await neo4jService.run(
    `
    MATCH (me:AppUser {uid: $uid})-[:FRIEND]-(friend:AppUser {uid: $friendId})
    WHERE NOT (me)-[:BLOCKED]->(friend) AND NOT (friend)-[:BLOCKED]->(me)
    OPTIONAL MATCH (friend)-[:ALREADY_SEEN]->(watchedCountMovie:Movie)
    OPTIONAL MATCH (friend)-[:RATED_APP]->(reviewedCountMovie:Movie)
    WITH friend, count(DISTINCT watchedCountMovie) AS watchedCount, count(DISTINCT reviewedCountMovie) AS reviewsCount
    RETURN {
      id: friend.uid,
      name: coalesce(friend.displayName, friend.email, 'Agreeo user'),
      avatarUrl: coalesce(friend.avatarUrl, ''),
      bio: coalesce(friend.bio, ''),
      watchedCount: watchedCount,
      reviewsCount: reviewsCount,
      privacySettings: {
        canShowWatched: coalesce(friend.canShowWatched, true),
        canShowReviews: coalesce(friend.canShowReviews, true),
        canShowWatchlist: coalesce(friend.canShowWatchlist, false)
      }
    } AS friend
    LIMIT 1
    `,
    { uid, friendId }
  );

  if (friendResult.records.length === 0) return null;
  const friend = normalizeFriend(friendResult.records[0].get('friend'));
  const privacy = friend.privacySettings;

  const watched = privacy.canShowWatched
    ? await loadFriendMovies(friendId, 'ALREADY_SEEN')
    : [];
  const watchlist = privacy.canShowWatchlist
    ? await loadFriendMovies(friendId, 'WATCHLISTED')
    : [];
  const reviews = privacy.canShowReviews
    ? await loadFriendReviews(friendId)
    : [];

  return { friend, watchedMovies: watched, reviews, watchlist };
}

async function loadFriendMovies(friendId, relationshipType) {
  const allowed = new Set(['ALREADY_SEEN', 'WATCHLISTED']);
  if (!allowed.has(relationshipType)) return [];
  const result = await neo4jService.run(
    `
    MATCH (:AppUser {uid: $friendId})-[r:${relationshipType}]->(m:Movie)
    RETURN ${movieMapCypher('m')} AS movie
    ORDER BY r.createdAt DESC
    LIMIT 20
    `,
    { friendId }
  );
  return result.records.map((record) => normalizeMovie(record.get('movie')));
}

async function loadFriendReviews(friendId) {
  const result = await neo4jService.run(
    `
    MATCH (:AppUser {uid: $friendId})-[r:RATED_APP]->(m:Movie)
    RETURN {
      movie: ${movieMapCypher('m')},
      rating: coalesce(r.rating, 0),
      reviewPreview: coalesce(r.review, ''),
      date: toString(coalesce(r.updatedAt, r.createdAt))
    } AS review
    ORDER BY coalesce(r.updatedAt, r.createdAt) DESC
    LIMIT 20
    `,
    { friendId }
  );
  return result.records.map((record) => {
    const review = native(record.get('review')) || {};
    return { ...review, movie: normalizeMovie(review.movie) };
  });
}

async function createMovieNight(uid, data) {
  const eventId = randomId('mn');
  const constraints = normalizeConstraints(data.constraints);
  const name = cleanString(data.name) || 'Movie Night';
  const dateTime = cleanString(data.dateTime) || null;
  const inviteLink = `agreeo://invite/${eventId}`;
  const invitedFriendIds = cleanStringList(data.invitedFriendIds);

  const createResult = await neo4jService.run(
    `
    MATCH (host:AppUser {uid: $uid})
    CREATE (event:MovieNight {
      id: $eventId,
      name: $name,
      contentType: 'movie',
      dateTime: $dateTime,
      includedGenres: $includedGenres,
      excludedGenres: $excludedGenres,
      maxDurationMinutes: $maxDurationMinutes,
      minimumRating: $minimumRating,
      language: $language,
      inviteLink: $inviteLink,
      status: 'waiting',
      winnerMovieId: null,
      round: 1,
      createdAt: datetime(),
      updatedAt: datetime()
    })
    MERGE (host)-[hosts:HOSTS]->(event)
    ON CREATE SET hosts.createdAt = datetime()
    MERGE (host)-[part:PARTICIPATES_IN]->(event)
    ON CREATE SET part.createdAt = datetime()
    SET part.status = 'joined', part.isHost = true, part.updatedAt = datetime()
    RETURN event.id AS eventId
    `,
    {
      uid,
      eventId,
      name,
      dateTime,
      inviteLink,
      ...constraints,
    }
  );

  if (createResult.records.length === 0) return null;
  if (invitedFriendIds.length > 0) {
    await inviteFriends(uid, eventId, invitedFriendIds);
  }
  return getMovieNight(uid, eventId);
}

async function inviteFriends(uid, eventId, friendIds) {
  const invitedFriendIds = cleanStringList(friendIds);
  if (invitedFriendIds.length === 0) return getMovieNight(uid, eventId);

  await neo4jService.run(
    `
    MATCH (:AppUser {uid: $uid})-[:HOSTS]->(event:MovieNight {id: $eventId})
    UNWIND $friendIds AS friendId
    MATCH (me:AppUser {uid: $uid})
    MATCH (friend:AppUser {uid: friendId})
    WHERE (me)-[:FRIEND]-(friend)
    MERGE (friend)-[part:PARTICIPATES_IN]->(event)
    ON CREATE SET part.createdAt = datetime()
    SET part.status = coalesce(part.status, 'pending'), part.isHost = false, part.updatedAt = datetime()
    `,
    { uid, eventId, friendIds: invitedFriendIds }
  );

  return getMovieNight(uid, eventId);
}

async function joinMovieNight(uid, eventId) {
  const result = await neo4jService.run(
    `
    MATCH (user:AppUser {uid: $uid})
    MATCH (event:MovieNight {id: $eventId})
    WHERE coalesce(event.status, 'waiting') IN ['draft', 'waiting']
    MERGE (user)-[part:PARTICIPATES_IN]->(event)
    ON CREATE SET part.createdAt = datetime(), part.isHost = false
    SET part.status = 'joined',
        part.isHost = coalesce(part.isHost, false),
        part.updatedAt = datetime(),
        event.updatedAt = datetime()
    RETURN event.id AS eventId
    LIMIT 1
    `,
    { uid, eventId }
  );

  if (result.records.length === 0) return null;
  return getMovieNight(uid, eventId);
}

async function leaveMovieNight(uid, eventId) {
  return neo4jService.executeWrite(async (tx) => {
    // 1. Confirm the user participates and capture whether they are the host.
    const partResult = await tx.run(
      `
      MATCH (user:AppUser {uid: $uid})-[part:PARTICIPATES_IN]->(event:MovieNight {id: $eventId})
      RETURN coalesce(part.isHost, false) AS isHost
      LIMIT 1
      `,
      { uid, eventId }
    );
    if (partResult.records.length === 0) return false;
    const wasHost = partResult.records[0].get('isHost') === true;

    // 2. Remove the user's votes, participation and any HOSTS edge.
    await tx.run(
      `
      MATCH (user:AppUser {uid: $uid})
      OPTIONAL MATCH (user)-[vote:VOTED_IN]->(:Movie)
      WHERE vote.eventId = $eventId
      DELETE vote
      WITH user
      MATCH (user)-[part:PARTICIPATES_IN]->(event:MovieNight {id: $eventId})
      OPTIONAL MATCH (user)-[hosts:HOSTS]->(event)
      DELETE part, hosts
      SET event.updatedAt = datetime()
      `,
      { uid, eventId }
    );

    // 3. If the host left, hand hosting over to another participant
    //    (joined first, then earliest joined). If nobody remains, delete the event.
    if (wasHost) {
      const promoted = await tx.run(
        `
        MATCH (event:MovieNight {id: $eventId})<-[part:PARTICIPATES_IN]-(candidate:AppUser)
        WITH event, candidate, part
        ORDER BY CASE WHEN part.status = 'joined' THEN 0 ELSE 1 END ASC,
                 coalesce(part.createdAt, datetime()) ASC
        LIMIT 1
        MERGE (candidate)-[h:HOSTS]->(event)
        ON CREATE SET h.createdAt = datetime()
        SET part.isHost = true, event.updatedAt = datetime()
        RETURN candidate.uid AS newHostId
        `,
        { eventId }
      );

      if (promoted.records.length === 0) {
        await tx.run(
          `
          OPTIONAL MATCH (:AppUser)-[vote:VOTED_IN]->(:Movie)
          WHERE vote.eventId = $eventId
          DELETE vote
          `,
          { eventId }
        );
        await tx.run(
          `
          MATCH (event:MovieNight {id: $eventId})
          DETACH DELETE event
          `,
          { eventId }
        );
      }
    }

    return true;
  });
}

function assembleMovieNightData(event, participants, shortlist, votes) {
  // Enrich shortlist with computed vote scores
  const enrichedShortlist = shortlist.map((candidate) => {
    const movieId = `tmdb-${candidate.movie.tmdbId}`;
    const movieVotes = votes.filter((v) => v.movieId === movieId);
    const voteSc = movieVotes.reduce((sum, v) => sum + voteScore(v.vote), 0);
    return {
      ...candidate,
      voteScore: voteSc,
      finalScore: voteSc,
      likesCount: movieVotes.filter((v) => v.vote === 'like').length,
      dislikesCount: movieVotes.filter((v) => v.vote === 'dislike').length,
    };
  });

  return {
    ...event,
    participants,
    shortlist: enrichedShortlist,
    votes,
    votedUserIds: completedVoterIds(participants, enrichedShortlist, votes)
  };
}

async function listMovieNights(uid) {
  const result = await neo4jService.run(
    `
    MATCH (me:AppUser {uid: $uid})-[:PARTICIPATES_IN]->(event:MovieNight)
    OPTIONAL MATCH (host:AppUser)-[:HOSTS]->(event)
    WITH event, host
    ORDER BY event.updatedAt DESC
    LIMIT 50
    RETURN {
      id: event.id,
      name: event.name,
      hostUserId: host.uid,
      dateTime: event.dateTime,
      constraints: {
        includedGenres: coalesce(event.includedGenres, []),
        excludedGenres: coalesce(event.excludedGenres, []),
        maxDurationMinutes: event.maxDurationMinutes,
        minimumRating: event.minimumRating,
        language: event.language
      },
      inviteLink: coalesce(event.inviteLink, ''),
      status: coalesce(event.status, 'waiting'),
      winnerMovieId: event.winnerMovieId,
      round: coalesce(event.round, 1),
      createdAt: toString(event.createdAt),
      updatedAt: toString(event.updatedAt)
    } AS event,
    [(user:AppUser)-[part:PARTICIPATES_IN]->(event) | {
      userId: user.uid,
      name: coalesce(user.displayName, user.email, 'Agreeo user'),
      avatarUrl: coalesce(user.avatarUrl, ''),
      status: coalesce(part.status, 'pending'),
      isHost: coalesce(part.isHost, false)
    }] AS participants,
    [(event)-[candidate:HAS_CANDIDATE]->(m:Movie) WHERE event.status = 'completed' OR candidate.eliminated IS NULL OR NOT candidate.eliminated | {
      movie: ${movieMapCypher('m')},
      compatibilityScore: coalesce(candidate.compatibilityScore, 0.0),
      explanationTags: coalesce(candidate.explanationTags, []),
      scoreBreakdownJson: coalesce(candidate.scoreBreakdownJson, '{}'),
      eliminated: coalesce(candidate.eliminated, false)
    }] AS shortlist,
    [(vUser:AppUser)-[vote:VOTED_IN]->(vMovie:Movie) WHERE vote.eventId = event.id | {
      eventId: vote.eventId,
      userId: vUser.uid,
      movieId: 'tmdb-' + toString(vMovie.tmdbId),
      vote: vote.vote,
      createdAt: toString(coalesce(vote.updatedAt, vote.createdAt))
    }] AS votes
    `,
    { uid }
  );

  return result.records.map((record) => {
    const event = native(record.get('event'));
    const rawParticipants = native(record.get('participants')) || [];
    const rawShortlist = native(record.get('shortlist')) || [];
    const rawVotes = native(record.get('votes')) || [];

    // Sort participants: isHost DESC, name ASC case-insensitive
    const participants = rawParticipants.sort((left, right) => {
      const leftHost = left.isHost === true ? 1 : 0;
      const rightHost = right.isHost === true ? 1 : 0;
      if (leftHost !== rightHost) {
        return rightHost - leftHost;
      }
      return left.name.toLowerCase().localeCompare(right.name.toLowerCase());
    });

    // Normalize and sort shortlist
    const shortlist = rawShortlist.map((candidate) => normalizeCandidate(candidate))
      .sort((left, right) => {
        if (left.compatibilityScore !== right.compatibilityScore) {
          return right.compatibilityScore - left.compatibilityScore;
        }
        return left.movie.title.localeCompare(right.movie.title);
      });

    // Sort votes
    const votes = rawVotes.sort((left, right) => left.createdAt.localeCompare(right.createdAt));

    return assembleMovieNightData(event, participants, shortlist, votes);
  });
}

async function getMovieNight(uid, eventId, tx = null) {
  // Without an ambient transaction, run all four reads (event + participants +
  // shortlist + votes) inside a single read transaction so the assembled event
  // is a consistent snapshot rather than four independently-timed queries.
  if (!tx) {
    return neo4jService.executeRead((readTx) => getMovieNight(uid, eventId, readTx));
  }

  const run = (q, p) => tx.run(q, p);
  const eventResult = await run(
    `
    MATCH (:AppUser {uid: $uid})-[:PARTICIPATES_IN]->(event:MovieNight {id: $eventId})
    OPTIONAL MATCH (host:AppUser)-[:HOSTS]->(event)
    RETURN {
      id: event.id,
      name: event.name,
      hostUserId: host.uid,
      dateTime: event.dateTime,
      constraints: {
        includedGenres: coalesce(event.includedGenres, []),
        excludedGenres: coalesce(event.excludedGenres, []),
        maxDurationMinutes: event.maxDurationMinutes,
        minimumRating: event.minimumRating,
        language: event.language
      },
      inviteLink: coalesce(event.inviteLink, ''),
      status: coalesce(event.status, 'waiting'),
      winnerMovieId: event.winnerMovieId,
      round: coalesce(event.round, 1),
      createdAt: toString(event.createdAt),
      updatedAt: toString(event.updatedAt)
    } AS event
    LIMIT 1
    `,
    { uid, eventId }
  );

  if (eventResult.records.length === 0) return null;
  const event = native(eventResult.records[0].get('event'));
  const [participants, shortlist, votes] = await Promise.all([
    loadParticipants(eventId, tx),
    loadShortlist(eventId, tx),
    loadVotes(eventId, tx),
  ]);

  return assembleMovieNightData(event, participants, shortlist, votes);
}

function completedVoterIds(participants, shortlist, votes) {
  const joinedIds = participants
    .filter((participant) => participant.status === 'joined')
    .map((participant) => participant.userId);
  if (joinedIds.length === 0 || shortlist.length === 0) return [];
  return joinedIds.filter((userId) => shortlist.every((candidate) => {
    const movieId = `tmdb-${candidate.movie.tmdbId}`;
    return votes.some((vote) => vote.userId === userId && vote.movieId === movieId);
  }));
}

async function loadParticipants(eventId, tx = null) {
  const run = (q, p) => tx ? tx.run(q, p) : neo4jService.run(q, p);
  const result = await run(
    `
    MATCH (user:AppUser)-[part:PARTICIPATES_IN]->(:MovieNight {id: $eventId})
    RETURN {
      userId: user.uid,
      name: coalesce(user.displayName, user.email, 'Agreeo user'),
      avatarUrl: coalesce(user.avatarUrl, ''),
      status: coalesce(part.status, 'pending'),
      isHost: coalesce(part.isHost, false)
    } AS participant
    ORDER BY coalesce(part.isHost, false) DESC, toLower(coalesce(user.displayName, user.email, '')) ASC
    `,
    { eventId }
  );
  return result.records.map((record) => native(record.get('participant')));
}

async function loadShortlist(eventId, tx = null) {
  const run = (q, p) => tx ? tx.run(q, p) : neo4jService.run(q, p);
  const result = await run(
    `
    MATCH (event:MovieNight {id: $eventId})-[candidate:HAS_CANDIDATE]->(m:Movie)
    WHERE event.status = 'completed' OR candidate.eliminated IS NULL OR NOT candidate.eliminated
    RETURN {
      movie: ${movieMapCypher('m')},
      compatibilityScore: coalesce(candidate.compatibilityScore, 0.0),
      explanationTags: coalesce(candidate.explanationTags, []),
      scoreBreakdownJson: coalesce(candidate.scoreBreakdownJson, '{}'),
      eliminated: coalesce(candidate.eliminated, false)
    } AS candidate
    ORDER BY candidate.compatibilityScore DESC, m.title ASC
    `,
    { eventId }
  );
  return result.records.map((record) => normalizeCandidate(record.get('candidate')));
}

function normalizeCandidate(raw) {
  const candidate = native(raw) || {};
  let scoreBreakdown = {};
  try {
    scoreBreakdown = JSON.parse(candidate.scoreBreakdownJson || '{}');
  } catch (_) {
    scoreBreakdown = {};
  }
  return {
    movie: normalizeMovie(candidate.movie),
    compatibilityScore: toFiniteNumber(candidate.compatibilityScore),
    explanationTags: Array.isArray(candidate.explanationTags) ? candidate.explanationTags : [],
    scoreBreakdown,
    eliminated: candidate.eliminated === true,
  };
}

async function loadVotes(eventId, tx = null) {
  const run = (q, p) => tx ? tx.run(q, p) : neo4jService.run(q, p);
  const result = await run(
    `
    MATCH (user:AppUser)-[vote:VOTED_IN]->(m:Movie)
    WHERE vote.eventId = $eventId
    RETURN {
      eventId: vote.eventId,
      userId: user.uid,
      movieId: 'tmdb-' + toString(m.tmdbId),
      vote: vote.vote,
      createdAt: toString(coalesce(vote.updatedAt, vote.createdAt))
    } AS vote
    ORDER BY vote.createdAt ASC
    `,
    { eventId }
  );
  return result.records.map((record) => native(record.get('vote')));
}

async function updateMovieNight(uid, eventId, data) {
  const constraintsProvided = data && Object.prototype.hasOwnProperty.call(data, 'constraints');
  const constraints = constraintsProvided ? normalizeConstraints(data.constraints) : null;
  const status = cleanString(data.status);
  const name = data.name == null ? null : cleanString(data.name);
  const dateTime = data.dateTime === undefined ? undefined : (cleanString(data.dateTime) || null);

  const result = await neo4jService.run(
    `
    MATCH (:AppUser {uid: $uid})-[:HOSTS]->(event:MovieNight {id: $eventId})
    SET event.updatedAt = datetime()
    FOREACH (_ IN CASE WHEN $name IS NULL THEN [] ELSE [1] END | SET event.name = $name)
    FOREACH (_ IN CASE WHEN $dateTimeProvided THEN [1] ELSE [] END | SET event.dateTime = $dateTime)
    FOREACH (_ IN CASE WHEN $status <> '' THEN [1] ELSE [] END | SET event.status = $status)
    FOREACH (_ IN CASE WHEN $constraintsProvided THEN [1] ELSE [] END |
      SET event.includedGenres = $includedGenres,
          event.excludedGenres = $excludedGenres,
          event.maxDurationMinutes = $maxDurationMinutes,
          event.minimumRating = $minimumRating,
          event.language = $language,
          event.status = 'waiting',
          event.winnerMovieId = null
    )
    RETURN event.id AS eventId
    LIMIT 1
    `,
    {
      uid,
      eventId,
      name,
      dateTimeProvided: data.dateTime !== undefined,
      dateTime: dateTime === undefined ? null : dateTime,
      status,
      constraintsProvided,
      ...(constraints || normalizeConstraints()),
    }
  );

  if (result.records.length === 0) return null;
  if (constraintsProvided) {
    await clearShortlistAndVotes(eventId);
  }
  if (status === 'voting') {
    await generateShortlist(uid, eventId);
  }
  return getMovieNight(uid, eventId);
}

async function clearShortlistAndVotes(eventId) {
  await neo4jService.run(
    `
    MATCH (event:MovieNight {id: $eventId})
    OPTIONAL MATCH (event)-[candidate:HAS_CANDIDATE]->(:Movie)
    DELETE candidate
    WITH event
    OPTIONAL MATCH (:AppUser)-[vote:VOTED_IN]->(:Movie)
    WHERE vote.eventId = $eventId
    DELETE vote
    SET event.winnerMovieId = null
    `,
    { eventId }
  );
}

async function createInviteLink(uid, eventId) {
  const inviteLink = `agreeo://invite/${eventId}`;
  const result = await neo4jService.run(
    `
    MATCH (:AppUser {uid: $uid})-[:HOSTS]->(event:MovieNight {id: $eventId})
    SET event.inviteLink = $inviteLink, event.updatedAt = datetime()
    RETURN event.inviteLink AS inviteLink
    LIMIT 1
    `,
    { uid, eventId, inviteLink }
  );
  if (result.records.length === 0) return null;
  return { inviteLink: result.records[0].get('inviteLink'), event: await getMovieNight(uid, eventId) };
}

const TMDB_ENRICH_CONCURRENCY = 4;

// Runs `worker` over `items` with at most `limit` promises in flight at once.
async function runWithConcurrency(items, limit, worker) {
  const queue = [...items];
  const runners = Array.from({ length: Math.min(limit, queue.length) }, async () => {
    while (queue.length > 0) {
      const item = queue.shift();
      await worker(item);
    }
  });
  await Promise.all(runners);
}

// Fetches missing details for a single shortlist candidate from TMDB and
// persists them back onto the Movie node. Mutates candidate.movie in place.
async function enrichCandidateFromTmdb(candidate) {
  try {
    console.info(`[generateShortlist] Enriching movie tmdbId=${candidate.movie.tmdbId} from TMDB...`);
    const tmdbMovie = await tmdbGet(`/movie/${candidate.movie.tmdbId}`, { language: 'en-US' });
    if (!tmdbMovie) return;

    const posterUrl = tmdbMovie.poster_path ? `https://image.tmdb.org/t/p/w780${tmdbMovie.poster_path}` : '';
    const backdropUrl = tmdbMovie.backdrop_path ? `https://image.tmdb.org/t/p/w780${tmdbMovie.backdrop_path}` : '';
    const genres = Array.isArray(tmdbMovie.genres)
      ? tmdbMovie.genres.map((g) => g?.name).filter((n) => typeof n === 'string' && n.trim() !== '')
      : [];
    const runtime = Number.isInteger(tmdbMovie.runtime) ? tmdbMovie.runtime : null;

    candidate.movie.posterPath = tmdbMovie.poster_path || null;
    candidate.movie.backdropPath = tmdbMovie.backdrop_path || null;
    candidate.movie.posterUrl = posterUrl;
    candidate.movie.backdropUrl = backdropUrl;
    if (tmdbMovie.overview) candidate.movie.overview = tmdbMovie.overview;
    candidate.movie.genres = genres;
    candidate.movie.runtime = runtime || 0;
    candidate.movie.tmdbHydrated = true;

    await neo4jService.run(
      `
      MATCH (m:Movie {tmdbId: $tmdbId})
      SET m.posterPath = $posterPath,
          m.backdropPath = $backdropPath,
          m.posterUrl = $posterUrl,
          m.backdropUrl = $backdropUrl,
          m.overview = coalesce($overview, m.overview),
          m.genres = $genres,
          m.runtime = $runtime,
          m.tmdbHydrated = true
      `,
      {
        tmdbId: candidate.movie.tmdbId,
        posterPath: tmdbMovie.poster_path || null,
        backdropPath: tmdbMovie.backdrop_path || null,
        posterUrl,
        backdropUrl,
        overview: tmdbMovie.overview || null,
        genres,
        runtime
      }
    );
  } catch (e) {
    console.error(`[generateShortlist] Failed to enrich movie tmdbId=${candidate.movie.tmdbId}:`, e.message);
  }
}

async function generateShortlist(uid, eventId) {
  const event = await getMovieNight(uid, eventId);
  if (!event) return null;
  const constraints = normalizeConstraints(event.constraints);
  const joinedParticipants = event.participants.filter((participant) => participant.status === 'joined');

  // Calculate Group Taste Vector based on tag embeddings of movies swiped by joined participants
  const userIds = joinedParticipants.map((p) => p.userId);
  let groupTasteVector = null;
  if (userIds.length > 0) {
    const groupTagsResult = await neo4jService.run(
      `
      MATCH (u:AppUser)
      WHERE u.uid IN $userIds
      MATCH (u)-[r:LIKED|SELECTED_FAVORITE|WATCHLISTED|DISLIKED]->(m:Movie)
      MATCH (m)<-[:MATCHES_TMDB]-(ml:MovieLensMovie)-[h:HAS_TAG]->(t:Tag)
      WHERE t.embedding IS NOT NULL
      RETURN t.embedding AS embedding, type(r) AS relType, coalesce(h.frequency, 1) AS frequency
      `,
      { userIds }
    );

    if (groupTagsResult.records.length > 0) {
      const sumVector = new Array(384).fill(0);
      let totalWeight = 0;

      for (const record of groupTagsResult.records) {
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
          sumVector[i] += embedding[i] * weight;
        }
        totalWeight += weight;
      }

      // No magnitude normalization needed: the vector index uses cosine
      // similarity, invariant to scaling the query vector by a positive scalar.
      if (totalWeight > 0) {
        groupTasteVector = sumVector;
      }
    }
  }

  const movies = await loadCandidateMovies(constraints, 150, groupTasteVector);
  const states = await loadUserMovieStates(
    joinedParticipants.map((participant) => participant.userId),
    movies.map((movie) => movie.tmdbId).filter((tmdbId) => Number.isInteger(tmdbId))
  );
  const shortlist = buildShortlist({ constraints, participants: joinedParticipants, movies, states, limit: 10 });

  // Enrich shortlist candidate movies with TMDB details if they are missing
  // poster data or not hydrated. Bounded concurrency keeps us well under TMDB
  // rate limits instead of firing one request per candidate simultaneously.
  const candidatesToEnrich = shortlist.filter(
    (candidate) => candidate.movie && candidate.movie.tmdbId &&
      (!candidate.movie.tmdbHydrated || !candidate.movie.posterPath)
  );
  await runWithConcurrency(candidatesToEnrich, TMDB_ENRICH_CONCURRENCY, (candidate) =>
    enrichCandidateFromTmdb(candidate)
  );

  await neo4jService.run(
    `
    MATCH (event:MovieNight {id: $eventId})
    OPTIONAL MATCH (event)-[old:HAS_CANDIDATE]->(:Movie)
    DELETE old
    WITH event
    UNWIND $candidates AS candidate
    MATCH (m:Movie {tmdbId: candidate.tmdbId})
    MERGE (event)-[rel:HAS_CANDIDATE]->(m)
    SET rel.compatibilityScore = candidate.compatibilityScore,
        rel.explanationTags = candidate.explanationTags,
        rel.scoreBreakdownJson = candidate.scoreBreakdownJson,
        event.updatedAt = datetime(),
        event.winnerMovieId = null
    `,
    {
      eventId,
      candidates: shortlist.map((candidate) => ({
        tmdbId: candidate.movie.tmdbId,
        compatibilityScore: candidate.compatibilityScore,
        explanationTags: candidate.explanationTags,
        scoreBreakdownJson: JSON.stringify(candidate.scoreBreakdown),
      })),
    }
  );
  await clearVotesOnly(eventId);
  return getMovieNight(uid, eventId);
}

async function clearVotesOnly(eventId) {
  await neo4jService.run(
    `
    OPTIONAL MATCH (:AppUser)-[vote:VOTED_IN]->(:Movie)
    WHERE vote.eventId = $eventId
    DELETE vote
    `,
    { eventId }
  );
}

const { TMDB_GENRE_IDS_BY_NAME, TMDB_GENRE_NAMES_BY_ID, mapGenreNameToId } = require('./genreUtils');

async function loadCandidateMovies(constraints, limit = 150, groupTasteVector = null) {
  try {
    const params = {
      language: 'en-US',
      include_adult: false,
      page: 1,
      'vote_count.gte': 100,
    };

    if (constraints.maxDurationMinutes && constraints.maxDurationMinutes > 0) {
      params['with_runtime.lte'] = constraints.maxDurationMinutes;
    }
    if (constraints.minimumRating && constraints.minimumRating > 0) {
      params['vote_average.gte'] = constraints.minimumRating;
    }

    const withGenres = (constraints.includedGenres || [])
      .map(mapGenreNameToId)
      .filter(Boolean)
      .join('|');
    if (withGenres) {
      params['with_genres'] = withGenres;
    }

    const withoutGenres = (constraints.excludedGenres || [])
      .map(mapGenreNameToId)
      .filter(Boolean)
      .join(',');
    if (withoutGenres) {
      params['without_genres'] = withoutGenres;
    }

    console.info('[loadCandidateMovies] Discovering TMDB movies with params:', params);
    const tmdbResponse = await tmdbGet('/discover/movie', params);

    if (tmdbResponse && Array.isArray(tmdbResponse.results)) {
      for (const m of tmdbResponse.results) {
        if (!m || !m.id) continue;

        const genres = (m.genre_ids || [])
          .map(id => TMDB_GENRE_NAMES_BY_ID[id])
          .filter(Boolean)
          .map(name => name.replace(/\b\w/g, char => char.toUpperCase()));

        const releaseDate = m.release_date || '';
        const posterUrl = m.poster_path ? `https://image.tmdb.org/t/p/w780${m.poster_path}` : '';
        const backdropUrl = m.backdrop_path ? `https://image.tmdb.org/t/p/w780${m.backdrop_path}` : '';

        // Merge movie node
        await neo4jService.run(
          `
          MERGE (m:Movie {tmdbId: $tmdbId})
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
            m.genres = $genres,
            m.tmdbHydrated = true
          `,
          {
            tmdbId: m.id,
            title: m.title || '',
            originalTitle: m.original_title || m.title || '',
            overview: m.overview || '',
            posterPath: m.poster_path || null,
            backdropPath: m.backdrop_path || null,
            posterUrl,
            backdropUrl,
            releaseDate,
            voteAverage: m.vote_average || 0.0,
            genres,
          }
        );
      }
    }
  } catch (error) {
    console.error('[loadCandidateMovies] Error discovering/merging from TMDB API:', error);
  }

  const safeLimit = toPositiveInteger(limit, 150, 500);
  let result;
  if (groupTasteVector) {
    result = await neo4jService.run(
      `
      CALL db.index.vector.queryNodes('tag_embeddings', toInteger($topK), $groupTasteVector)
      YIELD node AS tagNode, score AS similarity
      MATCH (tagNode)<-[h:HAS_TAG]-(ml:MovieLensMovie)-[:MATCHES_TMDB]->(m:Movie)
      
      WITH m, ml, tagNode.name AS tag, h.frequency AS tagFrequency, similarity
      WITH m, ml, tag, tagFrequency, (2.0 * similarity - 1.0) AS stdSimilarity
      WHERE stdSimilarity >= $similarityThreshold
      
      WITH m, ml, [g IN coalesce(m.genres, []) WHERE g IS NOT NULL] + collect(DISTINCT tag) AS rawGenres, sum(tagFrequency * (stdSimilarity ^ 3)) AS tagScore
      WITH m, ml, [g IN rawGenres WHERE g IS NOT NULL] AS genres, tagScore
      
      WHERE ($maxDurationMinutes IS NULL OR coalesce(m.runtime, 0) = 0 OR coalesce(m.runtime, 0) <= $maxDurationMinutes)
        AND ($minimumRating IS NULL OR coalesce(m.voteAverage, m.movieLensAvgRating * 2.0, 0.0) >= $minimumRating)
        AND (size($includedGenres) = 0 OR any(g IN genres WHERE g IN $includedGenres))
        AND none(g IN genres WHERE g IN $excludedGenres)
        
      RETURN {
        tmdbId: m.tmdbId,
        title: coalesce(m.title, ''),
        originalTitle: coalesce(m.originalTitle, m.title, ''),
        overview: coalesce(m.overview, ''),
        posterPath: m.posterPath,
        backdropPath: m.backdropPath,
        posterUrl: coalesce(m.posterUrl, ''),
        backdropUrl: coalesce(m.backdropUrl, ''),
        releaseDate: coalesce(m.releaseDate, ''),
        runtime: coalesce(m.runtime, 0),
        voteAverage: coalesce(m.voteAverage, m.movieLensAvgRating * 2.0, 0.0),
        genres: genres,
        movieLensAvgRating: m.movieLensAvgRating,
        movieLensRatingCount: coalesce(m.movieLensRatingCount, 0)
      } AS movie
      ORDER BY tagScore DESC, coalesce(m.movieLensRatingCount, 0) DESC, m.title ASC
      LIMIT toInteger($limit)
      `,
      {
        ...constraints,
        groupTasteVector,
        topK: 25,
        similarityThreshold: 0.35,
        limit: safeLimit,
      }
    );
  } else {
    result = await neo4jService.run(
      `
      MATCH (m:Movie)
      WHERE m.tmdbId IS NOT NULL
      OPTIONAL MATCH (m)<-[:MATCHES_TMDB]-(:MovieLensMovie)-[:IN_GENRE]->(genre:Genre)
      WITH m, [g IN coalesce(m.genres, []) WHERE g IS NOT NULL] + collect(DISTINCT genre.name) AS rawGenres
      WITH m, [g IN rawGenres WHERE g IS NOT NULL] AS genres
      WHERE ($maxDurationMinutes IS NULL OR coalesce(m.runtime, 0) = 0 OR coalesce(m.runtime, 0) <= $maxDurationMinutes)
        AND ($minimumRating IS NULL OR coalesce(m.voteAverage, m.movieLensAvgRating * 2.0, 0.0) >= $minimumRating)
        AND (size($includedGenres) = 0 OR any(g IN genres WHERE g IN $includedGenres))
        AND none(g IN genres WHERE g IN $excludedGenres)
      RETURN {
        tmdbId: m.tmdbId,
        title: coalesce(m.title, ''),
        originalTitle: coalesce(m.originalTitle, m.title, ''),
        overview: coalesce(m.overview, ''),
        posterPath: m.posterPath,
        backdropPath: m.backdropPath,
        posterUrl: coalesce(m.posterUrl, ''),
        backdropUrl: coalesce(m.backdropUrl, ''),
        releaseDate: coalesce(m.releaseDate, ''),
        runtime: coalesce(m.runtime, 0),
        voteAverage: coalesce(m.voteAverage, m.movieLensAvgRating * 2.0, 0.0),
        genres: genres,
        movieLensAvgRating: m.movieLensAvgRating,
        movieLensRatingCount: coalesce(m.movieLensRatingCount, 0)
      } AS movie
      ORDER BY coalesce(m.movieLensRatingCount, 0) DESC, coalesce(m.voteAverage, m.movieLensAvgRating * 2.0, 0.0) DESC, m.title ASC
      LIMIT toInteger($limit)
      `,
      { ...constraints, limit: safeLimit }
    );
  }
  return result.records.map((record) => normalizeMovie(record.get('movie')));
}

async function loadUserMovieStates(userIds, tmdbIds) {
  if (!Array.isArray(userIds) || userIds.length === 0 || !Array.isArray(tmdbIds) || tmdbIds.length === 0) return {};
  const result = await neo4jService.run(
    `
    MATCH (u:AppUser)
    WHERE u.uid IN $userIds
    MATCH (m:Movie)
    WHERE m.tmdbId IN $tmdbIds
    OPTIONAL MATCH (u)-[liked:LIKED]->(m)
    OPTIONAL MATCH (u)-[disliked:DISLIKED]->(m)
    OPTIONAL MATCH (u)-[watchlisted:WATCHLISTED]->(m)
    OPTIONAL MATCH (u)-[seen:ALREADY_SEEN]->(m)
    OPTIONAL MATCH (u)-[rated:RATED_APP]->(m)
    RETURN u.uid AS userId,
           m.tmdbId AS tmdbId,
           count(liked) > 0 AS liked,
           count(disliked) > 0 AS disliked,
           count(watchlisted) > 0 AS inWatchlist,
           count(seen) > 0 AS watched,
           max(rated.rating) AS rating
    `,
    { userIds, tmdbIds }
  );

  const states = {};
  for (const record of result.records) {
    const userId = record.get('userId');
    const tmdbId = toNativeNumber(record.get('tmdbId'));
    states[userId] = states[userId] || {};
    states[userId][String(tmdbId)] = {
      preference: record.get('disliked') ? 'disliked' : record.get('liked') ? 'liked' : 'neutral',
      inWatchlist: record.get('inWatchlist') === true,
      watched: record.get('watched') === true,
      rating: record.get('rating') == null ? null : toNativeNumber(record.get('rating')),
    };
  }
  return states;
}

function buildShortlist({ constraints, participants, movies, states, limit = 5 }) {
  if (constraints.includedGenres.some((genre) => constraints.excludedGenres.includes(genre))) return [];
  const candidates = [];
  for (const movie of movies) {
    const candidate = calculateCompatibility(movie, participants, states, constraints);
    candidates.push(candidate);
  }
  candidates.sort(compareCandidates);
  return candidates.slice(0, limit);
}

function calculateCompatibility(movie, participants, states, constraints) {
  let score = 0;
  let watchlistSaves = 0;
  let likes = 0;
  let dislikes = 0;
  let watched = 0;
  let positiveRatings = 0;
  for (const participant of participants) {
    const state = states[participant.userId]?.[String(movie.tmdbId)] || {};
    if (state.inWatchlist) { watchlistSaves += 1; score += 4; }
    if (state.preference === 'liked') { likes += 1; score += 3; }
    if (toFiniteNumber(state.rating) >= 4) { positiveRatings += 1; score += 1; }
    if (state.preference === 'disliked') { dislikes += 1; score -= 15; }
    if (state.watched) { watched += 1; score -= 1; }
  }
  const includedGenreMatches = movie.genres.filter((genre) => constraints.includedGenres.includes(genre)).length;
  const groupSize = participants.length || 1;
  const halfGroup = Math.ceil(groupSize / 2);
  let groupBonus = 0;
  let groupPenalty = 0;
  if (includedGenreMatches > 0) groupBonus += includedGenreMatches >= 2 ? 2 : 1;
  if (watched < halfGroup) groupBonus += 1;
  if (toFiniteNumber(movie.voteAverage) >= 7.5) groupBonus += 1;
  if (watched >= halfGroup) groupPenalty -= 3;
  if (dislikes >= halfGroup) groupPenalty -= 5;
  const total = score + groupBonus + groupPenalty;
  const scoreBreakdown = { watchlistSaves, likes, dislikes, watched, positiveRatings, includedGenreMatches, groupBonus, groupPenalty, total };
  return {
    movie,
    compatibilityScore: total,
    explanationTags: explainCandidate(movie, scoreBreakdown, participants, constraints),
    scoreBreakdown,
  };
}

function explainCandidate(movie, breakdown, participants, constraints) {
  const tags = [];
  const halfGroup = Math.ceil((participants.length || 1) / 2);
  if (breakdown.watchlistSaves > 0) tags.push(`Saved by ${breakdown.watchlistSaves} ${breakdown.watchlistSaves === 1 ? 'friend' : 'friends'}`);
  if (breakdown.likes >= halfGroup && breakdown.likes > 0) tags.push('Liked by most participants');
  if (constraints.includedGenres.length > 0 && breakdown.includedGenreMatches > 0) tags.push('Matches selected genres');
  if (breakdown.watched < halfGroup) tags.push('Mostly unwatched');
  if (toFiniteNumber(movie.voteAverage) >= 7.5) tags.push('High rating');
  if (tags.length === 0) tags.push('Balanced group fit');
  return tags;
}

function compareCandidates(left, right) {
  return right.compatibilityScore - left.compatibilityScore ||
    right.scoreBreakdown.watchlistSaves - left.scoreBreakdown.watchlistSaves ||
    right.scoreBreakdown.likes - left.scoreBreakdown.likes ||
    toFiniteNumber(right.movie.voteAverage) - toFiniteNumber(left.movie.voteAverage) ||
    releaseYear(right.movie) - releaseYear(left.movie) ||
    left.movie.title.localeCompare(right.movie.title);
}

function releaseYear(movie) {
  const year = Number.parseInt(String(movie.releaseDate || '').slice(0, 4), 10);
  return Number.isInteger(year) ? year : 0;
}

function voteScore(vote) {
  if (vote === 'like') return 3;
  if (vote === 'neutral') return 1;
  if (vote === 'alreadySeen') return -1;
  if (vote === 'dislike') return -4;
  return 0;
}

function hasEveryoneVoted(event) {
  const joinedIds = event.participants.filter((participant) => participant.status === 'joined').map((participant) => participant.userId);
  if (joinedIds.length === 0 || event.shortlist.length === 0) return false;
  for (const candidate of event.shortlist) {
    const movieId = `tmdb-${candidate.movie.tmdbId}`;
    const voters = new Set(event.votes.filter((vote) => vote.movieId === movieId).map((vote) => vote.userId));
    if (!joinedIds.every((userId) => voters.has(userId))) return false;
  }
  return true;
}

const MAX_TIE_BREAKER_ROUNDS = 2;

function scoreShortlist(shortlist, votes) {
  if (!Array.isArray(shortlist) || shortlist.length === 0) return [];
  const scored = shortlist.map((candidate) => {
    const movieId = `tmdb-${candidate.movie.tmdbId}`;
    const movieVotes = votes.filter((vote) => vote.movieId === movieId);
    return {
      candidate,
      finalScore: movieVotes.reduce((sum, vote) => sum + voteScore(vote.vote), 0),
      likes: movieVotes.filter((vote) => vote.vote === 'like').length,
      dislikes: movieVotes.filter((vote) => vote.vote === 'dislike').length,
    };
  });
  scored.sort((left, right) =>
    right.finalScore - left.finalScore ||
    right.likes - left.likes ||
    left.dislikes - right.dislikes ||
    right.candidate.compatibilityScore - left.candidate.compatibilityScore ||
    toFiniteNumber(right.candidate.movie.voteAverage) - toFiniteNumber(left.candidate.movie.voteAverage) ||
    left.candidate.movie.title.localeCompare(right.candidate.movie.title)
  );
  return scored;
}

function selectWinner(shortlist, votes) {
  const scored = scoreShortlist(shortlist, votes);
  if (scored.length === 0) return null;
  return scored[0].candidate;
}

async function clearVotesForTiedMovies(eventId, tiedTmdbIds, tx = null) {
  const run = (q, p) => tx ? tx.run(q, p) : neo4jService.run(q, p);
  await run(
    `
    OPTIONAL MATCH (:AppUser)-[vote:VOTED_IN]->(m:Movie)
    WHERE vote.eventId = $eventId AND m.tmdbId IN $tiedTmdbIds
    DELETE vote
    `,
    { eventId, tiedTmdbIds }
  );
}

async function startTieBreaker(eventId, tiedTmdbIds, tx = null) {
  const run = (q, p) => tx ? tx.run(q, p) : neo4jService.run(q, p);
  // Set eliminated = true for candidates not in the tied set
  await run(
    `
    MATCH (event:MovieNight {id: $eventId})-[rel:HAS_CANDIDATE]->(m:Movie)
    WHERE NOT m.tmdbId IN $tiedTmdbIds
    SET rel.eliminated = true
    `,
    { eventId, tiedTmdbIds }
  );
  // Increment round
  await run(
    `
    MATCH (event:MovieNight {id: $eventId})
    SET event.round = coalesce(event.round, 1) + 1, event.updatedAt = datetime()
    `,
    { eventId }
  );
  await clearVotesForTiedMovies(eventId, tiedTmdbIds, tx);
}

async function submitVote(uid, eventId, movieId, voteValue) {
  return await neo4jService.executeWrite(async (tx) => {
    const tmdbId = Number.parseInt(String(movieId).replace('tmdb-', ''), 10);
    if (!Number.isInteger(tmdbId) || tmdbId <= 0) return null;
    const vote = ['like', 'dislike', 'alreadySeen', 'neutral'].includes(voteValue) ? voteValue : 'neutral';

    // Insert/update the vote. The SET on `event` below takes a write lock on the
    // MovieNight node, which serializes concurrent votes on the same event (and
    // the subsequent winner computation) without needing a separate lock prop.
    const result = await tx.run(
      `
      MATCH (user:AppUser {uid: $uid})-[part:PARTICIPATES_IN]->(event:MovieNight {id: $eventId})
      MATCH (event)-[rel:HAS_CANDIDATE]->(movie:Movie {tmdbId: $tmdbId})
      WHERE part.status = 'joined' AND (rel.eliminated IS NULL OR NOT rel.eliminated)
      MERGE (user)-[v:VOTED_IN {eventId: $eventId}]->(movie)
      ON CREATE SET v.createdAt = datetime()
      SET v.vote = $vote, v.updatedAt = datetime(), event.status = 'voting', event.updatedAt = datetime()
      RETURN movie.tmdbId AS tmdbId
      LIMIT 1
      `,
      { uid, eventId, tmdbId, vote }
    );
    if (result.records.length === 0) return null;

    // 3. Load movie night state (passing the transaction tx)
    let event = await getMovieNight(uid, eventId, tx);
    if (event && hasEveryoneVoted(event)) {
      const scored = scoreShortlist(event.shortlist, event.votes);
      if (scored.length === 0) return event;

      const highestScore = scored[0].finalScore;
      const tied = scored.filter((s) => Math.abs(s.finalScore - highestScore) < 0.001);
      const currentRound = event.round || 1;

      if (tied.length > 1 && currentRound < MAX_TIE_BREAKER_ROUNDS) {
        // Tie detected — start tie-breaker round (passing tx)
        const tiedTmdbIds = tied.map((t) => t.candidate.movie.tmdbId);
        await startTieBreaker(eventId, tiedTmdbIds, tx);
        event = await getMovieNight(uid, eventId, tx);
        // Mark the event with tieBreaker flag for the controller
        event._tieBreaker = true;
        event._tiedMovieCount = tiedTmdbIds.length;
      } else {
        // Single winner (or max rounds reached — use deterministic sort)
        const winner = scored[0].candidate;
        await tx.run(
          `
          MATCH (event:MovieNight {id: $eventId})
          SET event.status = 'completed', event.winnerMovieId = $winnerMovieId, event.updatedAt = datetime()
          `,
          { eventId, winnerMovieId: `tmdb-${winner.movie.tmdbId}` }
        );
        event = await getMovieNight(uid, eventId, tx);
      }
    }
    return event;
  });
}

async function deleteVote(uid, eventId, movieId) {
  const tmdbId = Number.parseInt(String(movieId).replace('tmdb-', ''), 10);
  if (!Number.isInteger(tmdbId) || tmdbId <= 0) return null;
  
  await neo4jService.run(
    `
    MATCH (user:AppUser {uid: $uid})-[vote:VOTED_IN {eventId: $eventId}]->(movie:Movie {tmdbId: $tmdbId})
    DELETE vote
    `,
    { uid, eventId, tmdbId }
  );

  await neo4jService.run(
    `
    MATCH (event:MovieNight {id: $eventId})
    SET event.status = 'voting', event.winnerMovieId = null, event.updatedAt = datetime()
    `,
    { eventId }
  );

  return getMovieNight(uid, eventId);
}

async function getMovieNightResult(uid, eventId) {
  const event = await getMovieNight(uid, eventId);
  if (!event) return null;
  const winner = event.shortlist.find((candidate) => `tmdb-${candidate.movie.tmdbId}` === event.winnerMovieId) || null;
  return { event, result: { winner } };
}

async function createNotification(recipientId, type, title, message, entityId = null, extraData = {}) {
  const id = randomId('notif');
  const extraDataStr = JSON.stringify(extraData);
  const result = await neo4jService.run(
    `
    MATCH (u:AppUser {uid: $recipientId})
    CREATE (n:InAppNotification {
      id: $id,
      type: $type,
      title: $title,
      message: $message,
      entityId: $entityId,
      extraData: $extraDataStr,
      read: false,
      createdAt: datetime()
    })
    CREATE (u)-[:HAS_NOTIFICATION]->(n)
    RETURN n.id AS id
    `,
    { recipientId, id, type, title, message, entityId, extraDataStr }
  );
  return result.records.length > 0 ? id : null;
}

async function listNotifications(uid) {
  const result = await neo4jService.run(
    `
    MATCH (u:AppUser {uid: $uid})-[:HAS_NOTIFICATION]->(n:InAppNotification)
    RETURN 
      n.id AS id,
      n.type AS type,
      n.title AS title,
      n.message AS message,
      n.entityId AS entityId,
      n.extraData AS extraData,
      n.read AS read,
      toString(n.createdAt) AS createdAt
    ORDER BY n.createdAt DESC
    `,
    { uid }
  );
  return result.records.map(record => {
    let extraData = {};
    try {
      extraData = JSON.parse(record.get('extraData') || '{}');
    } catch (e) {}
    return {
      id: record.get('id'),
      type: record.get('type'),
      title: record.get('title'),
      message: record.get('message'),
      entityId: record.get('entityId'),
      extraData,
      read: record.get('read') === true,
      createdAt: record.get('createdAt')
    };
  });
}

async function markNotificationAsRead(uid, notificationId) {
  const result = await neo4jService.run(
    `
    MATCH (u:AppUser {uid: $uid})-[:HAS_NOTIFICATION]->(n:InAppNotification {id: $notificationId})
    SET n.read = true
    RETURN n.id AS id
    `,
    { uid, notificationId }
  );
  return result.records.length > 0;
}

async function getUserDisplayName(uid) {
  const result = await neo4jService.run(
    `
    MATCH (u:AppUser {uid: $uid})
    RETURN coalesce(u.displayName, u.email, 'Someone') AS displayName
    LIMIT 1
    `,
    { uid }
  );
  return result.records.length > 0 ? result.records[0].get('displayName') : 'Someone';
}

module.exports = {
  normalizeConstraints,
  runWithConcurrency,
  getFriends,
  searchFriends,
  sendFriendRequest,
  acceptFriendRequest,
  declineFriendRequest,
  cancelFriendRequest,
  removeFriend,
  blockFriend,
  getBlockedUsers,
  unblockFriend,
  getFriendProfile,
  createMovieNight,
  inviteFriends,
  joinMovieNight,
  leaveMovieNight,
  listMovieNights,
  getMovieNight,
  updateMovieNight,
  createInviteLink,
  generateShortlist,
  submitVote,
  deleteVote,
  getMovieNightResult,
  buildShortlist,
  hasEveryoneVoted,
  selectWinner,
  createNotification,
  listNotifications,
  markNotificationAsRead,
  getUserDisplayName,
};


