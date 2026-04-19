import 'package:flutter/material.dart';

import '../providers/quiz_provider.dart';
import 'wrong_questions_screen.dart';

class ResultScreen extends StatelessWidget {
  final QuizResult? result;
  final int? score;
  final int? total;
  final List? questions;
  final Map<int, int>? answers;

  const ResultScreen({
    super.key,
    this.result,
    this.score,
    this.total,
    this.questions,
    this.answers,
  }) : assert(
          result != null ||
              (score != null &&
                  total != null &&
                  questions != null &&
                  answers != null),
        );

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (result != null) {
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
                      Text('Score: ${result!.score}/720',
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                          'Accuracy: ${result!.accuracyPercent.toStringAsFixed(2)}%'),
                      Text(
                          'Correct: ${result!.correct} | Wrong: ${result!.wrong} | Unattempted: ${result!.unattempted}'),
                      Text('Time taken: ${_formatTime(result!.timeTaken)}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
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

    final localScore = score ?? 0;
    final localTotal = total ?? 0;
    final localQuestions = questions ?? const [];
    final localAnswers = answers ?? const <int, int>{};

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Score: $localScore / $localTotal',
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: localTotal,
                itemBuilder: (context, index) {
                  final q = localQuestions[index];
                  final correctIndex = q['correct_answer'].toString().codeUnitAt(0) - 65;
                  final selected = localAnswers[index];

                  return Card(
                    child: ListTile(
                      title: Text('Q${index + 1}'),
                      subtitle: Text(
                        selected == correctIndex ? 'Correct' : 'Wrong',
                      ),
                      trailing: Text('Ans: ${q['correct_answer']}'),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
