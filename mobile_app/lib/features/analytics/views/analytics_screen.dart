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
      return Scaffold(appBar: AppBar(title: const Text('Analytics')), body: Center(child: Text(error!)));
    }
    if (data == null) {
      return Scaffold(appBar: AppBar(title: const Text('Analytics')), body: const Center(child: CircularProgressIndicator()));
    }

    final trend = (data!['trend'] as List<dynamic>).cast<Map<String, dynamic>>();
    final spots = <FlSpot>[];
    for (var i = 0; i < trend.length; i++) {
      spots.add(FlSpot(i.toDouble(), (trend[i]['score'] as num).toDouble()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Performance Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('Overall Accuracy'),
              trailing: Text('${data!['overall_accuracy']}%'),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Average Score'),
              trailing: Text('${data!['avg_score']}'),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Score Trend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true),
                titlesData: const FlTitlesData(show: true),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(spots: spots, isCurved: true, dotData: const FlDotData(show: true)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Weak Areas: ${(data!['weak_topics'] as List<dynamic>).join(', ')}'),
          Text('Strong Areas: ${(data!['strong_topics'] as List<dynamic>).join(', ')}'),
        ],
      ),
    );
  }
}
