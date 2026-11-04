// BUT-2502: a first Google sign-in on Android showed "Autentiseringsfel. Logga
// in igen." although the server had made the account and accepted the sign-in.
// A failed sign-in is now reported without personal data, a sign-in that left
// the device signed in anyway goes through, and a code without its own text is
// shown with the code.

import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/auth/provider_sign_in_types.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/auth/provider_sign_in_platform.dart';
import 'package:butlery/services/auth/provider_sign_in_service.dart';
import 'package:butlery/services/auth/sign_in_failure_reporter.dart';
import 'package:butlery/services/auth_service.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/fakes/fake_provider_sign_in_platform.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockUser extends Mock implements User {}

class _ProviderInfo extends Fake implements UserInfo {
  _ProviderInfo(this.providerId);

  @override
  final String providerId;
}

class _SheetFails extends FakeProviderSignInPlatform {
  @override
  Future<ProviderTokens?> obtainTokens(SignInProvider provider) async =>
      throw const ProviderSheetException('google: unknownError');
}

final _googleCredential = AuthCredential(
  providerId: 'google.com',
  signInMethod: 'google.com',
);

User _userWith(String providerId, {required Duration sinceCreated}) {
  final user = _MockUser();
  final now = DateTime(2026, 11, 3, 22, 43);
  when(() => user.uid).thenReturn('anna');
  when(() => user.email).thenReturn('anna@example.com');
  when(() => user.providerData).thenReturn([_ProviderInfo(providerId)]);
  when(() => user.metadata).thenReturn(
    UserMetadata(
      now.subtract(sinceCreated).millisecondsSinceEpoch,
      now.millisecondsSinceEpoch,
    ),
  );
  return user;
}

