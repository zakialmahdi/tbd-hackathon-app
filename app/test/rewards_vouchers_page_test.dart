import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/screens/rewards_vouchers_page.dart';

void main() {
  testWidgets('uses CO2 savings to unlock and claim rewards', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RewardsVouchersPage(
          co2SavingsStream: Stream<double>.multi((controller) {
            controller
              ..add(7.5)
              ..close();
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('7.5 kg'), findsOneWidget);
    expect(find.text('2.5 kg CO₂ to Reusable cup'), findsOneWidget);

    final claimButtons = find.widgetWithText(FilledButton, 'Claim');
    expect(claimButtons, findsNWidgets(2));
    expect(
      tester.widget<FilledButton>(claimButtons.first).onPressed,
      isNotNull,
    );
    expect(tester.widget<FilledButton>(claimButtons.at(1)).onPressed, isNull);

    await tester.ensureVisible(claimButtons.first);
    await tester.tap(claimButtons.first);
    await tester.pumpAndSettle();
    expect(find.text('Claim RM5 ReMarket voucher?'), findsOneWidget);

    await tester.tap(find.text('Claim reward'));
    await tester.pumpAndSettle();

    expect(find.text('RM5 ReMarket voucher'), findsOneWidget);
    expect(find.textContaining('Code: ECO'), findsOneWidget);

    await tester.tap(find.text('Rewards'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Claimed'), findsOneWidget);
  });
}
