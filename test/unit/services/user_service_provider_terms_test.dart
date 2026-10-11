// BUT-916 C1-C3: the terms step for a new Google/Apple account is decided by
// whether Firestore holds its profile, so it survives a restart, and nothing
// is written for the account before the user has answered it.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/services/user_service.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../test_support/base_unit_test.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockUserRepository extends Mock implements UserRepository {}

class _MockFirestoreRepository extends Mock implements FirestoreRepository {}

class _Provider extends Fake implements UserInfo {
  _Provider(this.providerId);

  @override
  final String providerId;
}

User _user({required String providerId, String? email = 'anna@example.com'}) =>
    MockUser(
      uid: 'uid-anna',
      email: email,
      displayName: 'Anna Andersson',
      providerData: [_Provider(providerId)],
    );

void main() {
  late _MockAuthRepository auth;
  late _MockUserRepository repo;

  UserProfile profile(String displayName) => UserProfile(
    uid: 'uid-anna',
    displayName: displayName,
    email: '',
    isOnline: false,
    joinedAt: DateTime(2026, 10, 1),
    lastActiveAt: DateTime(2026, 10, 1),
  );

  setUpAll(() async {
    registerFallbackValue(
      UserProfile(
        uid: 'fallback',
        displayName: 'x',
        email: '',
        isOnline: false,
        joinedAt: DateTime(2026),
        lastActiveAt: DateTime(2026),
      ),
    );
    production.ServiceLocator.initialize(DIContainer());
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    auth = _MockAuthRepository();
    repo = _MockUserRepository();
    when(() => auth.authStateChanges()).thenAnswer((_) => const Stream.empty());
    when(() => repo.fetchProfile(any())).thenAnswer((_) async => null);
    when(() => repo.ensureBaseUserDocument(any())).thenAnswer((_) async {});
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Future<UserService> start(User user) async {
    when(() => auth.currentUser).thenReturn(user);
    final service = UserService(
      repository: repo,
      authRepository: auth,
      firestoreRepository: _MockFirestoreRepository(),
    );
    await service.initialize();
    return service;
  }

  test(
    'a new Google account waits on the terms and nothing is written',
    () async {
      final service = await start(_user(providerId: 'google.com'));

      expect(service.termsPending, isTrue);
      expect(service.currentUserProfile, isNull);
      expect(service.hasError, isFalse);
      verifyNever(() => repo.ensureBaseUserDocument(any()));
      verifyNever(() => repo.recordTermsAcceptance(any(), any()));
    },
  );

  test('the step comes back after a restart until the profile is made, '
      'and not after', () async {
    final user = _user(providerId: 'apple.com');

    final first = await start(user);
    expect(first.termsPending, isTrue);
    first.dispose();

    final afterRestart = await start(user);
    expect(afterRestart.termsPending, isTrue, reason: 'nothing was answered');
    afterRestart.dispose();

    when(
      () => repo.fetchProfile('uid-anna'),
    ).thenAnswer((_) async => profile('Anna'));
    final afterAccept = await start(user);
    expect(afterAccept.termsPending, isFalse);
    verify(() => repo.ensureBaseUserDocument('uid-anna')).called(1);
  });

  test('an account with a password never meets the step', () async {
    final service = await start(_user(providerId: 'password'));

    expect(service.termsPending, isFalse);
  });

  test('a returning account with a profile is not asked, and its profile '
      'is read once', () async {
    when(
      () => repo.fetchProfile('uid-anna'),
    ).thenAnswer((_) async => profile('Anna'));

    final service = await start(_user(providerId: 'google.com'));

    expect(service.termsPending, isFalse);
    expect(service.currentUserProfile?.displayName, 'Anna');
    verify(() => repo.fetchProfile('uid-anna')).called(1);
  });

  test(
    'no address from the provider is a retryable error, not a wait (C2)',
    () async {
      final service = await start(_user(providerId: 'apple.com', email: null));

      expect(service.termsPending, isFalse);
      expect(service.hasError, isTrue);
      expect(service.error, AppLocale.current.providerTermsNoEmail);
      verifyNever(() => repo.ensureBaseUserDocument(any()));
    },
  );

  test('a guest (anonymous, no address) is neither asked nor given the '
      'no-address error (BUT-920)', () async {
    final service = await start(
      MockUser(uid: 'uid-guest', isAnonymous: true, providerData: []),
    );

    expect(service.termsPending, isFalse);
    expect(service.hasError, isFalse);
  });

  test('accepting stops when the acceptance cannot be recorded', () async {
    final service = await start(_user(providerId: 'google.com'));
    when(
      () => repo.recordTermsAcceptance(any(), any()),
    ).thenThrow(Exception('unavailable'));

    final ok = await service.acceptProviderTerms(displayName: 'Anna');

    expect(ok, isFalse);
    expect(service.error, AppLocale.current.providerTermsSaveFailed);
    expect(service.termsPending, isTrue, reason: 'still unanswered');
    verifyNever(() => repo.ensureBaseUserDocument(any()));
  });

  test(
    'accepting records the current terms version before anything else',
    () async {
      final service = await start(_user(providerId: 'google.com'));
      final order = <String>[];
      when(() => repo.recordTermsAcceptance(any(), any())).thenAnswer((
        _,
      ) async {
        order.add('terms');
      });
      when(() => repo.ensureBaseUserDocument(any())).thenAnswer((_) async {
        order.add('base');
      });

      when(
        () => repo.saveProfile(
          any(),
          writeHouseholdSize: any(named: 'writeHouseholdSize'),
        ),
      ).thenAnswer((invocation) async {
        order.add('profile');
        final saved = invocation.positionalArguments.first as UserProfile;
        when(
          () => repo.fetchProfile('uid-anna'),
        ).thenAnswer((_) async => saved);
      });

      final ok = await service.acceptProviderTerms(displayName: 'Anna');

      expect(ok, isTrue);
      verify(
        () => repo.recordTermsAcceptance(
          'uid-anna',
          UserService.currentTermsVersion,
        ),
      ).called(1);
      expect(order.first, 'terms');
      expect(
        order.where((step) => step == 'base'),
        hasLength(1),
        reason: 'one base-document write per sign-up',
      );
      expect(service.termsPending, isFalse);
      expect(service.currentUserProfile?.displayName, 'Anna');
    },
  );

  test('an acceptance whose profile was never made asks again, and the '
      "profile is never made from the provider's full name", () async {
    final service = await start(_user(providerId: 'google.com'));
    when(
      () => repo.recordTermsAcceptance(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => repo.saveProfile(
        any(),
        writeHouseholdSize: any(named: 'writeHouseholdSize'),
      ),
    ).thenThrow(Exception('unavailable'));

    expect(await service.acceptProviderTerms(displayName: 'Anna'), isFalse);
    verify(() => repo.recordTermsAcceptance('uid-anna', any())).called(1);

    // The record now exists and the profile does not. Neither the retry
    // button nor a restart may make the profile behind the step's back.
    when(
      () => repo.saveProfile(
        any(),
        writeHouseholdSize: any(named: 'writeHouseholdSize'),
      ),
    ).thenAnswer((_) async {});
    await service.retryLoadProfile();
    expect(service.termsPending, isTrue, reason: 'after the retry button');
    service.dispose();

    final afterRestart = await start(_user(providerId: 'google.com'));
    expect(afterRestart.termsPending, isTrue, reason: 'after a restart');
    expect(afterRestart.currentUserProfile, isNull);
    verifyNever(
      () => repo.saveProfile(
        any(
          that: isA<UserProfile>().having(
            (p) => p.displayName,
            'displayName',
            'Anna Andersson',
          ),
        ),
        writeHouseholdSize: any(named: 'writeHouseholdSize'),
      ),
    );
  });

  test(
    'an e-mail sign-up still records the acceptance with its profile',
    () async {
      when(
        () => repo.saveProfile(
          any(),
          writeHouseholdSize: any(named: 'writeHouseholdSize'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => repo.recordTermsAcceptance(any(), any()),
      ).thenAnswer((_) async {});
      when(() => auth.registrationDisplayNameFor(any())).thenReturn(null);

      final service = await start(_user(providerId: 'password'));

      expect(service.currentUserProfile, isNotNull);
      verify(
        () => repo.recordTermsAcceptance(
          'uid-anna',
          UserService.currentTermsVersion,
        ),
      ).called(1);
    },
  );
}
