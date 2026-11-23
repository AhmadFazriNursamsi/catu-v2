#!/usr/bin/env bash
# backup.sh - cadangan harian CATU di disk server: database (skema public + drizzle) + konfigurasi. Pulihkan: restore.sh. Simpan N hari terakhir.
#
# Dijalankan DI SERVER, dari folder compose (produksi: ~/Documents/catu-v2):
#   ./backup.sh            # buat cadangan sekarang, lalu hapus cadangan harian yang lebih lama dari N hari
#   ./backup.sh --list     # tampilkan cadangan harian yang ada (tanpa mengubah apa pun)
#   ./backup.sh --status   # perbarui ringkasan backup-status/status.json saja (dipanggil juga oleh deploy.sh)
#
# Ringkasan backup-status/status.json (TANPA rahasia: hanya tanggal, ukuran, jumlah tabel, status cloud) dibaca backend
# untuk halaman admin /catubackup lewat mount read-only ./backup-status:/app/backup-status:ro. Folder cadangan sendiri
# tidak pernah di-mount ke container.
#
# Cron (sekali pasang, `crontab -e`), tiap hari 02.15 waktu server:
#   15 2 * * * cd ~/Documents/catu-v2 && ./backup.sh >> backups/daily/cron.log 2>&1
#
# Pengaturan (opsional, lewat environment):
#   CATU_PG_CONTAINER   container Postgres (bawaan: shared-postgres-production)
#   CATU_BACKUP_DAYS    berapa cadangan harian terbaru yang disimpan (bawaan: 7)
#   CATU_MIN_FREE_MB    batal bila sisa disk di bawah ini (bawaan: 2048)
#   CATU_CLOUD_DIR      folder konfigurasi salinan cloud (bawaan: ~/.catu-backup, lihat di bawah)
#
# Salinan ke AWS S3 (aktif bila ~/.catu-backup/s3.conf ada; dibuat oleh backup-s3-setup.sh dari Mac):
#   s3.conf          CATU_S3_BUCKET=..., CATU_S3_REGION=..., opsional CATU_S3_PREFIX=... (bawaan daily/; bucket bersama:
#                    mis. catu-backups/daily/ agar hanya menulis ke folder CATU)
#   aws-credentials  kunci IAM yang HANYA boleh menulis ke s3://<bucket>/daily/ (tidak bisa membaca/menghapus)
#   passphrase       kunci enkripsi; cadangan dienkripsi (AES-256, openssl) SEBELUM diunggah
# Gagal unggah tidak membatalkan cadangan lokal; tercatat "Cloud: GAGAL" di log.
#
# Kredensial DB dibaca dari .env tanpa dicetak dan tanpa masuk argumen perintah. Hanya folder buatan skrip ini
# (backups/daily/<STAMP> yang berisi penanda .daily-backup) yang pernah dihapus; cadangan deploy dan manual tidak disentuh.
set -euo pipefail

PG_CONTAINER="${CATU_PG_CONTAINER:-shared-postgres-production}"
KEEP="${CATU_BACKUP_DAYS:-7}"
MIN_FREE_MB="${CATU_MIN_FREE_MB:-2048}"
ROOT="backups/daily"
CLOUD_DIR="${CATU_CLOUD_DIR:-$HOME/.catu-backup}"
AWS_IMAGE="amazon/aws-cli:2.17.0"

say()  { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
fail() { say "GAGAL: $*"; exit 1; }
trap 'say "GAGAL: perintah di baris $LINENO keluar dengan kode $?."' ERR

[ -f docker-compose.yml ] || fail "docker-compose.yml tidak ada. Jalankan dari folder compose (mis. ~/Documents/catu-v2)."
[ -f .env ] || fail ".env tidak ada di folder ini."
case "$KEEP" in ''|*[!0-9]*|0) fail "CATU_BACKUP_DAYS harus angka >= 1." ;; esac

