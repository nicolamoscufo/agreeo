const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const neo4jService = require('../neo4jService');
const embeddingService = require('../embeddingService');

const CACHE_FILE = embeddingService.CACHE_FILE;

function toNativeNumber(value) {
  return typeof value?.toNumber === 'function' ? value.toNumber() : Number(value);
}

function isValidEmbedding(value) {
  return Array.isArray(value) && value.length === 384 && value.every(Number.isFinite);
}

async function waitForVectorIndex(maxAttempts = 30) {
  for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
    const result = await neo4jService.run(`
      SHOW INDEXES YIELD name, type, state
      WHERE name = 'tag_embeddings'
      RETURN name, type, state
    `);
    const record = result.records[0];
    if (record && record.get('type') === 'VECTOR' && record.get('state') === 'ONLINE') {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 2000));
  }
  throw new Error('Vector index tag_embeddings did not become ONLINE in time.');
}

async function migrate() {
  console.log('==================================================');
  console.log('[MIGRATION] Starting Tag Migration to Vector Nodes');
  console.log('==================================================');

  try {
    await neo4jService.verifyConnection();
    console.log('[MIGRATION] Connected to Neo4j database.');

    // 1. Create constraint for Tag name
    console.log('[MIGRATION] Creating uniqueness constraint on (:Tag {name})...');
    await neo4jService.run(`
      CREATE CONSTRAINT tag_name IF NOT EXISTS
      FOR (t:Tag)
      REQUIRE t.name IS UNIQUE
    `);
    console.log('[MIGRATION] Constraint created successfully.');

    // 2. Create the Vector Index
    console.log('[MIGRATION] Creating native Neo4j vector index "tag_embeddings"...');
    await neo4jService.run(`
      CREATE VECTOR INDEX tag_embeddings IF NOT EXISTS
      FOR (t:Tag) ON (t.embedding)
      OPTIONS {indexConfig: {
        \`vector.dimensions\`: 384,
        \`vector.similarity_function\`: 'cosine'
      }}
    `);
    console.log('[MIGRATION] Vector index definition submitted.');

    // 3. Load embeddings cache
    let cachedEmbeddings = {};
    if (fs.existsSync(CACHE_FILE)) {
      try {
        console.log('[MIGRATION] Loading pre-computed embeddings from cache file...');
        cachedEmbeddings = JSON.parse(fs.readFileSync(CACHE_FILE, 'utf8'));
        console.log(`[MIGRATION] Loaded ${Object.keys(cachedEmbeddings).length} embeddings from cache.`);
      } catch (e) {
        console.warn('[MIGRATION] Could not parse cache file, will calculate embeddings dynamically.', e);
      }
    }

    // 4. Find all unique tags in the database
    console.log('[MIGRATION] Querying unique tags currently in database...');
    const tagResult = await neo4jService.run(`
      MATCH ()-[r:TAGGED]->()
      WHERE r.tag IS NOT NULL
      RETURN DISTINCT r.tag AS tag
    `);
    const tags = tagResult.records.map(rec => rec.get('tag')).filter(Boolean);
    console.log(`[MIGRATION] Found ${tags.length} unique tags to process.`);
    if (tags.length === 0) {
      throw new Error('No raw TAGGED relationships found; semantic migration cannot continue.');
    }

    const expectedRelationshipResult = await neo4jService.run(`
      MATCH (:MovieLensUser)-[r:TAGGED]->(ml:MovieLensMovie)
      WHERE r.tag IS NOT NULL
      WITH DISTINCT ml, r.tag AS tagText
      RETURN count(*) AS expectedRelationshipCount
    `);
    const expectedRelationshipCount = toNativeNumber(
      expectedRelationshipResult.records[0].get('expectedRelationshipCount')
    );

    // 5. Populate (:Tag) nodes
    console.log('[MIGRATION] Populating (:Tag) nodes with embeddings...');
    await embeddingService.initialize(); // Ensure extractor is ready in case we need dynamic embedding

    // Reload cache from file in case it was created/updated during initialize()
    if (fs.existsSync(CACHE_FILE)) {
      try {
        cachedEmbeddings = JSON.parse(fs.readFileSync(CACHE_FILE, 'utf8'));
        console.log(`[MIGRATION] Reloaded ${Object.keys(cachedEmbeddings).length} embeddings from cache after initialization.`);
      } catch (e) {
        console.warn('[MIGRATION] Could not parse cache file after initialization.', e);
      }
    }

    const tagBatch = [];
    const failedTags = [];
    for (const tag of tags) {
      let embedding = cachedEmbeddings[tag];
      if (!isValidEmbedding(embedding)) {
        console.log(`[MIGRATION] Embedding not cached for "${tag}". Computing dynamically...`);
        try {
          embedding = await embeddingService.getEmbedding(tag, 'passage');
        } catch (err) {
          console.error(`[MIGRATION] Failed to compute embedding for tag "${tag}":`, err);
          failedTags.push(tag);
          continue;
        }
      }
      if (!isValidEmbedding(embedding)) {
        failedTags.push(tag);
        continue;
      }
      tagBatch.push({ tag, embedding });
    }

    if (failedTags.length > 0 || tagBatch.length !== tags.length) {
      throw new Error(
        `Embedding generation incomplete: ${tagBatch.length}/${tags.length} tags ready, ${failedTags.length} failed.`
      );
    }

    // Write Tag nodes in batches
    const batchSize = 100;
    for (let i = 0; i < tagBatch.length; i += batchSize) {
      const batch = tagBatch.slice(i, i + batchSize);
      await neo4jService.run(`
        UNWIND $batch AS entry
        MERGE (t:Tag {name: entry.tag})
        SET t.embedding = entry.embedding
      `, { batch });
      console.log(`[MIGRATION] Created ${Math.min(i + batchSize, tagBatch.length)} / ${tagBatch.length} Tag nodes.`);
    }

    // 6. Create HAS_TAG relationships by aggregating TAGGED relations
    console.log('[MIGRATION] Creating [:HAS_TAG] relationships...');
    const relResult = await neo4jService.run(`
      MATCH (u:MovieLensUser)-[r:TAGGED]->(ml:MovieLensMovie)
      WITH ml, r.tag AS tagText, count(r) AS freq
      MATCH (t:Tag {name: tagText})
      MERGE (ml)-[h:HAS_TAG]->(t)
      SET h.frequency = toInteger(freq)
      RETURN count(h) AS relCount
    `);
    const relCount = relResult.records[0].get('relCount').toNumber();
    console.log(`[MIGRATION] Created ${relCount} [:HAS_TAG] relationships.`);
    if (relCount !== expectedRelationshipCount) {
      throw new Error(
        `HAS_TAG materialization incomplete: expected ${expectedRelationshipCount}, found ${relCount}.`
      );
    }

    console.log('[MIGRATION] Computing global tag IDF weights...');
    await neo4jService.run(`
      MATCH (movie:MovieLensMovie)
      WITH count(movie) AS totalMovies
      MATCH (tag:Tag)
      OPTIONAL MATCH (tag)<-[:HAS_TAG]-(taggedMovie:MovieLensMovie)
      WITH tag, totalMovies, count(DISTINCT taggedMovie) AS documentFrequency
      SET
        tag.documentFrequency = documentFrequency,
        tag.idf = log((toFloat(totalMovies) + 1.0) /
          (toFloat(documentFrequency) + 1.0)) + 1.0
    `);

    // 7. Store totalTagCount on (ml:MovieLensMovie) nodes to optimize scoring calculation
    console.log('[MIGRATION] Setting totalTagCount property on MovieLensMovie nodes...');
    const countResult = await neo4jService.run(`
      MATCH (ml:MovieLensMovie)
      OPTIONAL MATCH (ml)-[h:HAS_TAG]->()
      WITH ml, sum(h.frequency) AS totalCount
      SET ml.totalTagCount = toInteger(totalCount)
      RETURN count(ml) AS movieCount
    `);
    const movieCount = countResult.records[0].get('movieCount').toNumber();
    console.log(`[MIGRATION] Updated ${movieCount} MovieLensMovie nodes with totalTagCount.`);

    // 8. Verify materialized data and index readiness.
    const embeddedTagResult = await neo4jService.run(`
      MATCH (t:Tag)
      WHERE t.name IN $tags AND t.embedding IS NOT NULL
      RETURN count(t) AS embeddedTagCount
    `, { tags });
    const embeddedTagCount = toNativeNumber(
      embeddedTagResult.records[0].get('embeddedTagCount')
    );
    if (embeddedTagCount !== tags.length) {
      throw new Error(
        `Tag materialization incomplete: expected ${tags.length}, found ${embeddedTagCount}.`
      );
    }

    console.log('[MIGRATION] Waiting for vector index "tag_embeddings"...');
    await waitForVectorIndex();
    console.log('[MIGRATION] Semantic graph and vector index are ready.');

    console.log('==================================================');
    console.log('[MIGRATION] Migration Completed Successfully.');
    console.log('==================================================');
  } catch (err) {
    console.error('[MIGRATION] Migration failed:', err);
    throw err;
  }
}

if (require.main === module) {
  migrate().then(() => process.exit(0)).catch(() => process.exit(1));
}

module.exports = migrate;
