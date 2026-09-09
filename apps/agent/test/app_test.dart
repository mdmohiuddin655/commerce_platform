import 'package:agent_app/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('agent foundation shell builds and names its role', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AgentApp());

    expect(find.text('agent'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
