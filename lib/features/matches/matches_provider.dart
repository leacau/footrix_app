import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/match_model.dart';
import 'models/prediction_model.dart';

final matchesProvider = StreamProvider<List<FootballMatch>>((ref) {
  final cutoff = DateTime.now().subtract(const Duration(days: 30));
  return FirebaseFirestore.instance
      .collection('matches')
      .where('kickoff', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
      .orderBy('kickoff', descending: false)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .where((doc) => doc.data()['apiSource'] == 'fifa')
            .map((doc) => FootballMatch.fromFirestore(doc))
            .toList(),
      );
});

final predictionForMatchProvider = StreamProvider.family<Prediction?, String>((
  ref,
  matchId,
) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('predictions')
      .where('userId', isEqualTo: uid)
      .where('matchId', isEqualTo: matchId)
      .limit(1)
      .snapshots()
      .map(
        (snap) => snap.docs.isEmpty
            ? null
            : Prediction.fromFirestore(snap.docs.first),
      );
});
