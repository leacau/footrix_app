import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../leagues/widgets/league_selector.dart';
import 'groups_provider.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _creating = false;
  // Cambiamos a la lista para soportar múltiples ligas
  final List<String> _selectedLeaguesForGroup = [];
  bool _isLeagueExclusive = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final groupsAsync = ref.watch(userGroupsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myGroups)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.createGroup,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.groupName,
                        hintText: l10n.groupNameHint,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.leagueCompetition,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    LeagueSelector(
                      // Mostramos la última liga seleccionada en el selector
                      selectedLeagueId: _selectedLeaguesForGroup.isNotEmpty
                          ? _selectedLeaguesForGroup.last
                          : null,
                      onLeagueSelected: (value) {
                        if (context.mounted && value != null) {
                          setState(() {
                            // Si la liga no está en la lista, la agregamos
                            if (!_selectedLeaguesForGroup.contains(value)) {
                              _selectedLeaguesForGroup.add(value);
                            }
                          });
                        }
                      },
                      showAllOption: false,
                    ),

                    // Pequeño indicador visual de cuántas ligas van seleccionadas
                    if (_selectedLeaguesForGroup.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${_selectedLeaguesForGroup.length} ligas seleccionadas',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                          ),
                        ),
                      ),

                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.onlyThisLeague),
                      subtitle: Text(l10n.leagueExclusiveSubtitle),
                      value: _isLeagueExclusive,
                      onChanged: (val) {
                        if (context.mounted) {
                          setState(() => _isLeagueExclusive = val);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      // Cambiamos la validación a la lista
                      onPressed: _creating || _selectedLeaguesForGroup.isEmpty
                          ? null
                          : () async {
                              if (_nameCtrl.text.trim().isEmpty) return;

                              setState(() => _creating = true);
                              try {
                                final code = await ref.read(
                                  createGroupProvider((
                                    name: _nameCtrl.text.trim(),
                                    leagueIds:
                                        _selectedLeaguesForGroup, // Pasamos el array
                                    isLeagueExclusive: _isLeagueExclusive,
                                  )).future,
                                );
                                final groupName = _nameCtrl.text.trim();
                                _nameCtrl.clear();
                                // Limpiamos la lista tras crear el grupo
                                _selectedLeaguesForGroup.clear();

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(l10n.groupCreated)),
                                  );
                                  _shareInvite(
                                    code: code,
                                    groupName: groupName,
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${l10n.error}: $e'),
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _creating = false);
                              }
                            },
                      child: _creating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.create),
                    ),
                    // Validamos contra la lista vacía
                    if (_selectedLeaguesForGroup.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          l10n.selectLeagueWarning,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.joinGroup,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _codeCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.sixCharacterCode,
                        hintText: l10n.codeExample,
                      ),
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [LengthLimitingTextInputFormatter(6)],
                      onChanged: (_) {
                        if (mounted) setState(() {});
                      },
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

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(l10n.joinedGroup)),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${l10n.error}: $e'),
                                    ),
                                  );
                                }
                              }
                            }
                          : null,
                      child: Text(l10n.join),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: groupsAsync.when(
                data: (groups) {
                  if (groups.isEmpty) {
                    return Center(child: Text(l10n.noGroupsYet));
                  }
                  return ListView.builder(
                    itemCount: groups.length,
                    itemBuilder: (_, i) {
                      final g = groups[i];
                      final leagueName = g['leagueName'] ?? l10n.allLeaguesName;
                      final isExclusive = g['isLeagueExclusive'] ?? false;

                      return ListTile(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GroupDetailScreen(group: g),
                            ),
                          );
                        },
                        title: Text(g['name']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${l10n.code}: ${g['code']}'),
                            Text(
                              '${l10n.league}: $leagueName${isExclusive ? ' (${l10n.exclusive})' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${(g['members'] as List).length}'),
                            IconButton(
                              tooltip: l10n.inviteWhatsapp,
                              icon: const Icon(Icons.ios_share),
                              onPressed: () => _shareInvite(
                                code: g['code'] as String? ?? g['id'] as String,
                                groupName:
                                    g['name'] as String? ?? l10n.myGroups,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('${l10n.error}: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareInvite({
    required String code,
    required String groupName,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    final message = Uri.encodeComponent(l10n.whatsappInvite(groupName, code));
    final uri = Uri.parse('https://wa.me/?text=$message');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.codeCopied(code))));
    }
  }
}
