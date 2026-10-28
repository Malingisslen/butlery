import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/import/allergen_setup_banner.dart';

Widget _app(Widget Function(BuildContext) onTap) => MaterialApp(
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

void main() {
  testWidgets('banner removes itself instead of lingering on every tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app((context) {
        AllergenSetupBanner.show(context);
        return const SizedBox();
      }),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.byType(MaterialBanner), findsOneWidget);

    await tester.pump(AllergenSetupBanner.autoDismissAfter);
    await tester.pumpAndSettle();

    expect(find.byType(MaterialBanner), findsNothing);
  });

  testWidgets('a second import restarts the timer rather than inheriting it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app((context) {
        AllergenSetupBanner.show(context);
        return const SizedBox();
      }),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(AllergenSetupBanner.autoDismissAfter * 0.8);
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(AllergenSetupBanner.autoDismissAfter * 0.5);

    expect(find.byType(MaterialBanner), findsOneWidget);
    // The auto-dismiss timer would otherwise outlive the test.
    AllergenSetupBanner.cancelAutoDismiss();
  });

  testWidgets('manual dismiss leaves no timer that hits a later banner', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app((context) {
        AllergenSetupBanner.show(context);
        return const SizedBox();
      }),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ButleryTextButton).first);
    await tester.pumpAndSettle();
    expect(find.byType(MaterialBanner), findsNothing);

    await tester.pump(AllergenSetupBanner.autoDismissAfter);

    expect(tester.takeException(), isNull);
  });
}
