'use strict';
const express = require('express');
const { pool } = require('../db/pool');
const { pixelsPlacedTotal, dbQueryDuration } = require('../metrics');

const GRID_SIZE = parseInt(process.env.GRID_SIZE || '50', 10);
const HEX_COLOR_RE = /^#[0-9A-Fa-f]{6}$/;

/**
 * Valide les paramètres d'un pixel.
 * @returns {string|null} Message d'erreur ou null si valide.
 */
function validatePixel(x, y, color) {
  if (typeof x !== 'number' || typeof y !== 'number') return 'x et y doivent être des nombres';
  if (!Number.isInteger(x) || !Number.isInteger(y))   return 'x et y doivent être des entiers';
  if (x < 0 || y < 0)                                 return 'x et y doivent être positifs ou nuls';
  if (x >= GRID_SIZE || y >= GRID_SIZE)                return `x et y doivent être inférieurs à ${GRID_SIZE}`;
  if (!HEX_COLOR_RE.test(color))                       return 'color doit être une couleur hexadécimale (#RRGGBB)';
  return null;
}

/**
 * Crée le routeur de la grille.
 * @param {import('socket.io').Server} io
 */
function createGridRouter(io) {
  const router = express.Router();

  // ── GET /api/grid — retourne tous les pixels non-blancs ───────────────────
  router.get('/grid', async (_req, res) => {
    const end = dbQueryDuration.startTimer({ operation: 'select_grid' });
    try {
      const { rows } = await pool.query(
        'SELECT x, y, color FROM pixels ORDER BY updated_at DESC'
      );
      end();
      res.json(rows);
    } catch (err) {
      end();
      console.error('[GET /api/grid] DB error:', err.message);
      res.status(500).json({ error: 'Erreur lors de la récupération de la grille' });
    }
  });

  // ── PATCH /api/pixel — met à jour un pixel ────────────────────────────────
  router.patch('/pixel', async (req, res) => {
    const { x, y, color } = req.body;

    const validationError = validatePixel(x, y, color);
    if (validationError) {
      return res.status(400).json({ error: validationError });
    }

    const end = dbQueryDuration.startTimer({ operation: 'upsert_pixel' });
    try {
      await pool.query(
        `INSERT INTO pixels (x, y, color, updated_at)
         VALUES ($1, $2, $3, NOW())
         ON CONFLICT (x, y) DO UPDATE
           SET color      = EXCLUDED.color,
               updated_at = NOW()`,
        [x, y, color]
      );
      end();

      // Instrumentation Prometheus
      pixelsPlacedTotal.inc({ color });

      // Diffusion en temps réel à tous les clients connectés
      io.emit('pixel:update', { x, y, color });

      res.json({ x, y, color });
    } catch (err) {
      end();
      console.error('[PATCH /api/pixel] DB error:', err.message);
      res.status(500).json({ error: 'Erreur lors de la mise à jour du pixel' });
    }
  });

  return router;
}

module.exports = createGridRouter;
