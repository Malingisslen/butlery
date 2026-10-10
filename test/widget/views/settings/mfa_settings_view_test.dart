import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/models/auth/mfa_types.dart';
import 'package:butlery/services/auth/auth_mfa_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/views/settings/mfa_backup_codes_dialog.dart';
import 'package:butlery/views/settings/mfa_enrollment_forms.dart';
import 'package:butlery/views/settings/mfa_settings_view.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockAuthMfaService extends Mock implements AuthMfaService {}

class _FakeFactor extends Fake implements MfaFactorInfo {}

class _FakeSetup extends Fake implements MfaTotpSetup {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  late _MockAuthMfaService mfa;
  late _MockAuthService auth;

  setUpAll(() {
    registerFallbackValue(_FakeFactor());
    registerFallbackValue(_FakeSetup());
  });

  setUp(() async {
    await GetIt.instance.reset();
    mfa = _MockAuthMfaService();
    auth = _MockAuthService();
    GetIt.instance.registerSingleton<AuthMfaService>(mfa);
    GetIt.instance.registerSingleton<AuthService>(auth);
    prod.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: const MfaSettingsView(),
      ),
    );
    await tester.pumpAndSettle();
  }

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
    expect(find.byIcon(ButleryIcons.trash2), findsOneWidget);

    await tester.tap(find.byIcon(ButleryIcons.trash2));
    await tester.pumpAndSettle();
    // The removal asks first; the way off is intact.
    expect(find.text('Ta bort MFA?'), findsOneWidget);
    expect(find.byKey(const ValueKey('mfa.turnOn')), findsNothing);
  });

  testWidgets('without two-step verification, the form offers to turn it on '
      'with one saffron action', (tester) async {
    when(() => mfa.hasMfaEnabled()).thenAnswer((_) async => false);
    when(() => mfa.getEnrolledFactors()).thenAnswer((_) async => []);

    await pump(tester);

    expect(find.text('MFA inaktiverat'), findsOneWidget);
    expect(find.text('Aktivera MFA för extra säkerhet.'), findsOneWidget);
    expect(find.text('Slå på tvåstegsverifiering'), findsOneWidget);
    expect(find.byKey(const ValueKey('mfa.turnOn')), findsOneWidget);
    expect(find.byType(HeroButton), findsOneWidget);
  });

  final codes = List.generate(10, (i) => 'ABCDE-FGH${i}K');

  void stubNoMfa() {
    when(() => mfa.hasMfaEnabled()).thenAnswer((_) async => false);
    when(() => mfa.getEnrolledFactors()).thenAnswer((_) async => []);
    when(() => mfa.errorMessage).thenReturn(null);
    when(() => mfa.discardBackupCodes()).thenAnswer((_) async {});
    when(
      () => auth.reauthenticateWithPassword(any()),
    ).thenAnswer((_) async => true);
    when(() => mfa.generateBackupCodes()).thenAnswer((_) async => codes);
  }

  Future<void> tapTurnOn(WidgetTester tester) async {
    final turnOn = find.byKey(const ValueKey('mfa.turnOn'));
    await tester.ensureVisible(turnOn);
    await tester.tap(turnOn);
    await tester.pumpAndSettle();
  }

  Future<void> confirmPassword(WidgetTester tester) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'hemligt123',
    );
    await tester.tap(find.text('Bekräfta'));
    await tester.pumpAndSettle();
  }

  Future<void> acknowledgeCodes(WidgetTester tester) async {
    final saved = find.byKey(const ValueKey('mfa.backupCodes.saved'));
    await tester.ensureVisible(saved);
    await tester.tap(saved);
    await tester.pump();
    final go = find.byKey(const ValueKey('mfa.backupCodes.continue'));
    await tester.ensureVisible(go);
    await tester.tap(go);
    await tester.pump(const Duration(milliseconds: 400));
  }

  const secretKey = 'ABCDEFGHIJKLMNOP';
  const setup = MfaTotpSetup(
    secret: 'secret',
    secretKey: secretKey,
    otpauthUrl: 'otpauth://totp/Butlery:anna?secret=ABCDEFGHIJKLMNOP',
  );

  void stubStartEnrollment([MfaTotpSetup? result = setup]) {
    when(() => mfa.startMfaEnrollment()).thenAnswer((_) async => result);
  }

  /// Gets to the step where the key is shown.
  Future<void> reachKeyStep(WidgetTester tester) async {
    await pump(tester);
    await tapTurnOn(tester);
    await confirmPassword(tester);
    await acknowledgeCodes(tester);
    await tester.pumpAndSettle();
  }

  Future<void> enterCodeAndConfirm(WidgetTester tester, String code) async {
    await tester.enterText(find.byKey(const ValueKey('mfa.codeField')), code);
    final confirm = find.byKey(const ValueKey('mfa.confirm'));
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
  }

  group('enabling two-step verification', () {
    testWidgets(
      'codes are made and acknowledged before the authenticator key is made',
      (tester) async {
        stubNoMfa();
        stubStartEnrollment();
        final order = <String>[];
        when(() => auth.reauthenticateWithPassword(any())).thenAnswer((
          _,
        ) async {
          order.add('reauth');
          return true;
        });
        when(() => mfa.generateBackupCodes()).thenAnswer((_) async {
          order.add('generate');
          return codes;
        });
        when(() => mfa.startMfaEnrollment()).thenAnswer((_) async {
          order.add('start');
          return setup;
        });
        await pump(tester);

        await tapTurnOn(tester);
        expect(order, isEmpty, reason: 'the password comes first');
        await confirmPassword(tester);
        expect(order, ['reauth', 'generate']);
        expect(find.byKey(const ValueKey('mfa.backupCodes')), findsOneWidget);

        await acknowledgeCodes(tester);
        await tester.pumpAndSettle();
        expect(order, ['reauth', 'generate', 'start']);
        expect(
          find.text(MfaTotpSetupForm.groupKey(secretKey)),
          findsOneWidget,
        );
        expect(find.text('ABCD EFGH IJKL MNOP'), findsOneWidget);
        verifyNever(() => mfa.discardBackupCodes());
      },
    );

    testWidgets('a refused re-authentication makes no codes and no key', (
      tester,
    ) async {
      stubNoMfa();
      when(
        () => auth.reauthenticateWithPassword(any()),
      ).thenAnswer((_) async => false);
      when(() => auth.errorMessage).thenReturn(null);
      await pump(tester);

      await tapTurnOn(tester);
      await confirmPassword(tester);

      verifyNever(() => mfa.generateBackupCodes());
      verifyNever(() => mfa.startMfaEnrollment());
    });

    testWidgets('cancelling the codes enrolls nothing and discards them', (
      tester,
    ) async {
      stubNoMfa();
      await pump(tester);

      await tapTurnOn(tester);
      await confirmPassword(tester);
      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();

      verify(() => mfa.discardBackupCodes()).called(1);
      verifyNever(() => mfa.startMfaEnrollment());
    });

    testWidgets('a key that could not be made discards the codes and shows '
        'the error', (tester) async {
      stubNoMfa();
      stubStartEnrollment(null);
      when(() => mfa.errorMessage).thenReturn('Nyckeln kunde inte göras');
      await pump(tester);

      await tapTurnOn(tester);
      await confirmPassword(tester);
      await acknowledgeCodes(tester);
      await tester.pumpAndSettle();

      verify(() => mfa.discardBackupCodes()).called(1);
      expect(find.text('Nyckeln kunde inte göras'), findsOneWidget);
      expect(find.byKey(const ValueKey('mfa.secretKey')), findsNothing);
    });

    testWidgets('six digits and Bekräfta enroll with that code', (
      tester,
    ) async {
      stubNoMfa();
      stubStartEnrollment();
      when(
        () => mfa.completeMfaEnrollment(any(), any()),
      ).thenAnswer((_) async => true);
      await reachKeyStep(tester);

      await enterCodeAndConfirm(tester, '123456');

      verify(() => mfa.completeMfaEnrollment(setup, '123456')).called(1);
    });

    testWidgets('Öppna i autentiseringsapp hands over the key, and a refusal '
        'says so', (tester) async {
      stubNoMfa();
      stubStartEnrollment();
      when(
        () => mfa.openInAuthenticatorApp(any()),
      ).thenAnswer((_) async => false);
      await reachKeyStep(tester);

      final open = find.byKey(const ValueKey('mfa.openApp'));
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();

      verify(() => mfa.openInAuthenticatorApp(setup)).called(1);
      expect(
        find.text(
          'Ingen autentiseringsapp öppnades. Installera en, eller skriv in nyckeln för hand.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a wrong code keeps the codes so a retry still has them, '
        'and leaving the code step discards them', (tester) async {
      stubNoMfa();
      stubStartEnrollment();
      when(
        () => mfa.completeMfaEnrollment(any(), any()),
      ).thenAnswer((_) async => false);
      await reachKeyStep(tester);

      await enterCodeAndConfirm(tester, '123456');
      verifyNever(() => mfa.discardBackupCodes());

      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();
      verify(() => mfa.discardBackupCodes()).called(1);
    });

    testWidgets('cancelling the code step clears an old error message', (
      tester,
    ) async {
      stubNoMfa();
      stubStartEnrollment();
      when(
        () => mfa.completeMfaEnrollment(any(), any()),
      ).thenAnswer((_) async => false);
      when(() => mfa.errorMessage).thenReturn('Fel kod från servern');
      await reachKeyStep(tester);
      await enterCodeAndConfirm(tester, '123456');
      expect(find.text('Fel kod från servern'), findsOneWidget);

      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();
      expect(find.text('Fel kod från servern'), findsNothing);
    });

    testWidgets('leaving the screen on the code step discards the codes', (
      tester,
    ) async {
      stubNoMfa();
      stubStartEnrollment();
      await reachKeyStep(tester);
      verifyNever(() => mfa.discardBackupCodes());

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      verify(() => mfa.discardBackupCodes()).called(1);
    });

    testWidgets('leaving the screen while the code is being verified keeps '
        'the codes', (tester) async {
      stubNoMfa();
      stubStartEnrollment();
      final pending = Completer<bool>();
      when(
        () => mfa.completeMfaEnrollment(any(), any()),
      ).thenAnswer((_) => pending.future);
      await reachKeyStep(tester);
      await tester.enterText(
        find.byKey(const ValueKey('mfa.codeField')),
        '123456',
      );
      final confirm = find.byKey(const ValueKey('mfa.confirm'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pump();
      verify(() => mfa.completeMfaEnrollment(any(), any())).called(1);

      await tester.pumpWidget(const SizedBox());
      verifyNever(() => mfa.discardBackupCodes());
      pending.complete(true);
      await tester.pumpAndSettle();
      verifyNever(() => mfa.discardBackupCodes());
    });

    testWidgets('Avbryt is off while the code is being verified, so the codes '
        'stay', (tester) async {
      stubNoMfa();
      stubStartEnrollment();
      final pending = Completer<bool>();
      when(
        () => mfa.completeMfaEnrollment(any(), any()),
      ).thenAnswer((_) => pending.future);
      await reachKeyStep(tester);
      await tester.enterText(
        find.byKey(const ValueKey('mfa.codeField')),
        '123456',
      );
      final confirm = find.byKey(const ValueKey('mfa.confirm'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pump();

      final cancel = find.text('Avbryt');
      await tester.ensureVisible(cancel);
      await tester.tap(cancel, warnIfMissed: false);
      await tester.pump();
      verifyNever(() => mfa.discardBackupCodes());
      expect(find.byKey(const ValueKey('mfa.secretKey')), findsOneWidget);

      pending.complete(false);
      await tester.pumpAndSettle();
    });

    testWidgets('the key is copied as typed into an app, and wiped after a '
        'minute', (tester) async {
      final writes = <String?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            writes.add((call.arguments as Map)['text'] as String?);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      stubNoMfa();
      stubStartEnrollment();
      await reachKeyStep(tester);

      final copy = find.byKey(const ValueKey('mfa.copyKey'));
      await tester.ensureVisible(copy);
      await tester.tap(copy);
      await tester.pump();
      // The raw key, not the grouped display or the otpauth address.
      expect(writes, [secretKey]);
      expect(
        find.text('Nyckeln är kopierad. Urklippet töms om en minut.'),
        findsOneWidget,
      );

      await tester.pump(mfaBackupCodesClipboardLifetime);
      expect(writes, [secretKey, '']);
      await tester.pumpAndSettle();
    });

    testWidgets('leaving the screen after a successful enrollment keeps the '
        'codes', (tester) async {
      stubNoMfa();
      stubStartEnrollment();
      when(
        () => mfa.completeMfaEnrollment(any(), any()),
      ).thenAnswer((_) async => true);
      await reachKeyStep(tester);
      await enterCodeAndConfirm(tester, '123456');

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      verifyNever(() => mfa.discardBackupCodes());
    });
  });

  group('the enrolled date', () {
    testWidgets('enrollmentTimestamp is read as seconds since epoch', (
      tester,
    ) async {
      when(() => mfa.hasMfaEnabled()).thenAnswer((_) async => true);
      when(() => mfa.getEnrolledFactors()).thenAnswer(
        (_) async => [
          const MfaFactorInfo(
            factor: 'f',
            displayName: 'Min telefon',
            enrollmentTimestamp: 1759320000,
          ),
        ],
      );
      await pump(tester);
      final d = DateTime.fromMillisecondsSinceEpoch(1759320000 * 1000);
      final expected =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      expect(find.text('Registrerad: $expected'), findsOneWidget);
    });
  });
}
