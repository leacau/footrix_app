import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/matches/fixture_screen.dart';
import '../../features/matches/match_detail_screen.dart';
import '../../features/rankings/leaderboard_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final auth = ref.watch(authProvider);
      final isLoggedIn = auth.value != null;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoggingIn) return '/login';
      if (isLoggedIn && isLoggingIn) return '/fixture';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/fixture', builder: (_, _) => const FixtureScreen()),
      GoRoute(
        path: '/match/:matchId',
        builder: (_, state) {
          final id = state.pathParameters['matchId']!;
          return MatchDetailScreen(matchId: id);
        },
      ),
      GoRoute(path: '/rankings', builder: (_, _) => const LeaderboardScreen()),
    ],
  );
});
