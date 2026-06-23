// Regression test for the onboarding-chain CRITICAL bug: a successful REGISTER
// must NOT manually pushReplacement to MinaReceptView. AuthView lives in the
// '/' subtree, so a manual replace tears out AuthWrapper and skips
// email-verification, the GDPR age gate, onboarding, and starter-content
// seeding. Only a returning user (LOGIN) is sent straight to the recipe list;
// register lets the auth-state change drive AuthWrapper into onboarding.

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
import 'package:butlery/views/mina_recept_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

const _kPumpCap = Duration(seconds: 2);

/// Counts pushReplacement onto the navigator. The login path does a manual
/// `Navigator.pushReplacement(MaterialPageRoute(MinaReceptView))`; register
/// must not.
class _ReplaceObserver extends NavigatorObserver {
  int replaceCount = 0;
  Route<dynamic>? lastNewRoute;

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    replaceCount++;
    lastNewRoute = newRoute;
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

void main() {
  group('AuthView submit navigation gating', () {
    late MockAuthService mockAuthService;
    late AuthViewModel realViewModel;
    late _ReplaceObserver observer;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      observer = _ReplaceObserver();

      // Real AuthViewModel + mocked service so isLoginMode / register / signIn
      // behave as in production, but no Firebase call leaves the test. The mock
      // returns success (!hasError) for both signInWithEmail and
      // registerWithEmail.
      mockAuthService = MockFactory.createAuthService(isAuthenticated: false);
      mockAuthService.setAuthState(isAuthenticated: false, isLoading: false);
      TestServiceLocator.registerMock<AuthService>(mockAuthService);

      realViewModel = AuthViewModel(authService: mockAuthService);
      TestServiceLocator.registerMock<AuthViewModel>(realViewModel);

      prod.ServiceLocator.initialize(DIContainer());
    });

    tearDown(() async {
      prod.ServiceLocator.reset();
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    Widget appUnderTest() => MaterialApp(
      locale: const Locale('sv'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      navigatorObservers: [observer],
      home: const AuthView(),
    );

    Future<void> fillCredentials(WidgetTester tester) async {
      await tester.enterText(
        find.byKey(const Key('email_field')),
        'ny.anvandare@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'Str0ng!Pass1',
      );
    }

    testWidgets(
      'successful LOGIN pushReplacement-es to MinaReceptView (returning user)',
      (tester) async {
        await tester.pumpWidget(appUnderTest());
        await tester.pumpAndSettle(_kPumpCap);

        // Default mode is login.
        expect(realViewModel.isLoginMode, isTrue);
        await fillCredentials(tester);
        await tester.pumpAndSettle(_kPumpCap);

        // Tap the submit button (login label). The card heading also reads
        // "Logga in", so target the last match — the bottom submit button.
        await tester.ensureVisible(find.text('Logga in').last);
        await tester.pumpAndSettle(_kPumpCap);
        await tester.tap(find.text('Logga in').last);
        // _handleSubmit awaits signIn (async) then pushReplacement-es. Pump
        // until the future resolves and the navigation lands.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Building the real MinaReceptView may surface service-graph exceptions
        // in the test harness — we only care that the replace happened.
        tester.takeException();

        expect(
          observer.replaceCount,
          1,
          reason: 'login must send the returning user straight to the list',
        );
        expect(observer.lastNewRoute, isNotNull);
      },
    );

    testWidgets(
      'successful REGISTER does NOT pushReplacement to MinaReceptView '
      '(routes through the onboarding gate)',
      (tester) async {
        await tester.pumpWidget(appUnderTest());
        await tester.pumpAndSettle(_kPumpCap);

        // Switch to register mode — reveals name field + age/terms checkboxes.
        realViewModel.toggleAuthMode();
        await tester.pumpAndSettle(_kPumpCap);
        expect(realViewModel.isLoginMode, isFalse);

        await tester.enterText(
          find.byKey(const Key('name_field')),
          'Ny Användare',
        );
        await fillCredentials(tester);
        await tester.pumpAndSettle(_kPumpCap);

        // Tick age-confirmation + terms (both required to submit). The two
        // checkboxes sit inside 24x24 SizedBoxes near the bottom of the scroll
        // view; ensureVisible + warnIfMissed:false keeps the tap robust against
        // layout offsets in the headless test surface.
        final checkboxes = find.byType(Checkbox);
        expect(checkboxes, findsNWidgets(2));
        for (var i = 0; i < 2; i++) {
          await tester.ensureVisible(checkboxes.at(i));
          await tester.pumpAndSettle(_kPumpCap);
          await tester.tap(checkboxes.at(i), warnIfMissed: false);
          await tester.pumpAndSettle(_kPumpCap);
        }
        // Both boxes must be checked, else _handleSubmit bails before register.
        final checkedValues = tester
            .widgetList<Checkbox>(checkboxes)
            .map((c) => c.value)
            .toList();
        expect(
          checkedValues,
          everyElement(isTrue),
          reason: 'age + terms must be accepted to reach the register call',
        );

        // Submit (create-account label). The card heading also reads "Skapa
        // konto", so target the last match — the bottom submit button.
        await tester.ensureVisible(find.text('Skapa konto').last);
        await tester.pumpAndSettle(_kPumpCap);
        await tester.tap(find.text('Skapa konto').last);
        await tester.pump();
        await tester.pump();
        tester.takeException();

        // Guard against a vacuous pass: replaceCount would also be 0 if
        // _handleSubmit bailed before register() (e.g. a silent validation
        // error). A null error confirms register() was actually reached.
        expect(
          realViewModel.error,
          isNull,
          reason: 'register() must have been reached and returned success',
        );

        expect(
          observer.replaceCount,
          0,
          reason:
              'register must NOT pushReplacement — that would tear out '
              'AuthWrapper and skip verification/age-gate/onboarding/seeding',
        );
        expect(
          find.byType(MinaReceptView),
          findsNothing,
          reason: 'a new user must never land on the recipe list directly',
        );
      },
    );
  });
}
