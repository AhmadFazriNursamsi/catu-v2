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

// Jalur lingkungan DEV di domain yang sama (opsional). Hanya aktif bila kedua variabel diisi; tanpa itu perilaku tidak berubah.
//   /dev/api/*  -> DEV_BACKEND_URL (awalan /dev/api dibuang)    /dev/*  -> DEV_WEB_URL (awalan /dev dibuang)
// Urutan penting: aturan yang lebih spesifik (/dev/api) harus lebih dulu.
const devBackend = process.env.DEV_BACKEND_URL;
const devWeb = process.env.DEV_WEB_URL;
if (devBackend && devWeb) {
  const devApiProxy = {
    '^/dev/api(/|$)': { target: devBackend, changeOrigin: true, rewrite: (path) => path.replace(/^\/dev\/api/, '') || '/' },
    '^/dev(/|$)': { target: devWeb, changeOrigin: true, rewrite: (path) => path.replace(/^\/dev/, '') || '/' },
  };
  Object.assign(proxyConfig, devApiProxy);
}

// Mode produksi masih dilayani server Vite: matikan HMR/WebSocket dan jangan suntikkan /@vite/client,
// supaya browser pengunjung tidak terus mencoba menyambung WebSocket (galat "failed to connect to websocket").
const noDevClient = {
  name: 'catu-no-dev-client',
  apply: 'serve',
  transformIndexHtml: {
    order: 'post',
    handler: (html) => html.replace(/<script type="module" src="[^"]*\/@vite\/client"><\/script>\s*/g, ''),
  },
};

export default defineConfig(({ mode }) => ({
  plugins: mode === 'production' ? [noDevClient] : [],
  server: {
    allowedHosts,
    strictPort: true,
    proxy: proxyConfig,
    ...(mode === 'production' ? { hmr: false, ws: false } : {}),
  },
}));
