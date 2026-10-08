// P6-U09 — the MFA sign-in challenge and backup codes, service level
// (produktregler.md:745-749; Skarmar v12 etapp 3 #authmfa, etapp 6 #mfaaktiv).
//
// Before P6-U09 nothing caught Firebase's multi-factor exception, so an
// account with two-step verification could not sign in at all.

// ignore_for_file: invalid_use_of_protected_member

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/auth/mfa_types.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/auth/auth_mfa_service.dart';
import 'package:butlery/services/auth_service.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockResolver extends Mock implements MultiFactorResolver {}

class _MockMfaException extends Mock
    implements FirebaseAuthMultiFactorException {}

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<dynamic> {}

class _FakePhoneAuthCredential extends Fake implements PhoneAuthCredential {}

class _FakeMultiFactorAssertion extends Fake implements MultiFactorAssertion {}

class _FakeUserCredential extends Fake implements UserCredential {}

class _MockUser extends Mock implements User {}

class _MockMultiFactor extends Mock implements MultiFactor {}

class _FakeMultiFactorInfo extends Fake implements MultiFactorInfo {}

class _MockMapResult extends Mock
    implements HttpsCallableResult<Map<dynamic, dynamic>> {}

PhoneMultiFactorInfo _hint(String number) => PhoneMultiFactorInfo(
  displayName: null,
  enrollmentTimestamp: 0,
  factorId: 'phone',
  uid: 'hint',
  phoneNumber: number,
);

