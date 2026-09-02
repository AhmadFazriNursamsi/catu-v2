import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';
import '../models/models.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/chat/chat_list_screen.dart';
import '../../features/notifications/notification_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

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

class NotificationService {
  static const String _key = 'catu_notifications_v1';
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static Map<String, dynamic>? currentUser;

  static bool _isInitialized = false;
  static String? _currentToken;
  static dynamic activeChatGroupId;
  static final Map<String, int> _recentNotificationTimestamps = {};

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'catu_custom_sound_channel_v1',
    'Pelayanan & Chat CATU',
    description: 'Notifikasi penting untuk permintaan pelayanan Romo, persetujuan jadwal, dan pesan chat umat',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('notif_catu'),
    enableVibration: true,
  );

  static Future<void> setCurrentUser(Map<String, dynamic> user) async {
    currentUser = Map<String, dynamic>.from(user);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('catu_current_user_profile', jsonEncode(user));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> _loadStoredUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('catu_current_user_profile');
      if (raw != null && raw.isNotEmpty) {
        return jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  static String? _pendingPayload;

  static void checkPendingNotificationTap() {
    if (_pendingPayload != null) {
      final payload = _pendingPayload;
      _pendingPayload = null;
      Future.delayed(const Duration(milliseconds: 600), () {
        handleNotificationTap(payload);
      });
    }
  }

  static Future<void> handleNotificationTap(String? payloadStr) async {
    if (payloadStr == null || payloadStr.isEmpty) return;
    try {
      debugPrint('👉 handleNotificationTap called with: $payloadStr');
      final Map<String, dynamic> data = jsonDecode(payloadStr);
      final String type = (data['type'] ?? data['notifType'] ?? data['notification_type'] ?? '').toString().toUpperCase();
      final int notifId = int.tryParse(data['id']?.toString() ?? '') ?? 0;
      if (notifId > 0) {
        ApiService.markNotificationRead(notifId);
      }

      final navState = navigatorKey.currentState;
      if (navState == null) {
        debugPrint('👉 navState is null, queuing payload for checkPendingNotificationTap');
        _pendingPayload = payloadStr;
        return;
      }

      final userMap = currentUser ?? await _loadStoredUser();
      final uName = userMap?['fullName'] ?? userMap?['full_name'] ?? 'User';
      final uId = userMap?['id'] ?? userMap?['userId'] ?? userMap?['user_id'];
      final int? currentUserId = uId != null ? int.tryParse(uId.toString()) : null;
      final role = userMap?['roleCode'] ?? userMap?['role_code'] ?? userMap?['role'] ?? 'UMAT';
      final isRomo = role.toString().toUpperCase().contains('ROMO');

      // 💬 1. CHAT NOTIFICATION -> Langsung masuk ke Grup Chatting
      if (type == 'CHAT_MESSAGE' || data.containsKey('groupId') || data.containsKey('chat_group_id')) {
        int? groupId = int.tryParse(data['groupId']?.toString() ?? data['group_id']?.toString() ?? data['chat_group_id']?.toString() ?? '');
        final int? orderId = int.tryParse(data['orderId']?.toString() ?? data['order_id']?.toString() ?? '');
        final orderNumber = data['orderNumber']?.toString() ?? (orderId != null ? 'ORD-$orderId' : 'Grup Pelayanan');

        if (groupId == null || groupId <= 0) {
          if (orderId != null && orderId > 0) {
            groupId = await ApiService.getChatGroupIdForOrder(orderId);
          }
        }

        if (groupId != null && groupId > 0) {
          ChatGroupItem? preloadedGroup;
          try {
            preloadedGroup = await ApiService.getChatGroupDetails(groupId, userId: currentUserId);
          } catch (_) {}

          navState.push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                groupId: groupId!,
                orderNumber: orderNumber.isNotEmpty ? orderNumber : (preloadedGroup?.orderId.toString() ?? groupId.toString()),
                userName: uName,
                userId: currentUserId,
                isRomo: isRomo,
                groupItem: preloadedGroup,
              ),
            ),
          );
        } else {
          navState.push(
            MaterialPageRoute(
              builder: (_) => ChatListScreen(
                user: userMap ?? {},
                orders: const [],
              ),
            ),
          );
        }
        return;
      }

      // 🔔 2. GENERAL NOTIFICATION -> Cukup sampai di List Notif saja
      navState.push(
        MaterialPageRoute(
          builder: (_) => NotificationScreen(
            role: role.toString(),
            orders: const [],
            user: userMap ?? {},
            isRomo: isRomo,
            romoId: isRomo ? currentUserId : null,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error handling notification tap: $e');
    }
  }

  static Future<void> init() async {
    if (_isInitialized) return;

    // 1. Setup Local Notifications
    const androidSettings = AndroidInitializationSettings('@drawable/ic_stat_catu');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    try {
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          print('Notification tapped: ${response.payload}');
          handleNotificationTap(response.payload);
        },
      );

      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.createNotificationChannel(_channel);

      final iosImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      final macosImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
      await macosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      print('Local notification init error: $e');
    }

    // 2. Initialize Firebase Cloud Messaging (FCM)
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await messaging.getToken();
      if (token != null) {
        _currentToken = token;
        debugPrint('🔥 Firebase FCM Token: $token');
      }

      messaging.onTokenRefresh.listen((newToken) {
        _currentToken = newToken;
        if (currentUser != null) {
          final uid = currentUser!['id'] ?? currentUser!['userId'] ?? currentUser!['user_id'];
          if (uid != null) registerUserDevice(uid);
        }
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notif = message.notification;
        if (notif != null) {
          showNotification(
            title: notif.title ?? 'Pemberitahuan CATU',
            body: notif.body ?? '',
            payload: jsonEncode(message.data),
          );
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('🔥 FCM onMessageOpenedApp received: ${message.data}');
        handleNotificationTap(jsonEncode(message.data));
      });

      // Cold start from terminated state
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null && initialMessage.data.isNotEmpty) {
        debugPrint('🔥 FCM getInitialMessage received: ${initialMessage.data}');
        _pendingPayload = jsonEncode(initialMessage.data);
        handleNotificationTap(_pendingPayload);
      }
    } catch (e) {
      debugPrint('Firebase init error: $e');
    }

    _isInitialized = true;
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    // 1. Suppress in-app notification if user is actively viewing this chat
    if (payload != null && payload.isNotEmpty) {
      try {
        final Map<String, dynamic> data = jsonDecode(payload);
        final String type = (data['type'] ?? data['notifType'] ?? data['notification_type'] ?? '').toString().toUpperCase();
        final String incomingGroupId = (data['groupId'] ?? data['group_id'] ?? '').toString();
        if (type == 'CHAT_MESSAGE' && activeChatGroupId != null && incomingGroupId.isNotEmpty && activeChatGroupId.toString() == incomingGroupId) {
          debugPrint('🔇 Suppressing in-app notification because user is actively viewing chat group $incomingGroupId');
          return;
        }
      } catch (_) {}
    }

    // 2. Deduplicate identical notifications within a 10-second window based on title & body
    final String notifKey = '${title.trim().toLowerCase()}|${body.trim().toLowerCase()}';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_recentNotificationTimestamps.containsKey(notifKey)) {
      final lastTime = _recentNotificationTimestamps[notifKey]!;
      if (nowMs - lastTime < 10000) {
        debugPrint('🔇 Suppressing duplicate notification within 10s: $title');
        return;
      }
    }
    _recentNotificationTimestamps[notifKey] = nowMs;
    _recentNotificationTimestamps.removeWhere((_, time) => nowMs - time > 60000);

    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/ic_stat_catu',
      largeIcon: const DrawableResourceAndroidBitmap('@drawable/ic_catu_logo'),
      color: const Color(0xFF1E5399),
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('notif_catu'),
      enableVibration: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notif_catu.caf',
      presentBanner: true,
      presentList: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await _localNotifications.show(
        id != 0 ? id : DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      print('Error showNotification: $e');
    }
  }

  static Future<void> registerUserDevice(dynamic userId) async {
    try {
      final intUid = int.tryParse(userId.toString()) ?? 0;
      if (intUid <= 0) return;

      if (_currentToken == null || _currentToken!.isEmpty) {
        try {
          _currentToken = await FirebaseMessaging.instance.getToken();
        } catch (_) {}
      }

      final deviceType = kIsWeb ? 'WEB' : (Platform.isIOS ? 'IOS' : 'ANDROID');

      if (_currentToken != null && _currentToken!.isNotEmpty) {
        await ApiService.registerDeviceToken(
          userId: intUid,
          fcmToken: _currentToken!,
          deviceType: deviceType,
        );
        debugPrint('NotificationService: Registered FCM device token for user $intUid ($deviceType)');
      }
    } catch (e) {
      print('Error registerUserDevice: $e');
    }
  }

  static Future<void> unregisterUserDevice(dynamic userId) async {
    try {
      final intUid = int.tryParse(userId.toString()) ?? 0;
      if (intUid <= 0) return;

      if (_currentToken != null && _currentToken!.isNotEmpty) {
        await ApiService.unregisterDeviceToken(
          userId: intUid,
          fcmToken: _currentToken!,
        );
      }
    } catch (e) {
      print('Error unregisterUserDevice: $e');
    }
  }

  // ─── Real-Time Notification Polling Stream ────────────────────────────────
  static Timer? _pollingTimer;
  static final Set<int> _knownNotifIds = {};

  static void startPolling(dynamic userId) {
    _pollingTimer?.cancel();
    final intUid = int.tryParse(userId.toString()) ?? 0;
    if (intUid <= 0) return;

    // Pre-populate existing notif IDs so we don't spam old notifications
    ApiService.getNotifications(userId: intUid).then((notifs) {
      for (final n in notifs) {
        final id = n['id'] is int ? n['id'] : int.tryParse(n['id'].toString());
        if (id != null) _knownNotifIds.add(id);
      }
    }).catchError((_) {});

    // Poll every 3 seconds for instant notifications
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final notifs = await ApiService.getNotifications(userId: intUid);
        for (final n in notifs) {
          final id = n['id'] is int ? n['id'] : int.tryParse(n['id'].toString());
          if (id != null && !_knownNotifIds.contains(id)) {
            _knownNotifIds.add(id);
            final isRead = n['isRead'] == true || n['is_read'] == true;
            // Only show local notification fallback from polling if FCM is not active
            if (!isRead && (_currentToken == null || _currentToken!.isEmpty)) {
              await showNotification(
                title: n['title'] ?? 'Pemberitahuan CATU',
                body: n['body'] ?? '',
                id: id,
                payload: jsonEncode({
                  'id': id,
                  'type': n['type'],
                  'orderId': n['orderId'] ?? n['order_id'],
                  'groupId': n['groupId'] ?? n['group_id'],
                  'orderNumber': n['orderNumber'] ?? n['order_number'],
                  'title': n['title'],
                  'body': n['body'],
                }),
              );
            }
          }
        }
      } catch (_) {}
    });
  }

  static void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

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
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  // ─── Get For Role (with backend sync and location filtering) ──────────────────

  static Future<List<NotificationItem>> getForRole(
    String role, {
    int? userId,
    int? parokiId,
    int? kabupatenKotaId,
  }) async {
    if (userId != null && userId > 0) {
      try {
        final rawNotifs = await ApiService.getNotifications(userId: userId);
        final List<NotificationItem> backendItems = [];
        for (final r in rawNotifs) {
          final id = 'backend_${r['id']}';
          final title = r['title'] ?? 'Pemberitahuan';
          final body = r['body'] ?? '';
          final type = r['type'] ?? 'STATUS_UPDATE';
          final isRead = r['isRead'] == true || r['is_read'] == true;
          final rawOrder = r['orderId'] ?? r['order_id'];
          final orderId = rawOrder != null ? rawOrder.toString() : null;
          final categoryName = r['categoryName'] ?? r['category_name'];
          final createdAt = DateTime.tryParse(r['createdAt'] ?? r['created_at'] ?? '') ?? DateTime.now();
          final rawGroup = r['groupId'] ?? r['group_id'];
          final int? groupId = rawGroup != null ? int.tryParse(rawGroup.toString()) : null;
          final orderNumber = r['orderNumber'] ?? r['order_number'];

          backendItems.add(NotificationItem(
            id: id,
            title: title,
            body: body,
            type: type,
            role: role,
            createdAt: createdAt,
            isRead: isRead,
            orderId: orderId,
            categoryName: categoryName,
            groupId: groupId,
            orderNumber: orderNumber,
          ));
        }

        backendItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return backendItems;
      } catch (e) {
        print('Error getNotifications from backend: $e');
      }
    }

    final all = await getAll();
    final filtered = all.where((n) {
      if (n.role != role) return false;
      if (role == 'ROMO_PAROKI') {
        if (parokiId != null && n.parokiId != null) {
          return n.parokiId == parokiId;
        }
        return true;
      }
      if (role == 'ROMO_ORDO') {
        if (kabupatenKotaId != null && n.kabupatenKotaId != null) {
          return n.kabupatenKotaId == kabupatenKotaId;
        }
        return true;
      }
      return true;
    }).toList();

    return filtered;
  }

  // ─── Unread Count ─────────────────────────────────────────────────────────

  static Future<int> unreadCount(
    String role, {
    int? userId,
    int? parokiId,
    int? kabupatenKotaId,
  }) async {
    final list = await getForRole(
      role,
      userId: userId,
      parokiId: parokiId,
      kabupatenKotaId: kabupatenKotaId,
    );
    return list.where((n) => !n.isRead).length;
  }

  // ─── Add Notification ─────────────────────────────────────────────────────

  static Future<void> add(NotificationItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.insert(0, jsonEncode(item.toJson()));
    if (raw.length > 50) {
      raw.removeLast();
    }
    await prefs.setStringList(_key, raw);
  }

  // ─── Mark Read ────────────────────────────────────────────────────────────

  static Future<void> markRead(String id) async {
    if (id.startsWith('backend_')) {
      final intId = int.tryParse(id.replaceFirst('backend_', ''));
      if (intId != null) {
        await ApiService.markNotificationRead(intId);
      }
    }
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

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  // ─── Mark All Read For Role ───────────────────────────────────────────────

  static Future<void> markAllRead(
    String role, {
    int? userId,
    int? parokiId,
    int? kabupatenKotaId,
  }) async {
    if (userId != null && userId > 0) {
      await ApiService.markAllNotificationsRead(userId);
    }
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
    if (id.startsWith('backend_')) {
      final intId = int.tryParse(id.replaceFirst('backend_', ''));
      if (intId != null) {
        await ApiService.deleteNotification(intId);
      }
    }
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
    int? userId,
    int? parokiId,
    int? kabupatenKotaId,
  }) async {
    if (userId != null && userId > 0) {
      await ApiService.markAllNotificationsRead(userId);
    }
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

  static Future<String> _uniqueId(String prefix) async {
    final prefs = await SharedPreferences.getInstance();
    final counter = (prefs.getInt('notif_counter_v1') ?? 0) + 1;
    await prefs.setInt('notif_counter_v1', counter);
    return '${prefix}_${counter}_${DateTime.now().millisecondsSinceEpoch}';
  }

  static Future<void> notifyNewRequest({
    required String orderId,
    required String umatName,
    required String categoryName,
    required String targetRole,
    String? misaItemName,
    int? itemIndex,
    int? parokiId,
    int? kabupatenKotaId,
    String? currentUserRole,
  }) async {
    final isKedukaan = categoryName.toLowerCase().contains('kedukaan');
    final servicePhrase = isKedukaan
        ? (misaItemName != null && misaItemName.isNotEmpty ? misaItemName : 'Misa Kedukaan')
        : 'Sakramen Perminyakan';
    final locationPhrase = targetRole == 'ROMO_PAROKI'
        ? 'paroki anda'
        : (targetRole == 'ROMO_ORDO' ? 'kota anda' : 'lingkungan anda');
    final uniqueId = await _uniqueId('new_${targetRole.toLowerCase()}_${orderId}_${itemIndex ?? 0}');
    await add(NotificationItem(
      id: uniqueId,
      title: isKedukaan ? servicePhrase : 'Permintaan Pelayanan Sakramen Perminyakan',
      body: 'Umat yang berada di $locationPhrase telah membuat sebuah permintaan pelayanan $servicePhrase dengan nama umat $umatName',
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

  static Future<void> notifyRomoResponse({
    required String orderId,
    String? romoName,
    String? categoryName,
    bool accepted = true,
    String? misaItemName,
    String? orderNumber,
    String? action,
  }) async {
    final isAccepted = action != null ? action == 'ACCEPT' : accepted;
    final isKedukaan = (categoryName ?? '').toLowerCase().contains('kedukaan');
    final servicePhrase = isKedukaan
        ? (misaItemName != null && misaItemName.isNotEmpty ? misaItemName : 'Misa Kedukaan')
        : (categoryName ?? 'Sakramen Perminyakan');
    final actText = isAccepted ? 'mengkonfirmasi' : 'menolak';
    final uniqueId = await _uniqueId('romo_${orderId}');
    await add(NotificationItem(
      id: uniqueId,
      title: isAccepted ? '$servicePhrase Dikonfirmasi ✓' : '$servicePhrase Ditolak',
      body: 'Romo ${romoName ?? ""} telah $actText permintaan pelayanan $servicePhrase Anda.',
      type: isAccepted ? 'ROMO_ACCEPTED' : 'ROMO_DECLINED',
      role: 'UMAT',
      createdAt: DateTime.now(),
      orderId: orderId,
      categoryName: categoryName,
      itemTitle: misaItemName,
    ));
  }

  static Future<void> notifyServiceCompleted({
    required String orderId,
    String? categoryName,
    String? penerimaName,
    String? targetRole,
    String? misaItemName,
    String? orderNumber,
    String? serviceName,
  }) async {
    final isKedukaan = (categoryName ?? '').toLowerCase().contains('kedukaan');
    final servicePhrase = isKedukaan
        ? (misaItemName != null && misaItemName.isNotEmpty ? misaItemName : 'Misa Kedukaan')
        : (categoryName ?? serviceName ?? 'Sakramen Perminyakan');
    final uniqueId = await _uniqueId('done_${orderId}');
    await add(NotificationItem(
      id: uniqueId,
      title: '$servicePhrase Selesai ✓',
      body: 'Pelayanan $servicePhrase untuk ${penerimaName ?? "Umat"} telah selesai dilaksanakan.',
      type: 'STATUS_UPDATE',
      role: targetRole ?? 'UMAT',
      createdAt: DateTime.now(),
      orderId: orderId,
      categoryName: categoryName,
      itemTitle: misaItemName,
    ));
  }
}
