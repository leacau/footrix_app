import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final adminUsersProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .orderBy('totalPoints', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});

final adminMatchesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('matches')
      .orderBy('kickoff', descending: false)
      .snapshots()
      .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});

class AdminController {
  final _db = FirebaseFirestore.instance;

  // 1. Crear Partido
  Future<void> createMatch({
    required String homeTeam,
    required String awayTeam,
    required String phase,
    required DateTime kickoff,
    int lockHoursBefore = 12, // ✅ Nuevo parámetro con default 12
  }) async {
    await _db.collection('matches').add({
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'phase': phase,
      'kickoff': Timestamp.fromDate(kickoff),
      'status': 'scheduled',
      'homeScore': 0,
      'awayScore': 0,
      'lockHoursBefore': lockHoursBefore, // ✅ Guardar configuración
    });
  }

  // 2. Finalizar Partido (Cargar resultado)
  Future<void> finishMatch(String matchId, int homeScore, int awayScore) async {
    await _db.collection('matches').doc(matchId).update({
      'status': 'finished',
      'homeScore': homeScore,
      'awayScore': awayScore,
    });
  }

  // 3. Activar/Desactivar Usuario
  Future<void> toggleUserStatus(String userId, bool isActive) async {
    await _db.collection('users').doc(userId).update({'isActive': isActive});
  }
}

final adminControllerProvider = Provider<AdminController>(
  (ref) => AdminController(),
);
