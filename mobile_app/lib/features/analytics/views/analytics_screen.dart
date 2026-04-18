import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  Map<String, dynamic>? data;
  String? error;

  String _formatDuration(int seconds) {
    final safeSeconds = seconds < 0 ? 0 : seconds;
    final h = safeSeconds ~/ 3600;
    final m = (safeSeconds % 3600) ~/ 60;
    final s = safeSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatAttemptedAt(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return 'Unknown time';
    }
    final local = parsed.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await ref.read(dioProvider).get('/quiz/analytics/dashboard');
      setState(() {
        data = response.data as Map<String, dynamic>;
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
      return Scaffold(
        appBar: AppBar(title: const Text('Analytics')),
        body: Center(child: Text(error!)),
      );
    }
    if (data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Analytics')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final overallAccuracy =
        (data!['overall_accuracy'] as num?)?.toDouble() ?? 0.0;
    final avgScore = (data!['avg_score'] as num?)?.toDouble() ?? 0.0;
    final completedTests = (data!['completed_tests'] as num?)?.toInt() ?? 0;
    final inProgressTests = (data!['in_progress_tests'] as num?)?.toInt() ?? 0;
    final trend = (data!['trend'] as List<dynamic>).cast<Map<String, dynamic>>();

    // Composite readiness index scaled to 0-100.
    final readiness =
        (((overallAccuracy / 100.0) * 0.45) + ((avgScore / 720.0) * 0.55)) * 100;

    final weakTopics =
        (data!['weak_topics'] as List<dynamic>).map((e) => e.toString()).toList();
    final strongTopics =
        (data!['strong_topics'] as List<dynamic>).map((e) => e.toString()).toList();
    final subjectStrength = _buildSubjectStrength(
      weakTopics: weakTopics,
      strongTopics: strongTopics,
    );

    final spots = <FlSpot>[];
    double highestTrendScore = 0;
    double lowestTrendScore = 720;
    for (var i = 0; i < trend.length; i++) {
      final score = (trend[i]['score'] as num).toDouble();
      highestTrendScore = score > highestTrendScore ? score : highestTrendScore;
      lowestTrendScore = score < lowestTrendScore ? score : lowestTrendScore;
      spots.add(FlSpot(i.toDouble(), score));
    }
    if (trend.isEmpty) {
      lowestTrendScore = 0;
    }

    final trendDelta = trend.length >= 2
        ? ((trend.last['score'] as num).toDouble() -
            (trend.first['score'] as num).toDouble())
        : 0.0;

    final consistencySpots = _buildConsistencySpots(trend);
    final consistencyScore = _computeConsistencyScore(trend);
    final scatterSpots = _buildTimeScoreSpots(trend);
    final correlation = _computeTimeScoreCorrelation(trend);

    final recommendation = _buildRecommendation(
      completedTests: completedTests,
      avgScore: avgScore,
      overallAccuracy: overallAccuracy,
      weakTopics: weakTopics,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Performance Dashboard')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Readiness Snapshot',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${readiness.toStringAsFixed(1)} / 100',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (readiness / 100).clamp(0.0, 1.0),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      completedTests == 0
                          ? 'No completed tests yet. Take your first mock to unlock accurate insights.'
                          : 'Calculated from average score and overall accuracy.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _metricTile(
                    title: 'Overall Accuracy',
                    value: '${overallAccuracy.toStringAsFixed(1)}%',
                    icon: Icons.track_changes,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metricTile(
                    title: 'Average Score',
                    value: '${avgScore.toStringAsFixed(1)} / 720',
                    icon: Icons.bar_chart,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _metricTile(
                    title: 'Completed Tests',
                    value: '$completedTests',
                    icon: Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metricTile(
                    title: 'In Progress',
                    value: '$inProgressTests',
                    icon: Icons.timelapse,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Score Trend',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 220,
                      child: trend.isEmpty
                          ? const Center(
                              child: Text('No completed test trend available.'),
                            )
                          : LineChart(
                              LineChartData(
                                minY: 0,
                                maxY: 720,
                                gridData: const FlGridData(show: true),
                                titlesData: const FlTitlesData(show: true),
                                borderData: FlBorderData(show: false),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: spots,
                                    isCurved: true,
                                    barWidth: 3,
                                    dotData: const FlDotData(show: true),
                                    belowBarData:
                                        BarAreaData(show: true, color: Colors.blue.withValues(alpha: 0.08)),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Best: ${highestTrendScore.toStringAsFixed(1)} | Lowest: ${lowestTrendScore.toStringAsFixed(1)} | Delta: ${trendDelta >= 0 ? '+' : ''}${trendDelta.toStringAsFixed(1)}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Subject-Wise Mini Bars',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 210,
                      child: BarChart(
                        BarChartData(
                          minY: 0,
                          maxY: 100,
                          gridData: const FlGridData(show: true),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: true),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  const labels = [
                                    'Phy',
                                    'Chem',
                                    'Bot',
                                    'Zoo'
                                  ];
                                  final idx = value.toInt();
                                  if (idx < 0 || idx >= labels.length) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(labels[idx]),
                                  );
                                },
                              ),
                            ),
                          ),
                          barGroups: subjectStrength.entries
                              .toList(growable: false)
                              .asMap()
                              .entries
                              .map(
                                (entry) => BarChartGroupData(
                                  x: entry.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: entry.value.value,
                                      width: 24,
                                      borderRadius: BorderRadius.circular(6),
                                      color: entry.value.value >= 60
                                          ? Colors.green
                                          : Colors.orange,
                                    )
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Derived from strong and weak topic signals for quick subject focus.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Weekly Consistency (Recent Attempts)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 190,
                      child: consistencySpots.isEmpty
                          ? const Center(
                              child: Text('Need at least 2 attempts for consistency.'),
                            )
                          : LineChart(
                              LineChartData(
                                minY: 0,
                                maxY: 100,
                                gridData: const FlGridData(show: true),
                                borderData: FlBorderData(show: false),
                                titlesData: const FlTitlesData(show: true),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: consistencySpots,
                                    isCurved: true,
                                    barWidth: 3,
                                    color: Colors.purple,
                                    dotData: const FlDotData(show: true),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(height: 8),
                    Text('Consistency Score: ${consistencyScore.toStringAsFixed(1)} / 100'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Time Spent vs Score Correlation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 210,
                      child: scatterSpots.isEmpty
                          ? const Center(
                              child: Text('No time-score pairs available.'),
                            )
                          : ScatterChart(
                              ScatterChartData(
                                minX: 0,
                                maxX: 180,
                                minY: 0,
                                maxY: 720,
                                gridData: const FlGridData(show: true),
                                borderData: FlBorderData(show: false),
                                titlesData: const FlTitlesData(show: true),
                                scatterSpots: scatterSpots,
                              ),
                            ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Correlation (r): ${correlation.toStringAsFixed(2)} (${_correlationLabel(correlation)})',
                    ),
                    const SizedBox(height: 4),
                    const Text('X-axis: Time (minutes), Y-axis: Score'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Score History (Recent)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: trend.isEmpty
                    ? const Text('No score history yet.')
                    : Column(
                        children: trend.map((entry) {
                          final attemptedAt = _formatAttemptedAt(
                            (entry['attempted_at'] ?? '').toString(),
                          );
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Score: ${(entry['score'] as num).toStringAsFixed(0)}',
                            ),
                            subtitle: Text(attemptedAt),
                          );
                        }).toList(),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Time History (Recent)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: trend.isEmpty
                    ? const Text('No time history yet.')
                    : Column(
                        children: trend.map((entry) {
                          final attemptedAt = _formatAttemptedAt(
                            (entry['attempted_at'] ?? '').toString(),
                          );
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Time: ${_formatDuration((entry['time_taken'] as num).toInt())}',
                            ),
                            subtitle: Text(attemptedAt),
                          );
                        }).toList(),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            _topicSection(
              title: 'Weak Areas',
              topics: weakTopics,
              fallback: 'No weak areas detected yet.',
              color: Colors.red.shade50,
              textColor: Colors.red.shade700,
            ),
            const SizedBox(height: 12),
            _topicSection(
              title: 'Strong Areas',
              topics: strongTopics,
              fallback: 'No strong areas detected yet.',
              color: Colors.green.shade50,
              textColor: Colors.green.shade700,
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.tips_and_updates),
                title: const Text('Recommended Next Step'),
                subtitle: Text(recommendation),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricTile({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(title),
          ],
        ),
      ),
    );
  }

  Widget _topicSection({
    required String title,
    required List<String> topics,
    required String fallback,
    required Color color,
    required Color textColor,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (topics.isEmpty)
              Text(fallback)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: topics
                    .map(
                      (topic) => Chip(
                        backgroundColor: color,
                        label: Text(
                          topic,
                          style: TextStyle(color: textColor),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  String _buildRecommendation({
    required int completedTests,
    required double avgScore,
    required double overallAccuracy,
    required List<String> weakTopics,
  }) {
    if (completedTests == 0) {
      return 'Take your first full mock test, then review mistakes before attempting a subject-wise quiz.';
    }
    if (overallAccuracy < 50) {
      final focus = weakTopics.isNotEmpty ? weakTopics.first : 'core topics';
      return 'Focus on $focus with 30 targeted questions today, then retake a short quiz.';
    }
    if (avgScore < 450) {
      return 'Increase question volume: 2 subject-wise tests and 1 revision block daily.';
    }
    if (avgScore < 580) {
      return 'Good base. Prioritize speed and negative-marking control in timed practice.';
    }
    return 'Strong performance. Maintain consistency with full mocks and weak-topic revision.';
  }

  Map<String, double> _buildSubjectStrength({
    required List<String> weakTopics,
    required List<String> strongTopics,
  }) {
    final subjects = ['Physics', 'Chemistry', 'Botany', 'Zoology'];
    final map = <String, double>{for (final s in subjects) s: 50.0};

    for (final topic in weakTopics) {
      final lowered = topic.toLowerCase();
      for (final subject in subjects) {
        if (lowered.contains(subject.toLowerCase())) {
          map[subject] = ((map[subject] ?? 50) - 20).clamp(0, 100).toDouble();
        }
      }
    }

    for (final topic in strongTopics) {
      final lowered = topic.toLowerCase();
      for (final subject in subjects) {
        if (lowered.contains(subject.toLowerCase())) {
          map[subject] = ((map[subject] ?? 50) + 20).clamp(0, 100).toDouble();
        }
      }
    }

    return map;
  }

  List<FlSpot> _buildConsistencySpots(List<Map<String, dynamic>> trend) {
    if (trend.length < 2) {
      return const [];
    }
    final spots = <FlSpot>[];
    for (var i = 1; i < trend.length; i++) {
      final prevScore = (trend[i - 1]['score'] as num).toDouble();
      final score = (trend[i]['score'] as num).toDouble();
      final consistency = (100 - ((score - prevScore).abs() / 720.0) * 100)
          .clamp(0, 100)
          .toDouble();
      spots.add(FlSpot((i - 1).toDouble(), consistency));
    }
    return spots;
  }

  double _computeConsistencyScore(List<Map<String, dynamic>> trend) {
    final spots = _buildConsistencySpots(trend);
    if (spots.isEmpty) {
      return 0;
    }
    final total = spots.fold<double>(0, (sum, s) => sum + s.y);
    return total / spots.length;
  }

  List<ScatterSpot> _buildTimeScoreSpots(List<Map<String, dynamic>> trend) {
    return trend.map((entry) {
      final minutes = ((entry['time_taken'] as num).toDouble() / 60).clamp(0, 180);
      final score = (entry['score'] as num).toDouble().clamp(0, 720);
      return ScatterSpot(
        minutes,
        score,
        dotPainter: FlDotCirclePainter(
          radius: 4,
          color: Colors.indigo,
          strokeWidth: 1,
          strokeColor: Colors.white,
        ),
      );
    }).toList(growable: false);
  }

  double _computeTimeScoreCorrelation(List<Map<String, dynamic>> trend) {
    if (trend.length < 2) {
      return 0;
    }
    final xs = trend
        .map((e) => (e['time_taken'] as num).toDouble() / 60.0)
        .toList(growable: false);
    final ys = trend
        .map((e) => (e['score'] as num).toDouble())
        .toList(growable: false);

    final meanX = xs.reduce((a, b) => a + b) / xs.length;
    final meanY = ys.reduce((a, b) => a + b) / ys.length;

    double numerator = 0;
    double denomX = 0;
    double denomY = 0;
    for (var i = 0; i < xs.length; i++) {
      final dx = xs[i] - meanX;
      final dy = ys[i] - meanY;
      numerator += dx * dy;
      denomX += dx * dx;
      denomY += dy * dy;
    }

    final denominator = math.sqrt(denomX * denomY);
    if (denominator == 0) {
      return 0;
    }
    return (numerator / denominator).clamp(-1.0, 1.0);
  }

  String _correlationLabel(double r) {
    final absR = r.abs();
    if (absR < 0.2) {
      return 'very weak';
    }
    if (absR < 0.4) {
      return 'weak';
    }
    if (absR < 0.7) {
      return 'moderate';
    }
    return 'strong';
  }
}
