const { randomUUID } = require('node:crypto');
const neo4jService = require('./neo4jService');
const socketService = require('./socketService');

const histories = new Map();
const TTL_MS = 30 * 60 * 1000;
const MAX_USERS = 100;
const MAX_ACTIONS = 30;

function enabled() {
  return String(process.env.ENABLE_NEO4J_DEBUG || 'false').toLowerCase() === 'true';
}

function prune() {
  const now = Date.now();
  for (const [uid, history] of histories) {
    if (now - history.touchedAt > TTL_MS) histories.delete(uid);
  }
}

function getHistory(uid) {
  prune();
  return histories.get(uid)?.entries || [];
}

function record(uid, entry) {
  prune();
  const entries = getHistory(uid);
  histories.delete(uid);
  histories.set(uid, { touchedAt: Date.now(), entries: [entry, ...entries].slice(0, MAX_ACTIONS) });
  while (histories.size > MAX_USERS) histories.delete(histories.keys().next().value);
  // Push is only a wake-up signal: the client re-reads the full history from
  // /debug/neo4j/live, so a lost event never loses a trace.
  if (socketService.getIo()) {
    socketService.emitToUser(uid, 'neo4j_live_action', {
      id: entry.id,
      action: entry.action,
      tmdbId: entry.tmdbId,
      title: entry.title,
      status: entry.status,
      httpStatus: entry.httpStatus,
      durationMs: entry.durationMs,
      startedAt: entry.startedAt,
      transactionStatuses: entry.transactions.map((tx) => tx.status),
      queryCount: entry.queries.length,
    });
  }
}

// Wrap only movie actions/library routes, after authentication. Diagnostic
// polling is deliberately not captured and never recalculates recommendations.
function traceAction(action, handler) {
  return async (req, res, next) => {
    const uid = req.user?.uid || req.user?.sub;
    if (!enabled() || !uid) return handler(req, res, next);
    const queries = [];
    queries.captureState = true;
    queries.batchId = typeof req.body?.recommendationBatchId === 'string'
      ? req.body.recommendationBatchId : null;
    const startedAt = Date.now();
    const entry = {
      id: randomUUID(), action,
      tmdbId: req.params?.tmdbId || null,
      endpoint: `${req.method} ${req.path}`,
      startedAt: new Date(startedAt).toISOString(),
    };
    try {
      await neo4jService.captureQueryTrace(() => handler(req, res, next), queries);
    } catch (error) {
      entry.error = error.message;
      next(error);
    } finally {
      const transactions = queries.transactions || [];
      const lastTransaction = transactions[transactions.length - 1];
      record(uid, {
        ...entry,
        title: lastTransaction?.after?.title || lastTransaction?.before?.title || null,
        status: entry.error || res.statusCode >= 400 ? 'error' : 'completed',
        httpStatus: res.statusCode,
        durationMs: Date.now() - startedAt,
        queries: [...queries],
        transactions,
        queryLimitReached: queries.length >= 100,
      });
    }
  };
}

module.exports = { traceAction, getHistory };
