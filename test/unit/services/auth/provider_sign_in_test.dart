// BUT-916 / BUT-549: "Fortsätt med Google / Apple" through AuthService and
// ProviderSignInService, with the provider sheets scripted.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/auth/provider_sign_in_types.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/auth/provider_sign_in_platform.dart';
import 'package:butlery/services/auth/provider_sign_in_service.dart';
import 'package:butlery/services/auth_service.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/fakes/fake_provider_sign_in_platform.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockResolver extends Mock implements MultiFactorResolver {}

class _MockMfaException extends Mock
    implements FirebaseAuthMultiFactorException {}

class _Credential extends Fake implements UserCredential {
  _Credential({required bool isNewUser})
    : additionalUserInfo = AdditionalUserInfo(isNewUser: isNewUser);

  @override
  final AdditionalUserInfo additionalUserInfo;
}

_MockMfaException _mfaException() {
  final exception = _MockMfaException();
  when(() => exception.resolver).thenReturn(_MockResolver());
  when(() => exception.code).thenReturn('multi-factor-auth-required');
  return exception;
}

final _googleCredential = AuthCredential(
  providerId: 'google.com',
  signInMethod: 'google.com',
);

void main() {
  late _MockAuthRepository repo;
  late MockAnalyticsService analytics;
  late FakeProviderSignInPlatform platform;
  late ProviderSignInService providers;
  late AuthService auth;
  late _MockMfaException mfa;

  setUpAll(() {
    registerFallbackValue(googleTokens());
    registerFallbackValue(_googleCredential);
    registerFallbackValue(SignInProvider.google);
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
    when(() => analytics.logLogout()).thenAnswer((_) async {});
    when(() => repo.authStateChanges()).thenAnswer((_) => Stream.value(null));
    when(() => repo.currentUser).thenReturn(null);
    when(() => repo.currentUserId).thenReturn(null);
    when(() => repo.providerIds).thenReturn(const []);
    when(() => repo.providerCredential(any())).thenReturn(_googleCredential);
    when(() => repo.signOut()).thenAnswer((_) async {});
    mfa = _mfaException();
    platform = FakeProviderSignInPlatform();
    providers = ProviderSignInService(authRepository: repo, platform: platform);
    auth = AuthService(
      authRepository: repo,
      analyticsService: analytics,
      providerSignIn: providers,
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

  void signsInAs(String email, {bool isNewUser = false}) {
    when(() => repo.signInWithProviderTokens(any())).thenAnswer((_) async {
      when(
        () => repo.currentUser,
      ).thenReturn(MockFactory.createMockUser(uid: 'anna', email: email));
      return _Credential(isNewUser: isNewUser);
    });
  }

  group('signing in', () {
    test('a new Google user is signed in and counted as a sign-up', () async {
      platform.answer(SignInProvider.google, googleTokens());
      signsInAs('anna@example.com', isNewUser: true);

      final outcome = await auth.signInWithProvider(SignInProvider.google);

      expect(outcome, ProviderSignInOutcome.signedIn);
      expect(auth.currentUser, isNotNull);
      verify(() => analytics.logSignUp(method: 'google')).called(1);
      verifyNever(() => analytics.logLogin(method: any(named: 'method')));
      expect(auth.providerAccountCreatedHere, isTrue);
    });

    test(
      'an existing Apple user is signed in and counted as a login',
      () async {
        platform.answer(SignInProvider.apple, appleTokens(givenName: 'Anna'));
        signsInAs('anna@example.com');

        final outcome = await auth.signInWithProvider(SignInProvider.apple);

        expect(outcome, ProviderSignInOutcome.signedIn);
        verify(() => analytics.logLogin(method: 'apple')).called(1);
        expect(auth.providerAccountCreatedHere, isFalse);
        expect(auth.providerFirstName, 'Anna');
      },
    );

    test('closing the sheet is silent and signs nobody in', () async {
      platform.answer(SignInProvider.google, null);

      final outcome = await auth.signInWithProvider(SignInProvider.google);

      expect(outcome, ProviderSignInOutcome.cancelled);
      expect(auth.errorMessage, isNull);
      expect(auth.isLoading, isFalse);
      verifyNever(() => repo.signInWithProviderTokens(any()));
    });

    test('a cancelled Firebase popup is silent too', () async {
      platform.googleFlow = ProviderFlow.firebase;
      when(
        () => repo.signInWithProviderFlow(any()),
      ).thenThrow(FirebaseAuthException(code: 'popup-closed-by-user'));

      final outcome = await auth.signInWithProvider(SignInProvider.google);

      expect(outcome, ProviderSignInOutcome.cancelled);
      expect(auth.errorMessage, isNull);
    });

    test('a second factor waits as a challenge, with no error', () async {
      platform.answer(SignInProvider.google, googleTokens());
      when(
        () => repo.signInWithProviderTokens(any()),
      ).thenThrow(mfa);

      final outcome = await auth.signInWithProvider(SignInProvider.google);

      expect(outcome, ProviderSignInOutcome.mfaRequired);
      expect(auth.pendingMfaChallenge, isNotNull);
      expect(auth.errorMessage, isNull);
      expect(auth.currentUser, isNull);
    });

    test('a failure after the provider signed in is reported, and the outcome '
        'follows who is signed in', () async {
      platform.answer(SignInProvider.google, googleTokens());
      signsInAs('anna@example.com');
      when(
        () => analytics.logLogin(method: any(named: 'method')),
      ).thenThrow(StateError('analytics down'));

      final outcome = await auth.signInWithProvider(SignInProvider.google);

      expect(outcome, ProviderSignInOutcome.signedIn);
      expect(auth.errorMessage, isNotNull);
      expect(auth.isLoading, isFalse);
    });

    test('and is a failure when nobody is signed in', () async {
      platform.answer(SignInProvider.google, googleTokens());
      when(
        () => repo.signInWithProviderTokens(any()),
      ).thenAnswer((_) async => _Credential(isNewUser: false));
      when(
        () => analytics.logLogin(method: any(named: 'method')),
      ).thenThrow(StateError('analytics down'));

      final outcome = await auth.signInWithProvider(SignInProvider.google);

      expect(outcome, ProviderSignInOutcome.failed);
      expect(auth.errorMessage, isNotNull);
    });

    test('a challenge left from an earlier attempt is dropped', () async {
      platform.answer(SignInProvider.google, googleTokens());
      when(() => repo.signInWithProviderTokens(any())).thenThrow(mfa);
      await auth.signInWithProvider(SignInProvider.google);
      expect(auth.pendingMfaChallenge, isNotNull);

      platform.answer(SignInProvider.google, null);
      await auth.signInWithProvider(SignInProvider.google);

      expect(auth.pendingMfaChallenge, isNull);
    });

    test('a finished sign-in holds no provider tokens', () async {
      when(() => repo.providerIds).thenReturn(['apple.com']);
      when(() => repo.revokeAppleToken(any())).thenAnswer((_) async {});
      platform.answer(SignInProvider.google, googleTokens());
      signsInAs('anna@example.com');
      await auth.signInWithProvider(SignInProvider.google);
      expect(auth.canRecoverThroughProvider(SignInProvider.google), isFalse);

      platform.answer(SignInProvider.apple, appleTokens());
      await auth.signInWithProvider(SignInProvider.apple);
      await auth.revokeAppleSignIn();

      verifyNever(() => repo.revokeAppleToken(any()));
    });

    test('a refused sign-in says so with the provider named', () async {
      platform.answer(SignInProvider.apple, appleTokens());
      when(
        () => repo.signInWithProviderTokens(any()),
      ).thenThrow(FirebaseAuthException(code: 'internal-error'));

      final outcome = await auth.signInWithProvider(SignInProvider.apple);

      expect(outcome, ProviderSignInOutcome.failed);
      expect(auth.errorMessage, contains('Apple'));
    });

    test('an uninvited sign-up says it is not invited, not that the provider '
        'failed', () async {
      platform.answer(SignInProvider.apple, appleTokens());
      when(() => repo.signInWithProviderTokens(any())).thenThrow(
        FirebaseAuthException(
          code: 'internal-error',
          message: 'SIGNUP_NOT_INVITED: not on the guest list',
        ),
      );

      final outcome = await auth.signInWithProvider(SignInProvider.apple);

      expect(outcome, ProviderSignInOutcome.failed);
      expect(auth.errorMessage, AppLocale.current.errorSignupNotInvited);
    });
  });

  group('an address that already has a password account (C4)', () {
    void accountExists() {
      when(() => repo.signInWithProviderTokens(any())).thenThrow(
        FirebaseAuthException(
          code: 'account-exists-with-different-credential',
          email: 'Anna@Example.com',
        ),
      );
    }

    test('asks for the password once when the provider vouches for the '
        'address', () async {
      platform.answer(SignInProvider.google, googleTokens());
      accountExists();

      final outcome = await auth.signInWithProvider(SignInProvider.google);

      expect(outcome, ProviderSignInOutcome.linkNeedsPassword);
      expect(auth.pendingProviderLink?.email, 'anna@example.com');
      expect(auth.pendingProviderLink?.provider, SignInProvider.google);
    });

    test(
      'refuses when the provider does not say the address is verified',
      () async {
        platform.answer(SignInProvider.google, googleTokens(verified: false));
        accountExists();

        final outcome = await auth.signInWithProvider(SignInProvider.google);

        expect(outcome, ProviderSignInOutcome.failed);
        expect(auth.pendingProviderLink, isNull);
        expect(auth.errorMessage, isNotNull);
      },
    );

    test('an account with two-step gains the provider only after the '
        'second factor', () async {
      platform.answer(SignInProvider.google, googleTokens());
      accountExists();
      await auth.signInWithProvider(SignInProvider.google);
      when(() => repo.linkCredential(any())).thenAnswer((_) async {});

      // The password is right; the second factor is asked for.
      when(
        () => repo.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(mfa);
      final passwordOnly = await auth.signInWithEmail(
        email: 'anna@example.com',
        password: 'hemligt123',
      );
      expect(passwordOnly, isFalse);
      expect(auth.pendingMfaChallenge, isNotNull);
      verifyNever(() => repo.linkCredential(any()));

      // The second factor resolved: now the provider joins.
      when(() => repo.currentUser).thenReturn(
        MockFactory.createMockUser(uid: 'anna', email: 'anna@example.com'),
      );
      expect(await auth.finishMfaSignIn(), isTrue);
      verify(() => repo.linkCredential(_googleCredential)).called(1);
      expect(auth.pendingProviderLink, isNull);
    });

    test('an account without two-step gains the provider after a correct '
        'password', () async {
      platform.answer(SignInProvider.google, googleTokens());
      accountExists();
      await auth.signInWithProvider(SignInProvider.google);
      when(() => repo.linkCredential(any())).thenAnswer((_) async {});
      when(
        () => repo.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async {});
      when(() => repo.currentUser).thenReturn(
        MockFactory.createMockUser(uid: 'anna', email: 'anna@example.com'),
      );

      final ok = await auth.signInWithEmail(
        email: 'anna@example.com',
        password: 'hemligt123',
      );

      expect(ok, isTrue);
      verify(() => repo.linkCredential(_googleCredential)).called(1);
      expect(auth.pendingProviderLink, isNull);
      expect(auth.takeFailedProviderLink(), isNull);
    });

    test('a link that fails is reported once after the sign-in', () async {
      platform.answer(SignInProvider.google, googleTokens());
      accountExists();
      await auth.signInWithProvider(SignInProvider.google);
      when(
        () => repo.linkCredential(any()),
      ).thenThrow(FirebaseAuthException(code: 'invalid-credential'));
      when(
        () => repo.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async {});
      when(() => repo.currentUser).thenReturn(
        MockFactory.createMockUser(uid: 'anna', email: 'anna@example.com'),
      );

      final ok = await auth.signInWithEmail(
        email: 'anna@example.com',
        password: 'hemligt123',
      );

      expect(ok, isTrue);
      expect(auth.takeFailedProviderLink(), SignInProvider.google);
      expect(auth.takeFailedProviderLink(), isNull);
    });

    test('the second factor done, the Google token is dropped', () async {
      platform.answer(SignInProvider.google, googleTokens());
      when(() => repo.signInWithProviderTokens(any())).thenThrow(mfa);
      await auth.signInWithProvider(SignInProvider.google);
      expect(auth.canRecoverThroughProvider(SignInProvider.google), isTrue);
      when(() => repo.currentUser).thenReturn(
        MockFactory.createMockUser(uid: 'anna', email: 'anna@example.com'),
      );

      expect(await auth.finishMfaSignIn(), isTrue);

      expect(auth.canRecoverThroughProvider(SignInProvider.google), isFalse);
    });

    test('going back from the challenge drops the Google token', () async {
      platform.answer(SignInProvider.google, googleTokens());
      when(() => repo.signInWithProviderTokens(any())).thenThrow(mfa);
      await auth.signInWithProvider(SignInProvider.google);
      expect(auth.canRecoverThroughProvider(SignInProvider.google), isTrue);

      auth.clearPendingMfa();

      expect(auth.canRecoverThroughProvider(SignInProvider.google), isFalse);
    });

    test('a password sign-in after a stopped Google sign-in drops the '
        'Google token', () async {
      platform.answer(SignInProvider.google, googleTokens());
      when(() => repo.signInWithProviderTokens(any())).thenThrow(mfa);
      await auth.signInWithProvider(SignInProvider.google);
      expect(auth.canRecoverThroughProvider(SignInProvider.google), isTrue);
      when(
        () => repo.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async {});
      when(() => repo.currentUser).thenReturn(
        MockFactory.createMockUser(uid: 'anna', email: 'anna@example.com'),
      );

      await auth.signInWithEmail(
        email: 'anna@example.com',
        password: 'x1234567',
      );

      expect(auth.canRecoverThroughProvider(SignInProvider.google), isFalse);
    });

    test('a sign-in to another address drops the waiting credential', () async {
      platform.answer(SignInProvider.google, googleTokens());
      accountExists();
      await auth.signInWithProvider(SignInProvider.google);
      when(
        () => repo.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async {});
      when(() => repo.currentUser).thenReturn(
        MockFactory.createMockUser(uid: 'bo', email: 'bo@example.com'),
      );

      await auth.signInWithEmail(email: 'bo@example.com', password: 'x1234567');

      verifyNever(() => repo.linkCredential(any()));
      expect(auth.pendingProviderLink, isNull);
    });
  });

  group('re-authentication (C7)', () {
    test('a password account confirms with its password', () {
      when(() => repo.providerIds).thenReturn(['password', 'google.com']);
      expect(auth.reauthenticationProvider(), isNull);
      expect(auth.hasPasswordSignIn, isTrue);
    });

    test('a Google-only account confirms through Google', () {
      when(() => repo.providerIds).thenReturn(['google.com']);
      expect(auth.reauthenticationProvider(), SignInProvider.google);
      expect(auth.hasPasswordSignIn, isFalse);
    });

    test('before a deletion Apple comes first where its sheet is native, '
        'even beside a password', () {
      when(() => repo.providerIds).thenReturn(['password', 'apple.com']);
      expect(
        auth.reauthenticationProvider(forDeletion: true),
        SignInProvider.apple,
      );
      platform.appleFlow = ProviderFlow.firebase;
      expect(auth.reauthenticationProvider(forDeletion: true), isNull);
    });

    test('a provider this device does not offer is not asked for', () {
      when(() => repo.providerIds).thenReturn(['apple.com']);
      platform.appleFlow = ProviderFlow.unavailable;
      expect(auth.reauthenticationProvider(), isNull);
    });

    test('a second factor on re-authentication waits as a challenge', () async {
      platform.answer(SignInProvider.google, googleTokens());
      when(
        () => repo.reauthenticateWithProviderTokens(any()),
      ).thenThrow(mfa);

      final outcome = await auth.reauthenticateWithProvider(
        SignInProvider.google,
      );

      expect(outcome, ProviderSignInOutcome.mfaRequired);
      expect(auth.pendingMfaChallenge, isNotNull);
    });

    test('a Google re-authentication keeps no token afterwards', () async {
      platform.answer(SignInProvider.google, googleTokens());
      when(
        () => repo.reauthenticateWithProviderTokens(any()),
      ).thenAnswer((_) async {});

      await auth.reauthenticateWithProvider(SignInProvider.google);

      expect(auth.canRecoverThroughProvider(SignInProvider.google), isFalse);
    });

    test('an Apple re-authentication with two-step keeps its code for the '
        'deletion when the challenge closes', () async {
      platform.answer(SignInProvider.google, googleTokens());
      signsInAs('anna@example.com');
      await auth.signInWithProvider(SignInProvider.google);
      when(() => repo.providerIds).thenReturn(['apple.com']);
      when(() => repo.revokeAppleToken(any())).thenAnswer((_) async {});
      when(
        () => repo.reauthenticateWithProviderTokens(any()),
      ).thenThrow(mfa);
      platform.answer(SignInProvider.apple, appleTokens());
      await auth.reauthenticateWithProvider(SignInProvider.apple);
      expect(auth.pendingMfaChallenge, isNotNull);

      auth.clearPendingMfa();
      await auth.revokeAppleSignIn();

      verify(() => repo.revokeAppleToken('apple-code')).called(1);
    });

    test(
      'a password re-authentication with two-step waits as a challenge',
      () async {
        when(() => repo.reauthenticateWithPassword(any())).thenThrow(mfa);

        final ok = await auth.reauthenticateWithPassword('hemligt123');

        expect(ok, isFalse);
        expect(auth.pendingMfaChallenge, isNotNull);
        expect(auth.errorMessage, isNull);
      },
    );
  });

  group('Apple revocation at deletion (C10)', () {
    test('revokes with the code from the Apple re-authentication', () async {
      when(() => repo.providerIds).thenReturn(['apple.com']);
      when(() => repo.reauthenticateWithProviderTokens(any())).thenAnswer(
        (_) async {},
      );
      when(() => repo.revokeAppleToken(any())).thenAnswer((_) async {});
      platform.answer(SignInProvider.apple, appleTokens());

      await auth.reauthenticateWithProvider(SignInProvider.apple);
      await auth.revokeAppleSignIn();

      verify(() => repo.revokeAppleToken('apple-code')).called(1);
    });

    test('without a code nothing is revoked and nothing throws', () async {
      when(() => repo.providerIds).thenReturn(['apple.com']);

      await auth.revokeAppleSignIn();

      verifyNever(() => repo.revokeAppleToken(any()));
    });

    test('a failed revocation never blocks the deletion', () async {
      when(() => repo.providerIds).thenReturn(['apple.com']);
      when(() => repo.reauthenticateWithProviderTokens(any())).thenAnswer(
        (_) async {},
      );
      when(
        () => repo.revokeAppleToken(any()),
      ).thenThrow(FirebaseAuthException(code: 'invalid-credential'));
      platform.answer(SignInProvider.apple, appleTokens());
      await auth.reauthenticateWithProvider(SignInProvider.apple);

      await expectLater(auth.revokeAppleSignIn(), completes);
    });

    test('an error of any kind never blocks the deletion', () async {
      when(() => repo.providerIds).thenThrow(StateError('no user'));

      await expectLater(auth.revokeAppleSignIn(), completes);
    });

    test('an account without Apple is left alone', () async {
      when(() => repo.providerIds).thenReturn(['google.com']);
      await auth.revokeAppleSignIn();
      verifyNever(() => repo.revokeAppleToken(any()));
    });
  });

  group('the Google account picker is forgotten at every sign-out (C5)', () {
    test('signOut', () async {
      await auth.signOut();
      expect(platform.googleSignOuts, 1);
    });

    test('logoutDueToInactivity', () async {
      await auth.logoutDueToInactivity();
      expect(platform.googleSignOuts, 1);
    });

    test('forceSignOut', () async {
      await auth.forceSignOut();
      expect(platform.googleSignOuts, 1);
    });

    test('and the waiting credential and tokens go with it', () async {
      platform.answer(SignInProvider.google, googleTokens());
      when(() => repo.signInWithProviderTokens(any())).thenThrow(
        FirebaseAuthException(
          code: 'account-exists-with-different-credential',
          email: 'anna@example.com',
        ),
      );
      await auth.signInWithProvider(SignInProvider.google);
      expect(auth.pendingProviderLink, isNotNull);
      expect(auth.canRecoverThroughProvider(SignInProvider.google), isTrue);

      await auth.signOut();

      expect(auth.pendingProviderLink, isNull);
      expect(auth.canRecoverThroughProvider(SignInProvider.google), isFalse);
    });
  });

  group('backup-code proof (C8)', () {
    test('Google proves with the token from the stopped sign-in', () async {
      platform.answer(SignInProvider.google, googleTokens());
      when(
        () => repo.signInWithProviderTokens(any()),
      ).thenThrow(mfa);
      await auth.signInWithProvider(SignInProvider.google);

      final proof = await auth.providerRecoveryProof(SignInProvider.google);

      expect(proof?.providerId, 'google.com');
      expect(proof?.nonce, isNull);
      expect(platform.sheetsOpened, [SignInProvider.google]);
    });

    test('Apple on iOS proves with a fresh sheet and its raw nonce', () async {
      platform.answer(SignInProvider.apple, appleTokens());

      final proof = await auth.providerRecoveryProof(SignInProvider.apple);

      expect(proof?.providerId, 'apple.com');
      expect(proof?.nonce, 'raw-nonce');
    });

    test('where Firebase runs the sheet there is no proof here', () async {
      platform.appleFlow = ProviderFlow.firebase;
      expect(auth.canRecoverThroughProvider(SignInProvider.apple), isFalse);
      expect(await auth.providerRecoveryProof(SignInProvider.apple), isNull);
    });
  });

  test('the Apple credential carries the id token and raw nonce, never the '
      'one-time code', () {
    final credential =
        FirebaseAuthRepository(
              firebaseAuth: MockFirebaseAuth(),
            ).providerCredential(appleTokens())
            as OAuthCredential;

    expect(credential.idToken, appleTokens().idToken);
    expect(credential.rawNonce, 'raw-nonce');
    expect(credential.accessToken, isNull);
  });

  group('deleting the auth user forgets the Google account picker', () {
    setUp(() {
      when(() => repo.deleteCurrentUser()).thenAnswer((_) async {});
    });

    test('deleteCurrentAuthUser', () async {
      await auth.deleteCurrentAuthUser();
      expect(platform.googleSignOuts, 1);
    });

    test('deleteAccount', () async {
      platform.answer(SignInProvider.google, googleTokens());
      signsInAs('anna@example.com');
      await auth.signInWithProvider(SignInProvider.google);

      expect(await auth.deleteAccount(), isTrue);
      expect(platform.googleSignOuts, 1);
    });
  });

  test('the token printout never carries a token', () {
    final tokens = appleTokens();
    expect(tokens.toString(), isNot(contains(tokens.idToken)));
    expect(tokens.toString(), isNot(contains('apple-code')));
  });
}
