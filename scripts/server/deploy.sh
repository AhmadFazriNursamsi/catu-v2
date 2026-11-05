#!/usr/bin/env bash
# deploy.sh - perbarui layanan CATU di server dalam SATU perintah, dengan cadangan dan mundur otomatis.
#
# Dijalankan DI SERVER, dari folder compose (produksi: ~/Documents/catu-v2, dev: ~/Documents/catu-v2-dev):
#   ./deploy.sh              # deploy: cadangan DB -> tag rollback -> pull -> up -> cek health -> mundur bila gagal
#   ./deploy.sh --check      # hanya memeriksa prasyarat (tanpa mengubah apa pun)
#   ./deploy.sh --rollback 20261105-1405   # kembali ke image yang ditandai pada deploy itu
#
# Pengaturan (opsional, lewat environment):
#   CATU_HEALTH_URL   alamat health (bawaan: produksi https://catu.devoutsys.com/api/health;
#                     dev: https://catu.devoutsys.com/dev/api/health)
#   CATU_PG_CONTAINER container Postgres (bawaan: shared-postgres-production)
#   CATU_KEEP_BACKUPS jumlah cadangan deploy yang disimpan (bawaan: 10)
#   CATU_DB_NAME / CATU_DB_USER  bila .env tidak memuat DB_NAME / DB_USERNAME (mis. produksi: catu / rootdba)
#
# Kredensial DB dibaca dari .env (DB_NAME, DB_USERNAME/DB_USER, DB_PASSWORD) tanpa dicetak dan tanpa masuk argumen
# perintah. Hanya skema public yang dicadangkan (katalog TimescaleDB milik aplikasi lain tidak ikut).
set -euo pipefail

HEALTH_URL="${CATU_HEALTH_URL:-https://catu.devoutsys.com/api/health}"
PG_CONTAINER="${CATU_PG_CONTAINER:-shared-postgres-production}"
KEEP="${CATU_KEEP_BACKUPS:-10}"
HEALTH_TRIES="${CATU_HEALTH_TRIES:-40}"   # x HEALTH_SLEEP detik = 2 menit
HEALTH_SLEEP="${CATU_HEALTH_SLEEP:-3}"
MODE="deploy"
ROLLBACK_STAMP=""

case "${1:-}" in
  "") ;;
  --check) MODE="check" ;;
  --rollback) MODE="rollback"; ROLLBACK_STAMP="${2:?Isi STAMP, contoh: ./deploy.sh --rollback 20261105-1405}" ;;
  -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
  *) echo "Argumen tidak dikenal: $1 (pakai --help)"; exit 2 ;;
esac

say()  { printf '%s %s\n' "$(date +%H:%M:%S)" "$*"; }
fail() { say "GAGAL: $*"; exit 1; }

[ -f docker-compose.yml ] || fail "docker-compose.yml tidak ada. Jalankan dari folder compose (mis. ~/Documents/catu-v2)."
[ -f .env ] || fail ".env tidak ada di folder ini."
command -v curl >/dev/null || fail "curl tidak terpasang."

# Satu deploy dalam satu waktu.
exec 9>"/tmp/catu-deploy-$(id -u)-$(basename "$PWD").lock"
command -v flock >/dev/null && { flock -n 9 || fail "Deploy lain sedang berjalan di folder ini."; }

envval() { # nilai dari .env tanpa mengeksekusi isinya; tanda kutip di ujung dibuang
  { grep -E "^$1=" .env || true; } | tail -1 | cut -d= -f2- | sed -e "s/^[\"']//" -e "s/[\"']$//"
}

IMAGES=$(docker compose config --images 2>/dev/null | sort -u || true)
[ -n "$IMAGES" ] || IMAGES=$(grep -E '^[[:space:]]*image:' docker-compose.yml | awk '{print $2}' | tr -d "\"'" | sort -u)
[ -n "$IMAGES" ] || fail "Tidak bisa membaca daftar image dari docker-compose.yml."
image_id() { docker image inspect -f '{{.Id}}' "$1" 2>/dev/null || echo "-"; }
retag()    { local ref="$1" tag="$2"; echo "${ref%:*}:$tag"; }

health_ok() { # health menjawab ok DAN berasal dari proses baru (uptime < batas detik)
  local max_uptime="$1" body up
  body=$(curl -fsS --max-time 5 "$HEALTH_URL" 2>/dev/null) || return 1
  echo "$body" | grep -q '"status":"ok"' || return 1
  [ -z "$max_uptime" ] && return 0
  up=$(echo "$body" | grep -o '"uptimeSeconds":[0-9]*' | cut -d: -f2)
  [ -n "$up" ] && [ "$up" -le "$max_uptime" ]
}

wait_health() {
  local started="$1" i
  for i in $(seq 1 "$HEALTH_TRIES"); do
    if health_ok "$(( $(date +%s) - started + 5 ))"; then return 0; fi
    sleep "$HEALTH_SLEEP"
  done
  return 1
}

restore_images() { # $1 = STAMP
  local ref tag_ref
  for ref in $IMAGES; do
    tag_ref=$(retag "$ref" "rollback-$1")
    if docker image inspect "$tag_ref" >/dev/null 2>&1; then
      docker tag "$tag_ref" "$ref"; say "Dikembalikan: $ref <- rollback-$1"
    else
      say "Peringatan: $tag_ref tidak ada, $ref dibiarkan."
    fi
  done
  local started; started=$(date +%s)
  docker compose up -d
  if wait_health "$started"; then say "Layanan kembali sehat dengan image rollback-$1."; else say "Health masih gagal setelah mundur. Periksa: docker compose logs backend --tail 100"; return 1; fi
}

