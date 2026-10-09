import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/models/auth/mfa_types.dart';
import 'package:butlery/services/auth/auth_mfa_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/views/settings/mfa_settings_view.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockAuthMfaService extends Mock implements AuthMfaService {}

class _FakeFactor extends Fake implements MfaFactorInfo {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  late _MockAuthMfaService mfa;
  late _MockAuthService auth;

  setUpAll(() => registerFallbackValue(_FakeFactor()));

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
    expect(find.text('Skicka kod'), findsNothing);
  });

  testWidgets('without two-step verification, the form offers to turn it on '
      'with Skicka kod as its saffron action', (tester) async {
    when(() => mfa.hasMfaEnabled()).thenAnswer((_) async => false);
    when(() => mfa.getEnrolledFactors()).thenAnswer((_) async => []);

    await pump(tester);

    expect(find.text('MFA inaktiverat'), findsOneWidget);
    expect(find.text('Aktivera MFA för extra säkerhet.'), findsOneWidget);
    expect(find.text('Skicka kod'), findsOneWidget);
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

  Future<void> typeNumberAndSend(
    WidgetTester tester,
    String number, {
    String? countryCode,
  }) async {
    if (countryCode != null) {
      await tester.enterText(
        find.byKey(const ValueKey('mfa.countryCode')),
        countryCode,
      );
    }
    await tester.enterText(
      find.byKey(const ValueKey('mfa.phoneNumber')),
      number,
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Skicka kod'));
    await tester.tap(find.text('Skicka kod'));
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

  void stubStartEnrollment(void Function(Invocation inv) onCall) {
    when(
      () => mfa.startMfaEnrollment(
        any(),
        onCodeSent: any(named: 'onCodeSent'),
        onError: any(named: 'onError'),
        onAutoVerified: any(named: 'onAutoVerified'),
      ),
    ).thenAnswer((inv) async => onCall(inv));
  }

  group('enabling two-step verification', () {
    testWidgets('codes are made and acknowledged before the number is sent, '
        'and 070 123 45 67 goes out as +46701234567', (tester) async {
      stubNoMfa();
      final order = <String>[];
      when(() => auth.reauthenticateWithPassword(any())).thenAnswer((_) async {
        order.add('reauth');
        return true;
      });
      when(() => mfa.generateBackupCodes()).thenAnswer((_) async {
        order.add('generate');
        return codes;
      });
      String? sentTo;
      stubStartEnrollment((inv) {
        order.add('enroll');
        sentTo = inv.positionalArguments.first as String;
      });
      await pump(tester);

      await typeNumberAndSend(tester, '070 123 45 67');
      expect(find.text('Koden skickas till +46 70 123 45 67'), findsOneWidget);
      expect(order, isEmpty, reason: 'the password comes first');
      await confirmPassword(tester);
      expect(order, ['reauth', 'generate']);
      expect(find.byKey(const ValueKey('mfa.backupCodes')), findsOneWidget);

      await acknowledgeCodes(tester);
      expect(order, ['reauth', 'generate', 'enroll']);
      expect(sentTo, '+46701234567');
      verifyNever(() => mfa.discardBackupCodes());
    });

    testWidgets('cancelling the codes enrolls nothing and discards them', (
      tester,
    ) async {
      stubNoMfa();
      await pump(tester);

      await typeNumberAndSend(tester, '070 123 45 67');
      await confirmPassword(tester);
      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();

      verify(() => mfa.discardBackupCodes()).called(1);
      verifyNever(
        () => mfa.startMfaEnrollment(
          any(),
          onCodeSent: any(named: 'onCodeSent'),
          onError: any(named: 'onError'),
          onAutoVerified: any(named: 'onAutoVerified'),
        ),
      );
    });

    testWidgets('a failed start discards the codes and shows the error', (
      tester,
    ) async {
      stubNoMfa();
      stubStartEnrollment((inv) {
        (inv.namedArguments[#onError] as void Function(MfaError))(
          const MfaError(code: 'quota-exceeded'),
        );
      });
      await pump(tester);

      await typeNumberAndSend(tester, '0701234567');
      await confirmPassword(tester);
      await acknowledgeCodes(tester);

      verify(() => mfa.discardBackupCodes()).called(1);
      expect(
        find.text('För många försök. Försök igen senare.'),
        findsOneWidget,
      );
    });

    testWidgets('a wrong SMS code keeps the codes so a retry still has them, '
        'and leaving the code step discards them', (tester) async {
      stubNoMfa();
      stubStartEnrollment((inv) {
        (inv.namedArguments[#onCodeSent] as void Function(String))('vid-1');
      });
      when(
        () => mfa.completeMfaEnrollment(any(), any()),
      ).thenAnswer((_) async => false);
      await pump(tester);

      await typeNumberAndSend(tester, '0701234567');
      await confirmPassword(tester);
      await acknowledgeCodes(tester);
      expect(
        find.text('En verifieringskod har skickats till +46 70 123 45 67.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('mfa.codeField')),
        '123456',
      );
      await tester.tap(find.text('Verifiera'));
      await tester.pumpAndSettle();
      verifyNever(() => mfa.discardBackupCodes());

      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();
      verify(() => mfa.discardBackupCodes()).called(1);
    });

    testWidgets('an error after the code was sent returns to the phone step '
        'with the codes discarded', (tester) async {
      stubNoMfa();
      stubStartEnrollment((inv) {
        (inv.namedArguments[#onCodeSent] as void Function(String))('vid-1');
        (inv.namedArguments[#onError] as void Function(MfaError))(
          const MfaError(code: 'quota-exceeded'),
        );
      });
      await pump(tester);

      await typeNumberAndSend(tester, '0701234567');
      await confirmPassword(tester);
      await acknowledgeCodes(tester);

      expect(find.byKey(const ValueKey('mfa.codeField')), findsNothing);
      expect(find.byKey(const ValueKey('mfa.phoneNumber')), findsOneWidget);
      verify(() => mfa.discardBackupCodes()).called(1);
    });

    testWidgets('cancelling the code step clears an old error message', (
      tester,
    ) async {
      stubNoMfa();
      stubStartEnrollment((inv) {
        (inv.namedArguments[#onCodeSent] as void Function(String))('vid-1');
      });
      when(
        () => mfa.completeMfaEnrollment(any(), any()),
      ).thenAnswer((_) async => false);
      when(() => mfa.errorMessage).thenReturn('Fel kod från servern');
      await pump(tester);
      await typeNumberAndSend(tester, '0701234567');
      await confirmPassword(tester);
      await acknowledgeCodes(tester);
      await tester.enterText(
        find.byKey(const ValueKey('mfa.codeField')),
        '123456',
      );
      await tester.tap(find.text('Verifiera'));
      await tester.pumpAndSettle();
      expect(find.text('Fel kod från servern'), findsOneWidget);

      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();
      expect(find.text('Fel kod från servern'), findsNothing);
    });

    testWidgets('leaving the screen on the code step discards the codes', (
      tester,
    ) async {
      stubNoMfa();
      stubStartEnrollment((inv) {
        (inv.namedArguments[#onCodeSent] as void Function(String))('vid-1');
      });
      await pump(tester);
      await typeNumberAndSend(tester, '0701234567');
      await confirmPassword(tester);
      await acknowledgeCodes(tester);
      verifyNever(() => mfa.discardBackupCodes());

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      verify(() => mfa.discardBackupCodes()).called(1);
    });

    testWidgets('leaving the screen while the code is being verified keeps '
        'the codes', (tester) async {
      stubNoMfa();
      stubStartEnrollment((inv) {
        (inv.namedArguments[#onCodeSent] as void Function(String))('vid-1');
      });
      final pending = Completer<bool>();
      when(
        () => mfa.completeMfaEnrollment(any(), any()),
      ).thenAnswer((_) => pending.future);
      await pump(tester);
      await typeNumberAndSend(tester, '0701234567');
      await confirmPassword(tester);
      await acknowledgeCodes(tester);
      await tester.enterText(
        find.byKey(const ValueKey('mfa.codeField')),
        '123456',
      );
      await tester.tap(find.text('Verifiera'));
      await tester.pump();
      verify(() => mfa.completeMfaEnrollment(any(), any())).called(1);

      await tester.pumpWidget(const SizedBox());
      verifyNever(() => mfa.discardBackupCodes());
      pending.complete(true);
      await tester.pumpAndSettle();
      verifyNever(() => mfa.discardBackupCodes());
    });

    testWidgets('leaving the screen after a successful enrollment keeps the '
        'codes', (tester) async {
      stubNoMfa();
      stubStartEnrollment((inv) {
        (inv.namedArguments[#onCodeSent] as void Function(String))('vid-1');
      });
      when(
        () => mfa.completeMfaEnrollment(any(), any()),
      ).thenAnswer((_) async => true);
      await pump(tester);
      await typeNumberAndSend(tester, '0701234567');
      await confirmPassword(tester);
      await acknowledgeCodes(tester);
      await tester.enterText(
        find.byKey(const ValueKey('mfa.codeField')),
        '123456',
      );
      await tester.tap(find.text('Verifiera'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      verifyNever(() => mfa.discardBackupCodes());
    });

    testWidgets('automatic verification mid-entry shows no error and MFA on', (
      tester,
    ) async {
      stubNoMfa();
      var enrolled = false;
      when(() => mfa.hasMfaEnabled()).thenAnswer((_) async => enrolled);
      when(() => mfa.getEnrolledFactors()).thenAnswer(
        (_) async => enrolled ? [const MfaFactorInfo(factor: 'f')] : [],
      );
      stubStartEnrollment((inv) {
        enrolled = true;
        (inv.namedArguments[#onAutoVerified] as void Function())();
      });
      await pump(tester);

      await typeNumberAndSend(tester, '0701234567');
      await confirmPassword(tester);
      await acknowledgeCodes(tester);

      expect(find.byIcon(ButleryIcons.triangleAlert), findsNothing);
      expect(find.text('MFA aktiverat'), findsOneWidget);
      verifyNever(() => mfa.discardBackupCodes());
    });

    for (final c in {
      'unverified-email': 'e-postadress inte är verifierad',
      'second-factor-already-in-use': 'redan används för tvåstegsverifiering',
      'requires-recent-login': 'din inloggning är för gammal',
    }.entries) {
      testWidgets('error code ${c.key} says what happened and what to do', (
        tester,
      ) async {
        stubNoMfa();
        stubStartEnrollment((inv) {
          (inv.namedArguments[#onError] as void Function(MfaError))(
            MfaError(code: c.key),
          );
        });
        await pump(tester);
        await typeNumberAndSend(tester, '0701234567');
        await confirmPassword(tester);
        await acknowledgeCodes(tester);

        expect(find.textContaining(c.value), findsOneWidget);
        expect(find.text('Något gick fel. Försök igen.'), findsNothing);
      });
    }

    testWidgets('an invalid country code blocks before re-authentication', (
      tester,
    ) async {
      stubNoMfa();
      await pump(tester);

      await typeNumberAndSend(tester, '0701234567', countryCode: '46');

      expect(find.textContaining('Landskoden ska börja med +'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(() => auth.reauthenticateWithPassword(any()));
      verifyNever(() => mfa.generateBackupCodes());
    });

    testWidgets('the country code is its own labelled field, prefilled +46', (
      tester,
    ) async {
      stubNoMfa();
      await pump(tester);

      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('mfa.countryCode')),
      );
      expect(field.controller!.text, '+46');
      expect(find.text('Landskod'), findsOneWidget);
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
      // Read as milliseconds the year would be 1970.
      expect(expected.startsWith('2025-'), isTrue);
      expect(find.text('Registrerad: $expected'), findsOneWidget);
    });
  });

  group('parseMfaPhone', () {
    String? e164(String cc, String n) =>
        parseMfaPhone(countryCode: cc, national: n).number?.e164;

    test('drops spaces, dashes and one leading zero', () {
      expect(e164('+46', '070 123 45 67'), '+46701234567');
      expect(e164('+46', '070-123 45 67'), '+46701234567');
      expect(e164('+46', '0070123'), '+46070123');
    });

    test('a number that starts with + is used as it is', () {
      expect(e164('+46', '+47 912 34 567'), '+4791234567');
      expect(e164('garbage', '+46 70 123 45 67'), '+46701234567');
    });

    test('a bare country code with no number is rejected', () {
      expect(
        parseMfaPhone(countryCode: '+46', national: '+46').problem,
        MfaPhoneProblem.number,
      );
      expect(
        parseMfaPhone(countryCode: '+46', national: '+4').problem,
        MfaPhoneProblem.number,
      );
    });

    test('exactly 15 digits are accepted and 16 are not', () {
      // +46 plus 13 national digits = 15; the 14th makes 16.
      expect(e164('+46', '1234567890123'), '+461234567890123');
      expect(
        parseMfaPhone(countryCode: '+46', national: '12345678901234').problem,
        MfaPhoneProblem.tooLong,
      );
    });

    test('formats the number grouped for the confirmation line', () {
      expect(
        parseMfaPhone(
          countryCode: '+46',
          national: '070 123 45 67',
        ).number!.display,
        '+46 70 123 45 67',
      );
    });

    test('rejects a bad country code, letters and an over-long number', () {
      expect(
        parseMfaPhone(countryCode: '46', national: '70123').problem,
        MfaPhoneProblem.countryCode,
      );
      expect(
        parseMfaPhone(countryCode: '+46567', national: '70123').problem,
        MfaPhoneProblem.countryCode,
      );
      expect(
        parseMfaPhone(countryCode: '+46', national: '70abc').problem,
        MfaPhoneProblem.number,
      );
      expect(
        parseMfaPhone(countryCode: '+46', national: '12345678901234').problem,
        MfaPhoneProblem.tooLong,
      );
      expect(
        parseMfaPhone(
          countryCode: '+46',
          national: '+1234567890123456',
        ).problem,
        MfaPhoneProblem.tooLong,
      );
    });
  });
}
