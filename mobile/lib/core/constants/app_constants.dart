import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'CATU Pelayanan';
  static const String appVersion = 'v2.5.0-build.20260814.181239';
  static const String apiBaseUrl = 'http://10.0.10.130:3005'; // NestJS Local Server (Docker Port 3005)
  
  // Custom HSL Colors
  static const Color primaryBlue = Color(0xFF1E3A8A); // Deep Catholic Church Blue
  static const Color accentGold = Color(0xFFD97706);  // Sacred Gold Accent
  static const Color bgCanvas = Color(0xFFF8FAFC);   // Off-white Clean Canvas
  static const Color cardSurface = Colors.white;
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
}
