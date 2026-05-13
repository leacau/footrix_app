import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ranking_provider.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  RankingScope _scope = RankingScope.global;
  final _filterCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final rankingAsync = ref.watch(
      rankingProvider((scope: _scope, filter: _filterCtrl.text)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('🏆 Rankings')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<RankingScope>(
                    value: _scope,
                    isExpanded: true,
                    items: RankingScope.values
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.name.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _scope = v);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                if (_scope != RankingScope.global)
                  Expanded(
                    child: TextField(
                      controller: _filterCtrl,
                      decoration: InputDecoration(
                        hintText: 'Filtrar por ${_scope.name}',
                      ),
                      onSubmitted: (_) {
                        setState(() {});
                      },
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: rankingAsync.when(
              // ✅ CORRECCIÓN: parámetro nombrado 'data:'
              data: (users) {
                if (users.isEmpty) {
                  return const Center(
                    child: Text('📭 Sin datos para este filtro'),
                  );
                }
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (_, i) => ListTile(
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text(users[i]['displayName'] ?? 'Anónimo'),
                    subtitle: Text(
                      '${users[i]['city'] ?? ''}, ${users[i]['country'] ?? ''}',
                    ),
                    trailing: Text(
                      '${users[i]['totalPoints'] ?? 0} pts',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0052CC),
                      ),
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
