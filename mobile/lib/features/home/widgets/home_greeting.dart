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

String _titleCase(String s) => s.trim().split(RegExp(r'\s+')).map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}').join(' ');

/// Jabatan pada beranda: Romo -> Romo Paroki / Kepala Romo Paroki / Romo Ordo / Ketua Romo Ordo;
/// pengurus -> jabatannya (mis. "Ketua Lingkungan", "Sekretaris Lingkungan"); Koordinator -> "Koordinator Keuskupan";
/// umat biasa -> "Umat" / "Umat Pendatang".
String homeRoleTitle(Map<String, dynamic> user) {
  final role = (user['roleCode'] ?? user['role_code'] ?? user['role'] ?? '').toString().toUpperCase();
  final romoPos = (user['romoPosition'] ?? user['romo_position'] ?? '').toString().toUpperCase();
  final pengurusPos = (user['pengurusPosition'] ?? user['pengurus_position'] ?? '').toString().trim();
  final leader = RegExp(r'KETUA|KEPALA|SUPERIOR').hasMatch(romoPos);

  if (role == 'ROMO_PAROKI') return leader ? 'Kepala Romo Paroki' : 'Romo Paroki';
  if (role == 'ROMO_ORDO') return leader ? 'Ketua Romo Ordo' : 'Romo Ordo';
  if (role.contains('KOORDINATOR') || pengurusPos.toLowerCase().contains('koordinator')) return 'Koordinator Keuskupan';
  if (pengurusPos.isNotEmpty) {
    final pos = pengurusPos.toUpperCase();
    final name = pos == 'KETUA' ? 'Ketua' : (pos == 'WAKIL' ? 'Wakil Ketua' : _titleCase(pengurusPos));
    return name.toLowerCase().contains('lingkungan') ? name : '$name Lingkungan';
  }
  if (role == 'PENGURUS_LINGKUNGAN') return 'Pengurus Lingkungan';
  return role == 'UMAT_PENDATANG' || user['kunjungan'] != null ? 'Umat Pendatang' : 'Umat';
}
