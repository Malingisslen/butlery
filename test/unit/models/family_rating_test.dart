import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/family_rating.dart';
import 'helpers/model_test_base.dart';

void main() {
  ModelTestBase.testModelGroup('FamilyRating', () {
    group('Identity', () {
      test('buildId pins a stable, collision-safe doc id per pair', () {
        // Intent: latest-verdict-wins relies on one stable doc id per pair,
        // so re-rating overwrites rather than appends. Pinning the exact value
        // makes a separator/format change fail loudly (it would silently send
        // writes to the wrong document otherwise).
        expect(FamilyRating.buildId('r1', 'm1'), 'r1|m1');
        expect(
          FamilyRating.buildId('r1', 'm1'),
          isNot(FamilyRating.buildId('r1', 'm2')),
        );
        // '|' separator cannot be produced by an underscore in either id.
        expect(
          FamilyRating.buildId('a_b', 'c'),
          isNot(FamilyRating.buildId('a', 'b_c')),
        );
      });

      test('create() uses the deterministic id', () {
        final rating = FamilyRating.create(
          recipeId: 'r1',
          householdId: 'hh_1',
          memberId: 'm1',
          memberType: HouseholdMemberType.profile,
          stars: 4,
          enteredByUid: 'parent_1',
        );
        expect(rating.id, FamilyRating.buildId('r1', 'm1'));
      });
    });

    group('Validation', () {
      test('hasValidStars enforces the 1–5 range', () {
        FamilyRating withStars(int s) => FamilyRating.create(
          recipeId: 'r1',
          householdId: 'hh_1',
          memberId: 'm1',
          memberType: HouseholdMemberType.profile,
          stars: s,
          enteredByUid: 'p1',
        );
        expect(withStars(0).hasValidStars, isFalse);
        expect(withStars(1).hasValidStars, isTrue);
        expect(withStars(5).hasValidStars, isTrue);
        expect(withStars(6).hasValidStars, isFalse);
      });
    });

    group('Proxy attribution', () {
      test('a user rated by someone else is a proxy entry', () {
        // Intent: this flag drives the "inmatat av X" label and the rule that
        // a proxy entry must never overwrite the member's own personal rating.
        final proxy = FamilyRating.create(
          recipeId: 'r1',
          householdId: 'hh_1',
          memberId: 'johan_uid',
          memberType: HouseholdMemberType.user,
          stars: 4,
          enteredByUid: 'malin_uid',
        );
        expect(proxy.isProxyEntry, isTrue);
      });

      test('a user rating themselves is not a proxy entry', () {
        final self = FamilyRating.create(
          recipeId: 'r1',
          householdId: 'hh_1',
          memberId: 'johan_uid',
          memberType: HouseholdMemberType.user,
          stars: 4,
          enteredByUid: 'johan_uid',
        );
        expect(self.isProxyEntry, isFalse);
      });

      test('a diner profile is never a proxy entry', () {
        final kid = FamilyRating.create(
          recipeId: 'r1',
          householdId: 'hh_1',
          memberId: 'liam_profile',
          memberType: HouseholdMemberType.profile,
          stars: 2,
          enteredByUid: 'malin_uid',
        );
        expect(kid.isProxyEntry, isFalse);
      });
    });

    group('copyWith', () {
      test('updates stars and bumps lastUpdatedAt, keeps createdAt', () {
        final original = FamilyRating(
          id: 'r1_m1',
          recipeId: 'r1',
          householdId: 'hh_1',
          memberId: 'm1',
          memberType: HouseholdMemberType.profile,
          stars: 2,
          enteredByUid: 'p1',
          createdAt: DateTime(2026, 1, 1),
          lastUpdatedAt: DateTime(2026, 1, 1),
        );

        final updated = original.copyWith(
          stars: 5,
          lastUpdatedAt: DateTime(2026, 6, 28),
        );

        expect(updated.stars, 5);
        expect(updated.createdAt, DateTime(2026, 1, 1));
        expect(updated.lastUpdatedAt, DateTime(2026, 6, 28));
        expect(updated.id, original.id);
      });
    });

    group('Round-trips', () {
      final model = FamilyRating(
        id: 'r1_m1',
        recipeId: 'r1',
        householdId: 'hh_1',
        memberId: 'm1',
        memberType: HouseholdMemberType.user,
        stars: 4,
        enteredByUid: 'p1',
        createdAt: DateTime(2026, 6, 1),
        lastUpdatedAt: DateTime(2026, 6, 28),
      );

      test('Firestore round-trip preserves fields', () {
        final restored = FamilyRating.fromMap(model.id, model.toFirestore());
        expect(restored.recipeId, 'r1');
        expect(restored.memberId, 'm1');
        expect(restored.memberType, HouseholdMemberType.user);
        expect(restored.stars, 4);
        expect(restored.enteredByUid, 'p1');
        expect(restored.createdAt, DateTime(2026, 6, 1));
        expect(restored.lastUpdatedAt, DateTime(2026, 6, 28));
      });

      test('JSON round-trip preserves fields', () {
        final restored = FamilyRating.fromJson(model.toJson());
        expect(restored.id, 'r1_m1');
        expect(restored.stars, 4);
        expect(restored.memberType, HouseholdMemberType.user);
      });
    });
  });

  ModelTestBase.testModelGroup('FamilyRatingSummary', () {
    FamilyRating star(String member, int s) => FamilyRating.create(
      recipeId: 'r1',
      householdId: 'hh_1',
      memberId: member,
      memberType: HouseholdMemberType.profile,
      stars: s,
      enteredByUid: 'p1',
    );

    test('computes a simple unweighted mean (every diner equal)', () {
      // Intent: spec §3 — a 6-year-old's star counts the same as an adult's.
      final summary = FamilyRatingSummary.fromRatings('r1', [
        star('m1', 5),
        star('m2', 4),
        star('m3', 3),
        star('m4', 2),
      ]);
      expect(summary.familyRatingCount, 4);
      expect(summary.familyAverage, closeTo(3.5, 0.0001));
    });

    test('ignores out-of-range stars', () {
      final summary = FamilyRatingSummary.fromRatings('r1', [
        star('m1', 4),
        star('m2', 9), // invalid, excluded
      ]);
      expect(summary.familyRatingCount, 1);
      expect(summary.familyAverage, 4);
    });

    test('empty ratings yield a zero summary', () {
      final summary = FamilyRatingSummary.fromRatings('r1', const []);
      expect(summary.hasRatings, isFalse);
      expect(summary.familyAverage, 0);
      expect(summary.familyRatingCount, 0);
    });

    test('displayAverage of an empty summary is "0,0" (card pill safety)', () {
      // Intent: this string renders on the recipe-card family pill, so a zero
      // summary must format cleanly, never "NaN".
      expect(
        FamilyRatingSummary.fromRatings('r1', const []).displayAverage,
        '0,0',
      );
    });

    test('displayAverage uses a Swedish decimal comma', () {
      final summary = FamilyRatingSummary.fromRatings('r1', [
        star('m1', 4),
        star('m2', 5),
        star('m3', 4),
      ]);
      // mean = 4.333... → "4,3"
      expect(summary.displayAverage, '4,3');
    });
  });
}
