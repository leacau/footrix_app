import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'matches_provider.dart';
import 'models/prediction_model.dart';
import 'widgets/match_card.dart';

class FixtureScreen extends ConsumerWidget {
  const FixtureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesProvider);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fixture'),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events),
            onPressed: () => Navigator.pushNamed(context, '/rankings'),
          ),
        ],
      ),
      body: matchesAsync.when(
        // ✅ CORRECCIÓN: parámetro nombrado 'data:' (NO positional)
        data: (matches) {
          if (matches.isEmpty) {
            return const Center(child: Text('📭 Cargando partidos...'));
          }

          return ListView.builder(
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final match = matches[index];

              return StreamBuilder<DocumentSnapshot>(
                stream: user != null
                    ? FirebaseFirestore.instance
                          .collection('predictions')
                          .doc('${user.uid}_${match.id}')
                          .snapshots()
                    : null,
                builder: (context, snapshot) {
                  Prediction? pred;
                  if (snapshot.hasData && snapshot.data!.exists) {
                    pred = Prediction.fromFirestore(snapshot.data!);
                  }
                  return MatchCard(match: match, existingPrediction: pred);
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
