import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/app/app.dart';

void main() {
  testWidgets('rider foundation shell builds and names its role', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const RiderApp());

    expect(find.text('rider'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
