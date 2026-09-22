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
    bool accessibleNavigation = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(accessibleNavigation: accessibleNavigation),
          child: child!,
        ),
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
          'A SnackBar with an action persists by default; without assistive '
          'navigation the window must end at 7 s (produktregler.md:131-132).',
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

  testWidgets('assistive navigation keeps the snackbar until dismissed', (
    tester,
  ) async {
    // Open question, not decided here: no source says whether a
    // screen-reader user gets exactly 7 s (tillganglighetshandoff:172 is
    // silent on timing). Until then they keep the pre-P3-U1 behaviour.
    await pumpApp(tester, accessibleNavigation: true);
    SnackBarUtils.showUndo(ctx, 'Recept borttaget', onUndo: () {});
    await tester.pump();

    final bar = shownSnackBar(tester);
    expect(bar.persist, isTrue);
    expect(bar.duration, kUndoWindow);
  });

  group('deferred commit follows the snackbar, not a timer', () {
    testWidgets('commits only after the snackbar has left the screen', (
      tester,
    ) async {
      await pumpApp(tester);
      var commits = 0;
      SnackBarUtils.showUndoDeferred(
        ctx,
        'Recept borttaget',
        onUndo: () {},
        onCommit: () => commits++,
      );
      await tester.pump();

      // Exactly kUndoWindow after the delete, Ångra is still on screen
      // (its timer started after the entrance animation), so nothing may
      // have been committed yet.
      await tester.pump(kUndoWindow);
      expect(find.text('Ångra'), findsOneWidget);
      expect(commits, 0);

      // The snackbar's own window runs out, it animates away, and only then
      // does the delete commit.
      await tester.pump(kUndoWindow);
      expect(commits, 0);
      await tester.pumpAndSettle();
      expect(find.text('Ångra'), findsNothing);
      expect(commits, 1);
    });

    testWidgets('Ångra means no commit', (tester) async {
      await pumpApp(tester);
      var commits = 0;
      var undone = 0;
      SnackBarUtils.showUndoDeferred(
        ctx,
        'Recept borttaget',
        onUndo: () => undone++,
        onCommit: () => commits++,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ångra'));
      await tester.pumpAndSettle();
      await tester.pump(kUndoWindow * 2);
      await tester.pumpAndSettle();

      expect(undone, 1);
      expect(commits, 0);
    });

    testWidgets('a second delete never queues behind the first', (
      tester,
    ) async {
      // Two deletes in a row: the second snackbar must not wait in the queue
      // with a live Ångra while its window runs out. The first one is closed
      // (and so committed) when the second is shown.
      await pumpApp(tester);
      final commits = <String>[];
      final undos = <String>[];
      SnackBarUtils.showUndoDeferred(
        ctx,
        'Första borttaget',
        onUndo: () => undos.add('a'),
        onCommit: () => commits.add('a'),
      );
      await tester.pumpAndSettle();
      SnackBarUtils.showUndoDeferred(
        ctx,
        'Andra borttaget',
        onUndo: () => undos.add('b'),
        onCommit: () => commits.add('b'),
      );
      await tester.pump();
      expect(commits, ['a']);

      await tester.pumpAndSettle();
      expect(find.text('Andra borttaget'), findsOneWidget);
      expect(find.text('Första borttaget'), findsNothing);

      await tester.tap(find.text('Ångra'));
      await tester.pumpAndSettle();
      expect(undos, ['b']);
      expect(commits, ['a']);
    });

    testWidgets('a route change closes the snackbar and commits', (
      tester,
    ) async {
      // SnackbarRouteObserver calls clearSnackBars on every push and pop. The
      // undo snackbar is always the head, so it is closed, not dropped from
      // the queue with its commit stranded.
      await pumpApp(tester);
      SnackBarUtils.showSuccess(ctx, 'Sparat');
      var commits = 0;
      SnackBarUtils.showUndoDeferred(
        ctx,
        'Recept borttaget',
        onUndo: () {},
        onCommit: () => commits++,
      );
      await tester.pump();
      ScaffoldMessenger.of(ctx).clearSnackBars();
      await tester.pumpAndSettle();

      expect(commits, 1);
    });

    testWidgets('no messenger rolls back instead of deleting', (tester) async {
      // No MaterialApp, so there is no ScaffoldMessenger at all.
      await tester.pumpWidget(
        Localizations(
          locale: const Locale('sv'),
          delegates: AppLocalizations.localizationsDelegates,
          child: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();
      final outside = ctx;
      var commits = 0;
      var undone = 0;
      UndoSnackBar.capture(outside).showDeferred(
        'Recept borttaget',
        onUndo: () => undone++,
        onCommit: () => commits++,
      );
      await tester.pumpAndSettle();

      expect(undone, 1);
      expect(commits, 0);
    });
  });
}
