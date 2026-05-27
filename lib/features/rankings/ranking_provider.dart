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
        query = query.where(
          params.scope.name,
          isEqualTo: params.filter!.trim(),
        );
      }

      if (params.groupId != null) {
        return FirebaseFirestore.instance
            .collection('groups')
            .doc(params.groupId)
            .snapshots()
            .asyncMap((groupDoc) async {
              if (!groupDoc.exists) return <Map<String, dynamic>>[];
              final group = groupDoc.data() as Map<String, dynamic>;
              final members = List<String>.from(
                group['members'] as List? ?? [],
              );
              if (members.isEmpty) return <Map<String, dynamic>>[];

              final usersSnap = await query.get();
              var users = usersSnap.docs
                  .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
                  .where((u) => members.contains(u['id']))
                  .toList();
              final foundUserIds = users
                  .map((user) => user['id'])
                  .whereType<String>()
                  .toSet();
              for (final memberId in members) {
                if (!foundUserIds.contains(memberId)) {
                  users.add({
                    'id': memberId,
                    'displayName': 'Anónimo',
                    'totalPoints': 0,
                    'triviaPoints': 0,
                  });
                }
              }

              users = _applyLeagueFilter(
                users,
                params.leagueId,
                params.groupId != null,
              );
              _sortUsers(users, params.type, params.leagueId);
              _attachRankingPoints(users, params.type, params.leagueId);
              return users;
            });
      }

      return query.snapshots().map((snap) {
        var users = snap.docs
            .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
            .toList();

        users = _applyLeagueFilter(
          users,
          params.leagueId,
          params.groupId != null,
        );
        _sortUsers(users, params.type, params.leagueId);
        _attachRankingPoints(users, params.type, params.leagueId);
        return users;
      });
    });

List<Map<String, dynamic>> _applyLeagueFilter(
  List<Map<String, dynamic>> users,
  dynamic leagues, // Puede recibir String (antiguo) o List<dynamic> (nuevo)
  bool isGroupContext,
) {
  if (leagues == null || isGroupContext) return users;

  // Lógica global estricta (fuera de grupos)
  return users.where((u) {
    final leagueStats = u['leagueStats'] as Map<String, dynamic>?;
    if (leagues is List) {
      return leagues.any((lid) => leagueStats?[lid] != null);
    }
    return leagueStats?[leagues] != null;
  }).toList();
}

void _sortUsers(
  List<Map<String, dynamic>> users,
  RankingType type,
  dynamic leagues,
) {
  users.sort((a, b) {
    final pointsA = _getPoints(a, type, leagues);
    final pointsB = _getPoints(b, type, leagues);
    return pointsB.compareTo(pointsA);
  });
}

void _attachRankingPoints(
  List<Map<String, dynamic>> users,
  RankingType type,
  dynamic leagues,
) {
  for (final user in users) {
    user['rankingPoints'] = _getPoints(user, type, leagues);
  }
}

int _getPoints(Map<String, dynamic> user, RankingType type, dynamic leagues) {
  if (leagues != null) {
    final leagueStats = user['leagueStats'] as Map<String, dynamic>? ?? {};
    int total = 0;

    // Convertimos a lista para soportar múltiples ligas
    final leagueIds = leagues is List ? leagues : [leagues];

    for (var lid in leagueIds) {
      final leagueData = leagueStats[lid];
      if (leagueData != null) {
        if (type == RankingType.predictions || type == RankingType.combined) {
          total += (leagueData['points'] as int? ?? 0);
        }
        if (type == RankingType.trivia || type == RankingType.combined) {
          total += (leagueData['triviaPoints'] as int? ?? 0);
        }
      }
    }
    return total;
  }

  // Lógica global sin ligas
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
