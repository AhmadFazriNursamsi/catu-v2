import 'package:flutter/material.dart';

/// Helper to format date string to "nama hari, dd/mm/yy" (e.g. "Senin, 01/09/26")
String formatServiceDate(String? rawDate) {
  if (rawDate == null || rawDate.isEmpty) return '-';
  try {
    String clean = rawDate.trim();
    if (clean.contains('T')) clean = clean.split('T').first;
    if (clean.contains(' ')) clean = clean.split(' ').first;
    final dt = DateTime.parse(clean);
    const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    final dayName = days[dt.weekday - 1];
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yy = (dt.year % 100).toString().padLeft(2, '0');
    return '$dayName, $dd/$mm/$yy';
  } catch (_) {
    return rawDate;
  }
}

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
  final int? id;
  final String itemName;
  final String scheduledDate;
  final String scheduledTimeStart;
  final String scheduledTimeEnd;
  final String locationName;
  String status;
  int? acceptedRomoId;
  String? acceptedRomoName;
  String rescheduleStatus;
  int? rescheduleProposedBy;
  String? rescheduleNewDate;
  String? rescheduleNewTimeStart;
  String? rescheduleNewTimeEnd;
  String rescheduleReason;
  String handoverStatus;
  int? handoverProposedBy;
  String? handoverProposerName;
  int? handoverTargetRomoId;
  String? handoverTargetRomoName;
  String handoverReason;

  OrderItem({
    this.id,
    required this.itemName,
    required this.scheduledDate,
    required this.scheduledTimeStart,
    required this.scheduledTimeEnd,
    required this.locationName,
    this.status = 'PENDING',
    this.acceptedRomoId,
    this.acceptedRomoName,
    this.rescheduleStatus = 'NONE',
    this.rescheduleProposedBy,
    this.rescheduleNewDate,
    this.rescheduleNewTimeStart,
    this.rescheduleNewTimeEnd,
    this.rescheduleReason = '',
    this.handoverStatus = 'NONE',
    this.handoverProposedBy,
    this.handoverProposerName,
    this.handoverTargetRomoId,
    this.handoverTargetRomoName,
    this.handoverReason = '',
  });

  bool get hasPendingReschedule => rescheduleStatus.toUpperCase() == 'PENDING_UMAT';
  bool get hasPendingHandover => handoverStatus.toUpperCase() == 'PENDING';
  bool get isHandoverCompleted => handoverStatus.toUpperCase() == 'ACCEPTED';

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final parsedId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');

    final rawAcceptedRomo = json['acceptedRomoId'] ?? json['accepted_romo_id'];
    final int? parsedAcceptedRomoId = rawAcceptedRomo != null ? int.tryParse(rawAcceptedRomo.toString()) : null;

    final rawProposedBy = json['rescheduleProposedBy'] ?? json['reschedule_proposed_by'];
    final int? parsedProposedBy = rawProposedBy != null ? int.tryParse(rawProposedBy.toString()) : null;

    final rawHandoverProposedBy = json['handoverProposedBy'] ?? json['handover_proposed_by'];
    final int? parsedHandoverProposedBy = rawHandoverProposedBy != null ? int.tryParse(rawHandoverProposedBy.toString()) : null;

    final rawHandoverTargetRomoId = json['handoverTargetRomoId'] ?? json['handover_target_romo_id'];
    final int? parsedHandoverTargetRomoId = rawHandoverTargetRomoId != null ? int.tryParse(rawHandoverTargetRomoId.toString()) : null;

    return OrderItem(
      id: parsedId,
      itemName: json['itemName'] ?? json['item_name'] ?? 'Misa',
      scheduledDate: json['scheduledDate'] ?? json['scheduled_date'] ?? '',
      scheduledTimeStart: json['scheduledTimeStart'] ?? json['scheduled_time_start'] ?? '',
      scheduledTimeEnd: json['scheduledTimeEnd'] ?? json['scheduled_time_end'] ?? '',
      locationName: json['locationName'] ?? json['location_name'] ?? '',
      status: json['status'] ?? 'PENDING',
      acceptedRomoId: parsedAcceptedRomoId,
      acceptedRomoName: json['acceptedRomoName'] ?? json['accepted_romo_name'],
      rescheduleStatus: (json['rescheduleStatus'] ?? json['reschedule_status'] ?? 'NONE').toString().toUpperCase(),
      rescheduleProposedBy: parsedProposedBy,
      rescheduleNewDate: json['rescheduleNewDate'] ?? json['reschedule_new_date'],
      rescheduleNewTimeStart: json['rescheduleNewTimeStart'] ?? json['reschedule_new_time_start'],
      rescheduleNewTimeEnd: json['rescheduleNewTimeEnd'] ?? json['reschedule_new_time_end'],
      rescheduleReason: json['rescheduleReason'] ?? json['reschedule_reason'] ?? '',
      handoverStatus: (json['handoverStatus'] ?? json['handover_status'] ?? 'NONE').toString().toUpperCase(),
      handoverProposedBy: parsedHandoverProposedBy,
      handoverProposerName: json['handoverProposerName'] ?? json['handover_proposer_name'],
      handoverTargetRomoId: parsedHandoverTargetRomoId,
      handoverTargetRomoName: json['handoverTargetRomoName'] ?? json['handover_target_romo_name'],
      handoverReason: json['handoverReason'] ?? json['handover_reason'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'itemName': itemName,
      'scheduledDate': scheduledDate,
      'scheduledTimeStart': scheduledTimeStart,
      'scheduledTimeEnd': scheduledTimeEnd,
      'locationName': locationName,
      if (acceptedRomoId != null) 'acceptedRomoId': acceptedRomoId,
      if (acceptedRomoName != null) 'acceptedRomoName': acceptedRomoName,
    };
  }

  /// Formatted date in "nama hari, dd/mm/yy" (e.g. "Sabtu, 15/08/26")
  String get formattedDateIndo => formatServiceDate(scheduledDate);

  /// Format date + start time for display (e.g. "Sabtu, 15/08/26 • 18:00 – 19:30 WIB")
  String get fullScheduleLabel {
    final dateStr = formatServiceDate(scheduledDate);
    if (scheduledTimeStart.isNotEmpty) {
      final timeEndStr = scheduledTimeEnd.isNotEmpty ? ' – $scheduledTimeEnd' : '';
      return '$dateStr • $scheduledTimeStart$timeEndStr WIB';
    }
    return dateStr;
  }
}

