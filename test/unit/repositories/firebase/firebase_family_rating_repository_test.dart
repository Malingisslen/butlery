/// Unit tests for FirebaseFamilyRatingRepository.
///
/// Pure-Dart; FakeFirebaseFirestore with a REAL FirebaseHouseholdRepository
/// wired to the same store. Focus: the 1–5 stars data-boundary guard,
/// household-membership access (incl. no cross-household re-parenting), and the
/// membership-gated getForRecipe/getForHousehold queries.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/family_rating.dart';
import 'package:butlery/models/household.dart';
import 'package:butlery/repositories/firebase/firebase_family_rating_repository.dart';
import 'package:butlery/repositories/firebase/firebase_household_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

const _malin = 'user-malin';
const _johan = 'user-johan';
const _stranger = 'user-stranger';
const _hh = 'hh-1';
const _recipe = 'recipe-1';

FirebaseFamilyRatingRepository _repo(
  FakeFirebaseFirestore fs, {
  String authedUserId = _malin,
}) {
  final mockAuth = FakeAuthRepository();
  mockAuth.setAuthState(
    user: FakeUser(uid: authedUserId),
    userId: authedUserId,
    isAuthenticated: true,
  );
  final householdRepo = FirebaseHouseholdRepository(
    firestore: fs,
    authRepository: mockAuth,
  );
  return FirebaseFamilyRatingRepository(
    firestore: fs,
    authRepository: mockAuth,
    householdRepository: householdRepo,
  );
}

