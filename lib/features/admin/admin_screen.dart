import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
  int _lockHours = 12;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🛠️ Panel Admin'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Usuarios'),
            Tab(text: 'Crear Partido'),
            Tab(text: 'Finalizar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsersTab(),
          _buildCreateMatchTab(),
          _buildFinishMatchTab(),
        ],
      ),
    );
  }

  // --- TAB 1: USUARIOS ---
  Widget _buildUsersTab() {
    final usersAsync = ref.watch(adminUsersProvider);

    // ✅ CORRECCIÓN EXPLÍCITA: 'data:' debe estar ESCRITO, no implícito
    return usersAsync.when(
      data: (List<Map<String, dynamic>> users) {
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final isActive = user['isActive'] ?? true;
            return ListTile(
              title: Text(user['displayName'] ?? 'Sin nombre'),
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
      error: (Object e, StackTrace _) => Center(child: Text('Error: $e')),
    );
  }

  // --- TAB 2: CREAR PARTIDO ---
  Widget _buildCreateMatchTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _homeCtrl,
            decoration: const InputDecoration(labelText: 'Equipo Local'),
          ),
          TextField(
            controller: _awayCtrl,
            decoration: const InputDecoration(labelText: 'Equipo Visitante'),
          ),
          TextField(
            controller: _phaseCtrl,
            decoration: const InputDecoration(labelText: 'Fase (Ej: Grupo A)'),
          ),
          TextField(
            controller: _dateCtrl,
            decoration: const InputDecoration(
              labelText: 'Fecha y Hora (YYYY-MM-DD HH:MM)',
            ),
            keyboardType: TextInputType.datetime,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _lockHours,
            decoration: const InputDecoration(
              labelText: 'Bloquear predicciones X horas antes',
            ),
            items: [1, 2, 4, 6, 12, 24, 48].map((h) {
              return DropdownMenuItem(value: h, child: Text('$h horas antes'));
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _lockHours = val);
              }
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Partido creado')),
                  );
                  _homeCtrl.clear();
                  _awayCtrl.clear();
                  _phaseCtrl.clear();
                  _dateCtrl.clear();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Error: Formato de fecha incorrecto'),
                    ),
                  );
                }
              }
            },
            child: const Text('Crear Partido'),
          ),
        ],
      ),
    );
  }

  // --- TAB 3: FINALIZAR PARTIDO ---
  Widget _buildFinishMatchTab() {
    final matchesAsync = ref.watch(adminMatchesProvider);

    // ✅ CORRECCIÓN EXPLÍCITA: 'data:' debe estar ESCRITO, no implícito
    return matchesAsync.when(
      data: (List<Map<String, dynamic>> matches) {
        final pendingMatches = matches
            .where((m) => m['status'] != 'finished')
            .toList();
        if (pendingMatches.isEmpty) {
          return const Center(child: Text('No hay partidos pendientes'));
        }
        return ListView.builder(
          itemCount: pendingMatches.length,
          itemBuilder: (context, index) {
            final match = pendingMatches[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text('${match['homeTeam']} vs ${match['awayTeam']}'),
                subtitle: Text(
                  '${match['phase']} - ${DateFormat('dd/MM HH:mm').format((match['kickoff'] as Timestamp).toDate())}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.scoreboard, color: Colors.green),
                  onPressed: () => _showFinishDialog(match['id']),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, StackTrace _) => Center(child: Text('Error: $e')),
    );
  }

  void _showFinishDialog(String matchId) {
    final homeCtrl = TextEditingController();
    final awayCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar Partido'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: homeCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Goles Local'),
            ),
            TextField(
              controller: awayCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Goles Visita'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final h = int.tryParse(homeCtrl.text) ?? 0;
              final a = int.tryParse(awayCtrl.text) ?? 0;
              await ref
                  .read(adminControllerProvider)
                  .finishMatch(matchId, h, a);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