class OrderRescheduleLog {
  final int id;
  final int orderId;
  final int? itemId;
  final int proposedBy;
  final String proposerName;
  final String? previousDate;
  final String? previousTimeStart;
  final String? previousTimeEnd;
  final String proposedDate;
  final String proposedTimeStart;
  final String? proposedTimeEnd;
  final String reason;
  final String status; // PENDING_UMAT, ACCEPTED, REJECTED
  final int? respondedBy;
  final String? responderName;
  final String? respondedAt;
  final String? createdAt;

  OrderRescheduleLog({
    required this.id,
    required this.orderId,
    this.itemId,
    required this.proposedBy,
    required this.proposerName,
    this.previousDate,
    this.previousTimeStart,
    this.previousTimeEnd,
    required this.proposedDate,
    required this.proposedTimeStart,
    this.proposedTimeEnd,
    required this.reason,
    required this.status,
    this.respondedBy,
    this.responderName,
    this.respondedAt,
    this.createdAt,
  });

  factory OrderRescheduleLog.fromJson(Map<String, dynamic> json) {
    String prevDate = json['previousDate'] ?? json['previous_date'] ?? '';
    if (prevDate.contains('T')) prevDate = prevDate.split('T').first;

    String propDate = json['proposedDate'] ?? json['proposed_date'] ?? '';
    if (propDate.contains('T')) propDate = propDate.split('T').first;

    String prevStart = json['previousTimeStart'] ?? json['previous_time_start'] ?? '';
    if (prevStart.length >= 5) prevStart = prevStart.substring(0, 5);

    String prevEnd = json['previousTimeEnd'] ?? json['previous_time_end'] ?? '';
    if (prevEnd.length >= 5) prevEnd = prevEnd.substring(0, 5);

    String propStart = json['proposedTimeStart'] ?? json['proposed_time_start'] ?? '';
    if (propStart.length >= 5) propStart = propStart.substring(0, 5);

    String propEnd = json['proposedTimeEnd'] ?? json['proposed_time_end'] ?? '';
    if (propEnd.length >= 5) propEnd = propEnd.substring(0, 5);

    return OrderRescheduleLog(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      orderId: json['orderId'] is int ? json['orderId'] : int.tryParse(json['orderId'].toString()) ?? 0,
      itemId: json['itemId'] != null ? int.tryParse(json['itemId'].toString()) : null,
      proposedBy: json['proposedBy'] is int ? json['proposedBy'] : int.tryParse(json['proposedBy'].toString()) ?? 0,
      proposerName: json['proposerName'] ?? json['proposer_name'] ?? 'Romo',
      previousDate: prevDate,
      previousTimeStart: prevStart,
      previousTimeEnd: prevEnd,
      proposedDate: propDate,
      proposedTimeStart: propStart,
      proposedTimeEnd: propEnd,
      reason: json['reason'] ?? '',
      status: (json['status'] ?? 'PENDING_UMAT').toString().toUpperCase(),
      respondedBy: json['respondedBy'] != null ? int.tryParse(json['respondedBy'].toString()) : null,
      responderName: json['responderName'] ?? json['responder_name'],
      respondedAt: json['respondedAt'] ?? json['responded_at'],
      createdAt: json['createdAt'] ?? json['created_at'],
    );
  }
}

