// Basic widget test for WireTuner application.
import 'package:flutter_test/flutter_test.dart';

import 'package:wiretuner/app.dart';

void main() {
  testWidgets('WireTuner app launches with placeholder text',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const App());

    // Verify that the placeholder text is displayed.
    expect(
      find.text('WireTuner - Vector Drawing Application'),
      findsOneWidget,
    );

    // Verify that the app bar title is displayed.
    expect(find.text('WireTuner'), findsOneWidget);
  });
}
