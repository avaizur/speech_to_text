import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart'; // Replaced uni_links with app_links
import 'screens/home_screen.dart'; // Correct import statement
import 'screens/auth_screen.dart'; // Add this if you have the AuthScreen

void main() {
  runApp(const MyApp());
  listenForDeepLinks(); // Start listening for deep links
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
      home: const HomeScreen(), // Update this line to use HomeScreen
    );
  }
}

// Callback Listener
void listenForDeepLinks() async {
  final appLinks = AppLinks(); // Initialize AppLinks
  appLinks.uriLinkStream.listen((Uri? uri) {
    if (uri != null && uri.toString().contains('callback')) {
      final code = uri.queryParameters['code'];
      print('Authorization code: $code');
      // Exchange the code for tokens with Cognito here (future implementation)
    }
  });
}
