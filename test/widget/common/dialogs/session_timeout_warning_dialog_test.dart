/// Widget tests for [SessionTimeoutWarningDialog] — the modal shown shortly
/// before a session is auto-logged-out. Covers title/message rendering, the
/// initial M:SS countdown formatting, that the countdown ticks down once per
/// second, that the timer auto-pops with `false` when it reaches zero, and
/// that both action buttons (Logga ut nu / Fortsätt session) resolve the
/// future to the correct sentinel AND fire their callback.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/auth/sign_out_guard.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/dialogs/session_timeout_warning_dialog.dart';

/// Wraps a child in MaterialApp with the project's l10n delegates so the
/// dialog can resolve `context.l10n.*` keys.
Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: child),
);

/// Builds a trigger button whose tap opens the dialog. The result is reported
/// back through [onResult] for assertion. The dialog runs an active periodic
/// Timer, so callers must avoid `pumpAndSettle` after it's open.
Widget _triggerButton({
  required int remainingSeconds,
  VoidCallback? onExtendSession,
  VoidCallback? onLogoutNow,
  void Function(bool?)? onResult,
}) {
  return Builder(
    builder: (ctx) => ElevatedButton(
      onPressed: () async {
        final result = await SessionTimeoutWarningDialog.show(
          context: ctx,
          remainingSeconds: remainingSeconds,
          onExtendSession: onExtendSession ?? () {},
          onLogoutNow: onLogoutNow ?? () {},
        );
        onResult?.call(result);
      },
      child: const Text('Show'),
    ),
  );
}

/// Drives the showDialog scale animation past its ~150ms barrier without
/// triggering pumpAndSettle (which would never settle on the active timer).
Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.text('Show'));
  await tester.pump(); // start dialog route
  await tester.pump(const Duration(milliseconds: 300)); // past entry animation
}

