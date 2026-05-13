import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'matches_provider.dart';
import 'widgets/prediction_form.dart';

class MatchDetailScreen extends ConsumerWidget {
  final String matchId;
  const MatchDetailScreen({super.key, required this.matchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchAsync = ref.watch(matchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle')),
      body: matchAsync.when(
        // ✅ CORRECCIÓN: parámetro nombrado 'data:'
        data: (matches) {
          final match = matches.firstWhere((m) => m.id == matchId);
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${match.homeTeam} vs ${match.awayTeam}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                PredictionForm(match: match),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
