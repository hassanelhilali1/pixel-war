'use strict';
const client = require('prom-client');

const register = new client.Registry();

// metriques par default genre cpu, ram etc
client.collectDefaultMetrics({ register });

// nos metriques custom

// compteur de pixels posés
const pixelsPlacedTotal = new client.Counter({
  name:       'pixels_placed_total',
  help:       'Total number of pixels placed',
  labelNames: ['color'],
  registers:  [register],
});

// nombre de gens connectés en websocket
const wsConnectionsActive = new client.Gauge({
  name:      'ws_connections_active',
  help:      'Number of active WebSocket connections',
  registers: [register],
});

// temps de reponse des requetes http
const httpRequestDuration = new client.Histogram({
  name:       'api_request_duration_seconds',
  help:       'Duration of HTTP API requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets:    [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
  registers:  [register],
});

// temps des requetes sql
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
