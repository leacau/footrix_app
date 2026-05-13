import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'matches_provider.dart';
import 'widgets/match_card.dart';

class FixtureScreen extends ConsumerWidget {
  const FixtureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Fixture')),
      body: matchesAsync.when(
        // ✅ CORRECCIÓN: parámetro nombrado 'data:' (NO positional, NO '')
        data: (matches) {
          if (matches.isEmpty) {
            return const Center(child: Text('📭 No hay partidos aún'));
          }
          return ListView.builder(
            itemCount: matches.length,
            itemBuilder: (_, i) => MatchCard(match: matches[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
