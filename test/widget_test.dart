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

    expect(find.text('Agreeo'), findsNWidgets(2));
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);

    await tester.tap(find.byType(GestureDetector).last);
    await tester.pumpAndSettle();

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
  });
}
