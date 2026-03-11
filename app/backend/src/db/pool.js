'use strict';
const { Pool } = require('pg');

// on peut se connecter soit avec DATABASE_URL soit avec les variables separees
const config = process.env.DATABASE_URL
  ? { connectionString: process.env.DATABASE_URL }
  : {
      host:     process.env.DB_HOST     || 'localhost',
      port:     parseInt(process.env.DB_PORT || '5432', 10),
      user:     process.env.POSTGRES_USER     || 'pixelwar',
      password: process.env.POSTGRES_PASSWORD || 'pixelwar',
      database: process.env.POSTGRES_DB       || 'pixelwar',
    };

const pool = new Pool({
  ...config,
  max:                    10,
  idleTimeoutMillis:      30_000,
  connectionTimeoutMillis: 2_000,
});

pool.on('error', (err) => {
  console.error('[DB] Unexpected pool error:', err.message);
});

module.exports = { pool };
