import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../leagues/leagues_provider.dart';
import '../leagues/widgets/league_selector.dart';
import 'models/prediction_model.dart';
import 'widgets/match_card.dart';

class FixtureScreen extends ConsumerStatefulWidget {
  const FixtureScreen({super.key});

  @override
  ConsumerState<FixtureScreen> createState() => _FixtureScreenState();
}

class _FixtureScreenState extends ConsumerState<FixtureScreen> {
  String? _selectedLeagueId;

  @override
  Widget build(BuildContext context) {
    // ✅ Usar provider que soporta filtro por liga
    final matchesAsync = ref.watch(matchesByLeagueProvider(_selectedLeagueId));
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fixture'),
        actions: [
          // ✅ Selector de ligas en el AppBar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: 220,
              child: LeagueSelector(
                selectedLeagueId: _selectedLeagueId,
                onLeagueSelected: (leagueId) {
                  if (context.mounted) {
                    setState(() => _selectedLeagueId = leagueId);
                  }
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Inicio',
            onPressed: () => context.go('/home'),
          ),
          IconButton(
            icon: const Icon(Icons.group),
            tooltip: 'Grupos',
            onPressed: () => context.push('/groups'),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Perfil',
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events),
            tooltip: 'Rankings',
            onPressed: () => context.push('/rankings'),
          ),
        ],
      ),
      body: matchesAsync.when(
        data: (matches) {
          if (matches.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sports_soccer, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    _selectedLeagueId != null
                        ? '📭 No hay partidos en esta liga'
                        : '📭 Cargando partidos...',
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (_selectedLeagueId != null)
                    TextButton(
                      onPressed: () {
                        if (context.mounted) {
                          setState(() => _selectedLeagueId = null);
                        }
                      },
                      child: const Text('Ver todas las ligas'),
                    ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final match = matches[index];

              return StreamBuilder<DocumentSnapshot>(
                key: ValueKey('pred_${match.id}_${user?.uid}'),
                stream: user != null
                    ? FirebaseFirestore.instance
                          .collection('predictions')
                          .doc('${user.uid}_${match.id}')
                          .snapshots()
                    : null,
                builder: (context, snapshot) {
                  Prediction? pred;
                  if (snapshot.hasData && snapshot.data!.exists) {
                    pred = Prediction.fromFirestore(snapshot.data!);
                  }
                  return MatchCard(match: match, existingPrediction: pred);
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
