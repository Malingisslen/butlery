/// Unit tests for FamilyRatingBreakdownViewModel.
///
/// Subject: the read-only detail-page breakdown — resolve each stored verdict
/// to its roster member, in roster order, only for members who rated; surface
/// the household average + count; and attribute a proxy entry ("inmatat av
/// {name}") to whoever entered it. Real repo + roster stack on a fake store;
/// the social mirror is a mock (irrelevant here).
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/models/family_rating.dart';
import 'package:butlery/models/household.dart';
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
import 'package:butlery/viewmodels/family/family_rating_breakdown_viewmodel.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockUnifiedRecipeService extends Mock implements UnifiedRecipeService {}

class _MockSocialRecipeOperations extends Mock
    implements SocialRecipeOperations {}

const _malin = 'user-malin';
const _johan = 'user-johan';
const _hh = 'hh-duo';
const _recipe = 'recipe-1';

void main() {
  late FakeFirebaseFirestore fs;
  late DinerProfileRepository dinerRepo;
  late FamilyRatingService ratingService;

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
        _johan: MockFactory.createUserProfile(
          userId: _johan,
          displayName: 'Johan',
        ),
      },
    );
    TestServiceLocator.registerSingleton<PermissionService>(
      MockFactory.createPermissionService(currentUserId: _malin),
    );

    fs = FakeFirebaseFirestore();
    // Two account holders so a proxy entry (Johan, entered by Malin) is real.
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

    final socialOps = _MockSocialRecipeOperations();
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
  });

  Future<String> addChild(String name) async {
    await dinerRepo.create(
      DinerProfile.create(
        householdId: _hh,
        name: name,
        ageBand: DinerAgeBand.child,
        createdBy: _malin,
        guardianConsent: GuardianConsent(
          byUid: _malin,
          at: DateTime.utc(2026, 1, 1),
          consentVersion: DinerProfile.currentConsentVersion,
          includesAllergenConsent: false,
        ),
      ),
    );
    final diners = await dinerRepo.getByHousehold(_hh);
    return diners.firstWhere((d) => d.name == name).id;
  }

  Future<void> rate(
    String memberId,
    HouseholdMemberType type,
    int stars, {
    String enteredBy = _malin,
  }) => ratingService.rateAsFamily(
    recipeId: _recipe,
    householdId: _hh,
    memberId: memberId,
    memberType: type,
    stars: stars,
    enteredByUid: enteredBy,
  );

  test('no ratings → section hidden (hasFamilyRatings false)', () async {
    final vm = FamilyRatingBreakdownViewModel(recipeId: _recipe);
    await vm.startListening();
    expect(vm.hasFamilyRatings, isFalse);
    expect(vm.rows, isEmpty);
  });

  test('rows resolve in roster order, only for members who rated', () async {
    final emma = await addChild('Emma');
    await rate(_malin, HouseholdMemberType.user, 4);
    await rate(emma, HouseholdMemberType.profile, 3);
    // Johan present in the household but unrated → no row.

    final vm = FamilyRatingBreakdownViewModel(recipeId: _recipe);
    await vm.startListening();

    expect(vm.rows.map((r) => r.member.memberId), [_malin, emma]);
    expect(vm.rows.map((r) => r.stars), [4, 3]);
  });

  test('average + count reflect every rated member equally', () async {
    final emma = await addChild('Emma');
    await rate(_malin, HouseholdMemberType.user, 4);
    await rate(_johan, HouseholdMemberType.user, 5, enteredBy: _malin);
    await rate(emma, HouseholdMemberType.profile, 3);

    final vm = FamilyRatingBreakdownViewModel(recipeId: _recipe);
    await vm.startListening();

    expect(vm.familyCount, 3);
    expect(vm.familyAverageDisplay, '4,0'); // (4+5+3)/3, Swedish comma
  });

  test('a proxy entry is attributed to whoever entered it', () async {
    // Johan's verdict was entered by Malin at the table → must read
    // "inmatat av Malin" and never be treated as Johan's self-rating.
    await rate(_johan, HouseholdMemberType.user, 5, enteredBy: _malin);

    final vm = FamilyRatingBreakdownViewModel(recipeId: _recipe);
    await vm.startListening();

    final johanRow = vm.rows.firstWhere((r) => r.member.memberId == _johan);
    expect(johanRow.isProxy, isTrue);
    expect(johanRow.enteredByName, 'Malin');
  });

  test('a self-rating is not flagged as a proxy entry', () async {
    await rate(_malin, HouseholdMemberType.user, 4);

    final vm = FamilyRatingBreakdownViewModel(recipeId: _recipe);
    await vm.startListening();

    final malinRow = vm.rows.firstWhere((r) => r.member.memberId == _malin);
    expect(malinRow.isProxy, isFalse);
    expect(malinRow.enteredByName, isNull);
  });

  test(
    'proxy entered by someone no longer in the roster → no blank name',
    () async {
      // The enterer left the household after rating. isProxy stays true, but the
      // name can't resolve — it must be null (the view then omits "inmatat av"
      // rather than rendering a blank), never an empty/garbage string.
      await rate(_johan, HouseholdMemberType.user, 5, enteredBy: 'ghost-uid');

      final vm = FamilyRatingBreakdownViewModel(recipeId: _recipe);
      await vm.startListening();

      final johanRow = vm.rows.firstWhere((r) => r.member.memberId == _johan);
      expect(johanRow.isProxy, isTrue);
      expect(johanRow.enteredByName, isNull);
    },
  );

  test(
    'a cleared (0-star) verdict is excluded from both rows and the count',
    () async {
      await rate(_malin, HouseholdMemberType.user, 4);
      // A zero-star verdict (e.g. a cleared rating) must not render a row nor
      // inflate the count — the row filter and the summary filter must agree.
      await rate(_johan, HouseholdMemberType.user, 0, enteredBy: _malin);

      final vm = FamilyRatingBreakdownViewModel(recipeId: _recipe);
      await vm.startListening();

      expect(vm.familyCount, 1);
      expect(vm.rows.map((r) => r.member.memberId), [_malin]);
    },
  );

  test('fractional average renders with a Swedish decimal comma', () async {
    await rate(_malin, HouseholdMemberType.user, 4);
    await rate(_johan, HouseholdMemberType.user, 5, enteredBy: _malin);

    final vm = FamilyRatingBreakdownViewModel(recipeId: _recipe);
    await vm.startListening();

    expect(vm.familyAverageDisplay, '4,5'); // (4+5)/2, comma not dot
  });

  test(
    'startListening notifies listeners so the detail section repaints',
    () async {
      await rate(_malin, HouseholdMemberType.user, 4);
      final vm = FamilyRatingBreakdownViewModel(recipeId: _recipe);
      var notifications = 0;
      vm.addListener(() => notifications++);

      await vm.startListening();

      expect(notifications, greaterThanOrEqualTo(1));
    },
  );

  // BUT-1461 Gap 2: the breakdown listens live, so a rating entered on another
  // member's device appears without re-opening the screen (no second load).
  test('a rating written after listening starts updates rows live', () async {
    final vm = FamilyRatingBreakdownViewModel(recipeId: _recipe);
    await vm.startListening();
    expect(vm.familyCount, 0);
    expect(vm.hasFamilyRatings, isFalse);

    // Another member rates — the live listener must reflect it with no further
    // call into the viewmodel.
    await rate(_malin, HouseholdMemberType.user, 4);
    await pumpEventQueue();

    expect(vm.familyCount, 1);
    expect(vm.rows.map((r) => r.member.memberId), [_malin]);
  });

  // Regression guard: the count/average and the rows must stay consistent when
  // the household roster changes mid-view. The old cached-roster path counted a
  // new member's rating in the summary but had no row for them → "2 betyg" over
  // one row.
  test('a member added mid-view shows a row with a matching count', () async {
    await rate(_malin, HouseholdMemberType.user, 4);
    final vm = FamilyRatingBreakdownViewModel(recipeId: _recipe);
    await vm.startListening();
    expect(vm.familyCount, 1);
    expect(vm.rows.map((r) => r.member.memberId), [_malin]);

    // A new child diner joins the household, then is rated on another device.
    final emma = await addChild('Emma');
    await rate(emma, HouseholdMemberType.profile, 5);
    await pumpEventQueue();

    expect(vm.familyCount, vm.rows.length); // never a phantom count
    expect(vm.familyCount, 2);
    expect(vm.rows.map((r) => r.member.memberId), containsAll([_malin, emma]));
  });

  test('no state update after dispose (late rating is ignored)', () async {
    await rate(_malin, HouseholdMemberType.user, 4);
    final vm = FamilyRatingBreakdownViewModel(recipeId: _recipe);
    await vm.startListening();
    expect(vm.familyCount, 1);

    vm.dispose();

    // A rating that lands after dispose must not reach the disposed viewmodel
    // (cancelled subscription → no notifyListeners-after-dispose, count frozen).
    await rate(_johan, HouseholdMemberType.user, 5, enteredBy: _malin);
    await pumpEventQueue();

    expect(vm.familyCount, 1);
  });

  // Disposing mid-setup (before the subscription is opened) must complete
  // cleanly and never open a listener — the isDisposed guard after the roster
  // fetch. State assertions can't observe the private subscription; this proves
  // the guarded path doesn't throw and leaves the VM inert.
  test('dispose during startListening setup completes without error', () async {
    await rate(_malin, HouseholdMemberType.user, 4);
    final vm = FamilyRatingBreakdownViewModel(recipeId: _recipe);

    final future = vm.startListening(); // do not await — tear down mid-setup
    vm.dispose();
    await expectLater(future, completes);

    await rate(_johan, HouseholdMemberType.user, 5, enteredBy: _malin);
    await pumpEventQueue();
    expect(vm.hasFamilyRatings, isFalse);
  });
}
