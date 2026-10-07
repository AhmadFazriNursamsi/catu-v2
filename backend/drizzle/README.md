# Migrasi database CATU

Satu-satunya jalur perubahan skema. Aplikasi **tidak** menjalankan DDL apa pun saat start (tidak ada `CREATE/ALTER` di kode),
tidak mengubah data pengguna saat start, dan tidak membuat akun apa pun.

| Berkas | Fungsi |
|---|---|
| `0000_baseline.sql` | Skema lengkap untuk database **baru**. Database yang sudah memakai migrasi lama melewatinya (cap waktunya sama dengan migrasi lama pertama). |
| `0001_standardization.sql` | Menyamakan database **lama** dengan standar produksi (indeks relasi, FK, CHECK, trigger `updated_at`, waktu bertimezone, enum mati dibuang, data referensi). Idempoten; pada database baru hanya mengisi data referensi. |
| `master_data_seed.sql` | Data master wilayah (provinsi sampai lingkungan). Diisi aplikasi bila belum lengkap. |

Seluruh migrasi yang belum berjalan diterapkan dalam **satu transaksi**: bila ada yang gagal, semuanya dibatalkan dan aplikasi **tidak start**.
Aturan CHECK/FK yang menolak data lama ditambahkan `NOT VALID` lalu divalidasi; baris lama yang melanggar menghasilkan peringatan
(aturan tetap berlaku untuk data baru) alih-alih menggagalkan seluruh migrasi.

## Menambah migrasi baru
1. Buat `NNNN_nama.sql` (nomor berikutnya) berisi SQL **idempoten** (`IF NOT EXISTS`, blok `DO`), tanpa menyunting berkas yang sudah ada.
2. Tambahkan entri di `meta/_journal.json` dengan `when` lebih besar dari entri terakhir dan `"breakpoints": false`.
3. Ubah `0000_baseline.sql` **tidak** boleh; database baru mendapatkan perubahan itu karena seluruh rantai migrasi dijalankan berurutan.
4. Buktikan dengan tes: `npm run test:integration` membangun database kosong dari rantai migrasi dan memeriksa standar skema
   (`test/integration/schema-standards.integration-spec.ts`).
5. Hindari `CREATE INDEX CONCURRENTLY` (tidak boleh dalam transaksi). Pada tabel besar, buat indeks di luar jam sibuk atau
   jalankan sebagai langkah manual terpisah lalu catat di migrasi dengan `IF NOT EXISTS`.

## Menjalankan
- Otomatis saat aplikasi start (bawaan): `DB_AUTO_MIGRATE=true`.
- Terpisah (disarankan di produksi): `DB_AUTO_MIGRATE=false` pada aplikasi, lalu pada setiap rilis jalankan
  `npm run db:migrate` (setelah `npm run build`) dengan akun pemilik tabel (`DB_MIGRATION_USERNAME` / `DB_MIGRATION_PASSWORD`;
  bila kosong memakai `DB_USERNAME` / `DB_PASSWORD`). Kode keluar 1 bila gagal.

## Menyiapkan produksi dari nol
```bash
# 1. buat database kosong dan akun pemilik, lalu:
npm run build
DB_USERNAME=<pemilik> DB_PASSWORD=<sandi> npm run db:migrate

# 2. buat admin pertama (sandi dibaca dari environment, minimal 12 karakter, memuat huruf dan angka)
DB_USERNAME=<pemilik> DB_PASSWORD=<sandi> \
ADMIN_PHONE=628xxxxxxxxxx ADMIN_PASSWORD='<sandi-kuat>' ADMIN_NAME='Nama Admin' ADMIN_ROLE=SUPERADMIN npm run db:create-admin
#    (ADMIN_RESET_PASSWORD=true untuk mengganti sandi akun yang sudah ada)

# 3. buat role aplikasi dengan hak minimal (tanpa DDL, bukan superuser)
psql -d <nama_db> -v ON_ERROR_STOP=1 -v app_password='<sandi-app>' -f db/app-role.sql

# 4. jalankan aplikasi dengan DB_USERNAME=catu_app dan DB_AUTO_MIGRATE=false
```
Tidak ada akun bawaan. Akun admin lama (`6288888888888`, `6289999999999`) yang mungkin masih ada di database lama harus
**diganti passwordnya** (`ADMIN_RESET_PASSWORD=true`) atau dinonaktifkan, karena hash lamanya pernah tertulis di kode dan di git.
