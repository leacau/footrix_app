import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../matches/models/match_model.dart'; // ✅ Importar el modelo FootballMatch

final leaguesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('leagues')
      .where('active', isEqualTo: true)
      .orderBy('name')
      .snapshots()
      .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});

// ✅ CORRECCIÓN: Devolver List<FootballMatch> en lugar de List<Map>
final matchesByLeagueProvider =
    StreamProvider.family<List<FootballMatch>, String?>((ref, leagueId) {
      final cutoff = DateTime.now().subtract(const Duration(days: 2));
      Query query = FirebaseFirestore.instance
          .collection('matches')
          .where('kickoff', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff));

      if (leagueId != null && leagueId.isNotEmpty) {
        query = query.where('leagueId', isEqualTo: leagueId);
      }

      return query
          .orderBy('kickoff', descending: false)
          .snapshots()
          .map(
            (snap) => snap.docs
                .where((d) => d.exists)
                .map(
                  (d) => FootballMatch.fromFirestore(d),
                ) // ✅ Convertir a modelo fuerte
                .toList(),
          );
    });
