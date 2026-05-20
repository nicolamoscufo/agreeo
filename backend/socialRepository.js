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
    posterUrl: movie.posterUrl || '',
    backdropUrl: movie.backdropUrl || '',
    releaseDate: movie.releaseDate || '',
    runtime: movie.runtime == null ? 0 : toNativeNumber(movie.runtime),
    voteAverage: movie.voteAverage == null ? null : Number(movie.voteAverage),
    genres: Array.isArray(movie.genres) ? movie.genres.filter(Boolean) : [],
    movieLens: {
      avgRating: movie.movieLensAvgRating == null ? null : Number(movie.movieLensAvgRating),
      ratingCount: movie.movieLensRatingCount == null ? 0 : toNativeNumber(movie.movieLensRatingCount),
    },
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
    movieLensRatingCount: coalesce(${alias}.movieLensRatingCount, 0)
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
    WITH me, candidate, replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(rawSearchText, 'à', 'a'), 'è', 'e'), 'é', 'e'), 'ì', 'i'), 'ò', 'o'), 'ù', 'u'), '.', ' '), '-', ' '), '_', ' '), "'", ' ') AS searchText
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
    { uid, normalized: tokens.join(' '), firstToken: tokens[0] || '', tokens }
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
  await generateShortlist(uid, eventId);
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
  await generateShortlist(uid, eventId);
  return getMovieNight(uid, eventId);
}

async function listMovieNights(uid) {
  const result = await neo4jService.run(
    `
    MATCH (:AppUser {uid: $uid})-[:PARTICIPATES_IN]->(event:MovieNight)
    RETURN event.id AS eventId
    ORDER BY event.updatedAt DESC
    LIMIT 50
    `,
    { uid }
  );

  const events = [];
  for (const record of result.records) {
    const event = await getMovieNight(uid, record.get('eventId'));
    if (event) events.push(event);
  }
  return events;
}

async function getMovieNight(uid, eventId) {
  const eventResult = await neo4jService.run(
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
    loadParticipants(eventId),
    loadShortlist(eventId),
    loadVotes(eventId),
  ]);

  return { ...event, participants, shortlist, votes };
}

async function loadParticipants(eventId) {
  const result = await neo4jService.run(
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

async function loadShortlist(eventId) {
  const result = await neo4jService.run(
    `
    MATCH (:MovieNight {id: $eventId})-[candidate:HAS_CANDIDATE]->(m:Movie)
    RETURN {
      movie: ${movieMapCypher('m')},
      compatibilityScore: coalesce(candidate.compatibilityScore, 0.0),
      explanationTags: coalesce(candidate.explanationTags, []),
      scoreBreakdownJson: coalesce(candidate.scoreBreakdownJson, '{}')
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
  };
}

async function loadVotes(eventId) {
  const result = await neo4jService.run(
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

async function generateShortlist(uid, eventId) {
  const event = await getMovieNight(uid, eventId);
  if (!event) return null;
  const constraints = normalizeConstraints(event.constraints);
  const joinedParticipants = event.participants.filter((participant) => participant.status === 'joined');
  const movies = await loadCandidateMovies(constraints, 150);
  const states = await loadUserMovieStates(
    joinedParticipants.map((participant) => participant.userId),
    movies.map((movie) => movie.tmdbId).filter((tmdbId) => Number.isInteger(tmdbId))
  );
  const shortlist = buildShortlist({ constraints, participants: joinedParticipants, movies, states, limit: 5 });

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
};

const TMDB_GENRE_NAMES_BY_ID = Object.fromEntries(
  Object.entries(TMDB_GENRE_IDS_BY_NAME).map(([name, id]) => [id, name])
);

function mapGenreNameToId(name) {
  if (!name) return null;
  const clean = String(name).trim().toLowerCase();
  return TMDB_GENRE_IDS_BY_NAME[clean] || null;
}

async function loadCandidateMovies(constraints, limit = 150) {
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
      .join(',');
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
            m.genres = $genres
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
  const result = await neo4jService.run(
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
    LIMIT ${safeLimit}
    `,
    constraints
  );
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
    if (state.preference === 'disliked') { dislikes += 1; score -= 4; }
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

function selectWinner(shortlist, votes) {
  if (!Array.isArray(shortlist) || shortlist.length === 0) return null;
  const scored = shortlist.map((candidate) => {
    const movieId = `tmdb-${candidate.movie.tmdbId}`;
    const movieVotes = votes.filter((vote) => vote.movieId === movieId);
    return {
      candidate,
      finalScore: candidate.compatibilityScore + movieVotes.reduce((sum, vote) => sum + voteScore(vote.vote), 0),
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
  return scored[0].candidate;
}

async function submitVote(uid, eventId, movieId, voteValue) {
  const tmdbId = Number.parseInt(String(movieId).replace('tmdb-', ''), 10);
  if (!Number.isInteger(tmdbId) || tmdbId <= 0) return null;
  const vote = ['like', 'dislike', 'alreadySeen', 'neutral'].includes(voteValue) ? voteValue : 'neutral';
  const result = await neo4jService.run(
    `
    MATCH (user:AppUser {uid: $uid})-[part:PARTICIPATES_IN]->(event:MovieNight {id: $eventId})
    MATCH (event)-[:HAS_CANDIDATE]->(movie:Movie {tmdbId: $tmdbId})
    WHERE part.status = 'joined'
    MERGE (user)-[v:VOTED_IN {eventId: $eventId}]->(movie)
    ON CREATE SET v.createdAt = datetime()
    SET v.vote = $vote, v.updatedAt = datetime(), event.status = 'voting', event.updatedAt = datetime()
    RETURN movie.tmdbId AS tmdbId
    LIMIT 1
    `,
    { uid, eventId, tmdbId, vote }
  );
  if (result.records.length === 0) return null;

  let event = await getMovieNight(uid, eventId);
  if (event && hasEveryoneVoted(event)) {
    const winner = selectWinner(event.shortlist, event.votes);
    if (winner) {
      await neo4jService.run(
        `
        MATCH (event:MovieNight {id: $eventId})
        SET event.status = 'completed', event.winnerMovieId = $winnerMovieId, event.updatedAt = datetime()
        `,
        { eventId, winnerMovieId: `tmdb-${winner.movie.tmdbId}` }
      );
      event = await getMovieNight(uid, eventId);
    }
  }
  return event;
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
  getFriends,
  searchFriends,
  sendFriendRequest,
  acceptFriendRequest,
  declineFriendRequest,
  removeFriend,
  blockFriend,
  getFriendProfile,
  createMovieNight,
  inviteFriends,
  joinMovieNight,
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


