class ServiceCategory {
  final int id;
  final String name;
  final String description;
  final bool isUrgentByDefault;

  ServiceCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.isUrgentByDefault,
  });

  factory ServiceCategory.fromJson(Map<String, dynamic> json) {
    return ServiceCategory(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      isUrgentByDefault: json['isUrgentByDefault'] ?? false,
    );
  }
}

class OrderItem {
  final String itemName;
  final String scheduledDate;
  final String scheduledTimeStart;
  final String scheduledTimeEnd;
  final String locationName;

  OrderItem({
    required this.itemName,
    required this.scheduledDate,
    required this.scheduledTimeStart,
    required this.scheduledTimeEnd,
    required this.locationName,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    String rawDate = json['scheduledDate'] ?? json['scheduled_date'] ?? '';
    if (rawDate.contains('T')) rawDate = rawDate.split('T').first;

    String start = json['scheduledTimeStart'] ?? json['scheduled_time_start'] ?? '';
    if (start.length >= 5) start = start.substring(0, 5);

    String end = json['scheduledTimeEnd'] ?? json['scheduled_time_end'] ?? '';
    if (end.length >= 5) end = end.substring(0, 5);

    return OrderItem(
      itemName: json['itemName'] ?? json['item_name'] ?? 'Misa Kedukaan',
      scheduledDate: rawDate,
      scheduledTimeStart: start,
      scheduledTimeEnd: end,
      locationName: json['locationName'] ?? json['location_name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemName': itemName,
      'scheduledDate': scheduledDate,
      'scheduledTimeStart': scheduledTimeStart,
      'scheduledTimeEnd': scheduledTimeEnd,
      'locationName': locationName,
    };
  }
}

class Order {
  final int id;
  final String orderNumber;
  final String categoryName;
  final String urgencyName;
  final String status;
  final String scheduledDate;
  final String scheduledTime;
  final String locationName;
  final String addressDetail;
  final String pemohonName;
  final String notes;
  final String keuskupanName;
  final String parokiName;
  final String lingkunganName;
  final List<OrderItem> items;
  final String? attachmentUrl;

  Order({
    required this.id,
    required this.orderNumber,
    required this.categoryName,
    required this.urgencyName,
    required this.status,
    required this.scheduledDate,
    this.scheduledTime = '',
    required this.locationName,
    this.addressDetail = '',
    required this.pemohonName,
    this.notes = '',
    this.keuskupanName = '',
    this.parokiName = '',
    this.lingkunganName = '',
    this.items = const [],
    this.attachmentUrl,
  });

  /// Parse "Jam Mulai" from notes
  String get jamMulaiLabel {
    if (notes.isNotEmpty) {
      final parts = notes.split('|');
      for (final part in parts) {
        final trimmed = part.trim();
        if (trimmed.toLowerCase().startsWith('jam mulai')) {
          final split = trimmed.split(':');
          if (split.length > 1) return split.sublist(1).join(':').trim();
        }
      }
    }
    return scheduledTime;
  }

  /// Parse "Jam Selesai" from notes
  String get jamSelesaiLabel {
    if (notes.isNotEmpty) {
      final parts = notes.split('|');
      for (final part in parts) {
        final trimmed = part.trim();
        if (trimmed.toLowerCase().startsWith('jam selesai')) {
          final split = trimmed.split(':');
          if (split.length > 1) return split.sublist(1).join(':').trim();
        }
      }
    }
    return '';
  }

  /// Parse "Catatan" from notes
  String get catatanLabel {
    if (notes.isNotEmpty) {
      final parts = notes.split('|');
      for (final part in parts) {
        final trimmed = part.trim();
        if (trimmed.toLowerCase().startsWith('catatan')) {
          final split = trimmed.split(':');
          if (split.length > 1) return split.sublist(1).join(':').trim();
        }
      }
    }
    return '';
  }

  /// Parse "Nama Penerima" from notes string.
  /// Notes format: "Nama Penerima: Bapak Antonius | Gender: Laki-laki | Usia: 72 tahun"
  String get penerimaName {
    if (notes.isNotEmpty) {
      final parts = notes.split('|');
      for (final part in parts) {
        final trimmed = part.trim();
        final lower = trimmed.toLowerCase();
        if (lower.startsWith('nama penerima') || lower.startsWith('nama almarhum') || lower.startsWith('nama:')) {
          final split = trimmed.split(':');
          if (split.length > 1) {
            final name = split.sublist(1).join(':').trim();
            if (name.isNotEmpty) return name;
          }
        }
      }
    }
    return pemohonName;
  }

  /// Parse gender from notes
  String get genderLabel {
    if (notes.isNotEmpty) {
      final parts = notes.split('|');
      for (final part in parts) {
        final trimmed = part.trim();
        if (trimmed.toLowerCase().startsWith('gender')) {
          final split = trimmed.split(':');
          if (split.length > 1) return split.sublist(1).join(':').trim();
        }
      }
    }
    return '';
  }

  /// Parse usia from notes
  String get usiaLabel {
    if (notes.isNotEmpty) {
      final parts = notes.split('|');
      for (final part in parts) {
        final trimmed = part.trim();
        if (trimmed.toLowerCase().startsWith('usia')) {
          final split = trimmed.split(':');
          if (split.length > 1) return split.sublist(1).join(':').trim();
        }
      }
    }
    return '';
  }

  /// Parse "Hubungan" from notes
  String get hubunganLabel {
    if (notes.isNotEmpty) {
      final parts = notes.split('|');
      for (final part in parts) {
        final trimmed = part.trim();
        if (trimmed.toLowerCase().startsWith('hubungan')) {
          final split = trimmed.split(':');
          if (split.length > 1) return split.sublist(1).join(':').trim();
        }
      }
    }
    return 'Kerabat';
  }

  /// Parse "Tgl Meninggal" from notes
  String get tanggalMeninggalLabel {
    if (notes.isNotEmpty) {
      final parts = notes.split('|');
      for (final part in parts) {
        final trimmed = part.trim();
        final lower = trimmed.toLowerCase();
        if (lower.startsWith('tgl meninggal') || lower.startsWith('tanggal meninggal')) {
          final split = trimmed.split(':');
          if (split.length > 1) return split.sublist(1).join(':').trim();
        }
      }
    }
    return scheduledDate;
  }

  /// Parse "Waktu Meninggal" from notes
  String get waktuMeninggalLabel {
    if (notes.isNotEmpty) {
      final parts = notes.split('|');
      for (final part in parts) {
        final trimmed = part.trim();
        if (trimmed.toLowerCase().startsWith('waktu meninggal')) {
          final split = trimmed.split(':');
          if (split.length > 1) return split.sublist(1).join(':').trim();
        }
      }
    }
    return jamMulaiLabel.isNotEmpty ? jamMulaiLabel : '06:26';
  }

  /// Format address for display
  String get displayAddress {
    if (addressDetail.isNotEmpty) return addressDetail;
    if (locationName.isNotEmpty) return locationName;
    return '-';
  }

  /// Format date + start time for display (e.g. "2026-08-20 • 14:00")
  String get fullScheduleLabel {
    String timeStr = scheduledTime;
    if (timeStr.length >= 5) {
      timeStr = timeStr.substring(0, 5);
    }
    if (timeStr.isNotEmpty) {
      return '$scheduledDate • $timeStr WIB';
    }
    return scheduledDate;
  }

  DateTime? get parsedDate {
    if (scheduledDate.isEmpty) return null;
    try {
      return DateTime.parse(scheduledDate);
    } catch (_) {
      return null;
    }
  }

  bool get isPastDate {
    final d = parsedDate;
    if (d == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final orderDay = DateTime(d.year, d.month, d.day);
    return orderDay.isBefore(today);
  }

  /// Belongs to Dashboard (Active Schedule):
  /// Date is today or future AND status is active (PENDING, CONFIRMED, IN_PROGRESS)
  bool get isActiveDashboardOrder {
    final st = status.toUpperCase();
    if (st == 'DONE' || st == 'CLOSE' || st == 'FAIL') return false;
    if (isPastDate) return false;
    return true;
  }

  /// Belongs to History (strictly mutually exclusive with Dashboard):
  bool get isHistoryOrder => !isActiveDashboardOrder;

  factory Order.fromJson(Map<String, dynamic> json) {
    // Backend returns id as String ("2"), parse safely to int
    final rawId = json['id'];
    final parsedId = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;

    // Backend returns scheduled_date as ISO datetime "2026-08-20T00:00:00.000Z"
    String rawDate = json['scheduled_date'] ?? json['scheduledDate'] ?? '';
    if (rawDate.contains('T')) rawDate = rawDate.split('T').first;

    String rawTime = json['scheduled_time'] ?? json['scheduledTime'] ?? '';
    if (rawTime.length >= 5) rawTime = rawTime.substring(0, 5);

    List<OrderItem> parsedItems = [];
    if (json['items'] is List) {
      parsedItems = (json['items'] as List)
          .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
          .toList();
    }

    String parsedStatus = json['status'] ?? 'PENDING';
    if (parsedStatus.toUpperCase() == 'PENDING' && rawDate.isNotEmpty) {
      try {
        final date = DateTime.parse(rawDate);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        if (DateTime(date.year, date.month, date.day).isBefore(today)) {
          parsedStatus = 'FAIL';
        }
      } catch (_) {}
    }

    return Order(
      id: parsedId,
      orderNumber: json['order_number'] ?? json['orderNumber'] ?? '',
      categoryName: json['category_name'] ?? json['categoryName'] ?? 'Pelayanan',
      urgencyName: json['urgency_name'] ?? json['urgencyName'] ?? 'Biasa',
      status: parsedStatus,
      scheduledDate: rawDate,
      scheduledTime: rawTime,
      locationName: json['location_name'] ?? json['locationName'] ?? '',
      addressDetail: json['address_detail'] ?? json['addressDetail'] ?? '',
      pemohonName: json['pemohon_name'] ?? json['pemohonName'] ?? 'Umat',
      notes: json['notes'] ?? '',
      keuskupanName: json['keuskupan_name'] ?? json['keuskupanName'] ?? 'Keuskupan Agung Jakarta',
      parokiName: json['paroki_name'] ?? json['parokiName'] ?? 'Paroki Alam Sutera - St. Laurensius',
      lingkunganName: json['lingkungan_name'] ?? json['lingkunganName'] ?? 'St. Angela Merici',
      items: parsedItems,
      attachmentUrl: json['attachment_url'] ?? json['attachmentUrl'],
    );
  }
}

class ChatMessage {
  final int id;
  final int chatGroupId;
  final int? senderId;
  final String? senderName;
  final String messageType;
  final String message;
  final String? attachmentUrl;
  final String createdAt;

  ChatMessage({
    required this.id,
    required this.chatGroupId,
    this.senderId,
    this.senderName,
    required this.messageType,
    required this.message,
    this.attachmentUrl,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? 0,
      chatGroupId: json['chat_group_id'] ?? json['chatGroupId'] ?? 0,
      senderId: json['sender_id'] ?? json['senderId'],
      senderName: json['sender_name'] ?? json['senderName'],
      messageType: json['message_type'] ?? json['messageType'] ?? 'TEXT',
      message: json['message'] ?? '',
      attachmentUrl: json['attachment_url'] ?? json['attachmentUrl'],
      createdAt: json['created_at'] ?? json['createdAt'] ?? '',
    );
  }
}

class ChatGroupItem {
  final int groupId;
  final int orderId;
  final String groupTitle;
  final String? lastMessageText;
  final String? lastMessageAt;
  final String orderTitle;
  final String orderCategory;
  final String orderStatus;
  final String scheduledDate;
  final String scheduledTimeStart;
  final String scheduledTimeEnd;
  final String penerimaName;
  final String requesterName;
  final String? requesterAvatar;
  final int unreadCount;

  ChatGroupItem({
    required this.groupId,
    required this.orderId,
    required this.groupTitle,
    this.lastMessageText,
    this.lastMessageAt,
    required this.orderTitle,
    required this.orderCategory,
    required this.orderStatus,
    required this.scheduledDate,
    required this.scheduledTimeStart,
    required this.scheduledTimeEnd,
    required this.penerimaName,
    required this.requesterName,
    this.requesterAvatar,
    this.unreadCount = 0,
  });

  factory ChatGroupItem.fromJson(Map<String, dynamic> json) {
    return ChatGroupItem(
      groupId: json['group_id'] ?? json['groupId'] ?? json['id'] ?? 0,
      orderId: json['order_id'] ?? json['orderId'] ?? 0,
      groupTitle: json['group_title'] ?? json['groupTitle'] ?? json['title'] ?? 'Group Pelayanan',
      lastMessageText: json['last_message_text'] ?? json['lastMessageText'],
      lastMessageAt: json['last_message_at'] ?? json['lastMessageAt'],
      orderTitle: json['order_title'] ?? json['orderTitle'] ?? json['title'] ?? 'Pelayanan',
      orderCategory: json['order_category'] ?? json['orderCategory'] ?? json['category'] ?? 'Permintaan Pelayanan',
      orderStatus: json['order_status'] ?? json['orderStatus'] ?? json['status'] ?? 'CONFIRMED',
      scheduledDate: json['scheduled_date'] ?? json['scheduledDate'] ?? '',
      scheduledTimeStart: json['scheduled_time_start'] ?? json['scheduledTimeStart'] ?? '08:00',
      scheduledTimeEnd: json['scheduled_time_end'] ?? json['scheduledTimeEnd'] ?? '09:00',
      penerimaName: json['penerima_name'] ?? json['penerimaName'] ?? 'Umat',
      requesterName: json['requester_name'] ?? json['requesterName'] ?? 'Nama Umat',
      requesterAvatar: json['requester_avatar'] ?? json['requesterAvatar'],
      unreadCount: json['unread_count'] ?? json['unreadCount'] ?? 0,
    );
  }
}
