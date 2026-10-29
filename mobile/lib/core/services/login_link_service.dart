import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../../features/home/home_screen.dart';
import 'api_service.dart';
import 'auth_http.dart' as http;
import 'auth_service.dart';
import 'notification_service.dart';

/// Tautan masuk sekali pakai dari WhatsApp untuk Romo yang didaftarkan Koordinator: https://<host>/api/public/m/login?t=...
/// (atau catu://m/login?t=... dari halaman cadangan). Token ditukar dengan sesi, lalu HomeScreen mewajibkan kata sandi baru.
class LoginLinkService {
  static StreamSubscription<Uri>? _sub;
  static bool _busy = false;
  static final Set<String> _handled = {};
  static final RegExp _tokenPattern = RegExp(r'^[A-Za-z0-9_-]{20,128}$');

  static void init() {
    _sub ??= AppLinks().uriLinkStream.listen((uri) => _onUri(uri), onError: (_) {});
  }

  /// Token dari tautan masuk, atau null bila bukan tautan masuk / formatnya salah.
  static String? tokenFrom(Uri uri) {
    final isApp = uri.scheme == 'catu' && uri.host == 'm' && uri.path == '/login';
    final isWeb = uri.scheme == 'https' && uri.path.endsWith('/m/login');
    final token = uri.queryParameters['t'];
    if (!(isApp || isWeb) || token == null || !_tokenPattern.hasMatch(token)) return null;
    return token;
  }

  static Future<void> _onUri(Uri uri) async {
    final token = tokenFrom(uri);
    if (token == null || _busy || !_handled.add(token)) return;
    _busy = true;
    try {
      final nav = await _navigator();
      if (nav == null || !nav.mounted) return;
      if (AuthService.isLoggedIn && !await _confirmSwitch(nav.context)) {
        _handled.remove(token);
        return;
      }
      await _signIn(nav, token);
    } finally {
      _busy = false;
    }
  }

  /// Saat aplikasi dibuka dari tautan (kondisi mati), navigator baru siap setelah frame pertama.
  static Future<NavigatorState?> _navigator() async {
    for (var i = 0; i < 25; i++) {
      final nav = NotificationService.navigatorKey.currentState;
      if (nav != null && nav.mounted) return nav;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return null;
  }

  static Future<bool> _confirmSwitch(BuildContext context) async {
    final name = AuthService.currentUser?['fullName'] ?? 'akun saat ini';
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Masuk dengan tautan?'),
        content: Text('Anda sedang masuk sebagai $name. Melanjutkan akan keluar dari akun ini dan masuk memakai tautan dari WhatsApp.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lanjutkan')),
        ],
      ),
    );
    return ok == true;
  }

  static Future<void> _signIn(NavigatorState nav, String token) async {
    final context = nav.context;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(canPop: false, child: Center(child: CircularProgressIndicator())),
    );
    String? error;
    Map<String, dynamic>? user;
    try {
      if (AuthService.isLoggedIn) await AuthService.logout();
      final res = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/auth/login-link'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'token': token}),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (res.statusCode < 300 && data is Map && data['user'] is Map) {
        user = Map<String, dynamic>.from(data['user'] as Map);
      } else {
        error = data is Map ? data['message']?.toString() : null;
      }
    } catch (_) {
      error = 'Tidak dapat terhubung ke server. Periksa koneksi internet, lalu ketuk tautan lagi.';
    }
    if (nav.mounted) nav.pop();
    if (user != null) {
      await AuthService.saveSession(user);
      nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => HomeScreen(user: user!)), (_) => false);
    } else if (nav.mounted) {
      await showDialog<void>(
        context: nav.context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tautan tidak dapat dipakai'),
          content: Text(error ?? 'Tautan sudah dipakai atau kedaluwarsa. Masuk dengan nomor HP dan kata sandi sementara dari WhatsApp.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup'))],
        ),
      );
    }
  }
}
