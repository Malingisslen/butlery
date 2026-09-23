// P3-U1: the one undo primitive (produktregler.md:125-140, § 2.4).
//
// Class 1 (`add`, `delete`) carries a 7 s snackbar whose action is "Ångra"
// (produktregler.md:131-132, content-style-guide.md:77). The primitive owns
// both numbers so no call site can drift to 4 or 5 seconds again.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/utils/undo_window.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/butlery_focus_ring.dart';

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
    // The window is UndoWindowTimer's, not Flutter's, so it can pause and
    // extend (Grafisk manual v6:647). The timeout itself is proven below.
    expect(bar.persist, isTrue);
    // The action lives in the content, where it can carry its paper ring.
    expect(
      find.descendant(
        of: find.byType(InkSnackBarAction),
        matching: find.text('Ångra'),
      ),
      findsOneWidget,
    );
    expect(find.text('Mjölk togs bort'), findsOneWidget);
    expect(find.text('OK'), findsNothing);
  });

  testWidgets('the label follows the locale, never a passed-in string', (
    tester,
  ) async {
    await pumpApp(tester, locale: const Locale('en'));
    SnackBarUtils.showUndo(ctx, 'Milk removed', onUndo: () {});
    await tester.pump();

    expect(find.text('Undo'), findsOneWidget);
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

  group('the ink snackbar (Komponentark v1:745-750, PQ-09 = A)', () {
    for (final (mode, theme) in [
      ('light', AppTheme.lightTheme),
      ('dark', AppTheme.darkTheme),
    ]) {
      for (final look in UndoSnackBarLook.values) {
        testWidgets('${look.name} is the ink snackbar in $mode', (
          tester,
        ) async {
          await pumpApp(tester, theme: theme);
          SnackBarUtils.showUndo(
            ctx,
            'Varan togs bort.',
            look: look,
            onUndo: () {},
          );
          await tester.pumpAndSettle();

          final bar = shownSnackBar(tester);
          expect(bar.backgroundColor, isNull, reason: 'snackBarTheme decides');
          expect(find.byIcon(Icons.check), findsNothing);
          // The painted surface: surface.ink in both modes.
          final material = tester.widget<Material>(
            find
                .descendant(
                  of: find.byType(SnackBar),
                  matching: find.byType(Material),
                )
                .first,
          );
          expect(material.color, const Color(0xFF24382C));
          final shape = material.shape! as RoundedRectangleBorder;
          expect(shape.borderRadius, BorderRadius.circular(8));
          expect(
            shape.side,
            mode == 'dark'
                ? const BorderSide(color: Color(0x2EF5F4ED))
                : BorderSide.none,
          );
          // Message paper, action light saffron.
          final message = tester.widget<Text>(
            find.byKey(InkSnackBar.messageKey),
          );
          expect(message.style?.color, const Color(0xFFF5F4ED));
          final action = tester.widget<TextButton>(
            find.byKey(InkSnackBarAction.actionKey),
          );
          expect(
            action.style?.foregroundColor?.resolve(<WidgetState>{}),
            const Color(0xFFE09D50),
          );
          // At least a 48 dp target.
          expect(
            tester.getSize(find.byKey(InkSnackBarAction.actionKey)).height,
            greaterThanOrEqualTo(48),
          );
        });
      }
    }

    testWidgets('the action has its own paper focus ring, also in light mode', (
      tester,
    ) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      await pumpApp(tester);
      SnackBarUtils.showUndo(ctx, 'Varan togs bort.', onUndo: () {});
      await tester.pumpAndSettle();

      final actionContext = tester.element(find.text('Ångra'));
      // The ring reads the surface it stands on: ink, so paper
      // (tokens.json focusRing dark #F5F4ED), never the light theme's ink.
      expect(FocusRingSurface.of(actionContext), Brightness.dark);
      expect(find.byType(ButleryFocusRing), findsWidgets);
    });
  });

  group('the window pauses and extends (Grafisk manual v6:647)', () {
    Future<SnackBarClosedReason? Function()> showAndSettle(
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      final controller = SnackBarUtils.showUndo(
        ctx,
        'Varan togs bort.',
        onUndo: () {},
      );
      SnackBarClosedReason? reason;
      controller!.closed.then((r) => reason = r);
      await tester.pumpAndSettle();
      return () => reason;
    }

    testWidgets('focus holds it; leaving focus starts the full window', (
      tester,
    ) async {
      final reason = await showAndSettle(tester);
      await tester.pump(const Duration(seconds: 5));

      Focus.of(tester.element(find.text('Ångra'))).requestFocus();
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Varan togs bort.'), findsOneWidget);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Varan togs bort.'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(reason(), SnackBarClosedReason.timeout);
    });

    testWidgets('each interaction starts the full window again', (
      tester,
    ) async {
      final reason = await showAndSettle(tester);
      await tester.pump(const Duration(seconds: 5));

      // A touch on the message: an interaction, not the action.
      await tester.tap(find.text('Varan togs bort.'));
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Varan togs bort.'), findsOneWidget);
      expect(reason(), isNull);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(reason(), SnackBarClosedReason.timeout);
    });

    testWidgets('a hovering pointer holds it', (tester) async {
      final reason = await showAndSettle(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Varan togs bort.')));
      await tester.pump(const Duration(seconds: 30));
      expect(reason(), isNull);

      await mouse.moveTo(Offset.zero);
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      expect(reason(), SnackBarClosedReason.timeout);
    });

    test('the timer: pauses nest, resume and extend restart the window', () {
      fakeAsync((async) {
        var timedOut = 0;
        final t = UndoWindowTimer(
          window: kUndoWindow,
          onTimeout: () => timedOut++,
        )..start();
        // Held until its content is on screen.
        async.elapse(const Duration(seconds: 60));
        expect(timedOut, 0);
        t.attach();
        async.elapse(const Duration(seconds: 6));
        t
          ..pause()
          ..pause();
        async.elapse(const Duration(seconds: 60));
        t.resume();
        async.elapse(const Duration(seconds: 60));
        expect(timedOut, 0, reason: 'one pause is still held');
        t.resume();
        async.elapse(const Duration(seconds: 6));
        t.extend();
        async.elapse(const Duration(seconds: 6));
        expect(timedOut, 0);
        async.elapse(const Duration(seconds: 1));
        expect(timedOut, 1);
        expect(t.isClosed, isTrue);
      });
    });
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

  testWidgets('assistive navigation keeps the snackbar until the user acts', (
    tester,
  ) async {
    // Produktbeslut PQ-21 = A (2026-09-23): with accessibleNavigation on,
    // the undo snackbar stays until the user acts.
    await pumpApp(tester, accessibleNavigation: true);
    var undone = 0;
    SnackBarUtils.showUndo(ctx, 'Recept borttaget', onUndo: () => undone++);
    await tester.pump();

    final bar = shownSnackBar(tester);
    expect(bar.persist, isTrue);
    await tester.pump(const Duration(minutes: 5));
    expect(find.text('Recept borttaget'), findsOneWidget);

    await tester.tap(find.text('Ångra'));
    await tester.pump();
    expect(undone, 1);
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

  group('one snackbar on two Scaffolds', () {
    test('the window runs while any copy is on screen', () {
      fakeAsync((async) {
        var timedOut = 0;
        final t = UndoWindowTimer(
          window: kUndoWindow,
          onTimeout: () => timedOut++,
        )..start();
        // Flutter builds the snackbar on every root Scaffold: two copies.
        t
          ..attach()
          ..attach();
        async.elapse(const Duration(seconds: 3));
        // One copy leaves (the popped route); the other stays on screen.
        t.detach();
        async.elapse(const Duration(seconds: 4));
        expect(timedOut, 1);
      });
    });

    test('it stops when the last copy leaves', () {
      fakeAsync((async) {
        var timedOut = 0;
        final t = UndoWindowTimer(
          window: kUndoWindow,
          onTimeout: () => timedOut++,
        )..start();
        t
          ..attach()
          ..attach()
          ..detach()
          ..detach();
        async.elapse(const Duration(seconds: 60));
        expect(timedOut, 0);
      });
    });

    testWidgets('an undo shown after a pop still times out', (tester) async {
      // recipe_management_handler pops the detail route and then shows the
      // undo: for a moment the snackbar is built on both Scaffolds.
      final nav = GlobalKey<NavigatorState>();
      late BuildContext detail;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          locale: const Locale('sv'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: Text('Lista')),
        ),
      );
      unawaited(
        nav.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              body: Builder(
                builder: (c) {
                  detail = c;
                  return const Text('Detalj');
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final undo = UndoSnackBar.capture(detail);
      nav.currentState!.pop();
      SnackBarClosedReason? reason;
      undo
          .show('Receptet togs bort', onUndo: () {})!
          .closed
          .then((r) => reason = r);
      await tester.pumpAndSettle();
      expect(find.text('Detalj'), findsNothing);
      expect(find.text('Receptet togs bort'), findsOneWidget);

      await tester.pump(kUndoWindow + const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Receptet togs bort'), findsNothing);
      expect(reason, SnackBarClosedReason.timeout);
    });
  });

  group('a snackbar with an action stays until the user acts', () {
    // The action sits in InkSnackBar's content, so SnackBar.action is null
    // and Flutter's default `persist ?? action != null` no longer applies.
    // _showSnackBar keeps the behaviour the SnackBarAction had.
    for (final assistive in [false, true]) {
      testWidgets('Försök igen persists (accessibleNavigation: $assistive)', (
        tester,
      ) async {
        await pumpApp(tester, accessibleNavigation: assistive);
        SnackBarUtils.showNetworkError(ctx, onRetry: () {});
        await tester.pump();
        expect(find.text('Försök igen'), findsOneWidget);
        expect(shownSnackBar(tester).persist, isTrue);
        await tester.pump(const Duration(minutes: 1));
        expect(find.text('Försök igen'), findsOneWidget);
      });
    }

    testWidgets('a snackbar without an action times out', (tester) async {
      await pumpApp(tester);
      SnackBarUtils.showInfo(ctx, 'Sparat');
      await tester.pumpAndSettle();
      expect(shownSnackBar(tester).persist, isFalse);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Sparat'), findsNothing);
    });
  });
}
