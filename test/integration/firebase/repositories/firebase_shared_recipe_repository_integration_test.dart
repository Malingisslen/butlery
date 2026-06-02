/// Emulator-lane integration tests for FirebaseSharedRecipeRepository.
///
/// These exercise the FieldValue operations the in-memory fake cannot
/// reproduce: `addMember` uses `FieldValue.arrayUnion`/`FieldValue.increment`
/// and the metadata writers use `FieldValue.serverTimestamp()`. Under
/// FakeFirebaseFirestore these throw (`MethodChannelFieldValue` vs
/// `MockFieldValuePlatform`), so the original tests in
/// `test/unit/repositories/firebase_shared_recipe_repository_test.dart`
/// were hard-skipped. BUT-1151 moves them onto the emulator lane: the mock
/// tier skips the group cleanly, the emulator CI leg runs them against a
/// real Firestore.
///
/// Only Firestore needs to be real here — the auth dependency stays a
/// `FakeAuthRepository` pinned to an authenticated `testUserId`.
@Tags(['integration', 'firebase'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_shared_recipe_repository.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../../test_support/emulator_lane.dart';
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseSharedRecipeRepository - FieldValue Integration (emulator)',
      () {
    late FirebaseFirestore firestore;
    late FirebaseSharedRecipeRepository repository;
    late FakeAuthRepository mockAuthRepo;
    late FakeUser mockUser;

    // Test data
    const testUserId = 'user-123';
    const testOtherUserId = 'other-user-456';
    const testFriendId = 'friend-789';
    const testRecipeId = 'shared-recipe-1';
    const testOriginalRecipeId = 'original-recipe-1';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      firestore = await firestoreForLane();
      await clearLane();

      mockAuthRepo = FakeAuthRepository();
      mockUser = FakeUser(uid: testUserId, displayName: 'Test User');

      mockAuthRepo.setAuthState(
        user: mockUser,
        userId: testUserId,
        isAuthenticated: true,
      );

      repository = FirebaseSharedRecipeRepository(
        firestore: firestore,
        authRepository: mockAuthRepo,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    Recipe createTestRecipe(String id, String userId) {
      return Recipe(
        core: RecipeCore(
          id: id,
          title: 'Test Recipe $id',
          description: 'A delicious test recipe',
          ingredients: ['Ingredient 1', 'Ingredient 2'],
          instructions: ['Step 1', 'Step 2'],
          mealType: 'Dinner',
          createdBy: userId,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
        ),
        type: RecipeType.personal,
      );
    }

    SharedRecipe createSharedRecipe({
      String? id,
      String? originalRecipeId,
      String? sharedByUserId,
      String? sharedByDisplayName,
      Recipe? recipeSnapshot,
      String? shareMessage,
      bool allowCollaboration = false,
      int? viewCount,
      int? engagementCount,
      int? dismissalCount,
    }) {
      final recipe = recipeSnapshot ??
          createTestRecipe(originalRecipeId ?? testOriginalRecipeId,
              sharedByUserId ?? testUserId);

      return SharedRecipe(
        id: id ?? testRecipeId,
        originalRecipeId: originalRecipeId ?? testOriginalRecipeId,
        recipeTitle: recipe.title,
        recipeImageUrl:
            recipe.imageUrls.isNotEmpty ? recipe.imageUrls.first : null,
        recipePortions: recipe.portions,
        recipeTimeMinutes: recipe.timeMinutes,
        recipeDescription: recipe.description,
        recipeSnapshot: recipe,
        sharedByUserId: sharedByUserId ?? testUserId,
        sharedByDisplayName: sharedByDisplayName ?? 'Test User',
        shareMessage: shareMessage,
        sharedAt: DateTime(2025, 1, 15),
        allowCollaboration: allowCollaboration,
        viewCount: viewCount ?? 0,
        engagementCount: engagementCount ?? 0,
        dismissalCount: dismissalCount ?? 0,
      );
    }

    /// Seeds a SharedRecipe into Firestore with optional subcollection data.
    /// Includes 'contentType': 'recipe' discriminator required by
    /// getSharedContentForUserViaSubcollection filtering.
    Future<void> seedSharedRecipe(
      SharedRecipe sharedRecipe, {
      List<String>? memberUserIds,
      List<String>? viewedByUserIds,
      List<String>? engagedByUserIds,
      List<String>? dismissedByUserIds,
    }) async {
      // Create main document with contentType discriminator
      final data = sharedRecipe.toFirestore();
      data['contentType'] = 'recipe';
      await firestore
          .collection('shared_content')
          .doc(sharedRecipe.id)
          .set(data);

      final recipeRef =
          firestore.collection('shared_content').doc(sharedRecipe.id);

      if (memberUserIds != null) {
        for (final userId in memberUserIds) {
          await recipeRef.collection('members').doc(userId).set({
            'userId': userId,
            'addedBy': sharedRecipe.sharedByUserId,
            'addedAt': DateTime.now().millisecondsSinceEpoch,
            'role': 'member',
          });
        }
      }

      if (viewedByUserIds != null) {
        for (final userId in viewedByUserIds) {
          await recipeRef.collection('views').doc(userId).set({
            'userId': userId,
            'viewedAt': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }

      if (engagedByUserIds != null) {
        for (final userId in engagedByUserIds) {
          await recipeRef.collection('engagements').doc(userId).set({
            'userId': userId,
            'action': 'import',
            'engagedAt': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }

      if (dismissedByUserIds != null) {
        for (final userId in dismissedByUserIds) {
          await recipeRef.collection('dismissals').doc(userId).set({
            'userId': userId,
            'dismissedAt': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }
    }

    // createSharedRecipe — exercises addMember's arrayUnion + increment.

    test('should allow user to create shared recipe with recipients', () async {
      final sharedRecipe = createSharedRecipe(sharedByUserId: testUserId);

      final recipeId = await repository.createSharedRecipe(
        sharedRecipe,
        recipientIds: [testFriendId],
      );

      // Verify members subcollection created (Issue #014)
      final memberDoc = await firestore
          .collection('shared_content')
          .doc(recipeId)
          .collection('members')
          .doc(testFriendId)
          .get();
      expect(memberDoc.exists, isTrue);
    });

    test('should create shared recipe with members subcollection', () async {
      final sharedRecipe = createSharedRecipe(
        sharedByUserId: testUserId,
        shareMessage: 'Check out this amazing recipe!',
      );

      final recipeId = await repository.createSharedRecipe(
        sharedRecipe,
        recipientIds: [testFriendId, testOtherUserId],
      );

      expect(recipeId, isNotEmpty);

      final doc =
          await firestore.collection('shared_content').doc(recipeId).get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['sharedByUserId'], testUserId);

      final membersSnapshot = await firestore
          .collection('shared_content')
          .doc(recipeId)
          .collection('members')
          .get();
      expect(membersSnapshot.docs.length, 2);
      expect(membersSnapshot.docs.any((d) => d.id == testFriendId), isTrue);
      expect(membersSnapshot.docs.any((d) => d.id == testOtherUserId), isTrue);
    });

    // BUT-1132: idempotent share — the post-query consume branch.

    test(
        'calling createSharedRecipe twice with same (sharedByUserId, originalRecipeId) reuses the existing doc',
        () async {
      final sharedRecipe = createSharedRecipe(sharedByUserId: testUserId);

      final firstId = await repository.createSharedRecipe(
        sharedRecipe,
        recipientIds: [testFriendId],
      );
      final secondId = await repository.createSharedRecipe(
        sharedRecipe,
        recipientIds: [testFriendId],
      );

      expect(secondId, equals(firstId),
          reason:
              'BUT-1132: idempotent — same shared_content doc reused for same (sharedByUserId, originalRecipeId)');

      // Verify only ONE doc exists in shared_content collection despite 2 calls.
      // The dedup query lookup on (sharedByUserId + originalRecipeId) prevents
      // the createSharedContent path from running a second time.
      final snapshot = await firestore.collection('shared_content').get();
      expect(snapshot.docs.length, equals(1),
          reason:
              'Only one shared_content doc must exist despite 2 createSharedRecipe calls');
    });

    // Status management — exercises addMetadata's serverTimestamp.

    test('should add view to views subcollection', () async {
      final sharedRecipe = createSharedRecipe(sharedByUserId: testOtherUserId);
      await seedSharedRecipe(sharedRecipe, memberUserIds: [testUserId]);

      await repository.markAsViewed(testRecipeId, testUserId);

      final viewDoc = await firestore
          .collection('shared_content')
          .doc(testRecipeId)
          .collection('views')
          .doc(testUserId)
          .get();
      expect(viewDoc.exists, isTrue);
      expect(viewDoc.data()?['userId'], testUserId);
    });

    test('should add engagement to engagements subcollection', () async {
      final sharedRecipe = createSharedRecipe(sharedByUserId: testOtherUserId);
      await seedSharedRecipe(sharedRecipe, memberUserIds: [testUserId]);

      await repository.markAsImported(testRecipeId, testUserId);

      final engagementDoc = await firestore
          .collection('shared_content')
          .doc(testRecipeId)
          .collection('engagements')
          .doc(testUserId)
          .get();
      expect(engagementDoc.exists, isTrue);
      expect(engagementDoc.data()?['userId'], testUserId);
      expect(engagementDoc.data()?['action'], 'import');
    });

    test('should add dismissal to dismissals subcollection', () async {
      final sharedRecipe = createSharedRecipe(sharedByUserId: testOtherUserId);
      await seedSharedRecipe(sharedRecipe, memberUserIds: [testUserId]);

      await repository.markAsDismissed(testRecipeId, testUserId);

      final dismissalDoc = await firestore
          .collection('shared_content')
          .doc(testRecipeId)
          .collection('dismissals')
          .doc(testUserId)
          .get();
      expect(dismissalDoc.exists, isTrue);
      expect(dismissalDoc.data()?['userId'], testUserId);
    });

    test('should remove dismissal from dismissals subcollection', () async {
      final sharedRecipe = createSharedRecipe(sharedByUserId: testOtherUserId);
      await seedSharedRecipe(
        sharedRecipe,
        memberUserIds: [testUserId],
        dismissedByUserIds: [testUserId],
      );

      await repository.undismiss(testRecipeId, testUserId);

      final dismissalDoc = await firestore
          .collection('shared_content')
          .doc(testRecipeId)
          .collection('dismissals')
          .doc(testUserId)
          .get();
      expect(dismissalDoc.exists, isFalse);
    });

    test('should throw when marking non-existent recipe as viewed', () async {
      // markAsViewed -> addView -> viewRepository.markAsViewed ->
      // addMetadata -> validateMetadataAccess returns false for non-existent doc
      // -> throws PermissionDeniedException wrapped in RepositoryException
      expect(
        () => repository.markAsViewed('non-existent', testUserId),
        throwsA(anything),
      );
    });
  }, skip: emulatorOnlySkip);
}
