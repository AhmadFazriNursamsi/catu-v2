/// Galat dari server berbentuk `{statusCode: 4xx/5xx, message}` (message dapat berupa teks atau daftar teks).
bool apiFailed(Map<String, dynamic> res) {
  final code = res['statusCode'];
  return code is num && code >= 400;
}

String apiMessage(Map<String, dynamic> res, String fallback) {
  final m = res['message'];
  if (m is List) return m.join('\n');
  final text = m?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
