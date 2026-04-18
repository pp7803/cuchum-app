import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling background message: ${message.messageId}');
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  Timer? _appleTokenRetryTimer;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Android notification channel
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'cuchum_notifications',
    'CucHum Notifications',
    description: 'Thông báo từ CucHum',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// Initialize FCM and local notifications
  Future<void> initialize({
    required Function(String token) onTokenReceived,
    Function(RemoteMessage message)? onMessageReceived,
    Function(RemoteMessage message)? onMessageOpenedApp,
  }) async {
    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission
    await _requestPermission();

    // iOS/macOS: verify APNs token bridge before reading FCM token.
    await _logApplePushBridgeStatus();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Get FCM token (safe on Apple: wait for APNs bridge and auto-retry)
    await _resolveAndEmitToken(onTokenReceived);

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      debugPrint('FCM Token refreshed: $newToken');
      onTokenReceived(newToken);
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Received foreground message: ${message.messageId}');
      _showLocalNotification(message);
      onMessageReceived?.call(message);
    });

    // Handle when app is opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('App opened from notification: ${message.messageId}');
      onMessageOpenedApp?.call(message);
    });

    // Check if app was opened from a notification when terminated
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App launched from notification: ${initialMessage.messageId}');
      onMessageOpenedApp?.call(initialMessage);
    }
  }

  /// Request notification permission
  Future<bool> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    final authorized =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    debugPrint('FCM permission status: ${settings.authorizationStatus}');
    return authorized;
  }

  Future<void> _logApplePushBridgeStatus() async {
    if (!Platform.isIOS && !Platform.isMacOS) return;

    String? apnsToken;
    for (var i = 0; i < 5; i++) {
      apnsToken = await _messaging.getAPNSToken();
      if (apnsToken != null && apnsToken.isNotEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }

    if (apnsToken == null || apnsToken.isEmpty) {
      debugPrint(
        '[FCM/APNs] APNs token is null. FCM iOS delivery will fail until APNs registration succeeds.',
      );
      return;
    }

    debugPrint('[FCM/APNs] APNs token available: $apnsToken');
  }

  Future<void> _resolveAndEmitToken(
    Function(String token) onTokenReceived,
  ) async {
    if (Platform.isIOS || Platform.isMacOS) {
      final bridgeReady = await _waitForApnsBridge();
      if (!bridgeReady) {
        debugPrint(
          '[FCM/APNs] APNs token still unavailable. Scheduling FCM token retry.',
        );
        _scheduleAppleTokenRetry(onTokenReceived);
        return;
      }
    }

    try {
      _fcmToken = await _messaging.getToken();
      if (_fcmToken != null && _fcmToken!.isNotEmpty) {
        debugPrint('FCM Token: $_fcmToken');
        onTokenReceived(_fcmToken!);
      }
    } on FirebaseException catch (e) {
      if (e.code == 'apns-token-not-set') {
        debugPrint(
          '[FCM/APNs] APNs token not set yet. Scheduling FCM token retry.',
        );
        _scheduleAppleTokenRetry(onTokenReceived);
        return;
      }
      debugPrint('Failed to get FCM token: ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('Failed to get FCM token: $e');
    }
  }

  Future<bool> _waitForApnsBridge() async {
    if (!Platform.isIOS && !Platform.isMacOS) return true;

    for (var i = 0; i < 8; i++) {
      final apnsToken = await _messaging.getAPNSToken();
      if (apnsToken != null && apnsToken.isNotEmpty) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
    return false;
  }

  void _scheduleAppleTokenRetry(Function(String token) onTokenReceived) {
    if (!Platform.isIOS && !Platform.isMacOS) return;
    _appleTokenRetryTimer?.cancel();
    _appleTokenRetryTimer = Timer(const Duration(seconds: 3), () {
      _resolveAndEmitToken(onTokenReceived);
    });
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    // Android initialization
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS initialization
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // macOS initialization
    const macOSSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: macOSSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create Android notification channel
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);
    }
  }

  /// Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Handle navigation based on payload
    if (response.payload != null) {
      try {
        final data = json.decode(response.payload!);
        _handleNotificationNavigation(data);
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  /// Handle navigation from notification
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final id = data['notification_id'] as String?;

    debugPrint('Navigation: type=$type, id=$id');
    // TODO: Implement navigation based on notification type
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: json.encode(message.data),
    );
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('Subscribed to topic: $topic');
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('Unsubscribed from topic: $topic');
  }

  /// Delete FCM token (on logout)
  Future<void> deleteToken() async {
    _appleTokenRetryTimer?.cancel();
    await _messaging.deleteToken();
    _fcmToken = null;
    debugPrint('FCM token deleted');
  }
}
