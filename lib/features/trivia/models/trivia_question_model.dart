import 'package:cloud_firestore/cloud_firestore.dart';

class TriviaQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctAnswer; // índice 0-3
  final String category;
  final int points;
  final bool active;
  final DateTime createdAt;

  TriviaQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.category,
    required this.points,
    required this.active,
    required this.createdAt,
  });

  factory TriviaQuestion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TriviaQuestion(
      id: doc.id,
      question: data['question'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      correctAnswer: data['correctAnswer'] ?? 0,
      category: data['category'] ?? 'general',
      points: data['points'] ?? 1,
      active: data['active'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      'category': category,
      'points': points,
      'active': active,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class TriviaAnswer {
  final String id;
  final String userId;
  final String questionId;
  final int selectedOption;
  final bool isCorrect;
  final int pointsEarned;
  final int streakAtAnswer;
  final DateTime answeredAt;

  TriviaAnswer({
    required this.id,
    required this.userId,
    required this.questionId,
    required this.selectedOption,
    required this.isCorrect,
    required this.pointsEarned,
    required this.streakAtAnswer,
    required this.answeredAt,
  });

  factory TriviaAnswer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TriviaAnswer(
      id: doc.id,
      userId: data['userId'] ?? '',
      questionId: data['questionId'] ?? '',
      selectedOption: data['selectedOption'] ?? 0,
      isCorrect: data['isCorrect'] ?? false,
      pointsEarned: data['pointsEarned'] ?? 0,
      streakAtAnswer: data['streakAtAnswer'] ?? 0,
      answeredAt:
          (data['answeredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'questionId': questionId,
      'selectedOption': selectedOption,
      'isCorrect': isCorrect,
      'pointsEarned': pointsEarned,
      'streakAtAnswer': streakAtAnswer,
      'answeredAt': Timestamp.fromDate(answeredAt),
    };
  }
}
