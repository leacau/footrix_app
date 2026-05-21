import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_handler.dart';

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  /// ✅ Inicializar FCM + listeners
  static Future<void> initialize({
    void Function(String)? onTokenRefresh,
    void Function(RemoteMessage)? onMessage,
  }) async {
    // 1. Configurar notificaciones locales (para foreground en móvil)
    if (!kIsWeb) {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      await _localNotifications.initialize(
        InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: (details) {
          NotificationHandler.handleNotificationTap(details.payload);
        },
      );
    }

    // 2. Token refresh listener
    if (onTokenRefresh != null) {
      _messaging.onTokenRefresh.listen((token) {
        onTokenRefresh(token);
        // ✅ Suscribirse al topic del usuario cuando el token cambia
        _subscribeToUserTopic();
      });
    }

    // 3. Foreground message listener
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('🔔 onMessage: ${message.notification?.title}');

      // Callback personalizado si se proveyó
      if (onMessage != null) {
        onMessage(message);
      }

      // Mostrar notificación local en foreground (solo móvil)
      if (!kIsWeb) {
        _showLocalNotification(message);
      }
    });

    // 4. Background/terminated message handler
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('🔔 onMessageOpenedApp: ${message.notification?.title}');
      NotificationHandler.handleNotificationTap(message.data['route']);
    });

    // 5. Get initial token (para registrar en backend si querés)
    try {
      final token = await _messaging.getToken(
        vapidKey: kIsWeb ? _getVapidKey() : null,
      );
      if (token != null) {
        if (onTokenRefresh != null) {
          onTokenRefresh(token);
        }
        // ✅ Suscribirse al topic del usuario
        await _subscribeToUserTopic();
        // ✅ Guardar token en Firestore
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
    }
  }

  /// ✅ Suscribirse al topic del usuario (user_{uid})
  static Future<void> _subscribeToUserTopic() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final topic = 'user_${user.uid}';
        await _messaging.subscribeToTopic(topic);
        debugPrint('✅ Suscribirse al topic: $topic');
      }
    } catch (e) {
      debugPrint('❌ Error subscribing to topic: $e');
    }
  }

  /// ✅ Guardar token en Firestore
  static Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('user_tokens')
            .doc(user.uid)
            .set({
              'token': token,
              'platform': kIsWeb ? 'web' : 'mobile',
              'updatedAt': FieldValue.serverTimestamp(),
            });
        debugPrint('✅ Token guardado en Firestore para user ${user.uid}');
      }
    } catch (e) {
      debugPrint('❌ Error saving token to Firestore: $e');
    }
  }

  /// ✅ Solicitar permisos de notificación
  static Future<void> requestPermissions() async {
    if (kIsWeb) {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
    } else {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: false,
        provisional: false,
      );
    }
  }

  /// ✅ Mostrar notificación local en foreground (móvil)
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final android = AndroidNotificationDetails(
      'footrix_channel',
      'Footrix Notifications',
      channelDescription: 'Notificaciones de partidos, puntos y grupos',
      importance: Importance.high,
      priority: Priority.high,
    );
    final ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = NotificationDetails(android: android, iOS: ios);

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data['route'],
    );
  }

  /// ✅ Obtener VAPID key para web
  static String _getVapidKey() {
    return const String.fromEnvironment(
      'VAPID_KEY',
      defaultValue:
          'BGkLmSGDziWtTHJebofHdQZ9B8TF-ZH2ugELJWxMwmS-X_p1BWuQ4Vz-_uTWEIwzbiUpB6fAoZvT1_Z8OZ7uAfg',
    );
  }

  /// ✅ Handler para mensajes en background
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('🔔 Background message: ${message.notification?.title}');
  }
}
