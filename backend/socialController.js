const socialRepository = require('./socialRepository');
const socketService = require('./socketService');

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

exports.friendProfile = async (req, res) => {
  const uid = requireUid(req, res);
  if (!uid) return;

  try {
    const profile = await socialRepository.getFriendProfile(uid, req.params.id);
    if (!profile) return res.status(404).json({ error: 'Friend profile not found' });
    return res.json({ profile });
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

    // Save notification & emit for each invited friend
    const pendingParticipants = event.participants.filter(p => p.status === 'pending');
    for (const friend of pendingParticipants) {
      await socialRepository.createNotification(
        friend.userId || friend.id,
        'movie_night_invite',
        'Movie Night Invitation',
        `${hostName} invited you to "${event.name}".`,
        event.id,
        { hostId: uid, hostName, eventName: event.name }
      );

      socketService.emitToUser(friend.userId || friend.id, 'movie_night_invite', {
        event,
        hostName
      });
    }

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
      for (const participant of joinedParticipants) {
        await socialRepository.createNotification(
          participant.userId,
          'movie_night_voting',
          'Voting Started',
          `Voting has started for "${event.name}".`,
          event.id,
          { eventName: event.name }
        );
        socketService.emitToUser(participant.userId, 'movie_night_voting_started', { event });
      }
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

    // Save notification & emit for newly invited friends
    for (const friendId of friendIds) {
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
    }

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

    // Check if status became completed
    if (event.status === 'completed') {
      const winnerCandidate = event.shortlist.find(c => `tmdb-${c.movie.tmdbId}` === event.winnerMovieId);
      const winnerTitle = winnerCandidate ? winnerCandidate.movie.title : 'Selected Movie';

      // Notify all participants (host and friends)
      for (const participant of event.participants) {
        await socialRepository.createNotification(
          participant.userId,
          'movie_night_completed',
          'Movie Night Decided!',
          `Decision reached for "${event.name}"! Winner: ${winnerTitle}.`,
          event.id,
          { eventName: event.name, winnerMovieId: event.winnerMovieId, winnerTitle }
        );
        socketService.emitToUser(participant.userId, 'movie_night_completed', { event, winnerTitle });
      }
    } else {
      // Emit movie_night_updated to all participants
      const allUids = event.participants.map(p => p.userId);
      socketService.emitToUsers(allUids, 'movie_night_updated', { event });
    }

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