class OrderRomoHandover {
  final int id;
  final int orderId;
  final int? itemId;
  final int previousRomoId;
  final String previousRomoName;
  final int? newRomoId;
  final String? newRomoName;
  final String handoverType; // 'BROADCAST_POOL' or 'DIRECT_ASSIGN'
  final String reason;
  final String status;
  final String? createdAt;

  OrderRomoHandover({
    required this.id,
    required this.orderId,
    this.itemId,
    required this.previousRomoId,
    required this.previousRomoName,
    this.newRomoId,
    this.newRomoName,
    required this.handoverType,
    required this.reason,
    required this.status,
    this.createdAt,
  });

  factory OrderRomoHandover.fromJson(Map<String, dynamic> json) {
    return OrderRomoHandover(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      orderId: json['orderId'] is int ? json['orderId'] : int.tryParse(json['orderId'].toString()) ?? 0,
      itemId: json['itemId'] != null ? int.tryParse(json['itemId'].toString()) : null,
      previousRomoId: json['previousRomoId'] is int ? json['previousRomoId'] : int.tryParse(json['previousRomoId'].toString()) ?? 0,
      previousRomoName: json['previousRomoName'] ?? 'Romo',
      newRomoId: json['newRomoId'] != null ? int.tryParse(json['newRomoId'].toString()) : null,
      newRomoName: json['newRomoName'],
      handoverType: json['handoverType'] ?? 'BROADCAST_POOL',
      reason: json['reason'] ?? '',
      status: json['status'] ?? 'COMPLETED',
      createdAt: json['createdAt'] ?? json['created_at'],
    );
  }
}

class Order {
  final int id;
  final int? userId;
  int? acceptedRomoId;
  String? acceptedRomoName;
  final String orderNumber;
  final String categoryName;
  final String urgencyName;
  String status;
  String scheduledDate;
  String scheduledTime;
  final String locationName;
  final String addressDetail;
  final String pemohonName;
  final String notes;
  final String keuskupanName;
  final String parokiName;
  final String lingkunganName;
  final List<OrderItem> items;
  final String? attachmentUrl;
  String rescheduleStatus;
  int? rescheduleProposedBy;
  String? rescheduleNewDate;
  String? rescheduleNewTime;
  String? rescheduleNewTimeEnd;
  String? rescheduleReason;
  List<OrderRescheduleLog> rescheduleHistory;
  List<OrderRomoHandover> handoverHistory;
  String handoverStatus;
  int? handoverProposedBy;
  String? handoverProposerName;
  int? handoverTargetRomoId;
  String? handoverTargetRomoName;
  String handoverReason;

