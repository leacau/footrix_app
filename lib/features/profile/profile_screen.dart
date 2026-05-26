import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../leagues/leagues_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _countryCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  bool _loading = false;
  bool _editing = false;

  int _totalPoints = 0;
  int _triviaPoints = 0;
  int _triviaStreak = 0;
  int _triviaBestStreak = 0;
  int _triviaAnswered = 0;
  Set<String> _selectedLeagueIds = {};
  bool _savingLeagues = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _countryCtrl.dispose();
    _provinceCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _countryCtrl.text = data['country'] ?? '';
        _provinceCtrl.text = data['province'] ?? '';
        _cityCtrl.text = data['city'] ?? '';
        _totalPoints = data['totalPoints'] as int? ?? 0;
        _triviaPoints = data['triviaPoints'] as int? ?? 0;
        _triviaStreak = data['triviaStreak'] as int? ?? 0;
        _triviaBestStreak = data['triviaBestStreak'] as int? ?? 0;
        _triviaAnswered = data['triviaAnswered'] as int? ?? 0;
        _selectedLeagueIds =
            (data['selectedLeagueIds'] as List<dynamic>? ?? const [])
                .whereType<String>()
                .toSet();
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'country': _countryCtrl.text.trim(),
        'province': _provinceCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) setState(() => _editing = false);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${l10n.error}: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveLeaguePreferences() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _savingLeagues = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'selectedLeagueIds': _selectedLeagueIds.toList()..sort(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.leaguesSaved)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${l10n.error}: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingLeagues = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myProfile),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                if (mounted) setState(() => _editing = true);
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          (user?.displayName?.trim().isNotEmpty ?? false)
                              ? user!.displayName!
                                    .trim()
                                    .substring(0, 1)
                                    .toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user?.displayName ?? l10n.user,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        user?.email ?? '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _leaguePreferencesCard(l10n),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.predictions,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _statRow(
                        l10n.totalPoints,
                        '$_totalPoints',
                        Icons.emoji_events,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.trivia,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              if (context.mounted) context.push('/trivia');
                            },
                            child: Text(l10n.play),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _statRow(l10n.triviaPoints, '$_triviaPoints', Icons.star),
                      _statRow(
                        l10n.currentStreak,
                        '$_triviaStreak',
                        Icons.local_fire_department,
                      ),
                      _statRow(
                        l10n.bestStreak,
                        '$_triviaBestStreak',
                        Icons.emoji_events,
                      ),
                      _statRow(
                        l10n.answeredQuestions,
                        '$_triviaAnswered',
                        Icons.quiz,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.location,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (_editing)
                            TextButton(
                              onPressed: _loading ? null : _save,
                              child: _loading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(l10n.save),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_editing) ...[
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _countryCtrl,
                                decoration: InputDecoration(
                                  labelText: l10n.country,
                                  prefixIcon: const Icon(Icons.flag),
                                ),
                                validator: (v) {
                                  if (v != null && v.trim().isEmpty) {
                                    return l10n.errorRequired;
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _provinceCtrl,
                                decoration: InputDecoration(
                                  labelText: l10n.provinceState,
                                  prefixIcon: const Icon(Icons.location_city),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _cityCtrl,
                                decoration: InputDecoration(
                                  labelText: l10n.city,
                                  prefixIcon: const Icon(Icons.place),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        _infoRow(l10n.country, _countryCtrl.text, l10n),
                        _infoRow(l10n.province, _provinceCtrl.text, l10n),
                        _infoRow(l10n.city, _cityCtrl.text, l10n),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leaguePreferencesCard(AppLocalizations l10n) {
    final leaguesAsync = ref.watch(leaguesProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    l10n.leaguesToPlay,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _savingLeagues ? null : _saveLeaguePreferences,
                  child: _savingLeagues
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.save),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _selectedLeagueIds.isEmpty
                  ? l10n.noLeagueSelection
                  : l10n.selectedLeagueCount(_selectedLeagueIds.length),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            leaguesAsync.when(
              data: (leagues) => ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: leagues.length,
                  itemBuilder: (context, index) {
                    final league = leagues[index];
                    final id = league['id'] as String;
                    final name =
                        league['name'] as String? ??
                        league['shortName'] as String? ??
                        id;
                    return CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _selectedLeagueIds.contains(id),
                      title: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedLeagueIds.add(id);
                          } else {
                            _selectedLeagueIds.remove(id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text(
                '${l10n.errorLoadingLeagues}: $error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.grey)),
            ],
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value.isNotEmpty ? value : l10n.unspecified,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
