import 'package:http/http.dart' as http;
import 'dart:convert';

class AIService {
  Future<String> analyzeText(String text) async {
    try {
      final response = await http.post(
        Uri.parse('https://lectura.co.uk/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['analyzedText'];
      } else {
        throw Exception('Failed to analyze text: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error in analyzeText: $e');
      rethrow;
    }
  }
}

