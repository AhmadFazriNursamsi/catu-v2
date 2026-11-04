#!/bin/bash
# deploy_dev_apk.sh - mengunggah APK debug "CATU Dev" ke server DEV (BUKAN produksi).
# Hasilnya bisa diunduh dari http://<server-dev>:4003/public/apk (tautan/QR seperti produksi), tanpa kabel/adb.
#
#   flutter build apk --debug --dart-define=CATU_API_URL=http://10.10.3.41:4003     # di folder mobile/
#   read -s ADMIN_PASSWORD; export ADMIN_PASSWORD                                  # sandi admin DEV, bukan produksi
#   ADMIN_PHONE=62xxxxxxxxxx ./scripts/mobile/deploy_dev_apk.sh [apk] [alamat-api-dev]
#
# Kredensial hanya dari environment. Skrip menolak alamat produksi. Koneksi http hanya untuk jaringan lokal/VPN.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
APK_PATH="${1:-$ROOT_DIR/mobile/build/app/outputs/flutter-apk/app-debug.apk}"
DEV_API="${2:-http://10.10.3.41:4003}"
DEV_API="${DEV_API%/}"

case "$DEV_API" in
  *catu.devoutsys.com/api*|https://catu.devoutsys.com|https://catu.devoutsys.com/) echo "❌ Ini skrip DEV; alamat produksi ditolak. Untuk produksi pakai deploy_apk.sh."; exit 1;;
esac
[ -f "$APK_PATH" ] || { echo "❌ APK tidak ditemukan: $APK_PATH"; exit 1; }
case "$(basename "$APK_PATH")" in *debug*) ;; *) echo "❌ Hanya APK debug (CATU Dev) yang boleh diunggah ke DEV."; exit 1;; esac
: "${ADMIN_PHONE:?Set ADMIN_PHONE (admin DEV, 62xxxxxxxxxx)}"
: "${ADMIN_PASSWORD:?Set ADMIN_PASSWORD (admin DEV) lewat: read -s ADMIN_PASSWORD; export ADMIN_PASSWORD}"

ACTUAL=$(shasum -a 256 "$APK_PATH" | awk '{print $1}')
echo "APK      : $APK_PATH ($(ls -lh "$APK_PATH" | awk '{print $5}'))"
echo "SHA-256  : $ACTUAL"
echo "Server   : $DEV_API"

LOGIN_RESP=$(python3 -c 'import json,os;print(json.dumps({"phoneNumber":os.environ["ADMIN_PHONE"],"password":os.environ["ADMIN_PASSWORD"]}))' \
  | curl -s -X POST "$DEV_API/auth/admin/login" -H "Content-Type: application/json" --data-binary @-)
TOKEN=$(echo "$LOGIN_RESP" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4 || true)
[ -n "$TOKEN" ] || { echo "❌ Login admin DEV gagal:"; echo "$LOGIN_RESP" | cut -c1-200; exit 1; }

CODE=$(curl -s -o /tmp/deploy_dev_apk.out -w "%{http_code}" -X PUT "$DEV_API/public/apk/local" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/octet-stream" --data-binary "@$APK_PATH")
[ "$CODE" = "200" ] || { echo "❌ Unggah gagal (HTTP $CODE):"; cut -c1-200 /tmp/deploy_dev_apk.out; exit 1; }

SERVED=$(curl -sL "$DEV_API/public/apk" | shasum -a 256 | awk '{print $1}')
[ "$SERVED" = "$ACTUAL" ] && echo "✅ Terunggah dan terverifikasi. Unduh: $DEV_API/public/apk" || { echo "❌ Hash yang disajikan server berbeda ($SERVED)."; exit 1; }
