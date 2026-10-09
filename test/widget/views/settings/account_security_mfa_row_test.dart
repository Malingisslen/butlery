/// In Kontosäkerhet the "Tvåfaktorsautentisering" row leads every user to
/// the two-step verification settings: the form that turns it on, or the
/// registered method that can be removed.
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

  testWidgets('the two-step heading fits at 320 dp and 200 % text (BUT-2192)', (
    tester,
  ) async {
    when(() => mfa.hasMfaEnabled()).thenAnswer((_) async => true);
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2.0)),
            child: const AccountSecurityView(),
          ),
        ),
        wrapInScaffold: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The section heading and the row both carry the name.
    expect(find.text(l10n.accountSecurityMfaSettings), findsNWidgets(2));
  });

  testWidgets(
    'a user without two-step verification sees the row and reaches the form '
    'that turns it on',
    (tester) async {
      when(() => mfa.hasMfaEnabled()).thenAnswer((_) async => false);

      await pumpView(tester);

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
      expect(find.text('Skicka kod'), findsOneWidget);
    },
  );

  testWidgets('a user with two-step verification reaches it from the row', (
    tester,
  ) async {
    when(() => mfa.hasMfaEnabled()).thenAnswer((_) async => true);

    await pumpView(tester);
    await tester.ensureVisible(mfaRow);
    await tester.tap(mfaRow);
    await tester.pumpAndSettle();

    expect(find.byType(MfaSettingsView), findsOneWidget);
    expect(find.text('Skicka kod'), findsNothing);
  });
}
