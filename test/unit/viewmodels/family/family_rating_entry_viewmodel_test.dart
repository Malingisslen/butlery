/// Unit tests for FamilyRatingEntryViewModel.
///
/// Subject: the "hand the phone around" entry — which diners are shown (the
/// present set, or the whole roster on manual entry), pre-fill from each
/// member's last verdict (latest-verdict-wins = an edit), and save that writes
/// a FamilyRating per rated row while SKIPPING empty rows. A real
/// FirebaseFamilyRatingRepository + roster stack on a fake store exercises it
/// end-to-end; the social mirror is a verifiable mock.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/models/family_rating.dart';
import 'package:butlery/repositories/firebase/firebase_diner_profile_repository.dart';
import 'package:butlery/repositories/firebase/firebase_family_rating_repository.dart';
import 'package:butlery/repositories/firebase/firebase_household_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/diner_profile_repository.dart';
import 'package:butlery/repositories/interfaces/family_rating_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/family/family_rating_service.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/operations/social_recipe_operations.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/family/family_rating_entry_viewmodel.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockUnifiedRecipeService extends Mock implements UnifiedRecipeService {}

class _MockSocialRecipeOperations extends Mock
    implements SocialRecipeOperations {}

class _MockFamilyRatingService extends Mock implements FamilyRatingService {}

const _malin = 'user-malin';
const _recipe = 'recipe-1';

