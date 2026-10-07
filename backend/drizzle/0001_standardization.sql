-- 0001_standardization: standarisasi skema untuk produksi.
--
-- Aman dijalankan berulang dan pada database lama maupun baru:
--   * database lama (sudah berisi data): menyamakan skema dengan standar (DDL yang dulu dijalankan aplikasi saat start,
--     indeks, relasi, aturan CHECK, trigger updated_at, tipe waktu seragam, enum mati dibuang, data referensi).
--   * database baru: 0000_baseline sudah membentuk skema akhir; berkas ini hanya mengisi data referensi.
-- Aturan yang menolak data lama ditambahkan sebagai NOT VALID lalu divalidasi; bila ada baris lama yang melanggar,
-- validasi dilewati dengan peringatan (aturan tetap berlaku untuk data baru) sehingga migrasi tidak gagal sia-sia.
SET LOCAL lock_timeout = '30s';
SET LOCAL statement_timeout = '15min';

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ===== Fungsi bantu (hanya hidup selama sesi migrasi) =====
CREATE FUNCTION pg_temp.ensure_check(tbl text, cname text, expr text) RETURNS void AS $f$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = cname AND conrelid = tbl::regclass) THEN
    EXECUTE format('ALTER TABLE %s ADD CONSTRAINT %I CHECK (%s) NOT VALID', tbl, cname, expr);
  END IF;
  BEGIN
    EXECUTE format('ALTER TABLE %s VALIDATE CONSTRAINT %I', tbl, cname);
  EXCEPTION WHEN check_violation THEN
    RAISE WARNING 'Aturan % pada % belum tervalidasi karena ada baris lama yang melanggar; tetap berlaku untuk data baru.', cname, tbl;
  END;
END $f$ LANGUAGE plpgsql;

CREATE FUNCTION pg_temp.ensure_fk(tbl text, cname text, col text, reftbl text, refcol text, ondelete text) RETURNS void AS $f$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = cname AND conrelid = tbl::regclass) THEN
    EXECUTE format('ALTER TABLE %s ADD CONSTRAINT %I FOREIGN KEY (%I) REFERENCES %s (%I) ON DELETE %s NOT VALID', tbl, cname, col, reftbl, refcol, ondelete);
  END IF;
  BEGIN
    EXECUTE format('ALTER TABLE %s VALIDATE CONSTRAINT %I', tbl, cname);
  EXCEPTION WHEN foreign_key_violation THEN
    RAISE WARNING 'Relasi % pada % belum tervalidasi karena ada baris lama yatim; tetap berlaku untuk data baru.', cname, tbl;
  END;
END $f$ LANGUAGE plpgsql;

