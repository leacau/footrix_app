import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final globalRankingProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .orderBy('totalPoints', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => doc.data()).toList());
});
