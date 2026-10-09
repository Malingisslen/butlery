// Enter in the password field submits, and a double tap submits once.

import 'dart:async';

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
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _GatedAuthService extends MockAuthService {
  int signInCalls = 0;
  final Completer<bool> gate = Completer<bool>();

  @override
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) {
    signInCalls++;
    return gate.future;
  }
}

class _ReplaceObserver extends NavigatorObserver {
  int replaceCount = 0;

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    replaceCount++;
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

void main() {
  group('AuthView submit', () {
    late _GatedAuthService service;
    late AuthViewModel viewModel;
    late _ReplaceObserver observer;
    late WidgetBuilder originalDestination;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      observer = _ReplaceObserver();
      originalDestination = AuthView.postLoginDestinationBuilder;
      AuthView.postLoginDestinationBuilder = (_) => const SizedBox.shrink();

      service = _GatedAuthService();
      service.setAuthState(isAuthenticated: false, isLoading: false);
      TestServiceLocator.registerMock<AuthService>(service);
      viewModel = AuthViewModel(authService: service);
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
        'anna@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'Str0ng!Pass1',
      );
    }

    testWidgets('Enter in the password field signs in', (tester) async {
      await tester.pumpWidget(appUnderTest());
      await tester.pumpAndSettle();
      await fillCredentials(tester);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(service.signInCalls, 1);

      service.gate.complete(true);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    });

    testWidgets('a double tap on the login button signs in once and '
        'navigates once', (tester) async {
      await tester.pumpWidget(appUnderTest());
      await tester.pumpAndSettle();
      await fillCredentials(tester);
      await tester.pumpAndSettle();

      final button = find.byKey(const ValueKey('auth.submit'));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.tap(button);
      await tester.pump();

      expect(service.signInCalls, 1);

      service.gate.complete(true);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(service.signInCalls, 1);
      expect(observer.replaceCount, 1);
    });

    testWidgets('Enter followed by a tap while signing in submits once', (
      tester,
    ) async {
      await tester.pumpWidget(appUnderTest());
      await tester.pumpAndSettle();
      await fillCredentials(tester);
      await tester.pumpAndSettle();

      await tester.testTextInput.receiveAction(TextInputAction.done);
      final button = find.byKey(const ValueKey('auth.submit'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();

      expect(service.signInCalls, 1);

      service.gate.complete(true);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(observer.replaceCount, 1);
    });
  });
}
