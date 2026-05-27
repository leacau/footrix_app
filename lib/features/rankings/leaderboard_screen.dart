import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../leagues/widgets/league_selector.dart';
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
  String? _selectedLeagueId;
  String? _selectedGroupId;

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rankingAsync = ref.watch(
      rankingProvider((
        scope: _scope,
        filter: _filterCtrl.text.isEmpty ? null : _filterCtrl.text,
        type: _type,
        leagueId: _selectedLeagueId,
        groupId: _selectedGroupId,
      )),
    );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.rankingsTitle),
          actions: [
            if (_selectedLeagueId != null || _selectedGroupId != null)
              IconButton(
                icon: const Icon(Icons.clear_all),
                tooltip: l10n.clearFilters,
                onPressed: () {
                  if (context.mounted) {
                    setState(() {
                      _selectedLeagueId = null;
                      _selectedGroupId = null;
                    });
                  }
                },
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Puntaje'),
              Tab(text: 'Promedio'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        l10n.type,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<RankingType>(
                          value: _type,
                          isExpanded: true,
                          items: RankingType.values.map((t) {
                            final label = t == RankingType.predictions
                                ? l10n.predictions
                                : t == RankingType.trivia
                                ? l10n.trivia
                                : l10n.combined;
                            return DropdownMenuItem(
                              value: t,
                              child: Text(label),
                            );
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
                      Text(
                        '${l10n.league}:',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LeagueSelector(
                          selectedLeagueId: _selectedLeagueId,
                          onLeagueSelected: (leagueId) {
                            if (context.mounted) {
                              setState(() {
                                _selectedLeagueId = leagueId;
                                _selectedGroupId = null;
                              });
                            }
                          },
                          showAllOption: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${l10n.location}:',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<RankingScope>(
                          value: _scope,
                          isExpanded: true,
                          items: RankingScope.values.map((s) {
                            final label = s == RankingScope.global
                                ? l10n.worldwide
                                : s == RankingScope.country
                                ? l10n.country
                                : s == RankingScope.province
                                ? l10n.province
                                : l10n.city;
                            return DropdownMenuItem(
                              value: s,
                              child: Text(label),
                            );
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
                            decoration: InputDecoration(
                              hintText: l10n.filterHint,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            onSubmitted: (_) {
                              if (context.mounted) setState(() {});
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
                data: (List<Map<String, dynamic>> users) {
                  if (users.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.emoji_events,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _selectedLeagueId != null
                                ? l10n.noDataForLeague
                                : l10n.noUsersForFilter,
                            style: const TextStyle(fontSize: 16),
                          ),
                          if (_selectedLeagueId != null ||
                              _filterCtrl.text.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                if (context.mounted) {
                                  setState(() {
                                    _selectedLeagueId = null;
                                    _filterCtrl.clear();
                                  });
                                }
                              },
                              child: Text(l10n.clearFilters),
                            ),
                        ],
                      ),
                    );
                  }

                  return TabBarView(
                    children: [
                      _RankingList(
                        users: sortedRankingUsers(users, RankingMode.points),
                        mode: RankingMode.points,
                        l10n: l10n,
                        locationLabel: _locationLabel,
                      ),
                      _RankingList(
                        users: sortedRankingUsers(users, RankingMode.average),
                        mode: RankingMode.average,
                        l10n: l10n,
                        locationLabel: _locationLabel,
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object e, StackTrace _) =>
                    Center(child: Text('${l10n.error}: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _locationLabel(Map<String, dynamic> user, AppLocalizations l10n) {
    final city = user['city'] as String? ?? '';
    final country = user['country'] as String? ?? '';
    final label = '$city, $country'.trim();
    return label == ',' || label.isEmpty ? l10n.noLocation : label;
  }
}

class _RankingList extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final RankingMode mode;
  final AppLocalizations l10n;
  final String Function(Map<String, dynamic>, AppLocalizations) locationLabel;

  const _RankingList({
    required this.users,
    required this.mode,
    required this.l10n,
    required this.locationLabel,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (_, i) {
        final user = users[i];
        final points = user['rankingPoints'] as int? ?? 0;
        final predictions = user['predictionCount'] as int? ?? 0;
        final average = user['rankingAverage'] as double? ?? 0;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: i < 3 ? Colors.amber : null,
            child: Text('${i + 1}'),
          ),
          title: Text(user['displayName'] ?? l10n.anonymous),
          subtitle: Text(
            '${locationLabel(user, l10n)} · $predictions predicciones',
          ),
          trailing: Text(
            mode == RankingMode.points
                ? l10n.pointsSuffix(points)
                : average.toStringAsFixed(2),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF0052CC),
            ),
          ),
        );
      },
    );
  }
}
