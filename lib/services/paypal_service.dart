import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

/// PayPal service (zero-arg createOrder) now uses .env prices.
/// Required in assets/config/app.env:
///   PAYPAL_ENV=sandbox|live
///   PAYPAL_CLIENT_ID=...
///   PAYPAL_CLIENT_SECRET=...
///   PRICE_MONTHLY=7.99 (used by default)
///   PRICE_YEARLY=79.99
///   PRICE_PAY_AS_YOU_GO=0.10
class PayPalService {
  PayPalService();

  String get _env => (dotenv.env['PAYPAL_ENV'] ?? 'sandbox').toLowerCase().trim();
  bool get _isSandbox => _env != 'live';

  String get _baseAuth => _isSandbox
      ? 'https://api-m.sandbox.paypal.com'
      : 'https://api-m.paypal.com';

  String get _clientId => dotenv.env['PAYPAL_CLIENT_ID']?.trim() ?? '';
  String get _clientSecret => dotenv.env['PAYPAL_CLIENT_SECRET']?.trim() ?? '';

  // Prices
  String get _priceMonthly => (dotenv.env['PRICE_MONTHLY'] ?? '1.99').trim();
  String get _priceYearly => (dotenv.env['PRICE_YEARLY'] ?? '19.99').trim();
  String get _pricePayg => (dotenv.env['PRICE_PAY_AS_YOU_GO'] ?? '0.10').trim();

  Future<String> _getAccessToken() async {
    if (_clientId.isEmpty || _clientSecret.isEmpty) {
      throw Exception('PayPal client credentials missing. Check env.');
    }

    final basic = base64Encode(utf8.encode('$_clientId:$_clientSecret'));
    final uri = Uri.parse('$_baseAuth/v1/oauth2/token');

    final resp = await http.post(
      uri,
      headers: {
        'Authorization': 'Basic $basic',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: 'grant_type=client_credentials',
    ).timeout(const Duration(seconds: 20));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('PayPal auth failed (${resp.statusCode}): ${resp.body}');
    }

    final token = (jsonDecode(resp.body) as Map<String, dynamic>)['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('PayPal auth: no access_token in response');
    }
    if (kDebugMode) {
      debugPrint('PayPal ENV: ${_isSandbox ? 'sandbox' : 'live'}  base: $_baseAuth');
    }
    return token;
  }

  /// Creates a PayPal order and returns the browser approval URL.
  /// - `plan` can be 'monthly' (default), 'yearly', or 'payg'
  Future<String> createOrder({
    String plan = 'monthly',
    String currency = 'USD',
    String description = 'Lectura Pro Upgrade',
    String? returnUrl,
    String? cancelUrl,
  }) async {
    final amount = switch (plan.toLowerCase().trim()) {
      'yearly' => _priceYearly,
      'payg' => _pricePayg,
      _ => _priceMonthly,
    };

    final token = await _getAccessToken();
    final uri = Uri.parse('$_baseAuth/v2/checkout/orders');

    final payload = {
      'intent': 'CAPTURE',
      'purchase_units': [
        {
          'amount': {
            'currency_code': currency,
            'value': amount,
          },
          'description': description,
        }
      ],
      'application_context': {
        'brand_name': 'Lectura',
        'landing_page': 'NO_PREFERENCE',
        'user_action': 'PAY_NOW',
        'return_url': returnUrl ?? 'https://www.lectura.co.uk/paypal/success',
        'cancel_url': cancelUrl ?? 'https://www.lectura.co.uk/paypal/cancel',
      },
    };

    final resp = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 20));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('PayPal order failed (${resp.statusCode}): ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final links = (data['links'] as List?)?.cast<dynamic>() ?? const [];
    for (final l in links) {
      final m = (l as Map).cast<String, dynamic>();
      if (m['rel'] == 'approve' && m['href'] is String) return m['href'] as String;
    }
    for (final l in links) {
      final m = (l as Map).cast<String, dynamic>();
      if (m['rel'] == 'payer-action' && m['href'] is String) return m['href'] as String;
    }
    throw Exception('PayPal order created but no approval link found: ${resp.body}');
  }
}
