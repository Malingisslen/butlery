import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/import/allergen_setup_banner.dart';
import 'package:butlery/widgets/import/clipboard_url_banner.dart';

Widget _app(void Function(BuildContext) onTap) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => onTap(context),
        child: const Text('go'),
      ),
    ),
  ),
);

int _used = 0;

void _showClipboard(BuildContext context) => ClipboardUrlBanner.show(
  ScaffoldMessenger.of(context),
  AppLocalizations.of(context),
  onUse: () => _used++,
);

void main() {
  setUp(() => _used = 0);

  testWidgets('banner removes itself after the auto-dismiss time', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_showClipboard));
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text('Receptlänk hittad i urklipp'), findsOneWidget);

    await tester.pump(ClipboardUrlBanner.autoDismissAfter);
    await tester.pumpAndSettle();

    expect(find.byType(MaterialBanner), findsNothing);
  });

  testWidgets('its timer does not close an allergen banner shown later', (
    tester,
  ) async {
    var step = 0;
    await tester.pumpWidget(
      _app((c) {
        if (step++ == 0) {
          _showClipboard(c);
        } else {
          AllergenSetupBanner.show(c);
        }
      }),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(ClipboardUrlBanner.autoDismissAfter * 0.5);

    // Allergen prompt replaces the clipboard banner mid-timer.
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Receptlänk hittad i urklipp'), findsNothing);

    await tester.pump(ClipboardUrlBanner.autoDismissAfter * 0.75);
    await tester.pump();

    expect(find.byType(MaterialBanner), findsOneWidget);
    // The allergen auto-dismiss timer would otherwise outlive the test.
    AllergenSetupBanner.cancelAutoDismiss();
  });

  testWidgets('"Använd" runs the import callback and closes the banner', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_showClipboard));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Använd'));
    await tester.pumpAndSettle();

    expect(_used, 1);
    expect(find.byType(MaterialBanner), findsNothing);
  });

  testWidgets('"Stäng" closes the banner without importing', (tester) async {
    await tester.pumpWidget(_app(_showClipboard));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stäng'));
    await tester.pumpAndSettle();

    expect(_used, 0);
    expect(find.byType(MaterialBanner), findsNothing);
  });
}
