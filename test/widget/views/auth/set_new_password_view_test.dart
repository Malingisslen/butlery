/// TR::FLOW::06::aterstall::satt-nytt (BUT-2170): the reset link opens
/// "Välj nytt lösenord" in the app. It names the account, refuses a bad
/// password before sending, and after saving goes to sign-in with the
/// address handed over (decision B1, Malin 2026-10-08). A dead link offers
/// "Skicka ny länk" instead of a form.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/auth/password_reset_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/viewmodels/password_reset_viewmodel.dart';
import 'package:butlery/views/auth/set_new_password_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/base_unit_test.dart';

class _MockResetService extends Mock implements PasswordResetService {}

class _MockAuthService extends Mock implements AuthService {}

class _MockUser extends Mock implements User {}

void main() {
  final l10n = AppLocalizationsSv();
  late _MockResetService service;
  late _MockAuthService auth;
  late List<String> pushedRoutes;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    PasswordResetHandoff.clear();
    pushedRoutes = [];
    service = _MockResetService();
    auth = _MockAuthService();
    when(() => auth.currentUser).thenReturn(null);
    TestServiceLocator.registerMock<PasswordResetViewModel>(
      PasswordResetViewModel(resetService: service, authService: auth),
    );
  });

  tearDown(() async {
    PasswordResetHandoff.clear();
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: const SetNewPasswordView(code: 'code-1'),
        wrapInScaffold: false,
        onGenerateRoute: (settings) {
          pushedRoutes.add(settings.name!);
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('inloggningen')),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  void signedInAsBertil() {
    final user = _MockUser();
    when(() => user.email).thenReturn('bertil@example.com');
    when(() => auth.currentUser).thenReturn(user);
  }

  // Opened on top of a home screen, so leaving the view is observable.
  Future<void> pumpViewOverHome(WidgetTester tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        onGenerateRoute: (settings) {
          pushedRoutes.add(settings.name!);
          return null;
        },
        child: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SetNewPasswordView(code: 'code-1'),
                ),
              ),
              child: const Text('hem'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('hem'));
    await tester.pumpAndSettle();
  }

  void linkIsGood() => when(
    () => service.check('code-1'),
  ).thenAnswer((_) async => (email: 'anna@example.com', failure: null));

  Future<void> typePasswords(
    WidgetTester tester,
    String first,
    String second,
  ) async {
    await tester.enterText(
      find.byKey(const ValueKey('setNewPassword.password')),
      first,
    );
    await tester.enterText(
      find.byKey(const ValueKey('setNewPassword.repeat')),
      second,
    );
    await tester.tap(find.byKey(const ValueKey('setNewPassword.save')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'names the account and, once saved, goes to sign-in with the address',
    (tester) async {
      linkIsGood();
      when(
        () => service.confirm(code: 'code-1', newPassword: 'nytt-losen-1'),
      ).thenAnswer((_) async => null);

      await pumpView(tester);
      expect(
        find.text(l10n.setNewPasswordForAccount('anna@example.com')),
        findsOneWidget,
      );

      await typePasswords(tester, 'nytt-losen-1', 'nytt-losen-1');

      verify(
        () => service.confirm(code: 'code-1', newPassword: 'nytt-losen-1'),
      ).called(1);
      expect(pushedRoutes, [Routes.auth]);
      expect(find.text('inloggningen'), findsOneWidget);
      final handoff = PasswordResetHandoff.pending;
      expect(handoff, isA<PasswordResetDone>());
      expect((handoff! as PasswordResetDone).email, 'anna@example.com');
    },
  );

  testWidgets('a mismatched repeat is refused before anything is sent', (
    tester,
  ) async {
    linkIsGood();
    await pumpView(tester);

    await typePasswords(tester, 'nytt-losen-1', 'nytt-losen-2');

    expect(find.text(l10n.accountSecurityPasswordMismatch), findsOneWidget);
    expect(find.text(l10n.setNewPasswordNothingChanged), findsOneWidget);
    verifyNever(
      () => service.confirm(
        code: any(named: 'code'),
        newPassword: any(named: 'newPassword'),
      ),
    );
    expect(pushedRoutes, isEmpty);
  });

  testWidgets('a dead link offers a new one and hands that to sign-in', (
    tester,
  ) async {
    when(() => service.check('code-1')).thenAnswer(
      (_) async => (email: null, failure: PasswordResetFailure.linkInvalid),
    );
    await pumpView(tester);

    expect(find.text(l10n.setNewPasswordLinkInvalidTitle), findsOneWidget);
    expect(find.byKey(const ValueKey('setNewPassword.password')), findsNothing);

    await tester.tap(find.text(l10n.setNewPasswordRequestNew));
    await tester.pumpAndSettle();

    expect(pushedRoutes, [Routes.auth]);
    expect(PasswordResetHandoff.pending, isA<PasswordResetRequestNewLink>());
  });

  testWidgets('an offline check offers a retry that keeps the same link', (
    tester,
  ) async {
    when(() => service.check('code-1')).thenAnswer(
      (_) async => (email: null, failure: PasswordResetFailure.network),
    );
    await pumpView(tester);
    expect(
      find.byKey(const ValueKey('setNewPassword.checkFailed')),
      findsOneWidget,
    );

    linkIsGood();
    await tester.tap(find.text(l10n.commonRetry));
    await tester.pumpAndSettle();

    expect(
      find.text(l10n.setNewPasswordForAccount('anna@example.com')),
      findsOneWidget,
    );
    verify(() => service.check('code-1')).called(2);
  });

  testWidgets('an offline check names the cause', (tester) async {
    when(() => service.check('code-1')).thenAnswer(
      (_) async => (email: null, failure: PasswordResetFailure.network),
    );
    await pumpView(tester);
    expect(
      find.text('${l10n.setNewPasswordCheckFailed} ${l10n.errorNetwork}'),
      findsOneWidget,
    );
  });

  testWidgets(
    'signed in to another account: saving stays signed in and goes back',
    (tester) async {
      signedInAsBertil();
      linkIsGood();
      when(
        () => service.confirm(code: 'code-1', newPassword: 'nytt-losen-1'),
      ).thenAnswer((_) async => null);

      await pumpViewOverHome(tester);
      await typePasswords(tester, 'nytt-losen-1', 'nytt-losen-1');

      expect(find.byType(SetNewPasswordView), findsNothing);
      expect(find.text('hem'), findsOneWidget);
      expect(
        find.text(l10n.setNewPasswordSavedOther('anna@example.com')),
        findsOneWidget,
      );
      expect(pushedRoutes, isEmpty);
      expect(PasswordResetHandoff.pending, isNull);
    },
  );

  testWidgets(
    'signed in to another account: a dead link only offers to close',
    (
      tester,
    ) async {
      signedInAsBertil();
      when(() => service.check('code-1')).thenAnswer(
        (_) async => (email: null, failure: PasswordResetFailure.linkInvalid),
      );
      await pumpViewOverHome(tester);

      expect(
        find.byKey(const ValueKey('setNewPassword.requestNew')),
        findsNothing,
      );
      await tester.tap(find.text(l10n.setNewPasswordClose));
      await tester.pumpAndSettle();
      expect(find.text('hem'), findsOneWidget);
      expect(pushedRoutes, isEmpty);
    },
  );

  testWidgets('a refused password keeps both fields as typed', (tester) async {
    linkIsGood();
    when(
      () => service.confirm(code: 'code-1', newPassword: 'nytt-losen-1'),
    ).thenAnswer((_) async => PasswordResetFailure.weakPassword);
    await pumpView(tester);

    await typePasswords(tester, 'nytt-losen-1', 'nytt-losen-1');

    expect(find.text(l10n.setNewPasswordWeak), findsOneWidget);
    for (final key in ['setNewPassword.password', 'setNewPassword.repeat']) {
      final field = tester.widget<TextField>(find.byKey(ValueKey(key)));
      expect(field.controller!.text, 'nytt-losen-1', reason: key);
    }
    expect(pushedRoutes, isEmpty);
  });

  testWidgets('a check refused for too many attempts names that cause', (
    tester,
  ) async {
    when(() => service.check('code-1')).thenAnswer(
      (_) async => (email: null, failure: PasswordResetFailure.tooManyAttempts),
    );
    await pumpView(tester);
    expect(
      find.text(
        '${l10n.setNewPasswordCheckFailed} ${l10n.errorTooManyAttempts}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a check that failed for an unknown reason names none', (
    tester,
  ) async {
    when(() => service.check('code-1')).thenAnswer(
      (_) async => (email: null, failure: PasswordResetFailure.unknown),
    );
    await pumpView(tester);
    expect(find.text(l10n.setNewPasswordCheckFailed), findsOneWidget);
  });
}