/// Drains the periodic countdown timer so the test ends with no pending
/// timers. Pumps enough seconds for the countdown to expire AND the dialog
/// close animation to finish.
Future<void> _drainTimers(WidgetTester tester, int seconds) async {
  for (var i = 0; i < seconds; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  // Let the auto-pop's close animation flush.
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('SessionTimeoutWarningDialog rendering', () {
    testWidgets('renders title, message, and the M:SS countdown initially', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_triggerButton(remainingSeconds: 65)));
      await _openDialog(tester);

      // sv: sessionExpiringTitle = "Session utgår snart"
      expect(find.text('Session utgår snart'), findsOneWidget);
      // sv: sessionExpiringMessage = "Din session kommer att avslutas om:"
      expect(find.text('Din session kommer att avslutas om:'), findsOneWidget);
      // sv: sessionContinueOrLogout
      expect(
        find.text('Vill du fortsätta din session eller logga ut nu?'),
        findsOneWidget,
      );
      // 65s formatted as "1:05" with zero-padded seconds
      expect(find.text('1:05'), findsOneWidget);

      // Drain so the test ends without pending timers.
      await tester.tap(find.text('Logga ut nu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets(
      'zero-pads seconds below 10 (e.g. 90s -> "1:30", 9s -> "0:09")',
      (tester) async {
        await tester.pumpWidget(_wrap(_triggerButton(remainingSeconds: 9)));
        await _openDialog(tester);

        expect(find.text('0:09'), findsOneWidget);

        await tester.tap(find.text('Logga ut nu'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      },
    );

    testWidgets('renders both action buttons with localized labels', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_triggerButton(remainingSeconds: 60)));
      await _openDialog(tester);

      // sv: commonLogoutNow = "Logga ut nu"
      expect(find.text('Logga ut nu'), findsOneWidget);
      // sv: sessionContinue = "Fortsätt session"
      expect(find.text('Fortsätt session'), findsOneWidget);

      await tester.tap(find.text('Logga ut nu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });
  });

  group('countdown behavior', () {
    testWidgets('ticks down once per real second', (tester) async {
      await tester.pumpWidget(_wrap(_triggerButton(remainingSeconds: 10)));
      await _openDialog(tester);

      expect(find.text('0:10'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('0:09'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('0:07'), findsOneWidget);

      // Close out cleanly.
      await tester.tap(find.text('Logga ut nu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('auto-pops with false when the countdown reaches zero', (
      tester,
    ) async {
      bool? result;
      var resolved = false;
      await tester.pumpWidget(
        _wrap(
          _triggerButton(
            remainingSeconds: 2,
            onResult: (v) {
              result = v;
              resolved = true;
            },
          ),
        ),
      );
      await _openDialog(tester);

      // 2 ticks bring _remainingSeconds from 2 -> 1 -> 0 (auto-pop on the 2nd tick).
      await _drainTimers(tester, 3);

      expect(resolved, isTrue);
      expect(result, isFalse);
      // Dialog must be gone.
      expect(find.text('Session utgår snart'), findsNothing);
    });
  });

  group('action button callbacks', () {
    testWidgets(
      'tapping "Logga ut nu" fires onLogoutNow and resolves the future with false',
      (tester) async {
        var logoutCalled = false;
        var extendCalled = false;
        bool? result;
        await tester.pumpWidget(
          _wrap(
            _triggerButton(
              remainingSeconds: 120,
              onLogoutNow: () => logoutCalled = true,
              onExtendSession: () => extendCalled = true,
              onResult: (v) => result = v,
            ),
          ),
        );
        await _openDialog(tester);

        await tester.tap(find.text('Logga ut nu'));
        // Close animation; no settle (no other timers exist after _handleLogoutNow
        // cancels the periodic one).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(logoutCalled, isTrue);
        expect(extendCalled, isFalse);
        expect(result, isFalse);
      },
    );

    testWidgets(
      'tapping "Fortsätt session" fires onExtendSession and resolves with true',
      (tester) async {
        var logoutCalled = false;
        var extendCalled = false;
        bool? result;
        await tester.pumpWidget(
          _wrap(
            _triggerButton(
              remainingSeconds: 120,
              onLogoutNow: () => logoutCalled = true,
              onExtendSession: () => extendCalled = true,
              onResult: (v) => result = v,
            ),
          ),
        );
        await _openDialog(tester);

        await tester.tap(find.text('Fortsätt session'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(extendCalled, isTrue);
        expect(logoutCalled, isFalse);
        expect(result, isTrue);
      },
    );

    testWidgets(
      'tapping an action cancels the timer (no further ticks after pop)',
      (tester) async {
        bool? result;
        await tester.pumpWidget(
          _wrap(
            _triggerButton(
              remainingSeconds: 60,
              onResult: (v) => result = v,
            ),
          ),
        );
        await _openDialog(tester);

        await tester.tap(find.text('Fortsätt session'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Pumping more seconds must not throw "pending timers" — the periodic
        // timer was cancelled by _handleExtendSession.
        await tester.pump(const Duration(seconds: 5));

        expect(result, isTrue);
      },
    );
  });

  // P6-U08a (produktregler.md:832, § 16.2): two modes. With changes waiting,
  // the changes are named and "Logga ut nu" leads to the manual sign-out's
  // confirmation (#utloggningko); only its destructive choice signs out.
  group('queue mode', () {
    const pending = PendingChanges(recipeChanges: 2, imageUploads: 1);

    Widget queueTrigger({
      VoidCallback? onExtendSession,
      VoidCallback? onLogoutNow,
      Future<void> Function()? onDiscardAndLogout,
      void Function(bool?)? onResult,
    }) {
      return Builder(
        builder: (ctx) => ElevatedButton(
          onPressed: () async {
            final result = await SessionTimeoutWarningDialog.show(
              context: ctx,
              remainingSeconds: 30,
              pendingChanges: pending,
              onExtendSession: onExtendSession ?? () {},
              onLogoutNow: onLogoutNow ?? () {},
              onDiscardAndLogout: onDiscardAndLogout,
            );
            onResult?.call(result);
          },
          child: const Text('Show'),
        ),
      );
    }

    testWidgets('names the waiting changes', (tester) async {
      await tester.pumpWidget(_wrap(queueTrigger()));
      await _openDialog(tester);

      expect(find.text('3 ändringar har inte sparats än:'), findsOneWidget);
      expect(find.text('Recept · 2 ändringar'), findsOneWidget);
      expect(find.text('Bilder · 1 väntar på uppladdning'), findsOneWidget);

      await _drainTimers(tester, 31);
    });

    testWidgets('empty queue: Logga ut nu signs out at once', (tester) async {
      var loggedOut = 0;
      await tester.pumpWidget(
        _wrap(
          _triggerButton(remainingSeconds: 30, onLogoutNow: () => loggedOut++),
        ),
      );
      await _openDialog(tester);
      await tester.tap(find.byKey(const ValueKey('sessionTimeout.logoutNow')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(loggedOut, 1);
      expect(
        find.byKey(const ValueKey('signOut.pendingChanges')),
        findsNothing,
      );
    });

    testWidgets(
      'Logga ut nu asks first; Vänta på synk keeps the session',
      (tester) async {
        var loggedOut = 0;
        var discarded = 0;
        var extended = 0;
        bool? result;
        await tester.pumpWidget(
          _wrap(
            queueTrigger(
              onLogoutNow: () => loggedOut++,
              onExtendSession: () => extended++,
              onDiscardAndLogout: () async => discarded++,
              onResult: (r) => result = r,
            ),
          ),
        );
        await _openDialog(tester);

        await tester.tap(
          find.byKey(const ValueKey('sessionTimeout.logoutNow')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.byKey(const ValueKey('signOut.pendingChanges')),
          findsOneWidget,
        );
        expect(find.text('3 ändringar har inte sparats'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('signOut.pendingChanges.wait')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(loggedOut, 0, reason: 'never the direct sign-out in queue mode');
        expect(discarded, 0, reason: 'waiting throws nothing away');
        expect(extended, 1);
        expect(result, isTrue);
      },
    );

    testWidgets(
      'the countdown running out under the confirmation closes both and '
      'never extends the session',
      (tester) async {
        var loggedOut = 0;
        var discarded = 0;
        var extended = 0;
        bool? result;
        var resolved = false;
        await tester.pumpWidget(
          _wrap(
            queueTrigger(
              onLogoutNow: () => loggedOut++,
              onExtendSession: () => extended++,
              onDiscardAndLogout: () async => discarded++,
              onResult: (r) {
                result = r;
                resolved = true;
              },
            ),
          ),
        );
        await _openDialog(tester);

        await tester.tap(
          find.byKey(const ValueKey('sessionTimeout.logoutNow')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.byKey(const ValueKey('signOut.pendingChanges')),
          findsOneWidget,
        );

        // Nobody answers; the 30 s run out with the confirmation on top.
        await _drainTimers(tester, 31);

        expect(extended, 0, reason: 'only a person may extend the session');
        expect(discarded, 0, reason: 'the timeout never clears the queue');
        expect(loggedOut, 0);
        expect(resolved, isTrue);
        expect(result, isFalse);
        expect(
          find.byKey(const ValueKey('signOut.pendingChanges')),
          findsNothing,
        );
        expect(find.text('Session utgår snart'), findsNothing);
      },
    );

    testWidgets(
      'Logga ut och släng ändringarna discards and signs out',
      (tester) async {
        var loggedOut = 0;
        var discarded = 0;
        bool? result;
        await tester.pumpWidget(
          _wrap(
            queueTrigger(
              onLogoutNow: () => loggedOut++,
              onDiscardAndLogout: () async => discarded++,
              onResult: (r) => result = r,
            ),
          ),
        );
        await _openDialog(tester);

        await tester.tap(
          find.byKey(const ValueKey('sessionTimeout.logoutNow')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(
          find.byKey(const ValueKey('signOut.pendingChanges.discard')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(discarded, 1);
        expect(loggedOut, 0);
        expect(result, isFalse);
      },
    );
  });
}
