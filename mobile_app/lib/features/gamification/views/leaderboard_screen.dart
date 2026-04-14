import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  List<dynamic> board = [];
  Map<String, dynamic>? rankPrediction;
  Map<String, dynamic>? gamificationProfile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dio = ref.read(dioProvider);
    final boardResp = await dio.get('/quiz/leaderboard');
    final rankResp = await dio.get('/quiz/rank-prediction');
    final profileResp = await dio.get('/quiz/gamification/me');
    setState(() {
      board = boardResp.data as List<dynamic>;
      rankPrediction = rankResp.data as Map<String, dynamic>;
      gamificationProfile = profileResp.data as Map<String, dynamic>;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (rankPrediction == null || gamificationProfile == null) {
      return Scaffold(appBar: AppBar(title: const Text('Leaderboard')), body: const Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard & Rank Prediction')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('Predicted NEET Rank'),
              subtitle: Text(
                '${rankPrediction!['predicted_rank_min']} - ${rankPrediction!['predicted_rank_max']}\nConfidence: ${rankPrediction!['confidence_percent']}%',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('Your Streak & Badges'),
              subtitle: Text(
                'Streak: ${gamificationProfile!['streak_days']} days\nBadges: ${(gamificationProfile!['badges'] as List).join(', ')}',
              ),
              trailing: Text('${gamificationProfile!['points']} pts'),
            ),
          ),
          const SizedBox(height: 12),
          ...board.asMap().entries.map((entry) {
            final i = entry.key;
            final row = entry.value as Map<String, dynamic>;
            return Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('#${i + 1}')),
                title: Text(row['full_name'].toString()),
                trailing: Text('${row['points']} pts'),
              ),
            );
          }),
        ],
      ),
    );
  }
}
