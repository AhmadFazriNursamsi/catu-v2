# Deploy satu perintah (`deploy.sh`)

> Alamat server tidak ditulis di repo (repo publik). Sekali di Mac: `export CATU_SSH=<user>@<ip-server>` (simpan di `~/.zshrc`/`~/.bash_profile`).

Menggantikan langkah manual (cadangan, tag rollback, pull, up, cek health). Dijalankan **di server**, dari folder compose.

## Pasang (sekali, dari Mac)
```
scp scripts/server/deploy.sh "$CATU_SSH":~/Documents/catu-v2/deploy.sh
scp scripts/server/deploy.sh "$CATU_SSH":~/Documents/catu-v2-dev/deploy.sh
ssh "$CATU_SSH" 'chmod +x ~/Documents/catu-v2/deploy.sh ~/Documents/catu-v2-dev/deploy.sh'
```

## Pakai
| Perintah | Fungsi |
|---|---|
| `./deploy.sh --check` | Periksa prasyarat; tidak mengubah apa pun |
| `./deploy.sh` | Deploy produksi |
| `CATU_HEALTH_URL=https://catu.devoutsys.com/dev/api/health ./deploy.sh` | Deploy dev (dari `~/Documents/catu-v2-dev`) |
| `./deploy.sh --rollback <STAMP>` | Kembali ke image deploy tertentu |

Dari Mac langsung: `ssh "$CATU_SSH" 'cd ~/Documents/catu-v2 && ./deploy.sh'`.

## Urutan kerja
1. Tandai image yang berjalan (`:rollback-<STAMP>`), lalu `pull`. Bila tidak ada image baru, berhenti tanpa mengubah apa pun.
2. Cadangkan DB (`pg_dump -n public -n drizzle -Fc`, kredensial dari `.env` tanpa dicetak), periksa isinya, salin compose dan `.env`.
   Bila gagal, berhenti; container lama tetap berjalan.
3. `up -d`, tunggu `/health` menjawab ok **dari proses baru** (uptime kecil), maksimal 2 menit.
4. Bila health gagal: cetak log backend, kembalikan image lama, `up -d` lagi. Database tidak diubah oleh skrip.
5. Simpan 10 cadangan deploy terakhir (`CATU_KEEP_BACKUPS`). Folder cadangan manual tidak disentuh.

Semua keluaran juga tersimpan di `backups/<STAMP>/deploy.log`.

## Pulihkan database (bila benar-benar perlu)
`deploy.sh` tidak pernah memulihkan DB otomatis. Pakai `restore.sh` (lihat bagian di bawah) dengan `backups/<STAMP>`.

# Cadangan harian (`backup.sh`)

Cadangan database (`pg_dump -n public -n drizzle -Fc`; `drizzle` = catatan migrasi, wajib agar backend bisa start di DB hasil pulih) plus `docker-compose.yml`, `.env`, dan `firebase-service-account.json`
ke `backups/daily/<STAMP>/` di disk server, dengan `SHA256SUMS`. Hanya **7 cadangan harian terbaru** yang disimpan
(`CATU_BACKUP_DAYS`); cadangan deploy (`backups/<STAMP>`) dan manual tidak disentuh. Batal bila sisa disk < 2 GB.
APK tidak ikut karena disimpan di penyimpanan objek, bukan di disk server.

## Pasang (sekali)
```
scp scripts/server/backup.sh scripts/server/restore.sh scripts/server/deploy.sh "$CATU_SSH":~/Documents/catu-v2/
ssh "$CATU_SSH" 'cd ~/Documents/catu-v2 && chmod +x backup.sh restore.sh deploy.sh && ./backup.sh'
```
Lalu di server `crontab -e`, tambahkan:
```
15 2 * * * cd ~/Documents/catu-v2 && ./backup.sh >> backups/daily/cron.log 2>&1
```

## Pakai
| Perintah | Fungsi |
|---|---|
| `./backup.sh` | Buat cadangan sekarang |
| `./backup.sh --list` | Lihat cadangan harian yang ada |
| `tail backups/daily/cron.log` | Cek hasil cron |

Cadangan di disk server melindungi dari data terhapus/rusak dan rilis gagal, **tidak** dari disk rusak atau server hilang.
Karena itu tiap cadangan harian juga dikirim ke AWS S3 (bagian berikut).

