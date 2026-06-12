import 'package:flutter/foundation.dart';

/// ✅ Maneja la navegación al tocar una notificación
class NotificationHandler {
  static String? _pendingRoute;

  /// ✅ Llamar cuando se toca una notificación
  static void handleNotificationTap(String? route) {
    if (route == null) return;

    debugPrint('🧭 Navegando desde notificación a: $route');

    // Si la app está en foreground, navegar inmediatamente
    // Si está en background/terminated, guardar para redirigir en el redirect del router
    _pendingRoute = _normalizeRoute(route);
  }

  /// ✅ Obtener y limpiar la ruta pendiente
  static String? getPendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  /// ✅ Limpiar manualmente (útil para tests)
  static void clearPendingRoute() {
    _pendingRoute = null;
  }

  /// ✅ Helpers para construir rutas de notificaciones
  static String routeForMatch(String matchId) => '/fixture?matchId=$matchId';
  static String routeForGroups() => '/groups';
  static String routeForFixture() => '/fixture';
  static String routeForRankings() => '/rankings';

  static String _normalizeRoute(String route) {
    if (route.startsWith('/match/')) {
      final matchId = route.substring('/match/'.length).split('?').first;
      return matchId.isEmpty ? '/fixture' : routeForMatch(matchId);
    }
    return route;
  }
}
