'use strict';

const { randomUUID } = require('node:crypto');

const TITLE_MAX = 100;
const BODY_MAX = 1000;

// Validates a note payload. Returns an array of error messages (empty when valid).
// When `partial` is true (PATCH-style update) missing fields are allowed.
function validateNote(payload, { partial = false } = {}) {
  const errors = [];

  if (payload === null || typeof payload !== 'object' || Array.isArray(payload)) {
    return ['request body must be a JSON object'];
  }

  const { title, body } = payload;

  if (title === undefined) {
    if (!partial) errors.push('title is required');
  } else if (typeof title !== 'string' || title.trim().length === 0) {
    errors.push('title must be a non-empty string');
  } else if (title.length > TITLE_MAX) {
    errors.push(`title must be at most ${TITLE_MAX} characters`);
  }

  if (body !== undefined) {
    if (typeof body !== 'string') {
      errors.push('body must be a string');
    } else if (body.length > BODY_MAX) {
      errors.push(`body must be at most ${BODY_MAX} characters`);
    }
  }

  if (partial && title === undefined && body === undefined) {
    errors.push('at least one of title or body is required');
  }

  return errors;
}

// Simple in-memory store. A Map keyed by UUID avoids prototype-pollution issues
// that a plain object keyed by user input could have.
function createNotesStore() {
  const notes = new Map();

  return {
    list() {
      return Array.from(notes.values());
    },

    get(id) {
      return notes.get(id) || null;
    },

    create({ title, body = '' }) {
      const now = new Date().toISOString();
      const note = { id: randomUUID(), title: title.trim(), body, createdAt: now, updatedAt: now };
      notes.set(note.id, note);
      return note;
    },

    update(id, { title, body }) {
      const existing = notes.get(id);
      if (!existing) return null;
      const updated = {
        ...existing,
        title: title === undefined ? existing.title : title.trim(),
        body: body === undefined ? existing.body : body,
        updatedAt: new Date().toISOString(),
      };
      notes.set(id, updated);
      return updated;
    },

    remove(id) {
      return notes.delete(id);
    },

    clear() {
      notes.clear();
    },
  };
}

module.exports = { createNotesStore, validateNote, TITLE_MAX, BODY_MAX };
