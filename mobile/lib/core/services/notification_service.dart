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

  // ─── Get For Role ─────────────────────────────────────────────────────────

  static Future<List<NotificationItem>> getForRole(String role) async {
    final all = await getAll();
    return all.where((n) => n.role == role).toList();
  }

  // ─── Unread Count ─────────────────────────────────────────────────────────

  static Future<int> unreadCount(String role) async {
    final items = await getForRole(role);
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

  static Future<void> markAllRead(String role) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final updated = raw.map((s) {
      try {
        final map = jsonDecode(s) as Map<String, dynamic>;
        if (map['role'] == role) map['isRead'] = true;
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

  static Future<void> deleteAll(String role) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final updated = raw.where((s) {
      try {
        final map = jsonDecode(s) as Map<String, dynamic>;
        return map['role'] != role;
      } catch (_) {
        return true;
      }
    }).toList();
    await prefs.setStringList(_key, updated);
  }

  // ─── Factory Helpers ──────────────────────────────────────────────────────

  /// Called when Umat creates a new service order
  static Future<void> notifyNewRequest({
    required String orderId,
    required String umatName,
    required String categoryName,
    required String targetRole, // 'ROMO_ORDO' or 'ROMO_PAROKI'
  }) async {
    final isKedukaan = categoryName.toLowerCase().contains('kedukaan');
    final serviceLabel = isKedukaan ? 'Misa Kedukaan' : 'Perminyakan';
    await add(NotificationItem(
      id: 'new_${orderId}_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Permintaan Pelayanan Baru',
      body: 'Umat yang berada di kota anda telah membuat sebuah permintaan pelayanan Sakramen $serviceLabel dengan nama umat $umatName',
      type: 'NEW_REQUEST',
      role: targetRole,
      createdAt: DateTime.now(),
      orderId: orderId,
      categoryName: categoryName,
    ));
  }

  /// Called when Romo accepts/declines a service request (notifies Umat)
  static Future<void> notifyRomoResponse({
    required String orderId,
    required String romoName,
    required String categoryName,
    required bool accepted,
  }) async {
    final isKedukaan = categoryName.toLowerCase().contains('kedukaan');
    final serviceLabel = isKedukaan ? 'Misa Kedukaan' : 'Perminyakan';
    final action = accepted ? 'mengkonfirmasi' : 'menolak';
    await add(NotificationItem(
      id: 'romo_${orderId}_${DateTime.now().millisecondsSinceEpoch}',
      title: accepted ? 'Pelayanan Dikonfirmasi ✓' : 'Pelayanan Ditolak',
      body: 'Romo $romoName telah $action permintaan pelayanan $serviceLabel Anda.',
      type: accepted ? 'ROMO_ACCEPTED' : 'ROMO_DECLINED',
      role: 'UMAT',
      createdAt: DateTime.now(),
      orderId: orderId,
      categoryName: categoryName,
    ));
  }

  /// Called when a service is completed (notifies Umat and Romo Paroki)
  static Future<void> notifyServiceCompleted({
    required String orderId,
    required String categoryName,
    required String penerimaName,
    required String targetRole,
  }) async {
    final isKedukaan = categoryName.toLowerCase().contains('kedukaan');
    final serviceLabel = isKedukaan ? 'Misa Kedukaan' : 'Perminyakan';
    await add(NotificationItem(
      id: 'done_${orderId}_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Pelayanan Selesai ✓',
      body: 'Pelayanan $serviceLabel untuk $penerimaName telah selesai dilaksanakan.',
      type: 'STATUS_UPDATE',
      role: targetRole,
      createdAt: DateTime.now(),
      orderId: orderId,
      categoryName: categoryName,
    ));
  }
}
