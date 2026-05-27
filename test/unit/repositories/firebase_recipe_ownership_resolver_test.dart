/// Unit tests for [FirebaseRecipeOwnershipResolver] (BUT-458).
///
/// Behaviors proven:
/// - Personal recipes resolve owner from `createdBy` with empty shared list.
/// - Collaborative recipes resolve owner from `socialData.ownerId` and shared
///   list from `memberPermissions.keys` (excluding the owner).
/// - Missing recipe → null (caller falls back to author-only read).
/// - Missing owner data → null (no inference; rules degrade gracefully).
/// - Resolver exception → null (non-blocking; comment still writes).
/// - Wired through [FirebaseCommentsRepository.addComment], the resolved
///   snapshot lands on the comment doc as `recipeOwnerId` + `sharedWithUserIds`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:butlery/repositories/firebase/firebase_comments_repository.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_ownership_resolver.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/core/utils/timestamp_provider.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/mocks/production_mocks.dart';

Recipe _personalRecipe({
  String createdBy = 'owner-uid',
}) {
  return Recipe.personal(
    title: 'Test Recipe',
    description: '',
    ingredients: const [],
    instructions: const [],
    mealType: 'dinner',
    createdBy: createdBy,
  );
}

Recipe _collaborativeRecipe({
  String ownerId = 'owner-uid',
  Map<String, ResourcePermission>? memberPermissions,
}) {
  return Recipe.collaborative(
    title: 'Collab Recipe',
    description: '',
    ingredients: const [],
    instructions: const [],
    mealType: 'dinner',
    ownerId: ownerId,
    ownerDisplayName: 'Owner',
    memberPermissions: memberPermissions,
  );
}

Recipe _orphanRecipe() {
  // Personal recipe with no createdBy — simulates a legacy orphan that
  // also has no socialData ownerId.
  return Recipe.personal(
    title: 'Orphan',
    description: '',
    ingredients: const [],
    instructions: const [],
    mealType: 'dinner',
    createdBy: null,
  );
}

