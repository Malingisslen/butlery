// BUT-916 slice B: adding and removing sign-in methods through AuthService
// and ProviderSignInService, with the provider sheets scripted.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/auth_error_mapper.dart';
import 'package:butlery/models/auth/provider_sign_in_types.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/auth/provider_sign_in_platform.dart';
import 'package:butlery/services/auth/provider_sign_in_service.dart';
import 'package:butlery/services/auth_service.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/fakes/fake_provider_sign_in_platform.dart';
import '../../../test_support/base_unit_test.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _UserCredential extends Fake implements UserCredential {}

final _credential = AuthCredential(
  providerId: 'google.com',
  signInMethod: 'google.com',
);

void main() {
  late _MockAuthRepository repo;
  late FakeProviderSignInPlatform platform;
  late ProviderSignInService providers;
  late AuthService auth;

  setUpAll(() {
    registerFallbackValue(googleTokens());
    registerFallbackValue(_credential);
    registerFallbackValue(SignInProvider.google);
  });

  setUp(() async {
    await BaseUnitTest.setupUnit();
    repo = _MockAuthRepository();
    when(() => repo.authStateChanges()).thenAnswer((_) => Stream.value(null));
    when(() => repo.currentUser).thenReturn(null);
    when(() => repo.currentUserId).thenReturn(null);
    when(() => repo.providerIds).thenReturn(const ['password']);
    when(() => repo.providerCredential(any())).thenReturn(_credential);
    when(() => repo.providerEmail(any())).thenReturn(null);
    when(() => repo.linkCredential(any())).thenAnswer((_) async {});
    when(() => repo.linkWithProviderFlow(any())).thenAnswer((_) async {});
    when(() => repo.unlinkProvider(any())).thenAnswer((_) async {});
    when(() => repo.reloadCurrentUser()).thenAnswer((_) async {});
    when(() => repo.revokeAppleToken(any())).thenAnswer((_) async {});
    when(
      () => repo.reauthenticateWithProviderTokens(any()),
    ).thenAnswer((_) async {});
    platform = FakeProviderSignInPlatform();
    providers = ProviderSignInService(authRepository: repo, platform: platform);
    auth = AuthService(
      authRepository: repo,
      analyticsService: MockFactory.createAnalyticsService(),
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

  group('which methods the account has', () {
    test('an account whose provider data cannot be read counts as a '
        'password account', () {
      when(() => repo.providerIds).thenReturn(const []);

      expect(auth.hasPasswordSignIn, isTrue);
      expect(auth.canUnlinkSignInMethod, isFalse);
    });

    test('a provider alone is the last method and stays', () {
      when(() => repo.providerIds).thenReturn(const ['google.com']);

      expect(auth.isProviderLinked(SignInProvider.google), isTrue);
      expect(auth.isProviderLinked(SignInProvider.apple), isFalse);
      expect(auth.canUnlinkSignInMethod, isFalse);
    });

    test('a provider beside the password can go', () {
      when(() => repo.providerIds).thenReturn(const ['password', 'google.com']);

      expect(auth.canUnlinkSignInMethod, isTrue);
    });

    test('ids that are not sign-in methods the app offers do not count', () {
      when(() => repo.providerIds).thenReturn(const ['google.com', 'phone']);

      expect(auth.canUnlinkSignInMethod, isFalse);
    });

    test('the address a linked provider holds is read from its data', () {
      when(() => repo.providerEmail('google.com')).thenReturn('a@example.com');

      expect(
        auth.providerAccountEmail(SignInProvider.google),
        'a@example.com',
      );
    });
  });

  group('linking a provider', () {
    test('a native sheet links its credential and keeps the account', () async {
      platform.answer(SignInProvider.google, googleTokens());

      final linked = await auth.linkProvider(SignInProvider.google);

      expect(linked, isTrue);
      verify(() => repo.linkCredential(_credential)).called(1);
      verifyNever(() => repo.signInWithProviderTokens(any()));
    });

    test('where Firebase runs the sheet it links through Firebase', () async {
      platform.googleFlow = ProviderFlow.firebase;

      final linked = await auth.linkProvider(SignInProvider.google);

      expect(linked, isTrue);
      verify(() => repo.linkWithProviderFlow(SignInProvider.google)).called(1);
    });

    test('closing the sheet changes nothing and says nothing', () async {
      final linked = await auth.linkProvider(SignInProvider.google);

      expect(linked, isFalse);
      expect(auth.errorMessage, isNull);
      verifyNever(() => repo.linkCredential(any()));
    });

    test('a provider account that belongs to another user is refused with '
        'its own text', () async {
      platform.answer(SignInProvider.google, googleTokens());
      when(
        () => repo.linkCredential(any()),
      ).thenThrow(FirebaseAuthException(code: 'credential-already-in-use'));

      final linked = await auth.linkProvider(SignInProvider.google);

      expect(linked, isFalse);
      expect(
        auth.errorMessage,
        AppLocale.current.signInMethodsAlreadyUsed('Google'),
      );
    });

    test('a provider that is already linked says so', () async {
      platform.answer(SignInProvider.google, googleTokens());
      when(
        () => repo.linkCredential(any()),
      ).thenThrow(FirebaseAuthException(code: 'provider-already-linked'));

      await auth.linkProvider(SignInProvider.google);

      expect(
        auth.errorMessage,
        AppLocale.current.signInMethodsAlreadyLinked('Google'),
      );
    });

    test('any other refusal says the provider could not be linked', () async {
      platform.answer(SignInProvider.apple, appleTokens());
      when(
        () => repo.linkCredential(any()),
      ).thenThrow(FirebaseAuthException(code: 'network-request-failed'));

      final linked = await auth.linkProvider(SignInProvider.apple);

      expect(linked, isFalse);
      expect(
        auth.errorMessage,
        AppLocale.current.signInMethodsLinkFailed('Apple'),
      );
    });
  });

  group('unlinking a provider', () {
    test('Google goes and nothing is revoked', () async {
      when(() => repo.providerIds).thenReturn(const ['password', 'google.com']);

      final done = await auth.unlinkProvider(SignInProvider.google);

      expect(done, isTrue);
      verify(() => repo.unlinkProvider('google.com')).called(1);
      verifyNever(() => repo.revokeAppleToken(any()));
    });

    test('Apple is revoked with the code of its fresh sheet, before the '
        'method goes', () async {
      when(() => repo.providerIds).thenReturn(const ['password', 'apple.com']);
      platform.answer(SignInProvider.apple, appleTokens());
      await auth.reauthenticateWithProvider(SignInProvider.apple);

      final done = await auth.unlinkProvider(SignInProvider.apple);

      expect(done, isTrue);
      verifyInOrder([
        () => repo.revokeAppleToken('apple-code'),
        () => repo.unlinkProvider('apple.com'),
      ]);
    });

    test('Google goes without revoking Apple, which stays linked', () async {
      when(
        () => repo.providerIds,
      ).thenReturn(const ['password', 'google.com', 'apple.com']);
      platform.answer(SignInProvider.apple, appleTokens());
      await auth.reauthenticateWithProvider(SignInProvider.apple);

      final done = await auth.unlinkProvider(SignInProvider.google);

      expect(done, isTrue);
      verifyNever(() => repo.revokeAppleToken(any()));
      verify(() => repo.unlinkProvider('google.com')).called(1);
    });

    test('a failed revocation never keeps the method', () async {
      when(() => repo.providerIds).thenReturn(const ['password', 'apple.com']);
      platform.answer(SignInProvider.apple, appleTokens());
      await auth.reauthenticateWithProvider(SignInProvider.apple);
      when(
        () => repo.revokeAppleToken(any()),
      ).thenThrow(FirebaseAuthException(code: 'invalid-credential'));

      final done = await auth.unlinkProvider(SignInProvider.apple);

      expect(done, isTrue);
      verify(() => repo.unlinkProvider('apple.com')).called(1);
    });

    test('where no code was given the method still goes', () async {
      when(() => repo.providerIds).thenReturn(const ['password', 'apple.com']);

      final done = await auth.unlinkProvider(SignInProvider.apple);

      expect(done, isTrue);
      verifyNever(() => repo.revokeAppleToken(any()));
      verify(() => repo.unlinkProvider('apple.com')).called(1);
    });

    test('the guard reads the account after a reload, not the cache', () async {
      var reloaded = false;
      when(() => repo.reloadCurrentUser()).thenAnswer((_) async {
        reloaded = true;
      });
      when(
        () => repo.providerIds,
      ).thenAnswer(
        (_) => reloaded ? ['google.com'] : ['password', 'google.com'],
      );

      final done = await auth.unlinkProvider(SignInProvider.google);

      expect(done, isFalse);
      verifyNever(() => repo.unlinkProvider(any()));
    });

    test('the last method is never removed', () async {
      when(() => repo.providerIds).thenReturn(const ['google.com']);

      final done = await auth.unlinkProvider(SignInProvider.google);

      expect(done, isFalse);
      expect(
        auth.errorMessage,
        AppLocale.current.signInMethodsUnlinkFailed('Google'),
      );
      verifyNever(() => repo.unlinkProvider(any()));
    });

    test('a refusal from Firebase leaves the method and says so', () async {
      when(() => repo.providerIds).thenReturn(const ['password', 'google.com']);
      when(
        () => repo.unlinkProvider(any()),
      ).thenThrow(FirebaseAuthException(code: 'no-such-provider'));

      final done = await auth.unlinkProvider(SignInProvider.google);

      expect(done, isFalse);
      expect(
        auth.errorMessage,
        AppLocale.current.signInMethodsUnlinkFailed('Google'),
      );
    });
  });

  group('adding a password', () {
    test('goes on the address the account already has', () async {
      when(() => repo.providerIds).thenReturn(const ['google.com']);
      when(() => repo.currentUser).thenReturn(
        MockFactory.createMockUser(uid: 'anna', email: 'anna@example.com'),
      );
      var linkedTo = '';
      when(() => repo.linkEmailPassword(any(), any())).thenAnswer((call) async {
        linkedTo = call.positionalArguments.first as String;
        return _UserCredential();
      });

      final done = await auth.addPasswordSignIn('hemligt123');

      expect(done, isTrue);
      expect(linkedTo, 'anna@example.com');
    });

    test('an account without an address cannot get one', () async {
      when(() => repo.providerIds).thenReturn(const ['google.com']);

      final done = await auth.addPasswordSignIn('hemligt123');

      expect(done, isFalse);
      expect(
        auth.errorMessage,
        AppLocale.current.signInMethodsPasswordFailed,
      );
      verifyNever(() => repo.linkEmailPassword(any(), any()));
    });

    test('a sign-in that is too old is reported in the app\'s words', () async {
      when(() => repo.currentUser).thenReturn(
        MockFactory.createMockUser(uid: 'anna', email: 'anna@example.com'),
      );
      when(
        () => repo.linkEmailPassword(any(), any()),
      ).thenThrow(FirebaseAuthException(code: 'requires-recent-login'));

      final done = await auth.addPasswordSignIn('hemligt123');

      expect(done, isFalse);
      expect(
        auth.errorMessage,
        mapAuthErrorToMessage(
          FirebaseAuthException(code: 'requires-recent-login'),
        ),
      );
      expect(
        auth.errorMessage,
        isNot(AppLocale.current.signInMethodsPasswordFailed),
      );
    });
  });
}
