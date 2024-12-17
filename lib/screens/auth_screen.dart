import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatelessWidget {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Lectura Auth')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                await _authService.signIn();
              },
              child: Text('Sign In'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _authService.signOut();
              },
              child: Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}
