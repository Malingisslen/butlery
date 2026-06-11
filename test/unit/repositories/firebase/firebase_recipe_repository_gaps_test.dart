/// Gap-filling tests for FirebaseRecipeRepository.
///
/// Targets uncovered methods that fake_cloud_firestore can reach:
/// - countRecipesByTagId (count() aggregation on user-scoped collection)
/// - canRead / canWrite / canDelete (permission decision matrix)
/// - validateUpdatePermission collaborative-recipe branches
///
/// The cook-count batch write (addIncrementCookCountToBatch) is covered by
/// test/integration/firebase/repositories/
/// firebase_cook_event_repository_integration_test.dart via logCookEvent.
///
/// Pattern: lightweight FakeFirebaseFirestore + FakeAuthRepository, no
/// global ServiceLocator (matches conversation_mutation_module_test.dart).
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

const _alice = 'user-alice';
const _bob = 'user-bob';
const _carol = 'user-carol';

FirebaseRecipeRepository _repo(
  FakeFirebaseFirestore firestore, {
  String authedUserId = _alice,
}) {
  final mockAuth = FakeAuthRepository();
  mockAuth.setAuthState(
    user: FakeUser(uid: authedUserId),
    userId: authedUserId,
    isAuthenticated: true,
  );
  return FirebaseRecipeRepository(
    firestore: firestore,
    authRepository: mockAuth,
  );
}

Recipe _personalRecipe({
  String title = 'Pasta',
  String createdBy = _alice,
  List<String>? personalTagIds,
}) {
  return Recipe.personal(
    title: title,
    description: 'desc',
    ingredients: const ['mjölk'],
    instructions: const ['blanda'],
    mealType: 'Middag',
    createdBy: createdBy,
    personalTagIds: personalTagIds,
  );
}

Recipe _collabRecipe({
  String title = 'Team pasta',
  String ownerId = _alice,
  Map<String, ResourcePermission>? memberPermissions,
  bool allowGuestViewing = false,
}) {
  return Recipe.collaborative(
    title: title,
    description: 'desc',
    ingredients: const ['mjölk'],
    instructions: const ['blanda'],
    mealType: 'Middag',
    ownerId: ownerId,
    ownerDisplayName: ownerId,
    memberPermissions: memberPermissions,
    allowGuestViewing: allowGuestViewing,
  );
}

/// Seed a recipe at users/{uid}/recipes/{recipeId}.
Future<void> _seedUserRecipe(
  FakeFirebaseFirestore firestore,
  String uid,
  Recipe recipe,
) async {
  await firestore
      .collection('users')
      .doc(uid)
      .collection('recipes')
      .doc(recipe.id)
      .set(recipe.toFirestore());
}

