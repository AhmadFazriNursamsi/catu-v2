import { SetMetadata } from '@nestjs/common';

export const ALLOW_PASSWORD_CHANGE_KEY = 'allowPasswordChange';

/**
 * Endpoint yang tetap boleh diakses akun yang wajib mengganti kata sandi sementara (must_change_password).
 * Semua endpoint lain menolak sampai kata sandi diganti. Menambah daftar ini wajib disengaja.
 */
export const AllowPasswordChange = () => SetMetadata(ALLOW_PASSWORD_CHANGE_KEY, true);
