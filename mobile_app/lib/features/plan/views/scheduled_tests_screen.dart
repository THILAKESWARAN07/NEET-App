import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../quiz/views/quiz_screen.dart';

class ScheduledTestsScreen extends ConsumerStatefulWidget {
  const ScheduledTestsScreen({super.key});

  @override
  ConsumerState<ScheduledTestsScreen> createState() =>
      _ScheduledTestsScreenState();
}

class _ScheduledTestsScreenState extends ConsumerState<ScheduledTestsScreen> {
  List<dynamic> tests = const [];
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await ref.read(dioProvider).get('/quiz/scheduled-tests');
      setState(() {
        tests = response.data as List<dynamic>;
        error = null;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    }
  }

  String _formatDuration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    return '${h}h ${m}m';
  }

  String _formatCountdown(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _startTest(Map<String, dynamic> item) async {
    final testType = (item['test_type'] ?? 'full').toString();
    final subject = item['subject']?.toString();

    if (!mounted) {
      return;
    }

    if (testType == 'subject') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuizScreen(
            mode: QuizStartMode.subject,
            subject: subject,
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const QuizScreen(mode: QuizStartMode.full),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scheduled Tests')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: error != null
            ? ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text(error!)),
                ],
              )
            : tests.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('No upcoming tests scheduled.')),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: tests.length,
                    itemBuilder: (context, index) {
                      final item = tests[index] as Map<String, dynamic>;
                      final status = (item['status'] ?? 'upcoming').toString();
                      final scheduledAt =
                          DateTime.parse(item['scheduled_at'].toString())
                              .toLocal();
                      final secondsToStart =
                          (item['seconds_to_start'] as num?)?.toInt() ?? 0;
                      final duration =
                          (item['duration_seconds'] as num?)?.toInt() ?? 0;
                      final isLive = status == 'live';

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item['title'].toString(),
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  Chip(
                                    label: Text(isLive ? 'LIVE' : 'UPCOMING'),
                                    backgroundColor: isLive
                                        ? Colors.red.withValues(alpha: 0.15)
                                        : Colors.blue.withValues(alpha: 0.15),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Type: ${item['test_type']}'),
                              if (item['subject'] != null)
                                Text('Subject: ${item['subject']}'),
                              Text('Starts: ${scheduledAt.toString()}'),
                              Text('Duration: ${_formatDuration(duration)}'),
                              if (!isLive)
                                Text(
                                    'Starts in: ${_formatCountdown(secondsToStart)}'),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed:
                                      isLive ? () => _startTest(item) : null,
                                  child: Text(isLive
                                      ? 'Start Test Now'
                                      : 'Available At Scheduled Time'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
