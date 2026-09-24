// P5-U00: the error contract (content-style-guide.md:87-97).
//
// A failure says what happened, what was kept when something was at stake,
// and what you can do, as a button that is never "OK"
// (content-style-guide.md:96; Komponentark v1:750). Screen readers hear it
// without a focus move: the snackbar and the inline error both have the
// alert role (Butlery tillganglighetshandoff.dc.html:172).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/feedback/inline_error.dart';

void main() {
  late BuildContext ctx;

  Future<void> pumpApp(
    WidgetTester tester, {
    ThemeData? theme,
    Widget? body,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sv'),
        theme: theme ?? AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (c) {
              ctx = c;
              return body ?? const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  Finder alertRole() => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.role == SemanticsRole.alert,
  );

  group('SnackBarUtils.showFailure', () {
    testWidgets('shows what happened and what was kept, in that order', (
      tester,
    ) async {
      await pumpApp(tester);
      SnackBarUtils.showFailure(
        ctx,
        what: 'Meddelandet kunde inte skickas.',
        preserved: 'Texten ligger kvar i fältet.',
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Meddelandet kunde inte skickas. Texten ligger kvar i fältet.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('without an action, the action is Stäng and closes it', (
      tester,
    ) async {
      await pumpApp(tester);
      SnackBarUtils.showFailure(ctx, what: 'Listan kunde inte hämtas.');
      await tester.pumpAndSettle();

      expect(find.text('Stäng'), findsOneWidget);
      expect(find.text('OK'), findsNothing);
      expect(tester.widget<SnackBar>(find.byType(SnackBar)).persist, isTrue);

      await tester.tap(find.text('Stäng'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('retry is Försök igen and runs once', (tester) async {
      var retried = 0;
      await pumpApp(tester);
      SnackBarUtils.showFailure(
        ctx,
        what: 'Omröstningen kunde inte skapas.',
        action: FailureAction.retry(() => retried++),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Försök igen'));
      await tester.pumpAndSettle();
      expect(retried, 1);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('an action named OK is shown as Stäng', (tester) async {
      var pressed = 0;
      await pumpApp(tester);
      SnackBarUtils.showFailure(
        ctx,
        what: 'Bilden kunde inte laddas upp.',
        action: FailureAction.named('ok', () => pressed++),
      );
      await tester.pumpAndSettle();

      expect(find.text('ok'), findsNothing);
      await tester.tap(find.text('Stäng'));
      await tester.pumpAndSettle();
      expect(pressed, 1);
    });

    testWidgets('a named action keeps its name', (tester) async {
      await pumpApp(tester);
      SnackBarUtils.showFailure(
        ctx,
        what: 'Kameran är avstängd.',
        action: FailureAction.named('Öppna inställningar', () {}),
      );
      await tester.pumpAndSettle();

      expect(find.text('Öppna inställningar'), findsOneWidget);
    });

    testWidgets('has the alert role, and the semantics tree accepts it', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester);
      SnackBarUtils.showFailure(ctx, what: 'Receptet kunde inte sparas.');
      await tester.pumpAndSettle();

      expect(alertRole(), findsOneWidget);
      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets('a confirmation is not an alert', (tester) async {
      await pumpApp(tester);
      SnackBarUtils.showSuccess(ctx, 'Receptet är sparat.');
      await tester.pumpAndSettle();

      expect(alertRole(), findsNothing);
      expect(find.text('Stäng'), findsNothing, reason: 'unchanged behaviour');
    });

    testWidgets('showErrorWithRetry and showNetworkError route through it', (
      tester,
    ) async {
      await pumpApp(tester);
      SnackBarUtils.showNetworkError(ctx);
      await tester.pumpAndSettle();
      expect(find.text('Stäng'), findsOneWidget);
      expect(alertRole(), findsOneWidget);
      await tester.tap(find.text('Stäng'));
      await tester.pumpAndSettle();

      SnackBarUtils.showErrorWithRetry(
        ctx,
        'Kunde inte hämta.',
        onRetry: () {},
      );
      await tester.pumpAndSettle();
      expect(find.text('Försök igen'), findsOneWidget);
      expect(alertRole(), findsOneWidget);
    });
  });

  // content-style-guide.md:87-97: the parts are separate sentences, even
  // when an older cause string has no full stop of its own.
  group('SnackBarUtils.failureMessage', () {
    test('adds a full stop between a bare cause and what was kept', () {
      expect(
        SnackBarUtils.failureMessage(
          'Kunde inte lämna listan',
          'Du är fortfarande med i listan.',
        ),
        'Kunde inte lämna listan. Du är fortfarande med i listan.',
      );
    });

    test('keeps punctuation that is already there', () {
      expect(
        SnackBarUtils.failureMessage(
          'Receptet kunde inte sparas.',
          'Dina ändringar ligger kvar i formuläret.',
        ),
        'Receptet kunde inte sparas. Dina ändringar ligger kvar i formuläret.',
      );
    });

    test('leaves a lone what untouched', () {
      expect(
        SnackBarUtils.failureMessage('Kunde inte hämta', null),
        'Kunde inte hämta',
      );
    });
  });

  group('InlineError', () {
    Future<void> pumpInline(
      WidgetTester tester, {
      ThemeData? theme,
      VoidCallback? onAction,
    }) {
      return pumpApp(
        tester,
        theme: theme,
        body: InlineError(
          what: 'Verifieringsmailet kunde inte skickas.',
          preserved: 'Din e-postadress är oförändrad.',
          actionLabel: onAction == null ? null : 'Försök igen',
          onAction: onAction,
        ),
      );
    }

    testWidgets('renders the three parts', (tester) async {
      var retried = 0;
      await pumpInline(tester, onAction: () => retried++);

      expect(
        find.text('Verifieringsmailet kunde inte skickas.'),
        findsOneWidget,
      );
      expect(find.text('Din e-postadress är oförändrad.'), findsOneWidget);
      await tester.tap(find.byKey(InlineError.actionKey));
      expect(retried, 1);
    });

    testWidgets('is an alert whose text is a live region', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpInline(tester);

      expect(alertRole(), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.liveRegion == true,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    // Komponentark v1:755: the outline is text.danger in both modes
    // (tokens.json:96-98), the title text.primary (tokens.json:54-56).
    for (final (name, theme, danger, title) in [
      (
        'light',
        AppTheme.lightTheme,
        const Color(0xFF9C3B23),
        const Color(0xFF24382C),
      ),
      (
        'dark',
        AppTheme.darkTheme,
        const Color(0xFFDE9078),
        const Color(0xFFF5F4ED),
      ),
    ]) {
      testWidgets('$name mode: danger outline, primary title', (tester) async {
        await pumpInline(tester, theme: theme);

        final box = tester.widget<Material>(find.byKey(InlineError.boxKey));
        final shape = box.shape! as RoundedRectangleBorder;
        expect(shape.side.color, danger);
        final text = tester.widget<Text>(
          find.text('Verifieringsmailet kunde inte skickas.'),
        );
        expect(text.style?.color, title);
      });
    }

    // The action is text.link in both modes (tokens.json:228-231), on the
    // surface.base box (tokens.json:104-106), never colorScheme.primary,
    // which is #24382C on #17251D in dark mode.
    for (final (name, theme, link, surface) in [
      (
        'light',
        AppTheme.lightTheme,
        const Color(0xFF8A5212),
        const Color(0xFFF5F4ED),
      ),
      (
        'dark',
        AppTheme.darkTheme,
        const Color(0xFFDCA968),
        const Color(0xFF17251D),
      ),
    ]) {
      testWidgets('$name mode: the action reads on the box', (tester) async {
        await pumpInline(tester, theme: theme, onAction: () {});

        final box = tester.widget<Material>(find.byKey(InlineError.boxKey));
        expect(box.color, surface);
        final label = tester.widget<RichText>(
          find.descendant(
            of: find.byKey(InlineError.actionKey),
            matching: find.byType(RichText),
          ),
        );
        final fg = label.text.style!.color!;
        expect(fg, link);
        final l1 = fg.computeLuminance();
        final l2 = surface.computeLuminance();
        final ratio = (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
        expect(ratio, greaterThanOrEqualTo(4.5));
      });
    }
  });
}
