# Berkas khusus development — JANGAN dipakai untuk produksi

- `init-dev-snapshot.sql`: dump lama database **development** (berisi akun uji beserta hash password, order, notifikasi, token perangkat).
- `seed_user_data.sql`: data awal development.

Skema produksi dan database baru dibangun **hanya** oleh migrasi di `backend/drizzle` (lihat `backend/drizzle/README.md`).
Berkas di folder ini tidak dipakai CI maupun aplikasi, dan disimpan hanya untuk rujukan. Hash password di dalamnya sudah ada di
riwayat git: anggap kredensial tersebut bocor dan jangan pernah memakai ulang di produksi.