Future<void> _seedHousehold(FakeFirebaseFirestore fs, {String id = _hh}) {
  final hh = Household(
    id: id,
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

FamilyRating _rating({
  String householdId = _hh,
  String recipeId = _recipe,
  String memberId = 'liam',
  int stars = 4,
}) => FamilyRating.create(
  recipeId: recipeId,
  householdId: householdId,
  memberId: memberId,
  memberType: HouseholdMemberType.profile,
  stars: stars,
  enteredByUid: _malin,
);

void main() {
  group('stars data-boundary guard', () {
    test('rejects stars below 1 and above 5', () async {
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      final repo = _repo(fs);

      await expectLater(
        () => repo.create(_rating(stars: 0)),
        throwsA(isA<SecurityViolationException>()),
      );
      await expectLater(
        () => repo.create(_rating(stars: 6)),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('accepts 1..5', () async {
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      final repo = _repo(fs);

      final created = await repo.create(_rating(stars: 5));
      expect(created.stars, 5);
    });

    test('createBatch cannot bypass the stars guard', () async {
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      final repo = _repo(fs);

      await expectLater(
        () => repo.createBatch([_rating(stars: 9)]),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('update enforces the stars guard', () async {
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      final repo = _repo(fs);
      final created = await repo.create(_rating(stars: 4));

      await expectLater(
        () => repo.update(created.copyWith(stars: 0)),
        throwsA(isA<SecurityViolationException>()),
      );
    });
  });

  group('household-membership access', () {
    test('member can create; non-member cannot', () async {
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);

      expect(
        await _repo(
          fs,
          authedUserId: _malin,
        ).validateCreatePermission(_malin, _rating()),
        isTrue,
      );
      expect(
        await _repo(
          fs,
          authedUserId: _stranger,
        ).validateCreatePermission(_stranger, _rating()),
        isFalse,
      );
    });

    test('read: member yes, outsider no, null delegates', () async {
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      final r = _rating();

      expect(
        await _repo(
          fs,
          authedUserId: _johan,
        ).validateReadPermission(_johan, r.id, r),
        isTrue,
      );
      expect(
        await _repo(
          fs,
          authedUserId: _stranger,
        ).validateReadPermission(_stranger, r.id, r),
        isFalse,
      );
      expect(
        await _repo(fs).validateReadPermission(_malin, 'any', null),
        isTrue,
      );
    });

    test('a non-member update is denied via update()', () async {
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      final created = await _repo(fs).create(_rating());

      final asStranger = _repo(fs, authedUserId: _stranger);
      await expectLater(
        () => asStranger.update(created.copyWith(stars: 1)),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('a valid member update is persisted', () async {
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      final repo = _repo(fs);
      final created = await repo.create(_rating(stars: 3));

      await repo.update(created.copyWith(stars: 5));
      final reread = await repo.read(created.id);
      expect(reread!.stars, 5);
    });

    test('delete loads the stored rating and checks membership', () async {
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      final created = await _repo(fs).create(_rating());

      expect(
        await _repo(
          fs,
          authedUserId: _johan,
        ).validateDeletePermission(_johan, created.id),
        isTrue,
      );
      expect(
        await _repo(
          fs,
          authedUserId: _stranger,
        ).validateDeletePermission(_stranger, created.id),
        isFalse,
      );
      expect(
        await _repo(fs).validateDeletePermission(_malin, 'ghost'),
        isFalse,
      );
    });

    test('cannot create a rating into another household', () async {
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      final repo = _repo(fs, authedUserId: _malin);

      await expectLater(
        () => repo.create(_rating(householdId: 'hh-other')),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('update cannot re-parent a rating to another household', () async {
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      await _seedHousehold(fs, id: 'hh-2');
      final repo = _repo(fs);
      final created = await repo.create(_rating());

      // copyWith intentionally can't change householdId, so an attacker would
      // forge the entity directly — the repo must still reject it.
      final reparented = FamilyRating(
        id: created.id,
        recipeId: created.recipeId,
        householdId: 'hh-2',
        memberId: created.memberId,
        memberType: created.memberType,
        stars: created.stars,
        enteredByUid: created.enteredByUid,
      );
      expect(
        await repo.validateUpdatePermission(_malin, created.id, reparented),
        isFalse,
      );
    });
  });

  group('queries', () {
    test('getForRecipe filters by recipe and is membership-gated', () async {
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      final repo = _repo(fs);
      await repo.create(_rating(recipeId: 'r1', memberId: 'liam'));
      await repo.create(_rating(recipeId: 'r1', memberId: 'emma'));
      await repo.create(_rating(recipeId: 'r2', memberId: 'liam'));

      final r1 = await repo.getForRecipe(_hh, 'r1');
      expect(r1, hasLength(2));
      expect(r1.every((x) => x.recipeId == 'r1'), isTrue);

      // Outsider gets nothing.
      expect(
        await _repo(fs, authedUserId: _stranger).getForRecipe(_hh, 'r1'),
        isEmpty,
      );
    });

    test(
      'getForRecipe excludes a same-recipe rating in another household',
      () async {
        // Proves the householdId where-clause is live — a query that filtered on
        // recipeId alone would leak the other household's rating.
        final fs = FakeFirebaseFirestore();
        await _seedHousehold(fs);
        await _seedHousehold(fs, id: 'hh-2');
        final repo = _repo(fs, authedUserId: _malin);

        await repo.create(_rating(recipeId: _recipe, memberId: 'liam'));
        // Same recipe, different household — seeded directly.
        final foreign = FamilyRating.create(
          recipeId: _recipe,
          householdId: 'hh-2',
          memberId: 'other',
          memberType: HouseholdMemberType.profile,
          stars: 3,
          enteredByUid: _malin,
        );
        await fs
            .collection('family_ratings')
            .doc(foreign.id)
            .set(foreign.toFirestore());

        final results = await repo.getForRecipe(_hh, _recipe);
        expect(results, hasLength(1));
        expect(results.single.householdId, _hh);
      },
    );

    test(
      'watchForRecipe streams the recipe rows and is membership-gated',
      () async {
        final fs = FakeFirebaseFirestore();
        await _seedHousehold(fs);
        final repo = _repo(fs);
        await repo.create(_rating(recipeId: 'r1', memberId: 'liam'));
        await repo.create(_rating(recipeId: 'r1', memberId: 'emma'));
        await repo.create(_rating(recipeId: 'r2', memberId: 'liam'));

        // Member: the first emission carries exactly the two r1 ratings.
        final rows = await repo.watchForRecipe(_hh, 'r1').first;
        expect(rows, hasLength(2));
        expect(rows.every((x) => x.recipeId == 'r1'), isTrue);

        // Outsider gets an empty stream (membership gate) — never a raw
        // permission-denied error leaking through the stream.
        expect(
          await _repo(
            fs,
            authedUserId: _stranger,
          ).watchForRecipe(_hh, 'r1').first,
          isEmpty,
        );
      },
    );

    test('createBatch persists valid ratings for a member', () async {
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      final repo = _repo(fs);

      await repo.createBatch([
        _rating(recipeId: 'r1', memberId: 'liam', stars: 5),
        _rating(recipeId: 'r1', memberId: 'emma', stars: 3),
      ]);

      expect(await repo.getForRecipe(_hh, 'r1'), hasLength(2));
    });

    test('getForHousehold returns all ratings for a member only', () async {
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      final repo = _repo(fs);
      await repo.create(_rating(recipeId: 'r1'));
      await repo.create(_rating(recipeId: 'r2'));

      expect(
        await _repo(fs, authedUserId: _johan).getForHousehold(_hh),
        hasLength(2),
      );
      expect(
        await _repo(fs, authedUserId: _stranger).getForHousehold(_hh),
        isEmpty,
      );
    });
  });
}
