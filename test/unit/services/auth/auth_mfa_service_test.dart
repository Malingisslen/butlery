/// Unit tests for AuthMfaService (authenticator-app MFA).
///
/// Intent: prove user-visible MFA behaviour — the key is made for the
/// signed-in account, enrollment and sign-in hand the typed code to Firebase,
/// and failures reach the user as the right text. Firebase's static TOTP
/// calls are replaced through the MfaTotpGateway seam.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/auth/mfa_types.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/auth/auth_mfa_service.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockUser extends Mock implements User {}

class _MockMultiFactor extends Mock implements MultiFactor {}

class _MockMultiFactorResolver extends Mock implements MultiFactorResolver {}

class _MockTotpGateway extends Mock implements MfaTotpGateway {}

class _MockTotpSecret extends Mock implements TotpSecret {}

class _MockAssertion extends Mock implements MultiFactorAssertion {}

class _FakeMultiFactorAssertion extends Fake implements MultiFactorAssertion {}

class _FakeTotpSecret extends Fake implements TotpSecret {}

PhoneMultiFactorInfo _phoneHint() => PhoneMultiFactorInfo(
  displayName: null,
  enrollmentTimestamp: 0,
  factorId: 'phone',
  uid: 'phone-uid',
  phoneNumber: '+46701234567',
);

TotpMultiFactorInfo _totpHint({String uid = 'totp-uid'}) =>
    TotpMultiFactorInfo(enrollmentTimestamp: 0, factorId: 'totp', uid: uid);

MfaResolverInfo _resolverInfo(_MockMultiFactorResolver resolver) =>
    MfaResolverInfo(resolver: resolver);

