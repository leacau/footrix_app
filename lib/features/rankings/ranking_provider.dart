import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum RankingScope { global, country, province, city }

enum RankingType { predictions, trivia, combined }

final rankingProvider =
    StreamProvider.family<
      List<Map<String, dynamic>>,
      ({RankingScope scope, String? filter, RankingType type})
    >((ref, params) {
      Query query = FirebaseFirestore.instance.collection('users');

      // Filtro por ubicación
      if (params.scope != RankingScope.global &&
          params.filter != null &&
          params.filter!.trim().isNotEmpty) {
        final field = params.scope.name;
        query = query.where(field, isEqualTo: params.filter!.trim());
      }

      // Ordenamiento en cliente según el tipo de ranking
      return query.snapshots().map((snap) {
        final users = snap.docs
            .map((d) => d.data() as Map<String, dynamic>)
            .toList();

        users.sort((a, b) {
          // ✅ CORRECCIÓN: Seleccionar campo según tipo de ranking
          final pointsA = _getPoints(a, params.type);
          final pointsB = _getPoints(b, params.type);
          return pointsB.compareTo(pointsA); // Descendente
        });

        return users;
      });
    });

/// ✅ Helper: Obtener puntos según el tipo de ranking
int _getPoints(Map<String, dynamic> user, RankingType type) {
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
