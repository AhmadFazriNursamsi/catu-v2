#!/bin/bash
# ==============================================================================
# deploy_apk.sh — CATU Mobile Release APK Deployment
# Uploads the built APK to S3 and/or the server's local APK storage.
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
RELEASE_DIR="$ROOT_DIR/mobile/build/release"

# Hanya APK RILIS hasil build_production.sh (build/release/catu-v*.apk). APK debug tidak pernah diunggah.
APK_PATH="${1:-$(ls -t "$RELEASE_DIR"/catu-v*.apk 2>/dev/null | head -1)}"
if [ -z "$APK_PATH" ] || [ ! -f "$APK_PATH" ]; then
  echo "❌ APK rilis tidak ditemukan. Jalankan './scripts/mobile/build_production.sh apk' terlebih dahulu."
  exit 1
fi
case "$(basename "$APK_PATH")" in *debug*) echo "❌ APK debug tidak boleh diunggah."; exit 1;; esac

SERVER_API="${2:-https://catu.devoutsys.com/api}"
case "$SERVER_API" in https://*) ;; *) echo "❌ Alamat server harus diawali https:// (didapat: $SERVER_API)."; exit 1;; esac

# Kredensial HANYA dari environment (tidak ada nilai bawaan; tidak lewat argumen agar tidak terlihat di daftar proses/riwayat shell).
: "${ADMIN_PHONE:?Set ADMIN_PHONE (nomor admin, 62xxxxxxxxxx) di environment}"
: "${ADMIN_PASSWORD:?Set ADMIN_PASSWORD di environment (jangan ditulis di baris perintah)}"

# Integritas: SHA-256 harus sama dengan berkas .sha256 hasil build, dan tanda tangan bukan kunci debug.
EXPECTED=$(awk '{print $1}' "$APK_PATH.sha256" 2>/dev/null || true)
ACTUAL=$(shasum -a 256 "$APK_PATH" | awk '{print $1}')
[ -n "$EXPECTED" ] && [ "$EXPECTED" = "$ACTUAL" ] || { echo "❌ SHA-256 APK tidak cocok dengan $(basename "$APK_PATH").sha256 (berkas berubah/bukan hasil build_production.sh)."; exit 1; }
ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
BT=$(ls -d "$ANDROID_HOME"/build-tools/* 2>/dev/null | sort -V | tail -1)
if [ -n "$BT" ] && "$BT/apksigner" verify --print-certs "$APK_PATH" | grep -qi "Android Debug"; then echo "❌ APK ditandatangani kunci debug."; exit 1; fi

echo "=========================================================="
echo "🚀 CATU APK Deployment to Server"
echo "=========================================================="
echo "   APK File  : $APK_PATH ($(ls -lh "$APK_PATH" | awk '{print $5}'))"
echo "   SHA-256   : $ACTUAL"
echo "   Server API: $SERVER_API"
echo "   Admin User: $ADMIN_PHONE"
echo "=========================================================="

# 1. Login to obtain JWT token (kredensial dikirim lewat stdin, bukan argumen baris perintah)
echo "🔑 Logging in as admin to get deployment token..."
LOGIN_RESP=$(python3 -c 'import json,os;print(json.dumps({"phoneNumber":os.environ["ADMIN_PHONE"],"password":os.environ["ADMIN_PASSWORD"]}))' | curl -s -X POST "$SERVER_API/auth/admin/login" \
  -H "Content-Type: application/json" \
  --data-binary @-)

TOKEN=$(echo "$LOGIN_RESP" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4 || echo "")

if [ -z "$TOKEN" ]; then
  echo "❌ Login failed! Server response (tanpa kredensial):"
  echo "$LOGIN_RESP" | cut -c1-200
  exit 1
fi
echo "✅ Authenticated successfully."

# 2. Try S3 presigned upload
echo "☁️  Attempting S3 Presigned Upload..."
UPLOAD_URL_RESP=$(curl -s -X GET "$SERVER_API/public/apk/upload-url" \
  -H "Authorization: Bearer $TOKEN")

S3_UPLOAD_URL=$(echo "$UPLOAD_URL_RESP" | grep -o '"uploadUrl":"[^"]*' | cut -d'"' -f4 || echo "")

DEPLOYED=false
if [ -n "$S3_UPLOAD_URL" ]; then
  echo "⬆️  Uploading directly to AWS S3 bucket..."
  S3_HTTP_STATUS=$(curl -s -w "%{http_code}" -o /tmp/s3_upload.log -X PUT \
    -H "Content-Type: application/vnd.android.package-archive" \
    --upload-file "$APK_PATH" \
    "$S3_UPLOAD_URL")

  if [ "$S3_HTTP_STATUS" = "200" ]; then
    echo "✅ S3 Upload Successful (HTTP 200)!"
    DEPLOYED=true
  else
    echo "⚠️  S3 Upload returned HTTP $S3_HTTP_STATUS. Details:"
    cat /tmp/s3_upload.log 2>/dev/null || true
    echo ""
  fi
fi

# 3. If S3 upload was not used or failed, upload directly to server local storage
if [ "$DEPLOYED" = false ]; then
  echo "🖥️  Uploading directly to server local storage (/api/public/apk/local)..."
  LOCAL_RESP=$(curl -s -X PUT "$SERVER_API/public/apk/local" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/vnd.android.package-archive" \
    --upload-file "$APK_PATH")
  echo "✅ Server response: $LOCAL_RESP"
fi

# 4. Verification
echo ""
echo "🔍 Verifying public download endpoint ($SERVER_API/public/apk)..."
curl -sI "$SERVER_API/public/apk" | head -n 12

echo ""
echo "🎉 APK deployment finished! Users downloading from $SERVER_API/public/apk will now get this APK."
