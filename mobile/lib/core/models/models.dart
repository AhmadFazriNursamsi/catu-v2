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
  });

  /// Parse "Nama Penerima" from notes string.
  /// Notes format: "Nama Penerima: Bapak Antonius | Gender: Laki-laki | Usia: 72 tahun"
  String get penerimaName {
    if (notes.isNotEmpty) {
      final parts = notes.split('|');
      for (final part in parts) {
        final trimmed = part.trim();
        final lower = trimmed.toLowerCase();
        if (lower.startsWith('nama penerima') || lower.startsWith('nama:')) {
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
    if (notes.isEmpty) return '';
    final parts = notes.split('|');
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.toLowerCase().startsWith('gender')) {
        final split = trimmed.split(':');
        if (split.length > 1) return split.sublist(1).join(':').trim();
      }
    }
    return '';
  }

  /// Parse usia from notes
  String get usiaLabel {
    if (notes.isEmpty) return '';
    final parts = notes.split('|');
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.toLowerCase().startsWith('usia')) {
        final split = trimmed.split(':');
        if (split.length > 1) return split.sublist(1).join(':').trim();
      }
    }
    return '';
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

  factory Order.fromJson(Map<String, dynamic> json) {
    // Backend returns id as String ("2"), parse safely to int
    final rawId = json['id'];
    final parsedId = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;

    // Backend returns scheduled_date as ISO datetime "2026-08-20T00:00:00.000Z"
    String rawDate = json['scheduled_date'] ?? json['scheduledDate'] ?? '';
    if (rawDate.contains('T')) rawDate = rawDate.split('T').first;

    String rawTime = json['scheduled_time'] ?? json['scheduledTime'] ?? '';
    if (rawTime.length >= 5) rawTime = rawTime.substring(0, 5);

    return Order(
      id: parsedId,
      orderNumber: json['order_number'] ?? json['orderNumber'] ?? '',
      categoryName: json['category_name'] ?? json['categoryName'] ?? 'Pelayanan',
      urgencyName: json['urgency_name'] ?? json['urgencyName'] ?? 'Biasa',
      status: json['status'] ?? 'PENDING',
      scheduledDate: rawDate,
      scheduledTime: rawTime,
      locationName: json['location_name'] ?? json['locationName'] ?? '',
      addressDetail: json['address_detail'] ?? json['addressDetail'] ?? '',
      pemohonName: json['pemohon_name'] ?? json['pemohonName'] ?? 'Umat',
      notes: json['notes'] ?? '',
    );
  }
}

class ChatMessage {
  final int id;
  final int chatGroupId;
  final String? senderName;
  final String messageType;
  final String message;
  final String? attachmentUrl;
  final String createdAt;

  ChatMessage({
    required this.id,
    required this.chatGroupId,
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
      senderName: json['sender_name'] ?? json['senderName'],
      messageType: json['message_type'] ?? json['messageType'] ?? 'TEXT',
      message: json['message'] ?? '',
      attachmentUrl: json['attachment_url'] ?? json['attachmentUrl'],
      createdAt: json['created_at'] ?? json['createdAt'] ?? '',
    );
  }
}
