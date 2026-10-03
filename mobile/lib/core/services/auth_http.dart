import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

export 'package:http/http.dart' show Response;

/// Penyimpanan access token JWT (di-cache di memori, dipersist di SharedPreferences).
class AuthTokenStore {
  static const String _key = 'catu_access_token';
  static String? _token;
  static bool _loaded = false;

  /// Dipanggil saat server menjawab 401 untuk request terautentikasi (sesi berakhir / token tidak valid).
  static Future<void> Function()? onUnauthorized;

  static Future<String?> read() async {
    if (!_loaded) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_key);
      _loaded = true;
    }
    return _token;
  }

  static Future<void> save(String? token) async {
    _token = (token == null || token.isEmpty) ? null : token;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    if (_token == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, _token!);
    }
  }

  static Future<void> clear() => save(null);

  /// Endpoint publik: token tidak dilampirkan dan 401 tidak berarti sesi berakhir.
  static bool _isPublic(Uri url) {
    final path = url.path;
    return path.endsWith('/auth/login') ||
        path.endsWith('/auth/admin/login') ||
        path.endsWith('/auth/register') ||
        path.contains('/auth/forgot-password/') ||
        path.endsWith('/health');
  }
}

/// Login berhasil mengembalikan accessToken; simpan agar request berikutnya terautentikasi.
Future<void> _storeLoginToken(String body) async {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['accessToken'] is String) {
      await AuthTokenStore.save(decoded['accessToken'] as String);
    }
  } catch (_) {
    // Body bukan JSON: abaikan, tidak ada token untuk disimpan.
  }
}

Future<http.Response> _send(
  Uri url,
  Map<String, String>? headers,
  Future<http.Response> Function(Map<String, String>? headers) call,
) async {
  if (AuthTokenStore._isPublic(url)) {
    final publicResponse = await call(headers);
    final issuesToken = url.path.endsWith('/auth/login') || url.path.endsWith('/auth/register');
    if (issuesToken && publicResponse.statusCode < 300) {
      await _storeLoginToken(publicResponse.body);
    }
    return publicResponse;
  }

  final token = await AuthTokenStore.read();
  final merged = token == null ? headers : <String, String>{...?headers, 'Authorization': 'Bearer $token'};
  final response = await call(merged);
  if (response.statusCode == 401) {
    final handler = AuthTokenStore.onUnauthorized;
    if (handler != null) unawaited(handler());
  }
  return response;
}

Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
    _send(url, headers, (h) => http.get(url, headers: h));

Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    _send(url, headers, (h) => http.post(url, headers: h, body: body, encoding: encoding));

Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    _send(url, headers, (h) => http.put(url, headers: h, body: body, encoding: encoding));

Future<http.Response> delete(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    _send(url, headers, (h) => http.delete(url, headers: h, body: body, encoding: encoding));
