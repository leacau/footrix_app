import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final createGroupProvider =
    FutureProvider.family<
      void,
      ({String name, String? leagueId, bool isLeagueExclusive})
    >((ref, params) async {
      final functions = FirebaseFunctions.instance;
      await functions.httpsCallable('createGroup').call({
        'name': params.name,
        'leagueId': params.leagueId,
        'isLeagueExclusive': params.isLeagueExclusive,
      });
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
