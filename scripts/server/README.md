# Deploy satu perintah (`deploy.sh`)

Menggantikan langkah manual (cadangan, tag rollback, pull, up, cek health). Dijalankan **di server**, dari folder compose.

## Pasang (sekali, dari Mac)
```
scp scripts/server/deploy.sh perkasa@10.10.3.41:~/Documents/catu-v2/deploy.sh
scp scripts/server/deploy.sh perkasa@10.10.3.41:~/Documents/catu-v2-dev/deploy.sh
ssh perkasa@10.10.3.41 'chmod +x ~/Documents/catu-v2/deploy.sh ~/Documents/catu-v2-dev/deploy.sh'
```

## Pakai
| Perintah | Fungsi |
|---|---|
| `./deploy.sh --check` | Periksa prasyarat; tidak mengubah apa pun |
| `./deploy.sh` | Deploy produksi |
| `CATU_HEALTH_URL=https://catu.devoutsys.com/dev/api/health ./deploy.sh` | Deploy dev (dari `~/Documents/catu-v2-dev`) |
| `./deploy.sh --rollback <STAMP>` | Kembali ke image deploy tertentu |

Dari Mac langsung: `ssh perkasa@10.10.3.41 'cd ~/Documents/catu-v2 && ./deploy.sh'`.

## Urutan kerja
1. Tandai image yang berjalan (`:rollback-<STAMP>`), lalu `pull`. Bila tidak ada image baru, berhenti tanpa mengubah apa pun.
2. Cadangkan DB (`pg_dump -n public -Fc`, kredensial dari `.env` tanpa dicetak), periksa isinya, salin compose dan `.env`.
   Bila gagal, berhenti; container lama tetap berjalan.
3. `up -d`, tunggu `/health` menjawab ok **dari proses baru** (uptime kecil), maksimal 2 menit.
4. Bila health gagal: cetak log backend, kembalikan image lama, `up -d` lagi. Database tidak diubah oleh skrip.
5. Simpan 10 cadangan deploy terakhir (`CATU_KEEP_BACKUPS`). Folder cadangan manual tidak disentuh.

Semua keluaran juga tersimpan di `backups/<STAMP>/deploy.log`.

## Pulihkan database (bila benar-benar perlu)
Skrip tidak pernah memulihkan DB otomatis. Manual, hanya skema public:
`pg_restore -n public --clean --if-exists --no-owner` dari `backups/<STAMP>/catu-db.dump`.

# Cadangan harian (`backup.sh`)

Cadangan database (`pg_dump -n public -Fc`) plus `docker-compose.yml`, `.env`, dan `firebase-service-account.json`
ke `backups/daily/<STAMP>/` di disk server, dengan `SHA256SUMS`. Hanya **7 cadangan harian terbaru** yang disimpan
(`CATU_BACKUP_DAYS`); cadangan deploy (`backups/<STAMP>`) dan manual tidak disentuh. Batal bila sisa disk < 2 GB.
APK tidak ikut karena disimpan di penyimpanan objek, bukan di disk server.

## Pasang (sekali)
```
scp scripts/server/backup.sh perkasa@10.10.3.41:~/Documents/catu-v2/backup.sh
ssh perkasa@10.10.3.41 'chmod +x ~/Documents/catu-v2/backup.sh && cd ~/Documents/catu-v2 && ./backup.sh'
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

Cadangan ini ada di disk yang sama dengan server: melindungi dari data terhapus/rusak dan rilis gagal, **tidak** dari
disk rusak atau server hilang. Sesekali salin satu cadangan ke luar server, mis. dari Mac:
`scp -r perkasa@10.10.3.41:~/Documents/catu-v2/backups/daily/<STAMP> ~/Backups/catu-server/`.

Pulihkan: sama seperti di atas, `pg_restore -n public --clean --if-exists --no-owner` dari `backups/daily/<STAMP>/catu-db.dump`.
