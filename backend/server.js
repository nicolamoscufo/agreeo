require('dotenv').config();

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const http = require('http');
const authController = require('./authController');
const movieController = require('./movieController');
const socialController = require('./socialController');
const neo4jDebugController = require('./neo4jDebugController');
const neo4jService = require('./neo4jService');
const socketService = require('./socketService');
const { verifyMiddleware, verifyRefresh, sign, signRefresh, resolveSecret } = require('./jwtUtils');

const app = express();
const server = http.createServer(app);
const port = process.env.PORT || 3000;

// Restrict CORS to an explicit allowlist when CORS_ORIGINS is set
// (comma-separated). Defaults to open, which is fine for native mobile clients.
const corsOrigins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);
app.use(helmet());
app.use(cors(corsOrigins.length > 0 ? { origin: corsOrigins } : undefined));
// 1mb (default is 100kb) so profile avatars uploaded as base64 data URIs fit.
app.use(express.json({ limit: '1mb' }));

// Needed for correct client IP detection behind a reverse proxy (nginx).
app.set('trust proxy', 1);

const authLimiter = rateLimit({
  windowMs: 15 * 60_000,
  max: Number.parseInt(process.env.AUTH_RATE_LIMIT_MAX || '10000', 10),
  standardHeaders: true,
  legacyHeaders: false,
});
const apiLimiter = rateLimit({
  windowMs: 15 * 60_000,
  max: Number.parseInt(process.env.API_RATE_LIMIT_MAX || '100000', 10),
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(apiLimiter);

// Log incoming requests: method and path only, never query strings,
// which may contain user input (search text, mood queries, ...).
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

app.post('/auth/register', authLimiter, authController.register);
app.post('/auth/login', authLimiter, authController.login);

app.get('/movies/popular', movieController.popular);
app.get('/movies/random', movieController.random);
app.get('/movies/recommendations', movieController.recommendations);
app.get('/movies/daily-suggestions', movieController.dailySuggestions);
app.get('/movies/search', movieController.search);
app.get('/movies/mood-search', verifyMiddleware, movieController.moodSearch);
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
        coalesce(u.bio, '') AS bio,
        coalesce(u.avatarUrl, '') AS avatarUrl,
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
        bio: record.get('bio') || '',
        avatarUrl: record.get('avatarUrl') || '',
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
app.patch('/me/profile', verifyMiddleware, authController.updateProfile);
app.patch('/me/privacy', verifyMiddleware, authController.updatePrivacy);
// Password change and account deletion are credential-sensitive: rate-limit
// them like login/register to slow down brute-force attempts.
app.post('/me/password', verifyMiddleware, authLimiter, authController.changePassword);
app.delete('/me', verifyMiddleware, authLimiter, authController.deleteAccount);

const { traceAction } = require('./neo4jLiveTrace');
app.post('/me/movies/:tmdbId/like', verifyMiddleware, traceAction('Like', movieController.like));
app.post('/me/movies/:tmdbId/dislike', verifyMiddleware, traceAction('Dislike', movieController.dislike));
app.post('/me/movies/:tmdbId/watchlist', verifyMiddleware, traceAction('Watchlist', movieController.watchlist));
app.post('/me/movies/:tmdbId/seen', verifyMiddleware, traceAction('Seen', movieController.markSeen));
app.delete('/me/movies/:tmdbId/watchlist', verifyMiddleware, traceAction('Remove watchlist', movieController.removeFromWatchlist));
app.delete('/me/movies/:tmdbId/like', verifyMiddleware, traceAction('Remove like', movieController.removeLike));
app.delete('/me/movies/:tmdbId/dislike', verifyMiddleware, traceAction('Remove dislike', movieController.removeDislike));
app.delete('/me/movies/:tmdbId/seen', verifyMiddleware, traceAction('Remove seen', movieController.removeSeen));
app.get('/me/library', verifyMiddleware, traceAction('Library', movieController.library));
app.get('/me/recommendations', verifyMiddleware, movieController.recommendationsForYou);
app.get('/me/recommendations/for-you', verifyMiddleware, movieController.recommendationsForYou);
app.get('/me/recommendations/daily-suggestions', verifyMiddleware, movieController.dailySuggestionsAuthenticated);
app.get('/me/recommendations/debug-stats', verifyMiddleware, movieController.recommendationDebugStats);
app.get('/me/recommendations/metrics', verifyMiddleware, movieController.recommendationMetrics);
app.post('/me/recommendations/:batchId/impressions', verifyMiddleware, movieController.recordRecommendationImpressions);

app.get('/friends', verifyMiddleware, socialController.listFriends);
app.get('/friends/search', verifyMiddleware, socialController.searchFriends);
app.post('/friends/requests', verifyMiddleware, socialController.sendFriendRequest);
app.post('/friends/requests/:id/accept', verifyMiddleware, socialController.acceptFriendRequest);
app.post('/friends/requests/:id/decline', verifyMiddleware, socialController.declineFriendRequest);
app.delete('/friends/requests/outgoing/:userId', verifyMiddleware, socialController.cancelFriendRequest);
app.get('/friends/blocked', verifyMiddleware, socialController.listBlockedUsers);
app.delete('/friends/:id', verifyMiddleware, socialController.removeFriend);
app.post('/friends/:id/block', verifyMiddleware, socialController.blockFriend);
app.delete('/friends/:id/block', verifyMiddleware, socialController.unblockFriend);
app.post('/friends/:id/report', verifyMiddleware, socialController.reportUser);
app.get('/friends/:id/profile', verifyMiddleware, socialController.friendProfile);

app.get('/movie-nights', verifyMiddleware, socialController.listMovieNights);
app.post('/movie-nights', verifyMiddleware, socialController.createMovieNight);
app.get('/movie-nights/:id', verifyMiddleware, socialController.movieNight);
app.patch('/movie-nights/:id', verifyMiddleware, socialController.updateMovieNight);
app.post('/movie-nights/:id/invite', verifyMiddleware, socialController.inviteFriends);
app.post('/movie-nights/:id/join', verifyMiddleware, socialController.joinMovieNight);
app.delete('/movie-nights/:id/participants/me', verifyMiddleware, socialController.leaveMovieNight);
app.post('/movie-nights/:id/invite-link', verifyMiddleware, socialController.createInviteLink);
app.post('/movie-nights/:id/shortlist', verifyMiddleware, socialController.generateShortlist);
app.post('/movie-nights/:id/votes', verifyMiddleware, socialController.submitVote);
app.delete('/movie-nights/:id/votes/:movieId', verifyMiddleware, socialController.deleteVote);
app.get('/movie-nights/:id/result', verifyMiddleware, socialController.movieNightResult);

// Notification endpoints
app.get('/notifications', verifyMiddleware, socialController.listNotifications);
app.post('/notifications/:id/read', verifyMiddleware, socialController.markNotificationAsRead);

// Neo4j debug console (read-only): opt-in via ENABLE_NEO4J_DEBUG=true.
app.get('/debug/neo4j/overview', verifyMiddleware, neo4jDebugController.overview);
app.get('/debug/neo4j/schema', verifyMiddleware, neo4jDebugController.schema);
app.get('/debug/neo4j/indexes', verifyMiddleware, neo4jDebugController.indexes);
app.post('/debug/neo4j/query', verifyMiddleware, neo4jDebugController.query);
app.get('/debug/neo4j/live', verifyMiddleware, neo4jDebugController.live);
app.get('/debug/neo4j/recommendation-path', verifyMiddleware, neo4jDebugController.recommendationPath);

// Lightweight liveness probe: no DB round-trip, safe for orchestrators.
app.get('/health', (_, res) => {
  return res.status(200).json({ ok: true });
});

// Readiness probe: verifies the Neo4j connection.
app.get('/health/db', async (_, res) => {
  try {
    await neo4jService.verifyConnection();

    return res.status(200).json({
      ok: true,
    });
  } catch (error) {
    console.error('/health/db error:', error);
    return res.status(500).json({
      ok: false,
    });
  }
});

async function start() {
  try {
    // Fail fast on weak/missing JWT secret before accepting any traffic.
    resolveSecret();

    await neo4jService.initialize();

    // Initialize Socket.io with the same CORS allowlist as Express.
    socketService.init(server, { corsOrigins });

    server.listen(port, () => {
      console.log(`Auth server with Socket.io listening on port ${port}`);
    });
  } catch (error) {
    console.error('Failed to start auth server:', error);
    process.exit(1);
  }
}

async function shutdown(signal) {
  console.log(`Received ${signal}, shutting down...`);

  const io = socketService.getIo();
  if (io) {
    io.close();
  }

  server.close(async () => {
    try {
      await neo4jService.close();
    } catch (error) {
      console.error('Error closing Neo4j driver:', error);
    }
    process.exit(0);
  });

  // Force exit if connections do not drain in time.
  setTimeout(() => process.exit(1), 10_000).unref();
}

['SIGTERM', 'SIGINT'].forEach((signal) => {
  process.on(signal, () => shutdown(signal));
});

start();

module.exports = server;
