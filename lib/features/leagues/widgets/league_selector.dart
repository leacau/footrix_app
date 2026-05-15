import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../leagues_provider.dart';
// ✅ El import de league_model.dart NO es necesario aquí porque usamos dynamic del provider
// import '../models/league_model.dart'; // ← Comentado para evitar warning

class LeagueSelector extends ConsumerWidget {
  final String? selectedLeagueId;
  final ValueChanged<String?> onLeagueSelected;
  final bool showAllOption;

  const LeagueSelector({
    super.key,
    this.selectedLeagueId,
    required this.onLeagueSelected,
    this.showAllOption = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaguesAsync = ref.watch(leaguesProvider);

    return leaguesAsync.when(
      // ✅ CORRECCIÓN CLAVE: 'data:' debe estar ESCRITO explícitamente
      data: (List<dynamic> leagues) {
        return DropdownButton<String>(
          hint: const Text('Todas las ligas'),
          value: selectedLeagueId,
          isExpanded: true,
          items: [
            if (showAllOption)
              const DropdownMenuItem(value: null, child: Text('🌍 Todas')),
            ...leagues.map((league) {
              // ✅ Cast seguro a Map para acceder a los campos
              final data = league as Map<String, dynamic>;
              final id = data['id'] as String;
              final shortName =
                  data['shortName'] as String? ??
                  data['name'] as String? ??
                  'Sin nombre';
              final country = data['country'] as String? ?? '';
              final logo = data['logo'] as String?;

              return DropdownMenuItem(
                value: id,
                child: Row(
                  children: [
                    if (logo != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          logo,
                          width: 20,
                          height: 20,
                          // ✅ CORRECCIÓN: usar '_' simple para todos los parámetros no usados
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.sports_soccer, size: 20),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(shortName)),
                    Text(
                      '($country)',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }),
          ],
          onChanged: (value) {
            if (value != selectedLeagueId) {
              onLeagueSelected(value);
            }
          },
        );
      },
      loading: () => const SizedBox(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (Object e, StackTrace _) =>
          Text('Error: $e', style: const TextStyle(color: Colors.red)),
    );
  }
}
