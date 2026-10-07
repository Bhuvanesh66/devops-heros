'use strict';

const express = require('express');
const helmet = require('helmet');
const { createNotesStore, validateNote } = require('./notesStore');
const pkg = require('../package.json');

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function createApp({ store = createNotesStore() } = {}) {
  const app = express();
  const startedAt = Date.now();

  app.disable('x-powered-by');
  app.use(helmet());
  // Small body limit: notes are short, so anything bigger is rejected early.
  app.use(express.json({ limit: '10kb' }));

  app.get('/', (req, res) => {
    res.json({
      service: pkg.name,
      version: pkg.version,
      message: 'Session 17 DevSecOps Notes API',
      endpoints: ['GET /health', 'GET /api/notes', 'POST /api/notes', 'GET /api/notes/:id', 'PUT /api/notes/:id', 'DELETE /api/notes/:id'],
    });
  });

  app.get('/health', (req, res) => {
    res.json({ status: 'ok', uptimeSeconds: Math.round((Date.now() - startedAt) / 1000) });
  });

  const router = express.Router();

  router.param('id', (req, res, next, id) => {
    if (!UUID_RE.test(id)) {
      return res.status(400).json({ error: 'id must be a UUID' });
    }
    return next();
  });

  router.get('/', (req, res) => {
    const notes = store.list();
    res.json({ count: notes.length, notes });
  });

  router.post('/', (req, res) => {
    const errors = validateNote(req.body);
    if (errors.length > 0) {
      return res.status(400).json({ errors });
    }
    const note = store.create(req.body);
    return res.status(201).location(`/api/notes/${note.id}`).json(note);
  });

  router.get('/:id', (req, res) => {
    const note = store.get(req.params.id);
    if (!note) return res.status(404).json({ error: 'note not found' });
    return res.json(note);
  });

  router.put('/:id', (req, res) => {
    const errors = validateNote(req.body, { partial: true });
    if (errors.length > 0) {
      return res.status(400).json({ errors });
    }
    const note = store.update(req.params.id, req.body);
    if (!note) return res.status(404).json({ error: 'note not found' });
    return res.json(note);
  });

  router.delete('/:id', (req, res) => {
    if (!store.remove(req.params.id)) {
      return res.status(404).json({ error: 'note not found' });
    }
    return res.status(204).end();
  });

  app.use('/api/notes', router);

  app.use((req, res) => {
    res.status(404).json({ error: 'route not found' });
  });

  // Central error handler: never leak stack traces to the client.
  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    const status = Number.isInteger(err.status) && err.status >= 400 && err.status < 500 ? err.status : 500;
    const message = status === 500 ? 'internal server error' : 'invalid request';
    res.status(status).json({ error: message });
  });

  return app;
}

module.exports = { createApp };
