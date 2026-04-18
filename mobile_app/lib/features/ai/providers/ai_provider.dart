import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

class ChatMessage {
  final String content;
  final bool isUser;
  ChatMessage({required this.content, required this.isUser});
}

final chatProvider =
    StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  return ChatNotifier(ref.read(dioProvider));
});

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final Dio dio;

  ChatNotifier(this.dio) : super([]) {
    state = [
      ChatMessage(
          content:
              "Hello! I am your NEET AI Assistant. How can I help you today?",
          isUser: false)
    ];
  }

  Future<void> loadHistory() async {
    try {
      final response =
          await dio.get('/ai/history', queryParameters: {'limit': 200});
      final rows = response.data as List<dynamic>;
      if (rows.isEmpty) {
        state = [
          ChatMessage(
              content:
                  "Hello! I am your NEET AI Assistant. How can I help you today?",
              isUser: false)
        ];
        return;
      }

      state = rows.map((row) {
        final item = row as Map<String, dynamic>;
        final role = (item['role'] ?? 'assistant').toString();
        return ChatMessage(
          content: (item['content'] ?? '').toString(),
          isUser: role == 'user',
        );
      }).toList();
    } catch (_) {
      // Keep default assistant greeting if history fetch fails.
    }
  }

  Future<void> sendMessage(String text, String subject) async {
    if (text.trim().isEmpty) return;

    state = [...state, ChatMessage(content: text, isUser: true)];

    try {
      final response = await dio.post('/ai/chat', data: {
        "message": text,
        "subject": subject,
      });

      print("RESPONSE: ${response.data}");
      
      final reply = response.data['response'];
      state = [...state, ChatMessage(content: reply, isUser: false)];
    } catch (e) {
      print("ERROR: $e");
      state = [
        ...state,
        ChatMessage(
            content: "Sorry, I couldn't connect to the server right now.",
            isUser: false)
      ];
    }
  }

  Future<void> summarizePdf(String filePath, String filename) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: filename),
      });
      final response = await dio.post('/ai/summarize-pdf', data: form);
      final summary = response.data['summary'] as String;
      state = [
        ...state,
        ChatMessage(content: 'PDF Summary:\n$summary', isUser: false)
      ];
    } catch (e) {
      state = [
        ...state,
        ChatMessage(
            content: 'Could not summarize the PDF right now.', isUser: false)
      ];
    }
  }

  Future<void> clearHistory() async {
    try {
      await dio.delete('/ai/history');
    } catch (_) {
      // Ignore server failure and clear local state anyway.
    }
    state = [
      ChatMessage(
          content:
              "Hello! I am your NEET AI Assistant. How can I help you today?",
          isUser: false)
    ];
  }
}
