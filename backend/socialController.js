const socialRepository = require('./socialRepository');

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
    const request = await socialRepository.sendFriendRequest(uid, targetUserId);
    if (!request) return res.status(404).json({ error: 'Friend request target not found' });
    return res.status(201).json({ request });
  } catch (error) {
    return handleError(res, error, 'Failed to send friend request');
  }
};

exports.acceptFriendRequest = async (req, res) => {
  const uid = requireUid(req, res);
  if (!uid) return;

  try {
    const accepted = await socialRepository.acceptFriendRequest(uid, req.params.id);
    if (!accepted) return res.status(404).json({ error: 'Friend request not found' });
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
    const declined = await socialRepository.declineFriendRequest(uid, req.params.id);
    if (!declined) return res.status(404).json({ error: 'Friend request not found' });
    const social = await socialRepository.getFriends(uid);
    return res.json({ ok: true, ...social });
  } catch (error) {
    return handleError(res, error, 'Failed to decline friend request');
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
    const event = await socialRepository.updateMovieNight(uid, req.params.id, req.body || {});
    if (!event) return res.status(404).json({ error: 'Movie night not found' });
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
    return res.json({ event });
  } catch (error) {
    return handleError(res, error, 'Failed to invite friends');
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
    return res.json({ event });
  } catch (error) {
    return handleError(res, error, 'Failed to submit movie night vote');
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
