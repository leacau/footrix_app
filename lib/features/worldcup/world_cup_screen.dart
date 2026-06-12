import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../groups/groups_provider.dart';
import 'world_cup_provider.dart';

class WorldCupScreen extends ConsumerStatefulWidget {
  const WorldCupScreen({super.key});

  @override
  ConsumerState<WorldCupScreen> createState() => _WorldCupScreenState();
}

class _WorldCupScreenState extends ConsumerState<WorldCupScreen> {
  final Map<String, _DraftPick> _drafts = {};
  bool _hydrated = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(worldCupControllerProvider).refreshMyScore();
      } catch (_) {
        // The live score stream remains available if an explicit refresh fails.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final matchesAsync = ref.watch(worldCupMatchesProvider);
    final predictionAsync = ref.watch(worldCupPredictionProvider);
    final scoreData = ref.watch(currentWorldCupScoreProvider).valueOrNull ?? {};
    final matchBreakdown = Map<String, dynamic>.from(
      scoreData['matchBreakdown'] as Map? ?? {},
    );
    final permissions =
        ref.watch(currentPredictionPermissionsProvider).valueOrNull ?? const {};
    final blocked = permissions['blocked'] == true;
    final bypassLocks = permissions['bypassLocks'] == true;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mundial 2026'),
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Predicciones'),
              Tab(text: 'Grupos'),
              Tab(text: 'Eliminatorias'),
              Tab(text: 'Mundial real'),
              Tab(text: 'Ranking'),
            ],
          ),
        ),
        body: matchesAsync.when(
          data: (matches) {
            _hydrateOnce(predictionAsync.valueOrNull);
            final groupMatches = matches
                .where((match) => match.isGroupStage)
                .toList();
            final knockoutMatches = matches
                .where((match) => !match.isGroupStage)
                .toList();
            final bracket = _BracketSimulation(
              groupMatches,
              knockoutMatches,
              _drafts,
            );
            final savedPickIds =
                predictionAsync.valueOrNull?.picks.keys.toSet() ??
                const <String>{};
            return TabBarView(
              children: [
                _PredictionsTab(
                  matches: groupMatches,
                  drafts: _drafts,
                  saving: _saving,
                  blocked: blocked,
                  bypassLocks: bypassLocks,
                  onChanged: (matchId, draft) {
                    setState(() => _drafts[matchId] = draft);
                  },
                  onSaveMatch: _saveMatch,
                  matchBreakdown: matchBreakdown,
                  savedPickIds: savedPickIds,
                ),
                _GroupsStandingsTab(
                  standingsByGroup: bracket.groupStandings,
                  matchCount: groupMatches.length,
                ),
                _KnockoutTab(
                  matches: knockoutMatches,
                  bracket: bracket,
                  drafts: _drafts,
                  saving: _saving,
                  blocked: blocked,
                  bypassLocks: bypassLocks,
                  onChanged: (matchId, draft) {
                    setState(() => _drafts[matchId] = draft);
                  },
                  onSaveMatch: _saveMatch,
                  matchBreakdown: matchBreakdown,
                  savedPickIds: savedPickIds,
                ),
                _RealWorldCupTab(
                  groupMatches: groupMatches,
                  knockoutMatches: knockoutMatches,
                ),
                const _WorldCupRankingHub(),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }

  void _hydrateOnce(WorldCupPredictionDoc? doc) {
    if (_hydrated || doc == null) return;
    _hydrated = true;
    for (final entry in doc.picks.entries) {
      _drafts[entry.key] = _DraftPick(
        homeGuess: entry.value.homeGuess,
        awayGuess: entry.value.awayGuess,
        winnerKey: entry.value.winnerKey,
      );
    }
  }

  Future<void> _saveMatch(String matchId, _DraftPick draft) async {
    setState(() {
      _drafts[matchId] = draft;
      _saving = true;
    });
    try {
      final picks = _drafts.map(
        (key, value) => MapEntry(
          key,
          WorldCupPredictionPick(
            homeGuess: value.homeGuess ?? 0,
            awayGuess: value.awayGuess ?? 0,
            winnerKey: value.winnerKey,
          ),
        ),
      );
      await ref.read(worldCupControllerProvider).save(picks);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Prediccion guardada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _PredictionsTab extends StatelessWidget {
  final List<WorldCupMatch> matches;
  final Map<String, _DraftPick> drafts;
  final bool saving;
  final bool blocked;
  final bool bypassLocks;
  final void Function(String matchId, _DraftPick draft) onChanged;
  final Future<void> Function(String matchId, _DraftPick draft) onSaveMatch;
  final Map<String, dynamic> matchBreakdown;
  final Set<String> savedPickIds;

  const _PredictionsTab({
    required this.matches,
    required this.drafts,
    required this.saving,
    required this.blocked,
    required this.bypassLocks,
    required this.onChanged,
    required this.onSaveMatch,
    required this.matchBreakdown,
    required this.savedPickIds,
  });

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Todavia no hay partidos del Mundial sincronizados.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final firstKickoff = _firstKickoff(matches);
    final locked = blocked || (!bypassLocks && _isWorldCupLocked(matches));

    return Column(
      children: [
        _LockBanner(firstKickoff: firstKickoff, locked: locked),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            children: [
              for (final entry in _groupByGroup(matches).entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Text(
                    entry.key,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                for (final match in entry.value)
                  _WorldCupPredictionCard(
                    match: match,
                    homeName: match.teamName(true),
                    awayName: match.teamName(false),
                    homeKey: match.teamKey(true),
                    awayKey: match.teamKey(false),
                    draft: drafts[match.id],
                    locked: locked,
                    saving: saving,
                    allowWinnerSelector: false,
                    canViewOthers: savedPickIds.contains(match.id),
                    onChanged: (draft) => onChanged(match.id, draft),
                    onSave: (draft) => onSaveMatch(match.id, draft),
                    scoreBreakdown: matchBreakdown[match.id] as Map?,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Map<String, List<WorldCupMatch>> _groupByGroup(List<WorldCupMatch> matches) {
    final grouped = <String, List<WorldCupMatch>>{};
    for (final match in matches) {
      grouped.putIfAbsent(match.groupName, () => []).add(match);
    }
    return grouped;
  }
}

class _GroupsStandingsTab extends StatelessWidget {
  final Map<String, List<_StandingRow>> standingsByGroup;
  final int matchCount;

  const _GroupsStandingsTab({
    required this.standingsByGroup,
    required this.matchCount,
  });

  @override
  Widget build(BuildContext context) {
    if (standingsByGroup.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Cargá predicciones de la fase de grupos para ver las tablas.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final entries = standingsByGroup.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('Tablas simuladas', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final entry in entries)
          Card(
            child: ExpansionTile(
              initiallyExpanded: entry.key == 'Grupo A',
              title: Text(entry.key),
              children: [_StandingsTable(rows: entry.value)],
            ),
          ),
      ],
    );
  }
}

class _KnockoutTab extends StatelessWidget {
  final List<WorldCupMatch> matches;
  final _BracketSimulation bracket;
  final Map<String, _DraftPick> drafts;
  final bool saving;
  final bool blocked;
  final bool bypassLocks;
  final void Function(String matchId, _DraftPick draft) onChanged;
  final Future<void> Function(String matchId, _DraftPick draft) onSaveMatch;
  final Map<String, dynamic> matchBreakdown;
  final Set<String> savedPickIds;

  const _KnockoutTab({
    required this.matches,
    required this.bracket,
    required this.drafts,
    required this.saving,
    required this.blocked,
    required this.bypassLocks,
    required this.onChanged,
    required this.onSaveMatch,
    required this.matchBreakdown,
    required this.savedPickIds,
  });

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Todavia no hay cruces eliminatorios sincronizados.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final firstKickoff = _firstKickoff([...bracket.groupMatches, ...matches]);
    final locked =
        blocked ||
        (!bypassLocks &&
            _isWorldCupLocked([...bracket.groupMatches, ...matches]));
    final byStage = <String, List<WorldCupMatch>>{};
    for (final match in matches) {
      byStage.putIfAbsent(match.stageName, () => []).add(match);
    }
    final entries = byStage.entries.toList()
      ..sort((a, b) => (_stageOrder(a.key)).compareTo(_stageOrder(b.key)));

    return Column(
      children: [
        _LockBanner(firstKickoff: firstKickoff, locked: locked),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            children: [
              for (final entry in entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Text(
                    entry.key.isEmpty ? 'Eliminatorias' : entry.key,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                for (final match in entry.value)
                  _WorldCupPredictionCard(
                    match: match,
                    homeName: bracket.displayName(match, true),
                    awayName: bracket.displayName(match, false),
                    homeKey: bracket.resolvedKey(match, true),
                    awayKey: bracket.resolvedKey(match, false),
                    draft: drafts[match.id],
                    locked: locked,
                    saving: saving,
                    allowWinnerSelector: true,
                    canViewOthers: savedPickIds.contains(match.id),
                    onChanged: (draft) => onChanged(match.id, draft),
                    onSave: (draft) => onSaveMatch(match.id, draft),
                    scoreBreakdown: matchBreakdown[match.id] as Map?,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  int _stageOrder(String stage) {
    if (stage.contains('Dieciseisavos')) return 1;
    if (stage.contains('Octavos')) return 2;
    if (stage.contains('Cuartos')) return 3;
    if (stage.contains('Semifinal')) return 4;
    if (stage.contains('tercer')) return 5;
    if (stage.contains('Final')) return 6;
    return 99;
  }
}

class _RealWorldCupTab extends StatelessWidget {
  final List<WorldCupMatch> groupMatches;
  final List<WorldCupMatch> knockoutMatches;

  const _RealWorldCupTab({
    required this.groupMatches,
    required this.knockoutMatches,
  });

  @override
  Widget build(BuildContext context) {
    final actualDrafts = <String, _DraftPick>{};
    for (final match in [...groupMatches, ...knockoutMatches]) {
      if (match.status != 'finished' ||
          match.homeScore == null ||
          match.awayScore == null) {
        continue;
      }
      actualDrafts[match.id] = _DraftPick(
        homeGuess: match.homeScore,
        awayGuess: match.awayScore,
        winnerKey: _actualWinnerKey(match),
      );
    }
    final bracket = _BracketSimulation(
      groupMatches,
      knockoutMatches,
      actualDrafts,
    );
    final groupEntries = bracket.groupStandings.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final stages = <String, List<WorldCupMatch>>{};
    for (final match in knockoutMatches) {
      stages.putIfAbsent(match.stageName, () => []).add(match);
    }
    final stageEntries = stages.entries.toList()
      ..sort(
        (a, b) =>
            _worldCupStageOrder(a.key).compareTo(_worldCupStageOrder(b.key)),
      );

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 28),
      children: [
        Text(
          'Marcha real del Mundial',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Tablas y cruces según los resultados oficiales.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 16),
        Text('Fase de grupos', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        for (final entry in groupEntries)
          Card(
            child: ExpansionTile(
              initiallyExpanded: entry.key == 'Grupo A',
              title: Text(entry.key),
              children: [_StandingsTable(rows: entry.value)],
            ),
          ),
        const SizedBox(height: 18),
        Text('Eliminatorias', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        for (final entry in stageEntries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Text(
              entry.key.isEmpty ? 'Eliminatorias' : entry.key,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          for (final match in entry.value)
            _RealWorldCupMatchCard(
              match: match,
              homeName: bracket.displayName(match, true),
              awayName: bracket.displayName(match, false),
            ),
        ],
      ],
    );
  }

  String? _actualWinnerKey(WorldCupMatch match) {
    if (match.homeScore! > match.awayScore!) return match.teamKey(true);
    if (match.awayScore! > match.homeScore!) return match.teamKey(false);
    if (match.winnerTeamId?.trim().isNotEmpty == true) {
      return 'team:${match.winnerTeamId!.trim()}';
    }
    if (match.winnerTeamName?.trim().isNotEmpty == true) {
      return 'name:${match.winnerTeamName!.trim()}';
    }
    return null;
  }
}

class _RealWorldCupMatchCard extends StatelessWidget {
  final WorldCupMatch match;
  final String homeName;
  final String awayName;

  const _RealWorldCupMatchCard({
    required this.match,
    required this.homeName,
    required this.awayName,
  });

  @override
  Widget build(BuildContext context) {
    final hasResult = match.homeScore != null && match.awayScore != null;
    final center = hasResult
        ? '${match.homeScore} - ${match.awayScore}'
        : match.kickoff == null
        ? 'A confirmar'
        : DateFormat('d/M HH:mm').format(match.kickoff!.toLocal());
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                homeName,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              width: 92,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: hasResult ? Colors.green.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                center,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Text(
                awayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int _worldCupStageOrder(String stage) {
  final normalized = stage.toLowerCase();
  if (normalized.contains('dieciseis') || normalized.contains('round of 32')) {
    return 1;
  }
  if (normalized.contains('octav') || normalized.contains('round of 16')) {
    return 2;
  }
  if (normalized.contains('cuart') || normalized.contains('quarter')) return 3;
  if (normalized.contains('semi')) return 4;
  if (normalized.contains('tercer') || normalized.contains('third')) return 5;
  if (normalized.contains('final')) return 6;
  return 99;
}

class _LockBanner extends StatelessWidget {
  final DateTime? firstKickoff;
  final bool locked;

  const _LockBanner({required this.firstKickoff, required this.locked});

  @override
  Widget build(BuildContext context) {
    final text = firstKickoff == null
        ? 'Se cerrara cuando FIFA confirme el primer partido.'
        : locked
        ? 'Predicciones cerradas desde ${DateFormat('d/M HH:mm').format(firstKickoff!)}.'
        : 'Editable hasta ${DateFormat('d/M HH:mm').format(firstKickoff!)}.';
    return Material(
      color: locked ? Colors.red.shade50 : Colors.green.shade50,
      child: ListTile(
        dense: true,
        leading: Icon(
          locked ? Icons.lock : Icons.lock_open,
          color: locked ? Colors.red.shade700 : Colors.green.shade700,
        ),
        title: Text(text),
      ),
    );
  }
}

DateTime? _firstKickoff(List<WorldCupMatch> matches) {
  return matches
      .where((match) => match.kickoff != null)
      .map((match) => match.kickoff!)
      .fold<DateTime?>(null, (min, date) {
        if (min == null || date.isBefore(min)) return date;
        return min;
      });
}

bool _isWorldCupLocked(List<WorldCupMatch> matches) {
  final firstKickoff = _firstKickoff(matches);
  return firstKickoff != null && !DateTime.now().isBefore(firstKickoff);
}

class _WorldCupPredictionCard extends ConsumerStatefulWidget {
  final WorldCupMatch match;
  final String homeName;
  final String awayName;
  final String? homeKey;
  final String? awayKey;
  final _DraftPick? draft;
  final bool locked;
  final bool saving;
  final bool allowWinnerSelector;
  final bool canViewOthers;
  final ValueChanged<_DraftPick> onChanged;
  final ValueChanged<_DraftPick> onSave;
  final Map? scoreBreakdown;

  const _WorldCupPredictionCard({
    required this.match,
    required this.homeName,
    required this.awayName,
    required this.homeKey,
    required this.awayKey,
    required this.draft,
    required this.locked,
    required this.saving,
    required this.allowWinnerSelector,
    required this.canViewOthers,
    required this.onChanged,
    required this.onSave,
    this.scoreBreakdown,
  });

  @override
  ConsumerState<_WorldCupPredictionCard> createState() =>
      _WorldCupPredictionCardState();
}

class _WorldCupPredictionCardState
    extends ConsumerState<_WorldCupPredictionCard> {
  final _homeCtrl = TextEditingController();
  final _awayCtrl = TextEditingController();
  String? _winnerKey;
  bool _othersExpanded = false;
  bool _othersLoading = false;
  String? _othersError;
  List<Map<String, dynamic>>? _otherPredictions;

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  @override
  void didUpdateWidget(covariant _WorldCupPredictionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft != widget.draft ||
        oldWidget.homeName != widget.homeName ||
        oldWidget.awayName != widget.awayName) {
      _loadDraft();
    }
  }

  @override
  void dispose() {
    _homeCtrl.dispose();
    _awayCtrl.dispose();
    super.dispose();
  }

  void _loadDraft() {
    final draft = widget.draft;
    final home = draft?.homeGuess?.toString() ?? '';
    final away = draft?.awayGuess?.toString() ?? '';
    if (_homeCtrl.text != home) _homeCtrl.text = home;
    if (_awayCtrl.text != away) _awayCtrl.text = away;
    _winnerKey = draft?.winnerKey;
  }

  _DraftPick? _currentDraft() {
    final home = int.tryParse(_homeCtrl.text.trim());
    final away = int.tryParse(_awayCtrl.text.trim());
    if (home == null || away == null) return null;
    final isDraw = home == away;
    return _DraftPick(
      homeGuess: home,
      awayGuess: away,
      winnerKey: isDraw ? _winnerKey : null,
    );
  }

  void _notifyChanged() {
    final draft = _currentDraft();
    if (draft != null) widget.onChanged(draft);
  }

  Future<void> _toggleOtherPredictions() async {
    setState(() => _othersExpanded = !_othersExpanded);
    if (!_othersExpanded || _otherPredictions != null || _othersLoading) return;
    setState(() {
      _othersLoading = true;
      _othersError = null;
    });
    try {
      final rows = await ref
          .read(worldCupControllerProvider)
          .otherPredictions(widget.match.id);
      if (mounted) setState(() => _otherPredictions = rows);
    } catch (error) {
      if (mounted) {
        setState(() => _othersError = 'No se pudieron cargar las predicciones');
      }
    } finally {
      if (mounted) setState(() => _othersLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeGuess = int.tryParse(_homeCtrl.text.trim());
    final awayGuess = int.tryParse(_awayCtrl.text.trim());
    final isDraw =
        homeGuess != null && awayGuess != null && homeGuess == awayGuess;
    final canSave =
        !widget.locked &&
        !widget.saving &&
        homeGuess != null &&
        awayGuess != null &&
        (!widget.allowWinnerSelector ||
            !isDraw ||
            _winnerKey == widget.homeKey ||
            _winnerKey == widget.awayKey);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  widget.match.matchNumber == null
                      ? widget.match.stageName
                      : '#${widget.match.matchNumber}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const Spacer(),
                if (widget.locked)
                  const Icon(Icons.lock, size: 14, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: _teamName(widget.homeName, TextAlign.right)),
                const SizedBox(width: 10),
                _inputBox(_homeCtrl),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('-'),
                ),
                _inputBox(_awayCtrl),
                const SizedBox(width: 10),
                Expanded(child: _teamName(widget.awayName, TextAlign.left)),
                IconButton(
                  icon: widget.saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle, color: Colors.blue),
                  iconSize: 22,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 38,
                    height: 38,
                  ),
                  onPressed: canSave
                      ? () {
                          final draft = _currentDraft();
                          if (draft != null) widget.onSave(draft);
                        }
                      : null,
                ),
              ],
            ),
            if (widget.allowWinnerSelector &&
                isDraw &&
                widget.homeKey != null &&
                widget.awayKey != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text('Clasifica ${widget.homeName}'),
                    selected: _winnerKey == widget.homeKey,
                    onSelected: widget.locked
                        ? null
                        : (_) {
                            setState(() => _winnerKey = widget.homeKey);
                            _notifyChanged();
                          },
                  ),
                  ChoiceChip(
                    label: Text('Clasifica ${widget.awayName}'),
                    selected: _winnerKey == widget.awayKey,
                    onSelected: widget.locked
                        ? null
                        : (_) {
                            setState(() => _winnerKey = widget.awayKey);
                            _notifyChanged();
                          },
                  ),
                ],
              ),
            ],
            if (widget.match.kickoff != null) ...[
              const SizedBox(height: 6),
              Text(
                DateFormat(
                  'EEE d/M HH:mm',
                ).format(widget.match.kickoff!.toLocal()),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              ),
            ],
            if (widget.match.status == 'finished' && widget.draft != null) ...[
              const Divider(height: 18),
              _WorldCupResultSummary(
                match: widget.match,
                draft: widget.draft!,
                breakdown: widget.scoreBreakdown,
              ),
            ],
            if (widget.canViewOthers) ...[
              const Divider(height: 18),
              InkWell(
                onTap: _toggleOtherPredictions,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.people_outline, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Predicciones de otros usuarios'),
                      ),
                      Icon(
                        _othersExpanded ? Icons.expand_less : Icons.expand_more,
                      ),
                    ],
                  ),
                ),
              ),
              if (_othersExpanded) ...[
                const SizedBox(height: 8),
                if (_othersLoading)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (_othersError != null)
                  Text(
                    _othersError!,
                    style: TextStyle(color: Colors.red.shade700),
                  )
                else if (_otherPredictions?.isEmpty ?? true)
                  Text(
                    'Todavia no hay otras predicciones.',
                    style: TextStyle(color: Colors.grey.shade700),
                  )
                else
                  for (final prediction in _otherPredictions!)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              prediction['displayName'] as String? ?? 'Anonimo',
                            ),
                          ),
                          Text(
                            '${prediction['homeGuess']} - ${prediction['awayGuess']}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _teamName(String name, TextAlign align) {
    return Text(
      name,
      textAlign: align,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
  }

  Widget _inputBox(TextEditingController ctrl) {
    return SizedBox(
      width: 35,
      child: TextField(
        controller: ctrl,
        enabled: !widget.locked,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
        ),
        onChanged: (_) => _notifyChanged(),
      ),
    );
  }
}

class _WorldCupResultSummary extends StatelessWidget {
  final WorldCupMatch match;
  final _DraftPick draft;
  final Map? breakdown;

  const _WorldCupResultSummary({
    required this.match,
    required this.draft,
    required this.breakdown,
  });

  @override
  Widget build(BuildContext context) {
    final points = breakdown?['points'] as int?;
    final matchupCorrect = breakdown?['matchupCorrect'] as bool? ?? true;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: [
        Text(
          'Predicción: ${draft.homeGuess} - ${draft.awayGuess}',
          style: const TextStyle(fontSize: 12),
        ),
        Text(
          'Resultado: ${match.homeScore ?? '-'} - ${match.awayScore ?? '-'}',
          style: const TextStyle(fontSize: 12),
        ),
        Text(
          points == null ? 'Puntaje: recalculando' : 'Puntaje: $points pts',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: points == null
                ? Colors.grey.shade700
                : points > 0
                ? Colors.green.shade700
                : Colors.red.shade700,
          ),
        ),
        if (!matchupCorrect)
          const Text(
            'Cruce distinto al previsto',
            style: TextStyle(fontSize: 11, color: Colors.orange),
          ),
      ],
    );
  }
}

class _StandingsTable extends StatelessWidget {
  final List<_StandingRow> rows;

  const _StandingsTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(28),
          2: FixedColumnWidth(38),
          3: FixedColumnWidth(38),
          4: FixedColumnWidth(38),
        },
        children: [
          const TableRow(
            children: [
              Text('#'),
              Text('Equipo'),
              Text('Pts', textAlign: TextAlign.center),
              Text('DG', textAlign: TextAlign.center),
              Text('GF', textAlign: TextAlign.center),
            ],
          ),
          for (var i = 0; i < rows.length; i++)
            TableRow(
              children: [
                Text('${i + 1}'),
                Text(rows[i].name, overflow: TextOverflow.ellipsis),
                Text('${rows[i].points}', textAlign: TextAlign.center),
                Text('${rows[i].goalDifference}', textAlign: TextAlign.center),
                Text('${rows[i].goalsFor}', textAlign: TextAlign.center),
              ],
            ),
        ],
      ),
    );
  }
}

class _WorldCupRankingHub extends StatelessWidget {
  const _WorldCupRankingHub();

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            child: TabBar(
              tabs: [
                Tab(text: 'Global'),
                Tab(text: 'Mis grupos'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _WorldCupRankingTab(groupId: null),
                _WorldCupGroupRankingTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorldCupRankingTab extends ConsumerWidget {
  final String? groupId;

  const _WorldCupRankingTab({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoresAsync = ref.watch(worldCupScoresProvider);
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
            child: scoresAsync.when(
              data: (rows) => TabBarView(
                children: [
                  _ScoreList(rows: sortedWorldCupScores(rows, false)),
                  _ScoreList(
                    rows: sortedWorldCupScores(rows, true),
                    average: true,
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorldCupGroupRankingTab extends ConsumerStatefulWidget {
  const _WorldCupGroupRankingTab();

  @override
  ConsumerState<_WorldCupGroupRankingTab> createState() =>
      _WorldCupGroupRankingTabState();
}

class _WorldCupGroupRankingTabState
    extends ConsumerState<_WorldCupGroupRankingTab> {
  String? _selectedGroupId;

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(userGroupsProvider).valueOrNull ?? const [];
    final scores = ref.watch(worldCupScoresProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedGroupId,
            decoration: const InputDecoration(labelText: 'Grupo'),
            items: [
              for (final group in groups)
                DropdownMenuItem(
                  value: group['id'] as String,
                  child: Text(group['name'] as String? ?? 'Grupo'),
                ),
            ],
            onChanged: (value) => setState(() => _selectedGroupId = value),
          ),
        ),
        Expanded(
          child: scores.when(
            data: (rows) {
              final selected = groups
                  .where((group) => group['id'] == _selectedGroupId)
                  .cast<Map<String, dynamic>?>()
                  .firstOrNull;
              final members = selected == null
                  ? <String>{}
                  : Set<String>.from(selected['members'] as List? ?? const []);
              final filtered = _selectedGroupId == null
                  ? <Map<String, dynamic>>[]
                  : rows.where((row) => members.contains(row['id'])).toList();
              if (_selectedGroupId == null) {
                return const Center(child: Text('Elegí un grupo.'));
              }
              return _ScoreList(rows: sortedWorldCupScores(filtered, false));
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Error: $error')),
          ),
        ),
      ],
    );
  }
}

class _ScoreList extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final bool average;

  const _ScoreList({required this.rows, this.average = false});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(child: Text('Todavia no hay puntajes.'));
    }
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final points = row['totalPoints'] as int? ?? 0;
        final predictionCount = row['predictionCount'] as int? ?? 0;
        final avg = row['average'] as num? ?? 0;
        return ListTile(
          leading: CircleAvatar(child: Text('${index + 1}')),
          title: Text(row['displayName'] as String? ?? 'Anonimo'),
          subtitle: Text('$predictionCount predicciones'),
          trailing: Text(
            average ? avg.toStringAsFixed(2) : '$points pts',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }
}

class _BracketSimulation {
  final List<WorldCupMatch> groupMatches;
  final List<WorldCupMatch> knockoutMatches;
  final Map<String, _DraftPick> drafts;
  late final Map<String, List<_StandingRow>> groupStandings = _buildStandings();
  late final Map<String, _StandingRow> _resolved = _resolveInitialSlots();
  late final Map<int, String> _winners = {};
  late final Map<int, String> _runnersUp = {};

  _BracketSimulation(this.groupMatches, this.knockoutMatches, this.drafts) {
    _simulateKnockout();
  }

  String displayName(WorldCupMatch match, bool home) {
    final key = resolvedKey(match, home);
    if (key != null && _resolved[key] != null) return _resolved[key]!.name;
    return home
        ? match.placeHolderA ?? match.teamName(true)
        : match.placeHolderB ?? match.teamName(false);
  }

  String? resolvedKey(WorldCupMatch match, bool home) {
    final slot = home ? match.placeHolderA : match.placeHolderB;
    if (slot == null) return match.teamKey(home);
    if (_resolved[slot] != null) return slot;
    return _resolveWinnerSlot(slot);
  }

  Map<String, List<_StandingRow>> _buildStandings() {
    final grouped = <String, Map<String, _StandingRow>>{};
    for (final match in groupMatches) {
      final table = grouped.putIfAbsent(match.groupName, () => {});
      table.putIfAbsent(
        match.teamKey(true),
        () =>
            _StandingRow(key: match.teamKey(true), name: match.teamName(true)),
      );
      table.putIfAbsent(
        match.teamKey(false),
        () => _StandingRow(
          key: match.teamKey(false),
          name: match.teamName(false),
        ),
      );
      final draft = drafts[match.id];
      if (draft?.homeGuess == null || draft?.awayGuess == null) continue;
      table[match.teamKey(true)]!.apply(draft!.homeGuess!, draft.awayGuess!);
      table[match.teamKey(false)]!.apply(draft.awayGuess!, draft.homeGuess!);
    }
    return grouped.map((group, table) {
      final rows = table.values.toList()..sort(_standingSort);
      return MapEntry(group, rows);
    });
  }

  Map<String, _StandingRow> _resolveInitialSlots() {
    final resolved = <String, _StandingRow>{};
    final thirds = <_StandingRow>[];
    for (final entry in groupStandings.entries) {
      final letter = entry.key.replaceAll('Grupo ', '').trim();
      final rows = entry.value;
      if (rows.isNotEmpty) resolved['1$letter'] = rows[0];
      if (rows.length > 1) resolved['2$letter'] = rows[1];
      if (rows.length > 2) thirds.add(rows[2].copyWith(slotGroup: letter));
    }
    thirds.sort(_standingSort);
    final usedThirds = <String>{};
    for (final match in knockoutMatches) {
      for (final slot in [match.placeHolderA, match.placeHolderB]) {
        if (slot == null || !slot.startsWith('3')) continue;
        final allowed = slot.substring(1).split('');
        final selected = thirds.where((third) {
          return allowed.contains(third.slotGroup) &&
              !usedThirds.contains(third.key);
        }).firstOrNull;
        if (selected != null) {
          resolved[slot] = selected;
          usedThirds.add(selected.key);
        }
      }
    }
    return resolved;
  }

  void _simulateKnockout() {
    final sorted = [...knockoutMatches]
      ..sort((a, b) => (a.matchNumber ?? 0).compareTo(b.matchNumber ?? 0));
    for (final match in sorted) {
      final number = match.matchNumber;
      if (number == null) continue;
      final homeKey = resolvedKey(match, true);
      final awayKey = resolvedKey(match, false);
      final draft = drafts[match.id];
      if (homeKey == null || awayKey == null || draft == null) continue;
      String? winner;
      String? runnerUp;
      if (draft.homeGuess != null && draft.awayGuess != null) {
        if (draft.homeGuess! > draft.awayGuess!) {
          winner = homeKey;
          runnerUp = awayKey;
        } else if (draft.awayGuess! > draft.homeGuess!) {
          winner = awayKey;
          runnerUp = homeKey;
        } else if (draft.winnerKey == homeKey || draft.winnerKey == awayKey) {
          winner = draft.winnerKey;
          runnerUp = winner == homeKey ? awayKey : homeKey;
        }
      }
      if (winner != null) _winners[number] = winner;
      if (runnerUp != null) _runnersUp[number] = runnerUp;
    }
  }

  String? _resolveWinnerSlot(String slot) {
    final prefix = slot.startsWith('RU')
        ? 'RU'
        : slot.startsWith('W')
        ? 'W'
        : '';
    if (prefix.isEmpty) return null;
    final number = int.tryParse(slot.substring(prefix.length));
    if (number == null) return null;
    return prefix == 'W' ? _winners[number] : _runnersUp[number];
  }
}

int _standingSort(_StandingRow a, _StandingRow b) {
  final points = b.points.compareTo(a.points);
  if (points != 0) return points;
  final gd = b.goalDifference.compareTo(a.goalDifference);
  if (gd != 0) return gd;
  final gf = b.goalsFor.compareTo(a.goalsFor);
  if (gf != 0) return gf;
  return a.name.compareTo(b.name);
}

class _StandingRow {
  final String key;
  final String name;
  final String? slotGroup;
  int points;
  int goalsFor;
  int goalsAgainst;

  _StandingRow({
    required this.key,
    required this.name,
    this.slotGroup,
    this.points = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
  });

  int get goalDifference => goalsFor - goalsAgainst;

  void apply(int scored, int conceded) {
    goalsFor += scored;
    goalsAgainst += conceded;
    if (scored > conceded) {
      points += 3;
    } else if (scored == conceded) {
      points += 1;
    }
  }

  _StandingRow copyWith({String? slotGroup}) {
    return _StandingRow(
      key: key,
      name: name,
      slotGroup: slotGroup ?? this.slotGroup,
      points: points,
      goalsFor: goalsFor,
      goalsAgainst: goalsAgainst,
    );
  }
}

class _DraftPick {
  final int? homeGuess;
  final int? awayGuess;
  final String? winnerKey;

  const _DraftPick({this.homeGuess, this.awayGuess, this.winnerKey});

  _DraftPick copyWith({int? homeGuess, int? awayGuess, String? winnerKey}) {
    return _DraftPick(
      homeGuess: homeGuess ?? this.homeGuess,
      awayGuess: awayGuess ?? this.awayGuess,
      winnerKey: winnerKey ?? this.winnerKey,
    );
  }
}