void main() {
  late FakeFirebaseFirestore fs;
  late HouseholdRepository householdRepo;
  late DinerProfileRepository dinerRepo;
  late FamilyRatingService ratingService;
  late _MockSocialRecipeOperations socialOps;
  late String householdId;

  setUpAll(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
    registerFallbackValue(HouseholdMemberType.user);
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
    final ratingRepo = FirebaseFamilyRatingRepository(
      firestore: fs,
      authRepository: TestServiceLocator.get<AuthRepository>(),
      householdRepository: householdRepo,
    );
    TestServiceLocator.registerSingleton<HouseholdRepository>(householdRepo);
    TestServiceLocator.registerSingleton<DinerProfileRepository>(dinerRepo);
    TestServiceLocator.registerSingleton<FamilyRatingRepository>(ratingRepo);
    TestServiceLocator.registerSingleton<HouseholdRosterService>(
      HouseholdRosterService(),
    );

    // Social mirror is verifiable so the proxy-vs-self privacy contract can be
    // asserted on the save path.
    socialOps = _MockSocialRecipeOperations();
    when(
      () => socialOps.rateRecipe(
        recipeId: any(named: 'recipeId'),
        rating: any(named: 'rating'),
        review: any(named: 'review'),
      ),
    ).thenAnswer((_) async => true);
    final recipeService = _MockUnifiedRecipeService();
    when(() => recipeService.social).thenReturn(socialOps);
    TestServiceLocator.registerSingleton<UnifiedRecipeService>(recipeService);
    TestServiceLocator.registerSingleton<FamilyRatingService>(
      FamilyRatingService(),
    );
    ratingService = FamilyRatingService();

    final household = await householdRepo.ensureForUser(_malin);
    householdId = household.id;
  });

  Future<String> addDiner(String name, DinerAgeBand band) async {
    await dinerRepo.create(
      DinerProfile.create(
        householdId: householdId,
        name: name,
        ageBand: band,
        createdBy: _malin,
        // Minors require guardian consent at creation (Art. 6); guests/adults
        // don't. Allergen consent is irrelevant here (no allergens stored).
        guardianConsent: band.isMinor
            ? GuardianConsent(
                byUid: _malin,
                at: DateTime.utc(2026, 1, 1),
                consentVersion: DinerProfile.currentConsentVersion,
                includesAllergenConsent: false,
              )
            : null,
      ),
    );
    final diners = await dinerRepo.getByHousehold(householdId);
    return diners.firstWhere((d) => d.name == name).id;
  }

  test('present set is limited to the diners who ate', () async {
    final emma = await addDiner('Emma', DinerAgeBand.toddler);
    await addDiner('Farfar', DinerAgeBand.adult); // ate elsewhere, not present

    final vm = FamilyRatingEntryViewModel(
      recipeId: _recipe,
      presentMemberIds: [_malin, emma],
    );
    await vm.load();

    final ids = vm.present.map((m) => m.memberId).toList();
    expect(ids, containsAll(<String>[_malin, emma]));
    expect(ids.length, 2, reason: 'Farfar did not eat and must not appear');
  });

  test('manual entry (null present) shows the whole roster', () async {
    await addDiner('Emma', DinerAgeBand.toddler);

    final vm = FamilyRatingEntryViewModel(recipeId: _recipe);
    await vm.load();

    expect(vm.present.length, 2, reason: 'Malin + Emma');
  });

  test('rows pre-fill from the last stored verdict', () async {
    final emma = await addDiner('Emma', DinerAgeBand.toddler);
    await ratingService.rateAsFamily(
      recipeId: _recipe,
      householdId: householdId,
      memberId: emma,
      memberType: HouseholdMemberType.profile,
      stars: 3,
      enteredByUid: _malin,
    );

    final vm = FamilyRatingEntryViewModel(
      recipeId: _recipe,
      presentMemberIds: [_malin, emma],
    );
    await vm.load();

    expect(vm.starsFor(emma), 3, reason: 're-rating is an edit, not a reset');
    expect(vm.starsFor(_malin), 0, reason: 'unrated rows start empty');
    expect(vm.hasAnyRating, isTrue);
  });

  test('save writes a rating per rated row and SKIPS empty rows', () async {
    final emma = await addDiner('Emma', DinerAgeBand.toddler);
    final guest = await addDiner('Mormor', DinerAgeBand.adult);

    final vm = FamilyRatingEntryViewModel(
      recipeId: _recipe,
      presentMemberIds: [_malin, emma, guest],
    );
    await vm.load();
    vm.setStars(emma, 5);
    vm.setStars(_malin, 4);
    // guest left unrated → must not produce a write.

    final ok = await vm.save();
    expect(ok, isTrue);

    final stored = await ratingService.getMemberRatings(
      householdId: householdId,
      recipeId: _recipe,
    );
    final byMember = {for (final r in stored) r.memberId: r.stars};
    expect(byMember[emma], 5);
    expect(byMember[_malin], 4);
    expect(
      byMember.containsKey(guest),
      isFalse,
      reason: 'an empty row is a no-write, not a zero-star rating',
    );
  });

  test('hasAnyRating is false until a star is set', () async {
    await addDiner('Emma', DinerAgeBand.toddler);
    final vm = FamilyRatingEntryViewModel(recipeId: _recipe);
    await vm.load();

    expect(vm.hasAnyRating, isFalse);
    vm.setStars(_malin, 2);
    expect(vm.hasAnyRating, isTrue);
  });

  test('the logged-in account holder is flagged as the self-rater', () async {
    final emma = await addDiner('Emma', DinerAgeBand.toddler);
    final vm = FamilyRatingEntryViewModel(
      recipeId: _recipe,
      presentMemberIds: [_malin, emma],
    );
    await vm.load();

    expect(vm.isHolder(_malin), isTrue);
    expect(vm.isHolder(emma), isFalse);
  });

  test(
    'PRIVACY: rating my own row mirrors to my public score, rating a child '
    'does NOT',
    () async {
      // The core privacy contract: an adult self-rate flows to the public/
      // social rating; a child diner-profile verdict is private and must never
      // bump anyone's public score.
      final emma = await addDiner('Emma', DinerAgeBand.toddler);
      final vm = FamilyRatingEntryViewModel(
        recipeId: _recipe,
        presentMemberIds: [_malin, emma],
      );
      await vm.load();
      vm.setStars(_malin, 4); // self-rate → should mirror
      vm.setStars(emma, 3); // child → must NOT mirror

      await vm.save();

      verify(
        () => socialOps.rateRecipe(
          recipeId: _recipe,
          rating: 4.0,
          review: any(named: 'review'),
        ),
      ).called(1);
      verifyNever(
        () => socialOps.rateRecipe(
          recipeId: any(named: 'recipeId'),
          rating: 3.0,
          review: any(named: 'review'),
        ),
      );
    },
  );

  test(
    'save calls rateAsFamily per rated member with the holder as enterer, and '
    'NEVER for an empty row (write-surface contract)',
    () async {
      // Pinned at the write surface with a mock service so "empty row = no
      // write" is proven directly, not inferred from a read that filters
      // invalid rows.
      final emma = await addDiner('Emma', DinerAgeBand.toddler);
      final guest = await addDiner('Mormor', DinerAgeBand.adult);

      final mockService = _MockFamilyRatingService();
      when(
        () => mockService.rateAsFamily(
          recipeId: any(named: 'recipeId'),
          householdId: any(named: 'householdId'),
          memberId: any(named: 'memberId'),
          memberType: any(named: 'memberType'),
          stars: any(named: 'stars'),
          enteredByUid: any(named: 'enteredByUid'),
        ),
      ).thenAnswer((_) async => null);
      TestServiceLocator.registerSingleton<FamilyRatingService>(mockService);

      final vm = FamilyRatingEntryViewModel(
        recipeId: _recipe,
        presentMemberIds: [_malin, emma, guest],
      );
      await vm.load();
      vm.setStars(emma, 5);
      // _malin + guest left unrated → must produce no write.

      await vm.save();

      verify(
        () => mockService.rateAsFamily(
          recipeId: _recipe,
          householdId: any(named: 'householdId'),
          memberId: emma,
          memberType: HouseholdMemberType.profile,
          stars: 5,
          enteredByUid: _malin,
        ),
      ).called(1);
      verifyNever(
        () => mockService.rateAsFamily(
          recipeId: any(named: 'recipeId'),
          householdId: any(named: 'householdId'),
          memberId: guest,
          memberType: any(named: 'memberType'),
          stars: any(named: 'stars'),
          enteredByUid: any(named: 'enteredByUid'),
        ),
      );
      verifyNever(
        () => mockService.rateAsFamily(
          recipeId: any(named: 'recipeId'),
          householdId: any(named: 'householdId'),
          memberId: _malin,
          memberType: any(named: 'memberType'),
          stars: any(named: 'stars'),
          enteredByUid: any(named: 'enteredByUid'),
        ),
      );
    },
  );

  test('setStars notifies listeners so the UI rebuilds', () async {
    await addDiner('Emma', DinerAgeBand.toddler);
    final vm = FamilyRatingEntryViewModel(recipeId: _recipe);
    await vm.load();
    var notifications = 0;
    vm.addListener(() => notifications++);

    vm.setStars(_malin, 5);

    expect(notifications, greaterThanOrEqualTo(1));
  });

  test('out-of-range stars are skipped (never written)', () async {
    final emma = await addDiner('Emma', DinerAgeBand.toddler);
    final vm = FamilyRatingEntryViewModel(
      recipeId: _recipe,
      presentMemberIds: [emma],
    );
    await vm.load();
    vm.setStars(emma, 9); // out of 1–5

    final ok = await vm.save();
    expect(ok, isTrue);
    final stored = await ratingService.getMemberRatings(
      householdId: householdId,
      recipeId: _recipe,
    );
    expect(stored, isEmpty, reason: 'a >5 value must not be persisted');
  });
}
