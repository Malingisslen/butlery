// BUT-2371: CapturedSnackBars shows the ink snackbar on a messenger captured
// while the context was alive, so callers that pop or await first no longer
// build a SnackBar by hand.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/captured_snackbars.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.lightTheme,
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: home,
);

void main() {
  testWidgets('shows after the context it was captured from is gone', (
    tester,
  ) async {
    late CapturedSnackBars captured;
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: AppTheme.lightTheme,
        locale: const Locale('sv'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const Scaffold(body: Text('Under')),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (context) {
          captured = CapturedSnackBars.capture(context);
          return const Scaffold(body: Text('Över'));
        },
      ),
    );
    await tester.pumpAndSettle();
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Över'), findsNothing);

    captured.showFailure(what: 'Exporten misslyckades.');
    await tester.pumpAndSettle();

    expect(find.byType(InkSnackBar), findsOneWidget);
    expect(find.text('Exporten misslyckades.'), findsOneWidget);
    expect(find.text('Stäng'), findsOneWidget);
  });

  testWidgets('a failure is an alert that stays until closed', (tester) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => CapturedSnackBars.capture(
                context,
              ).showFailure(what: 'Kunde inte spara.'),
              child: const Text('Visa'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Visa'));
    await tester.pumpAndSettle();

    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.persist, isTrue);
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.role == SemanticsRole.alert,
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Stäng'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a confirmation carries Stäng and closes by itself', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => CapturedSnackBars.capture(
                context,
              ).showConfirmation('Tiden är ute.'),
              child: const Text('Visa'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Visa'));
    await tester.pumpAndSettle();
    expect(find.text('Stäng'), findsOneWidget);
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).persist, isFalse);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('jumpQueue replaces what is on screen instead of queueing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                final s = CapturedSnackBars.capture(context);
                s.showFailure(what: 'Först.');
                s.show('Sedan.', jumpQueue: true);
              },
              child: const Text('Visa'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Visa'));
    await tester.pumpAndSettle();
    expect(find.text('Först.'), findsNothing);
    expect(find.text('Sedan.'), findsOneWidget);
  });

  testWidgets('without a ScaffoldMessenger it shows nothing and returns null', (
    tester,
  ) async {
    Object? result = 'unset';
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('sv'),
        delegates: AppLocalizations.localizationsDelegates,
        child: Builder(
          builder: (context) {
            result = CapturedSnackBars.capture(context).show('Ingenting.');
            return const SizedBox();
          },
        ),
      ),
    );
    expect(result, isNull);
  });
}
