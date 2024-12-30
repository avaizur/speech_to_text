import 'dart:convert';
import 'package:http/http.dart' as http;

class PayPalService {
  final String clientId = 'Ad9i5RBkbbt-pXfWd6BU9YpWfKyG2qcj6h69W8aXdYluJfvKcPdtTnlDbRs6dyM948jgxd3CxGYLHsn-';
  final String clientSecret = 'ECwTs0xlu48Kx3w-8MUNbdRwSxGTajim3sqWdAK0B0BVRPf2URmm3CTFt4AJKRSHjNMIy3_hRWsFfM-T';
  final String baseUrl = 'https://api.paypal.com'; // Use production URL when live

  Future<String> getAccessToken() async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/oauth2/token'),
      headers: {
        'Authorization': 'Basic ${base64Encode(utf8.encode('$clientId:$clientSecret'))}',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: 'grant_type=client_credentials',
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['access_token'];
    } else {
      throw Exception('Failed to get access token: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> createOrder(double amount) async {
    final accessToken = await getAccessToken();
    final response = await http.post(
      Uri.parse('$baseUrl/v2/checkout/orders'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'intent': 'CAPTURE',
        'purchase_units': [
          {
            'amount': {
              'currency_code': 'USD',
              'value': amount.toStringAsFixed(2),
            },
          },
        ],
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create order: ${response.body}');
    }
  }
}
