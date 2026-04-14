import 'package:flutter/material.dart';

import '../providers/quiz_provider.dart';
import 'wrong_questions_screen.dart';

class ResultScreen extends StatelessWidget {
  final QuizResult result;
  const ResultScreen({super.key, required this.result});

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
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
                    Text('Score: ${result.score}/720',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                        'Accuracy: ${result.accuracyPercent.toStringAsFixed(2)}%'),
                    Text(
                        'Correct: ${result.correct} | Wrong: ${result.wrong} | Unattempted: ${result.unattempted}'),
                    Text('Time taken: ${_formatTime(result.timeTaken)}'),
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
}
