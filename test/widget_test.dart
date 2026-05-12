import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailychallenge_app/main.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DailyChallengeApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
