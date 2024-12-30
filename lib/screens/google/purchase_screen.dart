import 'package:flutter/material.dart';
import '../services/google_billing_service.dart';

class PurchaseScreen extends StatelessWidget {
  final GoogleBillingService _billingService = GoogleBillingService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Purchase Options')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _billingService.purchaseProduct('24_hour_access'),
              child: Text('Buy 24-Hour Access - $1.99'),
            ),
            ElevatedButton(
              onPressed: () => _billingService.purchaseProduct('7_day_access'),
              child: Text('Buy 7-Day Access - $4.99'),
            ),
          ],
        ),
      ),
    );
  }
}
