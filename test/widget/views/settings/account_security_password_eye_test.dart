/// BUT-2166: the password field's eye shows the ACTION a tap takes — an open
/// eye while the password is hidden, a struck eye while it is shown.
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
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/base_unit_test.dart';

class _MockAuthMfaService extends Mock implements AuthMfaService {}

void main() {
  final l10n = AppLocalizationsSv();

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    final auth = MockFactory.createAuthService(
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
        child: const AccountSecurityView(),
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
}
