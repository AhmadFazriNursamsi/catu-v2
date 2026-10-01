import { defineConfig } from 'vite';

const allowedHosts = (process.env.ADMIN_WEB_ALLOWED_HOSTS || '')
  .split(',')
  .map((host) => host.trim())
  .filter(Boolean);

const backendTarget = process.env.INTERNAL_BACKEND_URL || 'http://backend:3000';

const apiPaths = [
  '/api',
  '/auth',
  '/master',
  '/orders',
  '/chat',
  '/activity-logs',
  '/news',
  '/test-runner',
  '/notifications',
  '/assignments',
  '/public',
];

const proxyConfig = {};
for (const p of apiPaths) {
  proxyConfig[p] = {
    target: backendTarget,
    changeOrigin: true,
  };
}

export default defineConfig({
  server: {
    allowedHosts,
    strictPort: true,
    proxy: proxyConfig,
  },
});
