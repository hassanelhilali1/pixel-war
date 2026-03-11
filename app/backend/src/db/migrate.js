'use strict';
const { pool } = require('./pool');

const MIGRATION_SQL = `
  CREATE TABLE IF NOT EXISTS pixels (
    x          INTEGER  NOT NULL,
    y          INTEGER  NOT NULL,
    color      CHAR(7)  NOT NULL DEFAULT '#FFFFFF',
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (x, y)
  );

  CREATE INDEX IF NOT EXISTS pixels_updated_at_idx ON pixels (updated_at DESC);
`;

async function migrate() {
  const client = await pool.connect();
  try {
    console.log('[DB] Running migrations…');
    await client.query(MIGRATION_SQL);
    console.log('[DB] Migrations complete ✓');
  } catch (err) {
    console.error('[DB] Migration failed:', err.message);
    throw err;
  } finally {
    client.release();
  }
}

module.exports = { migrate };
