import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agreeo/app.dart';

void main() {
  testWidgets('renders the auth landing screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const ProviderScope(child: AgreeoApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Agreeo'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    // Field label plus the hint of the empty input.
    expect(find.text('Password'), findsNWidgets(2));
    expect(find.text('Log in'), findsOneWidget);

    // Switch to the sign-up form.
    final toggle = find.byType(GestureDetector).last;
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.text('Display name'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });
}
