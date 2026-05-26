import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../leagues_provider.dart';

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
      data: (leagues) {
        return DropdownButton<String>(
          hint: const Text('Todas las ligas'),
          value: selectedLeagueId,
          isExpanded: true,
          items: [
            if (showAllOption)
              const DropdownMenuItem(value: null, child: Text('Todas')),
            ...leagues.map((league) {
              final id = league['id'] as String;
              final shortName =
                  league['shortName'] as String? ??
                  league['name'] as String? ??
                  'Sin nombre';
              final country = league['country'] as String? ?? '';
              final logo = league['logo'] as String?;

              return DropdownMenuItem(
                value: id,
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: logo != null && logo.trim().isNotEmpty
                          ? Image.network(
                              logo,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.sports_soccer, size: 20),
                            )
                          : const Icon(Icons.sports_soccer, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        shortName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (country.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '($country)',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
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
      error: (error, _) =>
          Text('Error: $error', style: const TextStyle(color: Colors.red)),
    );
  }
}
