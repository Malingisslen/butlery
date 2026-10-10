// A "Namn krävs" error must follow the field once the user has pressed the
// button, instead of standing until the next press; before the first press
// typing must not scold.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/auth_viewmodel.dart';
import 'package:butlery/views/auth_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';
import '../../../test_support/semantics_announcement.dart';

void main() {
  group('AuthView register form', () {
    late MockAuthService mockAuthService;
    late AuthViewModel viewModel;
    late WidgetBuilder originalDestination;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      originalDestination = AuthView.postLoginDestinationBuilder;
      AuthView.postLoginDestinationBuilder = (_) => const SizedBox.shrink();

      mockAuthService = MockFactory.createAuthService(isAuthenticated: false);
      mockAuthService.setAuthState(isAuthenticated: false, isLoading: false);
      TestServiceLocator.registerMock<AuthService>(mockAuthService);

      viewModel = AuthViewModel(authService: mockAuthService);
      TestServiceLocator.registerMock<AuthViewModel>(viewModel);
      prod.ServiceLocator.initialize(DIContainer());
    });

    tearDown(() async {
      AuthView.postLoginDestinationBuilder = originalDestination;
      prod.ServiceLocator.reset();
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    Future<void> pumpRegister(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('sv'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.lightTheme,
          home: const AuthView(),
        ),
      );
      await tester.pumpAndSettle();
      viewModel.toggleAuthMode();
      await tester.pumpAndSettle();
      expect(viewModel.isLoginMode, isFalse);
    }

    Future<void> pressSubmit(WidgetTester tester) async {
      final submit = find.byKey(const ValueKey('auth.submit'));
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
    }

    testWidgets('typing in the name field before any submit shows no error', (
      tester,
    ) async {
      await pumpRegister(tester);

      await tester.enterText(find.byKey(const Key('name_field')), 'A');
      await tester.pump();
      await tester.enterText(find.byKey(const Key('name_field')), '');
      await tester.pumpAndSettle();

      expect(find.text('Namn krävs'), findsNothing);
    });

    testWidgets('after a submit, "Namn krävs" goes away as a name is typed', (
      tester,
    ) async {
      await pumpRegister(tester);

      await pressSubmit(tester);
      expect(find.text('Namn krävs'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('name_field')), 'Anna');
      await tester.pumpAndSettle();

      expect(find.text('Namn krävs'), findsNothing);
    });

    testWidgets('after a submit, clearing a typed name brings the error back', (
      tester,
    ) async {
      await pumpRegister(tester);
      await pressSubmit(tester);
      await tester.enterText(find.byKey(const Key('name_field')), 'Anna');
      await tester.pumpAndSettle();
      expect(find.text('Namn krävs'), findsNothing);

      await tester.enterText(find.byKey(const Key('name_field')), '');
      await tester.pumpAndSettle();

      expect(find.text('Namn krävs'), findsOneWidget);
    });

    testWidgets('switching to Logga in after a failed submit stops the live '
        'checks until the next submit', (tester) async {
      await pumpRegister(tester);
      await pressSubmit(tester);
      expect(find.text('Namn krävs'), findsOneWidget);

      final toggle = find.byType(OutlinedButton);
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(viewModel.isLoginMode, isTrue);

      await tester.enterText(find.byKey(const Key('email_field')), 'anna');
      await tester.pumpAndSettle();
      expect(find.text('Ange en giltig e-postadress'), findsNothing);

      // Control: the same half-typed address is refused once submitted.
      await pressSubmit(tester);
      expect(find.text('Ange en giltig e-postadress'), findsOneWidget);
    });

    testWidgets('the terms checkbox is one stop named by its visible text', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpRegister(tester);

      expect(find.bySemanticsLabel(RegExp('^Jag accepterar')), findsOneWidget);
      expect(
        find.bySemanticsLabel('Jag accepterar Villkor och Integritetspolicy'),
        findsNothing,
      );
      handle.dispose();
    });

    Finder passwordToggle(String tooltip) => find.byWidgetPredicate(
      (w) => w is IconButton && w.tooltip == tooltip,
    );

    testWidgets('the password toggle announces its action once, can be '
        'activated, and flips to the opposite action', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRegister(tester);

      expect(announcedLines(tester, passwordToggle('Visa lösenord')), [
        'Visa lösenord',
      ]);
      expectActivatable(tester, passwordToggle('Visa lösenord'));

      await tester.ensureVisible(passwordToggle('Visa lösenord'));
      await tester.tap(passwordToggle('Visa lösenord'));
      await tester.pumpAndSettle();

      expect(announcedLines(tester, passwordToggle('Dölj lösenord')), [
        'Dölj lösenord',
      ]);
      expect(passwordToggle('Visa lösenord'), findsNothing);
      handle.dispose();
    });

    testWidgets('the password toggle is inert while signing in', (
      tester,
    ) async {
      // The busy submit button animates forever, so settling would time out.
      mockAuthService.setAuthState(isAuthenticated: false, isLoading: true);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('sv'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.lightTheme,
          home: const AuthView(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(viewModel.isLoading, isTrue);

      final toggle = tester.widget<IconButton>(
        passwordToggle('Visa lösenord'),
      );
      expect(toggle.onPressed, isNull);
    });
  });
}
