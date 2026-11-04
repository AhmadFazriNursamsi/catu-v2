# Lingkungan DEV (uji coba tanpa mengganggu produksi)

Alamat (jaringan lokal/VPN saja, tidak lewat domain produksi): admin web `http://10.10.3.41:3013`, API `http://10.10.3.41:4003` (aplikasi mobile dev memakai alamat API ini).
Stack ini terpisah dari produksi: container `catu_dev_*`, database `catu_dev` dengan user `catu_dev`, JWT sendiri,
WhatsApp/FCM/penyimpanan APK dimatikan. Admin web dev menampilkan pita merah **LINGKUNGAN DEV** dan memakai kunci
localStorage berawalan `dev_`, jadi login dev tidak menimpa sesi produksi (alamatnya satu origin).

## Alur kerja
`fitur` -> PR ke **`staging`** (CI membangun image `:staging`) -> uji di DEV -> PR `staging` -> **`main`** (produksi, `:latest`).

## Pasang pertama kali (di server, oleh pemilik)
1. Database terpisah (ganti `<PASSWORD_DEV>`; jangan memakai sandi produksi):
   ```bash
   export PGPASSWORD=$(grep ^DB_PASSWORD= ~/Documents/catu-v2/.env | cut -d= -f2-)
   docker exec -e PGPASSWORD shared-postgres-production psql -U rootdba -d postgres \
     -c "CREATE ROLE catu_dev LOGIN PASSWORD '<PASSWORD_DEV>'" \
     -c "CREATE DATABASE catu_dev OWNER catu_dev"
   unset PGPASSWORD
   ```
2. Folder dan berkas:
   ```bash
   mkdir -p ~/Documents/catu-v2-dev && cd ~/Documents/catu-v2-dev
   # salin docker-compose.yml dan .env.example dari deploy/dev/ repo, lalu: cp .env.example .env  && nano .env
   ```
3. Jalankan: `docker compose pull && docker compose up -d && docker compose logs backend --tail 50`
   (migrasi dan data master terisi otomatis; admin dev dibuat lewat cara yang sama seperti di lokal).
4. Buka `http://<DEV_HOST>:3013` dari komputer di jaringan yang sama. Pita merah **LINGKUNGAN DEV** harus muncul.
   (Domain publik `/dev/` lewat nginx tidak dipakai; bila kelak diperlukan, minta pengelola gerbang menambahkan `/dev/` -> port 3013 dan `/dev/api/` -> port 4003.)

## Memperbarui DEV
`cd ~/Documents/catu-v2-dev && docker compose pull && docker compose up -d`

## Aturan aman
- Jangan salin `.env` produksi ke sini. Jangan isi `WAGATE_*`, `SENSIO_ENV_CONFIG_*`, atau berkas Firebase produksi.
- Jangan unggah APK dari admin web DEV (penyimpanan APK dimatikan; tautan APK produksi tidak berubah).
- Mengisi data uji: pakai akun uji; jangan restore dump produksi ke `catu_dev` tanpa menyamarkan nomor HP pengguna.
