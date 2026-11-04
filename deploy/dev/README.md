# Lingkungan DEV (uji coba tanpa mengganggu produksi)

Alamat: admin web `https://catu.devoutsys.com/dev/`, API `https://catu.devoutsys.com/dev/api` (aplikasi mobile dev memakai alamat API ini).
Cadangan tanpa gerbang, dari jaringan lokal/VPN: `http://10.10.3.41:3013` dan `http://10.10.3.41:4003`.
Stack ini terpisah dari produksi: container `catu_dev_*`, database `catu_dev` dengan user `catu_dev`, JWT sendiri,
WhatsApp/FCM/penyimpanan APK dimatikan. Admin web dev menampilkan pita merah **LINGKUNGAN DEV** dan memakai kunci
localStorage berawalan `dev_`, jadi login dev tidak menimpa sesi produksi (alamatnya satu origin dengan produksi).

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
4. Gerbang web (nginx) yang melayani `catu.devoutsys.com` harus meneruskan dua jalur ke server dev. Backend menerima `/api/...`
   maupun tanpa `/api`, jadi awalan boleh dibuang. Tambahkan di blok server `catu.devoutsys.com`, di atas lokasi umum
   (ganti `10.10.3.41` bila gerbang berada di mesin lain; bila satu mesin dengan server dev, `127.0.0.1` juga boleh):
   ```nginx
   location = /dev { return 301 /dev/; }
   location /dev/api/ {
     proxy_pass http://10.10.3.41:4003/;
     proxy_set_header Host $host;
     proxy_set_header X-Real-IP $remote_addr;
     proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
     proxy_set_header X-Forwarded-Proto $scheme;
     client_max_body_size 50m;
   }
   location /dev/ {
     proxy_pass http://10.10.3.41:3013/;
     proxy_set_header Host $host;
     proxy_set_header X-Forwarded-Proto $scheme;
   }
   ```
   Uji `nginx -t`, cadangkan berkas asli lebih dulu, lalu `nginx -s reload`. Buka `https://catu.devoutsys.com/dev/`:
   pita merah **LINGKUNGAN DEV** harus muncul.

## APK uji (CATU Dev)
Aplikasi uji (ID `.dev`, nama "CATU Dev") dibagikan seperti produksi lewat tautan: `http://10.10.3.41:4003/public/apk`
(jaringan lokal/VPN). Sekali di server: `mkdir -p ~/Documents/catu-v2-dev/apk && chmod 777 ~/Documents/catu-v2-dev/apk`
(container berjalan sebagai user non-root), lalu `docker compose up -d`. Unggah dari Mac dengan
`scripts/mobile/deploy_dev_apk.sh` (kredensial admin DEV dari environment; menolak alamat produksi).
Isi `PUBLIC_APK_URL=http://10.10.3.41:4003/public/apk` di `.env` dev agar unduhan di admin web dev menunjuk ke sana.

## Memperbarui DEV
`cd ~/Documents/catu-v2-dev && docker compose pull && docker compose up -d`

## Aturan aman
- Jangan salin `.env` produksi ke sini. Jangan isi `WAGATE_*`, `SENSIO_ENV_CONFIG_*`, atau berkas Firebase produksi.
- Jangan unggah APK dari admin web DEV (penyimpanan APK dimatikan; tautan APK produksi tidak berubah).
- Mengisi data uji: pakai akun uji; jangan restore dump produksi ke `catu_dev` tanpa menyamarkan nomor HP pengguna.
