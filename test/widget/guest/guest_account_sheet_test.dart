// BUT-920: the "Skapa konto för att …" sheet and its single launcher hook.

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/widgets/guest/guest_account_sheet.dart';
import 'package:butlery/widgets/guest/guest_upgrade_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'guest_test_support.dart';

final _sv = AppLocalizationsSv();

class _CountingLauncher extends GuestUpgradeLauncher {
  int launched = 0;

  @override
  void launch(BuildContext context) => launched++;
}

void main() {
  final variants = {
    GuestAccountReason.share: (
      'Skapa konto för att dela',
      'Delning kräver ett konto, så att den du delar med ser vem du är. '
          'Allt du gjort som gäst följer med.',
    ),
    GuestAccountReason.together: (
      'Skapa konto för att göra saker tillsammans',
      'Vänner, grupper, meddelanden och hushåll kräver ett konto, så att '
          'andra ser vem du är. Allt du gjort som gäst följer med.',
    ),
    GuestAccountReason.importLimit: (
      'Du har använt dina tre importer',
      'Skapa ett gratis konto för att importera fler recept från länkar '
          'och foton. Recepten du redan importerat följer med.',
    ),
  };

  for (final entry in variants.entries) {
    testWidgets('${entry.key.name}: title, body and two buttons', (
      tester,
    ) async {
      final launcher = _CountingLauncher();
      late BuildContext context;
      await tester.pumpWidget(
        guestApp(
          Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      showGuestAccountSheet(context, entry.key, launcher: launcher);
      await tester.pumpAndSettle();

      expect(find.text(entry.value.$1), findsOneWidget);
      expect(find.text(entry.value.$2), findsOneWidget);
      expect(
        tester.getSize(find.widgetWithText(ElevatedButton, 'Skapa konto')).height,
        greaterThanOrEqualTo(48),
      );

      await tester.tap(find.text(_sv.guestNotNow));
      await tester.pumpAndSettle();
      expect(find.text(entry.value.$1), findsNothing);
      expect(launcher.launched, 0);
    });
  }

  testWidgets('"Skapa konto" closes the sheet and calls the launcher once', (
    tester,
  ) async {
    final launcher = _CountingLauncher();
    late BuildContext context;
    await tester.pumpWidget(
      guestApp(
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    showGuestAccountSheet(
      context,
      GuestAccountReason.share,
      launcher: launcher,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(_sv.guestCreateAccount));
    await tester.pumpAndSettle();

    expect(find.text(_sv.guestSheetShareTitle), findsNothing);
    expect(launcher.launched, 1);
  });
}
