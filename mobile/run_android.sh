#!/bin/bash
# ================================================
# run_android.sh — CATU Android Device Launch Script
# ================================================

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
export ANDROID_NDK_HOME="/opt/homebrew/share/android-commandlinetools/ndk/28.2.13676358"
export ANDROID_NDK_ROOT="/opt/homebrew/share/android-commandlinetools/ndk/28.2.13676358"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"

echo "🏷️ Step 0.5: Auto-updating app version & build timestamp..."
BUILD_TS=$(date +"%Y%m%d.%H%M%S")
VERSION_STRING="v2.5.0-build.$BUILD_TS"
LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "10.0.10.48")
echo "   Build Version: $VERSION_STRING"
echo "   Local API IP : $LOCAL_IP (Port 3005)"

cat <<CONST_EOF > "$PROJECT_DIR/lib/core/constants/app_constants.dart"
import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'CATU Pelayanan';
  static const String appVersion = '$VERSION_STRING';
  static const String apiBaseUrl = 'http://$LOCAL_IP:3005'; // NestJS Local Server (Docker Port 3005)
  
  // Custom HSL Colors
  static const Color primaryBlue = Color(0xFF1E3A8A); // Deep Catholic Church Blue
  static const Color accentGold = Color(0xFFD97706);  // Sacred Gold Accent
  static const Color bgCanvas = Color(0xFFF8FAFC);   // Off-white Clean Canvas
  static const Color cardSurface = Colors.white;
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
}
CONST_EOF

echo "🔨 Step 1: flutter pub get..."
cd "$PROJECT_DIR" && flutter pub get

echo ""
echo "📱 Step 2: Checking Android Device..."
ANDROID_DEVICE=$(adb devices | grep -w "device" | grep -v "List" | awk '{print $1}' | head -1)

if [ -z "$ANDROID_DEVICE" ]; then
  echo "❌ Tidak ada perangkat Android yang terhubung via ADB."
  echo "   Pastikan HP Android terhubung via USB dan USB Debugging telah aktif."
  exit 1
fi

echo "   Connected Device ID: $ANDROID_DEVICE"
echo "   Bridging backend port 3005 via USB ADB reverse..."
adb -s "$ANDROID_DEVICE" reverse tcp:3005 tcp:3005 2>/dev/null || true

echo ""
echo "🚀 Step 3: Running Flutter on Android device ($ANDROID_DEVICE)..."
flutter run -d "$ANDROID_DEVICE"
