const jwt = require('jsonwebtoken');

// Resolved lazily (and re-checked on every use) so requiring this module never
// crashes test runners; server.js calls resolveSecret() at startup to fail fast.
function resolveSecret() {
  const secret = process.env.JWT_SECRET;
  if (!secret || secret === 'CHANGE_ME' || secret.length < 32) {
    throw new Error(
      'JWT_SECRET must be set to a strong random value (>= 32 characters).'
    );
  }
  return secret;
}

function sign(payload) {
  return jwt.sign(payload, resolveSecret(), {
    expiresIn: '1h',
  });
}

function signRefresh(payload) {
  return jwt.sign(payload, resolveSecret(), {
    expiresIn: '7d',
  });
}

function verify(token) {
  try {
    return jwt.verify(token, resolveSecret());
  } catch (e) {
    return null;
  }
}

function verifyRefresh(token) {
  try {
    return jwt.verify(token, resolveSecret());
  } catch (e) {
    return null;
  }
}

function verifyMiddleware(req, res, next) {
  const header = req.headers['authorization'];

  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({
      error: 'Missing or invalid Authorization header',
    });
  }

  const token = header.substring(7);
  const payload = verify(token);

  if (!payload) {
    return res.status(401).json({
      error: 'Invalid token',
    });
  }

  req.user = payload;
  next();
}

module.exports = {
  resolveSecret,
  sign,
  verify,
  signRefresh,
  verifyRefresh,
  verifyMiddleware,
};
