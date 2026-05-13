import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'groups_provider.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _creating = false;

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(userGroupsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Grupos')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // === CREAR GRUPO ===
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Crear Grupo',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del Grupo',
                        hintText: 'Ej: Oficina, Familia, Amigos',
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _creating
                          ? null
                          : () async {
                              if (_nameCtrl.text.trim().isEmpty) return;

                              setState(() => _creating = true);
                              try {
                                await ref.read(
                                  createGroupProvider(
                                    _nameCtrl.text.trim(),
                                  ).future,
                                );
                                _nameCtrl.clear();

                                // ✅ CORRECCIÓN: usar context.mounted cuando usás context
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('✅ Grupo creado'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('❌ $e')),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => _creating = false);
                                }
                              }
                            },
                      child: _creating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Crear'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // === UNIRSE A GRUPO ===
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Unirse a Grupo',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Código de 6 caracteres',
                        hintText: 'Ej: X7K9P2',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [LengthLimitingTextInputFormatter(6)],
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _codeCtrl.text.length == 6
                          ? () async {
                              try {
                                await ref.read(
                                  joinGroupProvider(
                                    _codeCtrl.text.trim(),
                                  ).future,
                                );
                                _codeCtrl.clear();

                                // ✅ CORRECCIÓN: usar context.mounted cuando usás context
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('✅ Te uniste al grupo'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('❌ $e')),
                                  );
                                }
                              }
                            }
                          : null,
                      child: const Text('Unirse'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // === LISTA DE GRUPOS ===
            Expanded(
              child: groupsAsync.when(
                data: (groups) {
                  if (groups.isEmpty) {
                    return const Center(
                      child: Text('📭 No perteneces a ningún grupo aún.'),
                    );
                  }
                  return ListView.builder(
                    itemCount: groups.length,
                    itemBuilder: (_, i) {
                      final g = groups[i];
                      return ListTile(
                        title: Text(g['name']),
                        subtitle: Text('Código: ${g['code']}'),
                        trailing: Text('${(g['members'] as List).length} 👥'),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
