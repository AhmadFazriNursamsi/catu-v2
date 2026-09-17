#!/bin/bash
# ================================================
# run_ios.sh — CATU iOS Auto-Launch Script
# Auto-detects physical iPhone (release) or Simulator (debug)
# Plug-and-Play: reads configuration directly from .env
# ================================================

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_ENV_FILE="$PROJECT_DIR/../.env"
IOS_DIR="$PROJECT_DIR/ios"

# Load variables from root .env if present
if [ -f "$ROOT_ENV_FILE" ]; then
  [ -z "$CATU_API_URL" ] && CATU_API_URL=$(sed -n 's/^CATU_API_URL=//p' "$ROOT_ENV_FILE" | head -1)
  [ -z "$PUBLIC_API_URL" ] && PUBLIC_API_URL=$(sed -n 's/^PUBLIC_API_URL=//p' "$ROOT_ENV_FILE" | head -1)
  [ -z "$IOS_BUNDLE_ID" ] && IOS_BUNDLE_ID=$(sed -n 's/^IOS_BUNDLE_ID=//p' "$ROOT_ENV_FILE" | head -1)
  [ -z "$IOS_DEVELOPMENT_TEAM" ] && IOS_DEVELOPMENT_TEAM=$(sed -n 's/^IOS_DEVELOPMENT_TEAM=//p' "$ROOT_ENV_FILE" | head -1)
  [ -z "$IOS_DEVICE_ID" ] && IOS_DEVICE_ID=$(sed -n 's/^IOS_DEVICE_ID=//p' "$ROOT_ENV_FILE" | head -1)
fi

BUNDLE_ID="${IOS_BUNDLE_ID:-com.example.catuMobile}"
API_BASE_URL="${CATU_API_URL:-${PUBLIC_API_URL:-https://api-catu.farismunir.my.id}}"

echo "🏷️ Step 0.5: Auto-updating app version & build timestamp..."
BUILD_TS=$(date +"%Y%m%d.%H%M%S")
VERSION_STRING="v2.5.0-build.$BUILD_TS"
echo "   Build Version: $VERSION_STRING"
echo "   API Base URL : $API_BASE_URL"
echo "   Bundle ID    : $BUNDLE_ID"

cat <<EOF > "$PROJECT_DIR/lib/core/constants/app_constants.dart"
import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'CATU Pelayanan';
  static const String appVersion = '$VERSION_STRING';
  static const String apiBaseUrl = String.fromEnvironment(
    'CATU_API_URL',
    defaultValue: String.fromEnvironment('API_BASE_URL', defaultValue: '$API_BASE_URL'),
  );
  
  // Custom HSL Colors
  static const Color primaryBlue = Color(0xFF1E3A8A); // Deep Catholic Church Blue
  static const Color accentGold = Color(0xFFD97706);  // Sacred Gold Accent
  static const Color bgCanvas = Color(0xFFF8FAFC);   // Off-white Clean Canvas
  static const Color cardSurface = Colors.white;
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
}
EOF

echo "🔨 Step 1: flutter pub get..."
cd "$PROJECT_DIR" && flutter pub get

# Check for physically connected/paired iOS device
TARGET_DEVICE="${IOS_DEVICE_ID:-}"
if [ -z "$TARGET_DEVICE" ]; then
  TARGET_DEVICE=$(xcrun devicectl list devices 2>/dev/null | grep "available" | grep -oE "[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}" | head -1)
fi

if [ -n "$TARGET_DEVICE" ]; then
  echo ""
  echo "📱 Step 2: Physical iPhone detected ($TARGET_DEVICE)!"
  echo "📦 Step 3: Building Release iOS app with code signing..."
  flutter build ios --release "--dart-define=CATU_API_URL=$API_BASE_URL"

  if [ $? -ne 0 ]; then
    echo "❌ Build iOS release gagal!"
    exit 1
  fi

  echo ""
  echo "🚀 Step 4: Installing and launching on physical iPhone..."
  xcrun devicectl device install app --device "$TARGET_DEVICE" "$PROJECT_DIR/build/ios/iphoneos/Runner.app"
  xcrun devicectl device process launch --device "$TARGET_DEVICE" "$BUNDLE_ID"

  echo ""
  echo "✅ CATU berhasil berjalan di iPhone fisik ($TARGET_DEVICE)!"
  echo "   Target Server: $API_BASE_URL"
  exit 0
fi

# Fallback: iOS Simulator
echo ""
echo "📱 Step 2: Physical device not detected. Falling back to iOS Simulator..."
BOOTED_SIM=$(xcrun simctl list devices | grep -i "Booted" | head -1 | grep -oE "[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}")
SIMULATOR_ID="${BOOTED_SIM:-AD34C126-B786-46F3-BBCE-06A06AD21752}"

xcrun simctl terminate "$SIMULATOR_ID" "$BUNDLE_ID" 2>/dev/null || true

echo "📦 Step 3: Building with Xcode for Simulator..."
cd "$IOS_DIR" && xcodebuild \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Debug \
  -destination "id=$SIMULATOR_ID" \
  DART_DEFINES="$(printf 'CATU_API_URL=%s' "$API_BASE_URL" | base64 | tr -d '\n')" \
  CODE_SIGNING_ALLOWED=NO \
  build 2>&1 | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:)" | tail -5

if [ $? -ne 0 ]; then
  echo "❌ Build simulator gagal!"
  exit 1
fi

echo "📱 Step 4: Booting simulator..."
xcrun simctl boot "$SIMULATOR_ID" 2>/dev/null || echo "   (already booted)"
open -a Simulator
sleep 2

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Runner-*/Build/Products/Debug-iphonesimulator -name "Runner.app" 2>/dev/null | xargs ls -td 2>/dev/null | head -1)
if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
  echo "❌ Runner.app simulator tidak ditemukan!"
  exit 1
fi

echo "🚀 Step 5: Installing and launching on Simulator..."
xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"
xcrun simctl launch "$SIMULATOR_ID" "$BUNDLE_ID"

echo ""
echo "✅ CATU berhasil berjalan di iPhone Simulator ($SIMULATOR_ID)!"
