import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'trivia_provider.dart';
import 'models/trivia_question_model.dart';

class TriviaScreen extends ConsumerStatefulWidget {
  const TriviaScreen({super.key});

  @override
  ConsumerState<TriviaScreen> createState() => _TriviaScreenState();
}

class _TriviaScreenState extends ConsumerState<TriviaScreen> {
  TriviaQuestion? _currentQuestion;
  int? _selectedOption;
  bool _answered = false;
  int _timeLeft = 10;
  Timer? _timer;
  String? _feedback;
  Color? _feedbackColor;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timeLeft = 10;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0) {
          timer.cancel();
          _handleTimeout();
        }
      });
    });
  }

  void _handleTimeout() {
    if (_answered) return;
    setState(() {
      _answered = true;
      _feedback = '⏰ Tiempo agotado';
      _feedbackColor = Colors.orange;
    });
  }

  void _selectOption(int index) {
    if (_answered || _currentQuestion == null) return;

    setState(() {
      _selectedOption = index;
      _answered = true;
      _timer?.cancel();

      final isCorrect = index == _currentQuestion!.correctAnswer;
      if (isCorrect) {
        _feedback = '✅ ¡Correcto!';
        _feedbackColor = Colors.green;
      } else {
        _feedback = '❌ Incorrecto';
        _feedbackColor = Colors.red;
      }
    });

    _submitAnswer(index);
  }

  Future<void> _submitAnswer(int selectedOption) async {
    if (_currentQuestion == null) return;

    try {
      await ref.read(
        submitTriviaAnswerProvider((
          questionId: _currentQuestion!.id,
          selectedOption: selectedOption,
        )).future,
      );
    } catch (e) {
      // ✅ CORRECCIÓN: usar context.mounted cuando usás context
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _nextQuestion() {
    setState(() {
      _currentQuestion = null;
      _selectedOption = null;
      _answered = false;
      _feedback = null;
      _feedbackColor = null;
    });
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final questionsAsync = ref.watch(triviaQuestionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('🎮 Trivia Fútbol')),
      body: questionsAsync.when(
        // ✅ CORRECCIÓN CLAVE: 'data:' debe estar ESCRITO explícitamente
        data: (questions) {
          if (questions.isEmpty) {
            return const Center(child: Text('📭 No hay preguntas disponibles'));
          }

          // ✅ CORRECCIÓN: usar ??= para evitar warning prefer_conditional_assignment
          _currentQuestion ??=
              questions[DateTime.now().millisecondsSinceEpoch %
                  questions.length];

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Timer
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _timeLeft <= 3
                        ? Colors.red.shade100
                        : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '$_timeLeft segundos',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _timeLeft <= 3 ? Colors.red : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Pregunta
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _currentQuestion!.question,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Opciones
                ...List.generate(4, (index) {
                  final option = _currentQuestion!.options[index];
                  final isSelected = _selectedOption == index;
                  final isCorrect = index == _currentQuestion!.correctAnswer;
                  final showResult = _answered;

                  Color? optionColor;
                  if (showResult) {
                    if (isCorrect) {
                      optionColor = Colors.green.shade100;
                    } else if (isSelected && !isCorrect) {
                      optionColor = Colors.red.shade100;
                    }
                  } else if (isSelected) {
                    optionColor = Colors.blue.shade100;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ElevatedButton(
                      onPressed: _answered ? null : () => _selectOption(index),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: optionColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected
                                ? Colors.blue
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                String.fromCharCode(65 + index),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          if (showResult && isCorrect)
                            const Icon(Icons.check_circle, color: Colors.green),
                          if (showResult && isSelected && !isCorrect)
                            const Icon(Icons.close, color: Colors.red),
                        ],
                      ),
                    ),
                  );
                }),

                const Spacer(),

                // Feedback
                if (_feedback != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _feedbackColor?.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _feedbackColor ?? Colors.transparent,
                      ),
                    ),
                    child: Text(
                      _feedback!,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _feedbackColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Botón siguiente
                if (_answered)
                  ElevatedButton.icon(
                    onPressed: _nextQuestion,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Siguiente pregunta'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
