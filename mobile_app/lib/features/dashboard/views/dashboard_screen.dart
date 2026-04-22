import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../analytics/views/analytics_screen.dart';
import '../../admin/views/admin_screen.dart';
import '../../announcements/views/announcements_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../bookmarks/views/bookmarks_screen.dart';
import '../../gamification/views/leaderboard_screen.dart';
import '../../materials/views/materials_screen.dart';
import '../../plan/views/study_plan_screen.dart';
import '../../plan/views/scheduled_tests_screen.dart';
import '../../quiz/views/quiz_screen.dart';
import '../../quiz/views/remote_question_preview_screen.dart';
import '../../quiz/views/wrong_questions_screen.dart';
import '../../ai/views/ai_chat_screen.dart';
import '../../../core/api/api_client.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _estimatedScore = 0;
  int _completedTests = 0;
  List<Map<String, dynamic>> _trend = [];

  @override
  void initState() {
    super.initState();
    _loadPredictorScore();
  }

  Future<void> _loadPredictorScore() async {
    try {
      final response =
          await ref.read(dioProvider).get('/quiz/analytics/dashboard');
      final data = response.data as Map<String, dynamic>;
      final completed = (data['completed_tests'] as num?)?.toInt() ?? 0;
      final avgScoreRaw = (data['avg_score'] as num?)?.toDouble() ?? 0.0;
      final trendRaw = (data['trend'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

      if (!mounted) {
        return;
      }

      setState(() {
        _completedTests = completed;
        _trend = trendRaw;
        // Show 0 for new users with no completed tests.
        _estimatedScore =
            completed == 0 ? 0 : avgScoreRaw.round().clamp(0, 720).toInt();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _completedTests = 0;
        _estimatedScore = 0;
        _trend = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${user?.fullName ?? 'Student'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Card
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withValues(alpha: 0.7)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: _buildPredictorCard(),
            ),
            const SizedBox(height: 24),
            const Text('Your Toolkit',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Grid of Actions
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildActionCard(
                  context,
                  title: 'Full Mock Test',
                  icon: Icons.timer,
                  color: Colors.redAccent,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RemoteQuestionPreviewScreen(),
                      ),
                    );
                    if (!context.mounted) {
                      return;
                    }
                    await _loadPredictorScore();
                  },
                ),
                _buildActionCard(
                  context,
                  title: 'Subject Practice',
                  icon: Icons.science,
                  color: Colors.teal,
                  onTap: () async {
                    final subject = await _pickSubject(context);
                    if (!context.mounted || subject == null) {
                      return;
                    }
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuizScreen(
                          mode: QuizStartMode.subject,
                          subject: subject,
                        ),
                      ),
                    );
                    if (!context.mounted) {
                      return;
                    }
                    await _loadPredictorScore();
                  },
                ),
                _buildActionCard(
                  context,
                  title: 'Wrong Reattempt',
                  icon: Icons.replay_circle_filled,
                  color: Colors.deepPurple,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const WrongQuestionsScreen()),
                  ),
                ),
                _buildActionCard(
                  context,
                  title: 'AI Tutor',
                  icon: Icons.smart_toy,
                  color: Colors.blueAccent,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AiChatScreen())),
                ),
                _buildActionCard(
                  context,
                  title: 'Performance Dashboard',
                  icon: Icons.bar_chart,
                  color: Colors.green,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AnalyticsScreen())),
                ),
                _buildActionCard(
                  context,
                  title: 'Study Materials',
                  icon: Icons.picture_as_pdf,
                  color: Colors.orange,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MaterialsScreen())),
                ),
                _buildActionCard(
                  context,
                  title: 'Daily Study Plan',
                  icon: Icons.calendar_month,
                  color: Colors.indigo,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const StudyPlanScreen())),
                ),
                _buildActionCard(
                  context,
                  title: 'Scheduled Tests',
                  icon: Icons.event_available,
                  color: Colors.cyan,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ScheduledTestsScreen())),
                ),
                _buildActionCard(
                  context,
                  title: 'Bookmark & Revision',
                  icon: Icons.bookmark,
                  color: Colors.brown,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BookmarksScreen())),
                ),
                _buildActionCard(
                  context,
                  title: 'Gamification',
                  icon: Icons.emoji_events,
                  color: Colors.purple,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LeaderboardScreen())),
                ),
                _buildActionCard(
                  context,
                  title: 'Announcements',
                  icon: Icons.campaign,
                  color: Colors.deepOrange,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AnnouncementsScreen())),
                ),
                if (user?.role == 'admin')
                  _buildActionCard(
                    context,
                    title: 'Admin Panel',
                    icon: Icons.admin_panel_settings,
                    color: Colors.black,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AdminScreen())),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPredictorCard() {
    final subtitle = _completedTests == 0
        ? 'Start a quiz to unlock your NEET score prediction.'
        : 'Based on your recent quiz performance.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('NEET Rank Predictor',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Current Est. Score: $_estimatedScore/720',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Colors.white70)),
        if (_trend.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Score Trend',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _buildMiniTrendGraph(),
        ],
      ],
    );
  }

  Widget _buildMiniTrendGraph() {
    final spots = <FlSpot>[];
    for (var i = 0; i < _trend.length; i++) {
      final score = (_trend[i]['score'] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), score));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: SizedBox(
        height: 120,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: 720,
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                barWidth: 2,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _pickSubject(BuildContext context) {
    const subjects = ['Physics', 'Chemistry', 'Botany', 'Zoology'];
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              const Text('Choose Subject',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...subjects.map(
                (subject) => ListTile(
                  title: Text(subject),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.pop(ctx, subject),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionCard(BuildContext context,
      {required String title,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              radius: 30,
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 12),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
