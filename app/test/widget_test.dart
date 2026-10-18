import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('Splash navigates to the home shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VertivEraApp());

    expect(find.text('Waste less. Circle more.'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    expect(find.text('Bin Map'), findsOneWidget);
    expect(find.text('Services'), findsOneWidget);
  });
}
