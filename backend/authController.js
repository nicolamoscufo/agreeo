const neo4jService = require('./neo4jService');
const bcrypt = require('bcryptjs');
const { sign, signRefresh } = require('./jwtUtils');

const DEFAULT_ROLES = ['USER'];

const normalizeEmail = (email) => email.trim().toLowerCase();

// Minimum policy: at least 8 characters with at least one letter and one digit.
const isWeakPassword = (password) =>
  typeof password !== 'string' ||
  password.length < 8 ||
  !/[a-zA-Z]/.test(password) ||
  !/[0-9]/.test(password);

const displayNameFromEmail = (email) => {
  const normalized = normalizeEmail(email);
  return normalized.includes('@') ? normalized.split('@')[0] : normalized;
};

const generateUid = () => {
  return 'u_' + Math.random().toString(36).slice(2) + Date.now().toString(36);
};

const generateTokens = (uid, email, roles) => {
  const payload = {
    sub: uid,
    uid,
    email,
    roles,
  };

  const accessToken = sign(payload);
  const refreshToken = signRefresh({
    ...payload,
    type: 'refresh',
  });

  return { accessToken, refreshToken };
};

const userFromRecord = (record) => {
  return {
    uid: record.get('uid'),
    email: record.get('email'),
    displayName: record.get('displayName'),
    bio: record.get('bio') || '',
    avatarUrl: record.get('avatarUrl') || '',
    createdAt: record.get('createdAt'),
    onboardingCompleted: record.get('onboardingCompleted') === true,
    roles: record.get('roles') || DEFAULT_ROLES,
  };
};

// Shared RETURN projection so every auth/profile endpoint exposes the same
// user shape (kept in sync with /me in server.js and updateOnboarding).
const USER_RETURN = `
  u.uid AS uid,
  u.email AS email,
  u.displayName AS displayName,
  coalesce(u.bio, '') AS bio,
  coalesce(u.avatarUrl, '') AS avatarUrl,
  toString(u.createdAt) AS createdAt,
  coalesce(u.onboardingCompleted, false) AS onboardingCompleted,
  coalesce(u.roles, ['USER']) AS roles
`;

exports.register = async (req, res) => {
  const { email, password, displayName } = req.body;

  if (!email || isWeakPassword(password)) {
    return res.status(400).json({
      error:
        'Invalid email or password. Password must be at least 8 characters and contain at least one letter and one digit.',
    });
  }

  const emailNormalized = normalizeEmail(email);
  const resolvedDisplayName =
    displayName && displayName.trim().length > 0
      ? displayName.trim()
      : displayNameFromEmail(emailNormalized);

  try {
    const checkCypher = `
      MATCH (u:AppUser {emailNormalized: $emailNormalized})
      RETURN u.uid AS uid
      LIMIT 1
    `;

    const checkResult = await neo4jService.run(checkCypher, {
      emailNormalized,
    });

    if (checkResult.records.length > 0) {
      return res.status(409).json({
        error: 'User with this email already exists',
      });
    }

    const uid = generateUid();
    const passwordHash = await bcrypt.hash(password, 10);
    const roles = DEFAULT_ROLES;

    const createCypher = `
      CREATE (u:AppUser {
        uid: $uid,
        email: $email,
        emailNormalized: $emailNormalized,
        displayName: $displayName,
        passwordHash: $passwordHash,
        createdAt: datetime(),
        onboardingCompleted: false,
        roles: $roles
      })
      RETURN ${USER_RETURN}
    `;

    const result = await neo4jService.run(createCypher, {
      uid,
      email: email, // Usa la versione orginale preserving case
      emailNormalized,
      displayName: resolvedDisplayName,
      passwordHash,
      roles,
    });

    const user = userFromRecord(result.records[0]);
    const tokens = generateTokens(user.uid, user.email, user.roles);

    return res.status(201).json({
      ...tokens,
      user,
    });
  } catch (e) {
    // Two concurrent registrations can both pass the pre-check above; the
    // emailNormalized uniqueness constraint then rejects the second CREATE.
    // Surface that as a clean 409 instead of a generic 500.
    if (e && e.code === 'Neo.ClientError.Schema.ConstraintValidationFailed') {
      return res.status(409).json({
        error: 'User with this email already exists',
      });
    }
    console.error('Registration Error:', e);
    return res.status(500).json({
      error: 'An error occurred during registration',
    });
  }
};

