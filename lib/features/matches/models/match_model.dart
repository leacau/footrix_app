import 'package:cloud_firestore/cloud_firestore.dart';

enum MatchStatus { scheduled, live, finished }

class FootballMatch {
  final String id;
  final String homeTeam;
  final String awayTeam;
  final String phase;
  final DateTime? kickoff;
  final MatchStatus status;
  final int? homeScore;
  final int? awayScore;
  final int? homeYellowCards;
  final int? awayYellowCards;
  final bool hasPenalties;
  final int? lockHoursBefore;
  final String? leagueId;
  final String? venue;
  final String? venueCity;
  final String? homeTeamLogo;
  final String? awayTeamLogo;
  final String? competitionName;
  final String? competitionEmblem;
  final String? apiSource;

  FootballMatch({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.phase,
    this.kickoff,
    this.status = MatchStatus.scheduled,
    this.homeScore,
    this.awayScore,
    this.homeYellowCards,
    this.awayYellowCards,
    this.hasPenalties = false,
    this.lockHoursBefore,
    this.leagueId,
    this.venue,
    this.venueCity,
    this.homeTeamLogo,
    this.awayTeamLogo,
    this.competitionName,
    this.competitionEmblem,
    this.apiSource,
  });

  factory FootballMatch.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final kickoffTimestamp = data['kickoff'] as Timestamp?;

    return FootballMatch(
      id: doc.id,
      homeTeam: data['homeTeam'] ?? '',
      awayTeam: data['awayTeam'] ?? '',
      phase: data['phase'] ?? '',
      kickoff: kickoffTimestamp?.toDate(),
      status: _statusFromString(data['status']),
      homeScore: data['homeScore'] as int?,
      awayScore: data['awayScore'] as int?,
      homeYellowCards: data['homeYellowCards'] as int?,
      awayYellowCards: data['awayYellowCards'] as int?,
      hasPenalties: data['hasPenalties'] ?? false,
      lockHoursBefore: data['lockHoursBefore'] as int?,
      leagueId: data['leagueId'] as String?,
      venue: data['venue'] as String?,
      venueCity: data['venueCity'] as String?,
      homeTeamLogo: data['homeTeamLogo'] as String?,
      awayTeamLogo: data['awayTeamLogo'] as String?,
      competitionName: data['competitionName'] as String?,
      competitionEmblem: data['competitionEmblem'] as String?,
      apiSource: data['apiSource'] as String?,
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
      if (venue != null) 'venue': venue,
      if (venueCity != null) 'venueCity': venueCity,
      if (homeTeamLogo != null) 'homeTeamLogo': homeTeamLogo,
      if (awayTeamLogo != null) 'awayTeamLogo': awayTeamLogo,
      if (competitionName != null) 'competitionName': competitionName,
      if (competitionEmblem != null) 'competitionEmblem': competitionEmblem,
      if (apiSource != null) 'apiSource': apiSource,
    };
  }

  bool get isLocked {
    if (kickoff == null) return false;
    return DateTime.now().isAfter(kickoff!);
  }
}
