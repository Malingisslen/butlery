/// TR::FLOW::06::byt-epost::omverifiering-bada under BUT-2171 = A (Malin,
/// 2026-10-07): Firebase's flow is kept, so only the new address confirms
/// and the current one is told afterwards with a way to undo. The view says
/// so before the change is asked for, the change goes through
/// reauthentication, and the current address
/// stays the one shown until the link is opened.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/auth/auth_mfa_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/views/more/account_email_view.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/mocks/production_mocks.dart' as mocks;
import '../../../test_support/base_unit_test.dart';

class _MockAuthMfaService extends Mock implements AuthMfaService {}

void main() {
  final l10n = AppLocalizationsSv();
  late mocks.MockAuthService auth;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    auth = MockFactory.createAuthService(
      isAuthenticated: true,
      currentUser: MockFactory.createMockUser(
        uid: 'test-user-123',
        email: 'gammal@example.com',
      ),
    );
    TestServiceLocator.registerMock<AuthService>(auth);
    final mfa = _MockAuthMfaService();
    when(() => mfa.hasMfaEnabled()).thenAnswer((_) async => false);
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

  Future<void> enterEmailChange(
    WidgetTester tester,
    String password,
    String newEmail,
  ) async {
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('accountEmail.password')),
        matching: find.byType(TextField),
      ),
      password,
    );
    await tester.enterText(
      find.byKey(const ValueKey('accountEmail.newEmail')),
      newEmail,
    );
  }

  testWidgets(
    'tells how the change is confirmed before asking, then sends the link '
    'to the new address only after reauthentication',
    (tester) async {
      when(
        () => auth.reauthenticateWithPassword('hemligt'),
      ).thenAnswer((_) async => true);
      when(
        () => auth.changeEmail('ny@example.com'),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: const AccountEmailView(),
          wrapInScaffold: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('accountEmail.changeHow')))
            .data,
        l10n.accountSecurityEmailChangeHow,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('accountEmail.current')))
            .data,
        'gammal@example.com',
      );
      final bar = tester.widget<ButleryTopBar>(find.byType(ButleryTopBar));
      expect(bar.title, l10n.settingsAccountEmail);
      expect(bar.backTo, l10n.settingsAccountAreaTitle);

      await enterEmailChange(tester, 'hemligt', 'ny@example.com');
      final button = find.widgetWithText(
        FilledButton,
        l10n.accountSecurityChangeEmail,
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      verifyInOrder([
        () => auth.reauthenticateWithPassword('hemligt'),
        () => auth.changeEmail('ny@example.com'),
      ]);
      expect(find.text(l10n.accountSecurityEmailVerificationSent), findsOne);
      // The current address still applies until the link is opened.
      expect(find.text('gammal@example.com'), findsOneWidget);
    },
  );

  testWidgets('a refused reauthentication never asks for the change', (
    tester,
  ) async {
    when(
      () => auth.reauthenticateWithPassword(any()),
    ).thenAnswer((_) async => false);

    await tester.pumpWidget(
      createLocalizedTestApp(
        child: const AccountEmailView(),
        wrapInScaffold: false,
      ),
    );
    await tester.pumpAndSettle();

    await enterEmailChange(tester, 'fel', 'ny@example.com');
    final button = find.widgetWithText(
      FilledButton,
      l10n.accountSecurityChangeEmail,
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    verify(() => auth.reauthenticateWithPassword('fel')).called(1);
    verifyNever(() => auth.changeEmail(any()));
    expect(find.text(l10n.accountSecurityEmailChangeFailed), findsOneWidget);
    expect(find.text(l10n.accountSecurityEmailVerificationSent), findsNothing);
  });

  testWidgets('the page fits at 320 dp and 200 % text', (tester) async {
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
            child: const AccountEmailView(),
          ),
        ),
        wrapInScaffold: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
