/// Widget test for the BUT-465 re-consent renewal dialog.
///
/// Scope:
///   1. Renders the Swedish l10n title + both action buttons.
///   2. "Senare" dismisses the dialog without navigating.
///
/// Out of scope: the "Granska" button routes to [ConsentManagementView]
/// via `ServiceLocator.get<ConsentService>()`. Exercising that path needs
/// the full DI scaffolding from the consent ViewModel suite — covered by
/// `test/unit/services/account/consent_service_test.dart` instead.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/consent/consent_renewal_dialog.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  group('BUT-465 ConsentRenewalDialog', () {
    testWidgets('renders Swedish title + both action buttons', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ConsentRenewalDialog.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        find.text('Vi har uppdaterat våra användarvillkor'),
        findsOneWidget,
      );
      expect(find.text('Granska samtycken'), findsOneWidget);
      expect(find.text('Senare'), findsOneWidget);
    });

    testWidgets('"Senare" dismisses the dialog without navigation', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ConsentRenewalDialog.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Senare'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
