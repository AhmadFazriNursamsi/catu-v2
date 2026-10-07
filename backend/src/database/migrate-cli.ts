import { runMigrations } from './migrate';

/** Pemakaian: node dist/database/migrate-cli.js  (atau: npm run db:migrate). Kode keluar 1 bila migrasi gagal. */
runMigrations()
  .then(() => {
    console.log('Migrasi database selesai.');
    process.exit(0);
  })
  .catch((err: unknown) => {
    console.error(`Migrasi database GAGAL: ${err instanceof Error ? err.message : String(err)}`);
    process.exit(1);
  });
