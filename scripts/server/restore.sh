#!/usr/bin/env bash
# restore.sh - pulihkan database CATU dari satu folder cadangan (backup.sh atau deploy.sh). MENIMPA data sekarang.
#
# Dijalankan DI SERVER, dari folder compose (produksi: ~/Documents/catu-v2):
#   ./restore.sh backups/daily/20261110-104945
#
# Urutan: cek SHA256SUMS -> minta ketik PULIHKAN -> cadangan pengaman data sekarang (backups/pre-restore-<STAMP>)
# -> hentikan backend -> pg_restore --clean (tanpa entri SCHEMA public, yang terikat ekstensi TimescaleDB)
# -> nyalakan backend -> cek health. .env dan berkas lain di folder cadangan TIDAK disalin balik otomatis.
#
# Pengaturan: CATU_PG_CONTAINER (bawaan shared-postgres-production), CATU_HEALTH_URL (bawaan produksi),
# CATU_RESTORE_YES=1 melewati pertanyaan (hanya untuk uji).
set -euo pipefail

PG_CONTAINER="${CATU_PG_CONTAINER:-shared-postgres-production}"
HEALTH_URL="${CATU_HEALTH_URL:-https://catu.devoutsys.com/api/health}"

say()  { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
fail() { say "GAGAL: $*"; exit 1; }
trap 'say "GAGAL: perintah di baris $LINENO keluar dengan kode $?."' ERR

SRC="${1:?pakai: ./restore.sh <folder cadangan>, mis. backups/daily/20261110-104945}"
SRC="${SRC%/}"
[ -f docker-compose.yml ] && [ -f .env ] || fail "Jalankan dari folder compose (mis. ~/Documents/catu-v2)."
[ -f "$SRC/catu-db.dump" ] || fail "$SRC/catu-db.dump tidak ada."
if [ -f "$SRC/SHA256SUMS" ]; then
  ( cd "$SRC" && sha256sum -c --quiet SHA256SUMS ) || fail "SHA256SUMS tidak cocok; berkas cadangan rusak."
  say "SHA256SUMS cocok."
fi

envval() { { grep -E "^$1=" .env || true; } | tail -1 | cut -d= -f2- | sed -e "s/^[\"']//" -e "s/[\"']$//"; }
DB_NAME=$(envval DB_NAME); DB_USER=$(envval DB_USERNAME); [ -n "$DB_USER" ] || DB_USER=$(envval DB_USER)
[ -n "$DB_NAME" ] || DB_NAME=$( { docker compose config 2>/dev/null || true; } | awk '/^[[:space:]]+DB_NAME:/ && !n {print $2; n=1}' | tr -d "\"'")
[ -n "$DB_NAME" ] && [ -n "$DB_USER" ] && [ -n "$(envval DB_PASSWORD)" ] || fail "DB_NAME / DB_USERNAME / DB_PASSWORD tidak lengkap."

say "Akan MENIMPA database '$DB_NAME' di $PG_CONTAINER dengan $SRC/catu-db.dump."
if [ "${CATU_RESTORE_YES:-}" != "1" ]; then
  read -r -p "Ketik PULIHKAN untuk melanjutkan: " ans
  [ "$ans" = "PULIHKAN" ] || fail "Dibatalkan. Tidak ada yang diubah."
fi

STAMP=$(date +%Y%m%d-%H%M%S)
SAFE="backups/pre-restore-$STAMP"
mkdir -m 700 -p "$SAFE"
PGPASSWORD=$(envval DB_PASSWORD); export PGPASSWORD
docker exec -e PGPASSWORD "$PG_CONTAINER" pg_dump -U "$DB_USER" -d "$DB_NAME" -n public -n drizzle -Fc > "$SAFE/catu-db.dump" \
  || fail "Cadangan pengaman gagal. Tidak ada yang diubah."
chmod 600 "$SAFE/catu-db.dump"
say "Cadangan pengaman data sekarang: $SAFE/catu-db.dump"

say "Menghentikan backend..."
docker compose stop backend
TMPD="/tmp/catu-restore-$STAMP"
docker exec "$PG_CONTAINER" mkdir -p "$TMPD"
docker cp "$SRC/catu-db.dump" "$PG_CONTAINER:$TMPD/c.dump"
RESTORE_OK=1
docker exec -e PGPASSWORD -e DB_USER="$DB_USER" -e DB_NAME="$DB_NAME" -e T="$TMPD" "$PG_CONTAINER" sh -c '
  pg_restore -l "$T/c.dump" | grep -Ev " SCHEMA - public | COMMENT - SCHEMA public " > "$T/c.list" &&
  pg_restore -U "$DB_USER" -d "$DB_NAME" --clean --if-exists --no-owner --no-privileges --single-transaction --exit-on-error -L "$T/c.list" "$T/c.dump"' \
  || RESTORE_OK=0
docker exec "$PG_CONTAINER" rm -rf "$TMPD" || true
unset PGPASSWORD

say "Menyalakan backend..."
docker compose start backend
if [ "$RESTORE_OK" = 0 ]; then
  fail "pg_restore gagal; karena --single-transaction, database TIDAK berubah. Backend dinyalakan kembali dengan data lama."
fi
for _ in $(seq 1 40); do
  if curl -fsS --max-time 5 "$HEALTH_URL" 2>/dev/null | grep -q '"status":"ok"'; then
    say "BERHASIL. Database dipulihkan dari $SRC dan health ok."
    say "Bila perlu kembali ke data sebelum pemulihan: ./restore.sh $SAFE"
    exit 0
  fi
  sleep 3
done
fail "Database sudah dipulihkan, tapi health belum ok. Periksa: docker compose logs backend --tail 100"
