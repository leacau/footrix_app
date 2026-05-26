import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../matches/models/match_model.dart';

final leaguesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('leagues')
      .where('active', isEqualTo: true)
      .orderBy('name')
      .snapshots()
      .map(
        (snap) => snap.docs
            .where((d) => d.data()['apiSource'] == 'fifa')
            .map((d) => {'id': d.id, ...d.data()})
            .toList(),
      );
});

final userSelectedLeagueIdsProvider = StreamProvider<List<String>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const []);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map(
        (doc) =>
            (doc.data()?['selectedLeagueIds'] as List<dynamic>? ?? const [])
                .whereType<String>()
                .toList(),
      );
});

class FixtureMatchesQuery {
  final String? selectedLeagueId;
  final DateTime start;
  final DateTime end;

  const FixtureMatchesQuery({
    required this.selectedLeagueId,
    required this.start,
    required this.end,
  });

  @override
  bool operator ==(Object other) {
    return other is FixtureMatchesQuery &&
        other.selectedLeagueId == selectedLeagueId &&
        other.start == start &&
        other.end == end;
  }

  @override
  int get hashCode => Object.hash(selectedLeagueId, start, end);
}

final fixtureMatchesProvider =
    StreamProvider.family<List<FootballMatch>, FixtureMatchesQuery>((
      ref,
      params,
    ) {
      final userLeagueIds =
          ref.watch(userSelectedLeagueIdsProvider).asData?.value ?? const [];
      final selectedLeagueId = params.selectedLeagueId;
      final requestedLeagueIds = selectedLeagueId != null
          ? [selectedLeagueId]
          : userLeagueIds;

      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('matches')
          .where(
            'kickoff',
            isGreaterThanOrEqualTo: Timestamp.fromDate(params.start),
          )
          .where('kickoff', isLessThan: Timestamp.fromDate(params.end))
          .orderBy('kickoff', descending: false);

      if (requestedLeagueIds.length == 1) {
        query = query.where('leagueId', isEqualTo: requestedLeagueIds.first);
      } else if (requestedLeagueIds.length > 1 &&
          requestedLeagueIds.length <= 10) {
        query = query.where('leagueId', whereIn: requestedLeagueIds);
      }

      return query.snapshots().map((snap) {
        final matches = snap.docs
            .where((d) => d.data()['apiSource'] == 'fifa')
            .map((d) => FootballMatch.fromFirestore(d))
            .where((match) {
              if (requestedLeagueIds.isEmpty ||
                  requestedLeagueIds.length <= 10) {
                return true;
              }
              return match.leagueId != null &&
                  requestedLeagueIds.contains(match.leagueId);
            })
            .toList();

        matches.sort((a, b) {
          final aKickoff = a.kickoff ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bKickoff = b.kickoff ?? DateTime.fromMillisecondsSinceEpoch(0);
          return aKickoff.compareTo(bKickoff);
        });
        return matches;
      });
    });
