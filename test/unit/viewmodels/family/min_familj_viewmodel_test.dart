/// Unit tests for MinFamiljViewModel.
///
/// The subject is the two-tier GDPR consent gating and the CRUD flow for
/// non-account family members. A REAL FirebaseDinerProfileRepository +
/// FirebaseHouseholdRepository on a fake store exercise the consent invariants
/// end-to-end (the repo also enforces them); the ViewModel's job is to surface
/// the gates as user errors and shape the consent record correctly.
library;

import 'package:clock/clock.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/models/household.dart';
import 'package:butlery/repositories/firebase/firebase_diner_profile_repository.dart';
import 'package:butlery/repositories/firebase/firebase_household_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/diner_profile_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/family/min_familj_viewmodel.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

const _malin = 'user-malin';

MinFamiljViewModel _vm() => MinFamiljViewModel();

const _johan = 'user-johan';

void main() {
  late DinerProfileRepository dinerRepo;
  late FakeFirebaseFirestore fs;

  setUpAll(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  setUp(() {
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
    final householdRepo = FirebaseHouseholdRepository(
      firestore: fs,
      authRepository: TestServiceLocator.get<AuthRepository>(),
    );
    dinerRepo = FirebaseDinerProfileRepository(
      firestore: fs,
      authRepository: TestServiceLocator.get<AuthRepository>(),
      householdRepository: householdRepo,
    );
    TestServiceLocator.registerSingleton<HouseholdRepository>(householdRepo);
    TestServiceLocator.registerSingleton<DinerProfileRepository>(dinerRepo);
    TestServiceLocator.registerSingleton<HouseholdRosterService>(
      HouseholdRosterService(),
    );
  });

  group('load', () {
    test('resolves the household and lists the account holder', () async {
      final vm = _vm();
      await vm.load();

      expect(vm.hasError, isFalse);
      expect(vm.householdId, isNotNull);
      expect(vm.accounts.map((a) => a.displayName), contains('Malin'));
      expect(vm.isAdmin(_malin), isTrue);
      expect(vm.familyMembers, isEmpty);
    });
  });

  group('saveFamilyMember — consent gates', () {
    test(
      'a minor without guardian consent is rejected, nothing persisted',
      () async {
        final vm = _vm();
        await vm.load();

        final ok = await vm.saveFamilyMember(
          name: 'Liam',
          ageBand: DinerAgeBand.child,
          guardianConsentGiven: false,
          allergenConsentGiven: false,
        );

        expect(ok, isFalse);
        expect(vm.hasError, isTrue);
        expect(vm.familyMembers, isEmpty);
      },
    );

    test('allergens without explicit allergen consent are rejected', () async {
      final vm = _vm();
      await vm.load();

      final ok = await vm.saveFamilyMember(
        name: 'Liam',
        ageBand: DinerAgeBand.child,
        guardianConsentGiven: true,
        allergenConsentGiven: false,
        allergenKeys: {'gluten'},
      );

      expect(ok, isFalse);
      expect(vm.familyMembers, isEmpty);
    });

    test('an empty name is rejected', () async {
      final vm = _vm();
      await vm.load();

      final ok = await vm.saveFamilyMember(
        name: '   ',
        ageBand: DinerAgeBand.adult,
        guardianConsentGiven: false,
        allergenConsentGiven: false,
      );

      expect(ok, isFalse);
      expect(vm.familyMembers, isEmpty);
    });

    test(
      'an adult guest with allergens still needs explicit allergen consent',
      () async {
        // Allergen consent is age-independent — an adult needs no guardian
        // consent, but storing their health data still requires Art. 9 consent.
        final vm = _vm();
        await vm.load();

        final ok = await vm.saveFamilyMember(
          name: 'Mormor',
          ageBand: DinerAgeBand.adult,
          guardianConsentGiven: false,
          allergenConsentGiven: false,
          allergenKeys: {'gluten'},
        );

        expect(ok, isFalse);
        expect(vm.familyMembers, isEmpty);
      },
    );
  });

  group('saveFamilyMember — happy paths', () {
    test(
      'a minor with consent + allergens persists with the right consent',
      () async {
        final vm = _vm();
        await vm.load();

        final ok = await vm.saveFamilyMember(
          name: 'Liam',
          ageBand: DinerAgeBand.child,
          avatarColor: '#3E6F8E',
          guardianConsentGiven: true,
          allergenConsentGiven: true,
          allergenKeys: {'gluten', 'mjölk'},
        );

        expect(ok, isTrue);
        expect(vm.familyMembers, hasLength(1));
        final liam = vm.familyMembers.single;
        expect(liam.name, 'Liam');
        expect(liam.ageBand, DinerAgeBand.child);
        expect(liam.guardianConsent, isNotNull);
        expect(liam.hasAllergenConsent, isTrue);
        expect(
          liam.allergenPreferences?.trackedAllergens,
          containsAll(<String>['gluten', 'mjölk']),
        );
      },
    );

    test('an adult guest with no allergens needs no consent record', () async {
      final vm = _vm();
      await vm.load();

      final ok = await vm.saveFamilyMember(
        name: 'Mormor',
        ageBand: DinerAgeBand.adult,
        guardianConsentGiven: false,
        allergenConsentGiven: false,
      );

      expect(ok, isTrue);
      final mormor = vm.familyMembers.single;
      expect(mormor.guardianConsent, isNull);
      expect(mormor.allergenPreferences, isNull);
    });
  });

  group('edit + consent withdrawal + delete', () {
    Future<DinerProfile> seedLiam(MinFamiljViewModel vm) async {
      await vm.saveFamilyMember(
        name: 'Liam',
        ageBand: DinerAgeBand.child,
        guardianConsentGiven: true,
        allergenConsentGiven: true,
        allergenKeys: {'gluten'},
      );
      return vm.familyMembers.single;
    }

    test('editing preserves the original consent attestation date', () async {
      final vm = _vm();
      await vm.load();
      final liam = await withClock(
        Clock.fixed(DateTime.utc(2026, 6, 1)),
        () => seedLiam(vm),
      );
      final originalAt = liam.guardianConsent!.at;

      await withClock(
        Clock.fixed(DateTime.utc(2026, 7, 1)),
        () => vm.saveFamilyMember(
          existing: liam,
          name: 'Liam B',
          ageBand: DinerAgeBand.child,
          guardianConsentGiven: true,
          allergenConsentGiven: true,
          allergenKeys: {'gluten'},
        ),
      );

      final updated = vm.familyMembers.single;
      expect(updated.name, 'Liam B');
      expect(updated.guardianConsent!.at.isAtSameMomentAs(originalAt), isTrue);
    });

    test(
      'withdrawing allergen consent erases allergens, keeps base consent',
      () async {
        final vm = _vm();
        await vm.load();
        final liam = await seedLiam(vm);

        final ok = await vm.withdrawAllergenConsent(liam);

        expect(ok, isTrue);
        final updated = vm.familyMembers.single;
        expect(updated.allergenPreferences, isNull);
        expect(updated.guardianConsent, isNotNull); // base consent stays
        expect(updated.hasAllergenConsent, isFalse);
      },
    );

    test('deleting removes the family member', () async {
      final vm = _vm();
      await vm.load();
      final liam = await seedLiam(vm);

      final ok = await vm.deleteFamilyMember(liam.id);

      expect(ok, isTrue);
      expect(vm.familyMembers, isEmpty);
    });
  });

  group('consent attribution', () {
    void actAs(String uid) {
      (TestServiceLocator.get<AuthRepository>() as FakeAuthRepository)
          .setAuthState(
            user: FakeUser(uid: uid),
            userId: uid,
            isAuthenticated: true,
          );
      TestServiceLocator.registerSingleton<PermissionService>(
        MockFactory.createPermissionService(currentUserId: uid),
      );
    }

    Future<void> seedDuoHousehold() async {
      final hh = Household(
        id: 'hh-duo',
        name: Household.defaultName,
        members: [
          HouseholdMember(
            userId: _malin,
            permission: SharedListPermission.admin,
            addedAt: DateTime.utc(2026, 1, 1),
          ),
          HouseholdMember(
            userId: _johan,
            permission: SharedListPermission.admin,
            addedAt: DateTime.utc(2026, 1, 1),
          ),
        ],
        createdBy: _malin,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      await fs.collection('households').doc(hh.id).set(hh.toFirestore());
    }

    test(
      'a second admin who adds allergen consent is credited, not the first',
      () async {
        await seedDuoHousehold();

        // Malin creates Liam with base (Art. 6) consent only — no allergens.
        actAs(_malin);
        final vmMalin = _vm();
        await vmMalin.load();
        await vmMalin.saveFamilyMember(
          name: 'Liam',
          ageBand: DinerAgeBand.child,
          guardianConsentGiven: true,
          allergenConsentGiven: false,
        );
        expect(vmMalin.familyMembers.single.guardianConsent!.byUid, _malin);

        // Johan later upgrades: adds allergens + Art. 9 allergen consent.
        actAs(_johan);
        final vmJohan = _vm();
        await vmJohan.load();
        await vmJohan.saveFamilyMember(
          existing: vmJohan.familyMembers.single,
          name: 'Liam',
          ageBand: DinerAgeBand.child,
          guardianConsentGiven: true,
          allergenConsentGiven: true,
          allergenKeys: {'gluten'},
        );

        final upgraded = vmJohan.familyMembers.single;
        expect(upgraded.hasAllergenConsent, isTrue);
        expect(
          upgraded.guardianConsent!.byUid,
          _johan,
          reason: 'the allergen consent must credit whoever actually gave it',
        );
      },
    );
  });
}
