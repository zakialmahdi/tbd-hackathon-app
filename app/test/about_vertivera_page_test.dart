import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/screens/about_vertivera_page.dart';

void main() {
  testWidgets('shows VertivEra overview and app version', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutVertivEraPage()));

    expect(find.text('About VertivEra'), findsOneWidget);
    expect(find.byKey(const ValueKey('vertivera-app-icon')), findsOneWidget);
    expect(find.text('Waste less. Circle more.'), findsOneWidget);
    expect(find.text('A cleaner future, together'), findsOneWidget);
    expect(find.text('Give items another life'), findsOneWidget);
    expect(find.text('Find nearby recycling bins'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Get help with bulky items'),
      250,
    );
    expect(find.text('Get help with bulky items'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Version 1.0.0'), 250);
    expect(find.text('Version 1.0.0'), findsOneWidget);
  });
}