list_backups() { { ls -1d "$ROOT"/*/.daily-backup 2>/dev/null || true; } | sed 's#/.daily-backup##' | sort -r; }

info() { { grep -E "^$2=" "$1/info" 2>/dev/null || true; } | tail -1 | cut -d= -f2-; }
conf() { { grep -E "^$1=" "$CLOUD_DIR/s3.conf" 2>/dev/null || true; } | tail -1 | cut -d= -f2- | tr -d "\"' "; }
jstr() { printf '"%s"' "$(printf '%s' "$1" | tr -d '"\\' | tr -d '\000-\037')"; }
jnum() { case "$1" in ''|*[!0-9]*) printf 'null' ;; *) printf '%s' "$1" ;; esac; }
# Ringkasan JSON tanpa rahasia, ditulis atomik ke backup-status/status.json (folder 755, berkas 644: terbaca container backend).
write_status() {
  local st="backup-status" d sep=""
  mkdir -p "$st"; chmod 755 "$st"
  {
    printf '{"generatedAt":%s,"keepDaily":%s,"cloudEnabled":%s,' "$(jstr "$(date -Iseconds)")" "$KEEP" "$([ -f "$CLOUD_DIR/s3.conf" ] && echo true || echo false)"
    printf '"cloudTarget":%s,' "$(jstr "$([ -f "$CLOUD_DIR/s3.conf" ] && echo "s3://$(conf CATU_S3_BUCKET)/$(conf CATU_S3_PREFIX)")")"
    printf '"disk":{"freeMb":%s,"usedPct":%s},"daily":[' "$(jnum "$(df -Pm . | awk 'NR==2{print $4}')")" "$(jnum "$(df -P . | awk 'NR==2{sub("%","",$5);print $5}')")"
    while read -r d; do
      [ -n "$d" ] || continue
      printf '%s{"stamp":%s,"bytes":%s,"tables":%s,"db":%s,"cloud":%s,"cloudAt":%s}' "$sep" "$(jstr "$(basename "$d")")" \
        "$(jnum "$(du -sb "$d" | cut -f1)")" "$(jnum "$(info "$d" tables)")" "$(jstr "$(info "$d" db)")" \
        "$(jstr "$(info "$d" cloud)")" "$(jstr "$(info "$d" cloud_at)")"
      sep=","
    done < <(list_backups); sep=""
    printf '],"deploy":['
    while read -r d; do
      [ -n "$d" ] || continue
      printf '%s{"stamp":%s,"bytes":%s}' "$sep" "$(jstr "$(basename "$d")")" "$(jnum "$(du -sb "$d" | cut -f1)")"; sep=","
    done < <({ ls -1d backups/*/.deploy-backup 2>/dev/null || true; } | sed 's#/.deploy-backup##' | sort -r | head -10)
    printf '],"cloudUploads":['; sep=""
    # Riwayat unggahan S3 (berkas S3 tidak ikut dihapus saat rotasi lokal): catatan dari unggahan berhasil, ditambah
    # cadangan lokal yang ditandai cloud=ok tetapi belum tercatat (mis. sebelum catatan ini ada). 120 terbaru.
    while IFS='|' read -r stamp key bytes sha at; do
      [ -n "$stamp" ] || continue
      printf '%s{"stamp":%s,"key":%s,"bytes":%s,"sha256":%s,"at":%s}' "$sep" "$(jstr "$stamp")" "$(jstr "$key")" "$(jnum "$bytes")" "$(jstr "$sha")" "$(jstr "$at")"; sep=","
    done < <({ cat "$st/cloud-uploads.log" 2>/dev/null || true
               list_backups | while read -r d; do
                 [ "$(info "$d" cloud)" = ok ] || continue
                 grep -q "^$(basename "$d")|" "$st/cloud-uploads.log" 2>/dev/null && continue
                 p=$(conf CATU_S3_PREFIX); p="${p:-daily/}"; [ "${p%/}" = "$p" ] && p="$p/"
                 printf '%s|%s|||%s\n' "$(basename "$d")" "$p$(basename "$d").tar.gz.enc" "$(info "$d" cloud_at)"
               done; } | sort -r -u -t'|' -k1,1 | head -120)
    printf ']}\n'
  } > "$st/status.json.tmp"
  chmod 644 "$st/status.json.tmp"; mv "$st/status.json.tmp" "$st/status.json"
}

case "${1:-}" in
  --list) list_backups | while read -r d; do printf '%s  %s\n' "$(du -sh "$d" | cut -f1)" "$d"; done; exit 0 ;;
  --status) write_status; exit 0 ;;
  '') ;;
  *) echo "Argumen tidak dikenal: $1 (pakai --list, --status, atau tanpa argumen)"; exit 2 ;;
esac

mkdir -p "$ROOT"; chmod 700 backups "$ROOT"
exec 9>"/tmp/catu-backup-$(id -u)-$(basename "$PWD").lock"
command -v flock >/dev/null && { flock -n 9 || fail "Cadangan lain sedang berjalan di folder ini."; }

FREE_MB=$(df -Pm "$ROOT" | awk 'NR==2{print $4}')
[ "${FREE_MB:-0}" -ge "$MIN_FREE_MB" ] || fail "Sisa disk ${FREE_MB} MB < ${MIN_FREE_MB} MB. Cadangan tidak dibuat."

envval() { # nilai dari .env tanpa mengeksekusi isinya; tanda kutip di ujung dibuang
  { grep -E "^$1=" .env || true; } | tail -1 | cut -d= -f2- | sed -e "s/^[\"']//" -e "s/[\"']$//"
}
DB_NAME=$(envval DB_NAME); DB_USER=$(envval DB_USERNAME); [ -n "$DB_USER" ] || DB_USER=$(envval DB_USER)
# Produksi menaruh DB_NAME di environment compose, bukan .env.
[ -n "$DB_NAME" ] || DB_NAME=$( { docker compose config 2>/dev/null || true; } | awk '/^[[:space:]]+DB_NAME:/ && !n {print $2; n=1}' | tr -d "\"'")
[ -n "$DB_NAME" ] && [ -n "$DB_USER" ] && [ -n "$(envval DB_PASSWORD)" ] || fail "DB_NAME / DB_USERNAME / DB_PASSWORD tidak lengkap."

