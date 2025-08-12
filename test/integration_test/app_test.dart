import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App launches', (WidgetTester tester) async {
    // Load your app
    await tester.pumpWidget(MyApp());

    // Verify something exists
    expect(find.text('Your App Title'), findsOneWidget);
  });

