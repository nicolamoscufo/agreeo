const neo4j = require('neo4j-driver');
const neo4jService = require('./neo4jService');
const { getHistory } = require('./neo4jLiveTrace');

// Opt-in explicitly (same pattern as ENABLE_RECOMMENDATION_DEBUG): the console
// exposes the whole graph to any authenticated user, so it must never be
// reachable in a real production deployment by default.
function neo4jDebugEnabled() {
  return String(process.env.ENABLE_NEO4J_DEBUG || 'false').toLowerCase() === 'true';
}

function guard(req, res) {
  if (!neo4jDebugEnabled()) {
    res.status(404).json({ error: 'Neo4j debug console is disabled. Set ENABLE_NEO4J_DEBUG=true.' });
    return false;
  }
  return true;
}

const MAX_ROWS = 200;

// Converts neo4j-driver values (Integer, Node, Relationship, Path, temporal
// types) into plain JSON the Flutter client can render.
function serializeValue(value) {
  if (value === null || value === undefined) {
    return null;
  }
  if (neo4j.isInt(value)) {
    return value.inSafeRange() ? value.toNumber() : value.toString();
  }
  if (value instanceof neo4j.types.Node) {
    return {
      _type: 'node',
      labels: value.labels,
      properties: serializeValue(value.properties),
    };
  }
  if (value instanceof neo4j.types.Relationship) {
    return {
      _type: 'relationship',
      relType: value.type,
      properties: serializeValue(value.properties),
    };
  }
  if (value instanceof neo4j.types.Path) {
    return {
      _type: 'path',
      segments: value.segments.map((segment) => ({
        start: serializeValue(segment.start),
        relationship: serializeValue(segment.relationship),
        end: serializeValue(segment.end),
      })),
    };
  }
  if (Array.isArray(value)) {
    return value.map(serializeValue);
  }
  if (
    neo4j.isDate(value) ||
    neo4j.isDateTime(value) ||
    neo4j.isLocalDateTime(value) ||
    neo4j.isLocalTime(value) ||
    neo4j.isTime(value) ||
    neo4j.isDuration(value)
  ) {
    return value.toString();
  }
  if (typeof value === 'object') {
    const result = {};
    for (const [key, entry] of Object.entries(value)) {
      result[key] = serializeValue(entry);
    }
    return result;
  }
  return value;
}

function serializePlan(plan) {
  if (!plan) {
    return null;
  }
  const args = plan.arguments || {};
  return {
    operatorType: plan.operatorType,
    identifiers: plan.identifiers || [],
    details: serializeValue(args.Details ?? args.Expressions ?? args.LabelExpression ?? null),
    estimatedRows: serializeValue(args.EstimatedRows ?? null),
    rows: serializeValue(plan.rows ?? null),
    dbHits: serializeValue(plan.dbHits ?? null),
    children: (plan.children || []).map(serializePlan),
  };
}

function serializeSummary(summary) {
  const counters = summary.counters ? summary.counters.updates() : {};
  const nonZeroCounters = Object.fromEntries(
    Object.entries(counters).filter(([, count]) => count > 0)
  );
  return {
    queryType: summary.queryType,
    resultAvailableAfterMs: serializeValue(summary.resultAvailableAfter),
    resultConsumedAfterMs: serializeValue(summary.resultConsumedAfter),
    counters: nonZeroCounters,
    plan: serializePlan(summary.profile || summary.plan),
  };
}

function serializeRecords(records) {
  const keys = records.length > 0 ? records[0].keys : [];
  const rows = records.slice(0, MAX_ROWS).map((record) =>
    keys.map((key) => serializeValue(record.get(key)))
  );
  return { columns: keys, rows, truncated: records.length > MAX_ROWS, totalRows: records.length };
}

