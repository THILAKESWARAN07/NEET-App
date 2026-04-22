import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';
import '../core/storage/app_storage.dart';

class QuestionService {
  static const String _questionsUrl = '$backendBaseUrl/questions';
  static const String _submitUrl = '$apiBaseUrl/quiz/submit-json';
  static const String _cachedQuestionsKey = 'cached_questions_v2';
  static const String _cachedQuestionsTimeKey = 'questions_cache_time_v2';
  static const String _cachedQuestionsSourceKey = 'questions_cache_source_v2';
  static const int cacheMaxAgeMilliseconds = 86400000;
  static final AppStorage _storage = AppStorage();

  static Future<List<dynamic>> fetchQuestions() async {
    final uri = Uri.parse(_questionsUrl);

    for (int i = 0; i < 2; i++) {
      try {
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cachedQuestionsKey, response.body);
          await prefs.setInt(
            _cachedQuestionsTimeKey,
            DateTime.now().millisecondsSinceEpoch,
          );
          await prefs.setString(_cachedQuestionsSourceKey, _questionsUrl);
          return json.decode(response.body);
        }
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    final cachedTime = prefs.getInt(_cachedQuestionsTimeKey);
    final cached = prefs.getString(_cachedQuestionsKey);
    final cachedSource = prefs.getString(_cachedQuestionsSourceKey);

    // Prevent mixing cache from a different backend URL.
    if (cachedSource != null && cachedSource != _questionsUrl) {
      throw Exception("No data available");
    }

    if (cached != null && cachedTime != null) {
      final age = DateTime.now().millisecondsSinceEpoch - cachedTime;
      if (age <= cacheMaxAgeMilliseconds) {
        return json.decode(cached);
      }
    }

    if (cached != null && cachedTime == null) {
      return json.decode(cached);
    }

    throw Exception("No data available");
  }

  static Future<bool> submitQuizScore({
    required int score,
    required int total,
    required int timeInSeconds,
    int durationSeconds = 10800,
    String testType = 'json_mock',
    String? subject,
    String? authToken,
    double? accuracyPercent,
    List<Map<String, dynamic>>? questionAttempts,
  }) async {
    try {
      final token = authToken ?? await _storage.readToken();
      final submitUrl = Uri.parse(_submitUrl);

      final headers = {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final payload = {
        'score': score,
        'total': total,
        'time_taken_seconds': timeInSeconds,
        'duration_seconds': durationSeconds,
        'accuracy_percent': double.parse(
          (accuracyPercent ?? (total == 0 ? 0.0 : (score / total) * 100))
              .toStringAsFixed(2),
        ),
        'test_type': testType,
        if (subject != null) 'subject': subject,
        if (questionAttempts != null && questionAttempts.isNotEmpty)
          'question_attempts': questionAttempts,
      };

      final response = await http
          .post(
            submitUrl,
            headers: headers,
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 15));

      // Success if 200 or 201
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      // Log error but don't throw - local quiz should still work
      if (kDebugMode) {
        debugPrint('Error submitting quiz score: $e');
      }
      return false;
    }
  }
}
