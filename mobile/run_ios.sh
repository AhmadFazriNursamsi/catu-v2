#!/bin/bash
# ================================================
# run_ios.sh — CATU iOS Simulator Launch Script
# Xcode 26 workaround: build via xcodebuild,
# install & launch via simctl (bypass Flutter CLI bug)
# ================================================

SIMULATOR_ID="AD34C126-B786-46F3-BBCE-06A06AD21752"
BUNDLE_ID="com.example.catuMobile"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
IOS_DIR="$PROJECT_DIR/ios"

echo "🔨 Step 1: flutter pub get..."
cd "$PROJECT_DIR" && flutter pub get

echo ""
echo "📦 Step 2: Building with Xcode..."
cd "$IOS_DIR" && xcodebuild \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Debug \
  -destination "id=$SIMULATOR_ID" \
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
echo "🚀 Step 4: Install & Launch app..."
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Runner-*/Build/Products/Debug-iphonesimulator -name "Runner.app" 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
  echo "❌ Runner.app tidak ditemukan!"
  exit 1
fi

xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"
xcrun simctl launch "$SIMULATOR_ID" "$BUNDLE_ID"

echo ""
echo "✅ CATU berhasil berjalan di iPhone 17 Pro Simulator!"
echo "   Bundle ID: $BUNDLE_ID"
