import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class QuestionService {
  static const String url =
      "https://neet-backend-g2d8.onrender.com/questions";
  static const String cachedQuestionsKey = 'cached_questions';
  static const String cachedQuestionsTimeKey = 'questions_cache_time';
  static const int cacheMaxAgeMilliseconds = 86400000;

  static Future<List<dynamic>> fetchQuestions() async {
    final uri = Uri.parse(url);

    for (int i = 0; i < 2; i++) {
      try {
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(cachedQuestionsKey, response.body);
          await prefs.setInt(
            cachedQuestionsTimeKey,
            DateTime.now().millisecondsSinceEpoch,
          );
          return json.decode(response.body);
        }
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    final cachedTime = prefs.getInt(cachedQuestionsTimeKey);
    final cached = prefs.getString(cachedQuestionsKey);

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
}