  Order({
    required this.id,
    this.userId,
    this.acceptedRomoId,
    this.acceptedRomoName,
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
    this.rescheduleStatus = 'NONE',
    this.rescheduleProposedBy,
    this.rescheduleNewDate,
    this.rescheduleNewTime,
    this.rescheduleNewTimeEnd,
    this.rescheduleReason,
    this.rescheduleHistory = const [],
    this.handoverHistory = const [],
    this.handoverStatus = 'NONE',
    this.handoverProposedBy,
    this.handoverProposerName,
    this.handoverTargetRomoId,
    this.handoverTargetRomoName,
    this.handoverReason = '',
  });

  bool get hasPendingReschedule => rescheduleStatus.toUpperCase() == 'PENDING_UMAT';
  bool get hasPendingHandover => handoverStatus.toUpperCase() == 'PENDING';
  bool get isHandoverCompleted => handoverStatus.toUpperCase() == 'ACCEPTED';

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

  /// Formatted date in "nama hari, dd/mm/yy" (e.g. "Sabtu, 15/08/26")
  String get formattedDateIndo => formatServiceDate(scheduledDate);

  /// Format date + start time for display (e.g. "Sabtu, 15/08/26 • 14:00 WIB")
  String get fullScheduleLabel {
    String timeStr = scheduledTime;
    if (timeStr.length >= 5) {
      timeStr = timeStr.substring(0, 5);
    }
    final dateStr = formatServiceDate(scheduledDate);
    if (timeStr.isNotEmpty) {
      return '$dateStr • $timeStr WIB';
    }
    return dateStr;
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
    if (items.isNotEmpty) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      for (final item in items) {
        if (item.scheduledDate.isNotEmpty) {
          try {
            String clean = item.scheduledDate;
            if (clean.contains('T')) clean = clean.split('T').first;
            final d = DateTime.parse(clean);
            final itemDay = DateTime(d.year, d.month, d.day);
            if (!itemDay.isBefore(today)) return false;
          } catch (_) {}
        }
      }
      return true;
    }
    final d = parsedDate;
    if (d == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final orderDay = DateTime(d.year, d.month, d.day);
    return orderDay.isBefore(today);
  }

  /// Belongs to Dashboard (Active Schedule):
  /// Scheduled date is today or future (>= today) AND status is active (PENDING, CONFIRMED, IN_PROGRESS)
  bool get isActiveDashboardOrder {
    final st = status.toUpperCase();
    if (st == 'DONE' || st == 'CLOSE' || st == 'FAIL') return false;
    if (isPastDate) return false;
    return true;
  }

  /// Belongs to History (strictly mutually exclusive with Dashboard):
  /// Scheduled date is smaller than today (< today) OR status is finished (DONE, CLOSE, FAIL)
  bool get isHistoryOrder => !isActiveDashboardOrder;

