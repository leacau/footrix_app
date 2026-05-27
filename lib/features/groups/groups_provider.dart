import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../matches/models/prediction_model.dart';

final createGroupProvider =
    FutureProvider.family<
      String,
      ({String name, String? leagueId, bool isLeagueExclusive})
    >((ref, params) async {
      final functions = FirebaseFunctions.instance;
      final result = await functions.httpsCallable('createGroup').call({
        'name': params.name,
        'leagueId': params.leagueId,
        'isLeagueExclusive': params.isLeagueExclusive,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      return data['code'] as String? ?? '';
    });

final joinGroupProvider = FutureProvider.family<void, String>((
  ref,
  code,
) async {
  final functions = FirebaseFunctions.instance;
  await functions.httpsCallable('joinGroup').call({'code': code});
});

final userGroupsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('groups')
      .where('members', arrayContains: uid)
      .snapshots()
      .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});

// Proveedor para obtener las predicciones de los miembros del grupo
final groupPredictionsProvider = StreamProvider.family<List<Prediction>, String>((
  ref,
  groupId,
) {
  // 1. Primero obtenemos los IDs de los miembros del grupo
  return FirebaseFirestore.instance
      .collection('groups')
      .doc(groupId)
      .snapshots()
      .asyncExpand((groupDoc) {
        if (!groupDoc.exists) return Stream.value([]);

        final members = List<String>.from(groupDoc.data()?['members'] ?? []);
        if (members.isEmpty) return Stream.value([]);

        // 2. Buscamos predicciones cuyos userId estén en la lista de miembros
        // Nota: Firestore tiene un límite de 10 en 'whereIn', si el grupo es mayor
        // se recomienda filtrar por matchId o usar otra estrategia.
        return FirebaseFirestore.instance
            .collection('predictions')
            .where('userId', whereIn: members.take(10).toList())
            .snapshots()
            .map(
              (snap) => snap.docs
                  .map((doc) => Prediction.fromFirestore(doc))
                  .toList(),
            );
      });
});
