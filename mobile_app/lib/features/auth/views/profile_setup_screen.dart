import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  int? _targetExamYear;
  String? _preferredLanguage;

  static const List<String> _languages = ['English', 'Hindi'];

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 17, 1, 1),
      firstDate: DateTime(1990, 1, 1),
      lastDate: DateTime(now.year - 12, 12, 31),
    );
    if (picked != null) {
      _dobController.text = picked.toIso8601String().split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Your Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dobController,
              readOnly: true,
              onTap: _pickDate,
              decoration: const InputDecoration(
                labelText: 'Date of Birth (YYYY-MM-DD)',
                suffixIcon: Icon(Icons.calendar_today),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _targetExamYear,
              decoration: const InputDecoration(labelText: 'Target Exam Year'),
              items: [
                for (final year in List<int>.generate(6, (i) => DateTime.now().year + i))
                  DropdownMenuItem(value: year, child: Text(year.toString())),
              ],
              onChanged: (value) => setState(() => _targetExamYear = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _preferredLanguage,
              decoration: const InputDecoration(labelText: 'Preferred Language'),
              items: _languages
                  .map((lang) => DropdownMenuItem(value: lang, child: Text(lang)))
                  .toList(),
              onChanged: (value) => setState(() => _preferredLanguage = value),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: state.isLoading
                  ? null
                  : () {
                      ref.read(authProvider.notifier).completeProfile(
                            fullName: _nameController.text.trim(),
                            dob: _dobController.text.trim(),
                            targetExamYear: _targetExamYear,
                            preferredLanguage: _preferredLanguage,
                          );
                    },
              child: state.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Profile'),
            ),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(state.error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}
