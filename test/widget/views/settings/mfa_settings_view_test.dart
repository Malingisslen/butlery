/// PQ-16 = A (produktbeslut 2026-09-23, Linear BUT-2142): turning two-step
/// verification ON is hidden now. The app has no sign-in challenge and no
/// fallback path, so whoever turns it on can lock themselves out
/// (produktregler.md:677). Someone who already has it on must still be able
/// to turn it off.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/models/auth/mfa_types.dart';
import 'package:butlery/services/auth/auth_mfa_service.dart';
import 'package:butlery/views/settings/mfa_settings_view.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockAuthMfaService extends Mock implements AuthMfaService {}

class _FakeFactor extends Fake implements MfaFactorInfo {}

void main() {
  late _MockAuthMfaService mfa;

  setUpAll(() => registerFallbackValue(_FakeFactor()));

  setUp(() async {
    await GetIt.instance.reset();
    mfa = _MockAuthMfaService();
    GetIt.instance.registerSingleton<AuthMfaService>(mfa);
    prod.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  Future<void> pump(
    WidgetTester tester, {
    bool offersEnrollment = false,
  }) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: MfaSettingsView(offersEnrollment: offersEnrollment),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('without two-step verification, nothing offers to turn it on', (
    tester,
  ) async {
    when(() => mfa.hasMfaEnabled()).thenAnswer((_) async => false);
    when(() => mfa.getEnrolledFactors()).thenAnswer((_) async => []);

    await pump(tester);

    expect(find.byType(ButleryTopBar), findsOneWidget);
    expect(find.text('Skicka kod'), findsNothing);
    expect(find.text('Telefonnummer'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(HeroButton), findsNothing);
    // The line that urged turning it on would point at nothing.
    expect(find.text('Aktivera MFA för extra säkerhet.'), findsNothing);
    // The status is still told.
    expect(find.text('MFA inaktiverat'), findsOneWidget);
    verifyNever(
      () => mfa.startMfaEnrollment(
        any(),
        onCodeSent: any(named: 'onCodeSent'),
        onError: any(named: 'onError'),
        onAutoVerified: any(named: 'onAutoVerified'),
      ),
    );
  });

  testWidgets('with two-step verification on, it can still be removed', (
    tester,
  ) async {
    const factor = MfaFactorInfo(
      factor: 'phone-factor',
      displayName: 'Min telefon',
    );
    when(() => mfa.hasMfaEnabled()).thenAnswer((_) async => true);
    when(() => mfa.getEnrolledFactors()).thenAnswer((_) async => [factor]);

    await pump(tester);

    expect(find.text('Min telefon'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    // The removal asks first; the way off is intact.
    expect(find.text('Ta bort MFA?'), findsOneWidget);
    expect(find.text('Skicka kod'), findsNothing);
  });

  testWidgets('the form is kept behind the flag, with Skicka kod as its '
      'saffron action', (tester) async {
    when(() => mfa.hasMfaEnabled()).thenAnswer((_) async => false);
    when(() => mfa.getEnrolledFactors()).thenAnswer((_) async => []);

    await pump(tester, offersEnrollment: true);

    // The form exists behind the flag, with "Skicka kod" as the saffron hero.
    expect(find.text('Skicka kod'), findsOneWidget);
    expect(find.byType(HeroButton), findsOneWidget);
  });
}
