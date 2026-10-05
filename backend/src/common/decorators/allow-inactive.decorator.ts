import { SetMetadata } from '@nestjs/common';

export const ALLOW_INACTIVE_KEY = 'allowInactiveAccount';

/**
 * Endpoint yang tetap boleh diakses akun yang belum disetujui / ditolak (mis. cek status, notifikasi persetujuan).
 * Semua endpoint lain menolak akun yang tidak berstatus APPROVED. Menambah daftar ini wajib disengaja.
 */
export const AllowInactiveAccount = () => SetMetadata(ALLOW_INACTIVE_KEY, true);
