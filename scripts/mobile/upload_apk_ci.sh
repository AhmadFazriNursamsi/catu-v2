#!/bin/bash
# upload_apk_ci.sh - unggah APK RILIS ke server dengan token unggah khusus (APK_UPLOAD_TOKEN), lalu verifikasi hash
# berkas yang tersaji untuk publik. Dipakai GitHub Actions (.github/workflows/release-apk.yml); bisa juga manual.
#
#   APK_UPLOAD_TOKEN=... ./scripts/mobile/upload_apk_ci.sh [apk] [alamat-api]
#
# Token hanya dari environment dan dikirim lewat berkas header sementara (tidak muncul di daftar proses).
# Hanya APK rilis hasil build_production.sh (build/release/catu-v*.apk + .sha256). Bawaan alamat: produksi.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
APK_PATH="${1:-$(ls -t "$ROOT_DIR"/mobile/build/release/catu-v*.apk 2>/dev/null | head -1)}"
API="${2:-https://catu.devoutsys.com/api}"
API="${API%/}"

: "${APK_UPLOAD_TOKEN:?Set APK_UPLOAD_TOKEN di environment}"
[ -n "$APK_PATH" ] && [ -f "$APK_PATH" ] || { echo "❌ APK rilis tidak ditemukan (jalankan build_production.sh apk)."; exit 1; }
case "$(basename "$APK_PATH")" in *debug*) echo "❌ APK debug tidak boleh diunggah."; exit 1;; esac
case "$API" in https://*) ;; *) echo "❌ Alamat server harus https:// (didapat: $API)."; exit 1;; esac

sha() { if command -v sha256sum >/dev/null; then sha256sum "$1" | awk '{print $1}'; else shasum -a 256 "$1" | awk '{print $1}'; fi; }
EXPECTED=$(awk '{print $1}' "$APK_PATH.sha256" 2>/dev/null || true)
ACTUAL=$(sha "$APK_PATH")
[ -n "$EXPECTED" ] && [ "$EXPECTED" = "$ACTUAL" ] || { echo "❌ SHA-256 APK tidak cocok dengan $(basename "$APK_PATH").sha256."; exit 1; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
HDR="$TMP/hdr"; ( umask 077; printf 'X-Apk-Upload-Token: %s\n' "$APK_UPLOAD_TOKEN" > "$HDR" )

echo "APK    : $(basename "$APK_PATH") ($(du -h "$APK_PATH" | cut -f1))"
echo "SHA-256: $ACTUAL"
echo "Server : $API"

# 1. Utamakan object storage (S3) seperti produksi; bila tidak tersedia, ke disk server.
CODE=$(curl -sS -o "$TMP/url.json" -w '%{http_code}' -H @"$HDR" "$API/public/apk/ci/upload-url" || echo 000)
UPLOAD_URL=""
[ "$CODE" = "200" ] && UPLOAD_URL=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("uploadUrl",""))' "$TMP/url.json" 2>/dev/null || true)
case "$CODE" in 401|403) echo "❌ Token ditolak server (HTTP $CODE): $(cut -c1-200 "$TMP/url.json")"; exit 1;; esac

if [ -n "$UPLOAD_URL" ]; then
  echo "Unggah ke object storage..."
  CODE=$(curl -sS -o "$TMP/put.out" -w '%{http_code}' -X PUT -H "Content-Type: application/vnd.android.package-archive" --upload-file "$APK_PATH" "$UPLOAD_URL" || echo 000)
  [ "$CODE" = "200" ] || { echo "❌ Unggah ke object storage gagal (HTTP $CODE): $(cut -c1-200 "$TMP/put.out")"; exit 1; }
else
  echo "Object storage tidak tersedia (HTTP $CODE); unggah ke disk server..."
  CODE=$(curl -sS -o "$TMP/put.out" -w '%{http_code}' -X PUT -H @"$HDR" -H "Content-Type: application/vnd.android.package-archive" --upload-file "$APK_PATH" "$API/public/apk/ci/local" || echo 000)
  [ "$CODE" = "200" ] || { echo "❌ Unggah ke server gagal (HTTP $CODE): $(cut -c1-200 "$TMP/put.out")"; exit 1; }
fi

# 2. Pastikan yang diunduh publik adalah berkas ini.
for i in 1 2 3 4 5; do
  curl -sSL -o "$TMP/served.apk" "$API/public/apk" || true
  SERVED=$(sha "$TMP/served.apk" 2>/dev/null || echo -)
  if [ "$SERVED" = "$ACTUAL" ]; then echo "✅ Terunggah dan terverifikasi. Unduh: $API/public/apk"; exit 0; fi
  sleep 5
done
echo "❌ Berkas yang tersaji ($SERVED) berbeda dari yang diunggah ($ACTUAL)."
exit 1
