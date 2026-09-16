#!/bin/bash
# ================================================
# run_ios.sh — CATU iOS Simulator Launch Script
# Xcode 26 workaround: build via xcodebuild,
# install & launch via simctl (bypass Flutter CLI bug)
# ================================================

BOOTED_SIM=$(xcrun simctl list devices | grep -i "Booted" | head -1 | grep -oE "[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}")
SIMULATOR_ID="${BOOTED_SIM:-AD34C126-B786-46F3-BBCE-06A06AD21752}"
BUNDLE_ID="com.example.catuMobile"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_ENV_FILE="$PROJECT_DIR/../.env"
IOS_DIR="$PROJECT_DIR/ios"


echo "🏷️ Step 0.5: Auto-updating app version & build timestamp..."
BUILD_TS=$(date +"%Y%m%d.%H%M%S")
VERSION_STRING="v2.5.0-build.$BUILD_TS"
API_BASE_URL="${CATU_API_URL:-${PUBLIC_API_URL:-}}"
if [ -z "$API_BASE_URL" ] && [ -f "$ROOT_ENV_FILE" ]; then
  API_BASE_URL=$(sed -n 's/^PUBLIC_API_URL=//p' "$ROOT_ENV_FILE" | head -1)
fi
if [ -z "$API_BASE_URL" ]; then
  echo "❌ Set CATU_API_URL or PUBLIC_API_URL before running this script."
  exit 1
fi
echo "   Build Version: $VERSION_STRING"
echo "   API URL      : $API_BASE_URL"

cat <<EOF > "$PROJECT_DIR/lib/core/constants/app_constants.dart"
import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'CATU Pelayanan';
  static const String appVersion = '$VERSION_STRING';
  static const String apiBaseUrl = String.fromEnvironment('CATU_API_URL');
  
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
xcrun simctl terminate "$SIMULATOR_ID" "$BUNDLE_ID" 2>/dev/null || true

echo ""
echo "📦 Step 2: Building with Xcode..."
cd "$IOS_DIR" && xcodebuild \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Debug \
  -destination "id=$SIMULATOR_ID" \
  DART_DEFINES="$(printf 'CATU_API_URL=%s' "$API_BASE_URL" | base64 | tr -d '\n')" \
  CODE_SIGNING_ALLOWED=NO \
  build 2>&1 | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:)" | tail -5

# Cek build sukses
if [ $? -ne 0 ]; then
  echo "❌ Build gagal!"
  exit 1
fi

echo ""
echo "📱 Step 3: Boot simulator..."
xcrun simctl boot "$SIMULATOR_ID" 2>/dev/null || echo "   (already booted)"
open -a Simulator
sleep 2

echo ""
echo "🚀 Step 4: Install & Launch fresh app..."
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Runner-*/Build/Products/Debug-iphonesimulator -name "Runner.app" 2>/dev/null | xargs ls -td 2>/dev/null | head -1)

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
  echo "❌ Runner.app tidak ditemukan!"
  exit 1
fi

echo "   Installing binary from: $APP_PATH"
xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"
xcrun simctl launch "$SIMULATOR_ID" "$BUNDLE_ID"

echo ""
echo "✅ CATU berhasil berjalan di iPhone 17 Pro Simulator!"
echo "   Bundle ID: $BUNDLE_ID"
