import 'package:firebase_auth/firebase_auth.dart';
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
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isCreator = group['createdBy'] == currentUserId;
    final leagueIds = group['leagueIds'] ?? group['leagueId'];
    final rankingAsync = ref.watch(
      rankingProvider((
        scope: RankingScope.global,
        type: RankingType.predictions,
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
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'leave') {
                  _confirmLeaveGroup(context, ref, groupId);
                } else if (value == 'delete') {
                  _confirmDeleteGroup(context, ref, groupId);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'leave',
                  child: Text('Salir del grupo'),
                ),
                if (isCreator)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Eliminar grupo'),
                  ),
              ],
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
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
                return DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const Material(
                        child: TabBar(
                          tabs: [
                            Tab(text: 'Puntaje'),
                            Tab(text: 'Promedio'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _GroupRankingList(
                              users: sortedRankingUsers(
                                users,
                                RankingMode.points,
                              ),
                              mode: RankingMode.points,
                              groupId: groupId,
                              canManageMembers: isCreator,
                              currentUserId: currentUserId,
                              ref: ref,
                            ),
                            _GroupRankingList(
                              users: sortedRankingUsers(
                                users,
                                RankingMode.average,
                              ),
                              mode: RankingMode.average,
                              groupId: groupId,
                              canManageMembers: isCreator,
                              currentUserId: currentUserId,
                              ref: ref,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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

  Future<void> _confirmLeaveGroup(
    BuildContext context,
    WidgetRef ref,
    String groupId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salir del grupo'),
        content: const Text(
          'Si sos el creador, el grupo pasará a estar a cargo de otro integrante.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(groupsControllerProvider).leaveGroup(groupId);
      ref.invalidate(userGroupsProvider);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _confirmDeleteGroup(
    BuildContext context,
    WidgetRef ref,
    String groupId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar grupo'),
        content: const Text('Esta acción elimina el grupo para todos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(groupsControllerProvider).deleteGroup(groupId);
      ref.invalidate(userGroupsProvider);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _GroupRankingList extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final RankingMode mode;
  final String groupId;
  final bool canManageMembers;
  final String? currentUserId;
  final WidgetRef ref;

  const _GroupRankingList({
    required this.users,
    required this.mode,
    required this.groupId,
    required this.canManageMembers,
    required this.currentUserId,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: users.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final user = users[i];
        final name = (user['displayName'] as String?)?.trim().isNotEmpty == true
            ? user['displayName'] as String
            : 'Anónimo';
        final points = user['rankingPoints'] as int? ?? 0;
        final predictions = user['predictionCount'] as int? ?? 0;
        final average = user['rankingAverage'] as double? ?? 0;
        return ListTile(
          leading: CircleAvatar(child: Text('${i + 1}')),
          title: Text(name),
          subtitle: Text('$predictions predicciones'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                mode == RankingMode.points
                    ? '$points pts'
                    : average.toStringAsFixed(2),
              ),
              if (canManageMembers && user['id'] != currentUserId)
                IconButton(
                  tooltip: 'Quitar participante',
                  icon: const Icon(Icons.person_remove_outlined),
                  onPressed: () =>
                      _confirmRemoveMember(context, user['id'] as String, name),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmRemoveMember(
    BuildContext context,
    String memberId,
    String memberName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar participante'),
        content: Text('¿Querés quitar a $memberName del grupo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(groupsControllerProvider)
          .removeMember(groupId: groupId, memberId: memberId);
      ref.invalidate(userGroupsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
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