// GET /debug/neo4j/overview — server info, node/relationship counts per label/type.
exports.overview = async (req, res) => {
  if (!guard(req, res)) return;

  try {
    const [components, nodeCount, relCount, labels, relTypes, propertyKeys] = await Promise.all([
      neo4jService.run('CALL dbms.components() YIELD name, versions, edition RETURN name, versions[0] AS version, edition'),
      neo4jService.run('MATCH (n) RETURN count(n) AS count'),
      neo4jService.run('MATCH ()-[r]->() RETURN count(r) AS count'),
      neo4jService.run('CALL db.labels() YIELD label RETURN label ORDER BY label'),
      neo4jService.run('CALL db.relationshipTypes() YIELD relationshipType RETURN relationshipType ORDER BY relationshipType'),
      neo4jService.run('CALL db.propertyKeys() YIELD propertyKey RETURN count(propertyKey) AS count'),
    ]);

    const labelNames = labels.records.map((record) => record.get('label'));
    const labelCounts = await Promise.all(
      labelNames.map(async (label) => {
        const result = await neo4jService.run(`MATCH (n:\`${label}\`) RETURN count(n) AS count`);
        return { label, count: serializeValue(result.records[0].get('count')) };
      })
    );

    const relTypeNames = relTypes.records.map((record) => record.get('relationshipType'));
    const relTypeCounts = await Promise.all(
      relTypeNames.map(async (relType) => {
        const result = await neo4jService.run(`MATCH ()-[r:\`${relType}\`]->() RETURN count(r) AS count`);
        return { type: relType, count: serializeValue(result.records[0].get('count')) };
      })
    );

    const component = components.records[0];

    return res.json({
      server: {
        name: component.get('name'),
        version: component.get('version'),
        edition: component.get('edition'),
        uri: neo4jService.uri,
      },
      totals: {
        nodes: serializeValue(nodeCount.records[0].get('count')),
        relationships: serializeValue(relCount.records[0].get('count')),
        propertyKeys: serializeValue(propertyKeys.records[0].get('count')),
      },
      labels: labelCounts.sort((a, b) => b.count - a.count),
      relationshipTypes: relTypeCounts.sort((a, b) => b.count - a.count),
    });
  } catch (error) {
    console.error('/debug/neo4j/overview error:', error);
    return res.status(500).json({ error: 'Failed to load Neo4j overview' });
  }
};

// GET /debug/neo4j/schema — graph patterns (:From)-[:REL]->(:To) with counts.
exports.schema = async (req, res) => {
  if (!guard(req, res)) return;

  try {
    const result = await neo4jService.run(`
      MATCH (a)-[r]->(b)
      WITH labels(a) AS fromLabels, type(r) AS relType, labels(b) AS toLabels, count(*) AS count
      RETURN fromLabels, relType, toLabels, count
      ORDER BY count DESC
    `);

    const patterns = result.records.map((record) => ({
      from: record.get('fromLabels'),
      relType: record.get('relType'),
      to: record.get('toLabels'),
      count: serializeValue(record.get('count')),
    }));

    return res.json({ patterns });
  } catch (error) {
    console.error('/debug/neo4j/schema error:', error);
    return res.status(500).json({ error: 'Failed to load Neo4j schema' });
  }
};

// GET /debug/neo4j/indexes — SHOW INDEXES + SHOW CONSTRAINTS (vector config included).
exports.indexes = async (req, res) => {
  if (!guard(req, res)) return;

  try {
    const [indexes, constraints] = await Promise.all([
      neo4jService.run(`
        SHOW INDEXES
        YIELD name, type, entityType, labelsOrTypes, properties, state, populationPercent, indexProvider, options
        RETURN name, type, entityType, labelsOrTypes, properties, state, populationPercent, indexProvider, options
        ORDER BY type, name
      `),
      neo4jService.run(`
        SHOW CONSTRAINTS
        YIELD name, type, entityType, labelsOrTypes, properties
        RETURN name, type, entityType, labelsOrTypes, properties
        ORDER BY name
      `),
    ]);

    return res.json({
      indexes: indexes.records.map((record) => ({
        name: record.get('name'),
        type: record.get('type'),
        entityType: record.get('entityType'),
        labelsOrTypes: record.get('labelsOrTypes'),
        properties: record.get('properties'),
        state: record.get('state'),
        populationPercent: serializeValue(record.get('populationPercent')),
        provider: record.get('indexProvider'),
        options: serializeValue(record.get('options')),
      })),
      constraints: constraints.records.map((record) => ({
        name: record.get('name'),
        type: record.get('type'),
        entityType: record.get('entityType'),
        labelsOrTypes: record.get('labelsOrTypes'),
        properties: record.get('properties'),
      })),
    });
  } catch (error) {
    console.error('/debug/neo4j/indexes error:', error);
    return res.status(500).json({ error: 'Failed to load Neo4j indexes' });
  }
};

