import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/ai_provider.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  String _selectedSubject = 'Physics';
  bool _historyLoaded = false;

  final List<String> _subjects = ['Physics', 'Chemistry', 'Botany', 'Zoology'];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (_historyLoaded) {
        return;
      }
      _historyLoaded = true;
      await ref.read(chatProvider.notifier).loadHistory();
    });
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      ref
          .read(chatProvider.notifier)
          .sendMessage(_controller.text, _selectedSubject);
      _controller.clear();
    }
  }

  Future<void> _uploadPdf() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null || result.files.single.path == null) return;
    await ref.read(chatProvider.notifier).summarizePdf(
          result.files.single.path!,
          result.files.single.name,
        );
  }

  Future<void> _clearHistory() async {
    await ref.read(chatProvider.notifier).clearHistory();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearHistory,
            tooltip: 'Clear chat history',
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _uploadPdf,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSubject,
                dropdownColor: Theme.of(context).cardColor,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedSubject = newValue!;
                  });
                },
                items: _subjects.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                return Align(
                  alignment:
                      msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      color: msg.isUser
                          ? Theme.of(context).primaryColor
                          : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Text(
                      msg.content,
                      style: TextStyle(
                        color: msg.isUser
                            ? Colors.white
                            : Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Ask a doubt in $_selectedSubject...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24.0)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 10.0),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
