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
  RankingType _type = RankingType.predictions;
  final _filterCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final rankingAsync = ref.watch(
      rankingProvider((
        scope: _scope,
        filter: _filterCtrl.text.isEmpty ? null : _filterCtrl.text,
        type: _type,
      )),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('🏆 Rankings')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'Tipo:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<RankingType>(
                        value: _type,
                        isExpanded: true,
                        items: RankingType.values.map((t) {
                          final label = t == RankingType.predictions
                              ? 'Predicciones'
                              : t == RankingType.trivia
                              ? 'Trivia'
                              : 'Combinado';
                          return DropdownMenuItem(value: t, child: Text(label));
                        }).toList(),
                        onChanged: (value) {
                          if (value != null && context.mounted) {
                            setState(() => _type = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'Ubicación:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<RankingScope>(
                        value: _scope,
                        isExpanded: true,
                        items: RankingScope.values.map((s) {
                          final label = s == RankingScope.global
                              ? 'Mundial'
                              : s == RankingScope.country
                              ? 'País'
                              : s == RankingScope.province
                              ? 'Provincia'
                              : 'Ciudad';
                          return DropdownMenuItem(value: s, child: Text(label));
                        }).toList(),
                        onChanged: (value) {
                          if (value != null && context.mounted) {
                            setState(() => _scope = value);
                          }
                        },
                      ),
                    ),
                    if (_scope != RankingScope.global) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _filterCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Filtrar...',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                          ),
                          onSubmitted: (_) {
                            if (context.mounted) {
                              setState(() {});
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: rankingAsync.when(
              // ✅ CORRECCIÓN CLAVE: 'data:' debe estar ESCRITO explícitamente
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
                      '${_getPointsDisplay(users[i], _type)} pts',
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

  String _getPointsDisplay(Map<String, dynamic> user, RankingType type) {
    switch (type) {
      case RankingType.predictions:
        return '${user['totalPoints'] as int? ?? 0}';
      case RankingType.trivia:
        return '${user['triviaPoints'] as int? ?? 0}';
      case RankingType.combined:
        final pred = user['totalPoints'] as int? ?? 0;
        final trivia = user['triviaPoints'] as int? ?? 0;
        return '${pred + trivia}';
    }
  }
}
