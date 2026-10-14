/// Lösenord under Konto & säkerhet: the change goes through
/// reauthentication and then the new password, a mismatch never reaches the
/// service, and (BUT-2166) the field's eye shows the ACTION a tap takes — an
/// open eye while the password is hidden, a struck eye while it is shown.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/auth/auth_mfa_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/views/more/account_password_view.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

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

  IconData? glyphOf(WidgetTester tester, Finder button) => tester
      .widget<ButleryIcon>(
        find.descendant(of: button, matching: find.byType(ButleryIcon)),
      )
      .icon;

  testWidgets('the eye swaps to a struck eye once the password is shown', (
    tester,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: const AccountPasswordView(),
        wrapInScaffold: false,
      ),
    );
    await tester.pumpAndSettle();

    final show = find.byTooltip(l10n.tooltipShowPassword).first;
    expect(glyphOf(tester, show), ButleryIcons.eye);

    await tester.tap(show);
    await tester.pumpAndSettle();

    final hide = find.byTooltip(l10n.tooltipHidePassword);
    expect(hide, findsOneWidget);
    expect(glyphOf(tester, hide), ButleryIcons.eyeOff);
  });

  testWidgets('leaving with a typed new password asks first', (tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: const AccountPasswordView(),
        wrapInScaffold: false,
      ),
    );
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    unawaited(navigator.maybePop());
    await tester.pumpAndSettle();
    expect(find.text(l10n.unsavedChangesTitle), findsNothing);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('accountPassword.new')),
        matching: find.byType(EditableText),
      ),
      'hemligt123',
    );
    await tester.pump();
    unawaited(navigator.maybePop());
    await tester.pumpAndSettle();
    expect(find.text(l10n.unsavedChangesTitle), findsOneWidget);
  });

  testWidgets('the rule line names the length the form really enforces, and '
      'the confirm field says what it repeats', (tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: const AccountPasswordView(),
        wrapInScaffold: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('accountPassword.rule')))
          .data,
      l10n.passwordRuleHint,
    );
    expect(find.text(l10n.accountSecurityRepeatNewPassword), findsOneWidget);
  });

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: const AccountPasswordView(),
        wrapInScaffold: false,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillAndSubmit(
    WidgetTester tester, {
    required String confirm,
  }) async {
    Finder field(String key) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(TextField),
    );
    await tester.enterText(field('accountPassword.current'), 'gammalt123');
    await tester.enterText(field('accountPassword.new'), 'nyttLosen123');
    await tester.enterText(field('accountPassword.confirm'), confirm);
    final button = find.widgetWithText(
      FilledButton,
      l10n.accountSecurityChangePassword,
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('the repeated password says it matches only once it does', (
    tester,
  ) async {
    await pumpView(tester);
    Finder field(String key) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(TextField),
    );
    final confirm = find.byKey(const ValueKey('accountPassword.confirm'));
    final mark = find.descendant(
      of: confirm,
      matching: find.text(l10n.passwordsMatch),
    );

    await tester.enterText(field('accountPassword.new'), 'nyttLosen123');
    await tester.pump();
    expect(mark, findsNothing);

    await tester.enterText(field('accountPassword.confirm'), 'nyttLosen12');
    await tester.pump();
    expect(mark, findsNothing);

    await tester.enterText(field('accountPassword.confirm'), 'nyttLosen123');
    await tester.pump();
    expect(mark, findsOneWidget);
    expect(
      find.descendant(of: confirm, matching: find.byIcon(ButleryIcons.check)),
      findsOneWidget,
    );

    await tester.enterText(field('accountPassword.new'), 'annat');
    await tester.pump();
    expect(mark, findsNothing);
  });

  testWidgets('names the page and leads back to Konto & säkerhet', (
    tester,
  ) async {
    await pumpView(tester);

    final bar = tester.widget<ButleryTopBar>(find.byType(ButleryTopBar));
    expect(bar.title, l10n.settingsAccountPassword);
    expect(bar.backTo, l10n.settingsAccountAreaTitle);
  });

  testWidgets('reauthenticates with the current password, then changes it', (
    tester,
  ) async {
    when(
      () => auth.reauthenticateWithPassword('gammalt123'),
    ).thenAnswer((_) async => true);
    when(
      () => auth.changePassword('nyttLosen123'),
    ).thenAnswer((_) async => true);

    await pumpView(tester);
    await fillAndSubmit(tester, confirm: 'nyttLosen123');

    verifyInOrder([
      () => auth.reauthenticateWithPassword('gammalt123'),
      () => auth.changePassword('nyttLosen123'),
    ]);
    expect(find.text(l10n.accountSecurityPasswordChanged), findsOneWidget);
  });

  testWidgets('a mismatching confirmation never reaches the service', (
    tester,
  ) async {
    await pumpView(tester);
    await fillAndSubmit(tester, confirm: 'annat123456');

    verifyNever(() => auth.reauthenticateWithPassword(any()));
    verifyNever(() => auth.changePassword(any()));
    expect(find.text(l10n.accountSecurityPasswordMismatch), findsOneWidget);
    expect(find.text(l10n.accountSecurityPasswordChanged), findsNothing);
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
            child: const AccountPasswordView(),
          ),
        ),
        wrapInScaffold: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