-- ===== A. Tabel dan kolom yang dulu dibuat oleh DDL saat aplikasi start =====
CREATE TABLE IF NOT EXISTS app_settings (
  key varchar(100) PRIMARY KEY,
  value text NOT NULL,
  description text,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS order_number_counters (key varchar(40) PRIMARY KEY, last_value integer NOT NULL DEFAULT 0);

ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS jabatan_start_year integer,
  ADD COLUMN IF NOT EXISTS jabatan_end_year integer,
  ADD COLUMN IF NOT EXISTS jabatan_start_date varchar(20),
  ADD COLUMN IF NOT EXISTS jabatan_end_date varchar(20),
  ADD COLUMN IF NOT EXISTS is_jabatan_active boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS birth_date varchar(20),
  ADD COLUMN IF NOT EXISTS gender varchar(1),
  ADD COLUMN IF NOT EXISTS address text,
  ADD COLUMN IF NOT EXISTS avatar_url text;
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS attachment_url text,
  ADD COLUMN IF NOT EXISTS accepted_romo_id integer,
  ADD COLUMN IF NOT EXISTS external_romo_name varchar(255),
  ADD COLUMN IF NOT EXISTS rating integer,
  ADD COLUMN IF NOT EXISTS review_notes text,
  ADD COLUMN IF NOT EXISTS reviewed_at timestamptz,
  ADD COLUMN IF NOT EXISTS ordo_notified_at timestamptz,
  ADD COLUMN IF NOT EXISTS koordinator_notified_at timestamptz,
  ADD COLUMN IF NOT EXISTS lintas_paroki boolean NOT NULL DEFAULT false;
ALTER TABLE order_items
  ADD COLUMN IF NOT EXISTS external_romo_name varchar(255),
  ADD COLUMN IF NOT EXISTS rating integer,
  ADD COLUMN IF NOT EXISTS review_notes text,
  ADD COLUMN IF NOT EXISTS reviewed_at timestamptz;
ALTER TABLE order_romo_handovers ADD COLUMN IF NOT EXISTS external_romo_name varchar(255);

DO $f$
BEGIN
  IF (SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='user_profiles' AND column_name='pengurus_position') <> 'character varying' THEN
    ALTER TABLE user_profiles ALTER COLUMN pengurus_position TYPE varchar(100) USING pengurus_position::text;
  END IF;
  IF (SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='user_profiles' AND column_name='romo_position') <> 'character varying' THEN
    ALTER TABLE user_profiles ALTER COLUMN romo_position TYPE varchar(100) USING romo_position::text;
  END IF;
END $f$;
-- Default bawaan berupa cast ke enum yang tidak dipakai lagi.
ALTER TABLE user_profiles ALTER COLUMN romo_position SET DEFAULT 'ROMO_BIASA';

-- ===== B. Normalisasi data lama (dulu dijalankan ulang di setiap start aplikasi) =====
UPDATE orders SET status = 'CONFIRMED' WHERE status::text = 'ACCEPTED';
UPDATE orders SET status = 'DONE' WHERE status::text IN ('SELESAI', 'COMPLETED');
UPDATE orders SET status = 'FAIL' WHERE status::text IN ('REJECTED', 'CANCELLED');
UPDATE order_items SET status = 'PENDING' WHERE status IS NULL;
UPDATE order_items SET status = 'CONFIRMED' WHERE status = 'ACCEPTED';
UPDATE order_items SET status = 'DONE' WHERE status IN ('SELESAI', 'COMPLETED');
UPDATE order_items SET status = 'FAIL' WHERE status IN ('REJECTED', 'CANCELLED');
UPDATE user_profiles SET romo_position = NULL
  WHERE user_id IN (SELECT u.id FROM auth_users u JOIN roles r ON u.role_id = r.id WHERE r.code NOT LIKE 'ROMO%')
    AND romo_position IS NOT NULL;
UPDATE user_profiles SET keuskupan_id = NULL, paroki_id = NULL, wilayah_id = NULL, lingkungan_id = NULL
  WHERE user_id IN (SELECT u.id FROM auth_users u JOIN roles r ON u.role_id = r.id WHERE r.code = 'ROMO_ORDO')
    AND (keuskupan_id IS NOT NULL OR paroki_id IS NOT NULL OR wilayah_id IS NOT NULL OR lingkungan_id IS NOT NULL);
UPDATE user_profiles SET is_jabatan_active = NULL
  WHERE pengurus_position IS NULL AND (romo_position IS NULL OR romo_position NOT IN ('Kepala Romo Paroki', 'Ketua Romo Ordo', 'KETUA_ROMO'))
    AND is_jabatan_active IS NOT NULL;
UPDATE lingkungan SET name = btrim(regexp_replace(name, '\s+', ' ', 'g')) WHERE name <> btrim(regexp_replace(name, '\s+', ' ', 'g'));
UPDATE roles SET name = 'Umat Pendatang' WHERE code = 'UMAT_PENDATANG' AND name = 'umat yang sedang berkunjung';
UPDATE service_categories SET description = 'Pelayanan Sakramen Perminyakan (pengurapan orang sakit)' WHERE id = 1 AND description = 'sad';

-- ===== C. Waktu seragam: semua kolom waktu memakai zona waktu (nilai lama dibaca sebagai UTC) =====
DO $f$
DECLARE r record;
BEGIN
  FOR r IN SELECT table_name, column_name FROM information_schema.columns
           WHERE table_schema = 'public' AND data_type = 'timestamp without time zone'
             AND table_name IN (SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE')
  LOOP
    EXECUTE format('ALTER TABLE %I ALTER COLUMN %I TYPE timestamptz USING %I AT TIME ZONE ''UTC''', r.table_name, r.column_name, r.column_name);
  END LOOP;
END $f$;

-- ===== D. Relasi: buang yang ganda (gaya Drizzle *_fk vs *_fkey), seragamkan nama, lengkapi yang belum ada =====
-- Pasangan ganda berbeda aturan hapus (NO ACTION vs RESTRICT/CASCADE/SET NULL); yang efektif selama ini adalah versi *_fkey,
-- jadi versi *_fk yang dibuang dan perilaku tidak berubah.
DO $f$
DECLARE r record;
BEGIN
  FOR r IN SELECT c.oid, c.conname, c.conrelid, c.conkey, c.confrelid, c.confkey, c.confdeltype, c.confupdtype
           FROM pg_constraint c
           WHERE c.contype = 'f' AND c.connamespace = 'public'::regnamespace AND c.conname LIKE '%\_fk'
  LOOP
    IF EXISTS (SELECT 1 FROM pg_constraint d WHERE d.contype = 'f' AND d.oid <> r.oid AND d.conrelid = r.conrelid AND d.conkey = r.conkey
                 AND d.confrelid = r.confrelid AND d.confkey = r.confkey AND d.conname NOT LIKE '%\_fk') THEN
      EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I', r.conrelid::regclass, r.conname);
    ELSE
      EXECUTE format('ALTER TABLE %s RENAME CONSTRAINT %I TO %I', r.conrelid::regclass, r.conname,
                     (SELECT relname FROM pg_class WHERE oid = r.conrelid) || '_' || (SELECT attname FROM pg_attribute WHERE attrelid = r.conrelid AND attnum = r.conkey[1]) || '_fkey');
    END IF;
  END LOOP;
END $f$;

SELECT pg_temp.ensure_fk('orders', 'orders_accepted_romo_id_fkey', 'accepted_romo_id', 'auth_users', 'id', 'SET NULL');
SELECT pg_temp.ensure_fk('order_items', 'order_items_accepted_romo_id_fkey', 'accepted_romo_id', 'auth_users', 'id', 'SET NULL');
SELECT pg_temp.ensure_fk('orders', 'orders_reschedule_proposed_by_fkey', 'reschedule_proposed_by', 'auth_users', 'id', 'SET NULL');
SELECT pg_temp.ensure_fk('order_items', 'order_items_reschedule_proposed_by_fkey', 'reschedule_proposed_by', 'auth_users', 'id', 'SET NULL');
SELECT pg_temp.ensure_fk('user_profiles', 'user_profiles_ordo_id_fkey', 'ordo_id', 'ordo', 'id', 'SET NULL');
SELECT pg_temp.ensure_fk('chat_group_members', 'chat_group_members_last_read_message_id_fkey', 'last_read_message_id', 'chat_messages', 'id', 'SET NULL');

-- ===== E. Aturan CHECK (status, rating, format) =====
ALTER TABLE order_items ALTER COLUMN status SET NOT NULL;
SELECT pg_temp.ensure_check('orders', 'chk_orders_status', $c$status::text = ANY (ARRAY['PENDING','CONFIRMED','IN_PROGRESS','DONE','CLOSE','FAIL']::text[])$c$);
SELECT pg_temp.ensure_check('order_items', 'chk_order_items_status', $c$status::text = ANY (ARRAY['PENDING','CONFIRMED','IN_PROGRESS','DONE','CLOSE','FAIL']::text[])$c$);
SELECT pg_temp.ensure_check('orders', 'chk_orders_reschedule_status', $c$reschedule_status::text = ANY (ARRAY['NONE','PENDING_UMAT','ACCEPTED','REJECTED']::text[])$c$);
SELECT pg_temp.ensure_check('order_items', 'chk_order_items_reschedule_status', $c$reschedule_status::text = ANY (ARRAY['NONE','PENDING_UMAT','ACCEPTED','REJECTED']::text[])$c$);
SELECT pg_temp.ensure_check('orders', 'chk_orders_handover_status', $c$handover_status::text = ANY (ARRAY['NONE','PENDING','ACCEPTED','REJECTED']::text[])$c$);
SELECT pg_temp.ensure_check('order_items', 'chk_order_items_handover_status', $c$handover_status::text = ANY (ARRAY['NONE','PENDING','ACCEPTED','REJECTED']::text[])$c$);
SELECT pg_temp.ensure_check('order_reschedules', 'chk_order_reschedules_status', $c$status::text = ANY (ARRAY['PENDING_UMAT','ACCEPTED','REJECTED']::text[])$c$);
SELECT pg_temp.ensure_check('order_romo_handovers', 'chk_order_romo_handovers_status', $c$status::text = ANY (ARRAY['PENDING','ACCEPTED','REJECTED']::text[])$c$);
SELECT pg_temp.ensure_check('orders', 'chk_orders_rating', $c$rating IS NULL OR rating BETWEEN 1 AND 5$c$);
SELECT pg_temp.ensure_check('order_items', 'chk_order_items_rating', $c$rating IS NULL OR rating BETWEEN 1 AND 5$c$);
SELECT pg_temp.ensure_check('order_items', 'chk_order_items_time_range', $c$scheduled_time_end > scheduled_time_start$c$);
SELECT pg_temp.ensure_check('notifications', 'chk_notifications_type_format', $c$type ~ '^[A-Z][A-Z0-9_]*$'$c$);
SELECT pg_temp.ensure_check('auth_users', 'chk_auth_users_phone_format', $c$phone_number ~ '^[0-9]{9,16}$'$c$);
SELECT pg_temp.ensure_check('user_profiles', 'chk_user_profiles_gender', $c$gender::text = ANY (ARRAY['L','P']::text[])$c$);

-- Satu grup chat per misa (atau satu per pelayanan tanpa misa).
DO $f$
BEGIN
  CREATE UNIQUE INDEX IF NOT EXISTS uq_chat_groups_order_item ON chat_groups (order_id, COALESCE(order_item_id, 0));
EXCEPTION WHEN unique_violation THEN
  RAISE WARNING 'uq_chat_groups_order_item dilewati: ada grup chat ganda untuk order/misa yang sama; bereskan lalu jalankan ulang.';
END $f$;

-- ===== F. Indeks (kolom relasi dan jalur kueri utama) =====
CREATE INDEX IF NOT EXISTS ix_activity_logs_user_id ON activity_logs (user_id);
CREATE INDEX IF NOT EXISTS ix_auth_users_approval_assigned_to_user_id ON auth_users (approval_assigned_to_user_id);
CREATE INDEX IF NOT EXISTS ix_auth_users_role_id ON auth_users (role_id);
CREATE INDEX IF NOT EXISTS ix_chat_group_members_last_read_message_id ON chat_group_members (last_read_message_id);
CREATE INDEX IF NOT EXISTS ix_chat_group_members_user_id ON chat_group_members (user_id);
CREATE INDEX IF NOT EXISTS ix_chat_groups_order_item_id ON chat_groups (order_item_id);
CREATE INDEX IF NOT EXISTS ix_chat_message_reads_user_id ON chat_message_reads (user_id);
CREATE INDEX IF NOT EXISTS ix_chat_messages_reply_to_message_id ON chat_messages (reply_to_message_id);
CREATE INDEX IF NOT EXISTS ix_chat_messages_sender_id ON chat_messages (sender_id);
CREATE INDEX IF NOT EXISTS ix_kabupaten_kota_provinsi_id ON kabupaten_kota (provinsi_id);
CREATE INDEX IF NOT EXISTS ix_lingkungan_wilayah_id ON lingkungan (wilayah_id);
CREATE INDEX IF NOT EXISTS ix_news_article_tags_tag_id ON news_article_tags (tag_id);
CREATE INDEX IF NOT EXISTS ix_news_bookmarks_article_id ON news_bookmarks (article_id);
CREATE INDEX IF NOT EXISTS ix_news_scrape_logs_source_id ON news_scrape_logs (source_id);
CREATE INDEX IF NOT EXISTS ix_notifications_chat_group_id ON notifications (chat_group_id);
CREATE INDEX IF NOT EXISTS ix_notifications_order_id ON notifications (order_id);
CREATE INDEX IF NOT EXISTS ix_notifications_user_created ON notifications (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS ix_order_assignments_order_id ON order_assignments (order_id);
CREATE INDEX IF NOT EXISTS ix_order_assignments_romo_id ON order_assignments (romo_id);
CREATE INDEX IF NOT EXISTS ix_order_items_accepted_romo_id ON order_items (accepted_romo_id);
CREATE INDEX IF NOT EXISTS ix_order_items_handover_proposed_by ON order_items (handover_proposed_by);
CREATE INDEX IF NOT EXISTS ix_order_items_handover_target_romo_id ON order_items (handover_target_romo_id);
CREATE INDEX IF NOT EXISTS ix_order_items_order_id ON order_items (order_id);
CREATE INDEX IF NOT EXISTS ix_order_items_reschedule_proposed_by ON order_items (reschedule_proposed_by);
CREATE INDEX IF NOT EXISTS ix_order_monitors_user_id ON order_monitors (user_id);
CREATE INDEX IF NOT EXISTS ix_order_reschedules_item_id ON order_reschedules (item_id);
CREATE INDEX IF NOT EXISTS ix_order_reschedules_order_id ON order_reschedules (order_id);
CREATE INDEX IF NOT EXISTS ix_order_reschedules_proposed_by ON order_reschedules (proposed_by);
CREATE INDEX IF NOT EXISTS ix_order_reschedules_responded_by ON order_reschedules (responded_by);
CREATE INDEX IF NOT EXISTS ix_order_romo_handovers_item_id ON order_romo_handovers (item_id);
CREATE INDEX IF NOT EXISTS ix_order_romo_handovers_new_romo_id ON order_romo_handovers (new_romo_id);
CREATE INDEX IF NOT EXISTS ix_order_romo_handovers_order_id ON order_romo_handovers (order_id);
CREATE INDEX IF NOT EXISTS ix_order_romo_handovers_previous_romo_id ON order_romo_handovers (previous_romo_id);
CREATE INDEX IF NOT EXISTS ix_orders_accepted_romo_id ON orders (accepted_romo_id);
CREATE INDEX IF NOT EXISTS ix_orders_handover_proposed_by ON orders (handover_proposed_by);
CREATE INDEX IF NOT EXISTS ix_orders_handover_target_romo_id ON orders (handover_target_romo_id);
CREATE INDEX IF NOT EXISTS ix_orders_kabupaten_kota_id ON orders (kabupaten_kota_id);
CREATE INDEX IF NOT EXISTS ix_orders_keuskupan_id ON orders (keuskupan_id);
CREATE INDEX IF NOT EXISTS ix_orders_lingkungan_id ON orders (lingkungan_id);
CREATE INDEX IF NOT EXISTS ix_orders_paroki_id ON orders (paroki_id);
CREATE INDEX IF NOT EXISTS ix_orders_reschedule_proposed_by ON orders (reschedule_proposed_by);
CREATE INDEX IF NOT EXISTS ix_orders_service_category_id ON orders (service_category_id);
CREATE INDEX IF NOT EXISTS ix_orders_urgency_level_id ON orders (urgency_level_id);
CREATE INDEX IF NOT EXISTS ix_orders_user_created ON orders (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS ix_orders_wilayah_id ON orders (wilayah_id);
CREATE INDEX IF NOT EXISTS ix_paroki_keuskupan_id ON paroki (keuskupan_id);
CREATE INDEX IF NOT EXISTS ix_romo_profiles_ordo_id ON romo_profiles (ordo_id);
CREATE INDEX IF NOT EXISTS ix_user_approvals_approver_user_id ON user_approvals (approver_user_id);
CREATE INDEX IF NOT EXISTS ix_user_approvals_target_user_id ON user_approvals (target_user_id);
CREATE INDEX IF NOT EXISTS ix_user_profiles_kabupaten_kota_id ON user_profiles (kabupaten_kota_id);
CREATE INDEX IF NOT EXISTS ix_user_profiles_keuskupan_id ON user_profiles (keuskupan_id);
CREATE INDEX IF NOT EXISTS ix_user_profiles_lingkungan_id ON user_profiles (lingkungan_id);
CREATE INDEX IF NOT EXISTS ix_user_profiles_ordo_id ON user_profiles (ordo_id);
CREATE INDEX IF NOT EXISTS ix_user_profiles_paroki_id ON user_profiles (paroki_id);
CREATE INDEX IF NOT EXISTS ix_user_profiles_wilayah_id ON user_profiles (wilayah_id);
CREATE INDEX IF NOT EXISTS ix_wilayah_paroki_id ON wilayah (paroki_id);
CREATE INDEX IF NOT EXISTS ix_orders_status_scheduled ON orders (status, scheduled_date);
CREATE INDEX IF NOT EXISTS ix_orders_created_at ON orders (created_at DESC);
CREATE INDEX IF NOT EXISTS ix_orders_pending_created_at ON orders (created_at) WHERE status = 'PENDING';
CREATE INDEX IF NOT EXISTS ix_order_items_status_scheduled ON order_items (status, scheduled_date);
CREATE INDEX IF NOT EXISTS ix_notifications_user_unread ON notifications (user_id) WHERE NOT is_read;
CREATE INDEX IF NOT EXISTS ix_activity_logs_created_at ON activity_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS ix_auth_users_account_status ON auth_users (account_status);

-- ===== G. updated_at: kolom seragam dan diperbarui otomatis oleh basis data =====
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $f$
BEGIN
  NEW.updated_at := CURRENT_TIMESTAMP;
  RETURN NEW;
END $f$ LANGUAGE plpgsql;

DO $f$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['order_items', 'chat_groups', 'order_reschedules', 'order_romo_handovers'] LOOP
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = t AND column_name = 'updated_at') THEN
      EXECUTE format('ALTER TABLE %I ADD COLUMN updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP', t);
      EXECUTE format('UPDATE %I SET updated_at = created_at WHERE created_at IS NOT NULL', t);
    END IF;
  END LOOP;
  FOREACH t IN ARRAY ARRAY['orders', 'order_items', 'auth_users', 'user_profiles', 'chat_groups', 'order_reschedules', 'order_romo_handovers', 'news_articles', 'news_sources', 'app_settings'] LOOP
    EXECUTE format('CREATE OR REPLACE TRIGGER trg_%s_updated_at BEFORE UPDATE ON %I FOR EACH ROW WHEN (OLD.* IS DISTINCT FROM NEW.*) EXECUTE FUNCTION set_updated_at()', t, t);
  END LOOP;
END $f$;

-- ===== H. Enum yang tidak dipakai kolom mana pun =====
DO $f$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['romo_position_enum', 'pengurus_position_enum', 'notification_type_enum'] LOOP
    BEGIN
      EXECUTE format('DROP TYPE IF EXISTS %I', t);
    EXCEPTION WHEN dependent_objects_still_exist THEN
      RAISE WARNING 'Enum % masih dipakai objek lain; dilewati.', t;
    END;
  END LOOP;
END $f$;

-- ===== I. Data referensi (idempoten; tidak menimpa perubahan yang sudah ada) =====
INSERT INTO roles (code, name) VALUES
  ('UMAT', 'Umat Pemohon'), ('ROMO_PAROKI', 'Romo Paroki'), ('ROMO_ORDO', 'Romo Ordo'),
  ('PENGURUS_LINGKUNGAN', 'Pengurus Lingkungan'), ('KOORDINATOR_KEUSKUPAN', 'Koordinator Keuskupan'),
  ('ADMIN', 'Administrator'), ('SUPERADMIN', 'Super Admin'), ('UMAT_PENDATANG', 'Umat Pendatang')
ON CONFLICT (code) DO NOTHING;
INSERT INTO service_categories (id, name, description, is_urgent_by_default, is_active) VALUES
  (1, 'Sakramen Perminyakan', 'Pelayanan Sakramen Perminyakan (pengurapan orang sakit)', true, true),
  (2, 'Misa Kedukaan', 'Pelayanan Misa Kedukaan', true, true)
ON CONFLICT (id) DO NOTHING;
INSERT INTO urgency_levels (id, name, level) VALUES (1, 'Biasa', 1), (2, 'Penting', 2), (3, 'Darurat / Kritis', 3) ON CONFLICT (id) DO NOTHING;
INSERT INTO master_positions (category, code, name, is_lead) VALUES
  ('PENGURUS_LINGKUNGAN', 'KOORDINATOR', 'Koordinator', true), ('PENGURUS_LINGKUNGAN', 'KETUA_LINGKUNGAN', 'Ketua Lingkungan', true),
  ('PENGURUS_LINGKUNGAN', 'WAKIL_KETUA', 'Wakil Ketua', false), ('PENGURUS_LINGKUNGAN', 'SEKRETARIS', 'Sekretaris', false),
  ('ROMO_PAROKI', 'KEPALA_ROMO_PAROKI', 'Kepala Romo Paroki', true), ('ROMO_PAROKI', 'ROMO_PAROKI', 'Romo Paroki', false),
  ('ROMO_ORDO', 'KETUA_ROMO_ORDO', 'Ketua Romo Ordo', true), ('ROMO_ORDO', 'ROMO_ORDO', 'Romo Ordo', false)
ON CONFLICT (code) DO NOTHING;
INSERT INTO app_settings (key, value, description) VALUES
  ('escalation.ordo_after_minutes', '10', 'Menit sejak pelayanan dibuat sampai terbuka untuk Romo Ordo'),
  ('escalation.koordinator_after_minutes', '20', 'Menit sejak pelayanan dibuat sampai Koordinator diberi tahu untuk mencarikan Romo')
ON CONFLICT (key) DO NOTHING;
SELECT setval(pg_get_serial_sequence('roles', 'id'), GREATEST((SELECT COALESCE(MAX(id), 1) FROM roles), 1));
SELECT setval(pg_get_serial_sequence('service_categories', 'id'), GREATEST((SELECT COALESCE(MAX(id), 1) FROM service_categories), 1));
SELECT setval(pg_get_serial_sequence('urgency_levels', 'id'), GREATEST((SELECT COALESCE(MAX(id), 1) FROM urgency_levels), 1));