## Salinan ke cloud (AWS S3)

Setelah cadangan lokal jadi, `backup.sh` mengemas folder cadangan, **mengenkripsinya** (AES-256, `openssl -pbkdf2`) lalu
mengunggahnya ke `s3://<bucket>/daily/<STAMP>.tar.gz.enc` lewat container `amazon/aws-cli` (tanpa memasang aws CLI di server).
Aktif bila `~/.catu-backup/s3.conf` ada. Gagal unggah tidak membatalkan cadangan lokal (log: `Cloud: GAGAL`).

Kunci di server **hanya** boleh `s3:PutObject` ke `daily/*`: tidak bisa membaca, menghapus, atau menimpa versi lama
(bucket ber-versioning). Cadangan cloud disimpan 90 hari (aturan lifecycle bucket).

### Pasang (sekali)
1. Di Mac, oleh pemilik akun AWS (membuat bucket privat + user IAM tulis-saja + kunci enkripsi):
   ```
   AWS_PROFILE=<profil-admin> AWS_SHARED_CREDENTIALS_FILE=<berkas-kredensial> scripts/server/backup-s3-setup.sh <nama-bucket> ap-southeast-1
   ```
   Hasil: `~/Backups/catu-s3/server-config/` (`s3.conf`, `aws-credentials`, `passphrase`). **Simpan isi `passphrase` di pengelola
   sandi**: tanpa itu cadangan cloud tidak bisa dibuka.
2. Salin ke server dan pasang `backup.sh` versi baru:
   ```
   scp -r ~/Backups/catu-s3/server-config "$CATU_SSH":~/.catu-backup
   ssh "$CATU_SSH" 'chmod 700 ~/.catu-backup && chmod 600 ~/.catu-backup/*'
   scp scripts/server/backup.sh "$CATU_SSH":~/Documents/catu-v2/backup.sh
   ssh "$CATU_SSH" 'cd ~/Documents/catu-v2 && ./backup.sh && tail -3 backups/daily/cron.log'
   ```

### Pulihkan dari cloud (server hilang / disk rusak)
Di mesin pengganti (atau Mac), dengan kredensial AWS admin (bukan kunci tulis-saja server):
```
aws s3 ls s3://<bucket>/daily/ | tail                                   # pilih STAMP
aws s3 cp s3://<bucket>/daily/<STAMP>.tar.gz.enc .
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -pass file:passphrase -in <STAMP>.tar.gz.enc | tar -xzf -
mkdir -p ~/Documents/catu-v2/backups/daily && mv <STAMP> ~/Documents/catu-v2/backups/daily/
```
Folder hasil berisi `docker-compose.yml`, `env.bak` (→ `.env`), `firebase-service-account.json` (→ `backend/`) untuk
menyalakan ulang CATU di server baru (`docker compose pull && docker compose up -d`, Postgres dengan TimescaleDB pg17),
lalu `./restore.sh backups/daily/<STAMP>`.

# Pemulihan (`restore.sh`)

```
cd ~/Documents/catu-v2 && ./backup.sh --list      # pilih cadangan
./restore.sh backups/daily/<STAMP>               # minta ketik PULIHKAN
```
Urutan: cek `SHA256SUMS` → cadangan pengaman data sekarang ke `backups/pre-restore-<STAMP>` → hentikan backend →
`pg_restore --clean --if-exists --single-transaction` → nyalakan backend → cek health. Bila `pg_restore` gagal, database
tidak berubah (satu transaksi). Batalkan pemulihan: `./restore.sh backups/pre-restore-<STAMP>`.
`.env` dan berkas lain di folder cadangan tidak disalin balik otomatis; salin manual bila memang hilang.

Catatan teknis (teruji 10 Nov 2026 di Postgres 17 + TimescaleDB): dump `-n public` membawa entri `SCHEMA public`,
sedangkan ekstensi TimescaleDB terikat ke schema itu, sehingga `pg_restore --clean` biasa gagal (`cannot drop schema public`).
`restore.sh` membuang entri itu lewat daftar `-L`. Memulihkan ke Postgres tanpa TimescaleDB tidak didukung.
Pulihkan ke database lain (uji): Postgres sumber harus punya TimescaleDB, mis. image `timescale/timescaledb:latest-pg17`.
