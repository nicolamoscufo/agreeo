const neo4jService = require('./neo4jService');
const bcrypt = require('bcrypt');
const { sign, signRefresh } = require('./jwtUtils');

// Helper per generare i token (per evitare ripetizione di codice)
const generateTokens = (userId, email, roles) => {
  const accessToken = sign({ sub: userId, email, roles });
  const refreshToken = signRefresh({ sub: userId, email, roles, type: 'refresh' });
  return { accessToken, refreshToken };
};

exports.register = async (req, res) => {
  const { email, password } = req.body;

  // 1. Validazione input
  if (!email || !password || password.length < 6) {
    return res.status(400).json({ error: 'Invalid email or password. Password must be at least 6 characters.' });
  }

  try {
    // 2. Verifica se l'utente esiste già PRIMA di procedere
    const checkCypher = `MATCH (u:User {email: $email}) RETURN u.userId AS userId`;
    const checkResult = await neo4jService.run(checkCypher, { email });

    if (checkResult.records.length > 0) {
      return res.status(409).json({ error: 'User with this email already exists' });
    }

    // 3. Preparazione dati
    const hash = await bcrypt.hash(password, 10);
    const userId = 'u' + Math.random().toString(36).slice(2) + Date.now().toString(36);
    const roles = ['USER'];

    // 4. Creazione utente (usiamo CREATE invece di MERGE per evitare sovrascritture accidentali)
    const createCypher = `
            CREATE (u:User {
                userId: $userId, 
                email: $email, 
                passwordHash: $passwordHash, 
                createdAt: datetime(), 
                roles: $roles
            })
            RETURN u.userId AS userId
        `;

    const result = await neo4jService.run(createCypher, {
      email,
      userId,
      passwordHash: hash,
      roles
    });

    const userIdOut = result.records[0].get('userId');

    // 5. Generazione Token e risposta
    const tokens = generateTokens(userIdOut, email, roles);
    res.status(201).json({ userId: userIdOut, ...tokens });

  } catch (e) {
    console.error('Registration Error:', e); // Log l'errore vero nel server per il debug
    res.status(500).json({ error: 'An error occurred during registration' }); // Messaggio generico al client
  }
};

exports.login = async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required' });
  }

  try {
    // 1. Ricerca utente
    const cypher = `MATCH (u:User {email: $email}) RETURN u.userId AS userId, u.passwordHash AS passwordHash, u.roles AS roles`;
    const result = await neo4jService.run(cypher, { email });

    if (result.records.length === 0) {
      // Usiamo lo stesso errore per email non trovata o password errata per evitare "User Enumeration"
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const record = result.records[0];
    const userId = record.get('userId');
    const passwordHash = record.get('passwordHash');
    const roles = record.get('roles') || ['USER']; // Fallback se i ruoli sono nulli

    // 2. Verifica password
    const isMatch = await bcrypt.compare(password, passwordHash);
    if (!isMatch) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    // 3. Generazione Token e risposta
    const tokens = generateTokens(userId, email, roles);
    res.json({ userId, email, ...tokens });

  } catch (e) {
    console.error('Login Error:', e);
    res.status(500).json({ error: 'An error occurred during login' });
  }
};
