import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ranking_provider.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingAsync = ref.watch(globalRankingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ranking')),
      body: rankingAsync.when(
        // ✅ CORRECCIÓN: parámetro nombrado 'data:'
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('Sin datos aún'));
          }
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (_, i) => ListTile(
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(users[i]['displayName'] ?? 'Anónimo'),
              trailing: Text('${users[i]['totalPoints'] ?? 0} pts'),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
