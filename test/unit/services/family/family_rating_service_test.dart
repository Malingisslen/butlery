/// Unit tests for FamilyRatingService.
///
/// Subject: the household-internal rating semantics — upsert with
/// latest-verdict-wins (preserving createdAt, which the rules pin immutable),
/// and the adult hybrid (mirror a genuine self-rating to the personal/social
/// rating; never mirror a proxy entry or a diner-profile rating).
///
/// A REAL FirebaseFamilyRatingRepository on a fake store exercises the upsert
/// end-to-end; the social mirror is a verifiable mock so we can assert whether
/// it fired.
library;

import 'package:clock/clock.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/family_rating.dart';
import 'package:butlery/models/household.dart';
import 'package:butlery/repositories/firebase/firebase_family_rating_repository.dart';
import 'package:butlery/repositories/firebase/firebase_household_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/family_rating_repository.dart';
import 'package:butlery/services/family/family_rating_service.dart';
import 'package:butlery/services/unified/operations/social_recipe_operations.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockUnifiedRecipeService extends Mock implements UnifiedRecipeService {}

class _MockSocialRecipeOperations extends Mock
    implements SocialRecipeOperations {}

const _hh = 'hh-1';
const _malin = 'user-malin';
const _johan = 'user-johan';
const _recipe = 'recipe-1';

Future<void> _seedHousehold(FakeFirebaseFirestore fs) {
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
  return fs.collection('households').doc(hh.id).set(hh.toFirestore());
}

