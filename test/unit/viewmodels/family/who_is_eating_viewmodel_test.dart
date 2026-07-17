/// Unit tests for WhoIsEatingViewModel.
///
/// The subject is the "remember last time" attendance seeding: the picker must
/// pre-select the members of the caller's most recent attended cook event,
/// intersected with the CURRENT roster (a since-removed member must not
/// reappear), and fall back to everyone when there is no usable prior set.
/// A REAL FirebaseCookEventRepository / household / roster stack on a fake
/// store exercises the seeding end-to-end; the VM never writes.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/repositories/firebase/firebase_cook_event_repository.dart';
import 'package:butlery/repositories/firebase/firebase_diner_profile_repository.dart';
import 'package:butlery/repositories/firebase/firebase_household_repository.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/cook_event_repository.dart';
import 'package:butlery/repositories/interfaces/diner_profile_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/family/who_is_eating_viewmodel.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

const _malin = 'user-malin';

void main() {
  late FakeFirebaseFirestore fs;
  late HouseholdRepository householdRepo;
  late DinerProfileRepository dinerRepo;
  late String householdId;

  setUpAll(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  setUp(() async {
    (TestServiceLocator.get<AuthRepository>() as FakeAuthRepository)
        .setAuthState(
          user: FakeUser(uid: _malin),
          userId: _malin,
          isAuthenticated: true,
        );
    (TestServiceLocator.get<UserService>() as MockUserService).setUserState(
      users: {
        _malin: MockFactory.createUserProfile(
          userId: _malin,
          displayName: 'Malin',
        ),
      },
    );
    TestServiceLocator.registerSingleton<PermissionService>(
      MockFactory.createPermissionService(currentUserId: _malin),
    );

    fs = FakeFirebaseFirestore();
    householdRepo = FirebaseHouseholdRepository(
      firestore: fs,
      authRepository: TestServiceLocator.get<AuthRepository>(),
    );
    dinerRepo = FirebaseDinerProfileRepository(
      firestore: fs,
      authRepository: TestServiceLocator.get<AuthRepository>(),
      householdRepository: householdRepo,
    );
    final cookEventRepo = FirebaseCookEventRepository(
      firestore: fs,
      authRepository: TestServiceLocator.get<AuthRepository>(),
      recipeRepository: FirebaseRecipeRepository(
        firestore: fs,
        authRepository: TestServiceLocator.get<AuthRepository>(),
      ),
    );
    TestServiceLocator.registerSingleton<HouseholdRepository>(householdRepo);
    TestServiceLocator.registerSingleton<DinerProfileRepository>(dinerRepo);
    TestServiceLocator.registerSingleton<CookEventRepository>(cookEventRepo);
    TestServiceLocator.registerSingleton<HouseholdRosterService>(
      HouseholdRosterService(),
    );

    final household = await householdRepo.ensureForUser(_malin);
    householdId = household.id;
  });

  /// Add an adult guest diner (no consent needed) and return its id.
  Future<String> addGuest(String name) async {
    await dinerRepo.create(
      DinerProfile.create(
        householdId: householdId,
        name: name,
        ageBand: DinerAgeBand.adult,
        createdBy: _malin,
      ),
    );
    final diners = await dinerRepo.getByHousehold(householdId);
    return diners.firstWhere((d) => d.name == name).id;
  }

  /// Seed a cook event for Malin at [at] with the given attendees (written
  /// directly so the FieldValue-freezing logCookEvent batch is avoided).
  Future<void> seedCookEvent(DateTime at, List<String> attendees) async {
    await fs
        .collection(FirestoreCollections.recipeCookEvents)
        .doc(_malin)
        .collection(FirestoreCollections.recipeCookEventEntries)
        .doc()
        .set({
          'recipeId': 'r1',
          'cookedAt': Timestamp.fromDate(at),
          if (attendees.isNotEmpty) 'attendeeMemberIds': attendees,
        });
  }

  test('first use (no prior attendance) selects everyone', () async {
    final guest = await addGuest('Mormor');

    final vm = WhoIsEatingViewModel();
    await vm.load();

    expect(vm.hasError, isFalse);
    expect(vm.roster.length, 2);
    expect(vm.isSelected(_malin), isTrue);
    expect(vm.isSelected(guest), isTrue);
    expect(vm.selectedCount, 2);
  });

  test(
    'remembers last time — only the prior attendees are pre-ticked',
    () async {
      final present = await addGuest('Mormor');
      final absent = await addGuest('Farfar');

      // Last meal: Malin + Mormor ate; Farfar did not.
      await seedCookEvent(DateTime(2026, 6, 20), [_malin, present]);

      final vm = WhoIsEatingViewModel();
      await vm.load();

      expect(vm.isSelected(_malin), isTrue);
      expect(vm.isSelected(present), isTrue);
      expect(
        vm.isSelected(absent),
        isFalse,
        reason: 'someone absent last time should not be pre-selected',
      );
      expect(vm.selectedCount, 2);
    },
  );

  test('a remembered member no longer in the roster is dropped', () async {
    await addGuest('Mormor');

    // Prior set names a diner id that has since been removed from the household.
    await seedCookEvent(DateTime(2026, 6, 20), [_malin, 'ghost-diner-id']);

    final vm = WhoIsEatingViewModel();
    await vm.load();

    expect(vm.isSelected(_malin), isTrue);
    expect(
      vm.isSelected('ghost-diner-id'),
      isFalse,
      reason: 'a since-removed member must not reappear as eating',
    );
    // Seed was non-empty after intersection → do NOT fall back to everyone.
    expect(vm.selectedCount, 1);
  });

  test('falls back to everyone when NONE of the prior set survives', () async {
    final guest = await addGuest('Mormor');

    // Every remembered attendee has since left the household (no owner in the
    // set either) → the intersection is empty → re-select everyone. Guards the
    // `seed.isEmpty ? rosterIds : seed` branch, which the owner-always-present
    // cases never exercise.
    await seedCookEvent(DateTime(2026, 6, 20), ['ghost-1', 'ghost-2']);

    final vm = WhoIsEatingViewModel();
    await vm.load();

    expect(vm.isSelected(_malin), isTrue);
    expect(vm.isSelected(guest), isTrue);
    expect(vm.selectedCount, 2);
  });

  test('load notifies listeners so the picker UI rebuilds', () async {
    await addGuest('Mormor');
    final vm = WhoIsEatingViewModel();
    var notifications = 0;
    vm.addListener(() => notifications++);

    await vm.load();

    expect(
      notifications,
      greaterThanOrEqualTo(1),
      reason:
          'a load that populates state but never notifies leaves the '
          'picker blank',
    );
  });

  test('the most recent attended event wins over an older one', () async {
    final guest = await addGuest('Mormor');

    await seedCookEvent(DateTime(2026, 6, 1), [_malin]); // older
    await seedCookEvent(DateTime(2026, 6, 20), [_malin, guest]); // newer

    final vm = WhoIsEatingViewModel();
    await vm.load();

    expect(vm.isSelected(guest), isTrue);
    expect(vm.selectedCount, 2);
  });

  test('toggle flips a member in and out of the selection', () async {
    final guest = await addGuest('Mormor');
    final vm = WhoIsEatingViewModel();
    await vm.load();

    expect(vm.isSelected(guest), isTrue);
    vm.toggle(guest);
    expect(vm.isSelected(guest), isFalse);
    vm.toggle(guest);
    expect(vm.isSelected(guest), isTrue);
  });

  // BUT-1611: the presence flow reuses this VM with an explicit seed and the
  // read-only (no-create) roster path.
  group('BUT-1611 presence seed', () {
    test(
      'an explicit seed pre-selects exactly that set, not cook history',
      () async {
        final present = await addGuest('Mormor');
        final absent = await addGuest('Farfar');
        // Cook history would pre-tick Malin + Mormor — an explicit seed must win.
        await seedCookEvent(DateTime(2026, 6, 20), [_malin, present]);

        final vm = WhoIsEatingViewModel();
        await vm.load(seedMemberIds: [absent], allowCreateHousehold: false);

        expect(vm.isSelected(absent), isTrue);
        expect(vm.isSelected(_malin), isFalse);
        expect(vm.isSelected(present), isFalse);
        expect(vm.selectedCount, 1);
      },
    );

    test('an empty seed selects nobody (deliberate "nobody home")', () async {
      await addGuest('Mormor');
      final vm = WhoIsEatingViewModel();
      await vm.load(seedMemberIds: const [], allowCreateHousehold: false);
      expect(vm.selectedCount, 0);
    });

    test('a seed member no longer in the roster is dropped', () async {
      final guest = await addGuest('Mormor');
      final vm = WhoIsEatingViewModel();
      await vm.load(
        seedMemberIds: [guest, 'ghost-diner-id'],
        allowCreateHousehold: false,
      );
      expect(vm.isSelected(guest), isTrue);
      expect(vm.isSelected('ghost-diner-id'), isFalse);
      expect(vm.selectedCount, 1);
    });

    test(
      'read-only load for a household-less account creates NO household',
      () async {
        // BUT-1611's defining safety property: opening the weekly menu must
        // never CREATE a household. A fresh account with no household loads an
        // empty roster (feature stays invisible) and — critically — no household
        // is written as a side effect of the read.
        const loner = 'user-loner';
        TestServiceLocator.registerSingleton<PermissionService>(
          MockFactory.createPermissionService(currentUserId: loner),
        );
        expect(
          await householdRepo.getForUser(loner),
          isEmpty,
          reason: 'precondition: the loner has no household',
        );

        final vm = WhoIsEatingViewModel();
        await vm.load(seedMemberIds: const ['x'], allowCreateHousehold: false);

        expect(vm.hasError, isFalse);
        expect(vm.roster, isEmpty);
        expect(vm.selectedCount, 0);
        expect(
          await householdRepo.getForUser(loner),
          isEmpty,
          reason: 'opening the menu must not create a household on read',
        );
      },
    );
  });
}
