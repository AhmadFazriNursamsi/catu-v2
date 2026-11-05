import { createHash, timingSafeEqual } from 'node:crypto';

/** Panjang minimum token unggah APK; token pendek dianggap tidak dikonfigurasi (fitur nonaktif). */
export const MIN_UPLOAD_TOKEN_LENGTH = 32;

/**
 * Token unggah APK khusus untuk CI (env APK_UPLOAD_TOKEN): hanya membuka endpoint unggah APK, bukan akun Admin.
 * Perbandingan waktu-konstan atas digest SHA-256 agar panjang token tidak bocor.
 */
export function uploadTokenMatches(given: unknown, configured: string | undefined): boolean {
  if (!configured || configured.length < MIN_UPLOAD_TOKEN_LENGTH) return false;
  if (typeof given !== 'string' || given.length === 0) return false;
  const a = createHash('sha256').update(given).digest();
  const b = createHash('sha256').update(configured).digest();
  return timingSafeEqual(a, b);
}
