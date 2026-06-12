import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../auth/auth_provider.dart';
import '../leagues/leagues_provider.dart';
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
  int _lockHours = 12;
  bool _syncingFifa = false;
  bool _savingSettings = false;
  bool _recalculatingPoints = false;
  bool _repairingUsers = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _homeCtrl.dispose();
    _awayCtrl.dispose();
    _phaseCtrl.dispose();
    _dateCtrl.dispose();
    _predictionLockCtrl.dispose();
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
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: l10n.users),
            const Tab(text: 'Predicciones'),
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
          const _AdminPredictionsTab(),
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

        if (_predictionLockCtrl.text.isEmpty) {
          _predictionLockCtrl.text =
              '${predictionConfig['lockHoursBefore'] as int? ?? 12}';
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
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _repairingUsers ? null : _repairUserDocuments,
              icon: _repairingUsers
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.manage_accounts),
              label: const Text('Reparar perfiles de usuarios'),
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
      final users = result['usersRecalculated'] as int? ?? 0;
      final worldCupUsers =
          result['worldCupUsersRecalculated'] as int? ?? 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recalculado: $matches partidos, $predictions predicciones, '
              '$users usuarios y $worldCupUsers del Mundial. Delta $delta pts',
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

  Future<void> _repairUserDocuments() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _repairingUsers = true);
    try {
      final result = await ref
          .read(adminControllerProvider)
          .repairUserDocuments();
      final repaired = result['repaired'] as int? ?? 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Perfiles revisados: $repaired')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${l10n.error}: $e')));
      }
    } finally {
      if (mounted) setState(() => _repairingUsers = false);
    }
  }

  Future<void> _saveSettings() async {
    final l10n = AppLocalizations.of(context)!;
    final lockHours = int.tryParse(_predictionLockCtrl.text.trim());
    if (lockHours == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.checkNumericValues)));
      return;
    }

    setState(() => _savingSettings = true);
    try {
      final admin = ref.read(adminControllerProvider);
      await admin.updatePredictionSettings(lockHours);
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
    return ListView(
      padding: const EdgeInsets.all(16.0),
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
            return DropdownMenuItem(value: h, child: Text(l10n.hoursBefore(h)));
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _lockHours = val);
          },
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () async {
            try {
              final date = DateFormat('yyyy-MM-dd HH:mm').parse(_dateCtrl.text);
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
        content: SingleChildScrollView(
          child: Column(
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
            final permissions = Map<String, dynamic>.from(
              user['predictionPermissions'] as Map? ?? {},
            );
            return ListTile(
              title: Text(user['displayName'] ?? l10n.noName),
              subtitle: Text(
                '${user['email'] ?? ''}\n'
                '${permissions['blocked'] == true
                    ? 'Predicciones bloqueadas'
                    : permissions['bypassLocks'] == true
                    ? 'Sin restricciones de horario'
                    : 'Restricciones normales'}',
              ),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'status') {
                    ref
                        .read(adminControllerProvider)
                        .toggleUserStatus(user['id'], !isActive);
                  } else if (value == 'permissions') {
                    _showPermissionsDialog(context, ref, user);
                  } else if (value == 'points') {
                    _showPointsDialog(context, ref, user);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'status',
                    child: Text(
                      isActive ? 'Desactivar usuario' : 'Activar usuario',
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'permissions',
                    child: Text('Permisos de predicción'),
                  ),
                  const PopupMenuItem(
                    value: 'points',
                    child: Text('Modificar puntos'),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('${l10n.error}: $error')),
    );
  }

  Future<void> _showPermissionsDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> user,
  ) async {
    final permissions = Map<String, dynamic>.from(
      user['predictionPermissions'] as Map? ?? {},
    );
    var blocked = permissions['blocked'] == true;
    var bypassLocks = permissions['bypassLocks'] == true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(user['displayName'] as String? ?? 'Usuario'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Bloquear predicciones'),
                subtitle: const Text('No podrá predecir en ningún modo.'),
                value: blocked,
                onChanged: (value) => setDialogState(() => blocked = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Permitir fuera de término'),
                subtitle: const Text(
                  'Ignora cierres por horario en Fixture y Mundial.',
                ),
                value: bypassLocks,
                onChanged: blocked
                    ? null
                    : (value) => setDialogState(() => bypassLocks = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    await ref
        .read(adminControllerProvider)
        .updatePredictionPermissions(
          userId: user['id'] as String,
          blocked: blocked,
          bypassLocks: bypassLocks,
        );
  }

  Future<void> _showPointsDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> user,
  ) async {
    final controller = TextEditingController();
    var mode = 'normal';
    var operation = 'set';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modificar puntos'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: mode,
                decoration: const InputDecoration(labelText: 'Modo'),
                items: const [
                  DropdownMenuItem(value: 'normal', child: Text('Fixture')),
                  DropdownMenuItem(value: 'worldCup', child: Text('Mundial')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => mode = value);
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: operation,
                decoration: const InputDecoration(labelText: 'Operación'),
                items: const [
                  DropdownMenuItem(value: 'set', child: Text('Fijar total')),
                  DropdownMenuItem(
                    value: 'adjust',
                    child: Text('Sumar/restar'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => operation = value);
                },
              ),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                ),
                decoration: const InputDecoration(labelText: 'Puntos'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
    final value = int.tryParse(controller.text.trim());
    controller.dispose();
    if (saved != true || value == null) return;
    await ref
        .read(adminControllerProvider)
        .updateUserPoints(
          userId: user['id'] as String,
          mode: mode,
          operation: operation,
          value: value,
        );
  }
}

class _AdminPredictionsTab extends ConsumerStatefulWidget {
  const _AdminPredictionsTab();

  @override
  ConsumerState<_AdminPredictionsTab> createState() =>
      _AdminPredictionsTabState();
}

class _AdminPredictionsTabState extends ConsumerState<_AdminPredictionsTab> {
  List<Map<String, dynamic>> _rows = [];
  final Set<String> _selected = {};
  String? _userId;
  String? _leagueId;
  String _mode = 'all';
  DateTime? _from;
  DateTime? _to;
  bool _loading = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await ref
          .read(adminControllerProvider)
          .listPredictions(
            userId: _userId,
            leagueId: _leagueId,
            mode: _mode,
            from: _from,
            to: _to == null
                ? null
                : DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59),
          );
      if (mounted) {
        setState(() {
          _rows = rows;
          _selected.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar predicciones'),
        content: Text(
          'Se eliminarán ${_selected.length} predicciones y se recalcularán los puntos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deleting = true);
    try {
      final count = await ref
          .read(adminControllerProvider)
          .deletePredictions(_selected.toList());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Eliminadas: $count')));
      }
      await _load();
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _editPrediction(Map<String, dynamic> row) async {
    final homeCtrl = TextEditingController(text: '${row['homeGuess'] ?? 0}');
    final awayCtrl = TextEditingController(text: '${row['awayGuess'] ?? 0}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${row['homeTeam']} vs ${row['awayTeam']}'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: homeCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(labelText: 'Local'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('-'),
            ),
            Expanded(
              child: TextField(
                controller: awayCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(labelText: 'Visitante'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    final home = int.tryParse(homeCtrl.text.trim());
    final away = int.tryParse(awayCtrl.text.trim());
    homeCtrl.dispose();
    awayCtrl.dispose();
    if (saved != true || home == null || away == null) return;
    await ref
        .read(adminControllerProvider)
        .updatePrediction(
          id: row['id'] as String,
          homeGuess: home,
          awayGuess: away,
        );
    await _load();
  }

  Future<DateTime?> _pickDate(DateTime? initial) {
    return showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(adminUsersProvider).valueOrNull ?? const [];
    final leagues = ref.watch(leaguesProvider).valueOrNull ?? const [];
    final allSelected = _rows.isNotEmpty && _selected.length == _rows.length;

    return Column(
      children: [
        ExpansionTile(
          initiallyExpanded: true,
          title: const Text('Filtros'),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            DropdownButtonFormField<String?>(
              initialValue: _userId,
              decoration: const InputDecoration(labelText: 'Usuario'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                for (final user in users)
                  DropdownMenuItem(
                    value: user['id'] as String,
                    child: Text(
                      user['displayName'] as String? ??
                          user['email'] as String? ??
                          'Anonimo',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _userId = value),
            ),
            DropdownButtonFormField<String>(
              initialValue: _mode,
              decoration: const InputDecoration(labelText: 'Modo'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Todos')),
                DropdownMenuItem(value: 'normal', child: Text('Fixture')),
                DropdownMenuItem(value: 'worldCup', child: Text('Mundial')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _mode = value);
              },
            ),
            DropdownButtonFormField<String?>(
              initialValue: _leagueId,
              decoration: const InputDecoration(labelText: 'Liga'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todas')),
                for (final league in leagues)
                  DropdownMenuItem(
                    value: league['id'] as String,
                    child: Text(
                      league['shortName'] as String? ??
                          league['name'] as String? ??
                          league['id'] as String,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _leagueId = value),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _from == null
                          ? 'Desde'
                          : DateFormat('dd/MM/y').format(_from!),
                    ),
                    onPressed: () async {
                      final date = await _pickDate(_from);
                      if (date != null) setState(() => _from = date);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(
                      _to == null
                          ? 'Hasta'
                          : DateFormat('dd/MM/y').format(_to!),
                    ),
                    onPressed: () async {
                      final date = await _pickDate(_to);
                      if (date != null) setState(() => _to = date);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.search),
                label: const Text('Buscar predicciones'),
              ),
            ),
          ],
        ),
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Row(
            children: [
              Checkbox(
                value: allSelected,
                onChanged: _rows.isEmpty
                    ? null
                    : (value) {
                        setState(() {
                          _selected.clear();
                          if (value == true) {
                            _selected.addAll(
                              _rows.map((row) => row['id'] as String),
                            );
                          }
                        });
                      },
              ),
              Expanded(
                child: Text(
                  '${_rows.length} resultados · ${_selected.length} seleccionados',
                ),
              ),
              IconButton(
                tooltip: 'Eliminar seleccionadas',
                onPressed: _selected.isEmpty || _deleting
                    ? null
                    : _deleteSelected,
                icon: _deleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _rows.isEmpty
              ? const Center(child: Text('No hay predicciones para el filtro.'))
              : ListView.builder(
                  itemCount: _rows.length,
                  itemBuilder: (context, index) {
                    final row = _rows[index];
                    final id = row['id'] as String;
                    final dateMillis = row['dateMillis'] as int? ?? 0;
                    return CheckboxListTile(
                      value: _selected.contains(id),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selected.add(id);
                          } else {
                            _selected.remove(id);
                          }
                        });
                      },
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${row['displayName'] ?? 'Anonimo'} · '
                              '${row['homeGuess']} - ${row['awayGuess']}',
                            ),
                          ),
                          IconButton(
                            tooltip: 'Editar predicción',
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _editPrediction(row),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        '${row['homeTeam']} vs ${row['awayTeam']}\n'
                        '${row['competitionName'] ?? row['leagueId']} · '
                        '${dateMillis > 0 ? DateFormat('dd/MM/y HH:mm').format(DateTime.fromMillisecondsSinceEpoch(dateMillis)) : 'Sin fecha'}',
                      ),
                      isThreeLine: true,
                      secondary: Text(
                        row['mode'] == 'worldCup'
                            ? 'Mundial'
                            : '${row['points'] ?? 0} pts',
                      ),
                    );
                  },
                ),
        ),
      ],
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
