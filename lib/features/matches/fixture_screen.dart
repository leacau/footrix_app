import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../leagues/leagues_provider.dart';
import '../leagues/widgets/league_selector.dart';
import 'models/match_model.dart';
import 'models/prediction_model.dart';
import 'widgets/match_card.dart';

class FixtureScreen extends ConsumerStatefulWidget {
  final String? highlightedMatchId;

  const FixtureScreen({super.key, this.highlightedMatchId});

  @override
  ConsumerState<FixtureScreen> createState() => _FixtureScreenState();
}

class _FixtureScreenState extends ConsumerState<FixtureScreen> {
  String? _selectedLeagueId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.fixture),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: l10n.moreOptions,
            onSelected: (value) {
              switch (value) {
                case 'home':
                  context.go('/home');
                  break;
                case 'groups':
                  context.push('/groups');
                  break;
                case 'profile':
                  context.push('/profile');
                  break;
                case 'rankings':
                  context.push('/rankings');
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'home',
                child: _MenuItem(icon: Icons.home, label: l10n.home),
              ),
              PopupMenuItem(
                value: 'groups',
                child: _MenuItem(icon: Icons.group, label: l10n.groups),
              ),
              PopupMenuItem(
                value: 'profile',
                child: _MenuItem(icon: Icons.person, label: l10n.profile),
              ),
              PopupMenuItem(
                value: 'rankings',
                child: _MenuItem(
                  icon: Icons.emoji_events,
                  label: l10n.rankings,
                ),
              ),
            ],
          ),
        ],
      ),
      body: _FixtureBody(
        highlightedMatchId: widget.highlightedMatchId,
        selectedLeagueId: _selectedLeagueId,
        onLeagueSelected: (leagueId) {
          setState(() => _selectedLeagueId = leagueId);
        },
      ),
    );
  }
}

class _FixtureBody extends StatelessWidget {
  final String? highlightedMatchId;
  final String? selectedLeagueId;
  final ValueChanged<String?> onLeagueSelected;

