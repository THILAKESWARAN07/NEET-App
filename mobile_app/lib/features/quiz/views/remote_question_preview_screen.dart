import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/utils/latex_renderer.dart';
import '../../../services/question_service.dart';
import 'result_screen.dart';

class RemoteQuestionPreviewScreen extends StatefulWidget {
  const RemoteQuestionPreviewScreen({super.key});

  @override
  State<RemoteQuestionPreviewScreen> createState() =>
      _RemoteQuestionPreviewScreenState();
}

class _RemoteQuestionPreviewScreenState
    extends State<RemoteQuestionPreviewScreen> {
  static const int _mockTestDurationSeconds = 3 * 60 * 60;
  Timer? _timer;
  bool _loading = true;
  String? _errorMessage;
  List<dynamic> _questions = const [];
  int _currentIndex = 0;
  int? _selectedOptionIndex;
  final Map<int, int> _selectedAnswers = {};
  int _remainingSeconds = _mockTestDurationSeconds;
  bool _isSubmitted = false;

  ({int score, int correct, int wrong, int unattempted, double accuracyPercent})
      _calculateStats(List questions, Map<int, int> selectedAnswers) {
    int correct = 0;
    int wrong = 0;
    int unattempted = 0;

    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final correctIndex = q['correct_answer'].toString().codeUnitAt(0) - 65;
      final selected = selectedAnswers[i];

      if (selected == null) {
        unattempted++;
      } else if (selected == correctIndex) {
        correct++;
      } else {
        wrong++;
      }
    }

    final score = (correct * 4) - wrong;
    final attempted = correct + wrong;
    final accuracyPercent =
        attempted == 0 ? 0.0 : (correct / attempted) * 100.0;

    return (
      score: score,
      correct: correct,
      wrong: wrong,
      unattempted: unattempted,
      accuracyPercent: accuracyPercent,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuestions({bool isRefresh = false}) async {
    final preservedQuestionId = isRefresh && _questions.isNotEmpty
        ? _questions[_currentIndex]['id']?.toString()
        : null;
    final preservedIndex = _currentIndex;
    final preservedRemainingSeconds = _remainingSeconds;
    final preservedSelectedAnswers = isRefresh
        ? Map<int, int>.from(_selectedAnswers)
        : <int, int>{};

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final questions = await QuestionService.fetchQuestions();
      if (!mounted) {
        return;
      }

      setState(() {
        _questions = questions;
        if (isRefresh) {
          _selectedAnswers
            ..clear()
            ..addAll(preservedSelectedAnswers);

          if (questions.isEmpty) {
            _currentIndex = 0;
            _selectedOptionIndex = null;
          } else {
            final restoredIndex = preservedQuestionId == null
                ? preservedIndex
                : questions.indexWhere(
                    (question) => question['id']?.toString() == preservedQuestionId,
                  );
            _currentIndex = restoredIndex >= 0
                ? restoredIndex
                : preservedIndex.clamp(0, questions.length - 1);
            _selectedOptionIndex = _selectedAnswers[_currentIndex];
          }
          _remainingSeconds = preservedRemainingSeconds;
        } else {
          _currentIndex = 0;
          _selectedOptionIndex = null;
          _selectedAnswers.clear();
          _remainingSeconds = _mockTestDurationSeconds;
          _isSubmitted = false;
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
        _loading = false;
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        _autoSubmit();
      }
    });
  }

  String formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final normalizedMinutes = m % 60;
    return '${h.toString().padLeft(2, '0')}:${normalizedMinutes.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _goNextQuestion() {
    if (_questions.isEmpty || _currentIndex >= _questions.length - 1) {
      return;
    }
    setState(() {
      _currentIndex = _currentIndex + 1;
      _selectedOptionIndex = _selectedAnswers[_currentIndex];
    });
  }

  void _goPreviousQuestion() {
    if (_questions.isEmpty || _currentIndex <= 0) {
      return;
    }
    setState(() {
      _currentIndex = _currentIndex - 1;
      _selectedOptionIndex = _selectedAnswers[_currentIndex];
    });
  }

  List<Map<String, dynamic>> _buildQuestionAttemptsPayload() {
    final attempts = <Map<String, dynamic>>[];
    for (int index = 0; index < _questions.length; index++) {
      final question = _questions[index] as Map<String, dynamic>;
      final questionId = question['id'] as int?;
      if (questionId == null) {
        continue;
      }

      final selectedOptionIndex = _selectedAnswers[index];
      String? selectedOption;
      if (selectedOptionIndex != null) {
        final options = (question['options'] as List<dynamic>)
            .map((e) => e.toString())
            .toList();
        if (selectedOptionIndex >= 0 && selectedOptionIndex < options.length) {
          selectedOption = options[selectedOptionIndex];
        }
      }

      attempts.add({
        'question_id': questionId,
        'selected_option': selectedOption,
      });
    }

    return attempts;
  }

  void _submitQuiz() {
    if (_questions.isEmpty || _isSubmitted) {
      return;
    }

    _timer?.cancel();
    setState(() {
      _isSubmitted = true;
    });

    final stats = _calculateStats(_questions, _selectedAnswers);
    final timeInSeconds = _mockTestDurationSeconds - _remainingSeconds;

    // Save score to backend (non-blocking)
    QuestionService.submitQuizScore(
      score: stats.score,
      total: _questions.length,
      timeInSeconds: timeInSeconds,
      durationSeconds: _mockTestDurationSeconds,
      testType: 'json_mock',
      accuracyPercent: stats.accuracyPercent,
      questionAttempts: _buildQuestionAttemptsPayload(),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          score: stats.score,
          total: _questions.length,
          questions: _questions,
          answers: _selectedAnswers,
        ),
      ),
    );
  }

  void _autoSubmit() {
    if (_isSubmitted || _questions.isEmpty) {
      return;
    }

    setState(() {
      _isSubmitted = true;
    });
    final stats = _calculateStats(_questions, _selectedAnswers);
    final timeInSeconds = _mockTestDurationSeconds - _remainingSeconds;

    // Save score to backend (non-blocking)
    QuestionService.submitQuizScore(
      score: stats.score,
      total: _questions.length,
      timeInSeconds: timeInSeconds,
      durationSeconds: _mockTestDurationSeconds,
      testType: 'json_mock',
      accuracyPercent: stats.accuracyPercent,
      questionAttempts: _buildQuestionAttemptsPayload(),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          score: stats.score,
          total: _questions.length,
          questions: _questions,
          answers: _selectedAnswers,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasQuestions = _questions.isNotEmpty;
    final currentQuestion = hasQuestions ? _questions[_currentIndex] : null;
    final currentOptions = hasQuestions ? currentQuestion['options'] as List : const [];
    final currentSelectedAnswer = _selectedAnswers[_currentIndex];
    final currentCorrectIndex = hasQuestions
        ? currentQuestion['correct_answer'].toString().codeUnitAt(0) - 65
        : -1;
    final currentAnswered = currentSelectedAnswer != null;
    final canGoPrevious = _currentIndex > 0;
    final canGoNext = _currentIndex < _questions.length - 1;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quiz'),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(28),
            child: Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Marking: +4 correct | -1 wrong | 0 unattempted',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  formatTime(_remainingSeconds),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _loadQuestions(isRefresh: true),
            ),
          ],
        ),
        body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Failed to load questions'),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadQuestions,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : !hasQuestions
                  ? const Center(child: Text('No questions available'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Question ${_currentIndex + 1}/${_questions.length}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          safeMath(
                            currentQuestion['question_text'].toString(),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (currentQuestion['image_url'] != null &&
                              currentQuestion['image_url'].toString().isNotEmpty)
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return Center(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: constraints.maxWidth,
                                      maxHeight: 320,
                                    ),
                                    child: InteractiveViewer(
                                      boundaryMargin:
                                          const EdgeInsets.all(24),
                                      minScale: 0.8,
                                      maxScale: 4,
                                      child: Image.network(
                                        currentQuestion['image_url']
                                            .toString(),
                                        width: constraints.maxWidth,
                                        fit: BoxFit.contain,
                                        alignment: Alignment.center,
                                        errorBuilder: (_, __, ___) => const Text(
                                          'Image failed to load',
                                        ),
                                        loadingBuilder:
                                            (context, child, progress) {
                                          if (progress == null) return child;
                                          return const Center(
                                            child: CircularProgressIndicator(),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: 16),
                          ...List.generate(currentOptions.length, (index) {
                            final label = String.fromCharCode(65 + index);
                            final isSelected = _selectedOptionIndex == index;
                            final isAnswered = currentAnswered;
                            final isCorrect = index == currentCorrectIndex;
                            final backgroundColor = isAnswered
                                ? isCorrect
                                ? Colors.green.shade800
                                    : isSelected
                                  ? Colors.red.shade800
                                        : null
                                : isSelected
                                    ? Colors.blue.shade100
                                    : null;
                            final textColor = backgroundColor == null
                              ? null
                              : (isAnswered ? Colors.white : Colors.black);

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              color: backgroundColor,
                              child: ListTile(
                                leading: Text(
                                  label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.normal,
                                    color: textColor,
                                  ),
                                ),
                                title: safeMath(
                                  currentOptions[index].toString(),
                                  textStyle: TextStyle(
                                    fontWeight: FontWeight.normal,
                                    color: textColor,
                                  ),
                                ),
                                onTap: isAnswered
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedOptionIndex = index;
                                          _selectedAnswers[_currentIndex] = index;
                                        });
                                      },
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: canGoPrevious ? _goPreviousQuestion : null,
                                  child: const Text('Previous'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: canGoNext ? _goNextQuestion : null,
                                  child: const Text('Next'),
                                ),
                              ),
                            ],
                          ),
                          if (currentAnswered) ...[
                            const SizedBox(height: 20),
                            const Text(
                              'Explanation:',
                              style: TextStyle(fontWeight: FontWeight.normal, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            safeMath(
                              currentQuestion['explanation'].toString(),
                              textStyle: const TextStyle(fontWeight: FontWeight.normal),
                            ),
                          ],
                        ],
                      ),
                    ),
      bottomNavigationBar: hasQuestions && !_loading && _errorMessage == null
          ? SafeArea(
              minimum: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _submitQuiz,
                child: const Text('Submit Quiz'),
              ),
            )
          : null,
      ),
    );
  }
}
