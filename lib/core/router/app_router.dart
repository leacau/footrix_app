import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/matches/fixture_screen.dart';
import '../../features/rankings/leaderboard_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/groups/group_invite_screen.dart';
import '../../features/groups/groups_screen.dart';
import '../../features/notifications/notification_handler.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/admin/admin_screen.dart';
import '../../features/worldcup/world_cup_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',

    // ✅ CORRECCIÓN: Usar ref.read() en lugar de ref.watch() dentro de redirect
    redirect: (context, state) {
      // 1. Verificar si hay una ruta pendiente de una notificación
      final pendingRoute = NotificationHandler.getPendingRoute();
      if (pendingRoute != null) {
        NotificationHandler.clearPendingRoute();
        return pendingRoute;
      }

      // 2. Lógica de auth normal
      // ✅ CORRECCIÓN: ref.read() en lugar de ref.watch() para evitar errores de Riverpod en callbacks
      final auth = ref.read(authProvider);

      // ✅ Caso loading: no redirigir
      if (auth is AsyncLoading) {
        return null;
      }

      final isLoggedIn = auth.value != null;
      final isLoggingIn = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/splash';
      final isJoiningGroup = state.matchedLocation.startsWith('/join/');
      final isHomeRoute =
          state.matchedLocation == '/home' || state.matchedLocation == '/';

      if (isSplash) return null;
      if (isJoiningGroup) return null;
      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }
      if (isLoggedIn && isLoggingIn) {
        return '/home';
      }
      if (isLoggedIn && isHomeRoute) return null;
      return null;
    },

    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/admin', builder: (_, _) => const AdminScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),

      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),

      GoRoute(
        path: '/fixture',
        builder: (_, state) => FixtureScreen(
          highlightedMatchId: state.uri.queryParameters['matchId'],
        ),
      ),
      GoRoute(path: '/rankings', builder: (_, _) => const LeaderboardScreen()),
      GoRoute(path: '/world-cup', builder: (_, _) => const WorldCupScreen()),
      GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
      GoRoute(path: '/groups', builder: (_, _) => const GroupsScreen()),
      GoRoute(
        path: '/join/:code',
        builder: (_, state) {
          final code = state.pathParameters['code']!;
          return GroupInviteScreen(code: code);
        },
      ),
    ],

    // ✅ Removido RouteObserver problemático
  );
});
