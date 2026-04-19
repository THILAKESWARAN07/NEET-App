import 'dart:convert';
import 'package:http/http.dart' as http;

Future<List> fetchQuestions() async {
  final response = await http.get(
    Uri.parse('https://neet-backend-g2d8.onrender.com/questions'),
  );

  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    throw Exception("Failed to load questions");
  }
}
