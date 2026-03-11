'use strict';
const express = require('express');
const { pool } = require('../db/pool');

const router = express.Router();

router.get('/health', async (_req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({
      status:    'ok',
      timestamp: new Date().toISOString(),
      database:  'connected',
    });
  } catch (err) {
    res.status(503).json({
      status:    'error',
      timestamp: new Date().toISOString(),
      database:  'disconnected',
      error:     err.message,
    });
  }
});

module.exports = router;
