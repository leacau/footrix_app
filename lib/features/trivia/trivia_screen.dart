import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'models/trivia_question_model.dart';
import 'trivia_provider.dart';

class TriviaScreen extends ConsumerStatefulWidget {
  const TriviaScreen({super.key});

  @override
  ConsumerState<TriviaScreen> createState() => _TriviaScreenState();
}

class _TriviaScreenState extends ConsumerState<TriviaScreen> {
  TriviaQuestion? _currentQuestion;
  int? _selectedOption;
  int? _revealedCorrectAnswer;
  bool _answered = false;
  bool _submitting = false;
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
    if (_answered || _submitting) return;
    setState(() {
      _answered = true;
      _feedback = AppLocalizations.of(context)!.timeUp;
      _feedbackColor = Colors.orange;
    });
  }

  Future<void> _selectOption(int index) async {
    final l10n = AppLocalizations.of(context)!;
    if (_answered || _submitting || _currentQuestion == null) return;

    setState(() {
      _selectedOption = index;
      _submitting = true;
      _timer?.cancel();
    });

    try {
      final result = await ref.read(
        submitTriviaAnswerProvider((
          questionId: _currentQuestion!.id,
          selectedOption: index,
        )).future,
      );

      if (!mounted) return;
      setState(() {
        _answered = true;
        _submitting = false;
        _revealedCorrectAnswer = result.correctAnswer;
        if (result.alreadyAnswered) {
          _feedback = l10n.alreadyAnsweredQuestion;
          _feedbackColor = Colors.orange;
        } else if (result.isCorrect) {
          _feedback = l10n.correctPoints(result.pointsEarned);
          _feedbackColor = Colors.green;
        } else {
          _feedback = l10n.incorrect;
          _feedbackColor = Colors.red;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _selectedOption = null;
        });
      }
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${l10n.error}: $e')));
      }
      _startTimer();
    }
  }

  void _nextQuestion() {
    ref.invalidate(triviaQuestionsProvider);
    setState(() {
      _currentQuestion = null;
      _selectedOption = null;
      _revealedCorrectAnswer = null;
      _answered = false;
      _submitting = false;
      _feedback = null;
      _feedbackColor = null;
    });
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final questionsAsync = ref.watch(triviaQuestionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.footballTrivia)),
      body: questionsAsync.when(
        data: (questions) {
          if (questions.isEmpty) {
            return Center(child: Text(l10n.noQuestionsAvailable));
          }

          _currentQuestion ??=
              questions[DateTime.now().millisecondsSinceEpoch %
                  questions.length];

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
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
                        l10n.secondsLeft(_timeLeft),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _timeLeft <= 3 ? Colors.red : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
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
                ...List.generate(4, (index) {
                  final option = _currentQuestion!.options[index];
                  final isSelected = _selectedOption == index;
                  final isCorrect = _revealedCorrectAnswer == index;
                  final showResult = _answered;

                  Color? optionColor;
                  if (showResult) {
                    if (isCorrect) {
                      optionColor = Colors.green.shade100;
                    } else if (isSelected) {
                      optionColor = Colors.red.shade100;
                    }
                  } else if (isSelected) {
                    optionColor = Colors.blue.shade100;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ElevatedButton(
                      onPressed: (_answered || _submitting)
                          ? null
                          : () => _selectOption(index),
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
                          if (_submitting && isSelected)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
                if (_answered)
                  ElevatedButton.icon(
                    onPressed: _nextQuestion,
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(l10n.nextQuestion),
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
        error: (e, _) => Center(child: Text('${l10n.error}: $e')),
      ),
    );
  }
}
