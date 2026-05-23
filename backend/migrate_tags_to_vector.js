const fs = require('fs');
const path = require('path');
const neo4jService = require('./neo4jService');
const embeddingService = require('./embeddingService');

const CACHE_FILE = path.join(__dirname, 'data', 'tag_embeddings_multilingual_cache.json');

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
    for (const tag of tags) {
      let embedding = cachedEmbeddings[tag];
      if (!embedding) {
        console.log(`[MIGRATION] Embedding not cached for "${tag}". Computing dynamically...`);
        try {
          embedding = await embeddingService.getEmbedding(tag, 'passage');
        } catch (err) {
          console.error(`[MIGRATION] Failed to compute embedding for tag "${tag}":`, err);
          continue;
        }
      }
      tagBatch.push({ tag, embedding });
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

    // 8. Verify index state
    console.log('[MIGRATION] Checking vector index population state...');
    const indexCheck = await neo4jService.run('SHOW INDEXES YIELD name, type, state, populationPercent');
    indexCheck.records.forEach(r => {
      if (r.get('name') === 'tag_embeddings') {
        console.log(`[MIGRATION] Index "${r.get('name')}": Type: ${r.get('type')}, State: ${r.get('state')}, Progress: ${r.get('populationPercent')}%`);
      }
    });

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