void main() {
  group('sign-in with two-step verification', () {
    late _MockAuthRepository repo;
    late MockAnalyticsService analytics;
    late AuthService auth;

    setUp(() async {
      await BaseUnitTest.setupUnit();
      repo = _MockAuthRepository();
      analytics = MockFactory.createAnalyticsService();
      when(
        () => analytics.logLogin(method: any(named: 'method')),
      ).thenAnswer((_) async {});
      when(() => repo.authStateChanges()).thenAnswer((_) => Stream.value(null));
      when(() => repo.currentUser).thenReturn(null);
      when(() => repo.currentUserId).thenReturn(null);
      auth = AuthService(authRepository: repo, analyticsService: analytics);
    });

    tearDown(() async {
      try {
        auth.dispose();
      } on FlutterError {
        // already disposed
      }
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    test(
      'the multi-factor exception becomes a challenge, not an error',
      () async {
        final resolver = _MockResolver();
        when(() => resolver.hints).thenReturn([_hint('+*******4547')]);
        final exception = _MockMfaException();
        when(() => exception.resolver).thenReturn(resolver);
        when(() => exception.code).thenReturn('multi-factor-auth-required');
        when(
          () => repo.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(exception);

        final ok = await auth.signInWithEmail(
          email: 'anna@example.com',
          password: 'hemligt123',
        );

        expect(ok, isFalse);
        expect(auth.errorMessage, isNull, reason: 'a second step is no error');
        expect(auth.pendingMfaChallenge, isNotNull);
        expect(auth.pendingMfaChallenge!.phoneHint, '+*******4547');
        expect(maskedPhoneTail(auth.pendingMfaChallenge!.phoneHint), '47');
      },
    );

    test('finishing the challenge signs the user in and clears it', () async {
      final resolver = _MockResolver();
      when(() => resolver.hints).thenReturn([_hint('+*******4547')]);
      final exception = _MockMfaException();
      when(() => exception.resolver).thenReturn(resolver);
      when(
        () => repo.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(exception);
      await auth.signInWithEmail(
        email: 'anna@example.com',
        password: 'x1234567',
      );

      final user = MockFactory.createMockUser(uid: 'anna');
      when(() => repo.currentUser).thenReturn(user);
      expect(await auth.finishMfaSignIn(), isTrue);
      expect(auth.pendingMfaChallenge, isNull);
      expect(auth.currentUser, user);
    });

    test(
      'finishing without a signed-in user fails and stays signed out',
      () async {
        expect(await auth.finishMfaSignIn(), isFalse);
        expect(auth.currentUser, isNull);
      },
    );
  });

  group('AuthMfaService', () {
    late _MockAuthRepository repo;
    late _MockAnalytics analytics;
    late _MockFunctions functions;
    late AuthMfaService mfa;

    setUpAll(() {
      registerFallbackValue(MultiFactorSession('fallback'));
      registerFallbackValue(Duration.zero);
      registerFallbackValue(_FakeMultiFactorAssertion());
      registerFallbackValue(HttpsCallableOptions());
      registerFallbackValue(_FakeMultiFactorInfo());
    });

    setUp(() {
      repo = _MockAuthRepository();
      analytics = _MockAnalytics();
      functions = _MockFunctions();
      when(
        () => analytics.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        ),
      ).thenAnswer((_) async {});
      mfa = AuthMfaService(
        analyticsService: analytics,
        authRepository: repo,
        functions: functions,
      );
    });

    test('automatic verification reports back so the view moves on', () async {
      final resolver = _MockResolver();
      when(() => resolver.hints).thenReturn([_hint('+*******4547')]);
      when(() => resolver.session).thenReturn(MultiFactorSession('s'));
      when(
        () => resolver.resolveSignIn(any()),
      ).thenAnswer((_) async => _FakeUserCredential());
      Duration? timeout;
      when(
        () => repo.verifyPhoneNumber(
          multiFactorSession: any(named: 'multiFactorSession'),
          multiFactorInfo: any(named: 'multiFactorInfo'),
          phoneNumber: any(named: 'phoneNumber'),
          verificationCompleted: any(named: 'verificationCompleted'),
          verificationFailed: any(named: 'verificationFailed'),
          codeSent: any(named: 'codeSent'),
          codeAutoRetrievalTimeout: any(named: 'codeAutoRetrievalTimeout'),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((invocation) async {
        timeout = invocation.namedArguments[#timeout] as Duration;
        final completed =
            invocation.namedArguments[#verificationCompleted]
                as Future<void> Function(PhoneAuthCredential);
        await completed(_FakePhoneAuthCredential());
      });

      var autoVerified = 0;
      MfaError? error;
      await mfa.startMfaSignIn(
        MfaResolverInfo(resolver: resolver),
        onCodeSent: (_) {},
        onError: (e) => error = e,
        onAutoVerified: () => autoVerified++,
      );

      expect(autoVerified, 1);
      expect(error, isNull);
      expect(timeout, const Duration(seconds: 60), reason: '60 s, as drawn');
      verify(() => resolver.resolveSignIn(any())).called(1);
    });

    test('ten backup codes are returned once from the callable', () async {
      final callable = _MockCallable();
      final result = _MockMapResult();
      final codes = List.generate(10, (i) => 'AAAAA-BBBB$i');
      when(
        () => functions.httpsCallable('generateMfaBackupCodes'),
      ).thenReturn(callable);
      when(
        () => callable.call<Map<dynamic, dynamic>>(),
      ).thenAnswer((_) async => result);
      when(() => result.data).thenReturn({'codes': codes});

      expect(await mfa.generateBackupCodes(), codes);
    });

    test('fewer than ten codes is a failure: enrollment must stop', () async {
      final callable = _MockCallable();
      final result = _MockMapResult();
      when(
        () => functions.httpsCallable('generateMfaBackupCodes'),
      ).thenReturn(callable);
      when(
        () => callable.call<Map<dynamic, dynamic>>(),
      ).thenAnswer((_) async => result);
      when(() => result.data).thenReturn({
        'codes': ['A'],
      });

      expect(await mfa.generateBackupCodes(), isNull);
    });

    group('switching two-step verification off', () {
      late _MockUser user;
      late _MockMultiFactor multiFactor;
      late _MockCallable clear;

      setUp(() {
        user = _MockUser();
        multiFactor = _MockMultiFactor();
        clear = _MockCallable();
        when(() => repo.currentUser).thenReturn(user);
        when(() => user.multiFactor).thenReturn(multiFactor);
        when(
          () => multiFactor.unenroll(
            multiFactorInfo: any(named: 'multiFactorInfo'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => functions.httpsCallable('clearMfaBackupCodes'),
        ).thenReturn(clear);
      });

      MfaFactorInfo factor() => MfaFactorInfo(
        factor: _hint('+*******4547'),
        displayName: null,
        enrollmentTimestamp: 0,
      );

      test(
        'deletes the backup codes on the server after unenrolling',
        () async {
          when(
            () => clear.call<dynamic>(),
          ).thenAnswer((_) async => _MockResult());

          expect(await mfa.unenrollMfa(factor()), isTrue);

          verifyInOrder([
            () => multiFactor.unenroll(
              multiFactorInfo: any(named: 'multiFactorInfo'),
            ),
            () => clear.call<dynamic>(),
          ]);
        },
      );

      test('a failed clean-up does not undo a done unenrollment', () async {
        when(() => clear.call<dynamic>()).thenThrow(
          FirebaseFunctionsException(message: 'x', code: 'unavailable'),
        );

        expect(await mfa.unenrollMfa(factor()), isTrue);
        verify(() => clear.call<dynamic>()).called(1);
      });

      test('a refused unenrollment never clears the codes', () async {
        when(
          () => multiFactor.unenroll(
            multiFactorInfo: any(named: 'multiFactorInfo'),
          ),
        ).thenThrow(FirebaseAuthException(code: 'requires-recent-login'));

        expect(await mfa.unenrollMfa(factor()), isFalse);
        verifyNever(() => functions.httpsCallable('clearMfaBackupCodes'));
      });
    });

    test('discardBackupCodes asks the server and swallows a failure', () async {
      final clear = _MockCallable();
      when(
        () => functions.httpsCallable('clearMfaBackupCodes'),
      ).thenReturn(clear);
      when(() => clear.call<dynamic>()).thenThrow(
        FirebaseFunctionsException(message: 'x', code: 'unavailable'),
      );

      await mfa.discardBackupCodes();

      verify(() => clear.call<dynamic>()).called(1);
    });

    test('without the callables there are no codes and no recovery', () async {
      final offline = AuthMfaService(
        analyticsService: analytics,
        authRepository: repo,
      );
      expect(await offline.generateBackupCodes(), isNull);
      expect(
        await offline.recoverWithBackupCode(
          email: 'a@b.se',
          password: 'x',
          code: 'y',
        ),
        MfaRecoveryOutcome.unavailable,
      );
    });

    group('recovery outcomes', () {
      Future<MfaRecoveryOutcome> recoverWith(Object error) async {
        final callable = _MockCallable();
        when(
          () => functions.httpsCallable(
            'recoverWithMfaBackupCode',
            options: any(named: 'options'),
          ),
        ).thenReturn(callable);
        when(() => callable.call<dynamic>(any())).thenThrow(error);
        return mfa.recoverWithBackupCode(
          email: 'anna@example.com',
          password: 'hemligt123',
          code: 'ABCDE-FGHJK',
        );
      }

      test('a right code recovers', () async {
        final callable = _MockCallable();
        when(
          () => functions.httpsCallable(
            'recoverWithMfaBackupCode',
            options: any(named: 'options'),
          ),
        ).thenReturn(callable);
        when(
          () => callable.call<dynamic>(any()),
        ).thenAnswer((_) async => _MockResult());
        expect(
          await mfa.recoverWithBackupCode(
            email: 'anna@example.com',
            password: 'hemligt123',
            code: 'ABCDE-FGHJK',
          ),
          MfaRecoveryOutcome.recovered,
        );
      });

      test('a wrong or used code is rejected', () async {
        expect(
          await recoverWith(
            FirebaseFunctionsException(
              message: 'x',
              code: 'permission-denied',
            ),
          ),
          MfaRecoveryOutcome.rejected,
        );
      });

      test('the lock after five failures is its own outcome', () async {
        expect(
          await recoverWith(
            FirebaseFunctionsException(
              message: 'x',
              code: 'resource-exhausted',
            ),
          ),
          MfaRecoveryOutcome.locked,
        );
      });

      test('recovery asks for a limited-use App Check token', () async {
        final callable = _MockCallable();
        HttpsCallableOptions? options;
        when(
          () => functions.httpsCallable(
            'recoverWithMfaBackupCode',
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) {
          options =
              invocation.namedArguments[#options] as HttpsCallableOptions?;
          return callable;
        });
        when(
          () => callable.call<dynamic>(any()),
        ).thenAnswer((_) async => _MockResult());
        await mfa.recoverWithBackupCode(
          email: 'anna@example.com',
          password: 'hemligt123',
          code: 'ABCDE-FGHJK',
        );
        expect(options?.limitedUseAppCheckToken, isTrue);
      });

      test(
        'there is no "not needed" outcome: it would confirm the password',
        () async {
          // The server no longer tells an account without MFA apart from a
          // wrong password. Should anything still answer failed-precondition,
          // it must not become a success path that signs in.
          expect(
            MfaRecoveryOutcome.values.map((o) => o.name),
            isNot(contains('notNeeded')),
          );
          expect(
            await recoverWith(
              FirebaseFunctionsException(
                message: 'x',
                code: 'failed-precondition',
              ),
            ),
            MfaRecoveryOutcome.unavailable,
          );
        },
      );

      test('anything else is unavailable, never a success', () async {
        expect(
          await recoverWith(StateError('offline')),
          MfaRecoveryOutcome.unavailable,
        );
      });
    });
  });

  test('the masked tail is the last two digits, never more', () {
    expect(maskedPhoneTail('+*******4547'), '47');
    expect(maskedPhoneTail('+46 70 123 45 67'), '67');
    expect(maskedPhoneTail(null), isNull);
    expect(maskedPhoneTail('+*'), isNull);
  });
}
