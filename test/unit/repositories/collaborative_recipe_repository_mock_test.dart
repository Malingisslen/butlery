/// Comprehensive unit tests for CollaborativeRecipeRepository with mock-based testing
///
/// Tests real-time collaborative recipe editing functionality including comprehensive
/// presence management, conflict resolution, concurrent editing scenarios, and edge cases.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/repositories/collaborative_recipe_repository.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/realtime/live_editor.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('CollaborativeRecipeRepository Mock Tests', () {
    late CollaborativeRecipeRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepository;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      // Create fake Firestore instance
      fakeFirestore = FakeFirebaseFirestore();

      // Create mock auth repository with test user
      mockAuthRepository = MockAuthRepository();
      mockAuthRepository.setAuthState(
        userId: 'test-user-123',
        isAuthenticated: true,
      );

      // Create repository with fake Firestore and mock auth
      repository = CollaborativeRecipeRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepository,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('Collaborative Recipe Creation and Management', () {
      test('should create realtime recipe with full metadata', () async {
        // Arrange
        final baseRecipe = RecipeFactory.build(
          id: 'collab-recipe-1',
          title: 'Collaborative Recipe',
          description: 'A recipe for multiple chefs',
          createdBy: 'owner-123',
        );

        final realtimeRecipe = RealtimeRecipe.fromRecipe(
          recipe: baseRecipe,
          ownerId: 'owner-123',
          ownerDisplayName: 'Master Chef',
        );

        // Act
        await repository.createRealtimeRecipe(realtimeRecipe);

        // Assert
        final doc = await fakeFirestore
            .collection('realtime_recipes')
            .doc('collab-recipe-1')
            .get();

        expect(doc.exists, isTrue);
        expect(doc.data()?['ownerId'], equals('owner-123'));
        expect(doc.data()?['ownerDisplayName'], equals('Master Chef'));
        expect(doc.data()?['recipe'], isNotNull);
        expect(doc.data()?['activeEditors'], isEmpty);
        expect(doc.data()?['editCount'], equals(0));
      });

      test('should handle concurrent recipe creation attempts', () async {
        // Arrange
        final recipe1 = RealtimeRecipe.fromRecipe(
          recipe: RecipeFactory.build(id: 'recipe-1', title: 'Recipe 1'),
          ownerId: 'user-1',
          ownerDisplayName: 'User 1',
        );

        final recipe2 = RealtimeRecipe.fromRecipe(
          recipe: RecipeFactory.build(id: 'recipe-1', title: 'Recipe 2'),
          ownerId: 'user-2',
          ownerDisplayName: 'User 2',
        );

        // Act - Create first recipe
        await repository.createRealtimeRecipe(recipe1);

        // Try to create second recipe with same ID
        await repository.createRealtimeRecipe(recipe2);

        // Assert - Second creation should overwrite
        final doc = await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .get();

        expect(doc.data()?['ownerId'], equals('user-2'));
        expect(doc.data()?['recipe']?['core']?['title'], equals('Recipe 2'));
      });

      test('should update recipe with incremented edit count', () async {
        // Arrange
        final baseRecipe = RecipeFactory.build(
          id: 'recipe-1',
          title: 'Original Title',
          ingredients: ['Sugar', 'Flour'],
        );

        final realtimeRecipe = RealtimeRecipe.fromRecipe(
          recipe: baseRecipe,
          ownerId: 'owner-123',
          ownerDisplayName: 'Owner',
        );

        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .set(realtimeRecipe.toFirestore());

        // Act - Update recipe multiple times
        for (int i = 1; i <= 3; i++) {
          final updatedRecipe = realtimeRecipe.copyWith(
            recipe: baseRecipe.copyWith(title: 'Update $i'),
            editCount: i,
          );
          await repository.updateRealtimeRecipe(updatedRecipe);
        }

        // Assert
        final doc = await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .get();

        expect(doc.data()?['editCount'], equals(3));
        expect(doc.data()?['recipe']?['core']?['title'], equals('Update 3'));
      });

      test('should handle recipe not found scenario', () async {
        // Arrange
        // No recipe created

        // Act
        final snapshot = await repository.fetchRealtimeRecipe('non-existent');

        // Assert
        expect(snapshot.exists, isFalse);
      });

      test('should stream null for non-existent recipe', () async {
        // Arrange
        // No recipe created

        // Act
        final stream = repository.getRealtimeRecipeStream('non-existent');
        final recipe = await stream.first;

        // Assert
        expect(recipe, isNull);
      });
    });

    group('Advanced Presence Management', () {
      test('should manage multiple concurrent editors', () async {
        // Arrange
        final editors = [
          {'userId': 'editor-1', 'displayName': 'Editor One'},
          {'userId': 'editor-2', 'displayName': 'Editor Two'},
          {'userId': 'editor-3', 'displayName': 'Editor Three'},
        ];

        // Act - Add multiple editors
        for (final editor in editors) {
          await repository.updateUserPresence(
            'recipe-1',
            editor['userId']!,
            editor['displayName']!,
          );
        }

        // Assert - All editors should be active
        final activeEditors = await repository.getActiveEditors('recipe-1');
        expect(activeEditors, hasLength(3));

        for (final editor in activeEditors) {
          expect(editor['isActive'], isTrue);
          expect(editor['isCurrentlyActive'], isTrue);
        }
      });

      test('should handle presence conflicts and updates', () async {
        // Arrange
        await repository.setPresence('recipe-1', 'user-123', {
          'userId': 'user-123',
          'displayName': 'Original Name',
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
          'isActive': true,
          'currentField': 'title',
        });

        // Act - Update same user presence with different data
        await repository.updatePresence('recipe-1', 'user-123', {
          'displayName': 'Updated Name',
          'currentField': 'ingredients',
          'cursorPosition': 42,
        });

        // Assert
        final doc = await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-123')
            .get();

        expect(doc.data()?['displayName'], equals('Updated Name'));
        expect(doc.data()?['currentField'], equals('ingredients'));
        expect(doc.data()?['cursorPosition'], equals(42));
        expect(doc.data()?['userId'], equals('user-123')); // Original preserved
      });

      test('should track editor field focus changes', () async {
        // Arrange
        final fields = ['title', 'description', 'ingredients', 'instructions'];

        // Act - Simulate user moving through fields
        for (final field in fields) {
          await repository.updatePresence('recipe-1', 'user-123', {
            'currentField': field,
            'lastSeen': DateTime.now().millisecondsSinceEpoch,
          });

          // Verify immediate update
          final doc = await fakeFirestore
              .collection('realtime_recipes')
              .doc('recipe-1')
              .collection('presence')
              .doc('user-123')
              .get();

          expect(doc.data()?['currentField'], equals(field));
        }
      });

      test('should handle rapid heartbeat updates', () async {
        // Arrange
        await repository.updateUserPresence(
            'recipe-1', 'user-123', 'Test User');

        final initialDoc = await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-123')
            .get();
        final initialTime = initialDoc.data()?['lastSeen'] as int;

        // Act - Simulate rapid heartbeats
        for (int i = 0; i < 10; i++) {
          await Future.delayed(Duration(milliseconds: 10));
          await repository.updatePresenceHeartbeat('recipe-1', 'user-123');
        }

        // Assert
        final finalDoc = await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-123')
            .get();
        final finalTime = finalDoc.data()?['lastSeen'] as int;

        expect(finalTime, greaterThan(initialTime));
        expect(finalDoc.data()?['isActive'], isTrue);
      });

      test('should differentiate active from inactive editors', () async {
        // Arrange
        final now = DateTime.now().millisecondsSinceEpoch;

        // Active editor (just now)
        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('active-user')
            .set({
          'displayName': 'Active User',
          'isActive': true,
          'lastSeen': now,
        });

        // Recently active (30 seconds ago)
        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('recent-user')
            .set({
          'displayName': 'Recent User',
          'isActive': true,
          'lastSeen': now - 30000,
        });

        // Inactive (2 minutes ago)
        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('inactive-user')
            .set({
          'displayName': 'Inactive User',
          'isActive': true,
          'lastSeen': now - 120000,
        });

        // Act
        final editors = await repository.getActiveEditors('recipe-1');

        // Assert
        expect(editors, hasLength(3));

        final activeEditor =
            editors.firstWhere((e) => e['userId'] == 'active-user');
        expect(activeEditor['isCurrentlyActive'], isTrue);

        final recentEditor =
            editors.firstWhere((e) => e['userId'] == 'recent-user');
        expect(recentEditor['isCurrentlyActive'], isTrue); // Within 1 minute

        final inactiveEditor =
            editors.firstWhere((e) => e['userId'] == 'inactive-user');
        expect(inactiveEditor['isCurrentlyActive'], isFalse); // Over 1 minute
      });

      test('should handle presence removal vs clearing', () async {
        // Arrange
        await repository.updateUserPresence(
            'recipe-1', 'user-123', 'Test User');
        await repository.updateUserPresence(
            'recipe-1', 'user-456', 'Another User');

        // Act - Clear first user (mark inactive)
        await repository.clearUserPresence('recipe-1', 'user-123');

        // Remove second user (delete document)
        await repository.removePresence('recipe-1', 'user-456');

        // Assert
        final clearedDoc = await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-123')
            .get();

        final removedDoc = await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-456')
            .get();

        expect(clearedDoc.exists, isTrue);
        expect(clearedDoc.data()?['isActive'], isFalse);

        expect(removedDoc.exists, isFalse);
      });
    });

    group('Real-time Streaming and Participants', () {
      test('should stream live editor updates', () async {
        // Arrange
        final updates = <List<LiveEditor>>[];

        // Setup initial editors
        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-1')
            .set({
          'userId': 'user-1',
          'displayName': 'User One',
          'isActive': true,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        });

        // Act - Listen to stream
        final subscription =
            repository.getParticipantsStream('recipe-1').listen((editors) {
          updates.add(editors);
        });

        // Add another editor
        await Future.delayed(Duration(milliseconds: 50));
        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-2')
            .set({
          'userId': 'user-2',
          'displayName': 'User Two',
          'isActive': true,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        });

        await Future.delayed(Duration(milliseconds: 50));

        // Assert
        expect(updates.length, greaterThanOrEqualTo(1));

        // Cleanup
        await subscription.cancel();
      });

      test('should filter inactive users from participants stream', () async {
        // Arrange
        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('active-1')
            .set({
          'userId': 'active-1',
          'displayName': 'Active One',
          'isActive': true,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        });

        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('inactive-1')
            .set({
          'userId': 'inactive-1',
          'displayName': 'Inactive One',
          'isActive': false,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        });

        // Act
        final stream = repository.getParticipantsStream('recipe-1');
        final participants = await stream.first;

        // Assert
        expect(participants, hasLength(1));
        expect(participants.first.userId, equals('active-1'));
      });

      test('should handle empty participants gracefully', () async {
        // Arrange
        // No participants added

        // Act
        final stream = repository.getParticipantsStream('recipe-1');
        final participants = await stream.first;

        // Assert
        expect(participants, isEmpty);
      });
    });

    group('Cleanup and Maintenance Operations', () {
      test('should cleanup stale editors in batch', () async {
        // Arrange
        final now = DateTime.now().millisecondsSinceEpoch;

        // Create mix of active and stale editors
        final editors = [
          {'id': 'fresh-1', 'lastSeen': now},
          {'id': 'fresh-2', 'lastSeen': now - (2 * 60 * 1000)}, // 2 minutes
          {'id': 'stale-1', 'lastSeen': now - (6 * 60 * 1000)}, // 6 minutes
          {'id': 'stale-2', 'lastSeen': now - (10 * 60 * 1000)}, // 10 minutes
          {'id': 'stale-3', 'lastSeen': now - (60 * 60 * 1000)}, // 1 hour
        ];

        for (final editor in editors) {
          await fakeFirestore
              .collection('realtime_recipes')
              .doc('recipe-1')
              .collection('presence')
              .doc(editor['id'] as String)
              .set({
            'isActive': true,
            'lastSeen': editor['lastSeen'],
            'displayName': 'Editor ${editor['id']}',
          });
        }

        // Act
        await repository.cleanupInactiveEditors('recipe-1');

        // Assert
        for (final editor in editors) {
          final doc = await fakeFirestore
              .collection('realtime_recipes')
              .doc('recipe-1')
              .collection('presence')
              .doc(editor['id'] as String)
              .get();

          final lastSeen = editor['lastSeen'] as int;
          final shouldBeActive = (now - lastSeen) < (5 * 60 * 1000);

          expect(
            doc.data()?['isActive'],
            equals(shouldBeActive),
            reason: 'Editor ${editor['id']} active status incorrect',
          );
        }
      });

      test('should handle cleanup with no presence documents', () async {
        // Arrange
        // Create recipe without any presence documents
        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .set({'id': 'recipe-1'});

        // Act & Assert - Should not throw
        await expectLater(
          repository.cleanupInactiveEditors('recipe-1'),
          completes,
        );
      });

      test('should preserve user data during cleanup', () async {
        // Arrange
        final oldTime =
            DateTime.now().millisecondsSinceEpoch - (10 * 60 * 1000);

        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-123')
            .set({
          'userId': 'user-123',
          'displayName': 'Test User',
          'isActive': true,
          'lastSeen': oldTime,
          'customField': 'preserved',
          'currentField': 'ingredients',
        });

        // Act
        await repository.cleanupInactiveEditors('recipe-1');

        // Assert
        final doc = await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-123')
            .get();

        expect(doc.data()?['isActive'], isFalse);
        expect(doc.data()?['userId'], equals('user-123'));
        expect(doc.data()?['displayName'], equals('Test User'));
        expect(doc.data()?['customField'], equals('preserved'));
        expect(doc.data()?['currentField'], equals('ingredients'));
      });
    });

    group('User Document Operations', () {
      test('should fetch existing user document', () async {
        // Arrange
        await fakeFirestore.collection('users').doc('user-123').set({
          'uid': 'user-123',
          'displayName': 'John Doe',
          'email': 'john@example.com',
          'photoURL': 'https://example.com/photo.jpg',
        });

        // Act
        final doc = await repository.getUserDocument('user-123');

        // Assert
        expect(doc.exists, isTrue);
        expect(doc.data()?['displayName'], equals('John Doe'));
        expect(doc.data()?['email'], equals('john@example.com'));
      });

      test('should handle non-existent user document', () async {
        // Arrange
        // No user document created

        // Act
        final doc = await repository.getUserDocument('non-existent');

        // Assert
        expect(doc.exists, isFalse);
      });
    });

    group('Edge Cases and Error Scenarios', () {
      test('should handle simultaneous presence updates', () async {
        // Arrange
        final futures = <Future>[];

        // Act - Simulate multiple simultaneous updates
        for (int i = 0; i < 10; i++) {
          futures.add(
            repository.updatePresence('recipe-1', 'user-$i', {
              'displayName': 'User $i',
              'lastSeen': DateTime.now().millisecondsSinceEpoch,
              'isActive': true,
            }),
          );
        }

        await Future.wait(futures);

        // Assert - All should be created
        final snapshot = await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .get();

        expect(snapshot.docs, hasLength(10));
      });

      test('should handle recipe ID with special characters', () async {
        // Arrange
        const specialId = 'recipe_with-special.chars~123';
        final recipe = RealtimeRecipe.fromRecipe(
          recipe: RecipeFactory.build(id: specialId),
          ownerId: 'owner-123',
          ownerDisplayName: 'Owner',
        );

        // Act
        await repository.createRealtimeRecipe(recipe);

        // Assert
        final doc = await fakeFirestore
            .collection('realtime_recipes')
            .doc(specialId)
            .get();

        expect(doc.exists, isTrue);
      });

      test('should handle very long display names', () async {
        // Arrange
        final longName = 'A' * 500; // 500 character name

        // Act
        await repository.updateUserPresence('recipe-1', 'user-123', longName);

        // Assert
        final doc = await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-123')
            .get();

        expect(doc.data()?['displayName'], equals(longName));
      });

      test('should handle presence update for non-existent recipe', () async {
        // Arrange
        // No recipe created

        // Act & Assert - Should not throw
        await expectLater(
          repository.updateUserPresence(
              'non-existent', 'user-123', 'Test User'),
          completes,
        );

        // Verify presence was created anyway
        final doc = await fakeFirestore
            .collection('realtime_recipes')
            .doc('non-existent')
            .collection('presence')
            .doc('user-123')
            .get();

        expect(doc.exists, isTrue);
      });

      test('should maintain data consistency during rapid updates', () async {
        // Arrange
        final baseRecipe = RecipeFactory.build(id: 'recipe-1');
        final realtimeRecipe = RealtimeRecipe.fromRecipe(
          recipe: baseRecipe,
          ownerId: 'owner-123',
          ownerDisplayName: 'Owner',
        );

        await repository.createRealtimeRecipe(realtimeRecipe);

        // Act - Rapid concurrent updates
        final updateFutures = <Future>[];
        for (int i = 0; i < 20; i++) {
          final updated = realtimeRecipe.copyWith(
            editCount: i,
            recipe: baseRecipe.copyWith(title: 'Update $i'),
          );
          updateFutures.add(repository.updateRealtimeRecipe(updated));
        }

        await Future.wait(updateFutures);

        // Assert - Last update should win
        final doc = await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .get();

        // Due to concurrent updates, we can't predict exact final state
        // but document should exist and have valid data
        expect(doc.exists, isTrue);
        expect(doc.data()?['recipe'], isNotNull);
        expect(doc.data()?['editCount'], isNotNull);
      });
    });

    group('Complex Collaboration Scenarios', () {
      test('should support multi-recipe collaboration', () async {
        // Arrange
        final recipeIds = ['recipe-1', 'recipe-2', 'recipe-3'];
        const userId = 'user-123';

        // Act - User joins multiple recipes
        for (final recipeId in recipeIds) {
          await repository.updateUserPresence(recipeId, userId, 'Multi-Chef');
        }

        // Assert - User should be present in all recipes
        for (final recipeId in recipeIds) {
          final isActive =
              await repository.isUserActivelyEditing(recipeId, userId);
          expect(isActive, isTrue);
        }
      });

      test('should track recipe ownership transitions', () async {
        // Arrange
        final recipe = RealtimeRecipe.fromRecipe(
          recipe: RecipeFactory.build(id: 'recipe-1'),
          ownerId: 'original-owner',
          ownerDisplayName: 'Original Owner',
        );

        await repository.createRealtimeRecipe(recipe);

        // Act - Transfer ownership by creating new realtime recipe with same recipe but new owner
        final transferred = RealtimeRecipe.fromRecipe(
          recipe: recipe.recipe,
          ownerId: 'new-owner',
          ownerDisplayName: 'New Owner',
        );
        await repository.updateRealtimeRecipe(transferred);

        // Assert
        final doc = await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .get();

        expect(doc.data()?['ownerId'], equals('new-owner'));
        expect(doc.data()?['ownerDisplayName'], equals('New Owner'));
      });

      test('should handle recipe deletion with active editors', () async {
        // Arrange
        final recipe = RealtimeRecipe.fromRecipe(
          recipe: RecipeFactory.build(id: 'recipe-1'),
          ownerId: 'owner-123',
          ownerDisplayName: 'Owner',
        );

        await repository.createRealtimeRecipe(recipe);

        // Add active editors
        await repository.updateUserPresence('recipe-1', 'editor-1', 'Editor 1');
        await repository.updateUserPresence('recipe-1', 'editor-2', 'Editor 2');

        // Act - Delete recipe document
        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .delete();

        // Assert - Recipe gone but presence might remain
        final recipeDoc = await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .get();

        expect(recipeDoc.exists, isFalse);

        // Presence subcollection can still be accessed
        final presenceSnapshot = await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .get();

        // Firestore behavior: subcollections can exist without parent
        expect(presenceSnapshot.docs, hasLength(2));
      });
    });
  });
}
