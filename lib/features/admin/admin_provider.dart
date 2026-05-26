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

  Future<void> updatePredictionSettings(int lockHoursBefore) async {
    await _functions.httpsCallable('adminUpdatePredictionSettings').call({
      'lockHoursBefore': lockHoursBefore,
    });
  }

  Future<void> updateTriviaSettings(int dailyQuestionLimit) async {
    await _functions.httpsCallable('adminUpdateTriviaSettings').call({
      'dailyQuestionLimit': dailyQuestionLimit,
    });
  }
}

final adminControllerProvider = Provider<AdminController>(
  (ref) => AdminController(),
);
