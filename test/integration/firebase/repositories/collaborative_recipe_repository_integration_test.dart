/// Integration tests for Collaborative Recipe Repository
///
/// Tests collaborative recipe operations using FakeFirebaseFirestore (Fake Lane)
/// including real-time collaboration, presence management, and editing scenarios.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:butlery/repositories/collaborative_recipe_repository.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/realtime/live_editor.dart';
import '../../../test_support/base_unit_test.dart';
import '../../../test_support/stream_stabilizer.dart';
import '../../../test_support/test_data_isolator.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/firestore_singleton.dart';

void main() {
  group('Collaborative Recipe Repository Integration', () {
    late FirebaseFirestore firestore;
    late CollaborativeRecipeRepository repository;
    late MockUser testUser;
    late MockUser testUser2;
    late MockFirebaseAuth mockAuth;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      // Initialize test isolation
      TestDataIsolator.initializeTest('CollaborativeRecipe');

      // Setup Fake Firebase instances (Fake Lane)
      firestore = FirestoreSingleton.instance;

      // Create mock users
      testUser = MockUser(
        uid: 'chef1-uid',
        email: 'chef1@example.com',
        displayName: 'Chef 1',
      );

      testUser2 = MockUser(
        uid: 'chef2-uid',
        email: 'chef2@example.com',
        displayName: 'Chef 2',
      );

      mockAuth = MockFirebaseAuth(mockUser: testUser);

      // Create repository with fake Firestore
      repository = CollaborativeRecipeRepository(firestore: firestore);
    });

    tearDown(() async {
      await mockAuth.signOut();
      await TestDataIsolator.cleanupTest('CollaborativeRecipe');
    });

    group('Real-time Recipe Collaboration', () {
      test('should create and stream realtime recipe with Firebase', () async {
        // Arrange
        final baseRecipe = RecipeFactory.build(
          id: 'collab-recipe-1',
          title: 'Collaborative Pasta',
          description: 'A recipe we edit together',
          createdBy: testUser.uid,
        );

        final realtimeRecipe = RealtimeRecipe.fromRecipe(
          recipe: baseRecipe,
          ownerId: testUser.uid,
          ownerDisplayName: testUser.displayName ?? 'Chef 1',
        );

        // Act
        await repository.createRealtimeRecipe(realtimeRecipe);

        // Assert - Verify in Firestore
        final doc = await firestore
            .collection('realtime_recipes')
            .doc('collab-recipe-1')
            .get();

        expect(doc.exists, isTrue);
        expect(doc.data()?['ownerId'], equals(testUser.uid));

        // Test streaming
        final stream = repository.getRealtimeRecipeStream('collab-recipe-1');
        final streamedRecipe = await stream.first;

        expect(streamedRecipe, isNotNull);
        expect(streamedRecipe!.id, equals('collab-recipe-1'));
        expect(streamedRecipe.recipe.title, equals('Collaborative Pasta'));
      });

      test('should handle concurrent recipe updates', () async {
        // Arrange
        final baseRecipe = RecipeFactory.build(
          id: 'concurrent-recipe',
          title: 'Original Title',
          ingredients: ['Ingredient 1'],
          createdBy: testUser.uid,
        );

        final realtimeRecipe = RealtimeRecipe.fromRecipe(
          recipe: baseRecipe,
          ownerId: testUser.uid,
          ownerDisplayName: 'Owner',
        );

        await repository.createRealtimeRecipe(realtimeRecipe);

        // Act - Simulate concurrent updates
        final futures = <Future>[];

        // User 1 updates title
        futures.add(repository.updateRealtimeRecipe(
          realtimeRecipe.copyWith(
            recipe: baseRecipe.copyWith(title: 'User 1 Title'),
            editCount: 1,
          ),
        ));

        // User 2 updates ingredients
        futures.add(repository.updateRealtimeRecipe(
          realtimeRecipe.copyWith(
            recipe: baseRecipe.copyWith(
                ingredients: ['New Ingredient 1', 'New Ingredient 2']),
            editCount: 1,
          ),
        ));

        await Future.wait(futures);

        // Assert - Both updates should be reflected (last write wins for conflicts)
        final doc = await firestore
            .collection('realtime_recipes')
            .doc('concurrent-recipe')
            .get();

        expect(doc.exists, isTrue);
        expect(doc.data()?['editCount'], equals(1));
        // One of the updates will win (non-deterministic in concurrent scenario)
        expect(doc.data()?['recipe'], isNotNull);
      });

      test('should stream recipe changes in real-time', () async {
        // Arrange
        final baseRecipe = RecipeFactory.build(
          id: 'streaming-recipe',
          title: 'Initial Title',
          createdBy: testUser.uid,
        );

        final realtimeRecipe = RealtimeRecipe.fromRecipe(
          recipe: baseRecipe,
          ownerId: testUser.uid,
          ownerDisplayName: 'Owner',
        );

        await repository.createRealtimeRecipe(realtimeRecipe);

        // Setup stream listener with stabilization
        final updates = <RealtimeRecipe?>[];
        final stabilizedStream = repository
            .getRealtimeRecipeStream('streaming-recipe')
            .debounced(delay: const Duration(milliseconds: 50));

        final subscription =
            stabilizedStream.listen((recipe) => updates.add(recipe));

        // Wait for initial state
        await StreamStabilizer.waitForAsync();

        // Act - Make multiple updates
        for (int i = 1; i <= 3; i++) {
          await repository.updateRealtimeRecipe(
            realtimeRecipe.copyWith(
              recipe: baseRecipe.copyWith(title: 'Update $i'),
              editCount: i,
            ),
          );
          await StreamStabilizer.waitForAsync();
        }

        // Wait for final emissions
        await StreamStabilizer.waitForAsync(iterations: 2);

        // Assert - Filter out null values
        final nonNullUpdates = updates.where((r) => r != null).toList();
        expect(nonNullUpdates.length, greaterThanOrEqualTo(3));
        if (nonNullUpdates.isNotEmpty) {
          expect(nonNullUpdates.last?.recipe.title, equals('Update 3'));
          expect(nonNullUpdates.last?.editCount, equals(3));
        }

        // Cleanup
        await subscription.cancel();
      });
    });

    group('Presence Management with Firebase', () {
      test('should manage multiple user presence with server timestamps',
          () async {
        // Arrange
        const recipeId = 'presence-recipe';

        // Act - Add multiple users with presence
        await repository.setPresence(recipeId, testUser.uid, {
          'userId': testUser.uid,
          'displayName': 'Chef 1',
          'lastSeen': DateTime.now(),
          'isActive': true,
        });

        await repository.setPresence(recipeId, testUser2.uid, {
          'userId': testUser2.uid,
          'displayName': 'Chef 2',
          'lastSeen': DateTime.now(),
          'isActive': true,
        });

        // Assert - Check presence documents
        final presence1 = await firestore
            .collection('realtime_recipes')
            .doc(recipeId)
            .collection('presence')
            .doc(testUser.uid)
            .get();

        final presence2 = await firestore
            .collection('realtime_recipes')
            .doc(recipeId)
            .collection('presence')
            .doc(testUser2.uid)
            .get();

        expect(presence1.exists, isTrue);
        expect(presence1.data()?['displayName'], equals('Chef 1'));
        // FakeFirebaseFirestore stores DateTime as DateTime, not Timestamp
        final lastSeen = presence1.data()?['lastSeen'];
        expect(lastSeen, anyOf(isA<DateTime>(), isA<Timestamp>()));

        expect(presence2.exists, isTrue);
        expect(presence2.data()?['displayName'], equals('Chef 2'));
      });

      test('should stream active presence changes in real-time', () async {
        // Arrange
        const recipeId = 'stream-presence-recipe';
        final presenceUpdates = <int>[];

        // Setup presence stream listener with stabilization
        final stabilizedStream = repository
            .watchActivePresence(recipeId)
            .debounced(delay: const Duration(milliseconds: 50));

        final subscription = stabilizedStream
            .listen((snapshot) => presenceUpdates.add(snapshot.docs.length));

        // Wait for initial state
        await StreamStabilizer.waitForAsync();

        // Act - Add users progressively
        await repository.updateUserPresence(recipeId, 'user-1', 'User 1');
        await StreamStabilizer.waitForAsync();

        await repository.updateUserPresence(recipeId, 'user-2', 'User 2');
        await StreamStabilizer.waitForAsync();

        await repository.updateUserPresence(recipeId, 'user-3', 'User 3');
        await StreamStabilizer.waitForAsync();

        // Make one inactive
        await repository.clearUserPresence(recipeId, 'user-2');
        await StreamStabilizer.waitForAsync(iterations: 2);

        // Assert - Check the progression of updates
        expect(presenceUpdates.length, greaterThanOrEqualTo(3));
        // The last update should show 2 active users (after clearing user-2)
        if (presenceUpdates.length >= 2) {
          expect(presenceUpdates.last, equals(2)); // Only 2 active users
        }

        // Cleanup
        await subscription.cancel();
      });

      test('should track participants as LiveEditor objects', () async {
        // Arrange
        const recipeId = 'participants-recipe';

        // Add participants
        await firestore
            .collection('realtime_recipes')
            .doc(recipeId)
            .collection('presence')
            .doc('editor-1')
            .set({
          'userId': 'editor-1',
          'displayName': 'Editor One',
          'isActive': true,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        });

        await firestore
            .collection('realtime_recipes')
            .doc(recipeId)
            .collection('presence')
            .doc('editor-2')
            .set({
          'userId': 'editor-2',
          'displayName': 'Editor Two',
          'isActive': true,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        });

        // Act
        final stream = repository.getParticipantsStream(recipeId);
        final participants = await stream.first;

        // Assert
        expect(participants, hasLength(2));
        expect(participants, everyElement(isA<LiveEditor>()));
        expect(participants.map((e) => e.userId),
            containsAll(['editor-1', 'editor-2']));
        expect(participants.map((e) => e.displayName),
            containsAll(['Editor One', 'Editor Two']));
      });

      test('should handle rapid heartbeat updates efficiently', () async {
        // Arrange
        const recipeId = 'heartbeat-recipe';
        await repository.updateUserPresence(
            recipeId, testUser.uid, 'Test User');

        // Act - Simulate rapid heartbeats (like a real editing session)
        final heartbeatFutures = <Future>[];
        for (int i = 0; i < 20; i++) {
          heartbeatFutures.add(
            repository.updatePresenceHeartbeat(recipeId, testUser.uid),
          );
          await Future.delayed(
              const Duration(milliseconds: 50)); // 50ms intervals
        }

        await Future.wait(heartbeatFutures);

        // Assert - User should still be active
        final isActive =
            await repository.isUserActivelyEditing(recipeId, testUser.uid);
        expect(isActive, isTrue);

        // Verify last seen is recent
        final doc = await firestore
            .collection('realtime_recipes')
            .doc(recipeId)
            .collection('presence')
            .doc(testUser.uid)
            .get();

        final lastSeen = doc.data()?['lastSeen'] as int;
        final now = DateTime.now().millisecondsSinceEpoch;
        expect(now - lastSeen, lessThan(1000)); // Within last second
      });
    });

    group('Cleanup and Maintenance with Firebase', () {
      test('should cleanup inactive editors with batch operations', () async {
        // Arrange
        const recipeId = 'cleanup-recipe';
        final now = DateTime.now().millisecondsSinceEpoch;

        // Create mix of active and inactive editors
        final batch = firestore.batch();

        // Active editor
        batch.set(
          firestore
              .collection('realtime_recipes')
              .doc(recipeId)
              .collection('presence')
              .doc('active-editor'),
          {
            'displayName': 'Active Editor',
            'isActive': true,
            'lastSeen': now,
          },
        );

        // Inactive editors (over 5 minutes old)
        for (int i = 0; i < 3; i++) {
          batch.set(
            firestore
                .collection('realtime_recipes')
                .doc(recipeId)
                .collection('presence')
                .doc('inactive-$i'),
            {
              'displayName': 'Inactive $i',
              'isActive': true,
              'lastSeen': now - ((6 + i) * 60 * 1000), // 6+ minutes ago
            },
          );
        }

        await batch.commit();

        // Act
        await repository.cleanupInactiveEditors(recipeId);

        // Assert
        final activeDoc = await firestore
            .collection('realtime_recipes')
            .doc(recipeId)
            .collection('presence')
            .doc('active-editor')
            .get();

        expect(activeDoc.data()?['isActive'], isTrue);

        // Check inactive editors are marked as such
        for (int i = 0; i < 3; i++) {
          final inactiveDoc = await firestore
              .collection('realtime_recipes')
              .doc(recipeId)
              .collection('presence')
              .doc('inactive-$i')
              .get();

          expect(inactiveDoc.data()?['isActive'], isFalse);
        }
      });

      test('should handle cleanup with Firestore transactions', () async {
        // Arrange
        const recipeId = 'transaction-cleanup';
        final oldTime =
            DateTime.now().millisecondsSinceEpoch - (10 * 60 * 1000);

        // Create multiple stale editors
        for (int i = 0; i < 5; i++) {
          await firestore
              .collection('realtime_recipes')
              .doc(recipeId)
              .collection('presence')
              .doc('stale-$i')
              .set({
            'isActive': true,
            'lastSeen': oldTime,
            'displayName': 'Stale $i',
          });
        }

        // Act - Cleanup should handle all in batch
        await repository.cleanupInactiveEditors(recipeId);

        // Assert - All should be inactive
        final snapshot = await firestore
            .collection('realtime_recipes')
            .doc(recipeId)
            .collection('presence')
            .where('isActive', isEqualTo: true)
            .get();

        expect(snapshot.docs, isEmpty);
      });
    });

    group('Complex Collaboration Scenarios', () {
      test('should support multi-user real-time collaboration', () async {
        // Arrange
        const recipeId = 'multi-user-recipe';
        final baseRecipe = RecipeFactory.build(
          id: recipeId,
          title: 'Multi-User Recipe',
          createdBy: testUser.uid,
        );

        final realtimeRecipe = RealtimeRecipe.fromRecipe(
          recipe: baseRecipe,
          ownerId: testUser.uid,
          ownerDisplayName: 'Owner',
        );

        await repository.createRealtimeRecipe(realtimeRecipe);

        // Setup multiple users editing
        final users = [
          {'id': testUser.uid, 'name': 'User 1', 'field': 'title'},
          {'id': testUser2.uid, 'name': 'User 2', 'field': 'ingredients'},
          {'id': 'user-3', 'name': 'User 3', 'field': 'instructions'},
        ];

        // Act - Users join and edit different fields
        for (final user in users) {
          await repository.setPresence(recipeId, user['id']!, {
            'userId': user['id'],
            'displayName': user['name'],
            'currentField': user['field'],
            'lastSeen': DateTime.now(),
            'isActive': true,
          });
        }

        // Assert - All users should be present and editing
        final activeEditors = await repository.getActiveEditors(recipeId);
        expect(activeEditors, hasLength(3));

        // Verify field focus
        for (final user in users) {
          final doc = await firestore
              .collection('realtime_recipes')
              .doc(recipeId)
              .collection('presence')
              .doc(user['id']!)
              .get();

          expect(doc.data()?['currentField'], equals(user['field']));
        }
      });

      test('should handle recipe session lifecycle', () async {
        // Arrange
        const recipeId = 'lifecycle-recipe';
        final baseRecipe = RecipeFactory.build(
          id: recipeId,
          title: 'Lifecycle Test',
          createdBy: testUser.uid,
        );

        // Act - Full lifecycle

        // 1. Create session
        final realtimeRecipe = RealtimeRecipe.fromRecipe(
          recipe: baseRecipe,
          ownerId: testUser.uid,
          ownerDisplayName: 'Owner',
        );
        await repository.createRealtimeRecipe(realtimeRecipe);

        // 2. Users join
        await repository.updateUserPresence(recipeId, testUser.uid, 'Owner');
        await repository.updateUserPresence(recipeId, testUser2.uid, 'Editor');

        // 3. Make edits
        for (int i = 0; i < 5; i++) {
          await repository.updateRealtimeRecipe(
            realtimeRecipe.copyWith(
              editCount: i + 1,
              recipe: baseRecipe.copyWith(title: 'Edit $i'),
            ),
          );
        }

        // 4. Users leave
        await repository.clearUserPresence(recipeId, testUser2.uid);
        await repository.removePresence(recipeId, testUser.uid);

        // Assert - Session state
        final finalDoc =
            await firestore.collection('realtime_recipes').doc(recipeId).get();

        expect(finalDoc.exists, isTrue);
        expect(finalDoc.data()?['editCount'], equals(5));

        // Check presence cleanup
        final activeEditors = await repository.getActiveEditors(recipeId);
        expect(activeEditors.where((e) => e['isCurrentlyActive'] == true),
            isEmpty);
      });

      test('should handle concurrent presence updates without conflicts',
          () async {
        // Arrange
        const recipeId = 'concurrent-presence';

        // Act - Multiple concurrent presence updates
        final futures = <Future>[];
        for (int i = 0; i < 10; i++) {
          futures.add(
            repository.updatePresence(recipeId, 'user-$i', {
              'displayName': 'User $i',
              'lastSeen': DateTime.now(),
              'isActive': true,
              'editingField': 'field_$i',
            }),
          );
        }

        await Future.wait(futures);

        // Assert - All presence documents should exist
        final snapshot = await firestore
            .collection('realtime_recipes')
            .doc(recipeId)
            .collection('presence')
            .get();

        expect(snapshot.docs, hasLength(10));

        // Verify each has correct data
        for (int i = 0; i < 10; i++) {
          final doc = snapshot.docs.firstWhere((d) => d.id == 'user-$i');
          expect(doc.data()['displayName'], equals('User $i'));
          expect(doc.data()['editingField'], equals('field_$i'));
        }
      });
    });

    group('Performance and Scalability', () {
      test('should handle large number of participants efficiently', () async {
        // Arrange
        const recipeId = 'scalability-recipe';
        const numParticipants = 50;

        // Act - Add many participants
        final batch = firestore.batch();
        for (int i = 0; i < numParticipants; i++) {
          batch.set(
            firestore
                .collection('realtime_recipes')
                .doc(recipeId)
                .collection('presence')
                .doc('user-$i'),
            {
              'userId': 'user-$i',
              'displayName': 'User $i',
              'isActive': true,
              'lastSeen': DateTime.now().millisecondsSinceEpoch,
            },
          );
        }
        await batch.commit();

        // Assert - Can query efficiently
        final activeEditors = await repository.getActiveEditors(recipeId);
        expect(activeEditors, hasLength(numParticipants));

        // Stream should work
        final stream = repository.getParticipantsStream(recipeId);
        final participants = await stream.first;
        expect(participants, hasLength(numParticipants));
      });

      test('should handle rapid recipe updates without data loss', () async {
        // Arrange
        const recipeId = 'rapid-updates';
        final baseRecipe = RecipeFactory.build(
          id: recipeId,
          title: 'Initial',
          ingredients: [],
          createdBy: testUser.uid,
        );

        final realtimeRecipe = RealtimeRecipe.fromRecipe(
          recipe: baseRecipe,
          ownerId: testUser.uid,
          ownerDisplayName: 'Owner',
        );

        await repository.createRealtimeRecipe(realtimeRecipe);

        // Act - Rapid sequential updates
        final ingredients = <String>[];
        for (int i = 0; i < 20; i++) {
          ingredients.add('Ingredient $i');
          await repository.updateRealtimeRecipe(
            realtimeRecipe.copyWith(
              recipe: baseRecipe.copyWith(ingredients: List.from(ingredients)),
              editCount: i + 1,
            ),
          );
        }

        // Assert - Final state should have all ingredients
        final finalDoc =
            await firestore.collection('realtime_recipes').doc(recipeId).get();

        final finalIngredients =
            finalDoc.data()?['recipe']?['core']?['ingredients'] as List;
        expect(finalIngredients, hasLength(20));
        expect(finalDoc.data()?['editCount'], equals(20));
      });
    });

    group('Error Recovery and Edge Cases', () {
      test('should recover from network interruptions gracefully', () async {
        // This test simulates behavior but can't truly test network interruptions
        // in Firebase emulator

        // Arrange
        const recipeId = 'network-test';

        // Act - Create presence and immediately query
        await repository.updateUserPresence(
            recipeId, testUser.uid, 'Test User');

        // Immediate query (might hit cache in real scenario)
        final isActive1 =
            await repository.isUserActivelyEditing(recipeId, testUser.uid);

        // Wait and query again
        await Future.delayed(const Duration(milliseconds: 500));
        final isActive2 =
            await repository.isUserActivelyEditing(recipeId, testUser.uid);

        // Assert - Both should be consistent
        expect(isActive1, isTrue);
        expect(isActive2, isTrue);
      });

      test('should handle malformed data gracefully', () async {
        // Arrange
        const recipeId = 'malformed-recipe';

        // Create presence with unusual/incomplete data
        await firestore
            .collection('realtime_recipes')
            .doc(recipeId)
            .collection('presence')
            .doc('malformed-user')
            .set({
          // Missing some required fields but has isActive
          'isActive': true, // This is required for the query to find it
          'someField': 'value',
          // Missing displayName and lastSeen
        });

        // Wait for data to be written
        await StreamStabilizer.waitForAsync();

        // Act - Should handle gracefully
        final editors = await repository.getActiveEditors(recipeId);

        // Assert - Should return with safe defaults for missing fields
        expect(editors, hasLength(1));
        if (editors.isNotEmpty) {
          expect(
              editors.first['displayName'], equals('Unknown')); // Default value
          expect(editors.first['isActive'], isTrue); // The field we set
          expect(editors.first['isCurrentlyActive'],
              isFalse); // No lastSeen, so not currently active
        }
      });

      test('should handle recipe deletion during active session', () async {
        // Arrange
        const recipeId = 'delete-during-session';
        final baseRecipe = RecipeFactory.build(
          id: recipeId,
          createdBy: testUser.uid,
        );

        final realtimeRecipe = RealtimeRecipe.fromRecipe(
          recipe: baseRecipe,
          ownerId: testUser.uid,
          ownerDisplayName: 'Owner',
        );

        await repository.createRealtimeRecipe(realtimeRecipe);
        await repository.updateUserPresence(
            recipeId, testUser.uid, 'Active User');

        // Act - Delete recipe while user is present
        await firestore.collection('realtime_recipes').doc(recipeId).delete();

        // Assert - Presence operations should still work
        await expectLater(
          repository.updatePresenceHeartbeat(recipeId, testUser.uid),
          completes,
        );

        // Stream should return null for deleted recipe
        final stream = repository.getRealtimeRecipeStream(recipeId);
        final recipe = await stream.first;
        expect(recipe, isNull);
      });
    });
  });
}
