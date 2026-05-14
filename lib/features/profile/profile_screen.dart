import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
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
      }
    }
  }

  Future<void> _save() async {
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
      // ✅ CORRECCIÓN: usar 'mounted' (del State) para setState
      if (mounted) {
        setState(() => _editing = false);
      }
    } catch (e) {
      // ✅ CORRECCIÓN: usar 'context.mounted' para UI con context
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      // ✅ CORRECCIÓN: usar 'mounted' (del State) para setState
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit),
              // ✅ CORRECCIÓN: esto es síncrono, no necesita mounted
              onPressed: () {
                if (mounted) {
                  setState(() => _editing = true);
                }
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
                          user?.displayName?.substring(0, 1).toUpperCase() ??
                              'U',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user?.displayName ?? 'Usuario',
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '⚽ Predicciones',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _statRow(
                        'Puntos totales',
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
                          const Text(
                            '🎮 Trivia',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          TextButton(
                            // ✅ CORRECCIÓN: Navigator usa context → context.mounted
                            onPressed: () {
                              if (context.mounted) {
                                Navigator.pushNamed(context, '/trivia');
                              }
                            },
                            child: const Text('Jugar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _statRow('Puntos trivia', '$_triviaPoints', Icons.star),
                      _statRow(
                        'Racha actual',
                        '🔥 $_triviaStreak',
                        Icons.local_fire_department,
                      ),
                      _statRow(
                        'Mejor racha',
                        '🏆 $_triviaBestStreak',
                        Icons.emoji_events,
                      ),
                      _statRow(
                        'Preguntas respondidas',
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
                          const Text(
                            '🌍 Ubicación',
                            style: TextStyle(
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
                                  : const Text('Guardar'),
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
                                decoration: const InputDecoration(
                                  labelText: 'País',
                                  prefixIcon: Icon(Icons.flag),
                                ),
                                validator: (v) {
                                  if (v != null && v.trim().isEmpty) {
                                    return 'Requerido';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _provinceCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Provincia/Estado',
                                  prefixIcon: Icon(Icons.location_city),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _cityCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Ciudad',
                                  prefixIcon: Icon(Icons.place),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        _infoRow('País', _countryCtrl.text),
                        _infoRow('Provincia', _provinceCtrl.text),
                        _infoRow('Ciudad', _cityCtrl.text),
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value.isNotEmpty ? value : 'No especificado',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
