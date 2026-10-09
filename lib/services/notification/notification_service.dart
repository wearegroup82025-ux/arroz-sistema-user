import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handles:
/// 1. FCM token registration
/// 2. Foreground push notifications
/// 3. Local notification display
/// 4. Notification history in Firestore
/// 5. De-duplication of notification history
///
/// IMPORTANT:
/// Order-status push notifications that must work while the app is killed
/// must be sent by a trusted server / Firebase Cloud Function using FCM.
/// See the companion Firebase Function file.
class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifs =
      FlutterLocalNotificationsPlugin();

  static const String channelAlerts = 'stock_alerts_channel';
  static const String channelOrders = 'orders_channel';
  static const String channelUsers = 'users_channel';
  static const String channelWeather = 'weather_channel';
  static const String channelTyphoonSOS = 'typhoon_sos_channel';

  static const String _androidChannelName = 'ArrozSistema System';

  Future<void> initialize() async {
    try {
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      const settings = InitializationSettings(
        android: androidSettings,
        iOS: DarwinInitializationSettings(),
      );

      await _localNotifs.initialize(
        settings,
        onDidReceiveNotificationResponse: (details) {
          _handleNotificationClick(details.payload);
        },
      );

      final android = _localNotifs
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await android?.requestNotificationsPermission();

      await _createChannel(
        channelAlerts,
        'Inventory Alerts',
        'Stock warnings',
        Importance.high,
      );

      await _createChannel(
        channelOrders,
        'Orders & Status',
        'Order status updates',
        Importance.high,
      );

      await _createChannel(
        channelUsers,
        'User Notifications',
        'Account notifications',
        Importance.defaultImportance,
      );

      await _createChannel(
        channelWeather,
        'Weather Updates',
        'Weather and delay alerts',
        Importance.defaultImportance,
      );

      const sosChannel = AndroidNotificationChannel(
        channelTyphoonSOS,
        'EMERGENCY TYPHOON ALERTS',
        description: 'Critical disaster warnings',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await android?.createNotificationChannel(sosChannel);

      await _registerToken();

      _fcm.onTokenRefresh.listen((token) async {
        await _saveToken(token);
      });

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleOpenedMessage(initialMessage);
      }

      debugPrint('NotificationService initialized.');
    } catch (e, stackTrace) {
      debugPrint('NotificationService initialization error: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> initNotification() async {
    await NotificationService().initialize();
  }

  /// Call this after a successful user login as well.
  /// This is important when initialize() ran before authentication.
  Future<void> registerCurrentUserToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await _fcm.getToken();
    if (token == null || token.isEmpty) return;

    await _saveToken(token);
  }

  Future<void> _registerToken() async {
    await registerCurrentUserToken();
  }

  Future<void> _saveToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || token.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Keep the token in a dedicated collection too.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('fcmTokens')
          .doc(_safeTokenId(token))
          .set({
        'token': token,
        'platform': defaultTargetPlatform.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FCM token save error: $e');
    }
  }

  String _safeTokenId(String token) {
    // Firestore document IDs may contain most characters, but using
    // base64url gives us a stable compact-safe identifier.
    return base64UrlEncode(utf8.encode(token))
        .replaceAll('=', '')
        .replaceAll('/', '_')
        .replaceAll('+', '-');
  }

  Future<void> _createChannel(
    String id,
    String name,
    String description,
    Importance importance,
  ) async {
    final channel = AndroidNotificationChannel(
      id,
      name,
      description: description,
      importance: importance,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifs
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    final title =
        notification?.title ?? data['title']?.toString() ?? 'Notification';

    final body =
        notification?.body ?? data['body']?.toString() ?? '';

    final type = data['type']?.toString() ?? 'GENERAL';

    final userId =
        data['userId']?.toString() ?? FirebaseAuth.instance.currentUser?.uid;

    if (userId != null && title.isNotEmpty) {
      await saveNotification(
        userId: userId,
        title: title,
        body: body,
        type: type,
        notificationId: data['notificationId']?.toString(),
        orderId: data['orderId']?.toString(),
      );
    }

    await showNotification(
      id: _notificationId(message.messageId),
      title: title,
      body: body,
      payload: jsonEncode(data),
      channelId: _channelFor(type),
    );
  }

  static Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    try {
      await Firebase.initializeApp();

      // The Cloud Function already writes the notification history.
      // This handler only initializes Firebase for background FCM delivery.

      debugPrint(
        'Background FCM received: ${message.messageId}',
      );
    } catch (e) {
      debugPrint('Background notification error: $e');
    }
  }

  static Future<void> saveNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? notificationId,
    String? orderId,
  }) async {
    if (userId.isEmpty || title.trim().isEmpty) return;

    try {
      final collection = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications');

      final id = notificationId?.trim().isNotEmpty == true
          ? notificationId!.trim()
          : _buildDeterministicId(
              type: type,
              title: title,
              body: body,
              orderId: orderId,
            );

      final ref = collection.doc(id);

      // create-only semantics prevent duplicate notification history.
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final existing = await transaction.get(ref);

        if (existing.exists) {
          return;
        }

        transaction.set(ref, {
          'title': title.trim(),
          'body': body.trim(),
          'type': type,
          'orderId': orderId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      debugPrint('Save notification error: $e');
    }
  }

  static String _buildDeterministicId({
    required String type,
    required String title,
    required String body,
    String? orderId,
  }) {
    final raw = [
      type,
      orderId ?? '',
      title,
      body,
    ].join('|');

    return _simpleStableHash(raw);
  }

  static String _simpleStableHash(String value) {
    var hash = 0x811c9dc5;

    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }

    return hash.toRadixString(16).padLeft(8, '0');
  }

  static int _notificationId(String? messageId) {
    if (messageId == null || messageId.isEmpty) {
      return DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
    }

    return _simpleStableHash(messageId).hashCode & 0x7FFFFFFF;
  }

  static String _channelFor(String type) {
    switch (type) {
      case 'ORDER_UPDATE':
        return channelOrders;
      case 'DELAY_WARNING':
        return channelWeather;
      default:
        return channelAlerts;
    }
  }

  static Future<void> showNotification({
    int? id,
    required String title,
    required String body,
    String? payload,
    String channelId = channelAlerts,
    bool isOngoing = false,
  }) async {
    try {
      final targetId =
          id ?? DateTime.now().millisecondsSinceEpoch.remainder(2147483647);

      final isSOS = channelId == channelTyphoonSOS;

      final androidDetails = AndroidNotificationDetails(
        channelId,
        isSOS ? '🚨 EMERGENCY ALERTS' : _androidChannelName,
        importance: isSOS ? Importance.max : Importance.high,
        priority: isSOS ? Priority.max : Priority.high,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(body),
        ongoing: isOngoing || isSOS,
        autoCancel: !isSOS,
        fullScreenIntent: isSOS,
        playSound: true,
      );

      final platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentSound: true,
          presentBanner: true,
          presentList: true,
          interruptionLevel:
              isSOS ? InterruptionLevel.critical : InterruptionLevel.active,
        ),
      );

      await NotificationService()._localNotifs.show(
        targetId,
        title,
        body,
        platformDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Notification display failed: $e');
    }
  }

  static Future<void> dismissNotification(int id) async {
    try {
      await NotificationService()._localNotifs.cancel(id);
    } catch (e) {
      debugPrint('Error dismissing notification: $e');
    }
  }

  void _handleOpenedMessage(RemoteMessage message) {
    debugPrint(
      'Opened notification: ${message.messageId}, data: ${message.data}',
    );

    // Navigation can be wired to your global navigator later.
    // The notification history remains available in NotificationPage.
  }

  void _handleNotificationClick(String? payload) {
    if (payload == null || payload.isEmpty) return;
    debugPrint('Clicked local notification payload: $payload');
  }
}

/// Top-level background handler required by Firebase Messaging.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService.firebaseMessagingBackgroundHandler(message);
}
