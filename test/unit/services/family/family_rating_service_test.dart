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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/family_rating.dart';
import 'package:butlery/models/household.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/firebase/firebase_family_rating_repository.dart';
import 'package:butlery/repositories/firebase/firebase_household_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
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

/// A FirestoreRepository whose `firestore` getter throws, used to prove the
/// BUT-1505 denormalization transaction is best-effort (a failure must not
/// break the rating or the social mirror).
class _ThrowingFirestoreRepository extends Mock
    implements FirestoreRepository {}

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
  late _MockUnifiedRecipeService recipeService;
  late FakeFirebaseFirestore fs;

  Recipe personalRecipe() => Recipe(
    core: RecipeCore(
      id: _recipe,
      title: 'Fläskpannkaka',
      description: 'Test',
      ingredients: const ['ägg'],
      instructions: const ['vispa'],
      mealType: 'middag',
    ),
    type: RecipeType.personal,
  );

  setUpAll(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
    registerFallbackValue(personalRecipe());
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

    fs = FakeFirebaseFirestore();
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

    // BUT-1505: the denormalization writes the family aggregate onto the
    // owned recipe doc inside a Firestore transaction. Back the service's
    // FirestoreRepository with the SAME fake store as the rating repo so the
    // ratings query and the recipe patch see one consistent world.
    TestServiceLocator.registerSingleton<FirestoreRepository>(
      FirestoreRepository(firestore: fs),
    );

    socialOps = _MockSocialRecipeOperations();
    when(
      () => socialOps.rateRecipe(
        recipeId: any(named: 'recipeId'),
        rating: any(named: 'rating'),
        review: any(named: 'review'),
      ),
    ).thenAnswer((_) async => true);
    when(() => socialOps.removeRating(any())).thenAnswer((_) async => true);
    recipeService = _MockUnifiedRecipeService();
    when(() => recipeService.social).thenReturn(socialOps);
    // Denormalization helper looks the recipe up then patches it. Default to
    // "not in my list" so existing tests skip the patch cleanly; the denorm
    // test overrides getRecipeById to exercise the write.
    when(() => recipeService.getRecipeById(any())).thenReturn(null);
    when(
      () => recipeService.updateRecipe(any()),
    ).thenAnswer((_) async => true);
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

  // BUT-1505: the denormalization now transactionally patches the owned recipe
  // doc at users/{malin}/recipes/{recipe}, so denorm tests seed that doc and
  // assert the persisted `core` fields (rather than a mocked updateRecipe).
  DocumentReference<Map<String, dynamic>> ownedRecipeRef() =>
      fs.collection('users').doc(_malin).collection('recipes').doc(_recipe);

  Future<void> seedOwnedRecipe() =>
      ownedRecipeRef().set(personalRecipe().toFirestore());

  Future<Map<String, dynamic>?> readRecipeCore() async {
    final snap = await ownedRecipeRef().get();
    return snap.data()?['core'] as Map<String, dynamic>?;
  }

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

    test('un-rating an adult self-rate retracts the social mirror', () async {
      await rate(
        memberId: _malin,
        type: HouseholdMemberType.user,
        stars: 4,
        enteredByUid: _malin,
      );

      await service.removeRating(recipeId: _recipe, memberId: _malin);

      verify(() => socialOps.removeRating(_recipe)).called(1);
    });

    test('un-rating a child verdict never touches the social mirror', () async {
      await rate(
        memberId: 'liam',
        type: HouseholdMemberType.profile,
        stars: 5,
        enteredByUid: _malin,
      );
      // Pin that the verdict actually persisted, so verifyNever proves the
      // guard skipped the mirror — not that the seed silently failed.
      expect(
        await ratingRepo.read(FamilyRating.buildId(_recipe, 'liam')),
        isNotNull,
      );

      await service.removeRating(recipeId: _recipe, memberId: 'liam');

      verifyNever(() => socialOps.removeRating(any()));
    });

    test(
      'un-rating a PROXY-entered adult verdict never retracts their public '
      'rating',
      () async {
        // Malin entered a verdict FOR Johan at the table (proxy). Removing it
        // must not touch Johan's own public/social rating — only a genuine
        // self-rate ever mirrored out.
        await rate(
          memberId: _johan,
          type: HouseholdMemberType.user,
          stars: 4,
          enteredByUid: _malin,
        );
        expect(
          await ratingRepo.read(FamilyRating.buildId(_recipe, _johan)),
          isNotNull,
        );

        await service.removeRating(recipeId: _recipe, memberId: _johan);

        verifyNever(() => socialOps.removeRating(any()));
      },
    );

    test(
      'un-rating the last verdict clears the recipe family average',
      () async {
        await seedOwnedRecipe();
        when(
          () => recipeService.getRecipeById(_recipe),
        ).thenReturn(personalRecipe());

        await rate(
          memberId: _malin,
          type: HouseholdMemberType.user,
          stars: 4,
          enteredByUid: _malin,
        );
        await service.removeRating(recipeId: _recipe, memberId: _malin);

        // The un-rate denormalization (last transactional write) nulls the
        // persisted pill on the owned recipe doc.
        final core = await readRecipeCore();
        expect(core?['familyAverage'], isNull);
        expect(core?['familyRatingCount'], isNull);
      },
    );
  });

  group('family-average denormalization (card pill source)', () {
    test(
      'writes an EQUAL-WEIGHT household average onto the owned recipe',
      () async {
        await seedOwnedRecipe();
        when(
          () => recipeService.getRecipeById(_recipe),
        ).thenReturn(personalRecipe());

        // A child profile (5) and an adult user (1). Equal weight → 3.0; a
        // type-weighted scheme (adults count double) would give 2.33, so this
        // asymmetry pins "everyone counts equally — a 6-yo == an adult".
        await rate(
          memberId: 'liam',
          type: HouseholdMemberType.profile,
          stars: 5,
          enteredByUid: _malin,
        );
        await rate(
          memberId: _malin,
          type: HouseholdMemberType.user,
          stars: 1,
          enteredByUid: _malin,
        );

        final core = await readRecipeCore();
        expect(core?['familyAverage'], 3.0); // (5 + 1) / 2, NOT type-weighted
        expect(core?['familyRatingCount'], 2);
      },
    );

    test(
      'two near-simultaneous ratings for the same recipe both land '
      '(no lost update)',
      () async {
        // BUT-1583 / BUT-1505 acceptance criterion #2: two household members
        // rate the same recipe at the same moment. Each rateAsFamily upserts
        // its verdict then denormalizes the recipe's family aggregate inside a
        // transaction that recomputes from the authoritative rating store.
        // Firing both concurrently must leave BOTH verdicts on the pill — the
        // old read-cache-then-rewrite-whole-doc path dropped one (a lost
        // update); the transactional recompute makes the final count 2.
        // Scope note: fake_cloud_firestore's runTransaction is a no-op stub (no
        // isolation/retry), so this proves the load-bearing half — each denorm
        // recomputes from the authoritative rating store instead of clobbering
        // from a stale cache — not Firestore's real conflict-retry (that needs
        // the emulator). Recompute-from-store is what makes both verdicts land.
        await seedOwnedRecipe();
        when(
          () => recipeService.getRecipeById(_recipe),
        ).thenReturn(personalRecipe());

        await Future.wait([
          rate(
            memberId: 'liam',
            type: HouseholdMemberType.profile,
            stars: 5,
            enteredByUid: _malin,
          ),
          rate(
            memberId: 'emma',
            type: HouseholdMemberType.profile,
            stars: 1,
            enteredByUid: _malin,
          ),
        ]);

        // Both verdicts persisted to the authoritative store...
        final all = await ratingRepo.getForRecipe(_hh, _recipe);
        expect(all, hasLength(2), reason: 'both member verdicts stored');

        // ...and the denormalized pill reflects BOTH, not just the last writer.
        final core = await readRecipeCore();
        expect(
          core?['familyRatingCount'],
          2,
          reason: 'no silent drop — both concurrent verdicts counted',
        );
        expect(core?['familyAverage'], 3.0); // (5 + 1) / 2
      },
    );

    test(
      'a denormalization failure is isolated — rating + mirror still land',
      () async {
        // The transactional denorm blows up (firestore access throws), but the
        // family entry is the source of truth: the rating must persist and the
        // adult self-rate must still mirror.
        when(
          () => recipeService.getRecipeById(_recipe),
        ).thenReturn(personalRecipe());
        final throwingRepo = _ThrowingFirestoreRepository();
        when(() => throwingRepo.firestore).thenThrow(Exception('boom'));
        TestServiceLocator.registerSingleton<FirestoreRepository>(throwingRepo);

        final saved = await rate(
          memberId: _malin,
          type: HouseholdMemberType.user,
          stars: 4,
          enteredByUid: _malin,
        );

        expect(saved, isNotNull, reason: 'rating kept despite denorm failure');
        final stored = await ratingRepo.read(
          FamilyRating.buildId(_recipe, _malin),
        );
        expect(stored?.stars, 4);
        verify(
          () => socialOps.rateRecipe(
            recipeId: _recipe,
            rating: 4.0,
            review: any(named: 'review'),
          ),
        ).called(1);
      },
    );

    test(
      'skips the patch when the recipe is not in the user\'s list',
      () async {
        // getRecipeById returns null (setUp default) → community recipe / cold
        // cache → the denorm returns before touching the recipe doc.
        await seedOwnedRecipe();
        final saved = await rate(
          memberId: 'liam',
          type: HouseholdMemberType.profile,
          stars: 5,
          enteredByUid: _malin,
        );
        expect(saved, isNotNull);

        // The owned recipe doc keeps its seeded (null) family pill — no patch.
        final core = await readRecipeCore();
        expect(core?['familyAverage'], isNull);
        expect(core?['familyRatingCount'], isNull);
      },
    );
  });
}
