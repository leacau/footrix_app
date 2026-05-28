import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../auth/auth_provider.dart';
import 'admin_provider.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _homeCtrl = TextEditingController();
  final _awayCtrl = TextEditingController();
  final _phaseCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _predictionLockCtrl = TextEditingController();
  final _triviaLimitCtrl = TextEditingController();
  int _lockHours = 12;
  bool _syncingFifa = false;
  bool _savingSettings = false;
  bool _recalculatingPoints = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _homeCtrl.dispose();
    _awayCtrl.dispose();
    _phaseCtrl.dispose();
    _dateCtrl.dispose();
    _predictionLockCtrl.dispose();
    _triviaLimitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAdminAsync = ref.watch(isAdminProvider);

    if (isAdminAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (isAdminAsync.valueOrNull != true) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.adminPanel)),
        body: Center(child: Text(l10n.noAdminPermission)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminPanel),
        actions: [
          IconButton(
            tooltip: l10n.syncFifa,
            icon: _syncingFifa
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            onPressed: _syncingFifa ? null : _syncFifaFixtures,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.users),
            Tab(text: l10n.createMatch),
            Tab(text: l10n.finish),
            Tab(text: l10n.settings),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const _AdminUsersTab(),
          _buildCreateMatchTab(l10n),
          _AdminFinishTab(onFinish: _showFinishDialog),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  Future<void> _syncFifaFixtures() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _syncingFifa = true);
    try {
      final result = await ref
          .read(adminControllerProvider)
          .syncFifaFixturesNow();
      final matches = result['matchesSynced'] as int? ?? 0;
      final leagues = result['leaguesSynced'] as int? ?? 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.fifaSynced(matches, leagues))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${l10n.syncFifaError}: $e')));
      }
    } finally {
      if (mounted) setState(() => _syncingFifa = false);
    }
  }

  Widget _buildSettingsTab() {
    final l10n = AppLocalizations.of(context)!;
    final configAsync = ref.watch(appConfigProvider);

    return configAsync.when(
      data: (config) {
        final predictionConfig = Map<String, dynamic>.from(
          config['predictions'] as Map? ?? {},
        );
        final triviaConfig = Map<String, dynamic>.from(
          config['trivia'] as Map? ?? {},
        );

        if (_predictionLockCtrl.text.isEmpty) {
          _predictionLockCtrl.text =
              '${predictionConfig['lockHoursBefore'] as int? ?? 12}';
        }
        if (_triviaLimitCtrl.text.isEmpty) {
          _triviaLimitCtrl.text =
              '${triviaConfig['dailyQuestionLimit'] as int? ?? 10}';
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.predictionSettings,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _predictionLockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.predictionLockLabel,
                        helperText: l10n.predictionLockHelper,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.triviaSettings,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _triviaLimitCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.triviaDailyLimitLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _savingSettings ? null : _saveSettings,
              icon: _savingSettings
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(l10n.saveSettings),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _recalculatingPoints
                  ? null
                  : _syncAndRecalculateRecentPoints,
              icon: _recalculatingPoints
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.calculate),
              label: const Text('Sincronizar resultados y recalcular puntos'),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('${l10n.error}: $error')),
    );
  }

  Future<void> _syncAndRecalculateRecentPoints() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _recalculatingPoints = true);
    try {
      final result = await ref
          .read(adminControllerProvider)
          .syncAndRecalculateRecentPoints();
      final matches = result['matchesRecalculated'] as int? ?? 0;
      final predictions = result['predictionsProcessed'] as int? ?? 0;
      final delta = result['totalDelta'] as int? ?? 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recalculado: $matches partidos, $predictions predicciones, delta $delta pts',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${l10n.error}: $e')));
      }
    } finally {
      if (mounted) setState(() => _recalculatingPoints = false);
    }
  }

  Future<void> _saveSettings() async {
    final l10n = AppLocalizations.of(context)!;
    final lockHours = int.tryParse(_predictionLockCtrl.text.trim());
    final triviaLimit = int.tryParse(_triviaLimitCtrl.text.trim());
    if (lockHours == null || triviaLimit == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.checkNumericValues)));
      return;
    }

    setState(() => _savingSettings = true);
    try {
      final admin = ref.read(adminControllerProvider);
      await admin.updatePredictionSettings(lockHours);
      await admin.updateTriviaSettings(triviaLimit);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.settingsSaved)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${l10n.error}: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingSettings = false);
    }
  }

  Widget _buildCreateMatchTab(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _homeCtrl,
            decoration: InputDecoration(labelText: l10n.homeTeam),
          ),
          TextField(
            controller: _awayCtrl,
            decoration: InputDecoration(labelText: l10n.awayTeam),
          ),
          TextField(
            controller: _phaseCtrl,
            decoration: InputDecoration(labelText: l10n.phaseExample),
          ),
          TextField(
            controller: _dateCtrl,
            decoration: InputDecoration(labelText: l10n.dateTimeFormat),
            keyboardType: TextInputType.datetime,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _lockHours,
            decoration: InputDecoration(labelText: l10n.lockPredictionsBefore),
            items: [0, 1, 2, 4, 6, 12, 24, 48].map((h) {
              return DropdownMenuItem(
                value: h,
                child: Text(l10n.hoursBefore(h)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _lockHours = val);
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              try {
                final date = DateFormat(
                  'yyyy-MM-dd HH:mm',
                ).parse(_dateCtrl.text);
                await ref
                    .read(adminControllerProvider)
                    .createMatch(
                      homeTeam: _homeCtrl.text,
                      awayTeam: _awayCtrl.text,
                      phase: _phaseCtrl.text,
                      kickoff: date,
                      lockHoursBefore: _lockHours,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l10n.matchCreated)));
                  _homeCtrl.clear();
                  _awayCtrl.clear();
                  _phaseCtrl.clear();
                  _dateCtrl.clear();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l10n.dateFormatError)));
                }
              }
            },
            child: Text(l10n.createMatch),
          ),
        ],
      ),
    );
  }

  void _showFinishDialog(String matchId) {
    final l10n = AppLocalizations.of(context)!;
    final homeCtrl = TextEditingController();
    final awayCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.finishMatch),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: homeCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.homeGoals),
            ),
            TextField(
              controller: awayCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.awayGoals),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final h = int.tryParse(homeCtrl.text) ?? 0;
              final a = int.tryParse(awayCtrl.text) ?? 0;
              await ref
                  .read(adminControllerProvider)
                  .finishMatch(matchId, h, a);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}

