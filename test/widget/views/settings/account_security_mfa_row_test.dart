/// PQ-16 follow-up (produktbeslut PQ-16 = A, 2026-09-23; Linear BUT-2142):
/// turning two-step verification on is hidden, so in Kontosäkerhet the
/// "Tvåfaktorsautentisering" row would lead nowhere for a user without it.
/// That user does not see the row. A user who has it on still sees the row
/// and reaches the settings where it can be turned off; once it is off, the
/// row goes when they come back.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/auth/auth_mfa_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/views/settings/account_security_view.dart';
import 'package:butlery/views/settings/mfa_settings_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/base_unit_test.dart';

class _MockAuthMfaService extends Mock implements AuthMfaService {}

void main() {
  final l10n = AppLocalizationsSv();
  late _MockAuthMfaService mfa;
  final mfaRow = find.byKey(const ValueKey('accountSecurity.mfa'));

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    TestServiceLocator.registerMock<AuthService>(
      MockFactory.createAuthService(
        isAuthenticated: true,
        userId: 'test-user-123',
      ),
    );
    mfa = _MockAuthMfaService();
    when(() => mfa.getEnrolledFactors()).thenAnswer((_) async => []);
    TestServiceLocator.registerMock<AuthMfaService>(mfa);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: const AccountSecurityView(),
        wrapInScaffold: false,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a user without two-step verification does not see the row', (
    tester,
  ) async {
    when(() => mfa.hasMfaEnabled()).thenAnswer((_) async => false);

    await pumpView(tester);

    expect(mfaRow, findsNothing);
    expect(find.text(l10n.accountSecurityMfaSettings), findsNothing);
    // The rest of the view is still there.
    expect(find.text(l10n.accountSecurityTitle), findsOneWidget);
  });

  testWidgets('a failed check hides the row rather than guessing', (
    tester,
  ) async {
    when(() => mfa.hasMfaEnabled()).thenThrow(Exception('offline'));

    await pumpView(tester);

    expect(mfaRow, findsNothing);
  });

  testWidgets(
    'a user with two-step verification sees the row, reaches the settings, '
    'and the row goes once it is turned off',
    (tester) async {
      when(() => mfa.hasMfaEnabled()).thenAnswer((_) async => true);

      await pumpView(tester);

      expect(mfaRow, findsOneWidget);
      expect(
        find.descendant(
          of: mfaRow,
          matching: find.text(l10n.accountSecurityMfaSettings),
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(mfaRow);
      await tester.tap(mfaRow);
      await tester.pumpAndSettle();
      expect(find.byType(MfaSettingsView), findsOneWidget);

      // Turned off in the settings; back in Kontosäkerhet the row is gone.
      when(() => mfa.hasMfaEnabled()).thenAnswer((_) async => false);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();

      expect(find.byType(MfaSettingsView), findsNothing);
      expect(mfaRow, findsNothing);
    },
  );
}
