import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/quiz_provider.dart';
import 'quiz_screen.dart';

class WrongQuestionsScreen extends ConsumerStatefulWidget {
  const WrongQuestionsScreen({super.key});

  @override
  ConsumerState<WrongQuestionsScreen> createState() =>
      _WrongQuestionsScreenState();
}

class _WrongQuestionsScreenState extends ConsumerState<WrongQuestionsScreen> {
  static const List<String> _subjects = <String>[
    'All',
    'Physics',
    'Chemistry',
    'Botany',
    'Zoology'
  ];

  bool _loading = true;
  String? _error;
  String _selectedSubject = 'All';
  List<WrongQuestionItem> _items = const [];
  final Set<int> _selectedQuestionIds = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ref.read(quizProvider.notifier).fetchWrongQuestions(
            subject: _selectedSubject == 'All' ? null : _selectedSubject,
            limit: 180,
          );
      setState(() {
        _items = data;
        _selectedQuestionIds
            .removeWhere((id) => !_items.any((item) => item.question.id == id));
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _toggleSelection(int questionId, bool selected) {
    setState(() {
      if (selected) {
        _selectedQuestionIds.add(questionId);
      } else {
        _selectedQuestionIds.remove(questionId);
      }
    });
  }

  Future<void> _startReattempt() async {
    final questionIds = _selectedQuestionIds.isEmpty
        ? null
        : _selectedQuestionIds.toList(growable: false);

    if (!mounted) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          mode: QuizStartMode.reattempt,
          subject: _selectedSubject == 'All' ? null : _selectedSubject,
          questionIds: questionIds,
          questionCount: questionIds == null ? 30 : questionIds.length,
        ),
      ),
    );

    if (mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wrong Question Reattempt'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final subject = _subjects[index];
                  final selected = _selectedSubject == subject;
                  return ChoiceChip(
                    label: Text(subject),
                    selected: selected,
                    onSelected: (value) async {
                      if (!value) {
                        return;
                      }
                      setState(() {
                        _selectedSubject = subject;
                      });
                      await _load();
                    },
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: _subjects.length,
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator())),
            if (!_loading && _error != null)
              Expanded(
                child: Center(
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            if (!_loading && _error == null && _items.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                      'No wrong questions found yet. Complete a quiz first.'),
                ),
              ),
            if (!_loading && _error == null && _items.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final isSelected =
                        _selectedQuestionIds.contains(item.question.id);
                    return Card(
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (value) =>
                            _toggleSelection(item.question.id, value ?? false),
                        title: Text(
                          item.question.questionText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (item.question.imageUrl != null) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  item.question.imageUrl!,
                                  height: 140,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 140,
                                      color: Colors.black12,
                                      alignment: Alignment.center,
                                      child: const Text('Image unavailable'),
                                    );
                                  },
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              '${item.question.subject} | Your answer: ${item.selectedOption} | Correct: ${item.correctAnswer}',
                            ),
                          ],
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _loading || _error != null || _items.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton.icon(
                onPressed: _startReattempt,
                icon: const Icon(Icons.replay),
                label: Text(
                  _selectedQuestionIds.isEmpty
                      ? 'Start Reattempt (Top 30)'
                      : 'Start Reattempt (${_selectedQuestionIds.length})',
                ),
              ),
            ),
    );
  }
}
