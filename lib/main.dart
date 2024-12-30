import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'services/paypal_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AppLinks _appLinks;
  final PayPalService _payPalService = PayPalService(); // Instantiate PayPalService

  @override
  void initState() {
    super.initState();
    _initializeDeepLinkListener();
  }

  void _initializeDeepLinkListener() async {
    _appLinks = AppLinks();
    _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null && uri.toString().contains('callback')) {
        final code = uri.queryParameters['code'];
        print('Authorization code: $code');
        // Future implementation: Exchange the code for tokens with Cognito
      }
    });
  }

  Future<void> _createOrder(double amount) async {
    try {
      final order = await _payPalService.createOrder(amount);
      print('Order created: $order');
      // Handle the order response as needed
    } catch (e) {
      print('Error creating order: $e');
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
            const Text('Welcome to the Home Screen'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await _createOrder(10.00); // Example order amount in USD
              },
              child: const Text('Create PayPal Order'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Removed _appLinks.dispose() since it's not defined in the package
    super.dispose();
  }
}
