#!/bin/bash
# ==============================================================================
# build_production.sh — CATU Production Release Builder (APK dikirim langsung / iOS)
# Usage:
#   ./scripts/mobile/build_production.sh apk    # APK rilis berkode tanda tangan rilis, diverifikasi otomatis
#   ./scripts/mobile/build_production.sh ios    # iOS release
#   ./scripts/mobile/build_production.sh all    # keduanya
#
# Alamat server yang ditanam: CATU_RELEASE_API_URL (bawaan https://catu.devoutsys.com/api). Sengaja BUKAN CATU_API_URL
# dari .env (itu alamat backend lokal untuk pengembangan). Wajib https.
# APK rilis hanya dibangun bila keystore rilis ada (mobile/android/key.properties); tidak pernah memakai kunci debug.
# Panduan lengkap: mobile/RELEASE.md
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
MOBILE_DIR="$ROOT_DIR/mobile"
ROOT_ENV_FILE="$ROOT_DIR/.env"

# Konfigurasi iOS (opsional) dari .env
if [ -f "$ROOT_ENV_FILE" ]; then
  [ -z "${IOS_BUNDLE_ID:-}" ] && IOS_BUNDLE_ID=$(sed -n 's/^IOS_BUNDLE_ID=//p' "$ROOT_ENV_FILE" | head -1) || true
  [ -z "${IOS_DEVELOPMENT_TEAM:-}" ] && IOS_DEVELOPMENT_TEAM=$(sed -n 's/^IOS_DEVELOPMENT_TEAM=//p' "$ROOT_ENV_FILE" | head -1) || true
fi

TARGET_API_URL="${CATU_RELEASE_API_URL:-https://catu.devoutsys.com/api}"
BUILD_TARGET="${1:-apk}"
case "$TARGET_API_URL" in https://*) ;; *) echo "❌ CATU_RELEASE_API_URL harus diawali https:// (didapat: $TARGET_API_URL)"; exit 1;; esac

export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"

echo "=========================================================="
echo "🚀 CATU Mobile Production Builder"
echo "=========================================================="
echo "   Target Mode : $BUILD_TARGET"
echo "   API Endpoint: $TARGET_API_URL"
echo "=========================================================="

cd "$MOBILE_DIR"

VERSION_LINE=$(sed -n 's/^version: //p' pubspec.yaml | head -1)
VERSION_NAME="${VERSION_LINE%%+*}"; VERSION_CODE="${VERSION_LINE##*+}"
grep -q "appVersion = 'v$VERSION_NAME'" lib/core/constants/app_constants.dart || { echo "❌ AppConstants.appVersion tidak sama dengan versi di pubspec.yaml (v$VERSION_NAME)."; exit 1; }
echo "🏷️  Versi $VERSION_NAME (kode $VERSION_CODE)"

echo "📦 Resolving Flutter dependencies..."
flutter pub get

# ── Function: Build Android APK (dengan verifikasi otomatis) ──
build_apk() {
  echo ""
  echo "🤖 [1/2] Building Android Release APK..."
  [ -f android/key.properties ] || { echo "❌ android/key.properties belum ada. APK rilis tidak boleh memakai kunci debug (lihat mobile/RELEASE.md)."; exit 1; }

  flutter analyze --no-fatal-infos
  flutter test

  local SYMBOLS="build/symbols/$VERSION_NAME+$VERSION_CODE"; mkdir -p "$SYMBOLS"
  flutter build apk --release --obfuscate --split-debug-info="$SYMBOLS" --dart-define="CATU_API_URL=$TARGET_API_URL"

  local APK="build/app/outputs/flutter-apk/app-release.apk" BT
  [ -f "$APK" ] || { echo "❌ APK binary not found at $APK"; exit 1; }
  BT=$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -1)

  echo "🔎 Verifikasi APK..."
  local CERT; CERT=$("$BT/apksigner" verify --print-certs "$APK" | grep -E "certificate DN|SHA-256")
  echo "$CERT"
  echo "$CERT" | grep -qi "Android Debug" && { echo "❌ APK ditandatangani kunci debug."; exit 1; }
  local SCHEMES; SCHEMES=$("$BT/apksigner" verify --verbose "$APK")
  echo "$SCHEMES" | grep -qE "Verified using v2 scheme .*: true" || { echo "❌ Tanda tangan v2 tidak valid."; exit 1; }
  echo "$SCHEMES" | grep -qE "Verified using v3 scheme .*: true" || { echo "❌ Tanda tangan v3 tidak valid."; exit 1; }
  "$BT/aapt" dump badging "$APK" | grep -q "versionCode='$VERSION_CODE'" || { echo "❌ versionCode APK tidak sama dengan pubspec."; exit 1; }
  local MANIFEST; MANIFEST=$("$BT/aapt" dump xmltree "$APK" AndroidManifest.xml)
  echo "$MANIFEST" | grep -A1 "usesCleartextTraffic" | grep -q "0x0" || { echo "❌ APK masih mengizinkan HTTP tanpa enkripsi."; exit 1; }
  echo "$MANIFEST" | grep -A1 "allowBackup" | grep -q "0x0" || { echo "❌ APK mengizinkan cadangan data aplikasi (allowBackup)."; exit 1; }
  echo "$MANIFEST" | grep -q "debuggable" && { echo "❌ APK berstatus debuggable."; exit 1; }
  local LIBAPP; LIBAPP="$(mktemp)"
  unzip -p "$APK" 'lib/arm64-v8a/libapp.so' > "$LIBAPP"
  [ "$(strings "$LIBAPP" | grep -c -F "$TARGET_API_URL")" -ge 1 ] || { rm -f "$LIBAPP"; echo "❌ Alamat server tidak tertanam di APK."; exit 1; }
  if [ "$(strings "$LIBAPP" | grep -c -E "https?://(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.|localhost|127\.0\.0\.1)")" -gt 0 ]; then rm -f "$LIBAPP"; echo "❌ APK memuat alamat jaringan lokal."; exit 1; fi
  rm -f "$LIBAPP"

  mkdir -p build/release
  local FINAL="build/release/catu-v$VERSION_NAME-$VERSION_CODE.apk"
  cp "$APK" "$FINAL"
  ( cd build/release && shasum -a 256 "$(basename "$FINAL")" | tee "$(basename "$FINAL").sha256" )
  echo "✅ Android APK siap dikirim: $MOBILE_DIR/$FINAL ($(ls -lh "$FINAL" | awk '{print $5}'))"
  echo "ℹ️  Simpan juga $SYMBOLS (membaca crash log) dan cadangkan android/catu-release.jks + android/key.properties."
}

# ── Function: Build iOS App ──
build_ios() {
  echo ""
  echo "🍎 [2/2] Building iOS Release App..."
  flutter build ios --release --dart-define="CATU_API_URL=$TARGET_API_URL"

  local APP_PATH="$MOBILE_DIR/build/ios/iphoneos/Runner.app"
  if [ -d "$APP_PATH" ]; then
    echo "✅ iOS Release App Build Success!"
    echo "   Path: $APP_PATH"
  else
    echo "❌ Runner.app not found at $APP_PATH"
    exit 1
  fi
}

case "$BUILD_TARGET" in
  apk)
    build_apk
    ;;
  ios|ipa)
    build_ios
    ;;
  all)
    build_apk
    build_ios
    ;;
  *)
    echo "❌ Unknown target '$BUILD_TARGET'. Valid options: apk, ios, all."
    exit 1
    ;;
esac

echo ""
echo "🎉 Build process completed successfully!"
