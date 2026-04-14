import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

class StudyPlanScreen extends ConsumerStatefulWidget {
  const StudyPlanScreen({super.key});

  @override
  ConsumerState<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends ConsumerState<StudyPlanScreen> {
  Map<String, dynamic>? plan;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await ref.read(dioProvider).get('/quiz/study-plan');
      setState(() {
        plan = response.data as Map<String, dynamic>;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(appBar: AppBar(title: const Text('Daily Study Plan')), body: Center(child: Text(error!)));
    }
    if (plan == null) {
      return Scaffold(appBar: AppBar(title: const Text('Daily Study Plan')), body: const Center(child: CircularProgressIndicator()));
    }

    final items = (plan!['items'] as List<dynamic>).cast<Map<String, dynamic>>();
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Study Plan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Date: ${plan!['date']}'),
          Text('Revision: ${plan!['revision_minutes']} mins'),
          Text('Recommendation: ${plan!['mock_test_recommendation']}'),
          const SizedBox(height: 16),
          ...items.map(
            (item) => Card(
              child: ListTile(
                title: Text(item['subject'].toString()),
                subtitle: Text('Focus: ${item['focus_topic']}\nQuestions: ${item['recommended_questions']}'),
                trailing: Text('${item['target_accuracy']}%'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
