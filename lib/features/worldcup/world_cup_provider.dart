import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const worldCupLeagueId = 'copa-mundial-de-la-fifa';

class WorldCupMatch {
  final String id;
  final String homeTeam;
  final String awayTeam;
  final String? homeTeamId;
  final String? awayTeamId;
  final String? placeHolderA;
  final String? placeHolderB;
  final String stageName;
  final String groupName;
  final DateTime? kickoff;
  final int? matchNumber;
  final String status;
  final int? homeScore;
  final int? awayScore;

  const WorldCupMatch({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    this.homeTeamId,
    this.awayTeamId,
    this.placeHolderA,
    this.placeHolderB,
    required this.stageName,
    required this.groupName,
    this.kickoff,
    this.matchNumber,
    required this.status,
    this.homeScore,
    this.awayScore,
  });

  factory WorldCupMatch.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final kickoff = data['kickoff'] as Timestamp?;
    return WorldCupMatch(
      id: doc.id,
      homeTeam: data['homeTeam'] as String? ?? 'Por definir',
      awayTeam: data['awayTeam'] as String? ?? 'Por definir',
      homeTeamId: data['homeTeamId'] as String?,
      awayTeamId: data['awayTeamId'] as String?,
      placeHolderA: data['placeHolderA'] as String?,
      placeHolderB: data['placeHolderB'] as String?,
      stageName: data['stageName'] as String? ?? data['phase'] as String? ?? '',
      groupName: data['groupName'] as String? ?? '',
      kickoff: kickoff?.toDate(),
      matchNumber: data['matchNumber'] as int?,
      status: data['status'] as String? ?? 'scheduled',
      homeScore: data['homeScore'] as int?,
      awayScore: data['awayScore'] as int?,
    );
  }

  bool get isGroupStage => groupName.trim().isNotEmpty;

  String teamKey(bool home) {
    final id = home ? homeTeamId : awayTeamId;
    final name = home ? homeTeam : awayTeam;
    final placeholder = home ? placeHolderA : placeHolderB;
    if (id != null && id.trim().isNotEmpty) return 'team:${id.trim()}';
    if (name.trim().isNotEmpty && name != 'Por definir') {
      return 'name:${name.trim()}';
    }
    return 'slot:${placeholder ?? (home ? 'home:$id' : 'away:$id')}';
  }

  String teamName(bool home) {
    final name = home ? homeTeam : awayTeam;
    final placeholder = home ? placeHolderA : placeHolderB;
    if (name != 'Por definir') return name;
    return placeholder ?? name;
  }
}

class WorldCupPredictionDoc {
  final Map<String, WorldCupPredictionPick> picks;

  const WorldCupPredictionDoc({required this.picks});

  factory WorldCupPredictionDoc.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) return const WorldCupPredictionDoc(picks: {});
    final data = doc.data() as Map<String, dynamic>;
    final raw = data['matchPredictions'] as Map<String, dynamic>? ?? {};
    return WorldCupPredictionDoc(
      picks: raw.map((key, value) {
        final item = Map<String, dynamic>.from(value as Map);
        return MapEntry(key, WorldCupPredictionPick.fromMap(item));
      }),
    );
  }
}

class WorldCupPredictionPick {
  final int homeGuess;
  final int awayGuess;
  final String? winnerKey;

  const WorldCupPredictionPick({
    required this.homeGuess,
    required this.awayGuess,
    this.winnerKey,
  });

  factory WorldCupPredictionPick.fromMap(Map<String, dynamic> data) {
    return WorldCupPredictionPick(
      homeGuess: data['homeGuess'] as int? ?? 0,
      awayGuess: data['awayGuess'] as int? ?? 0,
      winnerKey: data['winnerKey'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'homeGuess': homeGuess,
    'awayGuess': awayGuess,
    if (winnerKey != null) 'winnerKey': winnerKey,
  };
}

final worldCupMatchesProvider = StreamProvider<List<WorldCupMatch>>((ref) {
  return FirebaseFirestore.instance
      .collection('matches')
      .where('leagueId', isEqualTo: worldCupLeagueId)
      .orderBy('kickoff')
      .snapshots()
      .map((snap) {
        final matches = snap.docs.map(WorldCupMatch.fromFirestore).toList();
        matches.sort((a, b) {
          final numberCompare = (a.matchNumber ?? 999).compareTo(
            b.matchNumber ?? 999,
          );
          if (numberCompare != 0) return numberCompare;
          return (a.kickoff ?? DateTime(2100)).compareTo(
            b.kickoff ?? DateTime(2100),
          );
        });
        return matches;
      });
});

final worldCupPredictionProvider = StreamProvider<WorldCupPredictionDoc>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const WorldCupPredictionDoc(picks: {}));
  return FirebaseFirestore.instance
      .collection('world_cup_predictions')
      .doc(uid)
      .snapshots()
      .map(WorldCupPredictionDoc.fromFirestore);
});

final worldCupScoresProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  return FirebaseFirestore.instance
      .collection('world_cup_scores')
      .snapshots()
      .map((snap) {
        final rows = snap.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
        rows.sort(_worldCupPointsSort);
        return rows;
      });
});

int _worldCupPointsSort(Map<String, dynamic> a, Map<String, dynamic> b) {
  final points = (b['totalPoints'] as int? ?? 0).compareTo(
    a['totalPoints'] as int? ?? 0,
  );
  if (points != 0) return points;
  return (a['predictionCount'] as int? ?? 0).compareTo(
    b['predictionCount'] as int? ?? 0,
  );
}

List<Map<String, dynamic>> sortedWorldCupScores(
  List<Map<String, dynamic>> rows,
  bool byAverage,
) {
  final copy = rows.map((row) => Map<String, dynamic>.from(row)).toList();
  copy.sort((a, b) {
    if (byAverage) {
      final average = (b['average'] as num? ?? 0).compareTo(
        a['average'] as num? ?? 0,
      );
      if (average != 0) return average;
    }
    return _worldCupPointsSort(a, b);
  });
  return copy;
}

final worldCupControllerProvider = Provider<WorldCupController>((ref) {
  return WorldCupController(FirebaseFunctions.instance);
});

class WorldCupController {
  final FirebaseFunctions _functions;

  const WorldCupController(this._functions);

  Future<int> save(Map<String, WorldCupPredictionPick> picks) async {
    final result = await _functions
        .httpsCallable('saveWorldCupPredictions')
        .call({
          'matchPredictions': picks.map(
            (key, value) => MapEntry(key, value.toMap()),
          ),
        });
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['predictionCount'] as int? ?? picks.length;
  }
}
