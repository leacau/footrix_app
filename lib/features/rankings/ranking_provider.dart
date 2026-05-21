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

      if (params.scope != RankingScope.global &&
          params.filter != null &&
          params.filter!.trim().isNotEmpty) {
        query = query.where(params.scope.name, isEqualTo: params.filter!.trim());
      }

      if (params.groupId != null) {
        return FirebaseFirestore.instance
            .collection('groups')
            .doc(params.groupId)
            .snapshots()
            .asyncMap((groupDoc) async {
              if (!groupDoc.exists) return <Map<String, dynamic>>[];
              final group = groupDoc.data() as Map<String, dynamic>;
              final members = List<String>.from(group['members'] as List? ?? []);
              if (members.isEmpty) return <Map<String, dynamic>>[];

              final usersSnap = await query.get();
              var users = usersSnap.docs
                  .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
                  .where((u) => members.contains(u['id']))
                  .toList();

              users = _applyLeagueFilter(users, params.leagueId);
              _sortUsers(users, params.type, params.leagueId);
              return users;
            });
      }

      return query.snapshots().map((snap) {
        var users = snap.docs
            .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
            .toList();

        users = _applyLeagueFilter(users, params.leagueId);
        _sortUsers(users, params.type, params.leagueId);
        return users;
      });
    });

List<Map<String, dynamic>> _applyLeagueFilter(
  List<Map<String, dynamic>> users,
  String? leagueId,
) {
  if (leagueId == null) return users;
  return users.where((u) {
    final leagueStats = u['leagueStats'] as Map<String, dynamic>?;
    return leagueStats?[leagueId] != null;
  }).toList();
}

void _sortUsers(
  List<Map<String, dynamic>> users,
  RankingType type,
  String? leagueId,
) {
  users.sort((a, b) {
    final pointsA = _getPoints(a, type, leagueId);
    final pointsB = _getPoints(b, type, leagueId);
    return pointsB.compareTo(pointsA);
  });
}

int _getPoints(Map<String, dynamic> user, RankingType type, String? leagueId) {
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
    return 0;
  }

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
