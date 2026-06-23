/// Unit tests for RecipeLegacyValidator.
///
/// Covers the four legacy-deletion fallback strategies (user-collection
/// doc presence, isPersonal inference, ownership hints, creation
/// metadata stub) plus the modern-recipe validation path and the
/// audit-log write. All Firebase dependencies are injected as callbacks
/// or driven through a `FakeFirebaseFirestore`, so no auth wiring is
/// needed.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/firebase/modules/recipe_legacy_validator.dart';

const _userId = 'alice';

Recipe _recipe({
  String id = 'r1',
  String title = 'My Recipe',
  RecipeType type = RecipeType.personal,
  DateTime? createdAt,
  String? createdBy = 'alice',
  RecipeSocialData? socialData,
  RecipeRealtimeData? realtimeData,
  List<String> imageUrls = const [],
}) {
  return Recipe(
    core: RecipeCore(
      id: id,
      title: title,
      description: 'd',
      ingredients: const [],
      instructions: const [],
      mealType: 'Middag',
      createdAt: createdAt ?? DateTime(2025, 1, 1),
      updatedAt: createdAt ?? DateTime(2025, 1, 1),
      createdBy: createdBy,
      imageUrls: imageUrls,
    ),
    type: type,
    socialData: socialData,
    realtimeData: realtimeData,
  );
}

class _OwnershipCall {
  final String currentUserId;
  final String resourceOwnerId;
  _OwnershipCall(this.currentUserId, this.resourceOwnerId);
}

RecipeLegacyValidator _validator(
  FakeFirebaseFirestore firestore, {
  Future<DocumentSnapshot<Map<String, dynamic>>> Function(String, String)?
  getUserRecipeDoc,
  List<_OwnershipCall>? ownershipCalls,
  bool ownershipThrows = false,
}) {
  return RecipeLegacyValidator(
    firestore: firestore,
    getUserRecipeDoc:
        getUserRecipeDoc ??
        (uid, rid) => firestore
            .collection('users')
            .doc(uid)
            .collection('recipes')
            .doc(rid)
            .get(),
    validateOwnership:
        ({
          required String currentUserId,
          required String resourceOwnerId,
          required String resourceType,
          required String resourceId,
        }) async {
          ownershipCalls?.add(_OwnershipCall(currentUserId, resourceOwnerId));
          if (ownershipThrows) {
            throw PermissionDeniedException('denied');
          }
        },
  );
}

