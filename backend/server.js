const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const authController = require('./authController');
const neo4jService = require('./neo4jService');
const { verifyMiddleware } = require('./jwtUtils');

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(bodyParser.json());

app.post('/auth/register', authController.register);
app.post('/auth/login', authController.login);
app.post('/auth/refresh', (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) return res.status(400).json({ error: 'Missing refreshToken' });
  const payload = require('./jwtUtils').verifyRefresh(refreshToken);
  if (!payload) return res.status(401).json({ error: 'Invalid refresh token' });
  const { sub, email, roles } = payload;
  const accessToken = require('./jwtUtils').sign({ sub, email, roles });
  const newRefresh = require('./jwtUtils').signRefresh({ sub, email, roles, type: 'refresh' });
  res.json({ accessToken, refreshToken: newRefresh });
});
app.get('/me', verifyMiddleware, (req, res) => {
  res.json({ user: req.user });
});

app.get('/health/db', async (_, res) => {
  try {
    await neo4jService.verifyConnection();
    res.status(200).json({ ok: true, neo4jUri: neo4jService.uri });
  } catch (error) {
    res.status(500).json({
      ok: false,
      error: error instanceof Error ? error.message : String(error),
    });
  }
});


app.listen(port, () => console.log(`Auth server listening on port ${port}`));

module.exports = app;
