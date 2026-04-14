import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});

  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen> {
  List<dynamic> bookmarks = [];
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response =
          await ref.read(dioProvider).get('/quiz/bookmarks/details');
      setState(() {
        bookmarks = response.data as List<dynamic>;
        error = null;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookmarks & Revision')),
      body: error != null
          ? Center(child: Text(error!))
          : bookmarks.isEmpty
              ? const Center(child: Text('No bookmarks added yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: bookmarks.length,
                  itemBuilder: (context, index) {
                    final item = bookmarks[index] as Map<String, dynamic>;
                    final question = item['question'] as Map<String, dynamic>;
                    final options = (question['options'] as List<dynamic>)
                        .map((e) => e.toString())
                        .toList();
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${question['subject']} • ${question['topic']} (${question['difficulty']})',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              question['question_text'].toString(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            ...options.map((option) => Text('• $option')),
                            const SizedBox(height: 8),
                            Text(
                              'Correct answer: ${question['correct_answer']}',
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold),
                            ),
                            if ((question['explanation'] ?? '')
                                .toString()
                                .isNotEmpty)
                              Text('Explanation: ${question['explanation']}'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Bookmarked on ${item['created_at']}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () async {
                                    await ref.read(dioProvider).delete(
                                        '/quiz/bookmarks/${item['id']}');
                                    _load();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
