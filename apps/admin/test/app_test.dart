import 'package:admin_app/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin foundation shell builds and names its role', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AdminApp());

    expect(find.text('admin'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
