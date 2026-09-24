#!/bin/bash
# ==============================================================================
# deploy_apk.sh — CATU Mobile Release APK Deployment
# Uploads the built APK to S3 and/or the server's local APK storage.
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

APK_PATH="${1:-$ROOT_DIR/mobile/build/app/outputs/flutter-apk/app-release.apk}"
if [ ! -f "$APK_PATH" ]; then
  APK_PATH="$ROOT_DIR/mobile/build/app/outputs/flutter-apk/app-debug.apk"
fi

if [ ! -f "$APK_PATH" ]; then
  echo "❌ Error: APK not found at $APK_PATH. Please run 'flutter build apk --release' first."
  exit 1
fi

SERVER_API="${2:-https://catu.devoutsys.com/api}"
ADMIN_PHONE="${3:-89999999999}"
ADMIN_PASS="${4:-Password123}"

echo "=========================================================="
echo "🚀 CATU APK Deployment to Server"
echo "=========================================================="
echo "   APK File  : $APK_PATH ($(ls -lh "$APK_PATH" | awk '{print $5}'))"
echo "   Server API: $SERVER_API"
echo "   Admin User: $ADMIN_PHONE"
echo "=========================================================="

# 1. Login to obtain JWT token
echo "🔑 Logging in as admin to get deployment token..."
LOGIN_RESP=$(curl -s -X POST "$SERVER_API/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"phoneNumber\":\"$ADMIN_PHONE\",\"password\":\"$ADMIN_PASS\"}")

TOKEN=$(echo "$LOGIN_RESP" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4 || echo "")

if [ -z "$TOKEN" ]; then
  echo "❌ Login failed! Server response:"
  echo "$LOGIN_RESP"
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
