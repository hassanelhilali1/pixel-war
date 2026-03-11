'use strict';
// Simuler l'environnement de test avant tout import
process.env.DATABASE_URL = 'postgresql://test:test@localhost/test_pixel_war';
process.env.GRID_SIZE    = '50';

// ── Mocks ─────────────────────────────────────────────────────────────────────
jest.mock('../db/pool', () => ({
  pool: { query: jest.fn(), connect: jest.fn() },
}));

jest.mock('../db/migrate', () => ({
  migrate: jest.fn().mockResolvedValue(undefined),
}));

const request   = require('supertest');
const { app }   = require('../index');
const { pool }  = require('../db/pool');

beforeEach(() => jest.clearAllMocks());

// ── /api/health ───────────────────────────────────────────────────────────────
describe('GET /api/health', () => {
  it('retourne 200 quand la DB répond', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });
    const res = await request(app).get('/api/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.database).toBe('connected');
  });

  it('retourne 503 quand la DB est indisponible', async () => {
    pool.query.mockRejectedValueOnce(new Error('Connection refused'));
    const res = await request(app).get('/api/health');
    expect(res.status).toBe(503);
    expect(res.body.status).toBe('error');
  });
});

// tests pour GET /api/grid
describe('GET /api/grid', () => {
  it('retourne un tableau de pixels', async () => {
    pool.query.mockResolvedValueOnce({
      rows: [{ x: 0, y: 0, color: '#FF0000' }],
    });
    const res = await request(app).get('/api/grid');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body[0]).toMatchObject({ x: 0, y: 0, color: '#FF0000' });
  });

  it('retourne 500 en cas d\'erreur DB', async () => {
    pool.query.mockRejectedValueOnce(new Error('DB down'));
    const res = await request(app).get('/api/grid');
    expect(res.status).toBe(500);
  });
});

// tests pour PATCH /api/pixel
describe('PATCH /api/pixel', () => {
  it('met à jour un pixel valide', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });
    const res = await request(app)
      .patch('/api/pixel')
      .send({ x: 5, y: 10, color: '#00FF00' });
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ x: 5, y: 10, color: '#00FF00' });
  });

  it('rejette une couleur invalide', async () => {
    const res = await request(app)
      .patch('/api/pixel')
      .send({ x: 0, y: 0, color: 'rouge' });
    expect(res.status).toBe(400);
  });

  it('rejette des coordonnées hors limites', async () => {
    const res = await request(app)
      .patch('/api/pixel')
      .send({ x: 999, y: 999, color: '#000000' });
    expect(res.status).toBe(400);
  });

  it('rejette des coordonnées négatives', async () => {
    const res = await request(app)
      .patch('/api/pixel')
      .send({ x: -1, y: 0, color: '#FFFFFF' });
    expect(res.status).toBe(400);
  });

  it('rejette des coordonnées non-numériques', async () => {
    const res = await request(app)
      .patch('/api/pixel')
      .send({ x: 'abc', y: 0, color: '#FFFFFF' });
    expect(res.status).toBe(400);
  });

  it('rejette des coordonnées décimales', async () => {
    const res = await request(app)
      .patch('/api/pixel')
      .send({ x: 1.5, y: 0, color: '#FF0000' });
    expect(res.status).toBe(400);
  });

  it('retourne 500 en cas d\'erreur DB', async () => {
    pool.query.mockRejectedValueOnce(new Error('DB error'));
    const res = await request(app)
      .patch('/api/pixel')
      .send({ x: 0, y: 0, color: '#FF0000' });
    expect(res.status).toBe(500);
  });
});
