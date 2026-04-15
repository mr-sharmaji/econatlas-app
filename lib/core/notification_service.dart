import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';

// ─────────────────────────────────────────────────────────────────────
// Shared notification configuration
// ─────────────────────────────────────────────────────────────────────
// The channel + Android init settings must be available to both the
// main isolate and the background isolate (the handler below runs in
// its own isolate so it can't reach `NotificationService.instance`).
// Keep these as top-level constants so both paths stay in sync.

const String _channelId = 'market_alerts';
const String _channelName = 'Market Alerts';
const String _channelDescription =
    'Market open/close and price alerts';
const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  _channelId,
  _channelName,
  description: _channelDescription,
  importance: Importance.high,
);

/// Build a Flutter-local notification from an FCM data payload and show it.
///
/// The server sends Android pushes as data-only messages (no `notification`
/// field) — title and body live under `message.data['title'] / ['body']`.
/// Rendering is fully client-side so we can force BigTextStyle on every
/// post: the collapsed view shows the first 1–2 lines, and pulling the
/// shade down expands to the full multi-sentence narrative instead of
/// ellipsizing to "…" in the compact row.
Future<void> _displayFromData(
  FlutterLocalNotificationsPlugin plugin,
  RemoteMessage message,
) async {
  final data = message.data;
  // Fall back to `message.notification` so iOS test pushes from the
  // Firebase console (which always send a notification payload) still
  // render correctly — this only affects debug flows.
  final String? title = (data['title'] as String?) ?? message.notification?.title;
  final String? body = (data['body'] as String?) ?? message.notification?.body;
  if (title == null && body == null) return;

  final androidDetails = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDescription,
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
    // BigTextStyle ensures long multi-sentence bodies expand fully
    // when the user pulls down the notification shade, across every
    // Android version and OEM skin. Without this, default remote-
    // notification rendering clips the body to a single ellipsized
    // line (see the "47-advancer…" report).
    styleInformation: BigTextStyleInformation(
      body ?? '',
      htmlFormatBigText: false,
      contentTitle: title,
      htmlFormatContentTitle: false,
      summaryText: null,
    ),
  );
  final details = NotificationDetails(android: androidDetails);

  // `message.messageId` is stable across deliveries; fall back to
  // hashCode so local tests without a real FCM id still show up.
  final int id = (message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString())
      .hashCode;
  await plugin.show(id, title, body, details);
}

/// Top-level handler for background messages (must be a top-level function
/// so Dart can register it as an entry point for the background isolate).
///
/// Because the server no longer ships a `notification` payload on Android,
/// the system will not auto-display anything in background/terminated
/// state — we must build and show the local notification ourselves, even
/// from this isolated entry point. That means initializing both Firebase
/// and flutter_local_notifications inside the background isolate.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final plugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await plugin.initialize(initSettings);
  // Re-register the channel — cheap and idempotent. Required on cold
  // starts where the main isolate hasn't created it yet.
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_channel);
  await _displayFromData(plugin, message);
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
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Get FCM token
    _token = await _fcm.getToken();

    // Register token with backend
    await _registerTokenWithBackend(_token);

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((newToken) {
      _token = newToken;
      _registerTokenWithBackend(newToken);
    });

    // Foreground message handler — Android no longer auto-displays
    // (server sends data-only) so we must render every push ourselves.
    FirebaseMessaging.onMessage.listen((message) async {
      await _displayFromData(_local, message);
    });

    // Background / terminated message handler — same story. Runs in a
    // separate isolate and re-initializes FLN inside the top-level
    // entry point.
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