void main() {
  late _MockAuthRepository mockRepo;
  late _MockAnalyticsService mockAnalytics;
  late _MockTotpGateway gateway;
  late AuthMfaService sut;
  late _MockUser mockUser;
  late _MockMultiFactor mockMultiFactor;

  setUpAll(() {
    registerFallbackValue(MultiFactorSession('fallback-session'));
    registerFallbackValue(_FakeMultiFactorAssertion());
    registerFallbackValue(_FakeTotpSecret());
  });

  setUp(() {
    mockRepo = _MockAuthRepository();
    mockAnalytics = _MockAnalyticsService();
    gateway = _MockTotpGateway();
    mockUser = _MockUser();
    mockMultiFactor = _MockMultiFactor();

    when(
      () => mockAnalytics.logLogin(method: any(named: 'method')),
    ).thenAnswer((_) async {});
    when(
      () => mockAnalytics.logEvent(
        name: any(named: 'name'),
        parameters: any(named: 'parameters'),
      ),
    ).thenAnswer((_) async {});

    when(() => mockRepo.currentUser).thenReturn(mockUser);
    when(() => mockUser.multiFactor).thenReturn(mockMultiFactor);
    when(() => mockUser.email).thenReturn('anna@example.com');

    sut = AuthMfaService(
      analyticsService: mockAnalytics,
      authRepository: mockRepo,
      totp: gateway,
    );
  });

  tearDown(() {
    sut.dispose();
    resetMocktailState();
  });

  group('hasMfaEnabled / getEnrolledFactors', () {
    test('hasMfaEnabled is true when factors are enrolled', () async {
      when(
        () => mockMultiFactor.getEnrolledFactors(),
      ).thenAnswer((_) async => [_phoneHint()]);
      expect(await sut.hasMfaEnabled(), isTrue);
    });

    test('hasMfaEnabled is false when none enrolled', () async {
      when(
        () => mockMultiFactor.getEnrolledFactors(),
      ).thenAnswer((_) async => <MultiFactorInfo>[]);
      expect(await sut.hasMfaEnabled(), isFalse);
    });

    test('hasMfaEnabled is false when no user is signed in', () async {
      when(() => mockRepo.currentUser).thenReturn(null);
      expect(await sut.hasMfaEnabled(), isFalse);
    });

    test('hasMfaEnabled is false when the lookup throws', () async {
      when(
        () => mockMultiFactor.getEnrolledFactors(),
      ).thenThrow(Exception('network'));
      expect(await sut.hasMfaEnabled(), isFalse);
    });

    test('getEnrolledFactors maps SDK factors to MfaFactorInfo', () async {
      final hint = _phoneHint();
      when(
        () => mockMultiFactor.getEnrolledFactors(),
      ).thenAnswer((_) async => [hint]);
      final factors = await sut.getEnrolledFactors();
      expect(factors, hasLength(1));
      expect(factors.first.displayName, hint.displayName);
    });

    test('getEnrolledFactors returns [] when no user is signed in', () async {
      when(() => mockRepo.currentUser).thenReturn(null);
      expect(await sut.getEnrolledFactors(), isEmpty);
    });

    test('getEnrolledFactors returns [] when the lookup throws', () async {
      when(
        () => mockMultiFactor.getEnrolledFactors(),
      ).thenThrow(Exception('network'));
      expect(await sut.getEnrolledFactors(), isEmpty);
    });
  });

  group('startMfaEnrollment', () {
    late _MockTotpSecret secret;

    setUp(() {
      secret = _MockTotpSecret();
      when(() => secret.secretKey).thenReturn('ABCDEFGHIJKLMNOP');
      when(
        () => mockMultiFactor.getSession(),
      ).thenAnswer((_) async => MultiFactorSession('s'));
      when(() => gateway.generateSecret(any())).thenAnswer((_) async => secret);
      when(
        () => gateway.qrCodeUrl(any(), accountName: any(named: 'accountName')),
      ).thenAnswer((_) async => 'otpauth://totp/Butlery:anna?secret=X');
    });

    test(
      'returns the key and address the app needs, for this account',
      () async {
        final setup = await sut.startMfaEnrollment();

        expect(setup?.secretKey, 'ABCDEFGHIJKLMNOP');
        expect(setup?.otpauthUrl, 'otpauth://totp/Butlery:anna?secret=X');
        expect(setup?.unwrap<TotpSecret>(), same(secret));
        verify(
          () => gateway.qrCodeUrl(secret, accountName: 'anna@example.com'),
        ).called(1);
      },
    );

    test('returns null when nobody is signed in', () async {
      when(() => mockRepo.currentUser).thenReturn(null);

      expect(await sut.startMfaEnrollment(), isNull);
      expect(sut.errorMessage, AppLocale.current.mfaSetupFailed);
      verifyNever(() => gateway.generateSecret(any()));
    });

    test('returns null and explains a refused request', () async {
      when(
        () => gateway.generateSecret(any()),
      ).thenThrow(FirebaseAuthException(code: 'requires-recent-login'));

      expect(await sut.startMfaEnrollment(), isNull);
      expect(sut.errorMessage, AppLocale.current.mfaErrorRequiresRecentLogin);
    });

    test('returns null, not a throw, when the key cannot be made', () async {
      // A throw would skip the view's discard of the codes just made.
      when(() => gateway.generateSecret(any())).thenThrow(StateError('x'));

      expect(await sut.startMfaEnrollment(), isNull);
      expect(sut.errorMessage, AppLocale.current.mfaSetupFailed);
    });
  });

  group('openInAuthenticatorApp', () {
    MfaTotpSetup setup(TotpSecret secret) => MfaTotpSetup(
      secret: secret,
      secretKey: 'KEY',
      otpauthUrl: 'otpauth://totp/x',
    );

    test('hands the address to the app and reports success', () async {
      final secret = _MockTotpSecret();
      when(
        () => gateway.openInOtpApp(any(), any()),
      ).thenAnswer((_) async {});

      expect(await sut.openInAuthenticatorApp(setup(secret)), isTrue);
      verify(
        () => gateway.openInOtpApp(secret, 'otpauth://totp/x'),
      ).called(1);
    });

    test('is false when no app took it, so the user types the key', () async {
      when(
        () => gateway.openInOtpApp(any(), any()),
      ).thenThrow(Exception('no app'));

      expect(
        await sut.openInAuthenticatorApp(setup(_MockTotpSecret())),
        isFalse,
      );
    });
  });

  group('completeMfaEnrollment', () {
    late _MockTotpSecret secret;
    late MfaTotpSetup setup;

    setUp(() {
      secret = _MockTotpSecret();
      setup = MfaTotpSetup(
        secret: secret,
        secretKey: 'KEY',
        otpauthUrl: 'otpauth://totp/x',
      );
    });

    test('enrolls the assertion for the typed code and logs totp', () async {
      final assertion = _MockAssertion();
      when(
        () => gateway.enrollmentAssertion(any(), any()),
      ).thenAnswer((_) async => assertion);
      when(
        () => mockMultiFactor.enroll(
          any(),
          displayName: any(named: 'displayName'),
        ),
      ).thenAnswer((_) async {});

      expect(await sut.completeMfaEnrollment(setup, '123456'), isTrue);

      verify(() => gateway.enrollmentAssertion(secret, '123456')).called(1);
      verify(
        () => mockMultiFactor.enroll(
          assertion,
          displayName: AppLocale.current.mfaAppTitle,
        ),
      ).called(1);
      verify(
        () => mockAnalytics.logEvent(
          name: AnalyticsEvents.mfaEnrolled,
          parameters: {'method': 'totp'},
        ),
      ).called(1);
    });

    test('returns false when no user is signed in', () async {
      when(() => mockRepo.currentUser).thenReturn(null);

      expect(await sut.completeMfaEnrollment(setup, '123456'), isFalse);
      verifyNever(() => gateway.enrollmentAssertion(any(), any()));
    });

    test('a wrong code says the code was wrong and enrolls nothing', () async {
      when(
        () => gateway.enrollmentAssertion(any(), any()),
      ).thenAnswer((_) async => _MockAssertion());
      when(
        () => mockMultiFactor.enroll(
          any(),
          displayName: any(named: 'displayName'),
        ),
      ).thenThrow(FirebaseAuthException(code: 'invalid-verification-code'));

      expect(await sut.completeMfaEnrollment(setup, '000000'), isFalse);
      expect(sut.errorMessage, AppLocale.current.mfaInvalidCode);
      verifyNever(
        () => mockAnalytics.logEvent(
          name: AnalyticsEvents.mfaEnrolled,
          parameters: any(named: 'parameters'),
        ),
      );
    });

    test('an unverified email gets its own explanation', () async {
      when(
        () => gateway.enrollmentAssertion(any(), any()),
      ).thenAnswer((_) async => _MockAssertion());
      when(
        () => mockMultiFactor.enroll(
          any(),
          displayName: any(named: 'displayName'),
        ),
      ).thenThrow(FirebaseAuthException(code: 'unverified-email'));

      expect(await sut.completeMfaEnrollment(setup, '123456'), isFalse);
      expect(sut.errorMessage, AppLocale.current.mfaErrorUnverifiedEmail);
    });
  });

  // -------------------------------------------------------------------------
  // Criterion 2 — unenrollMfa
  // -------------------------------------------------------------------------

  group('unenrollMfa', () {
    test('calls user.multiFactor.unenroll and returns true', () async {
      // Proves the happy-path contract: given a signed-in user and a valid
      // MfaFactorInfo, unenrollMfa delegates to Firebase and returns true.
      // Would fail if unenroll is never called or if the return were false.
      when(
        () => mockMultiFactor.unenroll(
          multiFactorInfo: any(named: 'multiFactorInfo'),
        ),
      ).thenAnswer((_) async {});

      final factor = MfaFactorInfo(
        factor: _totpHint(), // any MultiFactorInfo subtype works here
        displayName: 'Test factor',
        enrollmentTimestamp: 0,
      );

      final result = await sut.unenrollMfa(factor);

      expect(result, isTrue);
      verify(
        () => mockMultiFactor.unenroll(
          multiFactorInfo: any(named: 'multiFactorInfo'),
        ),
      ).called(1);
    });

    test('returns false when no user is signed in', () async {
      // Proves the null-user guard: unenroll must not attempt Firebase calls
      // when the user is not authenticated.
      when(() => mockRepo.currentUser).thenReturn(null);

      final factor = MfaFactorInfo(
        factor: _totpHint(),
        displayName: null,
        enrollmentTimestamp: 0,
      );

      final result = await sut.unenrollMfa(factor);

      expect(
        result,
        isFalse,
        reason: 'unenroll without a signed-in user must return false',
      );
      verifyNever(
        () => mockMultiFactor.unenroll(
          multiFactorInfo: any(named: 'multiFactorInfo'),
        ),
      );
    });
  });

  group('completeMfaSignIn', () {
    late _MockMultiFactorResolver resolver;

    setUp(() {
      resolver = _MockMultiFactorResolver();
    });

    test(
      'resolves with the assertion made from the app factor and code',
      () async {
        final assertion = _MockAssertion();
        when(() => resolver.hints).thenReturn([_phoneHint(), _totpHint()]);
        when(
          () => gateway.signInAssertion(any(), any()),
        ).thenAnswer((_) async => assertion);
        when(
          () => resolver.resolveSignIn(any()),
        ).thenAnswer((_) async => FakeUserCredential());

        expect(
          await sut.completeMfaSignIn(_resolverInfo(resolver), '654321'),
          isTrue,
        );

        verify(() => gateway.signInAssertion('totp-uid', '654321')).called(1);
        verify(() => resolver.resolveSignIn(assertion)).called(1);
        verify(() => mockAnalytics.logLogin(method: 'email_mfa')).called(1);
      },
    );

    test(
      'without an authenticator-app factor it fails and resolves nothing',
      () async {
        when(() => resolver.hints).thenReturn([_phoneHint()]);

        expect(
          await sut.completeMfaSignIn(_resolverInfo(resolver), '654321'),
          isFalse,
        );
        expect(sut.errorMessage, AppLocale.current.mfaChallengeFailed);
        verifyNever(() => resolver.resolveSignIn(any()));
      },
    );

    test('a wrong code says so in the authenticator-app wording', () async {
      when(() => resolver.hints).thenReturn([_totpHint()]);
      when(
        () => gateway.signInAssertion(any(), any()),
      ).thenAnswer((_) async => _MockAssertion());
      when(
        () => resolver.resolveSignIn(any()),
      ).thenThrow(FirebaseAuthException(code: 'invalid-verification-code'));

      expect(
        await sut.completeMfaSignIn(_resolverInfo(resolver), '000000'),
        isFalse,
      );
      expect(sut.errorMessage, AppLocale.current.mfaChallengeWrongCode);
    });
  });
}

/// Minimal UserCredential fake needed for completeMfaSignIn stubs.
class FakeUserCredential extends Fake implements UserCredential {
  @override
  User? get user => null;
}
