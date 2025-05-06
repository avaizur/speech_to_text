import 'package:flutter/material.dart';
import 'services/paypal_service.dart';

class PaymentScreen extends StatelessWidget {
  final PayPalService _payPalService = PayPalService();

  Future<void> makePayment(double amount) async {
    try {
      final order = await _payPalService.createOrder(amount);
      // Redirect user to PayPal approval link
      final approvalUrl = order['links']
          .firstWhere((link) => link['rel'] == 'approve')['href'];
      // Use a WebView or launch URL
    } catch (e) {
      print('Payment Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Payment')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => makePayment(1.99),
              child: Text('Pay $1.99 for 24-Hour Access'),
            ),
            ElevatedButton(
              onPressed: () => makePayment(7.99),
              child: Text('Subscribe for $7.99/Month'),
            ),
          ],
        ),
      ),
    );
  }
}
