// BUT-1507: at sign-in `initialize()` and the authStateChanges listener both
// start a profile load. For a brand-new account both saw "no profile" and both
// created it, so the second whole-settings save could land after
// markOnboardingComplete.

import 'dart:async';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/core/di/household_links_from_locator.dart';
import 'package:butlery/services/family/own_allergen_share_mirror.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/permission_service.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../test_support/base_unit_test.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockUserRepository extends Mock implements UserRepository {}

class _MockFirestoreRepository extends Mock implements FirestoreRepository {}

void main() {
  late _MockAuthRepository auth;
  late _MockUserRepository repo;

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
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  test('a new account is created once when initialize() and the auth '
      'listener load at the same time', () async {
    final user = MockUser(uid: 'uid-anna', email: 'anna@example.com');
    when(() => auth.currentUser).thenReturn(user);
    // Emits right after initialize() subscribes, while its own load is still
    // waiting on the profile read.
    when(() => auth.authStateChanges()).thenAnswer((_) => Stream.value(user));
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

    final release = Completer<void>();
    when(() => repo.fetchProfile(any())).thenAnswer((_) async {
      await release.future;
      return null;
    });

    final service = UserService(
      repository: repo,
      authRepository: auth,
      firestoreRepository: _MockFirestoreRepository(),
      permissionService: () => TestServiceLocator.get<PermissionService>(),
      profileSearchability: () => null,
      allergenShareMirror: OwnAllergenShareMirror(householdLinksFromLocator()),
    );

    addTearDown(service.dispose);

    final init = service.initialize();
    await pumpEventQueue();
    release.complete();
    await init;
    await pumpEventQueue();

    verify(
      () => repo.saveProfile(
        any(),
        writeHouseholdSize: any(named: 'writeHouseholdSize'),
        writeAvatarUrl: any(named: 'writeAvatarUrl'),
      ),
    ).called(1);
    expect(service.currentUserProfile, isNotNull);
  });

  test('a sign-in after a finished load reads the profile afresh instead of '
      'reusing the completed load', () async {
    final user = MockUser(uid: 'uid-anna', email: 'anna@example.com');
    final authEvents = StreamController<MockUser?>();
    addTearDown(authEvents.close);
    when(() => auth.currentUser).thenReturn(user);
    when(() => auth.authStateChanges()).thenAnswer((_) => authEvents.stream);
    when(() => repo.ensureBaseUserDocument(any())).thenAnswer((_) async {});
    // An existing profile, so no create path adds extra fetchProfile calls.
    final existing = UserProfile(
      uid: 'uid-anna',
      displayName: 'Anna',
      email: 'anna@example.com',
      isOnline: false,
      joinedAt: DateTime(2026),
      lastActiveAt: DateTime(2026),
    );
    when(() => repo.fetchProfile('uid-anna')).thenAnswer((_) async => existing);

    final service = UserService(
      repository: repo,
      authRepository: auth,
      firestoreRepository: _MockFirestoreRepository(),
      permissionService: () => TestServiceLocator.get<PermissionService>(),
      profileSearchability: () => null,
      allergenShareMirror: OwnAllergenShareMirror(householdLinksFromLocator()),
    );
    addTearDown(service.dispose);

    await service.initialize();
    await pumpEventQueue();
    verify(() => repo.fetchProfile('uid-anna')).called(1);

    authEvents.add(null);
    await pumpEventQueue();
    authEvents.add(user);
    await pumpEventQueue();

    verify(() => repo.fetchProfile('uid-anna')).called(1);
    expect(service.currentUserProfile?.uid, 'uid-anna');
  });
}
