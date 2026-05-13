import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/match_model.dart';

class MatchCard extends StatelessWidget {
  final FootballMatch match;
  const MatchCard({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        title: Text('${match.homeTeam} vs ${match.awayTeam}'),
        subtitle: Text(
          '${match.phase} - ${match.kickoff.day}/${match.kickoff.month}',
        ),
        trailing: match.status == MatchStatus.finished
            ? Text('${match.homeScore} - ${match.awayScore}')
            : const Icon(Icons.chevron_right),
        onTap: () => context.push('/match/${match.id}'),
      ),
    );
  }
}