void main() {
  group('countRecipesByTagId', () {
    test('returns 0 when no recipes have the tag', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedUserRecipe(
          firestore, _alice, _personalRecipe(personalTagIds: const ['veg']));

      expect(await repo.countRecipesByTagId('keto'), 0);
    });

    test('counts matching recipes by tag id', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedUserRecipe(
          firestore, _alice, _personalRecipe(personalTagIds: const ['veg']));
      await _seedUserRecipe(firestore, _alice,
          _personalRecipe(title: 'Soppa', personalTagIds: const ['veg']));
      await _seedUserRecipe(firestore, _alice,
          _personalRecipe(title: 'Kött', personalTagIds: const ['meat']));

      expect(await repo.countRecipesByTagId('veg'), 2);
      expect(await repo.countRecipesByTagId('meat'), 1);
    });

    test('returns 0 when not authenticated', () async {
      final firestore = FakeFirebaseFirestore();
      final mockAuth = FakeAuthRepository();
      // No setAuthState → currentUserId is null
      final repo = FirebaseRecipeRepository(
        firestore: firestore,
        authRepository: mockAuth,
      );

      expect(await repo.countRecipesByTagId('veg'), 0);
    });
  });

  group('canRead / canWrite / canDelete', () {
    test('owner can read/write/delete their own personal recipe', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      final recipe = _personalRecipe();
      await _seedUserRecipe(firestore, _alice, recipe);

      expect(await repo.canRead(recipe.id, _alice), isTrue);
      expect(await repo.canWrite(recipe.id, _alice), isTrue);
      expect(await repo.canDelete(recipe.id, _alice), isTrue);
    });

    test('non-owner with editor permission can read + write but not delete',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      final recipe = _collabRecipe(
        memberPermissions: {_bob: ResourcePermission.editor},
      );
      await _seedUserRecipe(firestore, _alice, recipe);

      expect(await repo.canRead(recipe.id, _bob), isTrue);
      expect(await repo.canWrite(recipe.id, _bob), isTrue);
      expect(await repo.canDelete(recipe.id, _bob), isFalse);
    });

    test('non-owner with admin permission can read + write', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      final recipe = _collabRecipe(
        memberPermissions: {_bob: ResourcePermission.admin},
      );
      await _seedUserRecipe(firestore, _alice, recipe);

      expect(await repo.canRead(recipe.id, _bob), isTrue);
      expect(await repo.canWrite(recipe.id, _bob), isTrue);
    });

    test('non-member cannot read/write/delete a collaborative recipe',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      final recipe = _collabRecipe(
        memberPermissions: {_bob: ResourcePermission.editor},
      );
      await _seedUserRecipe(firestore, _alice, recipe);

      expect(await repo.canRead(recipe.id, _carol), isFalse);
      expect(await repo.canWrite(recipe.id, _carol), isFalse);
      expect(await repo.canDelete(recipe.id, _carol), isFalse);
    });

    test('missing recipe returns false for all three', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);

      expect(await repo.canRead('ghost', _alice), isFalse);
      expect(await repo.canWrite('ghost', _alice), isFalse);
      expect(await repo.canDelete('ghost', _alice), isFalse);
    });
  });

  group('validate*Permission collaborative branches', () {
    test('validateReadPermission true for member with permission', () async {
      final repo = _repo(FakeFirebaseFirestore());
      final recipe = _collabRecipe(
        memberPermissions: {_bob: ResourcePermission.editor},
      );

      expect(
          await repo.validateReadPermission(_bob, recipe.id, recipe), isTrue);
    });

    test('validateReadPermission true for guest when allowGuestViewing',
        () async {
      final repo = _repo(FakeFirebaseFirestore());
      final recipe = _collabRecipe(allowGuestViewing: true);

      expect(
          await repo.validateReadPermission(_carol, recipe.id, recipe), isTrue);
    });

    test('validateReadPermission false for outsider on closed collab recipe',
        () async {
      final repo = _repo(FakeFirebaseFirestore());
      final recipe = _collabRecipe(
        memberPermissions: {_bob: ResourcePermission.editor},
      );

      expect(await repo.validateReadPermission(_carol, recipe.id, recipe),
          isFalse);
    });

    test('validateUpdatePermission true for collaborative member', () async {
      final repo = _repo(FakeFirebaseFirestore());
      final recipe = _collabRecipe(
        memberPermissions: {_bob: ResourcePermission.editor},
      );

      expect(
          await repo.validateUpdatePermission(_bob, recipe.id, recipe), isTrue);
    });

    test('validateUpdatePermission false for non-owner non-member', () async {
      final repo = _repo(FakeFirebaseFirestore());
      final recipe = _collabRecipe();

      expect(await repo.validateUpdatePermission(_carol, recipe.id, recipe),
          isFalse);
    });

    test('validateDeletePermission true when caller is owner', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      final recipe = _personalRecipe();
      await _seedUserRecipe(firestore, _alice, recipe);

      expect(await repo.validateDeletePermission(_alice, recipe.id), isTrue);
    });

    test('validateDeletePermission false when recipe missing', () async {
      final repo = _repo(FakeFirebaseFirestore());

      expect(await repo.validateDeletePermission(_alice, 'ghost'), isFalse);
    });

    test('validateDeletePermission false for non-owner', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _bob);
      final recipe = _personalRecipe();
      await _seedUserRecipe(firestore, _bob, recipe);

      expect(await repo.validateDeletePermission(_carol, recipe.id), isFalse);
    });
  });
}
