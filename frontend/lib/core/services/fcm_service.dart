import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'call_service.dart';

const _channelId = 'shopho_orders';
const _channelName = 'Đơn hàng';

final _localNotif = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (message.data['type'] == 'call') {
    await CallService.showIncomingCall(
      callId: message.data['call_id'] ?? '',
      callerName: message.data['caller_name'] ?? 'Người gọi',
      orderId: message.data['order_id'] ?? '',
    );
  }
}

class FcmService {
  static void Function(String orderId)? _navigate;
  static String? _pendingOrderId;

  /// If the app was launched by tapping a notification while terminated,
  /// returns the order ID to navigate to (and clears it).
  static String? consumePendingNavigation() {
    final id = _pendingOrderId;
    _pendingOrderId = null;
    return id;
  }

  static Future<void> init(
    FirebaseOptions options, {
    required void Function(String orderId) onNavigateToOrder,
  }) async {
    _navigate = onNavigateToOrder;

    await Firebase.initializeApp(options: options);
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

    // Android notification channel
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      importance: Importance.high,
    );
    await _localNotif
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Init local notifications plugin — tap on foreground notification navigates to order
    await _localNotif.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (details) {
        final orderId = details.payload;
        if (orderId != null && orderId.isNotEmpty) {
          _navigate?.call(orderId);
        }
      },
    );

    // iOS foreground presentation
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // App in background → user taps FCM notification → navigate to order
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final orderId = message.data['order_id'] as String?;
      if (orderId != null && orderId.isNotEmpty) {
        _navigate?.call(orderId);
      }
    });

    // App terminated → opened via FCM notification → store and navigate after first frame
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      final orderId = initial.data['order_id'] as String?;
      if (orderId != null && orderId.isNotEmpty) {
        _pendingOrderId = orderId;
      }
    }

    // Show notification when app is in foreground
    FirebaseMessaging.onMessage.listen((message) {
      // Call messages: show callkit UI, not a regular notification
      if (message.data['type'] == 'call') {
        CallService.showIncomingCall(
          callId: message.data['call_id'] ?? '',
          callerName: message.data['caller_name'] ?? 'Người gọi',
          orderId: message.data['order_id'] ?? '',
        );
        return;
      }
      final notification = message.notification;
      if (notification == null) return;
      final orderId = message.data['order_id'] as String?;
      _localNotif.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: orderId, // tapped → navigates to this order
      );
    });

    // Request permission (iOS/Android 13+)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Register the device token with the backend. Call after login.
  static Future<void> registerToken(Dio dio) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await dio.post(
        '/users/me/device-token',
        data: {'token': token, 'platform': defaultTargetPlatform.name.toLowerCase()},
      );
    } catch (e) {
      debugPrint('[FCM] registerToken error: $e');
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        await dio.post(
          '/users/me/device-token',
          data: {'token': newToken, 'platform': defaultTargetPlatform.name.toLowerCase()},
        );
      } catch (_) {}
    });
  }
}
