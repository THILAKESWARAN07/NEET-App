import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/api/api_client.dart';

Future<List> fetchQuestions() async {
  final response = await http.get(
    Uri.parse('$backendBaseUrl/questions'),
  );

  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    throw Exception("Failed to load questions");
  }
}
