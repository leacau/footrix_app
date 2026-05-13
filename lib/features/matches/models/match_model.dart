import 'package:cloud_firestore/cloud_firestore.dart';

enum MatchStatus { scheduled, live, finished }

class FootballMatch {
  final String id;
  final String homeTeam;
  final String awayTeam;
  final String phase;
  final DateTime kickoff;
  final MatchStatus status;
  final int? homeScore;
  final int? awayScore;
  final int? homeYellowCards;
  final int? awayYellowCards;
  final bool hasPenalties;

  FootballMatch({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.phase,
    required this.kickoff,
    this.status = MatchStatus.scheduled,
    this.homeScore,
    this.awayScore,
    this.homeYellowCards,
    this.awayYellowCards,
    this.hasPenalties = false,
  });

  factory FootballMatch.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FootballMatch(
      id: doc.id,
      homeTeam: data['homeTeam'] ?? '',
      awayTeam: data['awayTeam'] ?? '',
      phase: data['phase'] ?? '',
      kickoff: (data['kickoff'] as Timestamp).toDate(),
      status: _statusFromString(data['status']),
      homeScore: data['homeScore'] as int?,
      awayScore: data['awayScore'] as int?,
      homeYellowCards: data['homeYellowCards'] as int?,
      awayYellowCards: data['awayYellowCards'] as int?,
      hasPenalties: data['hasPenalties'] ?? false,
    );
  }

  static MatchStatus _statusFromString(String? str) {
    switch (str) {
      case 'live':
        return MatchStatus.live;
      case 'finished':
        return MatchStatus.finished;
      default:
        return MatchStatus.scheduled;
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'phase': phase,
      'kickoff': Timestamp.fromDate(kickoff),
      'status': status.name,
      if (homeScore != null) 'homeScore': homeScore,
      if (awayScore != null) 'awayScore': awayScore,
      if (homeYellowCards != null) 'homeYellowCards': homeYellowCards,
      if (awayYellowCards != null) 'awayYellowCards': awayYellowCards,
      'hasPenalties': hasPenalties,
    };
  }

  bool get isLocked => DateTime.now().isAfter(kickoff);
}
