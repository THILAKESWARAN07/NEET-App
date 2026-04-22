import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/latex_renderer.dart';
import '../providers/quiz_provider.dart';
import '../services/anti_cheat_service.dart';
import 'result_screen.dart';

enum QuizStartMode { full, subject, reattempt }

class QuizScreen extends ConsumerStatefulWidget {
  final QuizStartMode mode;
  final String? subject;
  final List<int>? questionIds;
  final int questionCount;

  const QuizScreen({
    super.key,
    this.mode = QuizStartMode.full,
    this.subject,
    this.questionIds,
    this.questionCount = 30,
  });

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  late AntiCheatService _antiCheatService;

  @override
  void initState() {
    super.initState();
    _antiCheatService = AntiCheatService(
      onCheatDetected: () async {
        await ref.read(quizProvider.notifier).logCheat();
        _showCheatWarning();
      },
    );
    _antiCheatService.startMonitoring();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final notifier = ref.read(quizProvider.notifier);
      if (widget.mode == QuizStartMode.reattempt) {
        notifier.startReattemptQuiz(
          subject: widget.subject,
          questionIds: widget.questionIds,
          questionCount: widget.questionCount,
        );
      } else if (widget.mode == QuizStartMode.subject) {
        notifier.startOrResumeQuiz(testType: 'subject', subject: widget.subject);
      } else {
        notifier.startOrResumeQuiz(testType: 'full');
      }
    });
  }

  @override
  void dispose() {
    _antiCheatService.stopMonitoring();
    super.dispose();
  }

  void _showCheatWarning() {
    final warnings = ref.read(quizProvider).cheatWarnings;
    if (warnings < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Warning $warnings/3: Do not leave the quiz screen!'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  String _formatTime(int seconds) {
    int h = seconds ~/ 3600;
    int m = (seconds % 3600) ~/ 60;
    int s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _openQuestionNavigator() async {
    final state = ref.read(quizProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Question Navigator',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 320,
                child: GridView.builder(
                  itemCount: state.questions.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemBuilder: (_, index) {
                    final question = state.questions[index];
                    final answered = state.selectedAnswers.containsKey(question.id);
                    final marked = state.markedForReview.contains(question.id);
                    final isCurrent = index == state.currentQuestionIndex;

                    Color bg = Colors.white;
                    if (isCurrent) {
                      bg = Colors.blue.shade700;
                    } else if (marked) {
                      bg = Colors.orange.shade500;
                    } else if (answered) {
                      bg = Colors.green.shade600;
                    }

                    return InkWell(
                      onTap: () {
                        ref.read(quizProvider.notifier).jumpToQuestion(index);
                        Navigator.of(ctx).pop();
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: bg == Colors.white ? Colors.black87 : Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Text('Blue: current, Green: answered, Orange: marked'),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final quizState = ref.watch(quizProvider);

    if (quizState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (quizState.error != null) {
      return Scaffold(body: Center(child: Text(quizState.error!)));
    }

    if (quizState.isSubmitted && quizState.result != null) {
      return ResultScreen(result: quizState.result!);
    }

    if (quizState.isSubmitted) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 24),
              Text(
                'Test Submitted Successfully',
                style: Theme.of(context).textTheme.displayLarge,
                textAlign: TextAlign.center,
              ),
              if (quizState.cheatWarnings >= 3)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Note: Your test was auto-submitted due to repeated rules violations.',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (quizState.questions.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentQuestion = quizState.questions[quizState.currentQuestionIndex];
    final selectedOption = quizState.selectedAnswers[currentQuestion.id];
    final isMarked = quizState.markedForReview.contains(currentQuestion.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Question ${quizState.currentQuestionIndex + 1}/${quizState.questions.length}'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(28),
          child: Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Marking: +4 correct | -1 wrong | 0 unattempted',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        automaticallyImplyLeading: false, // Prevent back button easily
        actions: [
          IconButton(
            onPressed: () => ref.read(quizProvider.notifier).toggleMarkForReview(),
            tooltip: 'Mark for review',
            icon: Icon(
              isMarked ? Icons.flag : Icons.outlined_flag,
              color: isMarked ? Colors.orange : null,
            ),
          ),
          IconButton(
            onPressed: _openQuestionNavigator,
            tooltip: 'Question navigator',
            icon: const Icon(Icons.grid_view_rounded),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                _formatTime(quizState.timeRemainingSeconds),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.redAccent),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    safeMath(
                      currentQuestion.questionText,
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (currentQuestion.imageUrl != null) ...[
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          currentQuestion.imageUrl!,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              color: Colors.black12,
                              child: const Text('Image could not be loaded.'),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    for (final option in currentQuestion.options)
                      Card(
                        child: ListTile(
                          leading: Icon(
                            selectedOption == option
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: selectedOption == option
                                ? Theme.of(context).primaryColor
                                : null,
                          ),
                          title: safeMath(option),
                          selected: selectedOption == option,
                          onTap: () => ref
                              .read(quizProvider.notifier)
                              .selectOption(option),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: ref.read(quizProvider.notifier).previousQuestion,
                    child: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: ref.read(quizProvider.notifier).nextQuestion,
                    child: const Text('Next'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () async {
            await ref.read(quizProvider.notifier).autoSubmit('completed');
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('Submit Test'),
        ),
      ),
    );
  }
}
