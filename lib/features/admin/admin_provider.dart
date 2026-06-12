import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final adminUsersProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .orderBy('totalPoints', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});

final adminMatchesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final cutoff = DateTime.now().subtract(const Duration(days: 1));
  return FirebaseFirestore.instance
      .collection('matches')
      .where('kickoff', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
      .orderBy('kickoff', descending: false)
      .limit(250)
      .snapshots()
      .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});

final appConfigProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return FirebaseFirestore.instance.collection('app_config').snapshots().map((
    snap,
  ) {
    final data = <String, dynamic>{};
    for (final doc in snap.docs) {
      data[doc.id] = doc.data();
    }
    return data;
  });
});

class AdminController {
  final _functions = FirebaseFunctions.instance;

  Future<void> createMatch({
    required String homeTeam,
    required String awayTeam,
    required String phase,
    required DateTime kickoff,
    int lockHoursBefore = 12,
  }) async {
    await _functions.httpsCallable('adminCreateMatch').call({
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'phase': phase,
      'kickoffMillis': kickoff.millisecondsSinceEpoch,
      'lockHoursBefore': lockHoursBefore,
    });
  }

  Future<void> finishMatch(String matchId, int homeScore, int awayScore) async {
    await _functions.httpsCallable('adminFinishMatch').call({
      'matchId': matchId,
      'homeScore': homeScore,
      'awayScore': awayScore,
    });
  }

  Future<void> toggleUserStatus(String userId, bool isActive) async {
    await _functions.httpsCallable('adminToggleUserStatus').call({
      'userId': userId,
      'isActive': isActive,
    });
  }

  Future<Map<String, dynamic>> syncFifaFixturesNow() async {
    final result = await _functions.httpsCallable('syncFixturesNow').call();
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> syncAndRecalculateRecentPoints() async {
    final result = await _functions
        .httpsCallable('adminSyncAndRecalculateRecentPoints')
        .call();
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> repairUserDocuments() async {
    final result = await _functions
        .httpsCallable('adminRepairUserDocuments')
        .call();
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> updatePredictionSettings(int lockHoursBefore) async {
    await _functions.httpsCallable('adminUpdatePredictionSettings').call({
      'lockHoursBefore': lockHoursBefore,
    });
  }

  Future<List<Map<String, dynamic>>> listPredictions({
    String? userId,
    String? leagueId,
    String mode = 'all',
    DateTime? from,
    DateTime? to,
  }) async {
    final result = await _functions.httpsCallable('adminListPredictions').call({
      if (userId != null && userId.isNotEmpty) 'userId': userId,
      if (leagueId != null && leagueId.isNotEmpty) 'leagueId': leagueId,
      'mode': mode,
      if (from != null) 'fromMillis': from.millisecondsSinceEpoch,
      if (to != null) 'toMillis': to.millisecondsSinceEpoch,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return (data['rows'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<int> deletePredictions(List<String> ids) async {
    final result = await _functions
        .httpsCallable('adminDeletePredictions')
        .call({'ids': ids});
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['deleted'] as int? ?? 0;
  }

  Future<void> updatePrediction({
    required String id,
    required int homeGuess,
    required int awayGuess,
  }) async {
    await _functions.httpsCallable('adminUpdatePrediction').call({
      'id': id,
      'homeGuess': homeGuess,
      'awayGuess': awayGuess,
    });
  }

  Future<void> updateUserPoints({
    required String userId,
    required String mode,
    required String operation,
    required int value,
  }) async {
    await _functions.httpsCallable('adminUpdateUserPoints').call({
      'userId': userId,
      'mode': mode,
      'operation': operation,
      'value': value,
    });
  }

  Future<void> updatePredictionPermissions({
    required String userId,
    required bool blocked,
    required bool bypassLocks,
  }) async {
    await _functions.httpsCallable('adminUpdatePredictionPermissions').call({
      'userId': userId,
      'blocked': blocked,
      'bypassLocks': bypassLocks,
    });
  }
}

final adminControllerProvider = Provider<AdminController>(
  (ref) => AdminController(),
);
