// P3-U1: the one undo primitive (produktregler.md:125-140, § 2.4).
//
// Class 1 (`add`, `delete`) carries a 7 s snackbar whose action is "Ångra"
// (produktregler.md:131-132, content-style-guide.md:77). The primitive owns
// both numbers so no call site can drift to 4 or 5 seconds again.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/utils/undo_window.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';

void main() {
  late BuildContext ctx;

  Future<void> pumpApp(
    WidgetTester tester, {
    ThemeData? theme,
    Locale locale = const Locale('sv'),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: theme ?? AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  SnackBar shownSnackBar(WidgetTester tester) =>
      tester.widget<SnackBar>(find.byType(SnackBar));

  test('the undo window is seven seconds', () {
    expect(kUndoWindow, const Duration(seconds: 7));
  });

  testWidgets('shows the message with Ångra for exactly the undo window', (
    tester,
  ) async {
    await pumpApp(tester);
    SnackBarUtils.showUndo(ctx, 'Mjölk togs bort', onUndo: () {});
    await tester.pump();

    final bar = shownSnackBar(tester);
    expect(bar.duration, kUndoWindow);
    expect(
      bar.persist,
      isFalse,
      reason:
          'A SnackBar with an action persists by default; the window must '
          'end at 7 s so a deferred commit never lands under a live Ångra.',
    );
    expect(bar.action?.label, 'Ångra');
    expect(find.text('Mjölk togs bort'), findsOneWidget);
    expect(find.text('OK'), findsNothing);
  });

  testWidgets('the label follows the locale, never a passed-in string', (
    tester,
  ) async {
    await pumpApp(tester, locale: const Locale('en'));
    SnackBarUtils.showUndo(ctx, 'Milk removed', onUndo: () {});
    await tester.pump();

    expect(shownSnackBar(tester).action?.label, 'Undo');
  });

  testWidgets('tapping Ångra runs onUndo once', (tester) async {
    await pumpApp(tester);
    var undone = 0;
    SnackBarUtils.showUndo(ctx, 'Recept borttaget', onUndo: () => undone++);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ångra'));
    await tester.pumpAndSettle();

    expect(undone, 1);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('the snackbar times out when the window ends', (tester) async {
    await pumpApp(tester);
    final controller = SnackBarUtils.showUndo(
      ctx,
      'Foto borttaget',
      onUndo: () {},
    );
    SnackBarClosedReason? reason;
    controller!.closed.then((r) => reason = r);
    await tester.pumpAndSettle();

    await tester.pump(kUndoWindow);
    await tester.pumpAndSettle();

    expect(reason, SnackBarClosedReason.timeout);
  });

  group('look is preserved per call site', () {
    testWidgets('plain carries no overrides, like pantry_item_card', (
      tester,
    ) async {
      await pumpApp(tester);
      SnackBarUtils.showUndo(ctx, 'Varan togs bort', onUndo: () {});
      await tester.pump();

      final bar = shownSnackBar(tester);
      expect(bar.backgroundColor, isNull, reason: 'snackBarTheme decides');
      expect(bar.margin, isNull);
      expect(bar.behavior, SnackBarBehavior.floating);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    for (final (mode, theme) in [
      ('light', AppTheme.lightTheme),
      ('dark', AppTheme.darkTheme),
    ]) {
      testWidgets('confirmation keeps the showSuccess look in $mode', (
        tester,
      ) async {
        await pumpApp(tester, theme: theme);
        SnackBarUtils.showUndo(
          ctx,
          'Veckan tömdes',
          look: UndoSnackBarLook.confirmation,
          onUndo: () {},
        );
        await tester.pump();

        final cs = theme.colorScheme;
        final bar = shownSnackBar(tester);
        expect(bar.backgroundColor, cs.primary);
        expect(bar.action?.textColor, cs.surfaceContainerHighest);
        expect(bar.duration, kUndoWindow);
        expect(bar.persist, isFalse);
        expect(find.byIcon(Icons.check), findsOneWidget);
      });
    }
  });

  testWidgets('a captured undo still shows after its context is gone', (
    tester,
  ) async {
    await pumpApp(tester);
    final undo = UndoSnackBar.capture(ctx);

    // Replace the Builder whose context was captured, as a dismissed row is
    // deactivated before Dismissible.onDismissed fires.
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );

    var undone = false;
    undo.show('Varan togs bort', onUndo: () => undone = true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ångra'));

    expect(undone, isTrue);
  });
}
