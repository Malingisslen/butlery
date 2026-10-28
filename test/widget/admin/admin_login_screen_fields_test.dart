import 'package:butlery/admin_main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/helpers/field_finder.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  testWidgets('the address and password labels stand above their boxes', (
    tester,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: AdminLoginScreen(authService: MockFactory.createAuthService()),
        wrapInScaffold: false,
      ),
    );
    await tester.pumpAndSettle();

    for (final label in ['E-post', 'Lösenord']) {
      expect(fieldLabelled(label, type: TextField), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(InputDecorator),
          matching: find.text(label),
        ),
        findsNothing,
        reason: label,
      );
    }
    expect(find.text('E-post (valfritt)'), findsNothing);
    expect(
      tester
          .widget<TextField>(fieldLabelled('Lösenord', type: TextField))
          .obscureText,
      isTrue,
    );
  });
}
