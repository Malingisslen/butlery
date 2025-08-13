/// Comprehensive unit tests for CollaborativeRecipeRepository
/// 
/// Tests real-time collaborative recipe editing functionality including
/// presence management, editor tracking, and synchronization operations.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/repositories/collaborative_recipe_repository.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/realtime/live_editor.dart';

import '../../infrastructure/helpers/_base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/recipe_factory.dart';

void main() {
  group('CollaborativeRecipeRepository', () {
    late CollaborativeRecipeRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(RecipeFactory.build());
    });

    setUp(() {
      // Create fake Firestore instance
      fakeFirestore = FakeFirebaseFirestore();
      
      // Create repository with fake Firestore
      repository = CollaborativeRecipeRepository(firestore: fakeFirestore);
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('Realtime Recipe Operations', () {
      test('should create realtime recipe', () async {
        // Arrange
        final baseRecipe = RecipeFactory.build(
          id: 'recipe-1',
          title: 'Test Recipe',
        );
        
        final realtimeRecipe = RealtimeRecipe.fromRecipe(
          recipe: baseRecipe,
          ownerId: 'user-123',
          ownerDisplayName: 'Test User',
        );
        
        // Act
        await repository.createRealtimeRecipe(realtimeRecipe);
        
        // Assert
        final doc = await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .get();
        
        expect(doc.exists, isTrue);
        expect(doc.data()?['ownerId'], equals('user-123'));
        expect(doc.data()?['ownerDisplayName'], equals('Test User'));
      });

      test('should update realtime recipe', () async {
        // Arrange
        final baseRecipe = RecipeFactory.build(
          id: 'recipe-1',
          title: 'Original Recipe',
        );
        
        final realtimeRecipe = RealtimeRecipe.fromRecipe(
          recipe: baseRecipe,
          ownerId: 'user-123',
          ownerDisplayName: 'Test User',
        );
        
        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .set(realtimeRecipe.toFirestore());
        
        final updatedRecipe = realtimeRecipe.copyWith(
          recipe: baseRecipe.copyWith(title: 'Updated Recipe'),
          editCount: 1,
        );
        
        // Act
        await repository.updateRealtimeRecipe(updatedRecipe);
        
        // Assert
        final doc = await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .get();
        
        expect(doc.data()?['editCount'], equals(1));
        expect(doc.data()?['recipe']?['core']?['title'], equals('Updated Recipe'));
      });

      test('should watch realtime recipe changes', () async {
        // Arrange
        final baseRecipe = RecipeFactory.build(
          id: 'recipe-1',
          title: 'Test Recipe',
        );
        
        final realtimeRecipe = RealtimeRecipe.fromRecipe(
          recipe: baseRecipe,
          ownerId: 'user-123',
          ownerDisplayName: 'Test User',
        );
        
        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .set(realtimeRecipe.toFirestore());
        
        // Act
        final stream = repository.watchRealtimeRecipe('recipe-1');
        final snapshot = await stream.first;
        
        // Assert
        expect(snapshot.exists, isTrue);
        expect(snapshot.id, equals('recipe-1'));
        expect(snapshot.data()?['ownerId'], equals('user-123'));
      });

      test('should fetch realtime recipe', () async {
        // Arrange
        final baseRecipe = RecipeFactory.build(
          id: 'recipe-1',
          title: 'Test Recipe',
        );
        
        final realtimeRecipe = RealtimeRecipe.fromRecipe(
          recipe: baseRecipe,
          ownerId: 'user-123',
          ownerDisplayName: 'Test User',
        );
        
        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .set(realtimeRecipe.toFirestore());
        
        // Act
        final snapshot = await repository.fetchRealtimeRecipe('recipe-1');
        
        // Assert
        expect(snapshot.exists, isTrue);
        expect(snapshot.data()?['ownerId'], equals('user-123'));
      });

      test('should stream realtime recipe object', () async {
        // Arrange
        final baseRecipe = RecipeFactory.build(
          id: 'recipe-1',
          title: 'Test Recipe',
        );
        
        final realtimeRecipe = RealtimeRecipe.fromRecipe(
          recipe: baseRecipe,
          ownerId: 'user-123',
          ownerDisplayName: 'Test User',
        );
        
        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .set(realtimeRecipe.toFirestore());
        
        // Act
        final stream = repository.getRealtimeRecipeStream('recipe-1');
        final recipe = await stream.first;
        
        // Assert
        expect(recipe, isNotNull);
        expect(recipe!.id, equals('recipe-1'));
        expect(recipe.ownerId, equals('user-123'));
      });
    });

    group('Presence Management', () {
      test('should set user presence', () async {
        // Arrange
        final presenceData = {
          'userId': 'user-123',
          'displayName': 'Test User',
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
          'isActive': true,
        };
        
        // Act
        await repository.setPresence('recipe-1', 'user-123', presenceData);
        
        // Assert
        final doc = await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-123')
            .get();
        
        expect(doc.exists, isTrue);
        expect(doc.data()?['displayName'], equals('Test User'));
        expect(doc.data()?['isActive'], isTrue);
      });

      test('should update user presence', () async {
        // Arrange
        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-123')
            .set({
          'userId': 'user-123',
          'displayName': 'Test User',
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
          'isActive': true,
          'currentField': null,
        });
        
        final updateData = {
          'currentField': 'ingredients',
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        };
        
        // Act
        await repository.updatePresence('recipe-1', 'user-123', updateData);
        
        // Assert
        final doc = await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-123')
            .get();
        
        expect(doc.data()?['currentField'], equals('ingredients'));
      });

      test('should update presence with convenience method', () async {
        // Arrange
        // No setup needed
        
        // Act
        await repository.updateUserPresence('recipe-1', 'user-123', 'Test User');
        
        // Assert
        final doc = await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-123')
            .get();
        
        expect(doc.exists, isTrue);
        expect(doc.data()?['userId'], equals('user-123'));
        expect(doc.data()?['displayName'], equals('Test User'));
        expect(doc.data()?['isActive'], isTrue);
        expect(doc.data()?['lastSeen'], isNotNull);
      });

      test('should update presence heartbeat', () async {
        // Arrange
        final initialTime = DateTime.now().millisecondsSinceEpoch - 60000; // 1 minute ago
        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-123')
            .set({
          'userId': 'user-123',
          'displayName': 'Test User',
          'lastSeen': initialTime,
          'isActive': true,
        });
        
        // Act
        await repository.updatePresenceHeartbeat('recipe-1', 'user-123');
        
        // Assert
        final doc = await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-123')
            .get();
        
        expect(doc.data()?['lastSeen'], greaterThan(initialTime));
        expect(doc.data()?['isActive'], isTrue);
      });

      test('should clear user presence', () async {
        // Arrange
        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-123')
            .set({
          'userId': 'user-123',
          'displayName': 'Test User',
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
          'isActive': true,
        });
        
        // Act
        await repository.clearUserPresence('recipe-1', 'user-123');
        
        // Assert
        final doc = await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-123')
            .get();
        
        expect(doc.data()?['isActive'], isFalse);
      });

      test('should remove presence completely', () async {
        // Arrange
        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-123')
            .set({
          'userId': 'user-123',
          'displayName': 'Test User',
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
          'isActive': true,
        });
        
        // Act
        await repository.removePresence('recipe-1', 'user-123');
        
        // Assert
        final doc = await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-123')
            .get();
        
        expect(doc.exists, isFalse);
      });

      test('should watch active presence', () async {
        // Arrange
        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-123')
            .set({
          'userId': 'user-123',
          'displayName': 'User 1',
          'isActive': true,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        });
        
        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-456')
            .set({
          'userId': 'user-456',
          'displayName': 'User 2',
          'isActive': true,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        });
        
        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-789')
            .set({
          'userId': 'user-789',
          'displayName': 'User 3',
          'isActive': false, // Inactive
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        });
        
        // Act
        final stream = repository.watchActivePresence('recipe-1');
        final snapshot = await stream.first;
        
        // Assert
        expect(snapshot.docs, hasLength(2));
      });

      test('should get participants stream', () async {
        // Arrange
        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-123')
            .set({
          'userId': 'user-123',
          'displayName': 'User 1',
          'isActive': true,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        });
        
        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-456')
            .set({
          'userId': 'user-456',
          'displayName': 'User 2',
          'isActive': true,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        });
        
        // Act
        final stream = repository.getParticipantsStream('recipe-1');
        final participants = await stream.first;
        
        // Assert
        expect(participants, hasLength(2));
        expect(participants[0], isA<LiveEditor>());
        expect(participants[0].userId, equals('user-123'));
        expect(participants[1].userId, equals('user-456'));
      });
    });

    group('Editor Tracking', () {
      test('should get active editors', () async {
        // Arrange
        final now = DateTime.now().millisecondsSinceEpoch;
        
        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-123')
            .set({
          'displayName': 'Active User',
          'isActive': true,
          'lastSeen': now, // Recent
        });
        
        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-456')
            .set({
          'displayName': 'Old User',
          'isActive': true,
          'lastSeen': now - 120000, // 2 minutes ago (inactive)
        });
        
        // Act
        final editors = await repository.getActiveEditors('recipe-1');
        
        // Assert
        expect(editors, hasLength(2));
        expect(editors[0]['userId'], equals('user-123'));
        expect(editors[0]['isCurrentlyActive'], isTrue);
        expect(editors[1]['userId'], equals('user-456'));
        expect(editors[1]['isCurrentlyActive'], isFalse);
      });

      test('should check if user is actively editing', () async {
        // Arrange
        final now = DateTime.now().millisecondsSinceEpoch;
        
        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-123')
            .set({
          'isActive': true,
          'lastSeen': now,
        });
        
        // Act
        final isActive = await repository.isUserActivelyEditing('recipe-1', 'user-123');
        
        // Assert
        expect(isActive, isTrue);
      });

      test('should return false for inactive user', () async {
        // Arrange
        final oldTime = DateTime.now().millisecondsSinceEpoch - 120000; // 2 minutes ago
        
        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-123')
            .set({
          'isActive': true,
          'lastSeen': oldTime,
        });
        
        // Act
        final isActive = await repository.isUserActivelyEditing('recipe-1', 'user-123');
        
        // Assert
        expect(isActive, isFalse);
      });

      test('should return false for non-existent user', () async {
        // Arrange
        // No setup needed - user doesn't exist
        
        // Act
        final isActive = await repository.isUserActivelyEditing('recipe-1', 'non-existent');
        
        // Assert
        expect(isActive, isFalse);
      });
    });

    group('Cleanup Operations', () {
      test('should cleanup inactive editors', () async {
        // Arrange
        final now = DateTime.now().millisecondsSinceEpoch;
        final oldTime = now - (6 * 60 * 1000); // 6 minutes ago
        
        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-active')
            .set({
          'isActive': true,
          'lastSeen': now,
        });
        
        await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-old')
            .set({
          'isActive': true,
          'lastSeen': oldTime,
        });
        
        // Act
        await repository.cleanupInactiveEditors('recipe-1');
        
        // Assert
        final activeDoc = await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-active')
            .get();
        
        final oldDoc = await fakeFirestore
            .collection('realtime_recipes')
            .doc('recipe-1')
            .collection('presence')
            .doc('user-old')
            .get();
        
        expect(activeDoc.data()?['isActive'], isTrue);
        expect(oldDoc.data()?['isActive'], isFalse);
      });

      test('should handle empty presence collection during cleanup', () async {
        // Arrange
        // Empty collection - no setup needed
        
        // Act
        await repository.cleanupInactiveEditors('recipe-1');
        
        // Assert
        expect(true, isTrue); // If we get here, no error was thrown
      });
    });

    group('User Document', () {
      test('should get user document', () async {
        // Arrange
        await fakeFirestore
            .collection('users')
            .doc('user-123')
            .set({
          'uid': 'user-123',
          'displayName': 'Test User',
          'email': 'test@example.com',
        });
        
        // Act
        final doc = await repository.getUserDocument('user-123');
        
        // Assert
        expect(doc.exists, isTrue);
        expect(doc.data()?['displayName'], equals('Test User'));
      });
    });
  });
}