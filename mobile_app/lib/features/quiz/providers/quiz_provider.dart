import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/storage/app_storage.dart';

final quizProvider = StateNotifierProvider<QuizNotifier, QuizState>((ref) {
  return QuizNotifier(ref.read(dioProvider), ref.read(appStorageProvider));
});

class QuizQuestion {
  final int id;
  final String subject;
  final String topic;
  final String questionText;
  final List<String> options;
  final String? imageUrl;

  QuizQuestion({
    required this.id,
    required this.subject,
    required this.topic,
    required this.questionText,
    required this.options,
    this.imageUrl,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'] as int,
      subject: json['subject'] as String,
      topic: json['topic'] as String,
      questionText: json['question_text'] as String,
      options:
          (json['options'] as List<dynamic>).map((e) => e.toString()).toList(),
      imageUrl: (json['image_url'] ?? '').toString().trim().isEmpty
          ? null
          : json['image_url'].toString(),
    );
  }
}

class QuizResult {
  final int attemptId;
  final int score;
  final int correct;
  final int wrong;
  final int unattempted;
  final double accuracyPercent;
  final int timeTaken;
  final List<QuestionResultItem> questionResults;

  QuizResult({
    required this.attemptId,
    required this.score,
    required this.correct,
    required this.wrong,
    required this.unattempted,
    required this.accuracyPercent,
    required this.timeTaken,
    this.questionResults = const [],
  });

