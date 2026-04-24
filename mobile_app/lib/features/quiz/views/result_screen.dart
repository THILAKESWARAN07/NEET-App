import 'package:flutter/material.dart';

import '../../../core/utils/latex_renderer.dart';
import '../../../services/question_service.dart';
import '../providers/quiz_provider.dart';
import 'wrong_questions_screen.dart';

class ResultScreen extends StatefulWidget {
  final QuizResult? result;
  final int? score;
  final int? total;
  final List? questions;
  final Map<int, int>? answers;
  final bool initialSyncFailed;
  final int? timeInSeconds;
  final int durationSeconds;
  final String testType;
  final String? subject;

  const ResultScreen({
    super.key,
    this.result,
    this.score,
    this.total,
    this.questions,
    this.answers,
    this.initialSyncFailed = false,
    this.timeInSeconds,
    this.durationSeconds = 10800,
    this.testType = 'json_mock',
    this.subject,
  }) : assert(
          result != null ||
              (score != null &&
                  total != null &&
                  questions != null &&
                  answers != null),
        );

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isRetryingSync = false;
  late bool _syncFailed;

  @override
  void initState() {
    super.initState();
    _syncFailed = widget.initialSyncFailed;
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> _buildQuestionAttemptsPayload(
    List<dynamic> localQuestions,
    Map<int, int> localAnswers,
  ) {
    final attempts = <Map<String, dynamic>>[];
    for (int index = 0; index < localQuestions.length; index++) {
      final question = localQuestions[index] as Map<String, dynamic>;
      final questionId = question['id'] as int?;
      if (questionId == null) {
        continue;
      }

      final selectedOptionIndex = localAnswers[index];
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

  Future<void> _retrySync({
    required int localScore,
    required int localTotal,
    required double localAccuracy,
    required List<dynamic> localQuestions,
    required Map<int, int> localAnswers,
  }) async {
    if (_isRetryingSync || widget.result != null) {
      return;
    }

    setState(() {
      _isRetryingSync = true;
    });

    final synced = await QuestionService.submitQuizScore(
      score: localScore,
      total: localTotal,
      timeInSeconds: widget.timeInSeconds ?? 0,
      durationSeconds: widget.durationSeconds,
      testType: widget.testType,
      subject: widget.subject,
      accuracyPercent: localAccuracy,
      questionAttempts: _buildQuestionAttemptsPayload(localQuestions, localAnswers),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isRetryingSync = false;
      _syncFailed = !synced;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          synced
              ? 'Score synced successfully.'
              : 'Sync failed again. Please check internet and retry.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.result != null) {
      final backendQuestionResults = widget.result!.questionResults;
      return Scaffold(
        appBar: AppBar(title: const Text('Test Result')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('Score: ${widget.result!.score}/720',
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.normal, color: Colors.blue)),
                      const SizedBox(height: 8),
                      Text(
                        'Accuracy: ${widget.result!.accuracyPercent.toStringAsFixed(2)}%',
                          style: const TextStyle(fontWeight: FontWeight.normal)),
                      Text(
                        'Correct: ${widget.result!.correct} | Wrong: ${widget.result!.wrong} | Unattempted: ${widget.result!.unattempted}',
                          style: const TextStyle(fontWeight: FontWeight.normal)),
                      Text('Time taken: ${_formatTime(widget.result!.timeTaken)}',
                          style: const TextStyle(fontWeight: FontWeight.normal)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (backendQuestionResults.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: backendQuestionResults.length,
                    itemBuilder: (context, index) {
                      final item = backendQuestionResults[index];
                      final isUnattempted = item.status == 'unattempted';
                      final isCorrect = item.status == 'correct';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        color: isUnattempted
                            ? Colors.grey.shade200
                            : isCorrect
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                        child: ListTile(
                          title: Text(
                            'Q${item.questionNumber}',
                            style: const TextStyle(
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          subtitle: safeMath(
                            '${isUnattempted
                                ? 'Unattempted'
                                : isCorrect
                                    ? 'Correct (+4)'
                                    : 'Wrong (-1)'}\n'
                            'Your answer: ${item.selectedOption ?? 'Not Attempted'}',
                            textStyle: TextStyle(
                              fontWeight: FontWeight.normal,
                              color: isUnattempted
                                  ? Colors.black54
                                  : isCorrect
                                      ? Colors.green
                                      : Colors.red,
                            ),
                          ),
                          trailing: safeMath(
                            'Ans: ${item.correctAnswer}',
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WrongQuestionsScreen()),
                ),
                icon: const Icon(Icons.replay),
                label: const Text('Reattempt Wrong Questions'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Dashboard'),
              ),
            ],
          ),
        ),
      );
    }

    final localScore = widget.score ?? 0;
    final localTotal = widget.total ?? 0;
    final localQuestions = widget.questions ?? const [];
    final localAnswers = widget.answers ?? const <int, int>{};
    int localCorrect = 0;
    int localWrong = 0;
    int localUnattempted = 0;

    for (int index = 0; index < localTotal; index++) {
      final q = localQuestions[index];
      final correctIndex = q['correct_answer'].toString().codeUnitAt(0) - 65;
      final selected = localAnswers[index];
      if (selected == null) {
        localUnattempted++;
      } else if (selected == correctIndex) {
        localCorrect++;
      } else {
        localWrong++;
      }
    }
    final localAttempted = localCorrect + localWrong;
    final localAccuracy =
        localAttempted == 0 ? 0.0 : (localCorrect / localAttempted) * 100;
    final localMaxMarks = localTotal * 4;

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _syncFailed
                            ? Colors.orange.shade100
                            : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _syncFailed ? 'Sync Status: Pending' : 'Sync Status: Synced',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _syncFailed
                              ? Colors.orange.shade900
                              : Colors.green.shade900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Score: $localScore / $localMaxMarks',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.normal,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Accuracy: ${localAccuracy.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Correct: $localCorrect | Wrong: $localWrong | Unattempted: $localUnattempted',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: localTotal,
                itemBuilder: (context, index) {
                  final q = localQuestions[index];
                  final correctIndex = q['correct_answer'].toString().codeUnitAt(0) - 65;
                  final selected = localAnswers[index];
                  final isUnattempted = selected == null;
                  final isCorrect = selected == correctIndex;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    color: isUnattempted
                        ? Colors.grey.shade200
                        : isCorrect
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                    child: ListTile(
                      title: Text(
                        'Q${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.normal),
                      ),
                      subtitle: safeMath(
                        '${isUnattempted
                            ? 'Unattempted'
                            : isCorrect
                                ? 'Correct (+4)'
                                : 'Wrong (-1)'}\n'
                        'Your answer: ${selected == null ? 'Not Attempted' : String.fromCharCode(65 + selected)}',
                        textStyle: TextStyle(
                          fontWeight: FontWeight.normal,
                          color: isUnattempted
                              ? Colors.black54
                              : isCorrect
                                  ? Colors.green
                                  : Colors.red,
                        ),
                      ),
                      trailing: safeMath(
                        'Ans: ${q['correct_answer']}',
                        textStyle: const TextStyle(fontWeight: FontWeight.normal),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            if (_syncFailed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton.icon(
                  onPressed: _isRetryingSync
                      ? null
                      : () => _retrySync(
                            localScore: localScore,
                            localTotal: localTotal,
                            localAccuracy: localAccuracy,
                            localQuestions: localQuestions,
                            localAnswers: localAnswers,
                          ),
                  icon: const Icon(Icons.sync),
                  label: Text(_isRetryingSync ? 'Retrying Sync...' : 'Retry Score Sync'),
                ),
              ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}
