import 'package:flutter/material.dart';
import '../services/remote_questions_service.dart';

class RemoteQuestionPreviewScreen extends StatelessWidget {
  const RemoteQuestionPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const service = RemoteQuestionsService();

    return Scaffold(
      appBar: AppBar(title: const Text('Render Quiz Preview')),
      body: Center(
        child: FutureBuilder<List<dynamic>>(
          future: service.fetchQuestions(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }

            if (snapshot.hasError) {
              return const Text('Error loading quiz');
            }

            final questions = snapshot.data ?? const <dynamic>[];
            if (questions.isEmpty) {
              return const Text('No questions found');
            }

            final first = questions.first;
            if (first is! Map) {
              return const Text('Invalid question format');
            }

            final question = first.cast<dynamic, dynamic>();
            final optionsRaw = question['options'];
            final options = optionsRaw is List
                ? optionsRaw.map((e) => e.toString()).toList()
                : const <String>[];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question['question_text']?.toString() ?? 'Untitled question',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final option in options)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text('• $option'),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
