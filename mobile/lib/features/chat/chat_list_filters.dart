import '../../core/models/models.dart';

enum ChatTimeFilter { threeDays, sevenDays, thirtyDays, all }

enum ChatCategoryFilter { all, kedukaan, perminyakan }

enum ChatReadFilter { all, unread, read }

extension ChatTimeFilterX on ChatTimeFilter {
  /// Batas umur pesan terakhir (hari); null = semua waktu.
  int? get maxDays => const {ChatTimeFilter.threeDays: 3, ChatTimeFilter.sevenDays: 7, ChatTimeFilter.thirtyDays: 30}[this];

  String get chipLabel => maxDays == null ? 'Semua' : '$maxDays Hari';

  String get modalLabel {
    if (maxDays == null) return 'Semua Waktu';
    return this == ChatTimeFilter.sevenDays ? '7 Hari Terakhir (Default)' : '$maxDays Hari Terakhir';
  }
}

extension ChatReadFilterX on ChatReadFilter {
  String get label => const {ChatReadFilter.all: 'Semua Status', ChatReadFilter.unread: 'Belum Dibaca', ChatReadFilter.read: 'Sudah Dibaca'}[this]!;
}

/// Saring berdasarkan waktu dan status baca.
/// Chat yang masih punya pesan belum dibaca selalu lolos saringan waktu agar tidak terlewat.
bool chatPassesTimeAndRead(ChatGroupItem g, DateTime now, ChatTimeFilter time, ChatReadFilter read) {
  final unread = g.unreadCount > 0;
  if (read == ChatReadFilter.unread && !unread) return false;
  if (read == ChatReadFilter.read && unread) return false;
  final maxDays = time.maxDays;
  final dt = g.lastMessageDateTime;
  if (maxDays == null || unread || dt == null) return true;
  return now.difference(dt).inDays <= maxDays;
}
