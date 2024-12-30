ElevatedButton(
  onPressed: () async {
    final payPalService = PayPalService();
    final order = await payPalService.createOrder(1.99);
    print('PayPal Order Created: $order');
    // Redirect user to PayPal approval link
  },
  child: Text('Pay via PayPal - $1.99'),
),
