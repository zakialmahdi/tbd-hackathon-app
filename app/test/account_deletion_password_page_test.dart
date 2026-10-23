import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/screens/account_deletion_password_page.dart';

void main() {
  testWidgets('cancel closes account deletion confirmation safely', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => const AccountDeletionConfirmationDialog(),
                ),
                child: const Text('Open deletion confirmation'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open deletion confirmation'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Open deletion confirmation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancel exits password entry without submitting deletion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push<String>(
                  MaterialPageRoute<String>(
                    builder: (_) => const AccountDeletionPasswordPage(),
                  ),
                ),
                child: const Text('Open deletion verification'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open deletion verification'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm it’s you'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Open deletion verification'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
