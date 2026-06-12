const socialRepository = require('./socialRepository');
const socketService = require('./socketService');
const { tmdbGet } = require('./tmdbClient');
const movieRepository = require('./movieRepository');
const { mapInteractionMovie } = require('./movieController');

function requestUid(req) {
  return req.user && (req.user.uid || req.user.sub);
}

function cleanString(value) {
  return value == null ? '' : String(value).trim();
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

function handleError(res, error, message) {
  console.error(`${message}:`, error);
  return res.status(500).json({ error: message });
}

function requireUid(req, res) {
  const uid = requestUid(req);
  if (!uid) {
    res.status(401).json({ error: 'Missing user context' });
    return null;
  }
  return uid;
}

exports.listFriends = async (req, res) => {
  const uid = requireUid(req, res);
  if (!uid) return;

  try {
    const social = await socialRepository.getFriends(uid);
    return res.json(social);
  } catch (error) {
    return handleError(res, error, 'Failed to load friends');
  }
};

exports.searchFriends = async (req, res) => {
  const uid = requireUid(req, res);
  if (!uid) return;

  try {
    const results = await socialRepository.searchFriends(uid, req.query.q || req.query.query || '');
    return res.json({ results });
  } catch (error) {
    return handleError(res, error, 'Failed to search friends');
  }
};

exports.sendFriendRequest = async (req, res) => {
  const uid = requireUid(req, res);
  if (!uid) return;
  const targetUserId = cleanString(req.body.targetUserId || req.body.userId);
  if (!targetUserId) return res.status(400).json({ error: 'targetUserId is required' });

  try {
    const result = await socialRepository.sendFriendRequest(uid, targetUserId);
    if (!result) return res.status(404).json({ error: 'Friend request target not found' });
    
    if (result.accepted) {
      const senderName = await socialRepository.getUserDisplayName(uid);
      const targetName = await socialRepository.getUserDisplayName(targetUserId);

      // Save notifications for both users
      await socialRepository.createNotification(
        targetUserId,
        'friend_accepted',
        'Friend Request Accepted',
        `${senderName} accepted your friend request.`,
        result.requestId,
        { fromUserId: uid, fromUserName: senderName }
      );
      await socialRepository.createNotification(
        uid,
        'friend_accepted',
        'Friend Request Accepted',
        `You are now friends with ${targetName}.`,
        result.requestId,
        { fromUserId: targetUserId, fromUserName: targetName }
      );

      // Emit real-time events to both
      socketService.emitToUser(targetUserId, 'friend_request_accepted', {
        friendId: uid,
        friendName: senderName,
        requestId: result.requestId
      });
      socketService.emitToUser(uid, 'friend_request_accepted', {
        friendId: targetUserId,
        friendName: targetName,
        requestId: result.requestId
      });

      return res.json({ ok: true, accepted: true, ...result.social });
    }

    const senderName = result.request.fromUser.name;
    await socialRepository.createNotification(
      targetUserId,
      'friend_request',
      'New Friend Request',
      `${senderName} sent you a friend request.`,
      result.request.id,
      { fromUserId: uid, fromUserName: senderName }
    );

    // Emit to target user
    socketService.emitToUser(targetUserId, 'friend_request_received', result.request);

    return res.status(201).json({ accepted: false, request: result.request });
  } catch (error) {
    return handleError(res, error, 'Failed to send friend request');
  }
};

exports.acceptFriendRequest = async (req, res) => {
  const uid = requireUid(req, res);
  if (!uid) return;

  try {
    const info = await socialRepository.acceptFriendRequest(uid, req.params.id);
    if (!info) return res.status(404).json({ error: 'Friend request not found' });

    // Save notification for original sender
    await socialRepository.createNotification(
      info.friendId,
      'friend_accepted',
      'Friend Request Accepted',
      `${info.accepterName} accepted your friend request.`,
      req.params.id,
      { fromUserId: uid, fromUserName: info.accepterName }
    );

    // Emit real-time event to original sender
    socketService.emitToUser(info.friendId, 'friend_request_accepted', {
      friendId: uid,
      friendName: info.accepterName,
      requestId: req.params.id
    });

    const social = await socialRepository.getFriends(uid);
    return res.json({ ok: true, ...social });
  } catch (error) {
    return handleError(res, error, 'Failed to accept friend request');
  }
};

exports.declineFriendRequest = async (req, res) => {
  const uid = requireUid(req, res);
  if (!uid) return;

  try {
    const info = await socialRepository.declineFriendRequest(uid, req.params.id);
    if (!info) return res.status(404).json({ error: 'Friend request not found' });

    // Emit real-time event to sender
    socketService.emitToUser(info.friendId, 'friend_request_declined', {
      friendId: uid,
      declinerName: info.declinerName,
      requestId: req.params.id
    });

    const social = await socialRepository.getFriends(uid);
    return res.json({ ok: true, ...social });
  } catch (error) {
    return handleError(res, error, 'Failed to decline friend request');
  }
};

exports.cancelFriendRequest = async (req, res) => {
  const uid = requireUid(req, res);
  if (!uid) return;
  const targetUserId = cleanString(req.params.userId);
  if (!targetUserId) return res.status(400).json({ error: 'userId is required' });

  try {
    const cancelled = await socialRepository.cancelFriendRequest(uid, targetUserId);
    if (!cancelled) return res.status(404).json({ error: 'Pending friend request not found' });

    // Let the target drop the request from their incoming list in real time.
    socketService.emitToUser(targetUserId, 'friend_request_cancelled', {
      fromUserId: uid,
    });

    const social = await socialRepository.getFriends(uid);
    return res.json({ ok: true, ...social });
  } catch (error) {
    return handleError(res, error, 'Failed to cancel friend request');
  }
};

exports.removeFriend = async (req, res) => {
  const uid = requireUid(req, res);
  if (!uid) return;

  try {
    const removed = await socialRepository.removeFriend(uid, req.params.id);
    if (!removed) return res.status(404).json({ error: 'Friend relationship not found' });
    const social = await socialRepository.getFriends(uid);
    return res.json({ ok: true, ...social });
  } catch (error) {
    return handleError(res, error, 'Failed to remove friend');
  }
};

exports.listBlockedUsers = async (req, res) => {
  const uid = requireUid(req, res);
  if (!uid) return;

  try {
    const blocked = await socialRepository.getBlockedUsers(uid);
    return res.json({ blocked });
  } catch (error) {
    return handleError(res, error, 'Failed to load blocked users');
  }
};

exports.unblockFriend = async (req, res) => {
  const uid = requireUid(req, res);
  if (!uid) return;

  try {
    const unblocked = await socialRepository.unblockFriend(uid, req.params.id);
    if (!unblocked) return res.status(404).json({ error: 'Blocked user not found' });
    const blocked = await socialRepository.getBlockedUsers(uid);
    return res.json({ ok: true, blocked });
  } catch (error) {
    return handleError(res, error, 'Failed to unblock user');
  }
};

exports.blockFriend = async (req, res) => {
  const uid = requireUid(req, res);
  if (!uid) return;

  try {
    const blocked = await socialRepository.blockFriend(uid, req.params.id);
    if (!blocked) return res.status(404).json({ error: 'Friend block target not found' });
    const social = await socialRepository.getFriends(uid);
    return res.json({ ok: true, ...social });
  } catch (error) {
    return handleError(res, error, 'Failed to block friend');
  }
};

exports.reportUser = async (req, res) => {
  const uid = requireUid(req, res);
  if (!uid) return;

  const reason = cleanString(req.body && req.body.reason);
  if (!reason) {
    return res.status(400).json({ error: 'A reason is required to report a user' });
  }

  try {
    const reportId = await socialRepository.reportUser(uid, req.params.id, {
      reason,
      context: cleanString(req.body && req.body.context),
      contentId: cleanString(req.body && req.body.contentId),
    });
    if (!reportId) return res.status(404).json({ error: 'Report target not found' });
    return res.json({ ok: true, reportId });
  } catch (error) {
    return handleError(res, error, 'Failed to report user');
  }
};

async function hydrateFriendProfileMovies(profile) {
  if (!profile) return profile;

  const unhydrated = [];

  // 1. Scan watchedMovies
  const watchedMovies = profile.watchedMovies || [];
  for (const m of watchedMovies) {
    if (m && m.tmdbId && !m.tmdbHydrated) {
      unhydrated.push(m);
    }
  }

  // 2. Scan watchlist
  const watchlist = profile.watchlist || [];
  for (const m of watchlist) {
    if (m && m.tmdbId && !m.tmdbHydrated) {
      unhydrated.push(m);
    }
  }

  // 3. Scan reviews
  const reviews = profile.reviews || [];
  for (const r of reviews) {
    if (r && r.movie && r.movie.tmdbId && !r.movie.tmdbHydrated) {
      unhydrated.push(r.movie);
    }
  }

  if (unhydrated.length === 0) {
    return profile;
  }

  const batchSize = 6;
  const hydratedMoviesMap = new Map();

  for (let i = 0; i < unhydrated.length; i += batchSize) {
    const batch = unhydrated.slice(i, i + batchSize);
    await Promise.all(
      batch.map(async (movie) => {
        try {
          if (hydratedMoviesMap.has(movie.tmdbId)) return;

          const tmdbMovie = await tmdbGet(`/movie/${movie.tmdbId}`, { append_to_response: 'credits' });
          if (tmdbMovie && tmdbMovie.id) {
            const mapped = mapInteractionMovie(tmdbMovie);
            mapped.tmdbHydrated = true;
            const fullMovie = {
              ...mapped,
              movieLensAvgRating: movie.movieLens?.avgRating ?? null,
              movieLensRatingCount: movie.movieLens?.ratingCount ?? 0,
            };
            await movieRepository.mergeTmdbMovie(fullMovie);
            hydratedMoviesMap.set(movie.tmdbId, fullMovie);
          }
        } catch (error) {
          console.warn(`Failed to hydrate friend profile movie ${movie.tmdbId} from TMDB:`, error.message);
        }
      })
    );
  }

  const mapMovieIfNeeded = (movie) => {
    if (movie && hydratedMoviesMap.has(movie.tmdbId)) {
      const hydrated = hydratedMoviesMap.get(movie.tmdbId);
      return {
        ...movie,
        ...hydrated,
        genres: hydrated.genres || [],
        tmdbHydrated: true,
      };
    }
    return movie;
  };

  const updatedWatchedMovies = watchedMovies.map(mapMovieIfNeeded);
  const updatedWatchlist = watchlist.map(mapMovieIfNeeded);
  const updatedReviews = reviews.map((r) => {
    if (r && r.movie) {
      return {
        ...r,
        movie: mapMovieIfNeeded(r.movie),
      };
    }
    return r;
  });

  return {
    ...profile,
    watchedMovies: updatedWatchedMovies,
    watchlist: updatedWatchlist,
    reviews: updatedReviews,
  };
}

exports.friendProfile = async (req, res) => {
  const uid = requireUid(req, res);
  if (!uid) return;

  try {
    const profile = await socialRepository.getFriendProfile(uid, req.params.id);
    if (!profile) return res.status(404).json({ error: 'Friend profile not found' });
    const hydratedProfile = await hydrateFriendProfileMovies(profile);
    return res.json({ profile: hydratedProfile });
  } catch (error) {
    return handleError(res, error, 'Failed to load friend profile');
  }
};

exports.listMovieNights = async (req, res) => {
  const uid = requireUid(req, res);
  if (!uid) return;

  try {
    const events = await socialRepository.listMovieNights(uid);
    return res.json({ events });
  } catch (error) {
    return handleError(res, error, 'Failed to load movie nights');
  }
};

exports.createMovieNight = async (req, res) => {
  const uid = requireUid(req, res);
  if (!uid) return;

  try {
    const event = await socialRepository.createMovieNight(uid, req.body || {});
    if (!event) return res.status(404).json({ error: 'Host user not found' });

    const hostName = await socialRepository.getUserDisplayName(uid);

    // Save notification & emit for each invited friend in parallel
    const pendingParticipants = event.participants.filter(p => p.status === 'pending');
    await Promise.all(pendingParticipants.map(async (friend) => {
      const friendId = friend.userId || friend.id;
      await socialRepository.createNotification(
        friendId,
        'movie_night_invite',
        'Movie Night Invitation',
        `${hostName} invited you to "${event.name}".`,
        event.id,
        { hostId: uid, hostName, eventName: event.name }
      );

      socketService.emitToUser(friendId, 'movie_night_invite', {
        event,
        hostName
      });
    }));

    return res.status(201).json({ event });
  } catch (error) {
    return handleError(res, error, 'Failed to create movie night');
  }
};

exports.movieNight = async (req, res) => {
  const uid = requireUid(req, res);
  if (!uid) return;

  try {
    const event = await socialRepository.getMovieNight(uid, req.params.id);
    if (!event) return res.status(404).json({ error: 'Movie night not found' });
    return res.json({ event });
  } catch (error) {
    return handleError(res, error, 'Failed to load movie night');
  }
};

exports.updateMovieNight = async (req, res) => {
  const uid = requireUid(req, res);
  if (!uid) return;

  try {
    const oldEvent = await socialRepository.getMovieNight(uid, req.params.id);
    const event = await socialRepository.updateMovieNight(uid, req.params.id, req.body || {});
    if (!event) return res.status(404).json({ error: 'Movie night not found' });

    // Check if status changed to voting
    const isVotingStarted = oldEvent && oldEvent.status !== 'voting' && event.status === 'voting';

    if (isVotingStarted) {
      const joinedParticipants = event.participants.filter(p => p.userId !== uid);
      await Promise.all(joinedParticipants.map(async (participant) => {
        await socialRepository.createNotification(
          participant.userId,
          'movie_night_voting',
          'Voting Started',
          `Voting has started for "${event.name}".`,
          event.id,
          { eventName: event.name }
        );
        socketService.emitToUser(participant.userId, 'movie_night_voting_started', { event });
      }));
    }

    // Emit movie_night_updated to all other participants
    const otherUids = event.participants
      .filter(p => p.userId !== uid)
      .map(p => p.userId);
    socketService.emitToUsers(otherUids, 'movie_night_updated', { event });

    return res.json({ event });
  } catch (error) {
    return handleError(res, error, 'Failed to update movie night');
  }
};

exports.inviteFriends = async (req, res) => {
  const uid = requireUid(req, res);
  if (!uid) return;
  const friendIds = cleanStringList(req.body.friendIds || req.body.invitedFriendIds);

  try {
    const event = await socialRepository.inviteFriends(uid, req.params.id, friendIds);
    if (!event) return res.status(404).json({ error: 'Movie night not found' });

    const hostName = await socialRepository.getUserDisplayName(uid);

    // Save notification & emit for newly invited friends in parallel
    await Promise.all(friendIds.map(async (friendId) => {
      await socialRepository.createNotification(
        friendId,
        'movie_night_invite',
        'Movie Night Invitation',
        `${hostName} invited you to "${event.name}".`,
        event.id,
        { hostId: uid, hostName, eventName: event.name }
      );

      socketService.emitToUser(friendId, 'movie_night_invite', {
        event,
        hostName
      });
    }));

    // Emit movie_night_updated to already joined participants
    const joinedUids = event.participants
      .filter(p => p.status === 'joined' && p.userId !== uid)
      .map(p => p.userId);
    socketService.emitToUsers(joinedUids, 'movie_night_updated', { event });

    return res.json({ event });
  } catch (error) {
    return handleError(res, error, 'Failed to invite friends');
  }
};

exports.joinMovieNight = async (req, res) => {
  const uid = requireUid(req, res);
  if (!uid) return;

  try {
    const event = await socialRepository.joinMovieNight(uid, req.params.id);
    if (!event) return res.status(404).json({ error: 'Movie night join target not found' });

    // Emit movie_night_updated to all other participants
    const otherUids = event.participants
      .filter(p => p.userId !== uid)
      .map(p => p.userId);
    socketService.emitToUsers(otherUids, 'movie_night_updated', { event });

    return res.json({ event });
  } catch (error) {
    return handleError(res, error, 'Failed to join movie night');
  }
};

exports.leaveMovieNight = async (req, res) => {
  const uid = requireUid(req, res);
  if (!uid) return;

  try {
    const previousEvent = await socialRepository.getMovieNight(uid, req.params.id);
    const left = await socialRepository.leaveMovieNight(uid, req.params.id);
    if (!left) return res.status(404).json({ error: 'Movie night leave target not found' });

    const otherUids = previousEvent
      ? previousEvent.participants.filter(p => p.userId !== uid).map(p => p.userId)
      : [];
    socketService.emitToUsers(otherUids, 'movie_night_updated', { eventId: req.params.id });

    return res.json({ ok: true });
  } catch (error) {
    return handleError(res, error, 'Failed to leave movie night');
  }
};

exports.createInviteLink = async (req, res) => {
  const uid = requireUid(req, res);
  if (!uid) return;

  try {
    const result = await socialRepository.createInviteLink(uid, req.params.id);
    if (!result) return res.status(404).json({ error: 'Movie night not found' });
    return res.json(result);
  } catch (error) {
    return handleError(res, error, 'Failed to create invite link');
  }
};

exports.generateShortlist = async (req, res) => {
  const uid = requireUid(req, res);
  if (!uid) return;

  try {
    const event = await socialRepository.generateShortlist(uid, req.params.id);
    if (!event) return res.status(404).json({ error: 'Movie night not found' });

    // Emit movie_night_updated to all other participants
    const otherUids = event.participants
      .filter(p => p.userId !== uid)
      .map(p => p.userId);
    socketService.emitToUsers(otherUids, 'movie_night_updated', { event });

    return res.json({ event });
  } catch (error) {
    return handleError(res, error, 'Failed to generate shortlist');
  }
};

exports.submitVote = async (req, res) => {
  const uid = requireUid(req, res);
  if (!uid) return;
  const movieId = cleanString(req.body.movieId);
  const vote = cleanString(req.body.vote);
  if (!movieId) return res.status(400).json({ error: 'movieId is required' });

  try {
    const event = await socialRepository.submitVote(uid, req.params.id, movieId, vote);
    if (!event) return res.status(404).json({ error: 'Movie night vote target not found' });

    const allUids = event.participants.map(p => p.userId);

    if (event._tieBreaker) {
      // Tie-breaker round started
      const tiedCount = event._tiedMovieCount || event.shortlist.length;
      const round = event.round || 2;

      await Promise.all(event.participants.map((participant) =>
        socialRepository.createNotification(
          participant.userId,
          'movie_night_tie_breaker',
          'Tie-Breaker!',
          `${tiedCount} movies tied in "${event.name}"! Vote again in round ${round}.`,
          event.id,
          { eventName: event.name, round, tiedCount }
        )
      ));
      // Clean internal flags before sending to clients
      delete event._tieBreaker;
      delete event._tiedMovieCount;
      socketService.emitToUsers(allUids, 'movie_night_tie_breaker', { event, round, tiedCount });
    } else if (event.status === 'completed') {
      const winnerCandidate = event.shortlist.find(c => `tmdb-${c.movie.tmdbId}` === event.winnerMovieId);
      const winnerTitle = winnerCandidate ? winnerCandidate.movie.title : 'Selected Movie';

      await Promise.all(event.participants.map(async (participant) => {
        await socialRepository.createNotification(
          participant.userId,
          'movie_night_completed',
          'Movie Night Decided!',
          `Decision reached for "${event.name}"! Winner: ${winnerTitle}.`,
          event.id,
          { eventName: event.name, winnerMovieId: event.winnerMovieId, winnerTitle }
        );
        socketService.emitToUser(participant.userId, 'movie_night_completed', { event, winnerTitle });
      }));
    } else {
      socketService.emitToUsers(allUids, 'movie_night_updated', { event });
    }

    // Clean internal flags before JSON response
    delete event._tieBreaker;
    delete event._tiedMovieCount;
    return res.json({ event });
  } catch (error) {
    return handleError(res, error, 'Failed to submit movie night vote');
  }
};

exports.deleteVote = async (req, res) => {
  const uid = requireUid(req, res);
  if (!uid) return;

  try {
    const event = await socialRepository.deleteVote(uid, req.params.id, req.params.movieId);
    if (!event) return res.status(404).json({ error: 'Movie night or vote not found' });

    // Emit movie_night_updated to all participants
    const allUids = event.participants.map(p => p.userId);
    socketService.emitToUsers(allUids, 'movie_night_updated', { event });

    return res.json({ event });
  } catch (error) {
    return handleError(res, error, 'Failed to delete movie night vote');
  }
};

exports.movieNightResult = async (req, res) => {
  const uid = requireUid(req, res);
  if (!uid) return;

  try {
    const result = await socialRepository.getMovieNightResult(uid, req.params.id);
    if (!result) return res.status(404).json({ error: 'Movie night not found' });
    return res.json(result);
  } catch (error) {
    return handleError(res, error, 'Failed to load movie night result');
  }
};

// Notification controllers
exports.listNotifications = async (req, res) => {
  const uid = requireUid(req, res);
  if (!uid) return;

  try {
    const notifications = await socialRepository.listNotifications(uid);
    return res.json({ notifications });
  } catch (error) {
    return handleError(res, error, 'Failed to load notifications');
  }
};

exports.markNotificationAsRead = async (req, res) => {
  const uid = requireUid(req, res);
  if (!uid) return;
  const notificationId = req.params.id;

  try {
    const success = await socialRepository.markNotificationAsRead(uid, notificationId);
    return res.json({ ok: success });
  } catch (error) {
    return handleError(res, error, 'Failed to mark notification as read');
  }
};

