import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../leagues/leagues_provider.dart';
import '../leagues/widgets/league_selector.dart';
import 'group_detail_screen.dart';
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
  bool _joining = false;
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
    final leaguesById = {
      for (final league in ref.watch(leaguesProvider).asData?.value ?? const [])
        league['id'] as String:
            league['shortName'] as String? ?? league['name'] as String? ?? '',
    };

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.myGroups),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Crear / Unirse'),
              Tab(text: 'Mis grupos'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _createGroupCard(l10n, leaguesById),
                  const SizedBox(height: 16),
                  _joinGroupCard(l10n),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _groupsList(l10n, groupsAsync),
            ),
          ],
        ),
      ),
    );
  }

  Widget _createGroupCard(
    AppLocalizations l10n,
    Map<String, String> leaguesById,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
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
              selectedLeagueId: _selectedLeaguesForGroup.isNotEmpty
                  ? _selectedLeaguesForGroup.last
                  : null,
              onLeagueSelected: (value) {
                if (value == null) return;
                setState(() {
                  if (!_selectedLeaguesForGroup.contains(value)) {
                    _selectedLeaguesForGroup.add(value);
                  }
                });
              },
              showAllOption: false,
            ),
            if (_selectedLeaguesForGroup.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final leagueId in _selectedLeaguesForGroup)
                    InputChip(
                      label: Text(_shortLeagueLabel(leagueId, leaguesById)),
                      onDeleted: () {
                        setState(
                          () => _selectedLeaguesForGroup.remove(leagueId),
                        );
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.onlyThisLeague),
              subtitle: Text(l10n.leagueExclusiveSubtitle),
              value: _isLeagueExclusive,
              onChanged: (val) => setState(() => _isLeagueExclusive = val),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _creating || _selectedLeaguesForGroup.isEmpty
                  ? null
                  : _createGroup,
              child: _creating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.create),
            ),
            if (_selectedLeaguesForGroup.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.selectLeagueWarning,
                  style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _joinGroupCard(AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
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
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _joining || _codeCtrl.text.length != 6
                  ? null
                  : _joinGroup,
              child: _joining
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.join),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupsList(
    AppLocalizations l10n,
    AsyncValue<List<Map<String, dynamic>>> groupsAsync,
  ) {
    return groupsAsync.when(
      data: (groups) {
        if (groups.isEmpty) {
          return Center(child: Text(l10n.noGroupsYet));
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(userGroupsProvider);
            await ref.read(userGroupsProvider.future);
          },
          child: ListView.builder(
            itemCount: groups.length,
            itemBuilder: (_, i) {
              final g = groups[i];
              final leagueName = _groupLeagueLabel(g, l10n.allLeaguesName);
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
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                        groupName: g['name'] as String? ?? l10n.myGroups,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('${l10n.error}: $e')),
    );
  }

  Future<void> _createGroup() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _creating = true);
    final requestId = '${DateTime.now().microsecondsSinceEpoch}-$name';
    try {
      final code = await ref
          .read(groupsControllerProvider)
          .createGroup(
            name: name,
            leagueIds: List<String>.from(_selectedLeaguesForGroup),
            isLeagueExclusive: _isLeagueExclusive,
            clientRequestId: requestId,
          );
      _nameCtrl.clear();
      setState(() => _selectedLeaguesForGroup.clear());
      ref.invalidate(userGroupsProvider);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.groupCreated)));
        _shareInvite(code: code, groupName: name);
      }
    } catch (e) {
      ref.invalidate(userGroupsProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${l10n.error}: $e')));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _joinGroup() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _joining = true);
    try {
      await ref.read(groupsControllerProvider).joinGroup(_codeCtrl.text.trim());
      _codeCtrl.clear();
      ref.invalidate(userGroupsProvider);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.joinedGroup)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${l10n.error}: $e')));
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _shareInvite({
    required String code,
    required String groupName,
  }) async {
    if (code.isEmpty) return;
    final inviteLink = _inviteLink(code);
    await Clipboard.setData(ClipboardData(text: inviteLink));
    final message = Uri.encodeComponent(
      'Sumate a mi grupo "$groupName" en Footrix: $inviteLink',
    );
    final uri = Uri.parse('https://wa.me/?text=$message');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Link copiado: $inviteLink')));
    }
  }

  String _inviteLink(String code) {
    final origin = kIsWeb && Uri.base.scheme.startsWith('http')
        ? '${Uri.base.scheme}://${Uri.base.authority}'
        : const String.fromEnvironment(
            'INVITE_BASE_URL',
            defaultValue: 'https://footrix-dc5a7.web.app',
          );
    return '$origin/join/$code';
  }

  String _shortLeagueLabel(String leagueId, Map<String, String> leaguesById) {
    final name = leaguesById[leagueId];
    if (name != null && name.trim().isNotEmpty) return name;
    return leagueId;
  }

  String _groupLeagueLabel(Map<String, dynamic> group, String fallback) {
    final leagueNames = (group['leagueNames'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .where((name) => name.trim().isNotEmpty)
        .toList();
    if (leagueNames.isNotEmpty) return leagueNames.join(', ');

    final leagueName = group['leagueName'];
    if (leagueName is String && leagueName.trim().isNotEmpty) {
      return leagueName;
    }

    final leagueIds = (group['leagueIds'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList();
    if (leagueIds.isNotEmpty) return leagueIds.join(', ');

    final leagueId = group['leagueId'];
    if (leagueId is String && leagueId.trim().isNotEmpty) return leagueId;

    return fallback;
  }
}
