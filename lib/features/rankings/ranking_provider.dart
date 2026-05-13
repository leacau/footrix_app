import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum RankingScope { global, country, province, city }

final rankingProvider =
    StreamProvider.family<
      List<Map<String, dynamic>>,
      ({RankingScope scope, String? filter})
    >((ref, params) {
      Query query = FirebaseFirestore.instance.collection('users');

      if (params.scope != RankingScope.global &&
          params.filter != null &&
          params.filter!.trim().isNotEmpty) {
        final field = params.scope.name; // country, province, city
        query = query.where(field, isEqualTo: params.filter!.trim());
      }

      // Ordenamiento en cliente para evitar errores de índices compuestos en Firestore
      return query.snapshots().map((snap) {
        final users = snap.docs
            .map((d) => d.data() as Map<String, dynamic>)
            .toList();
        users.sort(
          (a, b) => (b['totalPoints'] as int? ?? 0).compareTo(
            a['totalPoints'] as int? ?? 0,
          ),
        );
        return users;
      });
    });
