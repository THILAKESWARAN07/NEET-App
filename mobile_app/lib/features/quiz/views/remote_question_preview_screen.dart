import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

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
  Timer? _timer;
  bool _loading = true;
  String? _errorMessage;
  List<dynamic> _questions = const [];
  int _currentIndex = 0;
  int _lastIndex = -1;
  int? _selectedOptionIndex;
  final Map<int, int> _selectedAnswers = {};
  int _remainingSeconds = 180;
  bool _isSubmitted = false;

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
    setState(() {
      _loading = true;
      _errorMessage = null;
      if (isRefresh) {
        _selectedOptionIndex = null;
      }
    });

    try {
      final questions = await QuestionService.fetchQuestions();
      if (!mounted) {
        return;
      }

      setState(() {
        _questions = questions;
        _currentIndex = questions.isEmpty ? 0 : getRandomIndex(questions.length);
        _selectedOptionIndex = null;
        _selectedAnswers.clear();
        _isSubmitted = false;
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

  int getRandomIndex(int length) {
    int newIndex;
    do {
      newIndex = Random().nextInt(length);
    } while (newIndex == _lastIndex && length > 1);

    _lastIndex = newIndex;
    return newIndex;
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
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _goNextQuestion() {
    if (_questions.isEmpty) {
      return;
    }
    setState(() {
      _currentIndex = (_currentIndex + 1) % _questions.length;
      _selectedOptionIndex = _selectedAnswers[_currentIndex];
    });
  }

  void _goPreviousQuestion() {
    if (_questions.isEmpty) {
      return;
    }
    setState(() {
      _currentIndex = (_currentIndex - 1 + _questions.length) % _questions.length;
      _selectedOptionIndex = _selectedAnswers[_currentIndex];
    });
  }

  int calculateScore(List questions, Map<int, int> selectedAnswers) {
    int score = 0;

    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final correctIndex = q['correct_answer'].toString().codeUnitAt(0) - 65;

      if (selectedAnswers[i] == correctIndex) {
        score++;
      }
    }

    return score;
  }

  void _submitQuiz() {
    if (_questions.isEmpty || _isSubmitted) {
      return;
    }

    if (_selectedAnswers.length < _questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Answer all questions')),
      );
      return;
    }

    _timer?.cancel();
    _isSubmitted = true;

    final score = calculateScore(_questions, _selectedAnswers);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          score: score,
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

    _isSubmitted = true;
    final score = calculateScore(_questions, _selectedAnswers);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          score: score,
          total: _questions.length,
          questions: _questions,
          answers: _selectedAnswers,
        ),
      ),
    );
  }

  Widget safeMath(String text, {TextStyle? textStyle}) {
    try {
      return Math.tex(
        text,
        textStyle: textStyle,
      );
    } catch (_) {
      return Text(text, style: textStyle);
    }
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

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quiz'),
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
                            textStyle: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 12),
                          if (currentQuestion['image_url'] != null &&
                              currentQuestion['image_url'].toString().isNotEmpty)
                            InteractiveViewer(
                              child: Image.network(
                                currentQuestion['image_url'].toString(),
                                errorBuilder: (_, __, ___) => const Text(
                                  'Image failed to load',
                                ),
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 16),
                          ...List.generate(currentOptions.length, (index) {
                            final label = String.fromCharCode(65 + index);
                            final isSelected = _selectedOptionIndex == index;
                            final isAnswered = currentAnswered;
                            final isCorrect = index == currentCorrectIndex;
                            final backgroundColor = isAnswered
                                ? isCorrect
                                    ? Colors.green.shade100
                                    : isSelected
                                        ? Colors.red.shade100
                                        : null
                                : isSelected
                                    ? Colors.blue.shade100
                                    : null;

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              color: backgroundColor,
                              child: ListTile(
                                leading: Text(label),
                                title: safeMath(currentOptions[index].toString()),
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
                                  onPressed: _goPreviousQuestion,
                                  child: const Text('Previous'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _goNextQuestion,
                                  child: const Text('Next'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Explanation:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          safeMath(currentQuestion['explanation'].toString()),
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
