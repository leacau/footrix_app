import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_handler.dart';

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static StreamSubscription<String>? _tokenRefreshSub;
  static StreamSubscription<User?>? _authSub;

  static Future<void> initialize({
    void Function(String)? onTokenRefresh,
    void Function(RemoteMessage)? onMessage,
  }) async {
    if (!kIsWeb) {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      await _localNotifications.initialize(
        const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: (details) {
          NotificationHandler.handleNotificationTap(details.payload);
        },
      );
      await _createAndroidNotificationChannel();
    }

    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) async {
      onTokenRefresh?.call(token);
      await _registerTokenForCurrentUser(token);
    });

    await _authSub?.cancel();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) return;
      try {
        final token = await _messaging.getToken(
          vapidKey: kIsWeb ? _getVapidKey() : null,
        );
        if (token != null) {
          await _registerTokenForCurrentUser(token);
        }
      } catch (e) {
        debugPrint('Error registering FCM token after login: $e');
      }
    });

    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('onMessage: ${message.notification?.title}');
      onMessage?.call(message);
      if (!kIsWeb) {
        _showLocalNotification(message);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('onMessageOpenedApp: ${message.notification?.title}');
      NotificationHandler.handleNotificationTap(message.data['route']);
    });

    try {
      final token = await _messaging.getToken(
        vapidKey: kIsWeb ? _getVapidKey() : null,
      );
      if (token != null) {
        onTokenRefresh?.call(token);
        await _registerTokenForCurrentUser(token);
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  static Future<void> _createAndroidNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      'footrix_channel',
      'Footrix Notifications',
      description: 'Notificaciones de partidos, puntos y grupos',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  static Future<void> _registerTokenForCurrentUser(String token) async {
    await _subscribeToUserTopic();
    await _saveTokenToFirestore(token);
  }

  static Future<void> _subscribeToUserTopic() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final topic = 'user_${user.uid}';
      await _messaging.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic: $e');
    }
  }

  static Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final tokenId = base64Url.encode(utf8.encode(token));
      final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
      final userTokenDoc = FirebaseFirestore.instance
          .collection('user_tokens')
          .doc(user.uid);

      await userTokenDoc.set({
        'token': token,
        'platform': platform,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await userTokenDoc.collection('tokens').doc(tokenId).set({
        'token': token,
        'platform': platform,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('Token saved in Firestore for user ${user.uid}');
    } catch (e) {
      debugPrint('Error saving token to Firestore: $e');
    }
  }

  static Future<void> requestPermissions() async {
    if (kIsWeb) {
      return;
    }

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: false,
      provisional: false,
    );
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const android = AndroidNotificationDetails(
      'footrix_channel',
      'Footrix Notifications',
      channelDescription: 'Notificaciones de partidos, puntos y grupos',
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: android, iOS: ios);

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data['route'],
    );
  }

  static String _getVapidKey() {
    return const String.fromEnvironment(
      'VAPID_KEY',
      defaultValue:
          'BGkLmSGDziWtTHJebofHdQZ9B8TF-ZH2ugELJWxMwmS-X_p1BWuQ4Vz-_uTWEIwzbiUpB6fAoZvT1_Z8OZ7uAfg',
    );
  }

  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('Background message: ${message.notification?.title}');
  }
}
