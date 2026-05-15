import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  // ✅ Nuevos estados para filtros por liga y grupo
  String? _selectedLeagueId;
  String? _selectedGroupId;

  @override
  Widget build(BuildContext context) {
    // ✅ CORRECCIÓN: Pasar los 5 parámetros requeridos por rankingProvider
    final rankingAsync = ref.watch(
      rankingProvider((
        scope: _scope,
        filter: _filterCtrl.text.isEmpty ? null : _filterCtrl.text,
        type: _type,
        leagueId: _selectedLeagueId, // ✅ Nuevo parámetro
        groupId: _selectedGroupId, // ✅ Nuevo parámetro
      )),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏆 Rankings'),
        actions: [
          // ✅ Botón para resetear filtros
          if (_selectedLeagueId != null || _selectedGroupId != null)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Limpiar filtros',
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
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                // Filtro por Tipo de Ranking
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

                // Filtro por Liga
                Row(
                  children: [
                    const Text(
                      'Liga:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LeagueSelector(
                        selectedLeagueId: _selectedLeagueId,
                        onLeagueSelected: (leagueId) {
                          if (context.mounted) {
                            setState(() {
                              _selectedLeagueId = leagueId;
                              _selectedGroupId =
                                  null; // Resetear grupo al cambiar liga
                            });
                          }
                        },
                        showAllOption: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Filtro por Ubicación
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

          // Lista de usuarios
          Expanded(
            child: rankingAsync.when(
              // ✅ CORRECCIÓN: 'data:' explícito
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
                              ? '📭 Sin datos para esta liga'
                              : '📭 Sin usuarios para este filtro',
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
                            child: const Text('Limpiar filtros'),
                          ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (_, i) {
                    final user = users[i];
                    final points = _getPointsDisplay(
                      user,
                      _type,
                      _selectedLeagueId,
                    );

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: i < 3 ? Colors.amber : null,
                        child: Text('${i + 1}'),
                      ),
                      title: Text(user['displayName'] ?? 'Anónimo'),
                      subtitle: Text(
                        '${user['city'] ?? ''}, ${user['country'] ?? ''}'
                                .trim()
                                .isEmpty
                            ? 'Sin ubicación'
                            : '${user['city'] ?? ''}, ${user['country'] ?? ''}',
                      ),
                      trailing: Text(
                        '$points pts',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0052CC),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, StackTrace _) =>
                  Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ Helper: Obtener puntos según tipo y liga
  String _getPointsDisplay(
    Map<String, dynamic> user,
    RankingType type,
    String? leagueId,
  ) {
    // Si hay leagueId, usar stats específicos de esa liga
    if (leagueId != null) {
      final leagueStats = user['leagueStats'] as Map<String, dynamic>?;
      final leagueData = leagueStats?[leagueId];

      if (leagueData != null) {
        switch (type) {
          case RankingType.predictions:
            return '${leagueData['points'] as int? ?? 0}';
          case RankingType.trivia:
            return '${leagueData['triviaPoints'] as int? ?? 0}';
          case RankingType.combined:
            final pred = leagueData['points'] as int? ?? 0;
            final trivia = leagueData['triviaPoints'] as int? ?? 0;
            return '${pred + trivia}';
        }
      }
      // Si no tiene stats en esta liga, retornar 0
      return '0';
    }

    // Fallback a lógica global (sin filtro de liga)
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
