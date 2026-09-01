import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;
  static String? _currentToken;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'catu_high_importance_channel',
    'Pelayanan & Chat CATU',
    description: 'Notifikasi penting untuk permintaan pelayanan Romo, persetujuan jadwal, dan pesan chat umat',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static Future<void> init() async {
    if (_isInitialized) return;

    // 1. Setup Local Notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Notification tapped: ${response.payload}');
      },
    );

    // Create Notification Channel for Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 2. Setup Firebase Messaging if available
    try {
      if (!kIsWeb) {
        await Firebase.initializeApp();
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

        final messaging = FirebaseMessaging.instance;
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        // Capture token
        _currentToken = await messaging.getToken();
        print('FCM Device Token: $_currentToken');

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          final notif = message.notification;
          if (notif != null) {
            showNotification(
              title: notif.title ?? 'Notifikasi CATU',
              body: notif.body ?? '',
              payload: message.data.toString(),
            );
          }
        });
      }
    } catch (e) {
      print('Firebase Messaging init info (waiting for config): $e');
    }

    _isInitialized = true;
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _localNotifications.show(
      id != 0 ? id : DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  static Future<void> registerUserDevice(int userId) async {
    try {
      String? token = _currentToken;
      if (token == null && !kIsWeb) {
        try {
          token = await FirebaseMessaging.instance.getToken();
          _currentToken = token;
        } catch (_) {}
      }

      final deviceType = kIsWeb ? 'WEB' : (Platform.isIOS ? 'IOS' : 'ANDROID');

      if (token != null && token.isNotEmpty) {
        await ApiService.registerDeviceToken(
          userId: userId,
          fcmToken: token,
          deviceType: deviceType,
        );
      }
    } catch (e) {
      print('Error registerUserDevice: $e');
    }
  }

  static Future<void> unregisterUserDevice(int userId) async {
    try {
      if (_currentToken != null && _currentToken!.isNotEmpty) {
        await ApiService.unregisterDeviceToken(
          userId: userId,
          fcmToken: _currentToken!,
        );
      }
    } catch (e) {
      print('Error unregisterUserDevice: $e');
    }
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
    final title = isAccepted ? 'Pelayanan Diterima Romo' : 'Romo Berhalangan Hadir';
    final itemName = misaItemName ?? categoryName ?? 'Pelayanan';
    final body = isAccepted
        ? '${romoName ?? "Romo"} telah bersedia melayani permintaan $itemName.'
        : '${romoName ?? "Romo"} tidak dapat melayani permintaan $itemName.';
    await showNotification(title: title, body: body);
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
    final itemName = misaItemName ?? serviceName ?? categoryName ?? 'Pelayanan';
    await showNotification(
      title: 'Pelayanan Selesai Dilaksanakan',
      body: 'Pelayanan $itemName telah selesai dilaksanakan. Berkah Dalem.',
    );
  }
}