  const _FixtureBody({
    required this.highlightedMatchId,
    required this.selectedLeagueId,
    required this.onLeagueSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tabs = _buildTabs(l10n);
    final todayIndex = tabs.indexWhere((tab) => tab.label == l10n.today);

    return DefaultTabController(
      key: ValueKey(selectedLeagueId ?? 'user-leagues'),
      length: tabs.length,
      initialIndex: todayIndex,
      child: Column(
        children: [
          if (highlightedMatchId != null)
            _HighlightedMatch(matchId: highlightedMatchId!),
          const _FixturePointsSummary(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: LeagueSelector(
              selectedLeagueId: selectedLeagueId,
              onLeagueSelected: onLeagueSelected,
            ),
          ),
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Colors.grey.shade700,
              tabs: [for (final tab in tabs) Tab(text: tab.label)],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final tab in tabs)
                  _FixtureTabView(tab: tab, selectedLeagueId: selectedLeagueId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_FixtureTabData> _buildTabs(AppLocalizations l10n) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tabs = <_FixtureTabData>[
      _FixtureTabData(
        label: l10n.past,
        start: today.subtract(const Duration(days: 30)),
        end: today,
        emptyLabel: l10n.noPastMatches,
        descending: true,
      ),
      _FixtureTabData(
        label: l10n.today,
        start: today,
        end: today.add(const Duration(days: 1)),
        emptyLabel: l10n.noMatchesToday,
      ),
      _FixtureTabData(
        label: l10n.tomorrow,
        start: today.add(const Duration(days: 1)),
        end: today.add(const Duration(days: 2)),
        emptyLabel: l10n.noMatchesTomorrow,
      ),
    ];

    for (var offset = 2; offset <= 7; offset++) {
      final day = today.add(Duration(days: offset));
      tabs.add(
        _FixtureTabData(
          label: DateFormat('EEE d/M').format(day),
          start: day,
          end: day.add(const Duration(days: 1)),
          emptyLabel: l10n.noMatchesDate,
        ),
      );
    }

    tabs.add(
      _FixtureTabData(
        label: l10n.more,
        start: today.add(const Duration(days: 8)),
        end: today.add(const Duration(days: 91)),
        emptyLabel: l10n.noMoreMatches,
      ),
    );

    return tabs;
  }
}

class _HighlightedMatch extends StatelessWidget {
  final String matchId;

  const _HighlightedMatch({required this.matchId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LinearProgressIndicator(minHeight: 2);
        }
        final doc = snapshot.data!;
        if (!doc.exists) return const SizedBox.shrink();
        final match = FootballMatch.fromFirestore(doc);
        return ColoredBox(
          color: Theme.of(context).colorScheme.primaryContainer.withAlpha(80),
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Partido de la notificacion',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                _PredictionAwareMatchCard(match: match),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FixturePointsSummary extends ConsumerWidget {
  const _FixturePointsSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    final leagues = ref.watch(leaguesProvider).valueOrNull ?? const [];
    final leagueNames = {
      for (final league in leagues)
        league['id'] as String:
            league['shortName'] as String? ??
            league['name'] as String? ??
            league['id'] as String,
    };

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final globalPoints = data['totalPoints'] as int? ?? 0;
        final leagueStats = Map<String, dynamic>.from(
          data['leagueStats'] as Map? ?? const {},
        );
        final entries = leagueStats.entries.toList()
          ..sort(
            (a, b) => (leagueNames[a.key] ?? a.key).compareTo(
              leagueNames[b.key] ?? b.key,
            ),
          );

        return SizedBox(
          height: 76,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            scrollDirection: Axis.horizontal,
            children: [
              _FixturePointsItem(
                label: 'Puntaje global',
                points: globalPoints,
                emphasized: true,
              ),
              for (final entry in entries)
                _FixturePointsItem(
                  label: leagueNames[entry.key] ?? entry.key,
                  points: (entry.value as Map?)?['points'] as int? ?? 0,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FixturePointsItem extends StatelessWidget {
  final String label;
  final int points;
  final bool emphasized;

  const _FixturePointsItem({
    required this.label,
    required this.points,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: emphasized
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
          Text(
            '$points pts',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _FixtureTabView extends ConsumerWidget {
  final _FixtureTabData tab;
  final String? selectedLeagueId;

  const _FixtureTabView({required this.tab, required this.selectedLeagueId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final matchesAsync = ref.watch(
      fixtureMatchesProvider(
        FixtureMatchesQuery(
          selectedLeagueId: selectedLeagueId,
          start: tab.start,
          end: tab.end,
          descending: tab.descending,
        ),
      ),
    );

    return matchesAsync.when(
      data: (matches) => _FixtureMatchList(
        matches: matches,
        groupByLeague: selectedLeagueId == null,
        emptyLabel: tab.emptyLabel,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) {
        debugPrint('Firestore fixture error: $error');
        debugPrint('$stack');
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '${l10n.unableLoadFixture}\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        );
      },
    );
  }
}

class _FixtureMatchList extends StatelessWidget {
  final List<FootballMatch> matches;
  final bool groupByLeague;
  final String emptyLabel;

  const _FixtureMatchList({
    required this.matches,
    required this.groupByLeague,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyLabel,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
      );
    }

    final liveMatches = matches
        .where((match) => match.status == MatchStatus.live)
        .toList();
    final otherMatches = matches
        .where((match) => match.status != MatchStatus.live)
        .toList();
    final sections = groupByLeague
        ? _groupByLeague(otherMatches)
        : {'': otherMatches};
    final children = <Widget>[];

    if (liveMatches.isNotEmpty) {
      children.add(const _LiveHeader());
      for (final match in liveMatches) {
        children.add(_PredictionAwareMatchCard(match: match));
      }
      children.add(const SizedBox(height: 8));
    }

    for (final entry in sections.entries) {
      if (groupByLeague) {
        children.add(_LeagueHeader(match: entry.value.first));
      }
      for (final match in entry.value) {
        children.add(_PredictionAwareMatchCard(match: match));
      }
      children.add(const SizedBox(height: 8));
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: children,
    );
  }

  Map<String, List<FootballMatch>> _groupByLeague(List<FootballMatch> matches) {
    final groups = <String, List<FootballMatch>>{};
    for (final match in matches) {
      final key = match.competitionName ?? match.leagueId ?? '';
      groups.putIfAbsent(key, () => []).add(match);
    }

    final ordered = groups.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return {for (final entry in ordered) entry.key: entry.value};
  }
}

class _LiveHeader extends StatelessWidget {
  const _LiveHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: Colors.red.shade600),
          const SizedBox(width: 8),
          Text(
            l10n.live,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.red.shade700,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionAwareMatchCard extends StatelessWidget {
  final FootballMatch match;

  const _PredictionAwareMatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<DocumentSnapshot>(
      key: ValueKey('pred_${match.id}_${user?.uid}'),
      stream: user != null
          ? FirebaseFirestore.instance
                .collection('predictions')
                .doc('${user.uid}_${match.id}')
                .snapshots()
          : null,
      builder: (context, snapshot) {
        Prediction? pred;
        if (snapshot.hasData && snapshot.data!.exists) {
          pred = Prediction.fromFirestore(snapshot.data!);
        }
        return MatchCard(match: match, existingPrediction: pred);
      },
    );
  }
}

class _LeagueHeader extends StatelessWidget {
  final FootballMatch match;

  const _LeagueHeader({required this.match});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name =
        match.competitionName ??
        (match.leagueId?.isNotEmpty == true
            ? match.leagueId!
            : l10n.otherTournaments);
    final emblem = match.competitionEmblem;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: emblem != null && emblem.isNotEmpty
                ? Image.network(
                    emblem,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.emoji_events_outlined, size: 20),
                  )
                : const Icon(Icons.emoji_events_outlined, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [Icon(icon), const SizedBox(width: 8), Text(label)]);
  }
}

class _FixtureTabData {
  final String label;
  final DateTime start;
  final DateTime end;
  final String emptyLabel;
  final bool descending;

  const _FixtureTabData({
    required this.label,
    required this.start,
    required this.end,
    required this.emptyLabel,
    this.descending = false,
  });
}
