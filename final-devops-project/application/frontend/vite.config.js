import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// In development `npm run dev` serves the UI on :5173 and proxies /api to the
// backend, exactly like nginx does in the container. Override the target with
// VITE_API_PROXY=http://host:port when the backend runs somewhere else.
const apiTarget = process.env.VITE_API_PROXY || 'http://localhost:8000';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': { target: apiTarget, changeOrigin: true },
    },
  },
  build: {
    outDir: 'dist',
    sourcemap: false,
  },
});