// POST /debug/neo4j/query — read-only Cypher console with EXPLAIN/PROFILE support.
// The query runs inside a read transaction, so Neo4j itself rejects any write
// (Neo.ClientError.Statement.AccessMode) — no client-side query parsing needed.
exports.query = async (req, res) => {
  if (!guard(req, res)) return;

  const { query, mode, params = {} } = req.body || {};
  if (!params || typeof params !== 'object' || Array.isArray(params)) {
    return res.status(400).json({ error: 'params must be a JSON object' });
  }
  if (typeof query !== 'string' || query.trim().length === 0) {
    return res.status(400).json({ error: 'Missing Cypher query' });
  }

  let statement = query.trim();
  if (mode === 'explain') {
    statement = `EXPLAIN ${statement}`;
  } else if (mode === 'profile') {
    statement = `PROFILE ${statement}`;
  }

  const startedAt = Date.now();

  try {
    const result = await neo4jService.executeRead((tx) => tx.run(statement, {
      ...params,
      uid: req.user?.uid || req.user?.sub,
    }));
    const wallTimeMs = Date.now() - startedAt;

    return res.json({
      ...serializeRecords(result.records),
      summary: serializeSummary(result.summary),
      wallTimeMs,
    });
  } catch (error) {
    // Cypher errors (syntax, access mode, ...) are user-facing: return the
    // driver message so the console can display it like the Neo4j browser does.
    return res.status(422).json({
      error: error.message || 'Query failed',
      code: error.code || null,
      wallTimeMs: Date.now() - startedAt,
    });
  }
};

exports.serializeValue = serializeValue;
exports.serializePlan = serializePlan;
exports.neo4jDebugEnabled = neo4jDebugEnabled;

