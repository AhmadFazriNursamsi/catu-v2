class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String type; // 'NEW_REQUEST', 'ROMO_ACCEPTED', 'ROMO_DECLINED', 'STATUS_UPDATE', 'ROMO_HANDOVER', etc.
  final String role; // 'UMAT', 'ROMO_ORDO', 'ROMO_PAROKI', 'PENGURUS'
  final DateTime createdAt;
  bool isRead;
  final String? orderId;
  final String? categoryName; // 'Misa Kedukaan' or 'Perminyakan'
  final String? itemTitle; // Specific misa name e.g. 'Misa Tutup Peti'
  final int? parokiId;
  final int? kabupatenKotaId;
  final int? groupId;
  final int? itemId; // ID misa (order_items) tujuan notifikasi, bila ada
  final String? orderNumber;

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
    this.groupId,
    this.itemId,
    this.orderNumber,
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
        'groupId': groupId,
        'itemId': itemId,
        'orderNumber': orderNumber,
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
      groupId: json['groupId'] != null ? int.tryParse(json['groupId'].toString()) : null,
      itemId: json['itemId'] != null ? int.tryParse(json['itemId'].toString()) : null,
      orderNumber: json['orderNumber'],
    );
  }

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
