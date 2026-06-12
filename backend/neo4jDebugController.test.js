const assert = require('node:assert/strict');
const test = require('node:test');

const neo4j = require('neo4j-driver');

const { serializeValue, serializePlan, neo4jDebugEnabled } = require('./neo4jDebugController');

test('serializeValue converts neo4j Integer to plain number', () => {
  assert.equal(serializeValue(neo4j.int(42)), 42);
  assert.equal(serializeValue(neo4j.int('9007199254740993')), '9007199254740993');
});

test('serializeValue converts Node and Relationship into tagged objects', () => {
  const node = new neo4j.types.Node(neo4j.int(1), ['Movie'], {
    tmdbId: neo4j.int(550),
    title: 'Fight Club',
  });
  const serializedNode = serializeValue(node);
  assert.deepEqual(serializedNode, {
    _type: 'node',
    labels: ['Movie'],
    properties: { tmdbId: 550, title: 'Fight Club' },
  });

  const rel = new neo4j.types.Relationship(
    neo4j.int(7),
    neo4j.int(1),
    neo4j.int(2),
    'LIKED',
    { likedAt: 'today' }
  );
  const serializedRel = serializeValue(rel);
  assert.equal(serializedRel._type, 'relationship');
  assert.equal(serializedRel.relType, 'LIKED');
  assert.deepEqual(serializedRel.properties, { likedAt: 'today' });
});

test('serializeValue handles nested lists and maps', () => {
  const value = {
    counts: [neo4j.int(1), neo4j.int(2)],
    inner: { score: 0.93, label: null },
  };
  assert.deepEqual(serializeValue(value), {
    counts: [1, 2],
    inner: { score: 0.93, label: null },
  });
});

test('serializePlan flattens the operator tree with children', () => {
  const plan = {
    operatorType: 'ProduceResults@neo4j',
    identifiers: ['m'],
    arguments: { EstimatedRows: 10 },
    children: [
      {
        operatorType: 'NodeByLabelScan@neo4j',
        identifiers: ['m'],
        arguments: { EstimatedRows: 10, Details: 'm:Movie' },
        children: [],
      },
    ],
  };

  const serialized = serializePlan(plan);
  assert.equal(serialized.operatorType, 'ProduceResults@neo4j');
  assert.equal(serialized.children.length, 1);
  assert.equal(serialized.children[0].details, 'm:Movie');
  assert.equal(serialized.children[0].estimatedRows, 10);
});

test('neo4jDebugEnabled is opt-in via ENABLE_NEO4J_DEBUG', () => {
  const original = process.env.ENABLE_NEO4J_DEBUG;
  try {
    delete process.env.ENABLE_NEO4J_DEBUG;
    assert.equal(neo4jDebugEnabled(), false);
    process.env.ENABLE_NEO4J_DEBUG = 'true';
    assert.equal(neo4jDebugEnabled(), true);
    process.env.ENABLE_NEO4J_DEBUG = 'false';
    assert.equal(neo4jDebugEnabled(), false);
  } finally {
    if (original === undefined) {
      delete process.env.ENABLE_NEO4J_DEBUG;
    } else {
      process.env.ENABLE_NEO4J_DEBUG = original;
    }
  }
});
