import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  List<dynamic> announcements = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final response = await ref.read(dioProvider).get('/admin/announcements/public');
    setState(() {
      announcements = response.data as List<dynamic>;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      body: ListView.builder(
        itemCount: announcements.length,
        itemBuilder: (context, index) {
          final item = announcements[index] as Map<String, dynamic>;
          return Card(
            child: ListTile(
              title: Text(item['title'].toString()),
              subtitle: Text(item['content'].toString()),
            ),
          );
        },
      ),
    );
  }
}
