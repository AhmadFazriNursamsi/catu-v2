-- Reset data CATU: hapus semua transaksi, semua user non-admin, dan master data wilayah/keuskupan/ordo.
-- Dipertahankan: akun ber-peran SUPERADMIN/ADMIN beserta profilnya, roles, kategori layanan, tingkat urgensi,
-- master_positions, app_settings, dan seluruh berita (news_*).
--
-- Dijalankan pemilik di server, SETELAH pg_dump. Secara bawaan semuanya di-ROLLBACK (uji coba):
--   psql -U <user> -d <db> -f reset-data.sql                # uji coba, tidak ada yang berubah
--   psql -U <user> -d <db> -v commit=1 -f reset-data.sql    # sungguhan, di-COMMIT
-- Pasang MASTER_DATA_AUTO_SEED=false di .env backend SEBELUM backend dijalankan ulang, kalau tidak master data terisi lagi.

\set ON_ERROR_STOP on
BEGIN;

CREATE TEMP TABLE _sebelum AS
SELECT 'auth_users' AS tabel, count(*) AS jumlah FROM auth_users UNION ALL
SELECT 'orders', count(*) FROM orders UNION ALL
SELECT 'chat_messages', count(*) FROM chat_messages UNION ALL
SELECT 'notifications', count(*) FROM notifications UNION ALL
SELECT 'lingkungan', count(*) FROM lingkungan UNION ALL
SELECT 'wilayah', count(*) FROM wilayah UNION ALL
SELECT 'paroki', count(*) FROM paroki UNION ALL
SELECT 'keuskupan', count(*) FROM keuskupan UNION ALL
SELECT 'ordo', count(*) FROM ordo UNION ALL
SELECT 'kabupaten_kota', count(*) FROM kabupaten_kota UNION ALL
SELECT 'provinsi', count(*) FROM provinsi;

-- 1. Transaksi: chat, notifikasi, pesanan beserta turunannya.
DELETE FROM chat_message_reads;
DELETE FROM chat_messages;
DELETE FROM chat_group_members;
DELETE FROM chat_groups;
DELETE FROM notifications;
DELETE FROM order_monitors;
DELETE FROM order_assignments;
DELETE FROM order_reschedules;
DELETE FROM order_romo_handovers;
DELETE FROM order_items;
DELETE FROM orders;
DELETE FROM order_number_counters;
DELETE FROM activity_logs;
DELETE FROM user_devices;
DELETE FROM news_bookmarks;

-- 2. User selain SUPERADMIN/ADMIN (profil, profil Romo, tautan login ikut terhapus lewat CASCADE).
CREATE TEMP TABLE _hapus_user AS
SELECT u.id FROM auth_users u
WHERE NOT EXISTS (SELECT 1 FROM roles r WHERE r.id = u.role_id AND r.code IN ('SUPERADMIN', 'ADMIN'));

DELETE FROM user_approvals WHERE approver_user_id IN (SELECT id FROM _hapus_user) OR target_user_id IN (SELECT id FROM _hapus_user);
DELETE FROM auth_users WHERE id IN (SELECT id FROM _hapus_user);

-- 3. Master data wilayah, dari anak ke induk.
DELETE FROM lingkungan;
DELETE FROM wilayah;
DELETE FROM paroki;
DELETE FROM keuskupan;
DELETE FROM ordo;
DELETE FROM kabupaten_kota;
DELETE FROM provinsi;

SELECT s.tabel, s.jumlah AS sebelum,
  CASE s.tabel
    WHEN 'auth_users' THEN (SELECT count(*) FROM auth_users)
    WHEN 'orders' THEN (SELECT count(*) FROM orders)
    WHEN 'chat_messages' THEN (SELECT count(*) FROM chat_messages)
    WHEN 'notifications' THEN (SELECT count(*) FROM notifications)
    WHEN 'lingkungan' THEN (SELECT count(*) FROM lingkungan)
    WHEN 'wilayah' THEN (SELECT count(*) FROM wilayah)
    WHEN 'paroki' THEN (SELECT count(*) FROM paroki)
    WHEN 'keuskupan' THEN (SELECT count(*) FROM keuskupan)
    WHEN 'ordo' THEN (SELECT count(*) FROM ordo)
    WHEN 'kabupaten_kota' THEN (SELECT count(*) FROM kabupaten_kota)
    WHEN 'provinsi' THEN (SELECT count(*) FROM provinsi)
  END AS sesudah
FROM _sebelum s;

SELECT u.id, u.phone_number, r.code AS peran FROM auth_users u LEFT JOIN roles r ON r.id = u.role_id ORDER BY u.id;

\if :{?commit}
  COMMIT;
  \echo 'SELESAI: perubahan DISIMPAN (COMMIT).'
\else
  ROLLBACK;
  \echo 'UJI COBA: tidak ada yang berubah (ROLLBACK). Jalankan ulang dengan -v commit=1 untuk menyimpan.'
\endif
