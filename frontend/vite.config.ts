import { defineConfig } from 'vite';

export default defineConfig({
  server: {
    port: parseInt(process.env.VITE_PORT as any) || 8080
  },
  build: {
    sourcemap: false,
  }
})