// GET /debug/neo4j/recommendation-path — one real 5-relation collaborative
// path for the current user, with titles and ratings, for the Live demo.
// It is a bounded, read-only illustration, not the production M23 ranking.
exports.recommendationPath = async (req, res) => {
  if (!guard(req, res)) return;
  const uid = req.user?.uid || req.user?.sub;
  if (!uid) return res.status(401).json({ error: 'Missing user context' });

  try {
    const result = await neo4jService.run(`
      MATCH (me:AppUser {uid: $uid})-[sig:LIKED|SELECTED_FAVORITE|WATCHLISTED]->(seed:Movie)
      WITH me, seed, sig
      ORDER BY coalesce(sig.createdAt, sig.updatedAt, datetime()) DESC
      LIMIT 3
      MATCH (seed)<-[:MATCHES_TMDB]-(seedMl:MovieLensMovie)<-[r1:RATED]-(similar:MovieLensUser)
      WHERE r1.rating >= 4.0
      WITH me, seed, seedMl, r1, similar
      ORDER BY r1.rating DESC
      LIMIT 20
      MATCH (similar)-[r2:RATED]->(recMl:MovieLensMovie)-[:MATCHES_TMDB]->(rec:Movie)
      WHERE r2.rating >= 4.0
        AND NOT (me)-[:LIKED|DISLIKED|WATCHLISTED|ALREADY_SEEN|SELECTED_FAVORITE]->(rec)
      RETURN
        coalesce(me.displayName, me.email, 'User') AS user,
        seed.tmdbId AS seedTmdbId, seed.title AS seedTitle,
        seedMl.movieLensId AS seedMovieLensId, seedMl.title AS seedMovieLensTitle,
        similar.movieLensUserId AS neighborId, toFloat(r1.rating) AS seedRating,
        toFloat(r2.rating) AS candidateRating,
        rec.tmdbId AS candidateTmdbId, rec.title AS candidateTitle,
        recMl.movieLensId AS candidateMovieLensId, recMl.title AS candidateMovieLensTitle
      ORDER BY r2.rating DESC, r1.rating DESC
      LIMIT 1
    `, { uid });

    if (result.records.length === 0) {
      return res.json({
        path: null,
        reason: 'No path available: this needs at least one liked movie linked to MovieLens and one candidate you have not interacted with yet.',
      });
    }

    const record = result.records[0];
    const value = (key) => serializeValue(record.get(key));
    return res.json({
      path: {
        user: value('user'),
        seed: {
          tmdbId: value('seedTmdbId'), title: value('seedTitle'),
          movieLensId: value('seedMovieLensId'), movieLensTitle: value('seedMovieLensTitle'),
          rating: value('seedRating'),
        },
        neighbor: { id: value('neighborId') },
        candidate: {
          tmdbId: value('candidateTmdbId'), title: value('candidateTitle'),
          movieLensId: value('candidateMovieLensId'), movieLensTitle: value('candidateMovieLensTitle'),
          rating: value('candidateRating'),
        },
      },
      segments: [
        { kind: 'user', label: value('user'), sub: 'AppUser' },
        { kind: 'rel', label: 'LIKED', direction: 'out' },
        { kind: 'movie', label: value('seedTitle'), sub: `Movie #${value('seedTmdbId')}` },
        { kind: 'rel', label: 'MATCHES_TMDB', direction: 'in' },
        { kind: 'movielens-movie', label: value('seedMovieLensTitle'), sub: `MovieLens #${value('seedMovieLensId')}` },
        { kind: 'rel', label: 'RATED', direction: 'in', value: value('seedRating') },
        { kind: 'movielens-user', label: `MovieLensUser #${value('neighborId')}`, sub: 'vicino collaborativo' },
        { kind: 'rel', label: 'RATED', direction: 'out', value: value('candidateRating') },
        { kind: 'movielens-movie', label: value('candidateMovieLensTitle'), sub: `MovieLens #${value('candidateMovieLensId')}` },
        { kind: 'rel', label: 'MATCHES_TMDB', direction: 'out' },
        { kind: 'movie', label: value('candidateTitle'), sub: `Movie #${value('candidateTmdbId')}` },
      ],
      observedAt: new Date().toISOString(),
    });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to load recommendation path' });
  }
};

exports.live = async (req, res) => {
  if (!guard(req, res)) return;
  const uid = req.user?.uid || req.user?.sub;
  if (!uid) return res.status(401).json({ error: 'Missing user context' });
  try {
    const result = await neo4jService.run(`
      MATCH (u:AppUser {uid: $uid})
      OPTIONAL MATCH (u)-[r:LIKED|DISLIKED|WATCHLISTED|ALREADY_SEEN|SELECTED_FAVORITE]->(m:Movie)
      WITH u, r, m ORDER BY m.title, m.tmdbId, type(r)
      RETURN u.displayName AS displayName,
        collect(CASE WHEN m IS NOT NULL THEN {
          tmdbId: m.tmdbId, title: m.title, type: type(r), createdAt: toString(r.createdAt)
        } END) AS library
    `, { uid });
    const record = result.records[0];
    return res.json({
      displayName: record?.get('displayName') || 'Current user',
      library: serializeValue(record?.get('library') || []),
      entries: getHistory(uid),
      observedAt: new Date().toISOString(),
    });
  } catch (error) {
    return res.status(500).json({ error: 'Failed to load live trace' });
  }
};
