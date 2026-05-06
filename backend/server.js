const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const authController = require('./authController');
const preferencesController = require('./preferencesController');
const { verifyMiddleware, verifyRefresh } = require('./jwtUtils');

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
// User Preferences endpoints
app.post('/user/:uid/preferences', verifyMiddleware, preferencesController.updateUserPreferences);
app.get('/user/:uid/preferences', verifyMiddleware, preferencesController.getUserPreferences);


app.listen(port, () => console.log(`Auth server listening on port ${port}`));

module.exports = app;