void main() {
  late _MockAuthRepository repo;
  late MockAnalyticsService analytics;
  late FakeProviderSignInPlatform platform;
  late AuthService auth;
  late List<Map<String, String>> sent;
  User? signedIn;

  setUpAll(() {
    registerFallbackValue(googleTokens());
    registerFallbackValue(_googleCredential);
  });

  setUp(() async {
    await BaseUnitTest.setupUnit();
    repo = _MockAuthRepository();
    analytics = MockFactory.createAnalyticsService();
    when(
      () => analytics.logLogin(method: any(named: 'method')),
    ).thenAnswer((_) async {});
    when(
      () => analytics.logSignUp(method: any(named: 'method')),
    ).thenAnswer((_) async {});
    when(() => repo.authStateChanges()).thenAnswer((_) => Stream.value(null));
    signedIn = null;
    when(() => repo.currentUser).thenAnswer((_) => signedIn);
    when(() => repo.currentUserId).thenAnswer((_) => signedIn?.uid);
    when(() => repo.providerIds).thenReturn(const []);
    when(() => repo.providerCredential(any())).thenReturn(_googleCredential);
    platform = FakeProviderSignInPlatform();
    sent = [];
    auth = AuthService(
      authRepository: repo,
      analyticsService: analytics,
      providerSignIn: ProviderSignInService(
        authRepository: repo,
        platform: platform,
        failureReporter: SignInFailureReporter(
          send: (payload) async => sent.add(payload),
          platform: 'android',
        ),
      ),
    );
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

  void signInThrows(Object error, {User? leavesSignedIn}) {
    platform.answer(SignInProvider.google, googleTokens());
    when(() => repo.signInWithProviderTokens(any())).thenAnswer((_) async {
      signedIn = leavesSignedIn;
      throw error;
    });
  }

  group('a code the app has no text for', () {
    test('is shown with the code instead of "Autentiseringsfel"', () async {
      signInThrows(FirebaseAuthException(code: 'web-internal-error'));

      final outcome = await auth.signInWithProvider(SignInProvider.google);

      expect(outcome, ProviderSignInOutcome.failed);
      expect(
        auth.errorMessage,
        AppLocale.current.authProviderFailedWithCode(
          'Google',
          'web-internal-error',
        ),
      );
      expect(auth.errorMessage, isNot(AppLocale.current.errorAuthentication));
    });

    test('is reported with provider, step, platform and code only', () async {
      signInThrows(
        FirebaseAuthException(
          code: 'web-internal-error',
          message: 'anna@example.com could not be signed in',
          email: 'anna@example.com',
        ),
      );

      await auth.signInWithProvider(SignInProvider.google);
      await pumpEventQueue();

      expect(sent, [
        {
          'provider': 'google',
          'stage': 'signIn',
          'platform': 'android',
          'code': 'web-internal-error',
        },
      ]);
    });
  });

  test('a code with its own text keeps that text', () async {
    signInThrows(FirebaseAuthException(code: 'network-request-failed'));

    await auth.signInWithProvider(SignInProvider.google);

    expect(auth.errorMessage, AppLocale.current.errorNetwork);
  });

  group('a sign-in that failed but left the device signed in', () {
    test('goes through as a new account, without an error', () async {
      signInThrows(
        FirebaseAuthException(code: 'web-internal-error'),
        leavesSignedIn: _userWith('google.com', sinceCreated: Duration.zero),
      );

      final outcome = await auth.signInWithProvider(SignInProvider.google);
      await pumpEventQueue();

      expect(outcome, ProviderSignInOutcome.signedIn);
      expect(auth.errorMessage, isNull);
      expect(auth.providerAccountCreatedHere, isTrue);
      verify(() => analytics.logSignUp(method: 'google')).called(1);
      expect(sent.single['stage'], 'signInRecovered');
    });

    test('an older account goes through as a sign-in', () async {
      signInThrows(
        StateError('lost result'),
        leavesSignedIn: _userWith(
          'google.com',
          sinceCreated: const Duration(days: 3),
        ),
      );

      final outcome = await auth.signInWithProvider(SignInProvider.google);

      expect(outcome, ProviderSignInOutcome.signedIn);
      expect(auth.providerAccountCreatedHere, isFalse);
      verify(() => analytics.logLogin(method: 'google')).called(1);
    });

    test('is not taken for a sign-in through another provider', () async {
      signInThrows(
        FirebaseAuthException(code: 'web-internal-error'),
        leavesSignedIn: _userWith('password', sinceCreated: Duration.zero),
      );

      final outcome = await auth.signInWithProvider(SignInProvider.google);

      expect(outcome, ProviderSignInOutcome.failed);
    });

    test('is not taken when someone was signed in before', () async {
      signedIn = _userWith('google.com', sinceCreated: Duration.zero);
      signInThrows(
        FirebaseAuthException(code: 'web-internal-error'),
        leavesSignedIn: signedIn,
      );

      final outcome = await auth.signInWithProvider(SignInProvider.google);

      expect(outcome, ProviderSignInOutcome.failed);
    });
  });

  test('closing the sheet is not reported', () async {
    platform.answer(SignInProvider.google, null);

    await auth.signInWithProvider(SignInProvider.google);
    await pumpEventQueue();

    expect(sent, isEmpty);
  });

  test('a sheet that fails is reported by kind and fails the sign-in', () async {
    final sheetFails = AuthService(
      authRepository: repo,
      analyticsService: analytics,
      providerSignIn: ProviderSignInService(
        authRepository: repo,
        platform: _SheetFails(),
        failureReporter: SignInFailureReporter(
          send: (payload) async => sent.add(payload),
          platform: 'android',
        ),
      ),
    );
    addTearDown(sheetFails.dispose);

    final outcome = await sheetFails.signInWithProvider(SignInProvider.google);
    await pumpEventQueue();

    expect(outcome, ProviderSignInOutcome.failed);
    expect(sent.single['code'], startsWith('sheet:'));
    expect(sent.single['stage'], SignInFailureReporter.stageSignIn);
  });

  test('a report that cannot be sent never fails the sign-in', () async {
    final failing = AuthService(
      authRepository: repo,
      analyticsService: analytics,
      providerSignIn: ProviderSignInService(
        authRepository: repo,
        platform: platform,
        failureReporter: SignInFailureReporter(
          send: (_) async => throw StateError('offline'),
          platform: 'android',
        ),
      ),
    );
    signInThrows(FirebaseAuthException(code: 'web-internal-error'));

    final outcome = await failing.signInWithProvider(SignInProvider.google);
    await pumpEventQueue();

    expect(outcome, ProviderSignInOutcome.failed);
    failing.dispose();
  });

  group('the reported code', () {
    test('is never the message, which can repeat an address', () {
      expect(
        SignInFailureReporter.codeFor(
          FirebaseAuthException(code: 'unknown', message: 'anna@example.com'),
        ),
        'unknown',
      );
    });

    test('names a failed sheet and a non-Firebase error by kind', () {
      expect(
        SignInFailureReporter.codeFor(
          const ProviderSheetException('google: unknownError'),
        ),
        'sheet:google:.unknownError',
      );
      expect(
        SignInFailureReporter.codeFor(StateError('x')),
        'dart:StateError',
      );
    });

    test('fits the pattern the server accepts', () {
      final server = File(
        'functions/src/events/log-sign-in-failure.ts',
      ).readAsStringSync();
      final source = RegExp(
        r'const CODE_PATTERN = /(.+)/i;',
      ).firstMatch(server)!.group(1)!;
      final pattern = RegExp(source, caseSensitive: false);
      for (final error in <Object>[
        FirebaseAuthException(code: 'ERROR_X y@z'),
        ProviderSheetException('a' * 100),
        FirebaseAuthException(code: '---'),
      ]) {
        expect(SignInFailureReporter.codeFor(error), matches(pattern));
      }
    });
  });

  test('the app sends only values the server accepts', () {
    final server = File(
      'functions/src/events/log-sign-in-failure.ts',
    ).readAsStringSync();
    Set<String> list(String name) {
      final body = RegExp(
        'export const $name\\s*=\\s*\\[([^\\]]*)\\]',
      ).firstMatch(server)!.group(1)!;
      return RegExp('"([^"]+)"').allMatches(body).map((m) => m[1]!).toSet();
    }

    expect(
      list('SIGN_IN_FAILURE_PROVIDERS'),
      SignInProvider.values.map((p) => p.analyticsMethod).toSet(),
    );
    expect(list('SIGN_IN_FAILURE_STAGES'), {
      SignInFailureReporter.stageSignIn,
      SignInFailureReporter.stageRecovered,
    });
    expect(list('SIGN_IN_FAILURE_PLATFORMS'), {'android', 'ios', 'web'});
  });
}
