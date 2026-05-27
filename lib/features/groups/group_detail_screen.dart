import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../rankings/ranking_provider.dart';
import '../matches/models/prediction_model.dart';
import 'groups_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupDetailScreen extends ConsumerWidget {
  final Map<String, dynamic> group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    // Obtenemos el ranking del grupo usando el provider existente
    final rankingAsync = ref.watch(
      rankingProvider((
        scope: RankingScope.global,
        type: RankingType.combined,
        groupId: group['id'],
        filter: null,
        leagueId: group['leagueIds'], // Le pasamos el array completo
      )),
    );

    // Obtenemos todas las predicciones de los miembros
    final predictionsAsync = ref.watch(groupPredictionsProvider(group['id']));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(group['name']),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Ranking"),
              Tab(text: "Predicciones"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // PESTAÑA 1: RANKING Y PARTICIPANTES
            rankingAsync.when(
              data: (users) => ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, i) => ListTile(
                  leading: CircleAvatar(child: Text("${i + 1}")),
                  title: Text(users[i]['displayName'] ?? 'Usuario'),
                  trailing: Text("${users[i]['totalPoints'] ?? 0} pts"),
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text("Error: $e")),
            ),

            // PESTAÑA 2: PREDICCIONES (Lógica de visibilidad)
            predictionsAsync.when(
              data: (allPredictions) {
                // Agrupamos por partido para mostrar los resultados
                final predictionsByMatch = <String, List<Prediction>>{};
                for (var p in allPredictions) {
                  predictionsByMatch.putIfAbsent(p.matchId, () => []).add(p);
                }

                return ListView(
                  children: predictionsByMatch.entries.map((entry) {
                    final matchId = entry.key;
                    final predictions = entry.value;

                    // VALIDACIÓN: ¿El usuario actual predijo este partido?
                    final userHasPredicted = predictions.any(
                      (p) => p.userId == currentUserId,
                    );

                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ExpansionTile(
                        title: Text("Partido: $matchId"),
                        subtitle: Text(
                          userHasPredicted
                              ? "${predictions.length} predicciones realizadas"
                              : "Debes realizar tu predicción para ver las de los demás",
                        ),
                        children: [
                          if (userHasPredicted)
                            ...predictions.map(
                              (p) => ListTile(
                                title: Text(
                                  "Usuario: ${p.userId.substring(0, 5)}...",
                                ),
                                trailing: Text(
                                  "${p.homeGuess} - ${p.awayGuess}",
                                ),
                              ),
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                "🔒 Contenido bloqueado",
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text("Error: $e")),
            ),
          ],
        ),
      ),
    );
  }
}
