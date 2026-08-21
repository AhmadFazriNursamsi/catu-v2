import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  // Override this manually if needed, or leave null for auto-detection
  static String? _customBaseUrl;

  static void setBaseUrl(String url) {
    _customBaseUrl = url;
  }

  static String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }

    if (kIsWeb) {
      return 'http://localhost:3005';
    }

    if (Platform.isAndroid) {
      // 10.0.2.2 is the Android Emulator alias to the host machine
      return 'http://10.0.2.2:3005';
    }

    // iOS Simulator, macOS, Linux, Windows
    return 'http://localhost:3005';
  }

  // Network IP fallback for physical devices on same Wi-Fi
  static const String lanBaseUrl = 'http://10.0.10.93:3005';
}