  factory Order.fromJson(Map<String, dynamic> json) {
    // Backend returns id as String ("2"), parse safely to int
    final rawId = json['id'];
    final parsedId = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;

    final rawUserId = json['user_id'] ?? json['userId'];
    final parsedUserId = rawUserId is int ? rawUserId : int.tryParse(rawUserId?.toString() ?? '');

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

    final rawAcceptedRomo = json['acceptedRomoId'] ?? json['accepted_romo_id'];
    final int? parsedAcceptedRomoId = rawAcceptedRomo != null ? int.tryParse(rawAcceptedRomo.toString()) : null;
    final String? parsedAcceptedRomoName = json['acceptedRomoName'] ?? json['accepted_romo_name'];
    final rawProposedBy = json['rescheduleProposedBy'] ?? json['reschedule_proposed_by'];

    List<OrderRescheduleLog> parsedReschedules = [];
    if (json['rescheduleHistory'] is List) {
      parsedReschedules = (json['rescheduleHistory'] as List)
          .map((r) => OrderRescheduleLog.fromJson(r as Map<String, dynamic>))
          .toList();
    }

    List<OrderRomoHandover> parsedHandovers = [];
    if (json['handoverHistory'] is List) {
      parsedHandovers = (json['handoverHistory'] as List)
          .map((h) => OrderRomoHandover.fromJson(h as Map<String, dynamic>))
          .toList();
    }

    final rawHandoverProposedBy = json['handoverProposedBy'] ?? json['handover_proposed_by'];
    final int? parsedHandoverProposedBy = rawHandoverProposedBy != null ? int.tryParse(rawHandoverProposedBy.toString()) : null;

    final rawHandoverTargetRomoId = json['handoverTargetRomoId'] ?? json['handover_target_romo_id'];
    final int? parsedHandoverTargetRomoId = rawHandoverTargetRomoId != null ? int.tryParse(rawHandoverTargetRomoId.toString()) : null;

    return Order(
      id: parsedId,
      userId: parsedUserId,
      acceptedRomoId: parsedAcceptedRomoId,
      acceptedRomoName: parsedAcceptedRomoName,
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
      rescheduleStatus: (json['rescheduleStatus'] ?? json['reschedule_status'] ?? 'NONE').toString().toUpperCase(),
      rescheduleProposedBy: rawProposedBy != null ? int.tryParse(rawProposedBy.toString()) : null,
      rescheduleNewDate: json['rescheduleNewDate'] ?? json['reschedule_new_date'],
      rescheduleNewTime: json['rescheduleNewTime'] ?? json['reschedule_new_time'],
      rescheduleNewTimeEnd: json['rescheduleNewTimeEnd'] ?? json['reschedule_new_time_end'],
      rescheduleReason: json['rescheduleReason'] ?? json['reschedule_reason'],
      rescheduleHistory: parsedReschedules,
      handoverHistory: parsedHandovers,
      handoverStatus: (json['handoverStatus'] ?? json['handover_status'] ?? 'NONE').toString().toUpperCase(),
      handoverProposedBy: parsedHandoverProposedBy,
      handoverProposerName: json['handoverProposerName'] ?? json['handover_proposer_name'],
      handoverTargetRomoId: parsedHandoverTargetRomoId,
      handoverTargetRomoName: json['handoverTargetRomoName'] ?? json['handover_target_romo_name'],
      handoverReason: json['handoverReason'] ?? json['handover_reason'] ?? '',
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
    final rawId = json['id'];
    final parsedId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0;

    final rawGId = json['chat_group_id'] ?? json['chatGroupId'];
    final parsedGId = rawGId is int ? rawGId : int.tryParse(rawGId?.toString() ?? '') ?? 0;

    final rawSId = json['sender_id'] ?? json['senderId'];
    final parsedSId = rawSId is int ? rawSId : int.tryParse(rawSId?.toString() ?? '');

    return ChatMessage(
      id: parsedId,
      chatGroupId: parsedGId,
      senderId: parsedSId,
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
  final int? orderItemId;
  final String groupTitle;
  final String? lastMessageText;
  final String? lastMessageAt;
  final int? lastSenderId;
  final String? lastSenderName;
  final String orderTitle;
  final String orderCategory;
  final String orderStatus;
  final String urgencyName;
  final String scheduledDate;
  final String scheduledTimeStart;
  final String scheduledTimeEnd;
  final String penerimaName;
  final String requesterName;
  final String? requesterAvatar;
  final String notes;
  final int unreadCount;

  ChatGroupItem({
    required this.groupId,
    required this.orderId,
    this.orderItemId,
    required this.groupTitle,
    this.lastMessageText,
    this.lastMessageAt,
    this.lastSenderId,
    this.lastSenderName,
    required this.orderTitle,
    required this.orderCategory,
    required this.orderStatus,
    this.urgencyName = 'Biasa',
    required this.scheduledDate,
    required this.scheduledTimeStart,
    required this.scheduledTimeEnd,
    required this.penerimaName,
    required this.requesterName,
    this.requesterAvatar,
    this.notes = '',
    this.unreadCount = 0,
  });

  /// Urgency Level Icon Data
  IconData get urgencyIcon {
    final lower = urgencyName.toLowerCase();
    if (lower.contains('darurat') || lower.contains('kritis') || lower.contains('sangat') || lower.contains('tinggi') || lower.contains('emergency')) {
      return Icons.error_outline_rounded;
    } else if (lower.contains('penting') || lower.contains('urgent') || lower.contains('sedang')) {
      return Icons.warning_amber_rounded;
    }
    return Icons.info_outline_rounded;
  }

  /// Urgency Level Color
  Color get urgencyColor {
    final lower = urgencyName.toLowerCase();
    if (lower.contains('darurat') || lower.contains('kritis') || lower.contains('sangat') || lower.contains('tinggi') || lower.contains('emergency')) {
      return const Color(0xFFEF4444); // Red
    } else if (lower.contains('penting') || lower.contains('urgent') || lower.contains('sedang')) {
      return const Color(0xFFF59E0B); // Amber / Orange
    }
    return const Color(0xFF3B82F6); // Blue / Normal
  }

  /// Parse "Nama Penerima" or "Nama Almarhum" from notes
  String get penerimaOrDeceasedName {
    if (penerimaName.isNotEmpty && penerimaName != 'Umat' && penerimaName != requesterName) {
      return penerimaName;
    }
    if (notes.isNotEmpty) {
      final parts = notes.split('|');
      for (final part in parts) {
        final trimmed = part.trim();
        final lower = trimmed.toLowerCase();
        if (lower.startsWith('nama penerima') ||
            lower.startsWith('nama almarhum') ||
            lower.startsWith('nama yang meninggal') ||
            lower.startsWith('nama:')) {
          final split = trimmed.split(':');
          if (split.length > 1) {
            final name = split.sublist(1).join(':').trim();
            if (name.isNotEmpty) return name;
          }
        }
      }
    }
    return requesterName.isNotEmpty ? requesterName : 'Umat';
  }

  /// Parse "Misa Detail" or "Jenis Misa" from notes or orderTitle (e.g. Misa Penutupan Peti, Misa Requiem, Misa 40 Hari)
  String get detailMisaLabel {
    if (orderTitle.isNotEmpty &&
        orderTitle != 'Pelayanan' &&
        orderTitle != 'Misa Kedukaan' &&
        orderTitle != 'Pelayanan Kedukaan' &&
        orderTitle.toLowerCase().contains('misa')) {
      return orderTitle;
    }
    if (notes.isNotEmpty) {
      final parts = notes.split('|');
      for (final part in parts) {
        final trimmed = part.trim();
        final lower = trimmed.toLowerCase();
        if (lower.startsWith('misa:') ||
            lower.startsWith('jenis misa') ||
            lower.startsWith('detail misa') ||
            lower.startsWith('tipe misa') ||
            lower.startsWith('judul misa')) {
          final split = trimmed.split(':');
          if (split.length > 1) {
            final val = split.sublist(1).join(':').trim();
            if (val.isNotEmpty) return val;
          }
        }
      }
    }
    return 'Misa Penutupan Peti';
  }

  /// Display Title for List Chat (Line 1)
  String get displayTitle {
    final catLower = orderCategory.toLowerCase();
    if (catLower.contains('perminyakan')) {
      return 'a/n $penerimaOrDeceasedName';
    } else if (catLower.contains('kedukaan')) {
      return '$detailMisaLabel - $penerimaOrDeceasedName';
    }
    return requesterName.isNotEmpty ? requesterName : groupTitle;
  }

  /// Formatted Day & Date (e.g. Kamis, 13/08/26) matching Detail Chat
  String get formattedScheduledDayAndDate {
    return formatServiceDate(scheduledDate);
  }

  /// Formatted Time HH:mm
  String get formattedScheduledTimeOnly {
    if (scheduledTimeStart.isEmpty) return '13:30';
    if (scheduledTimeStart.length >= 5 && scheduledTimeStart.contains(':')) {
      return scheduledTimeStart.substring(0, 5);
    }
    return scheduledTimeStart;
  }

  /// Display Subtitle / Service Category Detail for List Chat (Line 2)
  String get displayServiceDetail {
    final catLower = orderCategory.toLowerCase();
    final dateFormatted = formattedScheduledDayAndDate;
    final timeFormatted = formattedScheduledTimeOnly;

    if (catLower.contains('perminyakan')) {
      return 'Sakramen Perminyakan • $dateFormatted - $timeFormatted';
    } else if (catLower.contains('kedukaan')) {
      return '$detailMisaLabel • $dateFormatted - $timeFormatted';
    }
    return '$orderCategory • $dateFormatted - $timeFormatted';
  }

  /// Formatted Last Message Time (HH:mm format in local device time)
  String get formattedLastTime {
    if (lastMessageAt == null || lastMessageAt!.isEmpty) {
      return '15:30';
    }
    final raw = lastMessageAt!;
    try {
      final dt = DateTime.parse(raw).toLocal();
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    } catch (_) {
      if (raw.contains('T')) {
        final parts = raw.split('T');
        if (parts.length > 1 && parts[1].length >= 5) {
          return parts[1].substring(0, 5);
        }
      }
      return raw;
    }
  }

  /// Display text for last message preview with sender name
  String formatLastMessage({int? currentUserId}) {
    if (lastMessageText == null || lastMessageText!.isEmpty) {
      return 'Belum ada pesan chat.';
    }
    if (lastSenderName != null && lastSenderName!.trim().isNotEmpty) {
      final isSelf = (lastSenderId != null && currentUserId != null && lastSenderId == currentUserId);
      final sender = isSelf ? 'Anda' : lastSenderName!.trim();
      return '$sender: $lastMessageText';
    }
    return lastMessageText!;
  }

  /// Default display text for last message preview
  String get displayLastMessage {
    return formatLastMessage();
  }

  factory ChatGroupItem.fromJson(Map<String, dynamic> json) {
    final rawGId = json['group_id'] ?? json['groupId'] ?? json['id'];
    final parsedGId = rawGId is int ? rawGId : int.tryParse(rawGId?.toString() ?? '') ?? 0;

    final rawOId = json['order_id'] ?? json['orderId'];
    final parsedOId = rawOId is int ? rawOId : int.tryParse(rawOId?.toString() ?? '') ?? 0;

    final rawOrderItemId = json['order_item_id'] ?? json['orderItemId'];
    final parsedOrderItemId = rawOrderItemId is int ? rawOrderItemId : int.tryParse(rawOrderItemId?.toString() ?? '');

    final rawUnread = json['unread_count'] ?? json['unreadCount'];
    final parsedUnread = rawUnread is int ? rawUnread : int.tryParse(rawUnread?.toString() ?? '') ?? 0;

    final rawSenderId = json['last_sender_id'] ?? json['lastSenderId'];
    final parsedSenderId = rawSenderId is int ? rawSenderId : int.tryParse(rawSenderId?.toString() ?? '');

    return ChatGroupItem(
      groupId: parsedGId,
      orderId: parsedOId,
      orderItemId: parsedOrderItemId,
      groupTitle: json['group_title'] ?? json['groupTitle'] ?? json['title'] ?? 'Group Pelayanan',
      lastMessageText: json['last_message_text'] ?? json['lastMessageText'],
      lastMessageAt: json['last_message_at'] ?? json['lastMessageAt'],
      lastSenderId: parsedSenderId,
      lastSenderName: json['last_sender_name'] ?? json['lastSenderName'],
      orderTitle: json['order_title'] ?? json['orderTitle'] ?? json['title'] ?? 'Pelayanan',
      orderCategory: json['order_category'] ?? json['orderCategory'] ?? json['category'] ?? 'Permintaan Pelayanan',
      orderStatus: json['order_status'] ?? json['orderStatus'] ?? json['status'] ?? 'CONFIRMED',
      urgencyName: json['urgency_name'] ?? json['urgencyName'] ?? 'Biasa',
      scheduledDate: json['scheduled_date'] ?? json['scheduledDate'] ?? '',
      scheduledTimeStart: json['scheduled_time_start'] ?? json['scheduledTimeStart'] ?? '08:00',
      scheduledTimeEnd: json['scheduled_time_end'] ?? json['scheduledTimeEnd'] ?? '09:00',
      penerimaName: json['penerima_name'] ?? json['penerimaName'] ?? 'Umat',
      requesterName: json['requester_name'] ?? json['requesterName'] ?? 'Nama Umat',
      requesterAvatar: json['requester_avatar'] ?? json['requesterAvatar'],
      notes: json['notes'] ?? '',
      unreadCount: parsedUnread,
    );
  }
}
