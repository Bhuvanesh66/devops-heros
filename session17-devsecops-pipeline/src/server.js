'use strict';

const { createApp } = require('./app');

const port = Number.parseInt(process.env.PORT || '3000', 10);
const host = process.env.HOST || '0.0.0.0';

const server = createApp().listen(port, host, () => {
  console.log(`notes-api listening on http://${host}:${port}`);
});

// Kubernetes sends SIGTERM before killing a pod: finish in-flight requests first.
function shutdown(signal) {
  console.log(`${signal} received, shutting down`);
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(1), 10000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
