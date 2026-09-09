import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/app/app.dart';

void main() {
  testWidgets('user foundation shell builds and names its role', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const UserApp());

    expect(find.text('user'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
