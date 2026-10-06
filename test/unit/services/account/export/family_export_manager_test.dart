/// Unit tests for FamilyExportManager (GDPR Art 15/20, BUT family Phase 5).
///
/// Subject: a user's export includes the household's diner profiles (shared
/// data they co-control) but only the family verdicts that are THEIRS or that
/// THEY entered — never another member's private verdict.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/models/family_rating.dart';
import 'package:butlery/models/household.dart';
import 'package:butlery/repositories/firebase/firebase_diner_profile_repository.dart';
import 'package:butlery/repositories/firebase/firebase_family_rating_repository.dart';
import 'package:butlery/repositories/firebase/firebase_household_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/account/export/family_export_manager.dart';

import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';
import '../../../../test_support/base_unit_test.dart';

const _malin = 'user-malin';
const _johan = 'user-johan';
const _hh = 'hh-duo';
const _recipe = 'recipe-1';

void main() {
  late FakeFirebaseFirestore fs;
  late FamilyExportManager manager;

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

    fs = FakeFirebaseFirestore();
    final hh = Household(
      id: _hh,
      name: Household.defaultName,
      members: [
        HouseholdMember(
          userId: _malin,
          permission: SharedListPermission.admin,
          addedAt: DateTime.utc(2026, 1, 1),
        ),
        HouseholdMember(
          userId: _johan,
          permission: SharedListPermission.edit,
          addedAt: DateTime.utc(2026, 1, 1),
        ),
      ],
      createdBy: _malin,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    await fs.collection('households').doc(_hh).set(hh.toFirestore());

    final householdRepo = FirebaseHouseholdRepository(
      firestore: fs,
      authRepository: TestServiceLocator.get<AuthRepository>(),
    );
    final dinerRepo = FirebaseDinerProfileRepository(
      firestore: fs,
      authRepository: TestServiceLocator.get<AuthRepository>(),
      householdRepository: householdRepo,
    );
    final ratingRepo = FirebaseFamilyRatingRepository(
      firestore: fs,
      authRepository: TestServiceLocator.get<AuthRepository>(),
      householdRepository: householdRepo,
    );

    manager = FamilyExportManager(
      householdRepository: householdRepo,
      dinerProfileRepository: dinerRepo,
      familyRatingRepository: ratingRepo,
    );

    // A managed guest (no consent needed).
    await dinerRepo.create(
      DinerProfile.create(
        householdId: _hh,
        name: 'Mormor',
        ageBand: DinerAgeBand.adult,
        createdBy: _malin,
      ),
    );

    // Seed verdicts directly so we can set arbitrary memberId/enteredByUid
    // (the repo would pin enteredByUid == caller).
    Future<void> seed(FamilyRating r) => fs
        .collection(FirestoreCollections.familyRatings)
        .doc(r.id)
        .set(
          r.toFirestore(),
        );

    await seed(
      FamilyRating.create(
        recipeId: _recipe,
        householdId: _hh,
        memberId: _malin,
        memberType: HouseholdMemberType.user,
        stars: 4,
        enteredByUid: _malin, // Malin's own verdict
      ),
    );
    await seed(
      FamilyRating.create(
        recipeId: _recipe,
        householdId: _hh,
        memberId: 'diner-emma',
        memberType: HouseholdMemberType.profile,
        stars: 5,
        enteredByUid: _malin, // entered BY Malin for a child
      ),
    );
    await seed(
      FamilyRating.create(
        recipeId: _recipe,
        householdId: _hh,
        memberId: _johan,
        memberType: HouseholdMemberType.user,
        stars: 2,
        enteredByUid: _johan, // Johan's OWN verdict — not Malin's to export
      ),
    );
  });

  test('exports the household diner profiles', () async {
    final out = await manager.exportFamily(_malin);
    expect(out['diner_profiles_count'], 1);
    final names = (out['diner_profiles'] as List)
        .map((d) => (d as Map)['name'])
        .toList();
    expect(names, contains('Mormor'));
  });

  test('includes only the caller\'s own and caller-entered verdicts', () async {
    final out = await manager.exportFamily(_malin);

    expect(
      out['family_ratings_count'],
      2,
      reason: "Malin's own + the one she entered for a child",
    );
    final memberIds = (out['family_ratings'] as List)
        .map((r) => (r as Map)['memberId'])
        .toSet();
    expect(memberIds, containsAll(<String>[_malin, 'diner-emma']));
    expect(
      memberIds,
      isNot(contains(_johan)),
      reason:
          "another member's private verdict must never leak into the export",
    );
  });

  test(
    'a different uid yields an empty section — never the caller\'s data',
    () async {
      // getForUser is caller-scoped, so exporting "someone else" returns an empty
      // section, NOT the duo household's profiles/verdicts — the export can't be
      // coerced into dumping another household by passing its uid. And empty is
      // distinguishable from a failure: no 'error' key.
      final out = await manager.exportFamily('user-stranger');

      expect(out['diner_profiles_count'], 0);
      expect(out['family_ratings_count'], 0);
      expect(out['diner_profiles'], isEmpty);
      expect(out['family_ratings'], isEmpty);
      expect(out.containsKey('error'), isFalse);
    },
  );

  test(
    'does not create a household as a side effect (read-only export)',
    () async {
      // A pure access request must not mutate. Export a uid with no household,
      // then confirm none was written for it.
      await manager.exportFamily('user-no-household');

      final households = await fs
          .collection('households')
          .where('createdBy', isEqualTo: 'user-no-household')
          .get();
      expect(
        households.docs,
        isEmpty,
        reason: 'Article 15 access must never create data',
      );
    },
  );

  test('a member of two households gets both: the active one at the top, the '
      'other beside it (BUT-2267)', () async {
    // Malin joined a friend's group household and keeps her own. Both hold
    // data about her, so an access request that exported one would be short.
    final joined = Household(
      id: 'hh-joined',
      name: Household.defaultName,
      members: [
        HouseholdMember(
          userId: 'host',
          permission: SharedListPermission.admin,
          addedAt: DateTime.utc(2026, 2, 1),
        ),
        HouseholdMember(
          userId: _malin,
          permission: SharedListPermission.view,
          addedAt: DateTime.utc(2026, 2, 1),
        ),
      ],
      createdBy: 'host',
      createdAt: DateTime.utc(2026, 2, 1),
      updatedAt: DateTime.utc(2026, 2, 1),
      sourceGroupId: 'g1',
      sourceGroupOwnerId: 'host',
    );
    await fs.collection('households').doc(joined.id).set(joined.toFirestore());

    final out = await manager.exportFamily(_malin);

    expect(out['household_id'], 'hh-joined');
    expect(out['diner_profiles_count'], 0);
    final others = out['other_households'] as List;
    expect(others, hasLength(1));
    final other = others.single as Map;
    expect(other['household_id'], _hh);
    expect(other['diner_profiles_count'], 1);
    expect(other['family_ratings_count'], 2);
  });

  test('a household the requester joined exports only the diners they '
      'entered, never the host\'s family (BUT-2267)', () async {
    final joined = Household(
      id: 'hh-joined',
      name: Household.defaultName,
      members: [
        HouseholdMember(
          userId: 'host',
          permission: SharedListPermission.admin,
          addedAt: DateTime.utc(2026, 2, 1),
        ),
        HouseholdMember(
          userId: _malin,
          permission: SharedListPermission.view,
          addedAt: DateTime.utc(2026, 2, 1),
        ),
      ],
      createdBy: 'host',
      createdAt: DateTime.utc(2026, 2, 1),
      updatedAt: DateTime.utc(2026, 2, 1),
      sourceGroupId: 'g1',
      sourceGroupOwnerId: 'host',
    );
    await fs.collection('households').doc(joined.id).set(joined.toFirestore());
    Future<void> seedDiner(String id, String name, String createdBy) => fs
        .collection(FirestoreCollections.dinerProfiles)
        .doc(id)
        .set(
          DinerProfile.create(
            householdId: joined.id,
            name: name,
            ageBand: DinerAgeBand.adult,
            createdBy: createdBy,
          ).toFirestore(),
        );
    await seedDiner('host-child', 'Värdens barn', 'host');
    await seedDiner('malins-guest', 'Malins gäst', _malin);

    final out = await manager.exportFamily(_malin);

    expect(out['household_id'], 'hh-joined');
    expect(out['diner_profiles_count'], 1);
    final names = (out['diner_profiles'] as List)
        .map((d) => (d as Map)['name'])
        .toList();
    expect(names, ['Malins gäst']);
  });

  test('a household the requester created exports every diner in it, '
      'including ones another member entered', () async {
    await fs
        .collection(FirestoreCollections.dinerProfiles)
        .doc('johans-guest')
        .set(
          DinerProfile.create(
            householdId: _hh,
            name: 'Johans gäst',
            ageBand: DinerAgeBand.adult,
            createdBy: _johan,
          ).toFirestore(),
        );

    final out = await manager.exportFamily(_malin);

    expect(out['diner_profiles_count'], 2);
  });

  test('a single household exports no other_households key', () async {
    final out = await manager.exportFamily(_malin);
    expect(out['household_id'], _hh);
    expect(out.containsKey('other_households'), isFalse);
  });
}
