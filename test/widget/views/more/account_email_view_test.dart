/// TR::FLOW::06::byt-epost::omverifiering-bada under BUT-2171 = A (Malin,
/// 2026-10-07): Firebase's flow is kept, so only the new address confirms
/// and the current one is told afterwards with a way to undo.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/auth/provider_sign_in_types.dart';
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

/// An account without a password (BUT-916 C7).
class _ProviderOnlyAuth extends mocks.MockAuthService {
  _ProviderOnlyAuth(this.provider);

  /// Null: the account's provider is not offered on this platform.
  final SignInProvider? provider;
  final reauthentications = <Completer<ProviderSignInOutcome>>[];

  @override
  bool get hasPasswordSignIn => false;

  @override
  SignInProvider? reauthenticationProvider({bool forDeletion = false}) =>
      provider;

  @override
  Future<ProviderSignInOutcome> reauthenticateWithProvider(
    SignInProvider provider,
  ) {
    final sheet = Completer<ProviderSignInOutcome>();
    reauthentications.add(sheet);
    return sheet.future;
  }
}

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
            .textSpan!
            .toPlainText(),
        '${l10n.accountSecurityEmailNow}gammal@example.com',
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
      expect(find.textContaining('gammal@example.com'), findsOneWidget);
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

  group('an account without a password (BUT-916 C7)', () {
    void use(_ProviderOnlyAuth providerAuth) {
      providerAuth.setAuthState(
        isAuthenticated: true,
        currentUser: MockFactory.createMockUser(
          uid: 'test-user-123',
          email: 'gammal@example.com',
        ),
      );
      TestServiceLocator.registerMock<AuthService>(providerAuth);
    }

    testWidgets('where its provider is not offered, the change says it '
        'cannot be confirmed here and the button is off', (tester) async {
      use(_ProviderOnlyAuth(null));
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: const AccountEmailView(),
          wrapInScaffold: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.accountSecurityEmailCannotConfirmHere),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('accountEmail.password')), findsNothing);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, l10n.accountSecurityChangeEmail),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('a second tap while the sheet is open starts nothing', (
      tester,
    ) async {
      final providerAuth = _ProviderOnlyAuth(SignInProvider.google);
      use(providerAuth);
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: const AccountEmailView(),
          wrapInScaffold: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.accountSecurityEmailProviderReauth('Google')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('accountEmail.newEmail')),
        'ny@example.com',
      );
      final button = find.widgetWithText(
        FilledButton,
        l10n.accountSecurityChangeEmail,
      );
      await tester.ensureVisible(button);

      await tester.tap(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();

      expect(providerAuth.reauthentications, hasLength(1));
      providerAuth.reauthentications.single.complete(
        ProviderSignInOutcome.cancelled,
      );
      await tester.pumpAndSettle();
    });

    Future<_ProviderOnlyAuth> submitThroughGoogle(WidgetTester tester) async {
      final providerAuth = _ProviderOnlyAuth(SignInProvider.google);
      use(providerAuth);
      when(
        () => providerAuth.changeEmail(any()),
      ).thenAnswer((_) async => true);
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: const AccountEmailView(),
          wrapInScaffold: false,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('accountEmail.newEmail')),
        'ny@example.com',
      );
      final button = find.widgetWithText(
        FilledButton,
        l10n.accountSecurityChangeEmail,
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      return providerAuth;
    }

    testWidgets('a cancelled sheet changes nothing', (tester) async {
      final providerAuth = await submitThroughGoogle(tester);
      providerAuth.reauthentications.single.complete(
        ProviderSignInOutcome.cancelled,
      );
      await tester.pumpAndSettle();

      verifyNever(() => providerAuth.changeEmail(any()));
      expect(
        find.text(l10n.accountSecurityEmailVerificationSent),
        findsNothing,
      );
    });

    testWidgets('a failed sheet changes nothing', (tester) async {
      final providerAuth = await submitThroughGoogle(tester);
      providerAuth.reauthentications.single.complete(
        ProviderSignInOutcome.failed,
      );
      await tester.pumpAndSettle();

      verifyNever(() => providerAuth.changeEmail(any()));
      expect(
        find.text(l10n.accountSecurityEmailVerificationSent),
        findsNothing,
      );
    });

    testWidgets('a confirmed sheet sends the change without a password', (
      tester,
    ) async {
      final providerAuth = await submitThroughGoogle(tester);
      providerAuth.reauthentications.single.complete(
        ProviderSignInOutcome.signedIn,
      );
      await tester.pumpAndSettle();

      verify(() => providerAuth.changeEmail('ny@example.com')).called(1);
      verifyNever(() => providerAuth.reauthenticateWithPassword(any()));
      expect(
        find.text(l10n.accountSecurityEmailVerificationSent),
        findsOneWidget,
      );
    });
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
