/// BUT-1781: the rating aggregate used to write its denormalized fields to a
/// top-level `recipes` collection that has never existed, and under top-level
/// field names while the Recipe model serializes them under `core`. Both bugs
/// made the O(1) read in `getRecipeStatistics` permanently miss.
///
/// BUT-1781 (second half): the same method also wrote `recipe_social_stats`
/// from the client, which `firestore.rules` denies outright — and that write
/// ran FIRST, so the rethrow meant the denormalization never executed even
/// after the path was corrected. The client no longer touches that collection.
///
/// Does not call `BaseUnitTest.setupUnit()` — nothing here needs the service
/// locator, and the bootstrap would otherwise win the race for
/// `FieldValueFactoryPlatform.instance` (a process-wide singleton) and make the
/// `FieldValue.delete()` in the empty branch throw a cast error. That is a
/// convenience, NOT a wall: if this suite ever needs the locator, call
/// `installFakeFieldValuePlatform()` from
/// `test/test_support/fake_field_value_platform.dart` first in `setUp` and the
/// sentinels keep working. Do not copy this omission as "sentinels and
/// setupUnit are incompatible".
library;

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/operations/modules/rating_statistics.dart';

void main() {
  group('RatingStatistics.updateRecipeRatingAggregate', () {
    late FakeFirebaseFirestore firestore;

    const ownerId = 'user_123';
    const recipeId = 'recipe_1';

    setUp(() {
      firestore = FakeFirebaseFirestore();
    });

    DocumentReference<Map<String, dynamic>> ownerRecipeRef() => firestore
        .collection('users')
        .doc(ownerId)
        .collection('recipes')
        .doc(recipeId);

    Future<void> seedRating(double value, String raterId) =>
        firestore.collection('recipe_ratings').add({
          'recipeId': recipeId,
          'userId': raterId,
          'rating': value,
          'review': null,
          'createdAt': Timestamp.now(),
        });

    test('denormalizes onto users/{uid}/recipes/{id} under core.*', () async {
      await ownerRecipeRef().set({
        'core': {'title': 'Test Recipe'},
      });
      await seedRating(5, 'rater_a');
      await seedRating(4, 'rater_b');

      await RatingStatistics.updateRecipeRatingAggregate(
        firestore: firestore,
        recipeId: recipeId,
        recipeOwnerId: ownerId,
      );

      final core =
          (await ownerRecipeRef().get()).data()!['core']
              as Map<String, dynamic>;
      expect(core['ratingCount'], equals(2));
      expect(core['averageRating'], equals(4.5));
      // The title must survive — the write is a partial update, not a replace.
      expect(core['title'], equals('Test Recipe'));

      // Nothing may land in the top-level collection; writing there was the bug.
      final orphan = await firestore.collection('recipes').doc(recipeId).get();
      expect(orphan.exists, isFalse);
    });

    test(
      'clears the denormalized fields when the last rating is removed',
      () async {
        await ownerRecipeRef().set({
          'core': {
            'title': 'Test Recipe',
            'ratingCount': 3,
            'averageRating': 4.0,
            // Seeded PRESENT on purpose: `FieldValue.delete()` against an
            // absent nested key is a silent no-op on this fake, so a fixture
            // without the field cannot tell "cleared it" from "never wrote it".
            'ratingDistribution': {'4': 3},
          },
        });

        await RatingStatistics.updateRecipeRatingAggregate(
          firestore: firestore,
          recipeId: recipeId,
          recipeOwnerId: ownerId,
        );

        final core =
            (await ownerRecipeRef().get()).data()!['core']
                as Map<String, dynamic>;
        expect(core['ratingCount'], equals(0));
        expect(core['averageRating'], isNull);
        // A stale histogram outliving its own count is what the UI renders.
        expect(core.containsKey('ratingDistribution'), isFalse);
        expect(core['title'], equals('Test Recipe'));
      },
    );

    test(
      'never writes recipe_social_stats — that collection is server-only',
      () async {
        await ownerRecipeRef().set({
          'core': {'title': 'Test Recipe'},
        });
        await seedRating(3, 'rater_a');

        await RatingStatistics.updateRecipeRatingAggregate(
          firestore: firestore,
          recipeId: recipeId,
          recipeOwnerId: ownerId,
        );

        // firestore.rules:2506-2508 says `allow create, update, delete: if
        // false` on recipe_social_stats; drainRatingAggregations is its single
        // producer. A client write there is permission-denied in production —
        // and this fake evaluates no rules, so the ONLY way to pin it is to
        // assert the client leaves the collection alone.
        final stats = await firestore
            .collection('recipe_social_stats')
            .doc(recipeId)
            .get();
        expect(stats.exists, isFalse);
      },
    );

    test(
      'an unknown owner skips the write instead of guessing a uid',
      () async {
        // The recipe DOES exist and the rating IS there — only the owner
        // handoff is missing. Seeding the document is what makes this
        // falsifiable: a fallback that guessed the rater's uid, or one that
        // wrote to some default collection, would land fields here.
        await ownerRecipeRef().set({
          'core': {'title': 'Test Recipe'},
        });
        await seedRating(3, ownerId);

        await RatingStatistics.updateRecipeRatingAggregate(
          firestore: firestore,
          recipeId: recipeId,
          recipeOwnerId: null,
        );

        final core =
            (await ownerRecipeRef().get()).data()!['core']
                as Map<String, dynamic>;
        expect(core.containsKey('ratingCount'), isFalse);
        expect(core['title'], equals('Test Recipe'));

        final stats = await firestore
            .collection('recipe_social_stats')
            .doc(recipeId)
            .get();
        expect(stats.exists, isFalse);
      },
    );

    test(
      'ratingDistribution goes to Firestore with STRING keys, never int',
      () async {
        await ownerRecipeRef().set({
          'core': {'title': 'Test Recipe'},
        });
        await seedRating(5, 'rater_a');
        await seedRating(5, 'rater_b');
        await seedRating(3, 'rater_c');

        await RatingStatistics.updateRecipeRatingAggregate(
          firestore: firestore,
          recipeId: recipeId,
          recipeOwnerId: ownerId,
        );

        final core =
            (await ownerRecipeRef().get()).data()!['core']
                as Map<String, dynamic>;
        final distribution = core['ratingDistribution'] as Map;
        // The premise the fake CANNOT stage: cloud_firestore's codec casts
        // every nested map key with `key as String` before the write leaves
        // Dart, so an int key is a TypeError on a real device while this fake
        // stores it happily. Assert the KEY TYPE, which the fake does preserve.
        expect(
          distribution.keys.every((k) => k is String),
          isTrue,
          reason: 'int map keys throw in _CodecUtility on a real device',
        );
        expect(distribution['5'], equals(2));
        expect(distribution['3'], equals(1));
      },
    );

    test(
      'RecipeCore serializers emit string distribution keys too',
      () async {
        final core = RecipeCore(
          id: recipeId,
          title: 'Test Recipe',
          description: '',
          ingredients: const [],
          instructions: const [],
          mealType: 'middag',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
          ratingDistribution: const {1: 0, 2: 0, 3: 1, 4: 0, 5: 2},
        );

        expect(
          (core.toFirestore()['ratingDistribution'] as Map).keys.every(
            (k) => k is String,
          ),
          isTrue,
        );
        // jsonEncode is the offline cache's sink and throws on a non-String key.
        expect(() => jsonEncode(core.toJson()), returnsNormally);
      },
    );
  });
}
