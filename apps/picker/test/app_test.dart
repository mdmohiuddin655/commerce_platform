import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picker_app/app/app.dart';

void main() {
  testWidgets('picker foundation shell builds and names its role', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PickerApp());

    expect(find.text('picker'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
