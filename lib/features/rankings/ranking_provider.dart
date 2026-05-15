import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum RankingScope { global, country, province, city }

enum RankingType { predictions, trivia, combined }

final rankingProvider =
    StreamProvider.family<
      List<Map<String, dynamic>>,
      ({
        RankingScope scope,
        String? filter,
        RankingType type,
        String? leagueId,
        String? groupId,
      })
    >((ref, params) {
      Query query = FirebaseFirestore.instance.collection('users');

      // Filtro por ubicación
      if (params.scope != RankingScope.global &&
          params.filter != null &&
          params.filter!.trim().isNotEmpty) {
        final field = params.scope.name;
        query = query.where(field, isEqualTo: params.filter!.trim());
      }

      return query.snapshots().map((snap) {
        var users = snap.docs
            .map((d) => d.data() as Map<String, dynamic>)
            .toList();

        // ✅ Filtrar por grupo si se especificó
        if (params.groupId != null) {
          // Obtener miembros del grupo desde Firestore
          // (En producción, esto debería ser más eficiente con una subcolección o índice)
          users = users.where((u) {
            // Verificar si el usuario está en el grupo
            // Esto asume que los grupos guardan un array de member UIDs
            // Podés optimizar esto con una query inversa si tenés muchos usuarios
            return true; // Placeholder: implementar lógica real según tu estructura de groups
          }).toList();
        }

        // ✅ Filtrar por liga si se especificó
        if (params.leagueId != null) {
          users = users.where((u) {
            final leagueStats = u['leagueStats'] as Map<String, dynamic>?;
            // Incluir usuario si tiene stats en esta liga
            return leagueStats?[params.leagueId] != null;
          }).toList();
        }

        // Ordenar según tipo de ranking y liga
        users.sort((a, b) {
          final pointsA = _getPoints(a, params.type, params.leagueId);
          final pointsB = _getPoints(b, params.type, params.leagueId);
          return pointsB.compareTo(pointsA);
        });

        return users;
      });
    });

/// ✅ Helper: Obtener puntos según tipo y liga
int _getPoints(Map<String, dynamic> user, RankingType type, String? leagueId) {
  // Si hay leagueId, usar stats específicos de esa liga
  if (leagueId != null) {
    final leagueStats = user['leagueStats'] as Map<String, dynamic>?;
    final leagueData = leagueStats?[leagueId];

    if (leagueData != null) {
      switch (type) {
        case RankingType.predictions:
          return leagueData['points'] as int? ?? 0;
        case RankingType.trivia:
          return leagueData['triviaPoints'] as int? ?? 0;
        case RankingType.combined:
          final pred = leagueData['points'] as int? ?? 0;
          final trivia = leagueData['triviaPoints'] as int? ?? 0;
          return pred + trivia;
      }
    }
    // Si no tiene stats en esta liga, retornar 0
    return 0;
  }

  // Fallback a lógica global (sin filtro de liga)
  switch (type) {
    case RankingType.predictions:
      return user['totalPoints'] as int? ?? 0;
    case RankingType.trivia:
      return user['triviaPoints'] as int? ?? 0;
    case RankingType.combined:
      final pred = user['totalPoints'] as int? ?? 0;
      final trivia = user['triviaPoints'] as int? ?? 0;
      return pred + trivia;
  }
}