  factory QuizResult.fromJson(Map<String, dynamic> json) {
    return QuizResult(
      attemptId: json['attempt_id'] as int,
      score: json['score'] as int,
      correct: json['correct'] as int,
      wrong: json['wrong'] as int,
      unattempted: json['unattempted'] as int,
      accuracyPercent: (json['accuracy_percent'] as num).toDouble(),
      timeTaken: json['time_taken'] as int,
      questionResults: (json['question_results'] as List<dynamic>? ?? const [])
          .map((e) => QuestionResultItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class QuestionResultItem {
  final int questionNumber;
  final int questionId;
  final String status;
  final String? selectedOption;
  final String correctAnswer;

  QuestionResultItem({
    required this.questionNumber,
    required this.questionId,
    required this.status,
    this.selectedOption,
    required this.correctAnswer,
  });

  factory QuestionResultItem.fromJson(Map<String, dynamic> json) {
    return QuestionResultItem(
      questionNumber: json['question_number'] as int,
      questionId: json['question_id'] as int,
      status: (json['status'] ?? '').toString(),
      selectedOption: (json['selected_option'] ?? '').toString().isEmpty
          ? null
          : json['selected_option'].toString(),
      correctAnswer: (json['correct_answer'] ?? '').toString(),
    );
  }
}

class WrongQuestionItem {
  final QuizQuestion question;
  final String selectedOption;
  final String correctAnswer;
  final int lastAttemptId;
  final DateTime lastAttemptedAt;

  WrongQuestionItem({
    required this.question,
    required this.selectedOption,
    required this.correctAnswer,
    required this.lastAttemptId,
    required this.lastAttemptedAt,
  });

  factory WrongQuestionItem.fromJson(Map<String, dynamic> json) {
    return WrongQuestionItem(
      question: QuizQuestion.fromJson(json['question'] as Map<String, dynamic>),
      selectedOption: (json['selected_option'] ?? '').toString(),
      correctAnswer: (json['correct_answer'] ?? '').toString(),
      lastAttemptId: json['last_attempt_id'] as int,
      lastAttemptedAt: DateTime.parse(json['last_attempted_at'] as String),
    );
  }
}

class QuizState {
  final int timeRemainingSeconds;
  final int cheatWarnings;
  final bool isSubmitted;
  final bool isLoading;
  final int? attemptId;
  final List<QuizQuestion> questions;
  final Map<int, String> selectedAnswers;
  final int currentQuestionIndex;
  final Set<int> markedForReview;
  final QuizResult? result;
  final String? error;
  final String? submissionNotice;

  QuizState({
    this.timeRemainingSeconds = 10800, // 3 hours
    this.cheatWarnings = 0,
    this.isSubmitted = false,
    this.isLoading = false,
    this.attemptId,
    this.questions = const [],
    this.selectedAnswers = const {},
    this.currentQuestionIndex = 0,
    this.markedForReview = const <int>{},
    this.result,
    this.error,
    this.submissionNotice,
  });

  QuizState copyWith({
    int? timeRemainingSeconds,
    int? cheatWarnings,
    bool? isSubmitted,
    bool? isLoading,
    int? attemptId,
    List<QuizQuestion>? questions,
    Map<int, String>? selectedAnswers,
    int? currentQuestionIndex,
    Set<int>? markedForReview,
    QuizResult? result,
    String? error,
    String? submissionNotice,
  }) {
    return QuizState(
      timeRemainingSeconds: timeRemainingSeconds ?? this.timeRemainingSeconds,
      cheatWarnings: cheatWarnings ?? this.cheatWarnings,
      isSubmitted: isSubmitted ?? this.isSubmitted,
      isLoading: isLoading ?? this.isLoading,
      attemptId: attemptId ?? this.attemptId,
      questions: questions ?? this.questions,
      selectedAnswers: selectedAnswers ?? this.selectedAnswers,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      markedForReview: markedForReview ?? this.markedForReview,
      result: result ?? this.result,
      error: error,
      submissionNotice: submissionNotice,
    );
  }
}

class QuizNotifier extends StateNotifier<QuizState> {
  final Dio _dio;
  final AppStorage _storage;
  Timer? _timer;

  QuizNotifier(this._dio, this._storage) : super(QuizState());

  String _extractApiError(Object error) {
    if (error is DioException) {
      final responseData = error.response?.data;
      if (responseData is Map<String, dynamic>) {
        final detail = responseData['detail'];
        if (detail is String && detail.isNotEmpty) {
          return detail;
        }
      }
      if (responseData is String && responseData.isNotEmpty) {
        return responseData;
      }
      if (error.message != null && error.message!.isNotEmpty) {
        return error.message!;
      }
    }
    return error.toString();
  }

  void _initializeAttemptFromResponse(Map<String, dynamic> data) {
    final attemptId = data['id'] as int;
    final questions = (data['questions'] as List<dynamic>)
        .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
        .toList();

    state = QuizState(
      isLoading: false,
      attemptId: attemptId,
      questions: questions,
      timeRemainingSeconds: data['duration_seconds'] as int,
    );
    startTimer();
  }

  Future<void> startOrResumeQuiz(
      {String testType = 'full', String? subject}) async {
    try {
      if (testType == 'subject' && (subject == null || subject.trim().isEmpty)) {
        state = QuizState(error: 'Please select a subject before starting subject practice.');
        return;
      }

      state = QuizState(isLoading: true);
      final response = await _dio.post(
        '/quiz/start',
        data: {
          'test_type': testType,
          'subject': subject,
          'question_count': testType == 'full' ? 180 : 45,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final attemptId = data['id'] as int;
      await _storage.saveAttemptId(attemptId);
      _initializeAttemptFromResponse(data);
    } catch (error) {
      state = QuizState(error: _extractApiError(error));
    }
  }

  Future<void> startReattemptQuiz({
    String? subject,
    List<int>? questionIds,
    int questionCount = 30,
    bool fromLatestCompletedTest = false,
  }) async {
    try {
      state = QuizState(isLoading: true);
      final response = await _dio.post(
        '/quiz/start-reattempt',
        data: {
          'subject': subject,
          'question_ids': questionIds,
          'question_count': questionCount,
          'from_latest_completed_test': fromLatestCompletedTest,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final attemptId = data['id'] as int;
      await _storage.saveAttemptId(attemptId);
      _initializeAttemptFromResponse(data);
    } catch (error) {
      state = QuizState(error: _extractApiError(error));
    }
  }

  Future<List<WrongQuestionItem>> fetchWrongQuestions({
    String? subject,
    int limit = 30,
  }) async {
    final response = await _dio.get(
      '/quiz/wrong-questions',
      queryParameters: {
        if (subject != null && subject.isNotEmpty) 'subject': subject,
        'limit': limit,
      },
    );

    final data = response.data as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map((item) => WrongQuestionItem.fromJson(item as Map<String, dynamic>))
        .toList();
    return items;
  }

  void startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.timeRemainingSeconds > 0) {
        state = state.copyWith(
            timeRemainingSeconds: state.timeRemainingSeconds - 1);
      } else {
        autoSubmit("timeout");
      }
    });
  }

  void selectOption(String option) {
    if (state.isSubmitted) return;
    if (state.questions.isEmpty) return;
    final question = state.questions[state.currentQuestionIndex];
    final newMap = {...state.selectedAnswers, question.id: option};
    state = state.copyWith(selectedAnswers: newMap);
    _submitAnswer(question.id, option);
  }

  Future<void> _submitAnswer(int questionId, String option) async {
    if (state.attemptId == null) return;
    await _dio.post('/quiz/${state.attemptId}/answer', data: {
      'question_id': questionId,
      'selected_option': option,
    });
  }

  void nextQuestion() {
    if (state.currentQuestionIndex < state.questions.length - 1) {
      state =
          state.copyWith(currentQuestionIndex: state.currentQuestionIndex + 1);
    }
  }

  void jumpToQuestion(int index) {
    if (index < 0 || index >= state.questions.length) {
      return;
    }
    state = state.copyWith(currentQuestionIndex: index);
  }

  void toggleMarkForReview() {
    if (state.questions.isEmpty) {
      return;
    }
    final questionId = state.questions[state.currentQuestionIndex].id;
    final marked = {...state.markedForReview};
    if (marked.contains(questionId)) {
      marked.remove(questionId);
    } else {
      marked.add(questionId);
    }
    state = state.copyWith(markedForReview: marked);
  }

  void previousQuestion() {
    if (state.currentQuestionIndex > 0) {
      state =
          state.copyWith(currentQuestionIndex: state.currentQuestionIndex - 1);
    }
  }

  Future<void> logCheat() async {
    if (state.isSubmitted) return;

    final newWarnings = state.cheatWarnings + 1;
    state = state.copyWith(cheatWarnings: newWarnings);
    if (state.attemptId != null) {
      await _dio.post('/quiz/${state.attemptId}/log-cheat',
          data: {'event': 'app_backgrounded'});
    }

    if (newWarnings >= 3) {
      await autoSubmit('terminated');
    }
  }

  Future<void> autoSubmit(String reason) async {
    if (state.isSubmitted || state.isLoading) {
      return;
    }

    _timer?.cancel();
    state = state.copyWith(isLoading: true);
    bool submitSucceeded = false;

    try {
      if (state.attemptId != null) {
        await _dio.post('/quiz/${state.attemptId}/submit');
        submitSucceeded = true;

        try {
          final resultResponse =
              await _dio.get('/quiz/${state.attemptId}/result');
          final result =
              QuizResult.fromJson(resultResponse.data as Map<String, dynamic>);
          await _storage.clearAttemptId();
          state = state.copyWith(
            isLoading: false,
            isSubmitted: true,
            result: result,
            error: null,
            submissionNotice: null,
          );
        } catch (resultError, resultStackTrace) {
          debugPrint('Quiz result fetch failed after submit: $resultError');
          debugPrintStack(stackTrace: resultStackTrace);
          await _storage.clearAttemptId();
          state = state.copyWith(
            isLoading: false,
            isSubmitted: true,
            error: null,
            submissionNotice:
                'Test submitted successfully. We could not load the detailed result right now.',
          );
        }

        return;
      }

      state = state.copyWith(isLoading: false, isSubmitted: true);
    } catch (error, stackTrace) {
      debugPrint('Quiz submit failed ($reason): $error');
      debugPrintStack(stackTrace: stackTrace);
      state = state.copyWith(isLoading: false);

      if (!submitSucceeded && !state.isSubmitted && state.timeRemainingSeconds > 0) {
        startTimer();
      }

      if (!submitSucceeded) {
        rethrow;
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