void main() {
  group('isLegacyRecipe', () {
    test('not legacy when modern fields all present', () {
      final firestore = FakeFirebaseFirestore();
      final r = _recipe(
        createdAt: DateTime(2024, 5, 1),
        createdBy: 'alice',
        socialData: const RecipeSocialData(),
      );
      expect(_validator(firestore).isLegacyRecipe(r), isFalse);
    });

    test('legacy when socialData is null', () {
      final firestore = FakeFirebaseFirestore();
      final r = _recipe(
        createdAt: DateTime(2024, 5, 1),
        createdBy: 'alice',
        // socialData null by default
      );
      expect(_validator(firestore).isLegacyRecipe(r), isTrue);
    });

    test('legacy when createdBy is null', () {
      final firestore = FakeFirebaseFirestore();
      final r = _recipe(
        createdAt: DateTime(2024, 5, 1),
        createdBy: null,
        socialData: const RecipeSocialData(),
      );
      expect(_validator(firestore).isLegacyRecipe(r), isTrue);
    });

    test('legacy when createdBy is empty', () {
      final firestore = FakeFirebaseFirestore();
      final r = _recipe(
        createdAt: DateTime(2024, 5, 1),
        createdBy: '',
        socialData: const RecipeSocialData(),
      );
      expect(_validator(firestore).isLegacyRecipe(r), isTrue);
    });

    test('legacy when createdAt predates 2022-06-01', () {
      final firestore = FakeFirebaseFirestore();
      final r = _recipe(
        createdAt: DateTime(2021, 1, 1),
        createdBy: 'alice',
        socialData: const RecipeSocialData(),
      );
      expect(_validator(firestore).isLegacyRecipe(r), isTrue);
    });
  });

  group('validateDeletionWithLegacySupport — modern path', () {
    test('returns false when modern recipe has empty owner', () async {
      final firestore = FakeFirebaseFirestore();
      final r = _recipe(socialData: const RecipeSocialData());
      final ok = await _validator(firestore).validateDeletionWithLegacySupport(
        r,
        _userId,
        r.id,
        false,
        (_) => '',
      );
      expect(ok, isFalse);
    });

    test('returns true when ownership validation passes', () async {
      final firestore = FakeFirebaseFirestore();
      final calls = <_OwnershipCall>[];
      final r = _recipe(socialData: const RecipeSocialData());
      final ok = await _validator(firestore, ownershipCalls: calls)
          .validateDeletionWithLegacySupport(
            r,
            _userId,
            r.id,
            false,
            (_) => 'alice',
          );
      expect(ok, isTrue);
      expect(calls.single.currentUserId, _userId);
      expect(calls.single.resourceOwnerId, 'alice');
    });

    test('returns false when ownership validation throws', () async {
      final firestore = FakeFirebaseFirestore();
      final r = _recipe(socialData: const RecipeSocialData());
      final ok = await _validator(firestore, ownershipThrows: true)
          .validateDeletionWithLegacySupport(
            r,
            _userId,
            r.id,
            false,
            (_) => 'alice',
          );
      expect(ok, isFalse);
    });
  });

  group('validateDeletionWithLegacySupport — legacy path', () {
    test('returns true when recipe exists in user collection', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('users')
          .doc(_userId)
          .collection('recipes')
          .doc('r1')
          .set({'placeholder': true});

      final r = _recipe();
      final ok = await _validator(
        firestore,
      ).validateDeletionWithLegacySupport(r, _userId, r.id, true, (_) => '');
      expect(ok, isTrue);
    });

    test(
      'returns true via personal-inference when doc absent + isPersonal',
      () async {
        final firestore = FakeFirebaseFirestore();
        // Don't seed the user collection — Strategy 1 fails, Strategy 2 fires.
        final r = _recipe(type: RecipeType.personal);
        final ok = await _validator(
          firestore,
        ).validateDeletionWithLegacySupport(r, _userId, r.id, true, (_) => '');
        expect(ok, isTrue);
      },
    );

    test(
      'returns true when image URL contains user id (ownership hint)',
      () async {
        final firestore = FakeFirebaseFirestore();
        final r = _recipe(
          type: RecipeType.shared,
          imageUrls: const [
            'https://storage.example/users/alice/recipes/img.jpg',
          ],
        );
        final ok = await _validator(
          firestore,
        ).validateDeletionWithLegacySupport(r, _userId, r.id, true, (_) => '');
        expect(ok, isTrue);
      },
    );

    test(
      'returns true when lastEditedByUserId == currentUserId (hint)',
      () async {
        final firestore = FakeFirebaseFirestore();
        final r = _recipe(
          type: RecipeType.shared,
          realtimeData: const RecipeRealtimeData(lastEditedByUserId: 'alice'),
        );
        final ok = await _validator(
          firestore,
        ).validateDeletionWithLegacySupport(r, _userId, r.id, true, (_) => '');
        expect(ok, isTrue);
      },
    );

    test('returns false when no strategy succeeds', () async {
      final firestore = FakeFirebaseFirestore();
      final r = _recipe(
        type: RecipeType.shared, // bypasses Strategy 2
        // no image hints, no realtimeData hints
      );
      final ok = await _validator(
        firestore,
      ).validateDeletionWithLegacySupport(r, _userId, r.id, true, (_) => '');
      expect(ok, isFalse);
    });

    test(
      'Strategy-1 error is swallowed; subsequent strategies still try',
      () async {
        final firestore = FakeFirebaseFirestore();
        final r = _recipe(type: RecipeType.personal);
        final ok = await _validator(
          firestore,
          getUserRecipeDoc: (_, __) async => throw StateError('boom'),
        ).validateDeletionWithLegacySupport(r, _userId, r.id, true, (_) => '');
        // Strategy 1 threw → caught → personal inference (Strategy 2) returns true
        expect(ok, isTrue);
      },
    );
  });

  group('logLegacyDeletion', () {
    test('writes one audit doc with the expected payload', () async {
      final firestore = FakeFirebaseFirestore();
      final r = _recipe(
        id: 'r-1',
        title: 'Pasta',
        createdAt: DateTime(2020, 1, 1),
        createdBy: null, // forces hasEmptyCreatedBy=true
      );

      await _validator(firestore).logLegacyDeletion(r, _userId);

      final snap = await firestore
          .collection('audit_logs')
          .doc('legacy_recipe_deletions')
          .collection('deletions')
          .get();

      expect(snap.docs, hasLength(1));
      final data = snap.docs.single.data();
      expect(data['action'], 'legacy_recipe_deletion');
      expect(data['recipeId'], 'r-1');
      expect(data['userId'], _userId);
      expect(data['recipeTitle'], 'Pasta');
      expect(data['createdAt'], DateTime(2020, 1, 1).toIso8601String());
      final reasons = data['legacyReasons'] as Map;
      expect(reasons['hasNoSocialData'], isTrue);
      expect(reasons['hasEmptyCreatedBy'], isTrue);
      expect(reasons['isOldRecipe'], isTrue);
      expect(data['deletedAt'], isA<String>());
    });

    test('multiple deletions append, do not overwrite', () async {
      final firestore = FakeFirebaseFirestore();
      final v = _validator(firestore);
      await v.logLegacyDeletion(_recipe(id: 'a'), _userId);
      await v.logLegacyDeletion(_recipe(id: 'b'), _userId);

      final snap = await firestore
          .collection('audit_logs')
          .doc('legacy_recipe_deletions')
          .collection('deletions')
          .get();
      expect(snap.docs, hasLength(2));
      expect(snap.docs.map((d) => d.data()['recipeId']).toSet(), {'a', 'b'});
    });
  });
}
