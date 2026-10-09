/// BUT-2170, decision B1 (Malin 2026-10-08): after a new password is saved
/// from a reset link, sign-in opens with the address filled in and says the
/// password is changed. A dead link lands on sign-in with "Glömt lösenord"
/// already open, so a new link is one tap away.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/auth/password_reset_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/viewmodels/auth_viewmodel.dart';
import 'package:butlery/views/auth_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/base_unit_test.dart';

const _kPumpCap = Duration(seconds: 2);

void main() {
  final l10n = AppLocalizationsSv();

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    final auth = MockFactory.createAuthService(isAuthenticated: false);
    auth.setAuthState(isAuthenticated: false, isLoading: false);
    TestServiceLocator.registerMock<AuthService>(auth);
    TestServiceLocator.registerMock<AuthViewModel>(
      AuthViewModel(authService: auth),
    );
    prod.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    PasswordResetHandoff.clear();
    prod.ServiceLocator.reset();
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Future<void> pumpAuth(WidgetTester tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(child: const AuthView(), wrapInScaffold: false),
    );
    await tester.pumpAndSettle(_kPumpCap);
  }

  testWidgets('a saved password: address filled in and the receipt shown', (
    tester,
  ) async {
    PasswordResetHandoff.record(const PasswordResetDone('anna@example.com'));
    await pumpAuth(tester);

    final email = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('email_field')),
        matching: find.byType(EditableText),
      ),
    );
    expect(email.controller.text, 'anna@example.com');
    expect(find.text(l10n.passwordResetDoneNotice), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('auth.passwordResetDoneNotice')),
        matching: find.byType(IconButton),
      ),
    );
    await tester.pumpAndSettle(_kPumpCap);
    expect(find.text(l10n.passwordResetDoneNotice), findsNothing);
    expect(PasswordResetHandoff.pending, isNull);
  });

  testWidgets('a dead link: "Glömt lösenord" opens by itself, once', (
    tester,
  ) async {
    PasswordResetHandoff.record(const PasswordResetRequestNewLink());
    await pumpAuth(tester);

    expect(find.byKey(const Key('reset_email_field')), findsOneWidget);
    expect(PasswordResetHandoff.pending, isNull);
  });

  testWidgets('signing in clears the hand-over', (tester) async {
    final original = AuthView.postLoginDestinationBuilder;
    AuthView.postLoginDestinationBuilder = (_) => const SizedBox.shrink();
    addTearDown(() => AuthView.postLoginDestinationBuilder = original);
    PasswordResetHandoff.record(const PasswordResetDone('anna@example.com'));
    await pumpAuth(tester);

    await tester.enterText(
      find.byKey(const Key('password_field')),
      'Str0ng!Pass1',
    );
    await tester.ensureVisible(find.text('Logga in').last);
    await tester.pumpAndSettle(_kPumpCap);
    await tester.tap(find.text('Logga in').last);
    await tester.pumpAndSettle();

    expect(PasswordResetHandoff.pending, isNull);
  });

  testWidgets('no hand-over: sign-in looks as before', (tester) async {
    await pumpAuth(tester);
    expect(find.byKey(const Key('email_field')), findsOneWidget);
    expect(find.text(l10n.passwordResetDoneNotice), findsNothing);
    expect(find.byKey(const Key('reset_email_field')), findsNothing);
  });
}
