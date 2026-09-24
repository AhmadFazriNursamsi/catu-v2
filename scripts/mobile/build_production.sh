#!/bin/bash
# ==============================================================================
# build_production.sh — CATU Production Release Builder (Plug-and-Play)
# Usage:
#   ./build_production.sh apk    # Build Android Release APK
#   ./build_production.sh ipa    # Build iOS Release App
#   ./build_production.sh all    # Build both Android & iOS
#
# Configuration is loaded automatically from root .env.
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
MOBILE_DIR="$ROOT_DIR/mobile"
ROOT_ENV_FILE="$ROOT_DIR/.env"

# 1. Load configuration from root .env
if [ -f "$ROOT_ENV_FILE" ]; then
  [ -z "$CATU_API_URL" ] && CATU_API_URL=$(sed -n 's/^CATU_API_URL=//p' "$ROOT_ENV_FILE" | head -1)
  [ -z "$PUBLIC_API_URL" ] && PUBLIC_API_URL=$(sed -n 's/^PUBLIC_API_URL=//p' "$ROOT_ENV_FILE" | head -1)
  [ -z "$IOS_BUNDLE_ID" ] && IOS_BUNDLE_ID=$(sed -n 's/^IOS_BUNDLE_ID=//p' "$ROOT_ENV_FILE" | head -1)
  [ -z "$IOS_DEVELOPMENT_TEAM" ] && IOS_DEVELOPMENT_TEAM=$(sed -n 's/^IOS_DEVELOPMENT_TEAM=//p' "$ROOT_ENV_FILE" | head -1)
fi

TARGET_API_URL="${CATU_API_URL:-${PUBLIC_API_URL:-https://catu.devoutsys.com/api}}"
BUILD_TARGET="${1:-apk}"

echo "=========================================================="
echo "🚀 CATU Mobile Production Builder"
echo "=========================================================="
echo "   Target Mode : $BUILD_TARGET"
echo "   API Endpoint: $TARGET_API_URL"
echo "=========================================================="

cd "$MOBILE_DIR"
echo "📦 Resolving Flutter dependencies..."
flutter pub get

# ── Function: Build Android APK ──
build_apk() {
  echo ""
  echo "🤖 [1/2] Building Android Release APK..."
  flutter build apk --release --dart-define="CATU_API_URL=$TARGET_API_URL"
  
  APK_PATH="$MOBILE_DIR/build/app/outputs/flutter-apk/app-release.apk"
  if [ -f "$APK_PATH" ]; then
    APK_SIZE=$(ls -lh "$APK_PATH" | awk '{print $5}')
    echo "✅ Android APK Build Success!"
    echo "   Path: $APK_PATH ($APK_SIZE)"
  else
    echo "❌ APK binary not found at $APK_PATH"
    exit 1
  fi
}

# ── Function: Build iOS App ──
build_ios() {
  echo ""
  echo "🍎 [2/2] Building iOS Release App..."
  flutter build ios --release --dart-define="CATU_API_URL=$TARGET_API_URL"
  
  APP_PATH="$MOBILE_DIR/build/ios/iphoneos/Runner.app"
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
