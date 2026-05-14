import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/trivia_question_model.dart';

final triviaQuestionsProvider = StreamProvider<List<TriviaQuestion>>((ref) {
  return FirebaseFirestore.instance
      .collection('trivia_questions')
      .where('active', isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map((d) => TriviaQuestion.fromFirestore(d)).toList(),
      );
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

final submitTriviaAnswerProvider =
    FutureProvider.family<void, ({String questionId, int selectedOption})>((
      ref,
      params,
    ) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No autenticado');

      final db = FirebaseFirestore.instance;

      // Obtener la pregunta para validar respuesta
      final questionDoc = await db
          .collection('trivia_questions')
          .doc(params.questionId)
          .get();
      if (!questionDoc.exists) throw Exception('Pregunta no encontrada');

      final question = TriviaQuestion.fromFirestore(questionDoc);
      final isCorrect = params.selectedOption == question.correctAnswer;

      // Obtener racha actual del usuario
      final userDoc = await db.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final currentStreak = userData['triviaStreak'] as int? ?? 0;

      // Calcular puntos: base + bonus por racha
      int pointsEarned = isCorrect ? question.points : 0;
      int newStreak = isCorrect ? currentStreak + 1 : 0;

      // Bonus: +1 punto extra por cada 3 aciertos seguidos
      if (isCorrect && newStreak > 0 && newStreak % 3 == 0) {
        pointsEarned += 1;
      }

      // Actualizar mejor racha si corresponde
      final bestStreak = userData['triviaBestStreak'] as int? ?? 0;
      final newBestStreak = newStreak > bestStreak ? newStreak : bestStreak;

      // Guardar respuesta
      final answerId = '${user.uid}_${params.questionId}';
      await db
          .collection('trivia_answers')
          .doc(answerId)
          .set(
            TriviaAnswer(
              id: answerId,
              userId: user.uid,
              questionId: params.questionId,
              selectedOption: params.selectedOption,
              isCorrect: isCorrect,
              pointsEarned: pointsEarned,
              streakAtAnswer: newStreak,
              answeredAt: DateTime.now(),
            ).toFirestore(),
          );

      // Actualizar stats del usuario
      await db.collection('users').doc(user.uid).update({
        'triviaPoints': FieldValue.increment(pointsEarned),
        'triviaStreak': newStreak,
        'triviaBestStreak': newBestStreak,
        'triviaAnswered': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
