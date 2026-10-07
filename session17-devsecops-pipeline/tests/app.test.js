'use strict';

const request = require('supertest');
const { createApp } = require('../src/app');
const { createNotesStore, validateNote, TITLE_MAX } = require('../src/notesStore');

describe('Notes API', () => {
  let app;
  let store;

  beforeEach(() => {
    store = createNotesStore();
    app = createApp({ store });
  });

  test('GET / returns service info', async () => {
    const res = await request(app).get('/');
    expect(res.status).toBe(200);
    expect(res.body.service).toBe('session17-devsecops-api');
    expect(res.body.endpoints).toContain('GET /health');
  });

  test('GET /health returns ok', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(typeof res.body.uptimeSeconds).toBe('number');
  });

  test('responses carry security headers and hide the framework', async () => {
    const res = await request(app).get('/health');
    expect(res.headers['x-powered-by']).toBeUndefined();
    expect(res.headers['x-content-type-options']).toBe('nosniff');
    expect(res.headers['content-security-policy']).toBeDefined();
  });

  test('GET /api/notes starts empty', async () => {
    const res = await request(app).get('/api/notes');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ count: 0, notes: [] });
  });

  test('POST /api/notes creates a note', async () => {
    const res = await request(app).post('/api/notes').send({ title: '  Buy milk ', body: '2 litres' });
    expect(res.status).toBe(201);
    expect(res.body.title).toBe('Buy milk');
    expect(res.body.body).toBe('2 litres');
    expect(res.body.id).toMatch(/^[0-9a-f-]{36}$/);
    expect(res.headers.location).toBe(`/api/notes/${res.body.id}`);

    const list = await request(app).get('/api/notes');
    expect(list.body.count).toBe(1);
  });

  test('POST /api/notes rejects a missing title', async () => {
    const res = await request(app).post('/api/notes').send({ body: 'no title' });
    expect(res.status).toBe(400);
    expect(res.body.errors).toContain('title is required');
  });

  test('POST /api/notes rejects an over-long title', async () => {
    const res = await request(app).post('/api/notes').send({ title: 'x'.repeat(TITLE_MAX + 1) });
    expect(res.status).toBe(400);
    expect(res.body.errors[0]).toMatch(/at most/);
  });

  test('POST /api/notes rejects malformed JSON without leaking details', async () => {
    const res = await request(app)
      .post('/api/notes')
      .set('Content-Type', 'application/json')
      .send('{"title": ');
    expect(res.status).toBe(400);
    expect(res.body).toEqual({ error: 'invalid request' });
  });

  test('GET /api/notes/:id returns a note, 404 when missing, 400 for a bad id', async () => {
    const created = await request(app).post('/api/notes').send({ title: 'Read book' });
    const ok = await request(app).get(`/api/notes/${created.body.id}`);
    expect(ok.status).toBe(200);
    expect(ok.body.title).toBe('Read book');

    const missing = await request(app).get('/api/notes/00000000-0000-4000-8000-000000000000');
    expect(missing.status).toBe(404);

    const bad = await request(app).get('/api/notes/not-a-uuid');
    expect(bad.status).toBe(400);
  });

  test('PUT /api/notes/:id updates a note', async () => {
    const created = await request(app).post('/api/notes').send({ title: 'Draft', body: 'v1' });
    const res = await request(app).put(`/api/notes/${created.body.id}`).send({ body: 'v2' });
    expect(res.status).toBe(200);
    expect(res.body.title).toBe('Draft');
    expect(res.body.body).toBe('v2');

    const empty = await request(app).put(`/api/notes/${created.body.id}`).send({});
    expect(empty.status).toBe(400);

    const missing = await request(app).put('/api/notes/00000000-0000-4000-8000-000000000000').send({ title: 'x' });
    expect(missing.status).toBe(404);
  });

  test('DELETE /api/notes/:id removes a note', async () => {
    const created = await request(app).post('/api/notes').send({ title: 'Temp' });
    const del = await request(app).delete(`/api/notes/${created.body.id}`);
    expect(del.status).toBe(204);

    const again = await request(app).delete(`/api/notes/${created.body.id}`);
    expect(again.status).toBe(404);
  });

  test('unknown routes return JSON 404', async () => {
    const res = await request(app).get('/does-not-exist');
    expect(res.status).toBe(404);
    expect(res.body.error).toBe('route not found');
  });
});

describe('validateNote', () => {
  test('rejects non-object payloads', () => {
    expect(validateNote(null)).toEqual(['request body must be a JSON object']);
    expect(validateNote([])).toEqual(['request body must be a JSON object']);
  });

  test('checks field types', () => {
    expect(validateNote({ title: '   ' })).toContain('title must be a non-empty string');
    expect(validateNote({ title: 'ok', body: 42 })).toContain('body must be a string');
    expect(validateNote({ title: 'ok', body: 'y'.repeat(1001) })[0]).toMatch(/body must be at most/);
    expect(validateNote({ title: 'ok', body: 'fine' })).toEqual([]);
  });
});
