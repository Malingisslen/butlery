// BUT-916 / BUT-549 mockup screen 1: "Fortsätt med Google" and "Fortsätt
// med Apple" above the e-mail form, read out by name, and where each
// outcome of a tap leads.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/auth/mfa_types.dart';
import 'package:butlery/models/auth/provider_sign_in_types.dart';
import 'package:butlery/services/auth/auth_mfa_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/auth_viewmodel.dart';
import 'package:butlery/views/auth/mfa_challenge_view.dart';
import 'package:butlery/views/auth_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _ProviderAuth extends MockAuthService {
  Set<SignInProvider> offered = SignInProvider.values.toSet();
  ProviderSignInOutcome next = ProviderSignInOutcome.signedIn;

  /// Taken before [next], one per sign-in.
  final List<ProviderSignInOutcome> queued = [];
  MfaResolverInfo? _challenge;
  final List<SignInProvider> tapped = [];
  SignInProvider? failedLink;

  @override
  bool canRecoverThroughProvider(SignInProvider provider) => true;

  @override
  Future<MfaProviderProof?> providerRecoveryProof(
    SignInProvider provider,
  ) async => MfaProviderProof(
    providerId: provider.providerId,
    idToken: 'header.payload.signature',
  );

  @override
  SignInProvider? takeFailedProviderLink() {
    final failed = failedLink;
    failedLink = null;
    return failed;
  }

  @override
  bool isProviderOffered(SignInProvider provider) => offered.contains(provider);

  @override
  MfaResolverInfo? get pendingMfaChallenge => _challenge;

  @override
  Future<ProviderSignInOutcome> signInWithProvider(
    SignInProvider provider,
  ) async {
    tapped.add(provider);
    final outcome = queued.isEmpty ? next : queued.removeAt(0);
    if (outcome == ProviderSignInOutcome.mfaRequired) {
      _challenge = const MfaResolverInfo(resolver: Object());
    }
    return outcome;
  }
}

class _RecoveringMfa extends Fake implements AuthMfaService {
  int recoveries = 0;

  @override
  Future<MfaRecoveryOutcome> recoverWithProviderBackupCode({
    required MfaProviderProof proof,
    required String code,
  }) async {
    recoveries++;
    return MfaRecoveryOutcome.recovered;
  }
}

void main() {
  late _ProviderAuth service;
  late WidgetBuilder originalDestination;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    originalDestination = AuthView.postLoginDestinationBuilder;
    AuthView.postLoginDestinationBuilder = (_) => const Text('inne i appen');
    service = _ProviderAuth();
    service.setAuthState(isAuthenticated: false, isLoading: false);
    TestServiceLocator.registerMock<AuthService>(service);
    TestServiceLocator.registerMock<AuthViewModel>(
      AuthViewModel(authService: service),
    );
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

  Widget app() => MaterialApp(
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
  );

  Future<void> tapProvider(WidgetTester tester, String key) async {
    final button = find.byKey(ValueKey('auth.provider.$key'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('both buttons are there and a screen reader names them', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Fortsätt med Google'), findsOneWidget);
    expect(find.bySemanticsLabel('Fortsätt med Apple'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('auth.provider.google'))),
      matchesSemantics(
        label: 'Fortsätt med Google',
        isButton: true,
        hasTapAction: true,
        hasFocusAction: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
      ),
    );
    // Above the e-mail form, as drawn.
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('auth.provider.apple'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('email_field'))).dy),
    );
    semantics.dispose();
  });

  testWidgets('where no provider is offered nothing is drawn', (tester) async {
    service.offered = {};
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Fortsätt med Google'), findsNothing);
    expect(find.text('Fortsätt med Apple'), findsNothing);
  });

  testWidgets('a signed-in provider goes into the app', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tapProvider(tester, 'apple');

    expect(service.tapped, [SignInProvider.apple]);
    expect(find.text('inne i appen'), findsOneWidget);
  });

  testWidgets('a provider that could not be linked is named after the '
      'sign-in', (tester) async {
    service.failedLink = SignInProvider.apple;
    // A snackbar is drawn by a Scaffold, as every real destination has.
    AuthView.postLoginDestinationBuilder = (_) =>
        const Scaffold(body: Text('inne i appen'));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tapProvider(tester, 'google');

    expect(find.text('inne i appen'), findsOneWidget);
    expect(
      find.text(
        'Apple kunde inte kopplas till kontot. Försök igen med Fortsätt '
        'med Apple.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a provider account with two-step asks for the code next', (
    tester,
  ) async {
    service.next = ProviderSignInOutcome.mfaRequired;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tapProvider(tester, 'google');

    expect(find.byType(MfaChallengeView), findsOneWidget);
    final view = tester.widget<MfaChallengeView>(find.byType(MfaChallengeView));
    expect(view.provider, SignInProvider.google);
    expect(view.email, isNull, reason: 'no password exists to keep');
    expect(find.text('inne i appen'), findsNothing);
  });

  testWidgets('a backup code whose sign-in was cancelled signs in on the '
      'retry and lands with the notice to turn two-step on again', (
    tester,
  ) async {
    final mfa = _RecoveringMfa();
    TestServiceLocator.registerMock<AuthMfaService>(mfa);
    service.queued.addAll([
      ProviderSignInOutcome.mfaRequired,
      ProviderSignInOutcome.cancelled,
    ]);
    AuthView.postLoginDestinationBuilder = (_) =>
        const Scaffold(body: Text('inne i appen'));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tapProvider(tester, 'google');
    await tester.tap(find.text('Använd en reservkod'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('mfaChallenge.backupCode')),
      'ABCDE-FGHJK',
    );
    await tester.tap(find.byKey(const ValueKey('mfaChallenge.backupSubmit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mfaChallenge.signInAgain')), findsOne);
    expect(find.text('inne i appen'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('mfaChallenge.signInAgain')));
    await tester.pumpAndSettle();

    expect(mfa.recoveries, 1);
    expect(find.text('inne i appen'), findsOneWidget);
    expect(
      find.text(
        'Tvåstegsverifieringen är avstängd. Slå på den igen under '
        'Kontosäkerhet.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a closed sheet stays on the sign-in screen', (tester) async {
    service.next = ProviderSignInOutcome.cancelled;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tapProvider(tester, 'google');

    expect(find.byType(AuthView), findsOneWidget);
    expect(find.text('inne i appen'), findsNothing);
  });
}
