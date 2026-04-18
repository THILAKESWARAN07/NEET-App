import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 20;

  late final TabController _tabController;

  bool _loading = true;
  String? _error;

  List<dynamic> _users = [];
  List<dynamic> _questions = [];
  List<dynamic> _materials = [];
  List<dynamic> _announcements = [];
  List<dynamic> _tests = [];
  List<dynamic> _cheatFlags = [];

  int _usersSkip = 0;
  int _questionsSkip = 0;
  int _announcementsSkip = 0;
  int _testsSkip = 0;
  int _cheatsSkip = 0;

  int _usersTotal = 0;
  int _questionsTotal = 0;
  int _announcementsTotal = 0;
  int _testsTotal = 0;
  int _cheatsTotal = 0;

  int? _editingQuestionId;
  int? _editingMaterialId;
  int? _editingTestId;

  final TextEditingController _searchController = TextEditingController();
  String _userRoleFilter = 'all';
  String _questionSubjectFilter = 'all';
  String _testStatusFilter = 'all';

  final TextEditingController _questionSubject = TextEditingController();
  final TextEditingController _questionTopic = TextEditingController();
  final TextEditingController _questionDifficulty =
      TextEditingController(text: 'medium');
  final TextEditingController _questionText = TextEditingController();
  final TextEditingController _questionOptionA = TextEditingController();
  final TextEditingController _questionOptionB = TextEditingController();
  final TextEditingController _questionOptionC = TextEditingController();
  final TextEditingController _questionOptionD = TextEditingController();
  final TextEditingController _questionCorrect =
      TextEditingController(text: 'A');
  final TextEditingController _questionExplanation = TextEditingController();
  final TextEditingController _questionImageUrl = TextEditingController();
  String? _csvImportStatus;

  final TextEditingController _materialSubject = TextEditingController();
  final TextEditingController _materialTitle = TextEditingController();
  final TextEditingController _materialPdfUrl = TextEditingController();

  final TextEditingController _announcementTitle = TextEditingController();
  final TextEditingController _announcementContent = TextEditingController();

  final TextEditingController _testTitle = TextEditingController();
  final TextEditingController _testSubject = TextEditingController();
  final TextEditingController _testScheduledAt = TextEditingController();
  final TextEditingController _testDurationSeconds =
      TextEditingController(text: '10800');
  String _testType = 'full';

  @override
  void initState() {
    super.initState();
    _questionImageUrl.addListener(_handleQuestionImageChanged);
    _tabController = TabController(length: 6, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _questionImageUrl.removeListener(_handleQuestionImageChanged);
    _questionSubject.dispose();
    _questionTopic.dispose();
    _questionDifficulty.dispose();
    _questionText.dispose();
    _questionOptionA.dispose();
    _questionOptionB.dispose();
    _questionOptionC.dispose();
    _questionOptionD.dispose();
    _questionCorrect.dispose();
    _questionExplanation.dispose();
    _questionImageUrl.dispose();
    _materialSubject.dispose();
    _materialTitle.dispose();
    _materialPdfUrl.dispose();
    _announcementTitle.dispose();
    _announcementContent.dispose();
    _testTitle.dispose();
    _testSubject.dispose();
    _testScheduledAt.dispose();
    _testDurationSeconds.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleQuestionImageChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final query = _searchController.text.trim();
      final responses = await Future.wait([
        dio.get('/admin/users/paginated', queryParameters: {
          'q': query,
          'role': _userRoleFilter,
          'skip': _usersSkip,
          'limit': _pageSize,
        }),
        dio.get('/admin/questions', queryParameters: {
          'q': query,
          'subject': _questionSubjectFilter,
          'skip': _questionsSkip,
          'limit': _pageSize,
        }),
        dio.get('/materials/'),
        dio.get('/admin/announcements/paginated', queryParameters: {
          'q': query,
          'skip': _announcementsSkip,
          'limit': _pageSize,
        }),
        dio.get('/admin/schedule-tests/paginated', queryParameters: {
          'q': query,
          'status': _testStatusFilter,
          'skip': _testsSkip,
          'limit': _pageSize,
        }),
        dio.get('/admin/cheat-dashboard/paginated', queryParameters: {
          'skip': _cheatsSkip,
          'limit': _pageSize,
          'min_cheat_count': 1,
        }),
      ]);

      setState(() {
        final usersPayload = responses[0].data as Map<String, dynamic>;
        final questionsPayload = responses[1].data as Map<String, dynamic>;
        final materialsPayload = responses[2].data as List<dynamic>;
        final announcementsPayload = responses[3].data as Map<String, dynamic>;
        final testsPayload = responses[4].data as Map<String, dynamic>;
        final cheatsPayload = responses[5].data as Map<String, dynamic>;

        _users = usersPayload['items'] as List<dynamic>;
        _questions = questionsPayload['items'] as List<dynamic>;
        _materials = materialsPayload;
        _announcements = announcementsPayload['items'] as List<dynamic>;
        _tests = testsPayload['items'] as List<dynamic>;
        _cheatFlags = cheatsPayload['items'] as List<dynamic>;

        _usersTotal = (usersPayload['total'] as num?)?.toInt() ?? 0;
        _questionsTotal = (questionsPayload['total'] as num?)?.toInt() ?? 0;
        _announcementsTotal =
            (announcementsPayload['total'] as num?)?.toInt() ?? 0;
        _testsTotal = (testsPayload['total'] as num?)?.toInt() ?? 0;
        _cheatsTotal = (cheatsPayload['total'] as num?)?.toInt() ?? 0;
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

  Future<void> _saveQuestion() async {
    final payload = {
      'subject': _questionSubject.text.trim(),
      'topic': _questionTopic.text.trim(),
      'difficulty': _questionDifficulty.text.trim().toLowerCase(),
      'question_text': _questionText.text.trim(),
      'options': [
        _questionOptionA.text.trim(),
        _questionOptionB.text.trim(),
        _questionOptionC.text.trim(),
        _questionOptionD.text.trim(),
      ],
      'correct_answer': _questionCorrect.text.trim(),
      'explanation': _questionExplanation.text.trim(),
      'image_url': _questionImageUrl.text.trim().isEmpty
          ? null
          : _questionImageUrl.text.trim(),
    };

    final dio = ref.read(dioProvider);
    if (_editingQuestionId == null) {
      await dio.post('/quiz/questions/', data: payload);
    } else {
      await dio.put('/admin/questions/$_editingQuestionId', data: payload);
    }

    _clearQuestionForm();
    await _load();
  }

  Future<void> _uploadQuestionImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null) {
      return;
    }

    final file = result.files.single;
    MultipartFile multipartFile;
    if (file.bytes != null) {
      multipartFile = MultipartFile.fromBytes(
        file.bytes!,
        filename: file.name,
      );
    } else if (file.path != null) {
      multipartFile = await MultipartFile.fromFile(
        file.path!,
        filename: file.name,
      );
    } else {
      setState(() {
        _csvImportStatus = 'Image upload failed: file path not available.';
      });
      return;
    }

    setState(() {
      _csvImportStatus = 'Uploading question image...';
    });

    try {
      final form = FormData.fromMap({'file': multipartFile});
      final response = await ref
          .read(dioProvider)
          .post('/admin/questions/image', data: form);
      setState(() {
        _questionImageUrl.text = (response.data['image_url'] ?? '').toString();
        _csvImportStatus = 'Question image uploaded.';
      });
    } catch (e) {
      setState(() {
        _csvImportStatus = 'Image upload failed: $e';
      });
    }
  }

  Future<void> _importQuestionsCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.single.path == null) {
      return;
    }

    setState(() {
      _csvImportStatus = 'Uploading CSV...';
    });

    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          result.files.single.path!,
          filename: result.files.single.name,
        ),
      });
      final response = await ref
          .read(dioProvider)
          .post('/admin/questions/bulk-csv', data: form);
      setState(() {
        _csvImportStatus = 'Imported ${response.data['created']} questions.';
      });
      await _load();
    } catch (e) {
      setState(() {
        _csvImportStatus = 'CSV import failed: $e';
      });
    }
  }

  Future<void> _deleteQuestion(int id) async {
    await ref.read(dioProvider).delete('/admin/questions/$id');
    if (_editingQuestionId == id) {
      _clearQuestionForm();
    }
    await _load();
  }

  void _editQuestion(Map<String, dynamic> question) {
    setState(() {
      _editingQuestionId = question['id'] as int;
      _questionSubject.text = (question['subject'] ?? '').toString();
      _questionTopic.text = (question['topic'] ?? '').toString();
      _questionDifficulty.text =
          (question['difficulty'] ?? 'medium').toString();
      _questionText.text = (question['question_text'] ?? '').toString();
      final options = (question['options'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList();
      _questionOptionA.text = options.isNotEmpty ? options[0] : '';
      _questionOptionB.text = options.length > 1 ? options[1] : '';
      _questionOptionC.text = options.length > 2 ? options[2] : '';
      _questionOptionD.text = options.length > 3 ? options[3] : '';
      _questionCorrect.text = (question['correct_answer'] ?? 'A').toString();
      _questionExplanation.text = (question['explanation'] ?? '').toString();
      _questionImageUrl.text = (question['image_url'] ?? '').toString();
      _tabController.animateTo(1);
    });
  }

  void _clearQuestionForm() {
    setState(() {
      _editingQuestionId = null;
      _questionSubject.clear();
      _questionTopic.clear();
      _questionDifficulty.text = 'medium';
      _questionText.clear();
      _questionOptionA.clear();
      _questionOptionB.clear();
      _questionOptionC.clear();
      _questionOptionD.clear();
      _questionCorrect.text = 'A';
      _questionExplanation.clear();
      _questionImageUrl.clear();
    });
  }

  Future<void> _saveMaterial() async {
    final payload = {
      'subject': _materialSubject.text.trim(),
      'title': _materialTitle.text.trim(),
      'pdf_url': _materialPdfUrl.text.trim(),
    };

    final dio = ref.read(dioProvider);
    if (_editingMaterialId == null) {
      await dio.post('/materials/', data: payload);
    } else {
      await dio.put('/materials/$_editingMaterialId', data: payload);
    }

    _clearMaterialForm();
    await _load();
  }

  Future<void> _deleteMaterial(int id) async {
    await ref.read(dioProvider).delete('/materials/$id');
    if (_editingMaterialId == id) {
      _clearMaterialForm();
    }
    await _load();
  }

  void _editMaterial(Map<String, dynamic> material) {
    setState(() {
      _editingMaterialId = material['id'] as int;
      _materialSubject.text = (material['subject'] ?? '').toString();
      _materialTitle.text = (material['title'] ?? '').toString();
      _materialPdfUrl.text = (material['pdf_url'] ?? '').toString();
      _tabController.animateTo(2);
    });
  }

  void _clearMaterialForm() {
    setState(() {
      _editingMaterialId = null;
      _materialSubject.clear();
      _materialTitle.clear();
      _materialPdfUrl.clear();
    });
  }

  Future<void> _saveAnnouncement() async {
    await ref.read(dioProvider).post('/admin/announcements', data: {
      'title': _announcementTitle.text.trim(),
      'content': _announcementContent.text.trim(),
    });
    _clearAnnouncementForm();
    await _load();
  }

  Future<void> _deleteAnnouncement(int id) async {
    await ref.read(dioProvider).delete('/admin/announcements/$id');
    await _load();
  }

  void _clearAnnouncementForm() {
    _announcementTitle.clear();
    _announcementContent.clear();
  }

  Future<void> _pickScheduledAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !mounted) {
      return;
    }

    final scheduled =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      _testScheduledAt.text = scheduled.toIso8601String();
    });
  }

  Future<void> _saveTest() async {
    final payload = {
      'title': _testTitle.text.trim(),
      'test_type': _testType,
      'subject':
          _testSubject.text.trim().isEmpty ? null : _testSubject.text.trim(),
      'scheduled_at': _testScheduledAt.text.trim(),
      'duration_seconds':
          int.tryParse(_testDurationSeconds.text.trim()) ?? 10800,
    };

    final dio = ref.read(dioProvider);
    if (_editingTestId == null) {
      await dio.post('/admin/schedule-tests', data: payload);
    } else {
      await dio.put('/admin/schedule-tests/$_editingTestId', data: payload);
    }

    _clearTestForm();
    await _load();
  }

  Future<void> _deleteTest(int id) async {
    await ref.read(dioProvider).delete('/admin/schedule-tests/$id');
    if (_editingTestId == id) {
      _clearTestForm();
    }
    await _load();
  }

  void _editTest(Map<String, dynamic> test) {
    setState(() {
      _editingTestId = test['id'] as int;
      _testTitle.text = (test['title'] ?? '').toString();
      _testType = (test['test_type'] ?? 'full').toString();
      _testSubject.text = (test['subject'] ?? '').toString();
      _testScheduledAt.text = (test['scheduled_at'] ?? '').toString();
      _testDurationSeconds.text =
          (test['duration_seconds'] ?? 10800).toString();
      _tabController.animateTo(4);
    });
  }

  void _clearTestForm() {
    setState(() {
      _editingTestId = null;
      _testTitle.clear();
      _testType = 'full';
      _testSubject.clear();
      _testScheduledAt.clear();
      _testDurationSeconds.text = '10800';
    });
  }

  Future<void> _updateUserRole(int userId, String role) async {
    await ref
        .read(dioProvider)
        .put('/admin/users/$userId/role', data: {'role': role});
    await _load();
  }

  Future<void> _refreshCurrentTab() async {
    await _load();
  }

  void _resetPagination() {
    _usersSkip = 0;
    _questionsSkip = 0;
    _announcementsSkip = 0;
    _testsSkip = 0;
    _cheatsSkip = 0;
  }

  Future<void> _searchAndReload() async {
    setState(_resetPagination);
    await _load();
  }

  List<Map<String, dynamic>> _filteredUsers() {
    final query = _searchController.text.trim().toLowerCase();
    return _users.cast<Map<String, dynamic>>().where((user) {
      final role = (user['role'] ?? 'user').toString();
      final matchesRole = _userRoleFilter == 'all' || role == _userRoleFilter;
      final text =
          '${user['full_name'] ?? ''} ${user['email'] ?? ''}'.toLowerCase();
      final matchesQuery = query.isEmpty || text.contains(query);
      return matchesRole && matchesQuery;
    }).toList();
  }

  List<Map<String, dynamic>> _filteredQuestions() {
    final query = _searchController.text.trim().toLowerCase();
    return _questions.cast<Map<String, dynamic>>().where((question) {
      final subject = (question['subject'] ?? '').toString();
      final matchesSubject =
          _questionSubjectFilter == 'all' || subject == _questionSubjectFilter;
      final text =
          '${question['question_text'] ?? ''} ${question['topic'] ?? ''} ${question['difficulty'] ?? ''}'
              .toLowerCase();
      final matchesQuery = query.isEmpty || text.contains(query);
      return matchesSubject && matchesQuery;
    }).toList();
  }

  List<Map<String, dynamic>> _filteredMaterials() {
    final query = _searchController.text.trim().toLowerCase();
    return _materials.cast<Map<String, dynamic>>().where((material) {
      final text =
          '${material['subject'] ?? ''} ${material['title'] ?? ''} ${material['pdf_url'] ?? ''}'
              .toLowerCase();
      return query.isEmpty || text.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> _filteredAnnouncements() {
    final query = _searchController.text.trim().toLowerCase();
    return _announcements.cast<Map<String, dynamic>>().where((announcement) {
      final text =
          '${announcement['title'] ?? ''} ${announcement['content'] ?? ''}'
              .toLowerCase();
      return query.isEmpty || text.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> _filteredTests() {
    final query = _searchController.text.trim().toLowerCase();
    return _tests.cast<Map<String, dynamic>>().where((test) {
      final status = test['status']?.toString() ?? 'upcoming';
      final matchesStatus =
          _testStatusFilter == 'all' || status == _testStatusFilter;
      final text =
          '${test['title'] ?? ''} ${test['test_type'] ?? ''} ${test['subject'] ?? ''}'
              .toLowerCase();
      final matchesQuery = query.isEmpty || text.contains(query);
      return matchesStatus && matchesQuery;
    }).toList();
  }

  Widget _buildSearchBar(String hint, {List<Widget>? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _searchAndReload(),
              decoration: InputDecoration(
                hintText: hint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _searchAndReload,
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            ...trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildPaginationControls({
    required int skip,
    required int total,
    required VoidCallback onPrev,
    required VoidCallback onNext,
  }) {
    final from = total == 0 ? 0 : skip + 1;
    final to = (skip + _pageSize) > total ? total : (skip + _pageSize);
    final canPrev = skip > 0;
    final canNext = (skip + _pageSize) < total;

    return Row(
      children: [
        Expanded(child: Text('Showing $from-$to of $total')),
        IconButton(
          onPressed: canPrev ? onPrev : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          onPressed: canNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _sectionCard(
      {required String title, required Widget child, Widget? action}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (action != null) action,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildUserTab() {
    return RefreshIndicator(
      onRefresh: _refreshCurrentTab,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildSearchBar(
            'Search users',
            trailing: [
              DropdownButton<String>(
                value: _userRoleFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All roles')),
                  DropdownMenuItem(value: 'user', child: Text('Users')),
                  DropdownMenuItem(value: 'admin', child: Text('Admins')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _userRoleFilter = value;
                    _usersSkip = 0;
                  });
                  _load();
                },
              ),
            ],
          ),
          _sectionCard(
            title: 'Users',
            child: _filteredUsers().isEmpty
                ? const Text('No users found.')
                : Column(
                    children: _filteredUsers().map<Widget>((user) {
                      final role = (user['role'] ?? 'user').toString();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text((user['full_name'] ?? 'User').toString()),
                        subtitle: Text(
                            '${user['email'] ?? ''} • ${user['points'] ?? 0} points'),
                        trailing: DropdownButton<String>(
                          value: role,
                          items: const [
                            DropdownMenuItem(
                                value: 'user', child: Text('user')),
                            DropdownMenuItem(
                                value: 'admin', child: Text('admin')),
                          ],
                          onChanged: (value) async {
                            if (value == null || value == role) {
                              return;
                            }
                            await _updateUserRole(user['id'] as int, value);
                          },
                        ),
                      );
                    }).toList()
                      ..add(
                        _buildPaginationControls(
                          skip: _usersSkip,
                          total: _usersTotal,
                          onPrev: () async {
                            setState(() {
                              _usersSkip =
                                  (_usersSkip - _pageSize).clamp(0, 1 << 30);
                            });
                            await _load();
                          },
                          onNext: () async {
                            setState(() {
                              _usersSkip += _pageSize;
                            });
                            await _load();
                          },
                        ),
                      ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionTab() {
    return RefreshIndicator(
      onRefresh: _refreshCurrentTab,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildSearchBar(
            'Search questions',
            trailing: [
              DropdownButton<String>(
                value: _questionSubjectFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All subjects')),
                  DropdownMenuItem(value: 'Physics', child: Text('Physics')),
                  DropdownMenuItem(
                      value: 'Chemistry', child: Text('Chemistry')),
                  DropdownMenuItem(value: 'Botany', child: Text('Botany')),
                  DropdownMenuItem(value: 'Zoology', child: Text('Zoology')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _questionSubjectFilter = value;
                    _questionsSkip = 0;
                  });
                  _load();
                },
              ),
            ],
          ),
          _sectionCard(
            title: _editingQuestionId == null
                ? 'Create Question'
                : 'Edit Question #$_editingQuestionId',
            action: TextButton(
              onPressed: _clearQuestionForm,
              child: const Text('Clear'),
            ),
            child: Column(
              children: [
                _textField(_questionSubject, 'Subject'),
                _textField(_questionTopic, 'Topic'),
                _textField(_questionDifficulty, 'Difficulty'),
                _textField(_questionText, 'Question text', maxLines: 4),
                _textField(
                  _questionImageUrl,
                  'Image URL (optional)',
                  hintText: 'Attach a question image or leave blank',
                ),
                if (_questionImageUrl.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _questionImageUrl.text.trim(),
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 180,
                          color: Colors.black12,
                          alignment: Alignment.center,
                          child: const Text('Image preview unavailable'),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _uploadQuestionImage,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Upload Question Image'),
                  ),
                ),
                Row(
                  children: [
                    Expanded(child: _textField(_questionOptionA, 'Option A')),
                    const SizedBox(width: 8),
                    Expanded(child: _textField(_questionOptionB, 'Option B')),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _textField(_questionOptionC, 'Option C')),
                    const SizedBox(width: 8),
                    Expanded(child: _textField(_questionOptionD, 'Option D')),
                  ],
                ),
                const SizedBox(height: 8),
                _textField(_questionCorrect, 'Correct answer',
                    hintText: 'A / B / C / D or exact option text'),
                _textField(_questionExplanation, 'Explanation', maxLines: 3),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveQuestion,
                    child: Text(_editingQuestionId == null
                        ? 'Create Question'
                        : 'Update Question'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _importQuestionsCsv,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import Questions from CSV'),
                  ),
                ),
                if (_csvImportStatus != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _csvImportStatus!,
                    style: TextStyle(
                      color: _csvImportStatus!.startsWith('Imported')
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _sectionCard(
            title: 'Questions',
            child: _filteredQuestions().isEmpty
                ? const Text('No questions available.')
                : Column(
                    children: _filteredQuestions().map<Widget>((question) {
                      final options =
                          (question['options'] as List<dynamic>? ?? const [])
                              .map((e) => e.toString())
                              .toList();
                      return Card(
                        child: ListTile(
                          leading: (question['image_url'] ?? '').toString().isEmpty
                              ? const Icon(Icons.quiz_outlined)
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    question['image_url'].toString(),
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) {
                                      return Container(
                                        width: 56,
                                        height: 56,
                                        color: Colors.black12,
                                        alignment: Alignment.center,
                                        child: const Icon(Icons.image),
                                      );
                                    },
                                  ),
                                ),
                          title: Text(
                              (question['question_text'] ?? '').toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                              '${question['subject']} • ${question['topic']} • ${question['difficulty']}\n${options.join(' | ')}${(question['image_url'] ?? '').toString().isNotEmpty ? '\nImage attached' : ''}'),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                _editQuestion(question);
                              } else if (value == 'delete') {
                                await _deleteQuestion(question['id'] as int);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                  value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ),
                      );
                    }).toList()
                      ..add(
                        _buildPaginationControls(
                          skip: _questionsSkip,
                          total: _questionsTotal,
                          onPrev: () async {
                            setState(() {
                              _questionsSkip = (_questionsSkip - _pageSize)
                                  .clamp(0, 1 << 30);
                            });
                            await _load();
                          },
                          onNext: () async {
                            setState(() {
                              _questionsSkip += _pageSize;
                            });
                            await _load();
                          },
                        ),
                      ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementTab() {
    return RefreshIndicator(
      onRefresh: _refreshCurrentTab,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildSearchBar('Search announcements'),
          _sectionCard(
            title: 'Create Announcement',
            action: TextButton(
              onPressed: _clearAnnouncementForm,
              child: const Text('Clear'),
            ),
            child: Column(
              children: [
                _textField(_announcementTitle, 'Title'),
                _textField(_announcementContent, 'Content', maxLines: 4),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveAnnouncement,
                    child: const Text('Publish Announcement'),
                  ),
                ),
              ],
            ),
          ),
          _sectionCard(
            title: 'Announcements',
            child: _filteredAnnouncements().isEmpty
                ? const Text('No announcements yet.')
                : Column(
                    children: _filteredAnnouncements().map<Widget>((ann) {
                      return Card(
                        child: ListTile(
                          title: Text((ann['title'] ?? '').toString()),
                          subtitle: Text((ann['content'] ?? '').toString()),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async =>
                                _deleteAnnouncement(ann['id'] as int),
                          ),
                        ),
                      );
                    }).toList()
                      ..add(
                        _buildPaginationControls(
                          skip: _announcementsSkip,
                          total: _announcementsTotal,
                          onPrev: () async {
                            setState(() {
                              _announcementsSkip =
                                  (_announcementsSkip - _pageSize)
                                      .clamp(0, 1 << 30);
                            });
                            await _load();
                          },
                          onNext: () async {
                            setState(() {
                              _announcementsSkip += _pageSize;
                            });
                            await _load();
                          },
                        ),
                      ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialsTab() {
    return RefreshIndicator(
      onRefresh: _refreshCurrentTab,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildSearchBar('Search materials'),
          _sectionCard(
            title: _editingMaterialId == null
                ? 'Add Study Material'
                : 'Edit Material #$_editingMaterialId',
            action: TextButton(
              onPressed: _clearMaterialForm,
              child: const Text('Clear'),
            ),
            child: Column(
              children: [
                _textField(_materialSubject, 'Subject'),
                _textField(_materialTitle, 'Title'),
                _textField(_materialPdfUrl, 'PDF Link',
                    hintText: 'Paste direct PDF URL here'),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveMaterial,
                    child: Text(_editingMaterialId == null
                        ? 'Add Material'
                        : 'Update Material'),
                  ),
                ),
              ],
            ),
          ),
          _sectionCard(
            title: 'Materials',
            child: _filteredMaterials().isEmpty
                ? const Text('No study materials yet.')
                : Column(
                    children: _filteredMaterials().map<Widget>((material) {
                      return Card(
                        child: ListTile(
                          title: Text((material['title'] ?? '').toString()),
                          subtitle: Text(
                              '${material['subject'] ?? ''}\n${material['pdf_url'] ?? ''}'),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                _editMaterial(material);
                              } else if (value == 'delete') {
                                await _deleteMaterial(material['id'] as int);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                  value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestsTab() {
    return RefreshIndicator(
      onRefresh: _refreshCurrentTab,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildSearchBar(
            'Search tests',
            trailing: [
              DropdownButton<String>(
                value: _testStatusFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All statuses')),
                  DropdownMenuItem(value: 'upcoming', child: Text('Upcoming')),
                  DropdownMenuItem(value: 'live', child: Text('Live')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _testStatusFilter = value;
                    _testsSkip = 0;
                  });
                  _load();
                },
              ),
            ],
          ),
          _sectionCard(
            title: _editingTestId == null
                ? 'Schedule Test'
                : 'Edit Test #$_editingTestId',
            action: TextButton(
              onPressed: _clearTestForm,
              child: const Text('Clear'),
            ),
            child: Column(
              children: [
                _textField(_testTitle, 'Title'),
                DropdownButtonFormField<String>(
                  initialValue: _testType,
                  decoration: const InputDecoration(
                      labelText: 'Test Type', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'full', child: Text('full')),
                    DropdownMenuItem(value: 'subject', child: Text('subject')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _testType = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                _textField(_testSubject, 'Subject (optional)'),
                const SizedBox(height: 12),
                TextField(
                  controller: _testScheduledAt,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Scheduled At',
                    hintText: 'Tap to pick date/time',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_month),
                      onPressed: _pickScheduledAt,
                    ),
                  ),
                  onTap: _pickScheduledAt,
                ),
                const SizedBox(height: 12),
                _textField(_testDurationSeconds, 'Duration Seconds',
                    keyboardType: TextInputType.number),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveTest,
                    child: Text(_editingTestId == null
                        ? 'Create Scheduled Test'
                        : 'Update Scheduled Test'),
                  ),
                ),
              ],
            ),
          ),
          _sectionCard(
            title: 'Scheduled Tests',
            child: _filteredTests().isEmpty
                ? const Text('No scheduled tests yet.')
                : Column(
                    children: _filteredTests().map<Widget>((test) {
                      return Card(
                        child: ListTile(
                          title: Text((test['title'] ?? '').toString()),
                          subtitle: Text(
                              '${test['test_type']} • ${test['subject'] ?? 'All subjects'}\n${test['scheduled_at']}'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                _editTest(test);
                              } else if (value == 'delete') {
                                await _deleteTest(test['id'] as int);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                  value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ),
                      );
                    }).toList()
                      ..add(
                        _buildPaginationControls(
                          skip: _testsSkip,
                          total: _testsTotal,
                          onPrev: () async {
                            setState(() {
                              _testsSkip =
                                  (_testsSkip - _pageSize).clamp(0, 1 << 30);
                            });
                            await _load();
                          },
                          onNext: () async {
                            setState(() {
                              _testsSkip += _pageSize;
                            });
                            await _load();
                          },
                        ),
                      ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheatTab() {
    return RefreshIndicator(
      onRefresh: _refreshCurrentTab,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _sectionCard(
            title: 'Cheat Detection Dashboard',
            child: _cheatFlags.isEmpty
                ? const Text('No cheat activity recorded.')
                : Column(
                    children: _cheatFlags.map<Widget>((entry) {
                      final cheat = entry as Map<String, dynamic>;
                      return Card(
                        child: ListTile(
                          title: Text('Attempt #${cheat['attempt_id']}'),
                          subtitle: Text(
                              'User ${cheat['user_id']} • ${cheat['status']}'),
                          trailing: Text('Cheats: ${cheat['cheat_count']}'),
                        ),
                      );
                    }).toList()
                      ..add(
                        _buildPaginationControls(
                          skip: _cheatsSkip,
                          total: _cheatsTotal,
                          onPrev: () async {
                            setState(() {
                              _cheatsSkip =
                                  (_cheatsSkip - _pageSize).clamp(0, 1 << 30);
                            });
                            await _load();
                          },
                          onNext: () async {
                            setState(() {
                              _cheatsSkip += _pageSize;
                            });
                            await _load();
                          },
                        ),
                      ),
                  ),
          ),
        ],
      ),
    );
  }

  TextField _textField(
    TextEditingController controller,
    String label, {
    String? hintText,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(authProvider.notifier).signOut(),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load,
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _load,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Users', icon: Icon(Icons.people)),
            Tab(text: 'Questions', icon: Icon(Icons.quiz)),
            Tab(text: 'Materials', icon: Icon(Icons.picture_as_pdf)),
            Tab(text: 'Announcements', icon: Icon(Icons.campaign)),
            Tab(text: 'Tests', icon: Icon(Icons.event)),
            Tab(text: 'Cheats', icon: Icon(Icons.shield)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserTab(),
          _buildQuestionTab(),
          _buildMaterialsTab(),
          _buildAnnouncementTab(),
          _buildTestsTab(),
          _buildCheatTab(),
        ],
      ),
    );
  }
}
