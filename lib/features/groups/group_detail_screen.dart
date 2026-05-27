import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../rankings/ranking_provider.dart';
import 'groups_provider.dart';

class GroupDetailScreen extends ConsumerWidget {
  final Map<String, dynamic> group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupId = group['id'] as String;
    final leagueIds = group['leagueIds'] ?? group['leagueId'];
    final rankingAsync = ref.watch(
      rankingProvider((
        scope: RankingScope.global,
        type: RankingType.combined,
        groupId: groupId,
        filter: null,
        leagueId: leagueIds,
      )),
    );
    final predictionsAsync = ref.watch(groupPredictionsProvider(groupId));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(group['name'] as String? ?? 'Grupo'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Ranking'),
              Tab(text: 'Predicciones'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            rankingAsync.when(
              data: (users) {
                if (users.isEmpty) {
                  return const Center(
                    child: Text('Todavía no hay integrantes'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: users.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final user = users[i];
                    final name =
                        (user['displayName'] as String?)?.trim().isNotEmpty ==
                            true
                        ? user['displayName'] as String
                        : 'Anónimo';
                    final points = user['rankingPoints'] as int? ?? 0;
                    return ListTile(
                      leading: CircleAvatar(child: Text('${i + 1}')),
                      title: Text(name),
                      subtitle: Text(
                        i == 0 ? 'Puntero del grupo' : 'Integrante del grupo',
                      ),
                      trailing: Text('$points pts'),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
            predictionsAsync.when(
              data: (matches) {
                if (matches.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Todavía no hay predicciones para las ligas de este grupo.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(groupPredictionsProvider(groupId));
                    await ref.read(groupPredictionsProvider(groupId).future);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: matches.length,
                    itemBuilder: (context, index) =>
                        _PredictionMatchTile(match: matches[index]),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ],
        ),
      ),
    );
  }
}

class _PredictionMatchTile extends StatelessWidget {
  final GroupPredictionMatch match;

  const _PredictionMatchTile({required this.match});

  @override
  Widget build(BuildContext context) {
    final dateLabel = match.kickoff == null
        ? null
        : DateFormat('d/M HH:mm').format(match.kickoff!.toLocal());

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        leading: Icon(
          match.userHasPredicted ? Icons.visibility : Icons.lock_outline,
        ),
        title: Text('${match.homeTeam} vs ${match.awayTeam}'),
        subtitle: Text(
          match.userHasPredicted
              ? '${match.predictionCount} predicciones cargadas${dateLabel == null ? '' : ' · $dateLabel'}'
              : 'Cargá tu predicción para ver las de los demás',
        ),
        children: [
          if (match.userHasPredicted)
            ...match.predictions.map(
              (prediction) => ListTile(
                dense: true,
                title: Text(
                  '${prediction.displayName} puso ${prediction.homeGuess} a ${prediction.awayGuess}',
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Contenido bloqueado hasta que participes en este partido.',
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }
}
