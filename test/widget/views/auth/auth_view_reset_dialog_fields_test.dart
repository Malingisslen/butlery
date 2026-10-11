/// The "Glömt lösenord" dialog's address field follows Komponentark v1
/// §11: the label stands above the box, and a malformed address shows its
/// error with a glyph.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/services/auth/password_reset_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/viewmodels/auth_viewmodel.dart';
import 'package:butlery/views/auth_view.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/helpers/field_finder.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/base_unit_test.dart';

const _kPumpCap = Duration(seconds: 2);

void main() {
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

  // A dead reset link opens the "Glömt lösenord" dialog by itself.
  Future<Finder> openResetDialog(WidgetTester tester) async {
    PasswordResetHandoff.record(const PasswordResetRequestNewLink());
    await pumpAuth(tester);
    return find.descendant(
      of: find.byType(AlertDialog),
      matching: fieldLabelled('E-post', type: TextField),
    );
  }

  testWidgets('the reset address label stands above its box', (tester) async {
    final field = await openResetDialog(tester);

    expect(field, findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(InputDecorator),
        matching: find.text('E-post'),
      ),
      findsNothing,
    );
  });

  testWidgets('a malformed reset address shows its error with a glyph', (
    tester,
  ) async {
    final field = await openResetDialog(tester);

    await tester.enterText(field, 'inte-en-adress');
    await tester.tap(find.byKey(const ValueKey('auth.resetSend')));
    await tester.pumpAndSettle(_kPumpCap);

    expect(
      find.descendant(
        of: field,
        matching: find.text('Ange en giltig e-postadress'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: field,
        matching: find.byWidgetPredicate(
          (w) => w is ButleryIcon && w.icon == ButleryIcons.info,
        ),
      ),
      findsOneWidget,
    );
  });
}
