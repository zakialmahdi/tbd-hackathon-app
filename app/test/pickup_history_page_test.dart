import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/screens/pickup_history_page.dart';

void main() {
  testWidgets('filters pickup history and opens booking details', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PickupHistoryPage()));

    expect(find.text('Pickup history'), findsOneWidget);
    expect(find.text('2 pickups completed'), findsOneWidget);
    expect(find.text('3 records'), findsOneWidget);

    await tester.tap(find.text('Cancelled'));
    await tester.pumpAndSettle();

    expect(find.text('1 record'), findsOneWidget);
    expect(find.text('Wardrobe + Garden waste'), findsOneWidget);
    expect(find.text('Sofa + Mattress'), findsNothing);

    await tester.tap(find.text('Wardrobe + Garden waste'));
    await tester.pumpAndSettle();

    expect(find.text('Pickup details'), findsOneWidget);
    expect(find.text('Booking VE-240511'), findsNWidgets(2));
    expect(find.text('No charge'), findsNWidgets(2));
  });
}
