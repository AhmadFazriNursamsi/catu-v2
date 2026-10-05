/// Sapaan beranda: Romo -> "Hi, Romo Nama"; umat sesuai gender (L: Bapak, P: Ibu); tanpa gender -> "Hi, Nama".
String homeGreeting(Map<String, dynamic> user, String name) {
  final role = (user['roleCode'] ?? user['role_code'] ?? '').toString().toUpperCase();
  final clean = name.trim();
  if (role.startsWith('ROMO')) {
    final hasTitle = RegExp(r'^(romo|rm\.?|pastor)\b', caseSensitive: false).hasMatch(clean);
    return 'Hi, ${hasTitle ? clean : 'Romo $clean'}';
  }
  switch ((user['gender'] ?? '').toString().toUpperCase()) {
    case 'L':
      return 'Hi, Bapak $clean';
    case 'P':
      return 'Hi, Ibu $clean';
    default:
      return 'Hi, $clean';
  }
}
