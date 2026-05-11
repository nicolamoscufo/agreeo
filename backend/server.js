require('dotenv').config();

const express = require('express');
const cors = require('cors');
const authController = require('./authController');
const movieController = require('./movieController');
const neo4jService = require('./neo4jService');
const { verifyMiddleware, verifyRefresh, sign, signRefresh } = require('./jwtUtils');

const app = express();
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

app.patch('/me/onboarding', verifyMiddleware, async (req, res) => {
  try {
    const uid = req.user.uid || req.user.sub;
    const completed = req.body.completed === true;

    const result = await neo4jService.run(
      `
      MATCH (u:AppUser {uid: $uid})
      SET u.onboardingCompleted = $completed
      RETURN
        u.uid AS uid,
        u.email AS email,
        u.displayName AS displayName,
        toString(u.createdAt) AS createdAt,
        coalesce(u.onboardingCompleted, false) AS onboardingCompleted,
        coalesce(u.roles, ['USER']) AS roles
      LIMIT 1
      `,
      { uid, completed }
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
    console.error('/me/onboarding error:', error);
    return res.status(500).json({
      error: 'Failed to update onboarding',
    });
  }
});

app.post('/me/movies/:tmdbId/like', verifyMiddleware, movieController.like);
app.post('/me/movies/:tmdbId/dislike', verifyMiddleware, movieController.dislike);
app.post('/me/movies/:tmdbId/watchlist', verifyMiddleware, movieController.watchlist);
app.delete('/me/movies/:tmdbId/watchlist', verifyMiddleware, movieController.removeFromWatchlist);
app.get('/me/library', verifyMiddleware, movieController.library);
app.get('/me/recommendations', verifyMiddleware, movieController.recommendations);

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

    app.listen(port, () => {
      console.log(`Auth server listening on port ${port}`);
    });
  } catch (error) {
    console.error('Failed to start auth server:', error);
    process.exit(1);
  }
}

start();

module.exports = app;