STAMP=$(date +%Y%m%d-%H%M%S)
DIR="$ROOT/$STAMP"
TMP="$DIR.tmp"
rm -rf "$TMP"; mkdir -m 700 "$TMP"
trap 'rm -rf "$TMP"' EXIT

PGPASSWORD=$(envval DB_PASSWORD); export PGPASSWORD
docker exec -e PGPASSWORD "$PG_CONTAINER" pg_dump -U "$DB_USER" -d "$DB_NAME" -n public -n drizzle -Fc > "$TMP/catu-db.dump" \
  || { unset PGPASSWORD; fail "pg_dump gagal."; }
unset PGPASSWORD
TABLES=$(docker exec -i "$PG_CONTAINER" pg_restore -l < "$TMP/catu-db.dump" | grep -c "TABLE DATA public" || true)
[ "${TABLES:-0}" -gt 0 ] || fail "Cadangan tidak berisi tabel; dibuang."

cp docker-compose.yml "$TMP/"
cp .env "$TMP/env.bak"
[ -f backend/firebase-service-account.json ] && cp backend/firebase-service-account.json "$TMP/"
( cd "$TMP" && sha256sum ./* > SHA256SUMS )
chmod 600 "$TMP"/*
touch "$TMP/.daily-backup"
mv "$TMP" "$DIR"
trap - EXIT
printf 'tables=%s\ndb=%s\n' "$TABLES" "$DB_NAME" > "$DIR/info"; chmod 600 "$DIR/info"
say "Cadangan: $DIR ($(du -sh "$DIR" | cut -f1), $TABLES tabel, DB $DB_NAME)"

# Enkripsi lalu unggah ke s3://<bucket>/<prefix><STAMP>.tar.gz.enc. Hanya PutObject (tidak pernah list/hapus/ubah bucket).
# Kunci & passphrase tidak pernah masuk argumen perintah.
cloud_upload() {
  [ -f "$CLOUD_DIR/s3.conf" ] || { echo "cloud=skipped" >> "$DIR/info"; say "Cloud: belum dikonfigurasi ($CLOUD_DIR/s3.conf tidak ada), dilewati."; return 0; }
  local bucket region prefix out sum
  bucket=$(conf CATU_S3_BUCKET); region=$(conf CATU_S3_REGION); prefix=$(conf CATU_S3_PREFIX); prefix="${prefix:-daily/}"
  case "$prefix" in */) ;; *) prefix="$prefix/" ;; esac
  [ -n "$bucket" ] && [ -n "$region" ] && [ -s "$CLOUD_DIR/aws-credentials" ] && [ -s "$CLOUD_DIR/passphrase" ] \
    || { say "Cloud: s3.conf / aws-credentials / passphrase tidak lengkap."; return 1; }
  out=$(umask 077 && mktemp "/tmp/catu-cloud-$STAMP.XXXXXX")
  tar -C "$ROOT" -czf - "$STAMP" | openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt -pass "file:$CLOUD_DIR/passphrase" -out "$out" \
    || { rm -f "$out"; say "Cloud: enkripsi gagal."; return 1; }
  sum=$(sha256sum "$out" | cut -d' ' -f1)
  docker run --rm -v "$CLOUD_DIR/aws-credentials:/aws/credentials:ro" -v "$out:/data/backup:ro" \
    -e AWS_SHARED_CREDENTIALS_FILE=/aws/credentials -e AWS_DEFAULT_REGION="$region" "$AWS_IMAGE" \
    s3 cp /data/backup "s3://$bucket/$prefix$STAMP.tar.gz.enc" --only-show-errors --metadata "sha256=$sum" \
    || { rm -f "$out"; say "Cloud: unggah ke s3://$bucket gagal."; return 1; }
  local at; at=$(date -Iseconds)
  printf 'cloud=ok\ncloud_at=%s\n' "$at" >> "$DIR/info"
  mkdir -p backup-status; chmod 755 backup-status
  printf '%s|%s|%s|%s|%s\n' "$STAMP" "$prefix$STAMP.tar.gz.enc" "$(stat -c %s "$out")" "$sum" "$at" >> backup-status/cloud-uploads.log
  chmod 644 backup-status/cloud-uploads.log
  say "Cloud: s3://$bucket/$prefix$STAMP.tar.gz.enc ($(du -h "$out" | cut -f1), sha256 ${sum:0:12}…)"
  rm -f "$out"
}
cloud_upload || { echo "cloud=failed" >> "$DIR/info"; say "Cloud: GAGAL. Cadangan lokal tetap tersimpan di $DIR."; }

list_backups | tail -n +$((KEEP + 1)) | while read -r old; do
  rm -rf "$old"; say "Cadangan lama dihapus: $old"
done
write_status || say "Peringatan: ringkasan backup-status/status.json gagal ditulis."
say "Selesai. Tersimpan $(list_backups | wc -l | tr -d ' ') cadangan harian (maks $KEEP)."
