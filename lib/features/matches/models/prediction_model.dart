import 'package:cloud_firestore/cloud_firestore.dart';

class Prediction {
  final String id;
  final String userId;
  final String matchId;
  final int homeGuess;
  final int awayGuess;
  final int? totalGoalsGuess;
  final bool? penaltiesGuess;
  final DateTime submittedAt;
  final int? pointsEarned;
  final String status;

  Prediction({
    required this.id,
    required this.userId,
    required this.matchId,
    required this.homeGuess,
    required this.awayGuess,
    this.totalGoalsGuess,
    this.penaltiesGuess,
    required this.submittedAt,
    this.pointsEarned,
    this.status = 'pending',
  });

  factory Prediction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Prediction(
      id: doc.id,
      userId: data['userId'] ?? '',
      matchId: data['matchId'] ?? '',
      homeGuess: data['homeGuess'] ?? 0,
      awayGuess: data['awayGuess'] ?? 0,
      totalGoalsGuess: data['totalGoalsGuess'] as int?,
      penaltiesGuess: data['penaltiesGuess'] as bool?,
      submittedAt: (data['submittedAt'] as Timestamp).toDate(),
      pointsEarned: data['pointsEarned'] as int?,
      status: data['status'] ?? 'pending',
    );
  }
}
