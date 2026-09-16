import { defineConfig } from 'vite';

const allowedHosts = (process.env.ADMIN_WEB_ALLOWED_HOSTS || '')
  .split(',')
  .map((host) => host.trim())
  .filter(Boolean);

export default defineConfig({
  server: {
    allowedHosts,
    strictPort: true,
  },
});
