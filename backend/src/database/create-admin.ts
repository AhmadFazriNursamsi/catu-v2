import { Pool } from 'pg';
import * as bcrypt from 'bcrypt';
import { migrationPoolConfig } from './migrate';

/**
 * Membuat (atau mereset password) akun Admin / Super Admin. Pengganti akun bawaan yang dulu dibuat saat aplikasi start.
 * Password tidak pernah ada di kode atau di argumen baris perintah: dibaca dari environment.
 *
 *   ADMIN_PHONE=628xxxxxxxxxx ADMIN_PASSWORD='...' ADMIN_NAME='Nama Admin' ADMIN_ROLE=SUPERADMIN npm run db:create-admin
 *   Tambahkan ADMIN_RESET_PASSWORD=true untuk mengganti password akun yang sudah ada.
 */
export const ADMIN_ROLES = ['SUPERADMIN', 'ADMIN'] as const;
export const MIN_ADMIN_PASSWORD = 12;

export interface AdminInput {
  phone: string;
  password: string;
  name: string;
  role: string;
  email?: string;
  resetPassword?: boolean;
}

/** Mengembalikan pesan galat pertama, atau null bila isian sah. */
export function validateAdminInput(i: AdminInput): string | null {
  if (!/^62[0-9]{8,14}$/.test(i.phone)) return 'ADMIN_PHONE harus berformat 62xxxxxxxxxx (hanya angka, diawali 62).';
  if (!(ADMIN_ROLES as readonly string[]).includes(i.role)) return `ADMIN_ROLE harus salah satu dari: ${ADMIN_ROLES.join(', ')}.`;
  if (!i.name || i.name.trim().length < 3) return 'ADMIN_NAME wajib diisi (minimal 3 karakter).';
  if (!i.password || i.password.length < MIN_ADMIN_PASSWORD) return `ADMIN_PASSWORD wajib diisi, minimal ${MIN_ADMIN_PASSWORD} karakter.`;
  if (!/[A-Za-z]/.test(i.password) || !/[0-9]/.test(i.password)) return 'ADMIN_PASSWORD harus memuat huruf dan angka.';
  return null;
}

export type AdminResult = 'DIBUAT' | 'PASSWORD_DIRESET';

export async function createAdmin(pool: Pool, input: AdminInput): Promise<AdminResult> {
  const invalid = validateAdminInput(input);
  if (invalid) throw new Error(invalid);
  const hash = await bcrypt.hash(input.password, 10);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const role = await client.query('SELECT id FROM roles WHERE code = $1', [input.role]);
    if (role.rowCount === 0) throw new Error(`Peran ${input.role} belum ada. Jalankan migrasi database terlebih dahulu (npm run db:migrate).`);
    const existing = await client.query('SELECT id FROM auth_users WHERE phone_number = $1', [input.phone]);
    let result: AdminResult;
    if (existing.rowCount && existing.rowCount > 0) {
      if (!input.resetPassword) throw new Error('Akun dengan nomor ini sudah ada. Tambahkan ADMIN_RESET_PASSWORD=true untuk mengganti passwordnya.');
      await client.query('UPDATE auth_users SET password_hash = $1, role_id = $2, account_status = $3, is_active = TRUE WHERE id = $4', [hash, role.rows[0].id, 'APPROVED', existing.rows[0].id]);
      result = 'PASSWORD_DIRESET';
    } else {
      const created = await client.query(
        `INSERT INTO auth_users (phone_number, password_hash, role_id, account_status) VALUES ($1, $2, $3, 'APPROVED') RETURNING id`,
        [input.phone, hash, role.rows[0].id],
      );
      await client.query('INSERT INTO user_profiles (user_id, full_name, email) VALUES ($1, $2, $3)', [created.rows[0].id, input.name.trim(), input.email || null]);
      result = 'DIBUAT';
    }
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

async function main() {
  const env = process.env;
  const pool = new Pool(migrationPoolConfig(env));
  try {
    const result = await createAdmin(pool, {
      phone: (env.ADMIN_PHONE || '').trim(),
      password: env.ADMIN_PASSWORD || '',
      name: env.ADMIN_NAME || '',
      role: (env.ADMIN_ROLE || 'SUPERADMIN').toUpperCase(),
      email: env.ADMIN_EMAIL,
      resetPassword: (env.ADMIN_RESET_PASSWORD || '').toLowerCase() === 'true',
    });
    console.log(`Akun ${env.ADMIN_PHONE} ${result === 'DIBUAT' ? 'berhasil dibuat' : 'berhasil direset passwordnya'}.`);
  } finally {
    await pool.end();
  }
}

if (require.main === module) {
  main().catch((err: unknown) => {
    console.error(`Gagal: ${err instanceof Error ? err.message : String(err)}`);
    process.exit(1);
  });
}
