# Lingkungan DEV (uji coba tanpa mengganggu produksi)

Alamat: `https://catu.devoutsys.com/dev/` (admin web) dan `https://catu.devoutsys.com/dev/api` (API).
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
4. Reverse proxy (nginx) di host `catu.devoutsys.com`, tambahkan di blok server yang sudah ada, **di atas** lokasi umum:
   ```nginx
   location = /dev { return 301 /dev/; }
   location /dev/api/ {
     proxy_pass http://127.0.0.1:4003/;
     proxy_set_header Host $host;
     proxy_set_header X-Forwarded-Proto $scheme;
     proxy_set_header X-Real-IP $remote_addr;
     client_max_body_size 50m;
   }
   location /dev/ {
     proxy_pass http://127.0.0.1:3003/;
     proxy_set_header Host $host;
     proxy_set_header X-Forwarded-Proto $scheme;
   }
   ```
   Cocokkan dengan cara blok `/api` produksi meneruskan ke backend (awalan `/api` dibuang atau tidak). Lalu `nginx -t && nginx -s reload`.

## Memperbarui DEV
`cd ~/Documents/catu-v2-dev && docker compose pull && docker compose up -d`

## Aturan aman
- Jangan salin `.env` produksi ke sini. Jangan isi `WAGATE_*`, `SENSIO_ENV_CONFIG_*`, atau berkas Firebase produksi.
- Jangan unggah APK dari admin web DEV (penyimpanan APK dimatikan; tautan APK produksi tidak berubah).
- Mengisi data uji: pakai akun uji; jangan restore dump produksi ke `catu_dev` tanpa menyamarkan nomor HP pengguna.
