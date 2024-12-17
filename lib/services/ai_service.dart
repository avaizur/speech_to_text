import 'package:http/http.dart' as http;
import 'dart:convert';

class AIService {
  Future<String> analyzeText(String text) async {
    try {
      final response = await http
          .post(
            Uri.parse('https://lectura.co.uk/analyze'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text}),
          )
          .timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['analyzedText'];
      } else {
        print('Response Code: ${response.statusCode}, Body: ${response.body}');
        throw Exception('Failed to analyze text: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error in analyzeText: $e');
      rethrow;
    }
  }
}
