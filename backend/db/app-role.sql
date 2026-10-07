-- Role database untuk APLIKASI (hak minimal): hanya baca/tulis data, tanpa hak mengubah skema.
--
-- Pembagian peran yang disarankan untuk produksi:
--   * pemilik/migrator (mis. catu_owner) : memiliki tabel dan menjalankan migrasi (npm run db:migrate)
--   * catu_app (berkas ini)               : dipakai aplikasi sehari-hari (DB_USERNAME/DB_PASSWORD), DB_AUTO_MIGRATE=false
-- Dengan begitu kebocoran kredensial aplikasi tidak memberi hak DROP/ALTER/CREATE, dan bukan superuser.
--
-- Pemakaian (jalankan SEBAGAI pemilik tabel / akun migrator, pada database CATU, SESUDAH migrasi):
--   psql -d <nama_db> -v ON_ERROR_STOP=1 -v app_password='<sandi-kuat>' -f backend/db/app-role.sql
-- Aman dijalankan ulang (mengatur ulang sandi dan hak).

SELECT format('CREATE ROLE catu_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION PASSWORD %L', :'app_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'catu_app') \gexec
SELECT format('ALTER ROLE catu_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION PASSWORD %L', :'app_password') \gexec

SELECT format('GRANT CONNECT ON DATABASE %I TO catu_app', current_database()) \gexec
GRANT USAGE ON SCHEMA public TO catu_app;
REVOKE CREATE ON SCHEMA public FROM catu_app;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO catu_app;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO catu_app;

-- Objek yang dibuat migrasi berikutnya (oleh akun yang menjalankan berkas ini) otomatis ikut mendapat hak yang sama.
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO catu_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO catu_app;

-- Riwayat migrasi tidak boleh disentuh aplikasi.
REVOKE ALL ON SCHEMA drizzle FROM catu_app;
