import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final createGroupProvider =
    FutureProvider.family<
      String,
      ({String name, List<String> leagueIds, bool isLeagueExclusive})
    >((ref, params) async {
      final functions = FirebaseFunctions.instance;
      final result = await functions.httpsCallable('createGroup').call({
        'name': params.name,
        'leagueIds': params.leagueIds,
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

class GroupPredictionEntry {
  final String displayName;
  final int homeGuess;
  final int awayGuess;

  const GroupPredictionEntry({
    required this.displayName,
    required this.homeGuess,
    required this.awayGuess,
  });

  factory GroupPredictionEntry.fromMap(Map<String, dynamic> data) {
    return GroupPredictionEntry(
      displayName: data['displayName'] as String? ?? 'Anónimo',
      homeGuess: data['homeGuess'] as int? ?? 0,
      awayGuess: data['awayGuess'] as int? ?? 0,
    );
  }
}

class GroupPredictionMatch {
  final String homeTeam;
  final String awayTeam;
  final DateTime? kickoff;
  final bool userHasPredicted;
  final int predictionCount;
  final List<GroupPredictionEntry> predictions;

  const GroupPredictionMatch({
    required this.homeTeam,
    required this.awayTeam,
    required this.kickoff,
    required this.userHasPredicted,
    required this.predictionCount,
    required this.predictions,
  });

  factory GroupPredictionMatch.fromMap(Map<String, dynamic> data) {
    final kickoffMillis = data['kickoffMillis'];
    final predictionItems = (data['predictions'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              GroupPredictionEntry.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();

    return GroupPredictionMatch(
      homeTeam: data['homeTeam'] as String? ?? 'Local',
      awayTeam: data['awayTeam'] as String? ?? 'Visitante',
      kickoff: kickoffMillis is int
          ? DateTime.fromMillisecondsSinceEpoch(kickoffMillis)
          : null,
      userHasPredicted: data['userHasPredicted'] == true,
      predictionCount:
          data['predictionCount'] as int? ?? predictionItems.length,
      predictions: predictionItems,
    );
  }
}

final groupPredictionsProvider =
    FutureProvider.family<List<GroupPredictionMatch>, String>((
      ref,
      groupId,
    ) async {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getGroupPredictions')
          .call({'groupId': groupId});
      final data = Map<String, dynamic>.from(result.data as Map);
      return (data['matches'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                GroupPredictionMatch.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList();
    });
