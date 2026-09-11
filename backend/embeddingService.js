const path = require('path');
const fs = require('fs');
const neo4jService = require('./neo4jService');

const MODEL_ID = process.env.EMBEDDING_MODEL_ID || 'Xenova/multilingual-e5-small';
const MODEL_REVISION = process.env.EMBEDDING_MODEL_REVISION || '761b726dd34fb83930e26aab4e9ac3899aa1fa78';
const CACHE_FILE = path.join(
  __dirname,
  'data',
  `tag_embeddings_${MODEL_REVISION.slice(0, 12)}.json`
);
let tagEmbeddings = {};
// We cache the in-flight promises (not the resolved values) so that concurrent
// first requests share a single import/model-load instead of each starting their
// own — the model load takes seconds and is far too expensive to duplicate.
let pipelinePromise = null;
let extractorPromise = null;

/**
 * Dynamically imports and configures @xenova/transformers (once).
 */
function loadTransformers() {
  if (!pipelinePromise) {
    pipelinePromise = (async () => {
      console.log('[EmbeddingService] Dynamically importing @xenova/transformers...');
      const transformers = await import('@xenova/transformers');
      transformers.env.allowLocalModels = false;
      return transformers.pipeline;
    })().catch((err) => {
      pipelinePromise = null; // allow a later retry instead of caching the failure
      throw err;
    });
  }
  return pipelinePromise;
}

/**
 * Returns the feature extraction pipeline instance, caching it after creation.
 */
function getExtractor() {
  if (!extractorPromise) {
    extractorPromise = (async () => {
      const pipeline = await loadTransformers();
      console.log(`[EmbeddingService] Loading ${MODEL_ID}@${MODEL_REVISION}...`);
      const ext = await pipeline('feature-extraction', MODEL_ID, {
        revision: MODEL_REVISION,
      });
      console.log('[EmbeddingService] Model loaded successfully.');
      return ext;
    })().catch((err) => {
      extractorPromise = null; // allow a later retry instead of caching the failure
      throw err;
    });
  }
  return extractorPromise;
}

/**
 * Computes the embedding vector (384 dimensions) for a given text.
 * Prepends 'query: ' or 'passage: ' instruction prefix required by E5 models.
 */
async function getEmbedding(text, type = 'query') {
  const ext = await getExtractor();
  const prefix = type === 'passage' ? 'passage: ' : 'query: ';
  const output = await ext(prefix + text, { pooling: 'mean', normalize: true });
  return Array.from(output.data);
}

/**
 * Cosine similarity between two vectors.
 */
function cosineSimilarity(vecA, vecB) {
  let dotProduct = 0;
  let normA = 0;
  let normB = 0;
  for (let i = 0; i < vecA.length; i++) {
    dotProduct += vecA[i] * vecB[i];
    normA += vecA[i] * vecA[i];
    normB += vecB[i] * vecB[i];
  }
  if (normA === 0 || normB === 0) return 0;
  return dotProduct / (Math.sqrt(normA) * Math.sqrt(normB));
}

/**
 * Initializes the tag embeddings in-memory cache.
 * Loads from disk if it exists, otherwise queries Neo4j and computes them.
 */
async function initialize() {
  console.log('[EmbeddingService] Initializing...');
  
  // Ensure directory exists
  const dir = path.dirname(CACHE_FILE);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  // Try loading from file cache
  if (fs.existsSync(CACHE_FILE)) {
    try {
      console.log('[EmbeddingService] Loading tag embeddings from cache file...');
      const raw = fs.readFileSync(CACHE_FILE, 'utf8');
      tagEmbeddings = JSON.parse(raw);
      console.log(`[EmbeddingService] Loaded ${Object.keys(tagEmbeddings).length} tags from cache.`);
      return;
    } catch (e) {
      console.error('[EmbeddingService] Failed to read cache file, recomputing...', e);
    }
  }

  // Retrieve unique tags from Neo4j
  try {
    console.log('[EmbeddingService] Querying Neo4j for unique tags...');
    const result = await neo4jService.run(`
      MATCH ()-[r:TAGGED]->()
      WHERE r.tag IS NOT NULL
      RETURN DISTINCT r.tag AS tag
    `);

    const tags = result.records.map(rec => rec.get('tag')).filter(Boolean);
    console.log(`[EmbeddingService] Found ${tags.length} unique tags. Generating embeddings...`);

    const ext = await getExtractor();

    // Process in sequential batches to prevent CPU starvation or memory limits
    const batchSize = 25;
    for (let i = 0; i < tags.length; i += batchSize) {
      const batch = tags.slice(i, i + batchSize);
      await Promise.all(batch.map(async (tag) => {
        try {
          tagEmbeddings[tag] = await getEmbedding(tag, 'passage');
        } catch (err) {
          console.error(`[EmbeddingService] Error embedding tag "${tag}":`, err);
        }
      }));
      if (i % 100 === 0 || i + batchSize >= tags.length) {
        console.log(`[EmbeddingService] Embedded ${Math.min(i + batchSize, tags.length)} / ${tags.length} tags.`);
      }
    }

    // Save cache to disk
    fs.writeFileSync(CACHE_FILE, JSON.stringify(tagEmbeddings), 'utf8');
    console.log('[EmbeddingService] Saved tag embeddings cache to disk.');
  } catch (err) {
    console.error('[EmbeddingService] Initialization query/embedding failed:', err);
    throw err;
  }
}

/**
 * Finds unique tags semantically matching the query.
 * Returns an array of objects: { tag: string, similarity: number }
 */
async function findSimilarTags(queryText, topK = 15, similarityThreshold = 0.3) {
  console.log(`[EmbeddingService] Analyzing query vibe: "${queryText}"`);
  const queryEmbedding = await getEmbedding(queryText);

  console.log(`[EmbeddingService] Querying Neo4j Vector Index 'tag_embeddings' (topK: ${topK}, threshold: ${similarityThreshold})...`);
  const result = await neo4jService.run(`
    CALL db.index.vector.queryNodes('tag_embeddings', toInteger($topK), $queryEmbedding)
    YIELD node AS tagNode, score AS similarity
    RETURN tagNode.name AS tag, similarity, tagNode.embedding AS embedding
  `, {
    topK,
    queryEmbedding
  });

  const matches = result.records.map(rec => {
    const similarityVal = rec.get('similarity');
    const similarity = typeof similarityVal?.toNumber === 'function' ? similarityVal.toNumber() : Number(similarityVal);
    // Convert Neo4j vector cosine similarity score range [0, 1] back to standard cosine similarity range [-1, 1]
    const stdSimilarity = 2 * similarity - 1;
    return {
      tag: rec.get('tag'),
      similarity: stdSimilarity,
      embedding: rec.get('embedding'),
    };
  });

  const filteredMatches = matches.filter(m => m.similarity >= similarityThreshold);
  console.log(`[EmbeddingService] Best semantic matches:`, filteredMatches.map(r => `${r.tag} (${r.similarity.toFixed(2)})`).join(', '));
  return filteredMatches;
}

module.exports = {
  CACHE_FILE,
  MODEL_ID,
  MODEL_REVISION,
  initialize,
  findSimilarTags,
  getEmbedding,
};
