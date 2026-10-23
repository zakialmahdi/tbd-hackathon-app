import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('Sign-in is required before opening the app', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      VertivEraApp(
        authStateChanges: Stream<User?>.value(null).asBroadcastStream(),
      ),
    );

    expect(find.text('Waste less. Circle more.'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to continue.'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('ReMarket'), findsNothing);
    expect(find.text('Bin Map'), findsNothing);
    expect(find.text('New here? Create an account'), findsOneWidget);

    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('Create an account to continue.'), findsOneWidget);
    expect(find.text('Already have an account? Sign in'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'test_user');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'user@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');
    await tester.enterText(find.byType(TextFormField).at(3), 'password456');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match.'), findsOneWidget);
  });
}
