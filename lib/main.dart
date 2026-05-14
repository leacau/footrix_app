import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/notifications/notification_service.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// 🔥 Background message handler (para cuando la app está cerrada)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.handleBackgroundMessage(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Inicializar Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ✅ Configurar FCM (solo si no es web, o con manejo de errores en web)
  if (kIsWeb) {
    // Web: intentar con manejo de errores
    try {
      await NotificationService.initialize(
        onTokenRefresh: (token) {
          debugPrint('🔑 FCM Token: $token');
        },
        onMessage: (message) {
          debugPrint(
            '🔔 Mensaje en foreground: ${message.notification?.title}',
          );
        },
      );
      debugPrint('✅ FCM inicializado en web');
    } catch (e) {
      debugPrint('⚠️ FCM en web no disponible: $e');
      debugPrint(
        'ℹ️ Las notificaciones funcionarán en foreground pero no en background',
      );
    }
  } else {
    // Móvil: inicializar normalmente
    await NotificationService.initialize(
      onTokenRefresh: (token) {
        debugPrint('🔑 FCM Token: $token');
      },
      onMessage: (message) {
        debugPrint('🔔 Mensaje en foreground: ${message.notification?.title}');
      },
    );
  }

  // ✅ Registrar handler para background (solo móvil)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // ✅ Solicitar permisos
  await NotificationService.requestPermissions();

  runApp(const ProviderScope(child: FootrixApp()));
}

class FootrixApp extends ConsumerWidget {
  const FootrixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      routerConfig: router,
      title: 'Footrix',
      theme: AppTheme.light,

      // 🔥 Localización ES/EN
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es'), Locale('en')],
      localeResolutionCallback: (locale, supported) {
        final target = locale ?? const Locale('es');
        if (supported.contains(target)) {
          return target;
        }
        return const Locale('es');
      },

      debugShowCheckedModeBanner: false,
    );
  }
}