# ---------------------------------------------------------------- --check
if [ "$MODE" = "check" ]; then
  say "Folder      : $PWD"
  say "Health      : $HEALTH_URL"
  for ref in $IMAGES; do say "Image       : $ref ($(image_id "$ref" | cut -c8-19))"; done
  DB_NAME="${CATU_DB_NAME:-$(envval DB_NAME)}"; DB_USER="${CATU_DB_USER:-$(envval DB_USERNAME)}"; [ -n "$DB_USER" ] || DB_USER=$(envval DB_USER)
  [ -n "$DB_NAME" ] || fail "DB_NAME tidak ada di .env."
  [ -n "$DB_USER" ] || fail "DB_USERNAME (atau DB_USER) tidak ada di .env."
  [ -n "$(envval DB_PASSWORD)" ] || fail "DB_PASSWORD tidak ada di .env."
  docker inspect "$PG_CONTAINER" >/dev/null 2>&1 || fail "Container Postgres '$PG_CONTAINER' tidak ditemukan (atur CATU_PG_CONTAINER)."
  say "Database    : $DB_NAME (user $DB_USER) di $PG_CONTAINER"
  health_ok "" && say "Health sekarang: ok" || say "Health sekarang: TIDAK ok"
  say "Prasyarat lengkap. Tidak ada yang diubah."
  exit 0
fi

# ---------------------------------------------------------------- --rollback
if [ "$MODE" = "rollback" ]; then
  restore_images "$ROLLBACK_STAMP"
  exit $?
fi

# ---------------------------------------------------------------- deploy
STAMP=$(date +%Y%m%d-%H%M%S)
DIR="backups/$STAMP"
mkdir -p "$DIR"
exec > >(tee -a "$DIR/deploy.log") 2>&1
say "Deploy $STAMP di $PWD"

# 1. Tandai image yang sedang dipakai, sebelum pull menimpa :latest.
for ref in $IMAGES; do
  echo "$ref $(image_id "$ref")" >> "$DIR/images-before.txt"
  docker image inspect "$ref" >/dev/null 2>&1 && docker tag "$ref" "$(retag "$ref" "rollback-$STAMP")"
done

# 2. Ambil image baru; berhenti bila tidak ada yang berubah.
docker compose pull
CHANGED=0
for ref in $IMAGES; do
  before=$(grep "^$ref " "$DIR/images-before.txt" | cut -d' ' -f2); after=$(image_id "$ref")
  echo "$ref $after" >> "$DIR/images-after.txt"
  if [ "$before" != "$after" ]; then CHANGED=1; say "Baru: $ref (${before:7:12} -> ${after:7:12})"; fi
done
if [ "$CHANGED" = 0 ]; then
  say "Tidak ada image baru. Tidak ada yang diubah."
  for ref in $IMAGES; do docker rmi "$(retag "$ref" "rollback-$STAMP")" >/dev/null 2>&1 || true; done
  rm -rf "$DIR"
  exit 0
fi

# 3. Cadangkan database (skema public) dan konfigurasi.
DB_NAME="${CATU_DB_NAME:-$(envval DB_NAME)}"; DB_USER="${CATU_DB_USER:-$(envval DB_USERNAME)}"; [ -n "$DB_USER" ] || DB_USER=$(envval DB_USER)
[ -n "$DB_NAME" ] && [ -n "$DB_USER" ] || fail "DB_NAME / DB_USERNAME tidak ada di .env. Tidak ada yang diubah (container lama masih berjalan)."
PGPASSWORD=$(envval DB_PASSWORD); export PGPASSWORD
docker exec -e PGPASSWORD "$PG_CONTAINER" pg_dump -U "$DB_USER" -d "$DB_NAME" -n public -Fc > "$DIR/catu-db.dump" \
  || { unset PGPASSWORD; fail "pg_dump gagal. Tidak ada yang diubah (container lama masih berjalan)."; }
unset PGPASSWORD
TABLES=$(docker exec -i "$PG_CONTAINER" pg_restore -l < "$DIR/catu-db.dump" | grep -c "TABLE DATA public" || true)
[ "${TABLES:-0}" -gt 0 ] || fail "Cadangan tidak berisi tabel. Tidak ada yang diubah (container lama masih berjalan)."
cp docker-compose.yml "$DIR/"; cp .env "$DIR/env.bak"; chmod 600 "$DIR/env.bak" "$DIR/catu-db.dump"
touch "$DIR/.deploy-backup"
say "Cadangan: $DIR/catu-db.dump ($(du -h "$DIR/catu-db.dump" | cut -f1), $TABLES tabel)"

# 4. Jalankan versi baru dan tunggu health dari proses baru.
STARTED=$(date +%s)
docker compose up -d
if wait_health "$STARTED"; then
  say "BERHASIL. Health ok dari proses baru."
else
  say "Health gagal dalam $((HEALTH_TRIES * HEALTH_SLEEP)) detik. Log backend:"
  docker compose logs backend --tail 60 || true
  say "Mundur otomatis ke image sebelumnya..."
  restore_images "$STAMP" || true
  fail "Deploy dibatalkan; versi lama dipulihkan. Cadangan DB tetap di $DIR (database tidak diubah oleh skrip)."
fi

# 5. Simpan hanya $KEEP cadangan deploy terakhir (hanya folder buatan skrip ini).
ls -1d backups/*/.deploy-backup 2>/dev/null | sed 's#/.deploy-backup##' | sort -r | tail -n +$((KEEP + 1)) | while read -r old; do
  rm -rf "$old"; say "Cadangan lama dihapus: $old"
  for ref in $IMAGES; do docker rmi "$(retag "$ref" "rollback-$(basename "$old")")" >/dev/null 2>&1 || true; done
done

say "Selesai. Mundur bila perlu: ./deploy.sh --rollback $STAMP"
