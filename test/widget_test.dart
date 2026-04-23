// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:agreeo/app.dart';

void main() {
  testWidgets('renders the auth landing screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AgreeoApp()));

    expect(find.text('Agreeo'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text("Don't have an account? Sign Up"),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text("Don't have an account? Sign Up"));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
  });
}
