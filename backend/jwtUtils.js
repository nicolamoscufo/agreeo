const jwt = require('jsonwebtoken');

const SECRET = process.env.JWT_SECRET || 'CHANGE_ME';

function sign(payload) {
  return jwt.sign(payload, SECRET, {
    expiresIn: '1h',
  });
}

function signRefresh(payload) {
  return jwt.sign(payload, SECRET, {
    expiresIn: '7d',
  });
}

function verify(token) {
  try {
    return jwt.verify(token, SECRET);
  } catch (e) {
    return null;
  }
}

function verifyRefresh(token) {
  try {
    return jwt.verify(token, SECRET);
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
  sign,
  verify,
  signRefresh,
  verifyRefresh,
  verifyMiddleware,
};