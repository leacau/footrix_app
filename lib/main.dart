import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/locale_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/notification_service.dart';
import 'features/updates/app_distribution_update_service.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  await NotificationService.handleBackgroundMessage(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase inicializado');
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
    debugPrint('Firebase ya estaba inicializado');
  } catch (e) {
    debugPrint('Error inicializando Firebase: $e');
  }

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  runApp(const ProviderScope(child: FootrixApp()));
  _configureNotifications();
  AppDistributionUpdateService.checkForTesterUpdateInBackground();
}

Future<void> _configureNotifications() async {
  try {
    await NotificationService.initialize(
      onTokenRefresh: (token) {
        debugPrint('FCM Token: $token');
      },
      onMessage: (message) {
        debugPrint('Mensaje en foreground: ${message.notification?.title}');
      },
    );
    debugPrint('FCM inicializado');
  } catch (e) {
    debugPrint('FCM no disponible: $e');
  }

  try {
    await NotificationService.requestPermissions();
  } catch (e) {
    debugPrint('No se pudieron pedir permisos de notificacion: $e');
  }
}

class FootrixApp extends ConsumerWidget {
  const FootrixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      routerConfig: router,
      title: 'Footrix',
      theme: AppTheme.light,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es'), Locale('en')],
      localeResolutionCallback: (locale, supported) {
        final target = locale ?? const Locale('es');
        for (final supportedLocale in supported) {
          if (supportedLocale.languageCode == target.languageCode) {
            return supportedLocale;
          }
        }
        return const Locale('es');
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
