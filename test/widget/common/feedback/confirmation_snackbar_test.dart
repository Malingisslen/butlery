/// Q4-01 = B (produktbeslut 2026-09-24): a confirmation snackbar (success or
/// info; not a failure, not an undo) carries "Stäng" (content-style-guide.md:
/// 97) and still closes by itself after 4-5 s. With a screen reader driving
/// navigation it stays until the user acts (PQ-21 = A, 2026-09-23).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';

Widget _app(
  void Function(BuildContext context) show, {
  bool accessibleNavigation = false,
}) => MaterialApp(
  theme: AppTheme.lightTheme,
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(accessibleNavigation: accessibleNavigation),
    child: child!,
  ),
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => show(context),
        child: const Text('Visa'),
      ),
    ),
  ),
);

SnackBar _snackBar(WidgetTester tester) =>
    tester.widget<SnackBar>(find.byType(SnackBar));

void main() {
  testWidgets('a success carries Stäng and closes by itself after 5 s', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app((c) => SnackBarUtils.showSuccess(c, 'Receptet sparades.')),
    );
    await tester.tap(find.text('Visa'));
    await tester.pumpAndSettle();

    expect(find.text('Stäng'), findsOneWidget);
    expect(_snackBar(tester).persist, isFalse);
    expect(_snackBar(tester).duration, const Duration(seconds: 5));

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Receptet sparades.'), findsNothing);
  });

  testWidgets('an info carries Stäng and closes by itself after 4 s', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app((c) => SnackBarUtils.showInfo(c, 'Sparat på enheten.')),
    );
    await tester.tap(find.text('Visa'));
    await tester.pumpAndSettle();

    expect(find.text('Stäng'), findsOneWidget);
    expect(_snackBar(tester).duration, const Duration(seconds: 4));

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Sparat på enheten.'), findsNothing);
  });

  testWidgets('Stäng closes it at once', (tester) async {
    await tester.pumpWidget(
      _app((c) => SnackBarUtils.showSuccess(c, 'Receptet sparades.')),
    );
    await tester.tap(find.text('Visa'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stäng'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('with a screen reader driving navigation, Stäng stays', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        (c) => SnackBarUtils.showSuccess(c, 'Receptet sparades.'),
        accessibleNavigation: true,
      ),
    );
    await tester.tap(find.text('Visa'));
    await tester.pumpAndSettle();

    expect(_snackBar(tester).persist, isTrue);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text('Receptet sparades.'), findsOneWidget);
  });

  testWidgets('a follow-up action replaces Stäng and stays until used', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        (c) => SnackBarUtils.showSuccess(
          c,
          'Receptet sparades.',
          actionLabel: 'Visa receptet',
          onAction: () {},
        ),
      ),
    );
    await tester.tap(find.text('Visa'));
    await tester.pumpAndSettle();

    expect(find.text('Visa receptet'), findsOneWidget);
    expect(find.text('Stäng'), findsNothing);
    expect(_snackBar(tester).persist, isTrue);
  });

  testWidgets('a failure is not a confirmation: it still stays', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        (c) =>
            SnackBarUtils.showFailure(c, what: 'Receptet kunde inte sparas.'),
      ),
    );
    await tester.tap(find.text('Visa'));
    await tester.pumpAndSettle();

    expect(find.text('Stäng'), findsOneWidget);
    expect(_snackBar(tester).persist, isTrue);
  });
}