exports.login = async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({
      error: 'Email and password are required',
    });
  }

  const emailNormalized = normalizeEmail(email);

  try {
    const cypher = `
      MATCH (u:AppUser {emailNormalized: $emailNormalized})
      RETURN
        u.passwordHash AS passwordHash,
        ${USER_RETURN}
      LIMIT 1
    `;

    const result = await neo4jService.run(cypher, {
      emailNormalized,
    });

    if (result.records.length === 0) {
      return res.status(401).json({
        error: 'Invalid email or password',
      });
    }

    const record = result.records[0];
    const passwordHash = record.get('passwordHash');

    const isMatch = await bcrypt.compare(password, passwordHash);
    if (!isMatch) {
      return res.status(401).json({
        error: 'Invalid email or password',
      });
    }

    const user = userFromRecord(record);
    const tokens = generateTokens(user.uid, user.email, user.roles);

    return res.status(200).json({
      ...tokens,
      user,
    });
  } catch (e) {
    console.error('Login Error:', e);
    return res.status(500).json({
      error: 'An error occurred during login',
    });
  }
};

const requestUid = (req) => (req.user && (req.user.uid || req.user.sub)) || null;

const MAX_DISPLAY_NAME_LENGTH = 60;
const MAX_BIO_LENGTH = 280;
// Avatars are stored inline on the AppUser node as data URIs (the client
// resizes/compresses before upload). Cap the property size to keep nodes lean.
const MAX_AVATAR_URL_LENGTH = 300_000;

const isValidAvatarUrl = (value) =>
  value === '' ||
  /^data:image\/(jpeg|png|webp);base64,[A-Za-z0-9+/=]+$/.test(value) ||
  /^https?:\/\/\S{1,2048}$/.test(value);

