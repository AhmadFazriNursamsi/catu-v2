import { Pool, PoolConfig } from 'pg';
import { drizzle } from 'drizzle-orm/node-postgres';
import { migrate } from 'drizzle-orm/node-postgres/migrator';
import * as fs from 'fs';
import * as path from 'path';

/**
 * Menjalankan migrasi skema (backend/drizzle). Satu-satunya jalur perubahan skema: tidak ada DDL lain yang dijalankan aplikasi.
 * Seluruh migrasi yang belum berjalan diterapkan dalam satu transaksi; bila gagal, semuanya dibatalkan dan error dilempar.
 *
 * Akun migrasi boleh berbeda dari akun aplikasi (DB_MIGRATION_USERNAME / DB_MIGRATION_PASSWORD) agar aplikasi cukup
 * memakai hak DML (lihat backend/db/app-role.sql).
 */
export function migrationPoolConfig(env: NodeJS.ProcessEnv = process.env): PoolConfig {
  return {
    host: env.DB_HOST || 'catu_postgres',
    port: parseInt(env.DB_PORT || '5432', 10),
    user: env.DB_MIGRATION_USERNAME || env.DB_USERNAME || env.DB_USER || 'postgres',
    password: env.DB_MIGRATION_PASSWORD || env.DB_PASSWORD,
    database: env.DB_NAME || 'catu_v2_db',
    max: 1,
    connectionTimeoutMillis: 10000,
  };
}

export function resolveMigrationsFolder(): string {
  const candidates = [
    path.resolve(process.cwd(), 'drizzle'),
    path.resolve(process.cwd(), 'backend/drizzle'),
    path.resolve(__dirname, '../../drizzle'),
    path.resolve(__dirname, '../../../drizzle'),
  ];
  const found = candidates.find((c) => fs.existsSync(path.join(c, 'meta/_journal.json')));
  if (!found) throw new Error(`Folder migrasi (drizzle/meta/_journal.json) tidak ditemukan. Dicari di: ${candidates.join(', ')}`);
  return found;
}

export async function runMigrations(config: PoolConfig = migrationPoolConfig()): Promise<void> {
  const pool = new Pool(config);
  try {
    await migrate(drizzle(pool), { migrationsFolder: resolveMigrationsFolder() });
  } finally {
    await pool.end();
  }
}

/** Aplikasi menjalankan migrasi sendiri saat start kecuali DB_AUTO_MIGRATE=false (deploy dengan langkah migrasi terpisah). */
export const autoMigrateEnabled = (env: NodeJS.ProcessEnv = process.env) => (env.DB_AUTO_MIGRATE ?? 'true').toLowerCase() !== 'false';
