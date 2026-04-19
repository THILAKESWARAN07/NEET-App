import 'dart:convert';
import 'package:http/http.dart' as http;

class RemoteQuestionsService {
  const RemoteQuestionsService();

  static const String questionsUrl = String.fromEnvironment(
    'QUESTIONS_URL',
    defaultValue: 'https://neet-backend-g2d8.onrender.com/questions',
  );

  Future<List<dynamic>> fetchQuestions() async {
    final response = await http.get(Uri.parse(questionsUrl));

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded is List) {
        return decoded;
      }
      throw Exception('Questions response is not a list');
    }

    throw Exception('Failed to load questions');
  }
}