class _AdminUsersTab extends ConsumerWidget {
  const _AdminUsersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final usersAsync = ref.watch(adminUsersProvider);

    return usersAsync.when(
      data: (users) {
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final isActive = user['isActive'] ?? true;
            return ListTile(
              title: Text(user['displayName'] ?? l10n.noName),
              subtitle: Text(user['email'] ?? ''),
              trailing: Switch(
                value: isActive,
                onChanged: (val) {
                  ref
                      .read(adminControllerProvider)
                      .toggleUserStatus(user['id'], val);
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('${l10n.error}: $error')),
    );
  }
}

class _AdminFinishTab extends ConsumerWidget {
  final ValueChanged<String> onFinish;

  const _AdminFinishTab({required this.onFinish});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final matchesAsync = ref.watch(adminMatchesProvider);

    return matchesAsync.when(
      data: (matches) {
        final pendingMatches = matches
            .where((m) => m['status'] != 'finished')
            .toList();
        if (pendingMatches.isEmpty) {
          return Center(child: Text(l10n.noPendingMatches));
        }
        return ListView.builder(
          itemCount: pendingMatches.length,
          itemBuilder: (context, index) {
            final match = pendingMatches[index];
            final kickoff = match['kickoff'];
            final kickoffLabel = kickoff is Timestamp
                ? DateFormat('dd/MM HH:mm').format(kickoff.toDate())
                : l10n.noSchedule;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text('${match['homeTeam']} vs ${match['awayTeam']}'),
                subtitle: Text('${match['phase']} - $kickoffLabel'),
                trailing: IconButton(
                  icon: const Icon(Icons.scoreboard, color: Colors.green),
                  onPressed: () => onFinish(match['id'] as String),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('${l10n.error}: $error')),
    );
  }
}
