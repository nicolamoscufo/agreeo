const neo4jService = require('./neo4jService');
const bcrypt = require('bcrypt');
const { sign, signRefresh } = require('./jwtUtils');

const DEFAULT_ROLES = ['USER'];

const normalizeEmail = (email) => email.trim().toLowerCase();

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
    createdAt: record.get('createdAt'),
    onboardingCompleted: record.get('onboardingCompleted') === true,
    roles: record.get('roles') || DEFAULT_ROLES,
  };
};

exports.register = async (req, res) => {
  const { email, password, displayName } = req.body;

  if (!email || !password || password.length < 6) {
    return res.status(400).json({
      error: 'Invalid email or password. Password must be at least 6 characters.',
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
      RETURN
        u.uid AS uid,
        u.email AS email,
        u.displayName AS displayName,
        toString(u.createdAt) AS createdAt,
        coalesce(u.onboardingCompleted, false) AS onboardingCompleted,
        coalesce(u.roles, ['USER']) AS roles
    `;

    const result = await neo4jService.run(createCypher, {
      uid,
      email: emailNormalized,
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
        u.uid AS uid,
        u.email AS email,
        u.displayName AS displayName,
        u.passwordHash AS passwordHash,
        toString(u.createdAt) AS createdAt,
        coalesce(u.onboardingCompleted, false) AS onboardingCompleted,
        coalesce(u.roles, ['USER']) AS roles
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