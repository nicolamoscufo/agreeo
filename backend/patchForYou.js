const fs = require('fs');
let code = fs.readFileSync('../backend/movieController.js', 'utf8');

const oldCodeStart = '  if (enrichedCandidates.length === 0) {';
const oldCodeEnd = '    };';

const lines = code.split('\n');
const startIdx = lines.findIndex(l => l.includes(oldCodeStart));
const endIdx = lines.findIndex((l, i) => i > startIdx && l.includes(oldCodeEnd) && lines[i+1].includes('  }'));

const newCode = `  if (enrichedCandidates.length === 0) {
    const exploratoryCandidates = await movieRepository.getExploratoryCandidates(uid, { limit: safeLimit });
    const fallbackCandidates = exploratoryCandidates.filter(c => c && c.tmdbId != null).map((c) => ({
      ...c,
      reason: c.reason || 'We are still learning your tastes. Try rating more movies.',
      source: 'exploratory'
    }));
    
    if (fallbackCandidates.length === 0) {
      return {
        results: [],
        meta: {
          fallbackUsed: false,
          fallbackReason: null,
          fallbackStrategy: null,
        },
        candidates: [],
      };
    }

    const hydratedPool = await hydrateRecommendations(fallbackCandidates, { limit: safeLimit });
    return {
      results: hydratedPool,
      meta: {
        fallbackUsed: true,
        fallbackReason: 'No personalized recommendations available yet.',
        fallbackStrategy: 'exploratory',
      },
      candidates: fallbackCandidates,
    };
  }`;

lines.splice(startIdx, endIdx - startIdx + 2, newCode);
fs.writeFileSync('../backend/movieController.js', lines.join('\n'));
console.log('Patched');
