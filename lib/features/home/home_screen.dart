import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/locale_provider.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_provider.dart';

final _ensuredHomeProfileIds = <String>{};

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = ref.watch(isAdminProvider).valueOrNull == true;
    _ensureProfileAndRedirect(context, ref, user);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          PopupMenuButton<Locale>(
            icon: const Icon(Icons.language),
            tooltip: l10n.language,
            onSelected: (locale) async {
              await ref.read(localeProvider.notifier).setLocale(locale);
              if (context.mounted) {
                final label = locale.languageCode == 'es'
                    ? l10n.spanish
                    : l10n.english;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.languageChanged(label))),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: const Locale('es'),
                child: Text(l10n.spanish),
              ),
              PopupMenuItem(
                value: const Locale('en'),
                child: Text(l10n.english),
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.person),
            onSelected: (value) {
              if (value == 'profile' && context.mounted) {
                context.push('/profile');
              } else if (value == 'logout') {
                FirebaseAuth.instance.signOut();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'profile', child: Text(l10n.myProfile)),
              PopupMenuItem(value: 'logout', child: Text(l10n.signOut)),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.helloUser(user?.displayName ?? l10n.user),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.chooseSection,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _NavCard(
                  icon: Icons.sports_soccer,
                  title: l10n.fixture,
                  subtitle: l10n.fixtureSubtitle,
                  color: Colors.blue,
                  onTap: () => context.push('/fixture'),
                ),
                _NavCard(
                  icon: Icons.public,
                  title: 'Mundial 2026',
                  subtitle: 'Prediccion completa',
                  color: Colors.indigo,
                  onTap: () => context.push('/world-cup'),
                ),
                _NavCard(
                  icon: Icons.group,
                  title: l10n.groups,
                  subtitle: l10n.groupsSubtitle,
                  color: Colors.green,
                  onTap: () => context.push('/groups'),
                ),
                _NavCard(
                  icon: Icons.emoji_events,
                  title: l10n.rankings,
                  subtitle: l10n.rankingsSubtitle,
                  color: Colors.amber,
                  onTap: () => context.push('/rankings'),
                ),
                _NavCard(
                  icon: Icons.person,
                  title: l10n.profile,
                  subtitle: l10n.profileSubtitle,
                  color: Colors.teal,
                  onTap: () => context.push('/profile'),
                ),
                _NavCard(
                  icon: Icons.settings,
                  title: l10n.settings,
                  subtitle: l10n.settingsSubtitle,
                  color: Colors.grey,
                  onTap: () => _showSettingsDialog(context, ref),
                ),
                if (isAdmin)
                  _NavCard(
                    icon: Icons.admin_panel_settings,
                    title: l10n.admin,
                    subtitle: l10n.adminSubtitle,
                    color: Colors.red,
                    onTap: () => context.push('/admin'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            _HomeStats(userId: user?.uid, title: l10n.myStats),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          final routes = ['/fixture', '/groups', '/rankings', '/profile'];
          if (index < routes.length && context.mounted) {
            context.push(routes[index]);
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.sports_soccer),
            label: l10n.fixture,
          ),
          NavigationDestination(
            icon: const Icon(Icons.group),
            label: l10n.groups,
          ),
          NavigationDestination(
            icon: const Icon(Icons.emoji_events),
            label: l10n.rankings,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person),
            label: l10n.profile,
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settings),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l10n.language}:'),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    ref
                        .read(localeProvider.notifier)
                        .setLocale(const Locale('es'));
                    Navigator.pop(context);
                  },
                  child: Text(l10n.spanish),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    ref
                        .read(localeProvider.notifier)
                        .setLocale(const Locale('en'));
                    Navigator.pop(context);
                  },
                  child: Text(l10n.english),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('${l10n.notifications}:'),
            const SizedBox(height: 8),
            SwitchListTile(
              title: Text(l10n.enablePush),
              value: true,
              onChanged: (_) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  void _ensureProfileAndRedirect(
    BuildContext context,
    WidgetRef ref,
    User? user,
  ) {
    if (user == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) return;
      if (!_ensuredHomeProfileIds.contains(user.uid)) {
        _ensuredHomeProfileIds.add(user.uid);
        await ref.read(authControllerProvider).ensureUserDocument(user);
      }
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final displayName =
          (doc.data()?['displayName'] as String?) ?? user.displayName ?? '';
      final normalized = displayName.trim().toLowerCase();
      final isAnonymous =
          normalized.isEmpty ||
          normalized == 'anónimo' ||
          normalized == 'anonimo' ||
          normalized == 'anonymous';
      if (isAnonymous && context.mounted) {
        context.go('/profile');
      }
    });
  }
}

class _HomeStats extends StatelessWidget {
  final String? userId;
  final String title;

  const _HomeStats({required this.userId, required this.title});

  @override
  Widget build(BuildContext context) {
    final uid = userId;
    if (uid == null) return const SizedBox.shrink();
    final firestore = FirebaseFirestore.instance;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: firestore.collection('users').doc(uid).snapshots(),
      builder: (context, userSnapshot) {
        final totalPoints =
            userSnapshot.data?.data()?['totalPoints'] as int? ?? 0;
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: firestore.collection('world_cup_scores').doc(uid).snapshots(),
          builder: (context, worldCupSnapshot) {
            final worldCupPoints =
                worldCupSnapshot.data?.data()?['totalPoints'] as int? ?? 0;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _statChip('Fixture', '$totalPoints pts'),
                        ),
                        Expanded(
                          child: _statChip(
                            'Mundial 2026',
                            '$worldCupPoints pts',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _statChip(String label, String value) {
  return Column(
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
    ],
  );
}
