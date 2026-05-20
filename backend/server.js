require('dotenv').config();

const express = require('express');
const cors = require('cors');
const http = require('http');
const authController = require('./authController');
const movieController = require('./movieController');
const socialController = require('./socialController');
const neo4jService = require('./neo4jService');
const socketService = require('./socketService');
const { verifyMiddleware, verifyRefresh, sign, signRefresh } = require('./jwtUtils');

const app = express();
const server = http.createServer(app);
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Log incoming requests
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  next();
});

app.post('/auth/register', authController.register);
app.post('/auth/login', authController.login);

app.get('/movies/popular', movieController.popular);
app.get('/movies/recommendations', movieController.recommendations);
app.get('/movies/daily-suggestions', movieController.dailySuggestions);
app.get('/movies/search', movieController.search);
app.get('/movies/:tmdbId', movieController.details);

app.post('/auth/refresh', (req, res) => {
  const { refreshToken } = req.body;

  if (!refreshToken) {
    return res.status(400).json({
      error: 'Missing refreshToken',
    });
  }

  const payload = verifyRefresh(refreshToken);

  if (!payload || payload.type !== 'refresh') {
    return res.status(401).json({
      error: 'Invalid refresh token',
    });
  }

  const { sub, uid, email, roles } = payload;
  const resolvedUid = uid || sub;

  const accessToken = sign({
    sub: resolvedUid,
    uid: resolvedUid,
    email,
    roles,
  });

  const newRefresh = signRefresh({
    sub: resolvedUid,
    uid: resolvedUid,
    email,
    roles,
    type: 'refresh',
  });

  return res.json({
    accessToken,
    refreshToken: newRefresh,
  });
});

app.get('/me', verifyMiddleware, async (req, res) => {
  try {
    const uid = req.user.uid || req.user.sub;

    const result = await neo4jService.run(
      `
      MATCH (u:AppUser {uid: $uid})
      RETURN
        u.uid AS uid,
        u.email AS email,
        u.displayName AS displayName,
        toString(u.createdAt) AS createdAt,
        coalesce(u.onboardingCompleted, false) AS onboardingCompleted,
        coalesce(u.roles, ['USER']) AS roles
      LIMIT 1
      `,
      { uid }
    );

    if (result.records.length === 0) {
      return res.status(404).json({
        error: 'User not found',
      });
    }

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
    console.error('/me error:', error);
    return res.status(500).json({
      error: 'Failed to load current user',
    });
  }
});

app.patch('/me/onboarding', verifyMiddleware, movieController.updateOnboarding);

app.post('/me/movies/:tmdbId/like', verifyMiddleware, movieController.like);
app.post('/me/movies/:tmdbId/dislike', verifyMiddleware, movieController.dislike);
app.post('/me/movies/:tmdbId/watchlist', verifyMiddleware, movieController.watchlist);
app.post('/me/movies/:tmdbId/seen', verifyMiddleware, movieController.markSeen);
app.delete('/me/movies/:tmdbId/watchlist', verifyMiddleware, movieController.removeFromWatchlist);
app.delete('/me/movies/:tmdbId/like', verifyMiddleware, movieController.removeLike);
app.delete('/me/movies/:tmdbId/dislike', verifyMiddleware, movieController.removeDislike);
app.delete('/me/movies/:tmdbId/seen', verifyMiddleware, movieController.removeSeen);
app.get('/me/library', verifyMiddleware, movieController.library);
app.get('/me/recommendations', verifyMiddleware, movieController.recommendationsForYou);
app.get('/me/recommendations/for-you', verifyMiddleware, movieController.recommendationsForYou);
app.get('/me/recommendations/daily-suggestions', verifyMiddleware, movieController.dailySuggestionsAuthenticated);
app.get('/me/recommendations/debug-stats', verifyMiddleware, movieController.recommendationDebugStats);

app.get('/friends', verifyMiddleware, socialController.listFriends);
app.get('/friends/search', verifyMiddleware, socialController.searchFriends);
app.post('/friends/requests', verifyMiddleware, socialController.sendFriendRequest);
app.post('/friends/requests/:id/accept', verifyMiddleware, socialController.acceptFriendRequest);
app.post('/friends/requests/:id/decline', verifyMiddleware, socialController.declineFriendRequest);
app.delete('/friends/:id', verifyMiddleware, socialController.removeFriend);
app.post('/friends/:id/block', verifyMiddleware, socialController.blockFriend);
app.get('/friends/:id/profile', verifyMiddleware, socialController.friendProfile);

app.get('/movie-nights', verifyMiddleware, socialController.listMovieNights);
app.post('/movie-nights', verifyMiddleware, socialController.createMovieNight);
app.get('/movie-nights/:id', verifyMiddleware, socialController.movieNight);
app.patch('/movie-nights/:id', verifyMiddleware, socialController.updateMovieNight);
app.post('/movie-nights/:id/invite', verifyMiddleware, socialController.inviteFriends);
app.post('/movie-nights/:id/join', verifyMiddleware, socialController.joinMovieNight);
app.post('/movie-nights/:id/invite-link', verifyMiddleware, socialController.createInviteLink);
app.post('/movie-nights/:id/shortlist', verifyMiddleware, socialController.generateShortlist);
app.post('/movie-nights/:id/votes', verifyMiddleware, socialController.submitVote);
app.delete('/movie-nights/:id/votes/:movieId', verifyMiddleware, socialController.deleteVote);
app.get('/movie-nights/:id/result', verifyMiddleware, socialController.movieNightResult);

// Notification endpoints
app.get('/notifications', verifyMiddleware, socialController.listNotifications);
app.post('/notifications/:id/read', verifyMiddleware, socialController.markNotificationAsRead);

app.get('/health/db', async (_, res) => {
  try {
    await neo4jService.verifyConnection();

    return res.status(200).json({
      ok: true,
      neo4jUri: neo4jService.uri,
    });
  } catch (error) {
    return res.status(500).json({
      ok: false,
      error: error instanceof Error ? error.message : String(error),
    });
  }
});

async function start() {
  try {
    await neo4jService.initialize();
    
    // Initialize Socket.io
    socketService.init(server);

    server.listen(port, () => {
      console.log(`Auth server with Socket.io listening on port ${port}`);
    });
  } catch (error) {
    console.error('Failed to start auth server:', error);
    process.exit(1);
  }
}

start();

module.exports = server;

