import { Logger } from '@nestjs/common';
import type { CorsOptions } from '@nestjs/common/interfaces/external/cors-options.interface';

const logger = new Logger('BootstrapConfig');

export const isProduction = () => process.env.NODE_ENV === 'production';

/** Gagal cepat jika konfigurasi keamanan minimum tidak terpenuhi. */
export function assertSecureEnvironment(): void {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    throw new Error('JWT_SECRET wajib diisi. Aplikasi tidak dapat berjalan tanpa secret JWT.');
  }
  if (isProduction() && secret.length < 32) {
    throw new Error('JWT_SECRET production minimal 32 karakter.');
  }
}

/** Origin diizinkan via CORS_ORIGINS (dipisah koma). Tanpa Origin (mobile/curl) selalu diizinkan. */
export function buildCorsOptions(): CorsOptions {
  const allowed = (process.env.CORS_ORIGINS || '')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);

  if (allowed.length === 0) {
    if (isProduction()) {
      logger.warn('CORS_ORIGINS belum diatur di production: semua origin diizinkan. Isi dengan domain admin web.');
    }
    return { origin: true, methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS', credentials: false };
  }

  return {
    origin: (origin, callback) => {
      if (!origin || allowed.includes(origin)) return callback(null, true);
      return callback(new Error('Origin tidak diizinkan oleh kebijakan CORS'), false);
    },
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
    credentials: false,
  };
}

export const bodyLimit = () => process.env.BODY_LIMIT || '15mb';

/** Swagger aktif di luar production, atau jika ENABLE_SWAGGER=true. */
export const swaggerEnabled = () => !isProduction() || process.env.ENABLE_SWAGGER === 'true';

/** Proxy tepercaya (reverse proxy/Docker network) agar IP klien asli terbaca untuk rate limit. */
export const trustProxySetting = () => process.env.TRUST_PROXY || 'loopback, linklocal, uniquelocal';
