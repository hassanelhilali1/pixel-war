import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    // Proxy vers le backend en dev local
    proxy: {
      '/api': {
        target:      'http://localhost:3000',
        changeOrigin: true,
      },
      '/socket.io': {
        target:      'http://localhost:3000',
        ws:           true,
        changeOrigin: true,
      },
    },
  },
  build: {
    outDir:    'dist',
    sourcemap: false,
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom', 'socket.io-client'],
        },
      },
    },
  },
});
