import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';

/// Top-level handler for background messages (must be top-level function).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Android auto-displays notifications with a `notification` payload
  // in background/terminated state. No need to show a local notification.
  await Firebase.initializeApp();
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _token;

  String? get token => _token;

  /// Initialize FCM and local notifications. Call once at app startup.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Request permission (Android 13+)
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    // Initialize local notifications
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _local.initialize(initSettings);

    // Create notification channel
    const channel = AndroidNotificationChannel(
      'market_alerts',
      'Market Alerts',
      description: 'Market open/close and price alerts',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Get FCM token
    _token = await _fcm.getToken();

    // Register token with backend
    await _registerTokenWithBackend(_token);

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((newToken) {
      _token = newToken;
      _registerTokenWithBackend(newToken);
    });

    // Foreground message handler — only show local notification
    // when the app is in the foreground, since Android auto-displays
    // the notification payload when the app is in background/terminated.
    FirebaseMessaging.onMessage.listen((message) async {
      // Foreground: Android does NOT auto-display, so we must show it
      await _showLocalNotification(message);
    });

    // Background message handler
    FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler);

    // Subscribe to default topic
    await _fcm.subscribeToTopic('market_alerts');
  }

  /// Register the FCM token with the backend so per-device notifications work.
  Future<void> _registerTokenWithBackend(String? fcmToken) async {
    if (fcmToken == null || fcmToken.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString(AppConstants.prefDeviceId);
      if (deviceId == null || deviceId.trim().isEmpty) return;

      final baseUrl =
          prefs.getString(AppConstants.prefBaseUrl) ?? AppConstants.defaultBaseUrl;
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 6),
        sendTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 8),
      ));
      await dio.post('/ipos/register-device', data: {
        'device_id': deviceId,
        'fcm_token': fcmToken,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
    } catch (_) {
      // Non-fatal — token registration is best-effort
    }
  }

  /// Show a local notification from an FCM message.
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'market_alerts',
      'Market Alerts',
      channelDescription: 'Market open/close and price alerts',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: androidDetails);

    await _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
    );
  }

  /// Check if notifications are enabled in user preferences.
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true;
  }

  /// Toggle notification preference.
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
    if (enabled) {
      await _fcm.subscribeToTopic('market_alerts');
    } else {
      await _fcm.unsubscribeFromTopic('market_alerts');
    }
  }
}
