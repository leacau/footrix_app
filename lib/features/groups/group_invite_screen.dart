import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import 'groups_provider.dart';
import 'pending_group_invite.dart';

class GroupInviteScreen extends ConsumerStatefulWidget {
  final String code;

  const GroupInviteScreen({super.key, required this.code});

  @override
  ConsumerState<GroupInviteScreen> createState() => _GroupInviteScreenState();
}

class _GroupInviteScreenState extends ConsumerState<GroupInviteScreen> {
  bool _joining = false;
  bool _joined = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeJoin());
  }

  Future<void> _maybeJoin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _joining || _joined) {
      if (user == null) await PendingGroupInvite.save(widget.code);
      return;
    }

    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      await ref.read(groupsControllerProvider).joinGroup(widget.code);
      ref.invalidate(userGroupsProvider);
      if (mounted) {
        setState(() => _joined = true);
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (mounted) context.go('/groups');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Invitación a grupo')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.group_add, size: 54),
                    const SizedBox(height: 16),
                    Text(
                      'Te invitaron a un grupo de Footrix',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Código ${widget.code}', textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    if (_joining)
                      const Center(child: CircularProgressIndicator())
                    else if (_joined)
                      const Text(
                        'Listo, ya sos parte del grupo.',
                        textAlign: TextAlign.center,
                      )
                    else if (!isLoggedIn) ...[
                      const Text(
                        'Ingresá o registrate para sumarte automáticamente.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () async {
                          await PendingGroupInvite.save(widget.code);
                          if (context.mounted) context.go('/login');
                        },
                        child: Text(l10n.loginButton),
                      ),
                      if (kIsWeb) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Si querés usarla como app, abrí el menú del navegador y elegí instalar o agregar a pantalla de inicio.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ] else ...[
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'No se pudo unir automáticamente: $_error',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ElevatedButton(
                        onPressed: _maybeJoin,
                        child: const Text('Sumarme al grupo'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