void main() {
  late FamilyRatingService service;
  late FirebaseFamilyRatingRepository ratingRepo;
  late _MockSocialRecipeOperations socialOps;

  setUpAll(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  setUp(() async {
    final auth = TestServiceLocator.get<AuthRepository>() as FakeAuthRepository;
    auth.setAuthState(
      user: FakeUser(uid: _malin),
      userId: _malin,
      isAuthenticated: true,
    );

    final fs = FakeFirebaseFirestore();
    await _seedHousehold(fs);
    final householdRepo = FirebaseHouseholdRepository(
      firestore: fs,
      authRepository: auth,
    );
    ratingRepo = FirebaseFamilyRatingRepository(
      firestore: fs,
      authRepository: auth,
      householdRepository: householdRepo,
    );
    TestServiceLocator.registerSingleton<FamilyRatingRepository>(ratingRepo);

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

    service = FamilyRatingService();
  });

  Future<FamilyRating?> rate({
    required String memberId,
    required HouseholdMemberType type,
    required int stars,
    required String enteredByUid,
    String recipeId = _recipe,
  }) => service.rateAsFamily(
    recipeId: recipeId,
    householdId: _hh,
    memberId: memberId,
    memberType: type,
    stars: stars,
    enteredByUid: enteredByUid,
  );

  group('rateAsFamily upsert', () {
    test('creates a new family rating', () async {
      final saved = await rate(
        memberId: 'liam',
        type: HouseholdMemberType.profile,
        stars: 4,
        enteredByUid: _malin,
      );

      expect(saved, isNotNull);
      expect(saved!.stars, 4);
      final stored = await ratingRepo.read(saved.id);
      expect(stored!.stars, 4);
    });

    test(
      'an out-of-range rating is rejected and never reaches the summary',
      () async {
        // The repo stars-guard throws; executeServiceOperation turns that into a
        // null return, so no corrupt entry lands to silently zero out the pill.
        final saved = await rate(
          memberId: 'liam',
          type: HouseholdMemberType.profile,
          stars: 0,
          enteredByUid: _malin,
        );

        expect(saved, isNull);
        final summary = await service.getSummaryForRecipe(
          householdId: _hh,
          recipeId: _recipe,
        );
        expect(summary.familyRatingCount, 0);
      },
    );

    test(
      're-rating overwrites stars and preserves createdAt (latest-verdict)',
      () async {
        final t1 = DateTime.utc(2026, 6, 1, 12);
        final t2 = DateTime.utc(2026, 6, 2, 18);

        await withClock(
          Clock.fixed(t1),
          () => rate(
            memberId: 'liam',
            type: HouseholdMemberType.profile,
            stars: 3,
            enteredByUid: _malin,
          ),
        );
        await withClock(
          Clock.fixed(t2),
          () => rate(
            memberId: 'liam',
            type: HouseholdMemberType.profile,
            stars: 5,
            enteredByUid: _johan,
          ),
        );

        final all = await ratingRepo.getForRecipe(_hh, _recipe);
        expect(all, hasLength(1), reason: 'deterministic id → single doc');
        final r = all.single;
        expect(r.stars, 5);
        expect(r.enteredByUid, _johan);
        // Firestore round-trips timestamps to local-zone DateTimes; compare the
        // instant, not the zone representation.
        expect(
          r.createdAt.isAtSameMomentAs(t1),
          isTrue,
          reason: 'createdAt preserved across re-rate',
        );
        expect(
          r.lastUpdatedAt.isAtSameMomentAs(t2),
          isTrue,
          reason: 'lastUpdatedAt bumped',
        );
      },
    );
  });

  group('adult hybrid mirror', () {
    test(
      'each adult self-rate fires the mirror, including the re-rate',
      () async {
        await rate(
          memberId: _malin,
          type: HouseholdMemberType.user,
          stars: 4,
          enteredByUid: _malin,
        );
        await rate(
          memberId: _malin,
          type: HouseholdMemberType.user,
          stars: 5,
          enteredByUid: _malin,
        );

        // The update path mirrors too — a changed verdict must reach the public
        // score, not just the first-ever rating.
        verify(
          () => socialOps.rateRecipe(
            recipeId: any(named: 'recipeId'),
            rating: any(named: 'rating'),
            review: any(named: 'review'),
          ),
        ).called(2);
      },
    );

    test(
      'an adult self-rating mirrors to the personal/social rating',
      () async {
        await rate(
          memberId: _malin,
          type: HouseholdMemberType.user,
          stars: 5,
          enteredByUid: _malin, // self, on own device
        );

        verify(
          () => socialOps.rateRecipe(recipeId: _recipe, rating: 5.0),
        ).called(1);
      },
    );

    test('a proxy entry never touches the rater\'s personal rating', () async {
      await rate(
        memberId: _johan,
        type: HouseholdMemberType.user,
        stars: 2,
        enteredByUid: _malin, // Malin entering for Johan on a shared phone
      );

      verifyNever(
        () => socialOps.rateRecipe(
          recipeId: any(named: 'recipeId'),
          rating: any(named: 'rating'),
          review: any(named: 'review'),
        ),
      );
      // The family entry is still recorded, attributed to the enterer.
      final stored = await ratingRepo.read(
        FamilyRating.buildId(_recipe, _johan),
      );
      expect(stored!.stars, 2);
      expect(stored.isProxyEntry, isTrue);
    });

    test('a diner-profile rating never mirrors', () async {
      await rate(
        memberId: 'liam',
        type: HouseholdMemberType.profile,
        stars: 4,
        enteredByUid: _malin,
      );

      verifyNever(
        () => socialOps.rateRecipe(
          recipeId: any(named: 'recipeId'),
          rating: any(named: 'rating'),
          review: any(named: 'review'),
        ),
      );
    });
  });

  group('reads', () {
    test('getSummaryForRecipe is the unweighted mean over members', () async {
      await rate(
        memberId: 'liam',
        type: HouseholdMemberType.profile,
        stars: 5,
        enteredByUid: _malin,
      );
      await rate(
        memberId: 'emma',
        type: HouseholdMemberType.profile,
        stars: 2,
        enteredByUid: _malin,
      );

      final summary = await service.getSummaryForRecipe(
        householdId: _hh,
        recipeId: _recipe,
      );
      expect(summary.familyRatingCount, 2);
      expect(summary.familyAverage, 3.5);
    });

    test('removeRating deletes the member verdict', () async {
      await rate(
        memberId: 'liam',
        type: HouseholdMemberType.profile,
        stars: 4,
        enteredByUid: _malin,
      );

      await service.removeRating(recipeId: _recipe, memberId: 'liam');

      final stored = await ratingRepo.read(
        FamilyRating.buildId(_recipe, 'liam'),
      );
      expect(stored, isNull);
    });

    test('removeRating on an absent verdict is a tolerant no-op', () async {
      await expectLater(
        service.removeRating(recipeId: _recipe, memberId: 'nobody'),
        completes,
      );
    });
  });
}
