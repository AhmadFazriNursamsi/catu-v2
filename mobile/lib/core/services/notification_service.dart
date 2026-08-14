import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String type; // 'NEW_REQUEST', 'ROMO_ACCEPTED', 'ROMO_DECLINED', 'STATUS_UPDATE'
  final String role; // 'UMAT', 'ROMO_ORDO', 'ROMO_PAROKI', 'PENGURUS'
  final DateTime createdAt;
  bool isRead;
  final String? orderId;
  final String? categoryName; // 'Misa Kedukaan' or 'Perminyakan'
  final String? itemTitle; // Specific misa name e.g. 'Misa Tutup Peti'
  final int? parokiId;
  final int? kabupatenKotaId;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.role,
    required this.createdAt,
    this.isRead = false,
    this.orderId,
    this.categoryName,
    this.itemTitle,
    this.parokiId,
    this.kabupatenKotaId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type,
        'role': role,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
        'orderId': orderId,
        'categoryName': categoryName,
        'itemTitle': itemTitle,
        'parokiId': parokiId,
        'kabupatenKotaId': kabupatenKotaId,
      };

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      type: json['type'] ?? 'STATUS_UPDATE',
      role: json['role'] ?? 'UMAT',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      isRead: json['isRead'] ?? false,
      orderId: json['orderId'],
      categoryName: json['categoryName'],
      itemTitle: json['itemTitle'],
      parokiId: json['parokiId'] != null ? int.tryParse(json['parokiId'].toString()) : null,
      kabupatenKotaId: json['kabupatenKotaId'] != null ? int.tryParse(json['kabupatenKotaId'].toString()) : null,
    );
  }

  /// Human-readable relative time label (e.g. "3 jam lalu", "1 hari lalu")
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays == 1) return '1 hari lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} minggu lalu';
    return '${(diff.inDays / 30).floor()} bulan lalu';
  }
}

class NotificationService {
  static const String _key = 'catu_notifications_v1';

  // ─── Read All ────────────────────────────────────────────────────────────────

  static Future<List<NotificationItem>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final items = raw
        .map((s) {
          try {
            return NotificationItem.fromJson(jsonDecode(s));
          } catch (_) {
            return null;
          }
        })
        .whereType<NotificationItem>()
        .toList();
    // Sort newest first
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  // ─── Get For Role (with location filtering) ────────────────────────────────

  static Future<List<NotificationItem>> getForRole(
    String role, {
    int? parokiId,
    int? kabupatenKotaId,
  }) async {
    final all = await getAll();
    return all.where((n) {
      if (n.role != role) return false;
      if (role == 'ROMO_PAROKI' && parokiId != null && n.parokiId != null) {
        return n.parokiId == parokiId;
      }
      if (role == 'ROMO_ORDO' && kabupatenKotaId != null && n.kabupatenKotaId != null) {
        return n.kabupatenKotaId == kabupatenKotaId;
      }
      return true;
    }).toList();
  }

  // ─── Unread Count ─────────────────────────────────────────────────────────

  static Future<int> unreadCount(
    String role, {
    int? parokiId,
    int? kabupatenKotaId,
  }) async {
    final items = await getForRole(
      role,
      parokiId: parokiId,
      kabupatenKotaId: kabupatenKotaId,
    );
    return items.where((n) => !n.isRead).length;
  }

  // ─── Add ─────────────────────────────────────────────────────────────────

  static Future<void> add(NotificationItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.insert(0, jsonEncode(item.toJson()));
    // Keep max 200 notifications
    final trimmed = raw.take(200).toList();
    await prefs.setStringList(_key, trimmed);
  }

  // ─── Mark As Read ─────────────────────────────────────────────────────────

