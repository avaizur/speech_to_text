import 'package:flutter/material.dart';
import '../services/paypal_service.dart'; // Adjust the path if needed

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PayPalService _payPalService = PayPalService();

  Future<void> _handlePayPalOrder() async {
    print('?? PayPal button pressed');
    try {
      final order = await _payPalService.createOrder(1.99); // Example amount
      await openPayPalApprovalUrl(order);
    } catch (e) {
      print('? Error creating PayPal order: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Screen'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Welcome to the Home Screen!'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _handlePayPalOrder,
              child: const Text('Create PayPal Order'),
            ),
          ],
        ),
      ),
    );
  }
}

