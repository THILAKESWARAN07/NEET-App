import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../quiz/views/wrong_questions_screen.dart';
import '../../ai/views/ai_chat_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NEET Rank Predictor',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('Current Est. Score: 620/720',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Keep up the good work in Physics!',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
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
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const QuizScreen(mode: QuizStartMode.full),
                    ),
                  ),
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
