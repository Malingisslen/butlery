// BUT-920: "Skapa konto" from guest, its e-mail-in-use way out, and signing
// out as a guest. Both ways out of a guest account erase it.

import 'dart:async';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/account/age_verification_service.dart';
import 'package:butlery/services/auth/guest_auth_service.dart';
import 'package:butlery/services/auth/sign_out_guard.dart';
import 'package:butlery/views/auth/guest_upgrade_view.dart';
import 'package:butlery/widgets/common/profile/handlers/auth_action_handler.dart';
import 'package:butlery/widgets/guest/guest_erasure.dart';
import 'package:butlery/widgets/guest/guest_upgrade_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'guest_test_support.dart';

final _sv = AppLocalizationsSv();

class _MockGuestAuth extends Mock implements GuestAuthService {}

class _MockAge extends Mock implements AgeVerificationService {}

/// Stands in for the queue guard of an ordinary sign-out; the test only needs
/// to see that path taken, so the question never comes back.
class _IdleGuard extends Fake implements SignOutGuard {
  @override
  Future<PendingChanges> pendingForCurrentUser() =>
      Completer<PendingChanges>().future;
}

class _RouteLog extends NavigatorObserver {
  final pushed = <String?>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed.add(route.settings.name);
}

void main() {
  final defaultErase = GuestErasure.erase;
  late List<String> erasures;
  late bool serverAnswers;

  setUp(() {
    erasures = [];
    serverAnswers = true;
    GuestErasure.erase = (reason) async {
      erasures.add(reason);
      return {'cfCompleted': serverAnswers};
    };
  });

  tearDown(() async {
    GuestErasure.erase = defaultErase;
    await resetLocator();
  });

  /// A host whose button runs [action] with a context under the navigator.
  Widget host(void Function(BuildContext) action, {_RouteLog? log}) => guestApp(
    Builder(
      builder: (context) =>
          TextButton(onPressed: () => action(context), child: const Text('go')),
    ),
    observer: log,
  );

  group('guest sign-out', () {
    testWidgets('warns that everything is erased, then erases and goes to '
        'sign-in', (tester) async {
      registerAuth(FakeAuthService(FakeUser(isAnonymous: true)));
      final log = _RouteLog();
      await tester.pumpWidget(host(AuthActionHandler.handleLogout, log: log));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text(_sv.guestLogoutTitle), findsOneWidget);
      expect(find.text(_sv.guestLogoutBody), findsOneWidget);
      expect(erasures, isEmpty, reason: 'nothing goes before the answer');

      await tester.tap(find.text(_sv.guestLogoutConfirm));
      await tester.pumpAndSettle();

      expect(erasures, ['guest_sign_out']);
      expect(log.pushed.last, Routes.auth);
    });

    testWidgets('from a page in a nested navigator (the Mer detail pane) a '
        'failed erasure closes the progress dialog and leaves the page', (
      tester,
    ) async {
      serverAnswers = false;
      registerAuth(FakeAuthService(FakeUser(isAnonymous: true)));
      await tester.pumpWidget(
        guestApp(
          Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (pageContext) => TextButton(
                      onPressed: () =>
                          AuthActionHandler.handleLogout(pageContext),
                      child: const Text('logga ut'),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('logga ut'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_sv.guestLogoutConfirm));
      await tester.pumpAndSettle();

      expect(find.byKey(GuestErasure.progressKey), findsNothing);
      expect(find.text('logga ut'), findsOneWidget);
      expect(find.text(_sv.guestEraseFailed), findsOneWidget);
    });

    testWidgets('cancelling erases nothing', (tester) async {
      registerAuth(FakeAuthService(FakeUser(isAnonymous: true)));
      await tester.pumpWidget(host(AuthActionHandler.handleLogout));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_sv.commonCancel));
      await tester.pumpAndSettle();

      expect(erasures, isEmpty);
    });

    testWidgets('an erasure the server did not answer keeps the guest signed '
        'in and says so', (tester) async {
      serverAnswers = false;
      registerAuth(FakeAuthService(FakeUser(isAnonymous: true)));
      final log = _RouteLog();
      await tester.pumpWidget(host(AuthActionHandler.handleLogout, log: log));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_sv.guestLogoutConfirm));
      await tester.pumpAndSettle();

      expect(find.text(_sv.guestEraseFailed), findsOneWidget);
      expect(log.pushed, isNot(contains(Routes.auth)));
    });

    testWidgets('an account that is not a guest is never erased by '
        'signing out', (tester) async {
      registerAuth(FakeAuthService(FakeUser(isAnonymous: false)));
      var ordinaryPath = false;
      AuthActionHandler.guardFactory = () {
        ordinaryPath = true;
        return _IdleGuard();
      };
      addTearDown(() => AuthActionHandler.guardFactory = defaultGuard);
      await tester.pumpWidget(host(AuthActionHandler.handleLogout));

      await tester.tap(find.text('go'));
      await tester.pump();

      expect(ordinaryPath, isTrue);
      expect(find.text(_sv.guestLogoutTitle), findsNothing);
      expect(erasures, isEmpty);
    });
  });

  group('guest "Radera konto"', () {
    testWidgets('asks no password, warns, erases and goes to sign-in', (
      tester,
    ) async {
      registerAuth(FakeAuthService(FakeUser(isAnonymous: true)));
      final log = _RouteLog();
      await tester.pumpWidget(
        host(AuthActionHandler.handleDeleteAccount, log: log),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text(_sv.guestDeleteTitle), findsOneWidget);
      expect(find.text(_sv.guestLogoutBody), findsOneWidget);
      expect(find.byType(TextField), findsNothing, reason: 'no password');
      expect(erasures, isEmpty);

      await tester.tap(find.text(_sv.guestDeleteConfirm));
      await tester.pumpAndSettle();

      expect(erasures, ['guest_account_delete']);
      expect(log.pushed.last, Routes.auth);
    });

    testWidgets('cancelling erases nothing', (tester) async {
      registerAuth(FakeAuthService(FakeUser(isAnonymous: true)));
      await tester.pumpWidget(host(AuthActionHandler.handleDeleteAccount));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_sv.commonCancel));
      await tester.pumpAndSettle();

      expect(erasures, isEmpty);
    });

    testWidgets('an erasure the server did not answer keeps the guest signed '
        'in and says so', (tester) async {
      serverAnswers = false;
      registerAuth(FakeAuthService(FakeUser(isAnonymous: true)));
      final log = _RouteLog();
      await tester.pumpWidget(
        host(AuthActionHandler.handleDeleteAccount, log: log),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_sv.guestDeleteConfirm));
      await tester.pumpAndSettle();

      expect(find.text(_sv.guestEraseFailed), findsOneWidget);
      expect(log.pushed, isNot(contains(Routes.auth)));
    });
  });

  group('upgrade', () {
    late _MockGuestAuth guestAuth;
    late _MockAge age;

    setUp(() {
      guestAuth = _MockGuestAuth();
      age = _MockAge();
      registerAuth(FakeAuthService(FakeUser(isAnonymous: true)));
      GetIt.instance
        ..registerSingleton<GuestAuthService>(guestAuth)
        ..registerSingleton<AgeVerificationService>(age);
      when(() => age.finishGuestUpgrade()).thenAnswer((_) async {});
    });

    Future<void> fillAndSubmit(
      WidgetTester tester, {
      bool acceptTerms = true,
    }) async {
      await tester.enterText(find.byKey(GuestUpgradeView.nameKey), 'Malin');
      await tester.enterText(
        find.byKey(GuestUpgradeView.emailKey),
        'malin@exempel.se',
      );
      await tester.enterText(
        find.byKey(GuestUpgradeView.passwordKey),
        'Hemligt123!x',
      );
      if (acceptTerms) {
        await tester.ensureVisible(find.byType(Checkbox));
        await tester.tap(find.byType(Checkbox));
      }
      await tester.ensureVisible(find.byKey(GuestUpgradeView.submitKey));
      await tester.tap(find.byKey(GuestUpgradeView.submitKey));
      await tester.pumpAndSettle();
    }

    // The form is a lazy ListView: an error shown above the button can push
    // it out of the built range, so it is scrolled to rather than looked up.
    Future<void> scrollTo(WidgetTester tester, Key key) async {
      await tester.scrollUntilVisible(
        find.byKey(key),
        100,
        scrollable: find
            .descendant(
              of: find.byType(GuestUpgradeView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(find.byKey(key));
      await tester.pumpAndSettle();
    }

    Future<void> openUpgrade(WidgetTester tester, {_RouteLog? log}) async {
      await tester.pumpWidget(
        host((c) => const GuestUpgradeLauncher().launch(c), log: log),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byType(GuestUpgradeView), findsOneWidget);
    }

    testWidgets('a new account is linked, given its age claim and closes', (
      tester,
    ) async {
      when(
        () => guestAuth.upgradeGuest(
          displayName: any(named: 'displayName'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async {});
      await openUpgrade(tester);

      await fillAndSubmit(tester);

      verify(
        () => guestAuth.upgradeGuest(
          displayName: 'Malin',
          email: 'malin@exempel.se',
          password: 'Hemligt123!x',
        ),
      ).called(1);
      verify(() => age.finishGuestUpgrade()).called(1);
      expect(find.byType(GuestUpgradeView), findsNothing);
      expect(find.text(_sv.guestUpgradeDone), findsOneWidget);
    });

    testWidgets('no account is made until the terms are accepted', (
      tester,
    ) async {
      when(
        () => guestAuth.upgradeGuest(
          displayName: any(named: 'displayName'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async {});
      await openUpgrade(tester);
      expect(find.text(_sv.passwordRuleHint), findsOneWidget);

      await fillAndSubmit(tester, acceptTerms: false);

      verifyNever(
        () => guestAuth.upgradeGuest(
          displayName: any(named: 'displayName'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
      expect(find.text(_sv.authTermsAcceptRequired), findsOneWidget);

      // The warning snackbar sits over the submit button.
      ScaffoldMessenger.of(
        tester.element(find.byType(GuestUpgradeView)),
      ).clearSnackBars();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.ensureVisible(find.byKey(GuestUpgradeView.submitKey));
      await tester.tap(find.byKey(GuestUpgradeView.submitKey));
      await tester.pumpAndSettle();

      verify(
        () => guestAuth.upgradeGuest(
          displayName: 'Malin',
          email: 'malin@exempel.se',
          password: 'Hemligt123!x',
        ),
      ).called(1);
    });

    testWidgets('a failed last step stays open and retries only that step', (
      tester,
    ) async {
      when(
        () => guestAuth.upgradeGuest(
          displayName: any(named: 'displayName'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async {});
      when(() => age.finishGuestUpgrade()).thenThrow(Exception('internal'));
      await openUpgrade(tester);

      await fillAndSubmit(tester);
      expect(find.text(_sv.guestUpgradeFinishFailed), findsOneWidget);

      when(() => age.finishGuestUpgrade()).thenAnswer((_) async {});
      await scrollTo(tester, GuestUpgradeView.submitKey);
      await tester.tap(find.byKey(GuestUpgradeView.submitKey));
      await tester.pumpAndSettle();

      verify(
        () => guestAuth.upgradeGuest(
          displayName: any(named: 'displayName'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).called(1);
      expect(find.byType(GuestUpgradeView), findsNothing);
    });

    testWidgets('an address in use says an account exists and offers to sign '
        'in instead, which erases the guest after a warning', (tester) async {
      when(
        () => guestAuth.upgradeGuest(
          displayName: any(named: 'displayName'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        const GuestUpgradeException(GuestUpgradeFailure.emailInUse, 'x'),
      );
      final log = _RouteLog();
      await openUpgrade(tester, log: log);

      await fillAndSubmit(tester);

      // The same words a sign-up with that address gets.
      expect(find.text(_sv.errorEmailAlreadyInUse), findsOneWidget);
      verifyNever(() => age.finishGuestUpgrade());

      await scrollTo(tester, GuestUpgradeView.signInInsteadKey);
      await tester.tap(find.byKey(GuestUpgradeView.signInInsteadKey));
      await tester.pumpAndSettle();
      expect(find.text(_sv.guestSignInInsteadBody), findsOneWidget);
      expect(erasures, isEmpty);

      await tester.tap(find.text(_sv.guestSignInInsteadConfirm));
      await tester.pumpAndSettle();

      expect(erasures, ['guest_sign_in_instead']);
      expect(log.pushed.last, Routes.auth);
    });

    testWidgets('another refusal shows its message and no sign-in offer', (
      tester,
    ) async {
      when(
        () => guestAuth.upgradeGuest(
          displayName: any(named: 'displayName'),
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        const GuestUpgradeException(GuestUpgradeFailure.other, 'Nätverksfel'),
      );
      await openUpgrade(tester);

      await fillAndSubmit(tester);

      expect(find.text('Nätverksfel'), findsOneWidget);
      expect(find.byKey(GuestUpgradeView.signInInsteadKey), findsNothing);
    });
  });
}

final defaultGuard = AuthActionHandler.guardFactory;
