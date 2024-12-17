import 'package:url_launcher/url_launcher.dart';

class AuthService {
  final String cognitoDomain = 'https://lectura.auth.us-east-1.amazoncognito.com'; // Use environment variables for sensitive data
  final String clientId = 'YOUR_APP_CLIENT_ID'; // Replace with secure storage/env vars
  final String redirectUri = 'lectura://callback';

  /// Sign-In method
  Future<void> signIn() async {
    final Uri signInUrl = Uri.parse(
        '$cognitoDomain/login?response_type=code&client_id=$clientId&redirect_uri=$redirectUri');

    // Validate the URL
    if (Uri.tryParse(signInUrl.toString()) == null) {
      throw Exception('Invalid URL: $signInUrl');
    }

    // Launch the URL
    if (await canLaunchUrl(signInUrl)) {
      await launchUrl(signInUrl, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch $signInUrl');
    }
  }

  /// Sign-Out method
  Future<void> signOut() async {
    final Uri signOutUrl = Uri.parse(
        '$cognitoDomain/logout?client_id=$clientId&logout_uri=$redirectUri');

    // Validate the URL
    if (Uri.tryParse(signOutUrl.toString()) == null) {
      throw Exception('Invalid URL: $signOutUrl');
    }

    // Launch the URL
    if (await canLaunchUrl(signOutUrl)) {
      await launchUrl(signOutUrl, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch $signOutUrl');
    }
  }
}

