'use strict';
require('dotenv').config();

const express    = require('express');
const http       = require('http');
const { Server } = require('socket.io');
const cors       = require('cors');
const helmet     = require('helmet');

const { migrate }           = require('./db/migrate');
const healthRouter          = require('./routes/health');
const createGridRouter      = require('./routes/grid');
const {
  register,
  httpRequestDuration,
  wsConnectionsActive,
} = require('./metrics');

const PORT         = parseInt(process.env.PORT || '3000', 10);
const FRONTEND_URL = process.env.FRONTEND_URL || '*';

const app    = express();
const server = http.createServer(app);
const io     = new Server(server, {
  cors: { origin: FRONTEND_URL, methods: ['GET', 'POST'] },
});

// ── Middlewares ───────────────────────────────────────────────────────────────
app.use(helmet({ contentSecurityPolicy: false }));
app.use(cors({ origin: FRONTEND_URL }));
app.use(express.json({ limit: '10kb' }));

// Instrumentation : durée des requêtes HTTP
app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer({ method: req.method, route: req.path });
  res.on('finish', () => end({ status_code: String(res.statusCode) }));
  next();
});

// ── Routes ────────────────────────────────────────────────────────────────────
app.use('/api', healthRouter);
app.use('/api', createGridRouter(io));

// Endpoint Prometheus
app.get('/metrics', async (_req, res) => {
  try {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  } catch (err) {
    res.status(500).end(err.message);
  }
});

// ── WebSocket ─────────────────────────────────────────────────────────────────
io.on('connection', (socket) => {
  wsConnectionsActive.inc();
  console.log(`[WS] Client connected:    ${socket.id}`);

  socket.on('disconnect', (reason) => {
    wsConnectionsActive.dec();
    console.log(`[WS] Client disconnected: ${socket.id} (${reason})`);
  });
});

// ── Bootstrap ─────────────────────────────────────────────────────────────────
async function bootstrap() {
  await migrate();
  server.listen(PORT, () => {
    console.log(`  Backend listening on port ${PORT}`);
    console.log(`    Health  → http://localhost:${PORT}/api/health`);
    console.log(`    Metrics → http://localhost:${PORT}/metrics`);
  });
}

if (require.main === module) {
  bootstrap().catch((err) => {
    console.error('  Bootstrap failed:', err);
    process.exit(1);
  });
}

module.exports = { app, server, io };
