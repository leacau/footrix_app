import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/trivia_question_model.dart';

final triviaQuestionsProvider = FutureProvider<List<TriviaQuestion>>((ref) async {
  final result = await FirebaseFunctions.instance
      .httpsCallable('getTriviaQuestions')
      .call();
  final data = Map<String, dynamic>.from(result.data as Map);
  final questions = List<dynamic>.from(data['questions'] as List? ?? []);
  return questions
      .map((q) => TriviaQuestion.fromCallable(Map<String, dynamic>.from(q as Map)))
      .where((q) => q.options.length >= 4)
      .toList();
});

final userTriviaHistoryProvider = StreamProvider<List<TriviaAnswer>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('trivia_answers')
      .where('userId', isEqualTo: uid)
      .orderBy('answeredAt', descending: true)
      .limit(20)
      .snapshots()
      .map(
        (snap) => snap.docs.map((d) => TriviaAnswer.fromFirestore(d)).toList(),
      );
});

class TriviaSubmitResult {
  final bool isCorrect;
  final bool alreadyAnswered;
  final int pointsEarned;
  final int correctAnswer;
  final int streak;

  const TriviaSubmitResult({
    required this.isCorrect,
    required this.alreadyAnswered,
    required this.pointsEarned,
    required this.correctAnswer,
    required this.streak,
  });

  factory TriviaSubmitResult.fromMap(Map<String, dynamic> data) {
    return TriviaSubmitResult(
      isCorrect: data['isCorrect'] == true,
      alreadyAnswered: data['alreadyAnswered'] == true,
      pointsEarned: data['pointsEarned'] as int? ?? 0,
      correctAnswer: data['correctAnswer'] as int? ?? 0,
      streak: data['streak'] as int? ?? 0,
    );
  }
}

final submitTriviaAnswerProvider =
    FutureProvider.family<
      TriviaSubmitResult,
      ({String questionId, int selectedOption})
    >((ref, params) async {
      final result = await FirebaseFunctions.instance
          .httpsCallable('submitTriviaAnswer')
          .call({
            'questionId': params.questionId,
            'selectedOption': params.selectedOption,
          });
      return TriviaSubmitResult.fromMap(
        Map<String, dynamic>.from(result.data as Map),
      );
    });
