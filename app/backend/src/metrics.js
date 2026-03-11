'use strict';
const client = require('prom-client');

const register = new client.Registry();

// Métriques système par défaut (CPU, mémoire, event loop…)
client.collectDefaultMetrics({ register });

// ── Métriques métier ──────────────────────────────────────────────────────────

/** Compteur : nombre de pixels posés (label par couleur) */
const pixelsPlacedTotal = new client.Counter({
  name:       'pixels_placed_total',
  help:       'Total number of pixels placed',
  labelNames: ['color'],
  registers:  [register],
});

/** Gauge : connexions WebSocket actives */
const wsConnectionsActive = new client.Gauge({
  name:      'ws_connections_active',
  help:      'Number of active WebSocket connections',
  registers: [register],
});

/** Histogramme : latence des requêtes HTTP par route */
const httpRequestDuration = new client.Histogram({
  name:       'api_request_duration_seconds',
  help:       'Duration of HTTP API requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets:    [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
  registers:  [register],
});

/** Histogramme : latence des requêtes PostgreSQL */
const dbQueryDuration = new client.Histogram({
  name:       'db_query_duration_seconds',
  help:       'Duration of PostgreSQL queries in seconds',
  labelNames: ['operation'],
  buckets:    [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1],
  registers:  [register],
});

module.exports = {
  register,
  pixelsPlacedTotal,
  wsConnectionsActive,
  httpRequestDuration,
  dbQueryDuration,
};
