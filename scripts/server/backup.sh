#!/usr/bin/env bash
# backup.sh - cadangan harian CATU di disk server: database (skema public + drizzle) + konfigurasi. Pulihkan: restore.sh. Simpan N hari terakhir.
#
# Dijalankan DI SERVER, dari folder compose (produksi: ~/Documents/catu-v2):
#   ./backup.sh            # buat cadangan sekarang, lalu hapus cadangan harian yang lebih lama dari N hari
#   ./backup.sh --list     # tampilkan cadangan harian yang ada (tanpa mengubah apa pun)
#
# Cron (sekali pasang, `crontab -e`), tiap hari 02.15 waktu server:
#   15 2 * * * cd ~/Documents/catu-v2 && ./backup.sh >> backups/daily/cron.log 2>&1
#
# Pengaturan (opsional, lewat environment):
#   CATU_PG_CONTAINER   container Postgres (bawaan: shared-postgres-production)
#   CATU_BACKUP_DAYS    berapa cadangan harian terbaru yang disimpan (bawaan: 7)
#   CATU_MIN_FREE_MB    batal bila sisa disk di bawah ini (bawaan: 2048)
#
# Kredensial DB dibaca dari .env tanpa dicetak dan tanpa masuk argumen perintah. Hanya folder buatan skrip ini
# (backups/daily/<STAMP> yang berisi penanda .daily-backup) yang pernah dihapus; cadangan deploy dan manual tidak disentuh.
set -euo pipefail

PG_CONTAINER="${CATU_PG_CONTAINER:-shared-postgres-production}"
KEEP="${CATU_BACKUP_DAYS:-7}"
MIN_FREE_MB="${CATU_MIN_FREE_MB:-2048}"
ROOT="backups/daily"

say()  { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
fail() { say "GAGAL: $*"; exit 1; }
trap 'say "GAGAL: perintah di baris $LINENO keluar dengan kode $?."' ERR

[ -f docker-compose.yml ] || fail "docker-compose.yml tidak ada. Jalankan dari folder compose (mis. ~/Documents/catu-v2)."
[ -f .env ] || fail ".env tidak ada di folder ini."
case "$KEEP" in ''|*[!0-9]*|0) fail "CATU_BACKUP_DAYS harus angka >= 1." ;; esac

list_backups() { { ls -1d "$ROOT"/*/.daily-backup 2>/dev/null || true; } | sed 's#/.daily-backup##' | sort -r; }

if [ "${1:-}" = "--list" ]; then
  list_backups | while read -r d; do printf '%s  %s\n' "$(du -sh "$d" | cut -f1)" "$d"; done
  exit 0
fi
[ -z "${1:-}" ] || { echo "Argumen tidak dikenal: $1 (pakai --list atau tanpa argumen)"; exit 2; }

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
say "Cadangan: $DIR ($(du -sh "$DIR" | cut -f1), $TABLES tabel, DB $DB_NAME)"

list_backups | tail -n +$((KEEP + 1)) | while read -r old; do
  rm -rf "$old"; say "Cadangan lama dihapus: $old"
done
say "Selesai. Tersimpan $(list_backups | wc -l | tr -d ' ') cadangan harian (maks $KEEP)."
