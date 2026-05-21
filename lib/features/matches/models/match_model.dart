import 'package:cloud_firestore/cloud_firestore.dart';

enum MatchStatus { scheduled, live, finished }

class FootballMatch {
  final String id;
  final String homeTeam;
  final String awayTeam;
  final String phase;
  final DateTime?
  kickoff; // ✅ CAMBIO: nullable porque la API puede no enviar fecha
  final MatchStatus status;
  final int? homeScore;
  final int? awayScore;
  final int? homeYellowCards;
  final int? awayYellowCards;
  final bool hasPenalties;
  final int? lockHoursBefore;
  final String? leagueId; // ✅ Agregado para filtros por liga

  FootballMatch({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.phase,
    this.kickoff, // ✅ Opcional
    this.status = MatchStatus.scheduled,
    this.homeScore,
    this.awayScore,
    this.homeYellowCards,
    this.awayYellowCards,
    this.hasPenalties = false,
    this.lockHoursBefore,
    this.leagueId,
  });

  factory FootballMatch.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // ✅ Manejo seguro de kickoff nullable
    Timestamp? kickoffTimestamp = data['kickoff'] as Timestamp?;
    DateTime? kickoffDate = kickoffTimestamp?.toDate();

    return FootballMatch(
      id: doc.id,
      homeTeam: data['homeTeam'] ?? '',
      awayTeam: data['awayTeam'] ?? '',
      phase: data['phase'] ?? '',
      kickoff: kickoffDate, // ✅ Puede ser null
      status: _statusFromString(data['status']),
      homeScore: data['homeScore'] as int?,
      awayScore: data['awayScore'] as int?,
      homeYellowCards: data['homeYellowCards'] as int?,
      awayYellowCards: data['awayYellowCards'] as int?,
      hasPenalties: data['hasPenalties'] ?? false,
      lockHoursBefore: data['lockHoursBefore'] as int?,
      leagueId: data['leagueId'] as String?,
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
      if (kickoff != null) 'kickoff': Timestamp.fromDate(kickoff!),
      'status': status.name,
      if (homeScore != null) 'homeScore': homeScore,
      if (awayScore != null) 'awayScore': awayScore,
      if (homeYellowCards != null) 'homeYellowCards': homeYellowCards,
      if (awayYellowCards != null) 'awayYellowCards': awayYellowCards,
      'hasPenalties': hasPenalties,
      if (lockHoursBefore != null) 'lockHoursBefore': lockHoursBefore,
      if (leagueId != null) 'leagueId': leagueId,
    };
  }

  // ✅ isLocked maneja kickoff nullable
  bool get isLocked {
    if (kickoff == null) return false; // Si no hay fecha, no se puede bloquear
    return DateTime.now().isAfter(kickoff!);
  }
}