void main() {
  group('FirebaseRecipeOwnershipResolver (BUT-458)', () {
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    test('personal recipe resolves owner from createdBy, empty shared list',
        () async {
      final resolver = FirebaseRecipeOwnershipResolver(
        getRecipe: (id) async => _personalRecipe(createdBy: 'owner-uid'),
      );

      final snapshot = await resolver.resolve('recipe-1');

      expect(snapshot, isNotNull);
      expect(snapshot!.recipeOwnerId, equals('owner-uid'));
      expect(snapshot.sharedWithUserIds, isEmpty);
    });

    test('collaborative recipe resolves owner + members (excluding owner)',
        () async {
      final resolver = FirebaseRecipeOwnershipResolver(
        getRecipe: (id) async => _collaborativeRecipe(
          ownerId: 'owner-uid',
          memberPermissions: {
            'owner-uid': ResourcePermission.admin,
            'member-1': ResourcePermission.editor,
            'member-2': ResourcePermission.viewer,
          },
        ),
      );

      final snapshot = await resolver.resolve('recipe-1');

      expect(snapshot, isNotNull);
      expect(snapshot!.recipeOwnerId, equals('owner-uid'));
      expect(snapshot.sharedWithUserIds, containsAll(['member-1', 'member-2']));
      // Owner is in the dedicated field, not the shared list.
      expect(snapshot.sharedWithUserIds, isNot(contains('owner-uid')));
    });

    test('missing recipe returns null', () async {
      final resolver = FirebaseRecipeOwnershipResolver(
        getRecipe: (id) async => null,
      );

      final snapshot = await resolver.resolve('recipe-missing');

      expect(snapshot, isNull);
    });

    test('recipe with no createdBy and no socialData returns null', () async {
      final resolver = FirebaseRecipeOwnershipResolver(
        getRecipe: (id) async => _orphanRecipe(),
      );

      final snapshot = await resolver.resolve('orphan');

      expect(snapshot, isNull);
    });

    test('getRecipe throwing returns null (non-blocking)', () async {
      final resolver = FirebaseRecipeOwnershipResolver(
        getRecipe: (id) async => throw StateError('boom'),
      );

      final snapshot = await resolver.resolve('recipe-1');

      expect(snapshot, isNull);
    });

    test(
        'collaborative recipe with empty memberPermissions yields empty shares',
        () async {
      final resolver = FirebaseRecipeOwnershipResolver(
        getRecipe: (id) async => _collaborativeRecipe(
          ownerId: 'owner-uid',
          memberPermissions: {},
        ),
      );

      final snapshot = await resolver.resolve('recipe-1');

      expect(snapshot, isNotNull);
      expect(snapshot!.recipeOwnerId, equals('owner-uid'));
      expect(snapshot.sharedWithUserIds, isEmpty);
    });
  });

  group('FirebaseCommentsRepository.addComment with resolver wired', () {
    late FirebaseCommentsRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late FakeAuthRepository mockAuthRepo;
    late FakeUser mockUser;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuthRepo = FakeAuthRepository();
      mockUser = FakeUser(uid: 'author-uid', displayName: 'Author');
      mockAuthRepo.setAuthState(
        user: mockUser,
        userId: 'author-uid',
        isAuthenticated: true,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
    });

    test('populates recipeOwnerId and sharedWithUserIds when resolver wired',
        () async {
      // Arrange: collaborative recipe with two members. Recipe.collaborative
      // auto-generates an id, so capture it for the resolver match.
      final recipe = _collaborativeRecipe(
        ownerId: 'owner-uid',
        memberPermissions: {
          'owner-uid': ResourcePermission.admin,
          'member-1': ResourcePermission.editor,
          'member-2': ResourcePermission.viewer,
        },
      );

      final ownershipResolver = FirebaseRecipeOwnershipResolver(
        getRecipe: (id) async => id == recipe.id ? recipe : null,
      );

      repository = FirebaseCommentsRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
        timestampProvider: const TestTimestampProvider(),
        recipeOwnershipResolver: ownershipResolver.resolve,
      );

      // Act
      final result = await repository.addComment(
        recipeId: recipe.id,
        userId: 'author-uid',
        content: 'Looks great!',
      );

      // Assert: model fields hydrated
      expect(result.recipeId, equals(recipe.id));
      expect(result.authorId, equals('author-uid'));

      // Assert: raw doc carries denorm fields used by security rules
      final doc = await fakeFirestore
          .collection('recipe_comments')
          .doc(result.id)
          .get();
      final data = doc.data() as Map<String, dynamic>;
      expect(data['recipeOwnerId'], equals('owner-uid'));
      expect(
        (data['sharedWithUserIds'] as List).cast<String>(),
        containsAll(['member-1', 'member-2']),
      );
    });

    test('falls back to no recipeOwnerId when resolver returns null', () async {
      // Arrange: resolver returns null (recipe missing / orphan)
      Future<RecipeOwnershipSnapshot?> nullResolver(String recipeId) async =>
          null;

      repository = FirebaseCommentsRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
        timestampProvider: const TestTimestampProvider(),
        recipeOwnershipResolver: nullResolver,
      );

      // Act
      final result = await repository.addComment(
        recipeId: 'recipe-missing',
        userId: 'author-uid',
        content: 'Hello',
      );

      // Assert: doc still writes, but without recipeOwnerId; sharedWithUserIds
      // is the empty-list fallback (so security rules' `in` operator
      // doesn't crash on the missing field).
      final doc = await fakeFirestore
          .collection('recipe_comments')
          .doc(result.id)
          .get();
      final data = doc.data() as Map<String, dynamic>;
      expect(data.containsKey('recipeOwnerId'), isFalse);
      expect((data['sharedWithUserIds'] as List), isEmpty);
    });
  });
}
