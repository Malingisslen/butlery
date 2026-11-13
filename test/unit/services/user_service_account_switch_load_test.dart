// A profile load still waiting on Firestore when the account switches must not
// put the account that left into the memory, cache or writes of the one now
// signed in.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/di/household_links_from_locator.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/services/family/own_allergen_share_mirror.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/social/profile_searchability_service.dart';
import 'package:butlery/services/user_service.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../test_support/base_unit_test.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockUserRepository extends Mock implements UserRepository {}

class _MockFirestoreRepository extends Mock implements FirestoreRepository {}

class _MockSearchability extends Mock implements ProfileSearchabilityService {}

UserProfile _profile(String uid, String name) => UserProfile(
  uid: uid,
  displayName: name,
  email: '$uid@example.com',
  isOnline: false,
  joinedAt: DateTime(2026),
  lastActiveAt: DateTime(2026),
);

void main() {
  late _MockAuthRepository auth;
  late _MockUserRepository repo;
  late StreamController<User?> authEvents;
  User? signedIn;

  final anna = MockUser(uid: 'uid-anna', email: 'anna@example.com');
  final bo = MockUser(uid: 'uid-bo', email: 'bo@example.com');

  setUpAll(() async {
    registerFallbackValue(_profile('fallback', 'x'));
    production.ServiceLocator.initialize(DIContainer());
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    auth = _MockAuthRepository();
    repo = _MockUserRepository();
    authEvents = StreamController<User?>();
    signedIn = anna;
    when(() => auth.currentUser).thenAnswer((_) => signedIn);
    when(() => auth.authStateChanges()).thenAnswer((_) => authEvents.stream);
    when(() => auth.registrationDisplayNameFor(any())).thenReturn(null);
    when(() => repo.ensureBaseUserDocument(any())).thenAnswer((_) async {});
    when(
      () => repo.recordTermsAcceptance(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => repo.saveProfile(
        any(),
        writeHouseholdSize: any(named: 'writeHouseholdSize'),
        writeAvatarUrl: any(named: 'writeAvatarUrl'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    await authEvents.close();
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  UserService buildService({ProfileSearchabilityService? searchability}) {
    final service = UserService(
      repository: repo,
      authRepository: auth,
      firestoreRepository: _MockFirestoreRepository(),
      permissionService: () => TestServiceLocator.get<PermissionService>(),
      profileSearchability: () => searchability,
      allergenShareMirror: OwnAllergenShareMirror(householdLinksFromLocator()),
    );
    addTearDown(service.dispose);
    return service;
  }

  Future<void> switchToBo() async {
    signedIn = null;
    authEvents.add(null);
    await pumpEventQueue();
    signedIn = bo;
    authEvents.add(bo);
    await pumpEventQueue();
  }

  test('the account that left does not replace the new account\'s profile '
      'when its read answers last', () async {
    final annaRead = Completer<UserProfile?>();
    when(
      () => repo.fetchProfile('uid-anna'),
    ).thenAnswer((_) => annaRead.future);
    when(
      () => repo.fetchProfile('uid-bo'),
    ).thenAnswer((_) async => _profile('uid-bo', 'Bo'));

    final service = buildService();
    final init = service.initialize();
    await pumpEventQueue();

    await switchToBo();
    expect(service.currentUserProfile?.uid, 'uid-bo');

    annaRead.complete(_profile('uid-anna', 'Anna'));
    await init;
    await pumpEventQueue();

    expect(service.currentUserProfile?.uid, 'uid-bo');
    expect(service.currentUserProfile?.displayName, 'Bo');
  });

  test('a missing profile read for the account that left creates nothing '
      'and records no terms once another account is signed in', () async {
    final annaRead = Completer<UserProfile?>();
    when(
      () => repo.fetchProfile('uid-anna'),
    ).thenAnswer((_) => annaRead.future);
    when(
      () => repo.fetchProfile('uid-bo'),
    ).thenAnswer((_) async => _profile('uid-bo', 'Bo'));

    final service = buildService();
    final init = service.initialize();
    await pumpEventQueue();

    await switchToBo();
    annaRead.complete(null);
    await init;
    await pumpEventQueue();

    verifyNever(
      () => repo.saveProfile(
        any(),
        writeHouseholdSize: any(named: 'writeHouseholdSize'),
        writeAvatarUrl: any(named: 'writeAvatarUrl'),
      ),
    );
    verifyNever(() => repo.recordTermsAcceptance(any(), any()));
    expect(service.currentUserProfile?.uid, 'uid-bo');
  });

  test(
    'a load that loses its account to a sign-out leaves nothing behind',
    () async {
      final annaRead = Completer<UserProfile?>();
      when(
        () => repo.fetchProfile('uid-anna'),
      ).thenAnswer((_) => annaRead.future);

      final service = buildService();
      final init = service.initialize();
      await pumpEventQueue();

      signedIn = null;
      authEvents.add(null);
      await pumpEventQueue();

      annaRead.complete(_profile('uid-anna', 'Anna'));
      await init;
      await pumpEventQueue();

      expect(service.currentUserProfile, isNull);
    },
  );

  test('a profile save that loses its account to a switch does not re-assert '
      'searchability, which would act on the account now signed in', () async {
    final minorAnna = _profile(
      'uid-anna',
      'Anna',
    ).copyWith(isMinor: true, isSearchable: true);
    when(
      () => repo.fetchProfile('uid-anna'),
    ).thenAnswer((_) async => minorAnna);
    when(
      () => repo.fetchPersistedSearchable('uid-anna'),
    ).thenAnswer((_) async => true);
    final save = Completer<void>();
    when(
      () => repo.saveProfile(
        any(),
        writeHouseholdSize: any(named: 'writeHouseholdSize'),
        writeAvatarUrl: any(named: 'writeAvatarUrl'),
      ),
    ).thenAnswer((_) => save.future);
    final searchability = _MockSearchability();
    when(
      () => searchability.setSearchable(any()),
    ).thenAnswer((_) async => true);

    final service = buildService(searchability: searchability);
    await service.initialize();
    expect(service.currentUserProfile?.isMinor, isTrue);

    final saving = service.createOrUpdateProfile(displayName: 'Anna B');
    await pumpEventQueue();
    signedIn = bo;
    save.complete();
    await saving;

    verifyNever(() => searchability.setSearchable(any()));
    expect(service.currentUserProfile?.displayName, 'Anna');
  });

  test('without a switch the same save does re-assert the minor\'s '
      'searchability', () async {
    final minorAnna = _profile(
      'uid-anna',
      'Anna',
    ).copyWith(isMinor: true, isSearchable: true);
    when(
      () => repo.fetchProfile('uid-anna'),
    ).thenAnswer((_) async => minorAnna);
    when(
      () => repo.fetchPersistedSearchable('uid-anna'),
    ).thenAnswer((_) async => true);
    final searchability = _MockSearchability();
    when(
      () => searchability.setSearchable(any()),
    ).thenAnswer((_) async => true);

    final service = buildService(searchability: searchability);
    await service.initialize();
    await service.createOrUpdateProfile(displayName: 'Anna B');

    verify(() => searchability.setSearchable(true)).called(1);
    expect(service.currentUserProfile?.displayName, 'Anna B');
  });
}