exports.updateProfile = async (req, res) => {
  const uid = requestUid(req);
  if (!uid) return res.status(401).json({ error: 'Missing user context' });

  const updates = {};

  if (Object.prototype.hasOwnProperty.call(req.body, 'displayName')) {
    const displayName = typeof req.body.displayName === 'string' ? req.body.displayName.trim() : '';
    if (displayName.length === 0 || displayName.length > MAX_DISPLAY_NAME_LENGTH) {
      return res.status(400).json({
        error: `displayName must be 1-${MAX_DISPLAY_NAME_LENGTH} characters`,
      });
    }
    updates.displayName = displayName;
  }

  if (Object.prototype.hasOwnProperty.call(req.body, 'bio')) {
    const bio = typeof req.body.bio === 'string' ? req.body.bio.trim() : null;
    if (bio === null || bio.length > MAX_BIO_LENGTH) {
      return res.status(400).json({
        error: `bio must be a string of at most ${MAX_BIO_LENGTH} characters`,
      });
    }
    updates.bio = bio;
  }

  if (Object.prototype.hasOwnProperty.call(req.body, 'avatarUrl')) {
    const avatarUrl = typeof req.body.avatarUrl === 'string' ? req.body.avatarUrl : null;
    if (
      avatarUrl === null ||
      avatarUrl.length > MAX_AVATAR_URL_LENGTH ||
      !isValidAvatarUrl(avatarUrl)
    ) {
      return res.status(400).json({
        error: 'avatarUrl must be an https URL or a base64 image data URI',
      });
    }
    updates.avatarUrl = avatarUrl;
  }

  if (Object.keys(updates).length === 0) {
    return res.status(400).json({
      error: 'Provide at least one of displayName, bio, avatarUrl',
    });
  }

  try {
    const setClauses = Object.keys(updates)
      .map((key) => `u.${key} = $${key}`)
      .join(', ');

    const result = await neo4jService.run(
      `
      MATCH (u:AppUser {uid: $uid})
      SET ${setClauses}
      RETURN ${USER_RETURN}
      LIMIT 1
      `,
      { uid, ...updates }
    );

    if (result.records.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    return res.json({ user: userFromRecord(result.records[0]) });
  } catch (e) {
    console.error('Update Profile Error:', e);
    return res.status(500).json({
      error: 'An error occurred while updating the profile',
    });
  }
};

// Privacy flags the social layer reads from the AppUser node when serving
// friend profiles (socialRepository coalesces the same names/defaults).
const PRIVACY_KEYS = ['canShowWatched', 'canShowReviews', 'canShowWatchlist'];

exports.updatePrivacy = async (req, res) => {
  const uid = requestUid(req);
  if (!uid) return res.status(401).json({ error: 'Missing user context' });

  const updates = {};
  for (const key of PRIVACY_KEYS) {
    if (Object.prototype.hasOwnProperty.call(req.body, key)) {
      if (typeof req.body[key] !== 'boolean') {
        return res.status(400).json({ error: `${key} must be a boolean` });
      }
      updates[key] = req.body[key];
    }
  }

  if (Object.keys(updates).length === 0) {
    return res.status(400).json({
      error: `Provide at least one of ${PRIVACY_KEYS.join(', ')}`,
    });
  }

  try {
    const setClauses = Object.keys(updates)
      .map((key) => `u.${key} = $${key}`)
      .join(', ');

    const result = await neo4jService.run(
      `
      MATCH (u:AppUser {uid: $uid})
      SET ${setClauses}
      RETURN
        coalesce(u.canShowWatched, true) AS canShowWatched,
        coalesce(u.canShowReviews, true) AS canShowReviews,
        coalesce(u.canShowWatchlist, false) AS canShowWatchlist
      LIMIT 1
      `,
      { uid, ...updates }
    );

    if (result.records.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const record = result.records[0];
    return res.json({
      privacy: {
        canShowWatched: record.get('canShowWatched') === true,
        canShowReviews: record.get('canShowReviews') === true,
        canShowWatchlist: record.get('canShowWatchlist') === true,
      },
    });
  } catch (e) {
    console.error('Update Privacy Error:', e);
    return res.status(500).json({
      error: 'An error occurred while updating privacy settings',
    });
  }
};

const verifyPasswordForUid = async (uid, password) => {
  const result = await neo4jService.run(
    `
    MATCH (u:AppUser {uid: $uid})
    RETURN u.passwordHash AS passwordHash
    LIMIT 1
    `,
    { uid }
  );

  if (result.records.length === 0) return { found: false, valid: false };

  const passwordHash = result.records[0].get('passwordHash');
  const valid = await bcrypt.compare(password, passwordHash);
  return { found: true, valid };
};

exports.changePassword = async (req, res) => {
  const uid = requestUid(req);
  if (!uid) return res.status(401).json({ error: 'Missing user context' });

  const { currentPassword, newPassword } = req.body;

  if (!currentPassword || typeof currentPassword !== 'string') {
    return res.status(400).json({ error: 'currentPassword is required' });
  }

  if (isWeakPassword(newPassword)) {
    return res.status(400).json({
      error:
        'New password must be at least 8 characters and contain at least one letter and one digit.',
    });
  }

  try {
    const { found, valid } = await verifyPasswordForUid(uid, currentPassword);
    if (!found) return res.status(404).json({ error: 'User not found' });
    // 403 (not 401) so clients don't mistake this for an expired token.
    if (!valid) return res.status(403).json({ error: 'Current password is incorrect' });

    const passwordHash = await bcrypt.hash(newPassword, 10);
    await neo4jService.run(
      `
      MATCH (u:AppUser {uid: $uid})
      SET u.passwordHash = $passwordHash
      `,
      { uid, passwordHash }
    );

    return res.json({ ok: true });
  } catch (e) {
    console.error('Change Password Error:', e);
    return res.status(500).json({
      error: 'An error occurred while changing the password',
    });
  }
};

exports.deleteAccount = async (req, res) => {
  const uid = requestUid(req);
  if (!uid) return res.status(401).json({ error: 'Missing user context' });

  const { password } = req.body;
  if (!password || typeof password !== 'string') {
    return res.status(400).json({ error: 'password is required to delete the account' });
  }

  try {
    const { found, valid } = await verifyPasswordForUid(uid, password);
    if (!found) return res.status(404).json({ error: 'User not found' });
    if (!valid) return res.status(403).json({ error: 'Password is incorrect' });

    // DETACH DELETE also removes every relationship (LIKED, FRIENDS_WITH,
    // PARTICIPATES_IN, ...), so the user disappears from friends' views too.
    await neo4jService.run(
      `
      MATCH (u:AppUser {uid: $uid})
      DETACH DELETE u
      `,
      { uid }
    );

    return res.json({ ok: true });
  } catch (e) {
    console.error('Delete Account Error:', e);
    return res.status(500).json({
      error: 'An error occurred while deleting the account',
    });
  }
};