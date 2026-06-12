const neo4j = require('neo4j-driver');
const neo4jService = require('./neo4jService');

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

  const { query, mode } = req.body || {};
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
    const result = await neo4jService.executeRead((tx) => tx.run(statement));
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