  static Future<void> markRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final updated = raw.map((s) {
      try {
        final map = jsonDecode(s) as Map<String, dynamic>;
        if (map['id'] == id) map['isRead'] = true;
        return jsonEncode(map);
      } catch (_) {
        return s;
      }
    }).toList();
    await prefs.setStringList(_key, updated);
  }

  // ─── Mark All Read For Role ───────────────────────────────────────────────

  static Future<void> markAllRead(
    String role, {
    int? parokiId,
    int? kabupatenKotaId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final updated = raw.map((s) {
      try {
        final map = jsonDecode(s) as Map<String, dynamic>;
        if (map['role'] == role) {
          if (role == 'ROMO_PAROKI' && parokiId != null && map['parokiId'] != null) {
            if (map['parokiId'] == parokiId) map['isRead'] = true;
          } else if (role == 'ROMO_ORDO' && kabupatenKotaId != null && map['kabupatenKotaId'] != null) {
            if (map['kabupatenKotaId'] == kabupatenKotaId) map['isRead'] = true;
          } else {
            map['isRead'] = true;
          }
        }
        return jsonEncode(map);
      } catch (_) {
        return s;
      }
    }).toList();
    await prefs.setStringList(_key, updated);
  }

  // ─── Delete One ───────────────────────────────────────────────────────────

  static Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final updated = raw.where((s) {
      try {
        final map = jsonDecode(s) as Map<String, dynamic>;
        return map['id'] != id;
      } catch (_) {
        return true;
      }
    }).toList();
    await prefs.setStringList(_key, updated);
  }

  // ─── Delete All For Role ──────────────────────────────────────────────────

  static Future<void> deleteAll(
    String role, {
    int? parokiId,
    int? kabupatenKotaId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final updated = raw.where((s) {
      try {
        final map = jsonDecode(s) as Map<String, dynamic>;
        if (map['role'] == role) {
          if (role == 'ROMO_PAROKI' && parokiId != null && map['parokiId'] != null) {
            return map['parokiId'] != parokiId;
          } else if (role == 'ROMO_ORDO' && kabupatenKotaId != null && map['kabupatenKotaId'] != null) {
            return map['kabupatenKotaId'] != kabupatenKotaId;
          }
          return false;
        }
        return true;
      } catch (_) {
        return true;
      }
    }).toList();
    await prefs.setStringList(_key, updated);
  }

  // ─── Factory Helpers ──────────────────────────────────────────────────────

  /// Generate a unique notification ID using an atomic counter
  static Future<String> _uniqueId(String prefix) async {
    final prefs = await SharedPreferences.getInstance();
    final counter = (prefs.getInt('notif_counter_v1') ?? 0) + 1;
    await prefs.setInt('notif_counter_v1', counter);
    return '${prefix}_${counter}_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Called when Umat creates a new service order — generates 1 notif per misa item
  static Future<void> notifyNewRequest({
    required String orderId,
    required String umatName,
    required String categoryName,
    required String targetRole, // 'ROMO_ORDO' or 'ROMO_PAROKI'
    String? misaItemName, // optional: per-item misa name
    int? itemIndex,        // optional: index for uniqueness
    int? parokiId,
    int? kabupatenKotaId,
  }) async {
    final isKedukaan = categoryName.toLowerCase().contains('kedukaan');
    final serviceLabel = isKedukaan ? 'Misa Kedukaan' : 'Perminyakan';
    final suffix = misaItemName != null ? ' ($misaItemName)' : '';
    final locationPhrase = targetRole == 'ROMO_PAROKI'
        ? 'paroki anda'
        : 'kota anda';
    final uniqueId = await _uniqueId('new_${targetRole.toLowerCase()}_${orderId}_${itemIndex ?? 0}');
    await add(NotificationItem(
      id: uniqueId,
      title: 'Permintaan Pelayanan Baru',
      body: 'Umat yang berada di $locationPhrase telah membuat sebuah permintaan pelayanan Sakramen $serviceLabel dengan nama umat $umatName$suffix',
      type: 'NEW_REQUEST',
      role: targetRole,
      createdAt: DateTime.now(),
      orderId: orderId,
      categoryName: categoryName,
      itemTitle: misaItemName,
      parokiId: parokiId,
      kabupatenKotaId: kabupatenKotaId,
    ));
  }

  /// Called when Romo accepts/declines a service request (notifies Umat)
  static Future<void> notifyRomoResponse({
    required String orderId,
    required String romoName,
    required String categoryName,
    required bool accepted,
    String? misaItemName,
  }) async {
    final isKedukaan = categoryName.toLowerCase().contains('kedukaan');
    final serviceLabel = isKedukaan ? 'Misa Kedukaan' : 'Perminyakan';
    final action = accepted ? 'mengkonfirmasi' : 'menolak';
    final suffix = misaItemName != null ? ' ($misaItemName)' : '';
    final uniqueId = await _uniqueId('romo_${orderId}');
    await add(NotificationItem(
      id: uniqueId,
      title: accepted ? 'Pelayanan Dikonfirmasi ✓' : 'Pelayanan Ditolak',
      body: 'Romo $romoName telah $action permintaan pelayanan $serviceLabel$suffix Anda.',
      type: accepted ? 'ROMO_ACCEPTED' : 'ROMO_DECLINED',
      role: 'UMAT',
      createdAt: DateTime.now(),
      orderId: orderId,
      categoryName: categoryName,
      itemTitle: misaItemName,
    ));
  }

  /// Called when a service is completed (notifies Umat and Romo Paroki)
  static Future<void> notifyServiceCompleted({
    required String orderId,
    required String categoryName,
    required String penerimaName,
    required String targetRole,
    String? misaItemName,
  }) async {
    final isKedukaan = categoryName.toLowerCase().contains('kedukaan');
    final serviceLabel = isKedukaan ? 'Misa Kedukaan' : 'Perminyakan';
    final suffix = misaItemName != null ? ' ($misaItemName)' : '';
    final uniqueId = await _uniqueId('done_${orderId}');
    await add(NotificationItem(
      id: uniqueId,
      title: 'Pelayanan Selesai ✓',
      body: 'Pelayanan $serviceLabel$suffix untuk $penerimaName telah selesai dilaksanakan.',
      type: 'STATUS_UPDATE',
      role: targetRole,
      createdAt: DateTime.now(),
      orderId: orderId,
      categoryName: categoryName,
      itemTitle: misaItemName,
    ));
  }
}
