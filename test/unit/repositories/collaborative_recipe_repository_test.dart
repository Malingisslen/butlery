/// Comprehensive unit tests for CollaborativeRecipeRepository
/// 
/// Tests real-time collaborative recipe editing functionality including
/// presence management, editor tracking, and synchronization operations.
library;

// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/collaborative_recipe_repository.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/realtime/live_editor.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/recipe_factory.dart';

// Local mocks for sealed Firebase classes
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference<T> extends Mock implements CollectionReference<T> {}
class MockDocumentReference<T> extends Mock implements DocumentReference<T> {}
class MockDocumentSnapshot<T> extends Mock implements DocumentSnapshot<T> {}
class MockQuery<T> extends Mock implements Query<T> {}
class MockQuerySnapshot<T> extends Mock implements QuerySnapshot<T> {}
class MockQueryDocumentSnapshot<T> extends Mock implements QueryDocumentSnapshot<T> {}
class MockWriteBatch extends Mock implements WriteBatch {}

void main() {
  group('CollaborativeRecipeRepository', () {
    late CollaborativeRecipeRepository repository;
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference<Map<String, dynamic>> mockRealtimeCollection;
    late MockCollectionReference<Map<String, dynamic>> mockPresenceCollection;
    late MockDocumentReference<Map<String, dynamic>> mockDocRef;
    late MockDocumentSnapshot<Map<String, dynamic>> mockDocSnapshot;
    late MockQuery<Map<String, dynamic>> mockQuery;
    late MockQuerySnapshot<Map<String, dynamic>> mockQuerySnapshot;
    late MockWriteBatch mockBatch;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(RecipeFactory.build());
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      
      // Initialize mocks
      mockFirestore = MockFirebaseFirestore();
      mockRealtimeCollection = MockCollectionReference<Map<String, dynamic>>();
      mockPresenceCollection = MockCollectionReference<Map<String, dynamic>>();
      mockDocRef = MockDocumentReference<Map<String, dynamic>>();
      mockDocSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
      mockQuery = MockQuery<Map<String, dynamic>>();
      mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      mockBatch = MockWriteBatch();
      
      // Setup Firestore mock structure
      when(() => mockFirestore.collection('realtime_recipes')).thenReturn(mockRealtimeCollection);
      when(() => mockFirestore.collection('presence')).thenReturn(mockPresenceCollection);
      when(() => mockRealtimeCollection.doc(any())).thenReturn(mockDocRef);
      when(() => mockPresenceCollection.doc(any())).thenReturn(mockDocRef);
      
      // Setup batch operations - WriteBatch methods return self for chaining
      when(() => mockFirestore.batch()).thenReturn(mockBatch);
      when<dynamic>(() => mockBatch.set(any(), any(), any())).thenReturn(mockBatch);
      when<dynamic>(() => mockBatch.update(any(), any())).thenReturn(mockBatch);
      when<dynamic>(() => mockBatch.delete(any())).thenReturn(mockBatch);
      when(() => mockBatch.commit()).thenAnswer((_) async {});
      
      // Setup default doc operations
      when(() => mockDocRef.set(any(), any())).thenAnswer((_) async {});
      when(() => mockDocRef.set(any())).thenAnswer((_) async {});
      when(() => mockDocRef.update(any())).thenAnswer((_) async {});
      when(() => mockDocRef.delete()).thenAnswer((_) async {});
      when(() => mockDocRef.get()).thenAnswer((_) async => mockDocSnapshot);
      
      // Create repository with mocked Firestore
      repository = CollaborativeRecipeRepository(firestore: mockFirestore);
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
        verify(() => mockDocRef.set(any(), any())).called(1);
        final captured = verify(() => mockDocRef.set(captureAny(), any())).captured.single;
        expect(captured['ownerId'], equals('user-123'));
        expect(captured['ownerDisplayName'], equals('Test User'));
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
        
        // Setup existing recipe
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.data()).thenReturn(realtimeRecipe.toFirestore());
        
        final updatedRecipe = realtimeRecipe.copyWith(
          recipe: baseRecipe.copyWith(title: 'Updated Recipe'),
          editCount: 1,
        );
        
        // Act
        await repository.updateRealtimeRecipe(updatedRecipe);
        
        // Assert
        verify(() => mockDocRef.update(any())).called(1);
        final captured = verify(() => mockDocRef.update(captureAny())).captured.single;
        expect(captured['editCount'], equals(1));
        expect(captured['recipe']['core']['title'], equals('Updated Recipe'));
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
        
        // Setup stream response
        when(() => mockDocRef.snapshots()).thenAnswer((_) => Stream.value(mockDocSnapshot));
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.id).thenReturn('recipe-1');
        when(() => mockDocSnapshot.data()).thenReturn(realtimeRecipe.toFirestore());
        
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
        
        // Setup get response
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.data()).thenReturn(realtimeRecipe.toFirestore());
        
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
        
        // Setup stream response
        when(() => mockDocRef.snapshots()).thenAnswer((_) => Stream.value(mockDocSnapshot));
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.id).thenReturn('recipe-1');
        when(() => mockDocSnapshot.data()).thenReturn(realtimeRecipe.toFirestore());
        
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
        
        // Setup presence collection
        final mockPresenceDocRef = MockDocumentReference<Map<String, dynamic>>();
        when(() => mockDocRef.collection('presence')).thenReturn(mockPresenceCollection);
        when(() => mockPresenceCollection.doc('user-123')).thenReturn(mockPresenceDocRef);
        when(() => mockPresenceDocRef.set(any(), any())).thenAnswer((_) async {});
        when(() => mockPresenceDocRef.set(any())).thenAnswer((_) async {});
        
        // Act
        await repository.setPresence('recipe-1', 'user-123', presenceData);
        
        // Assert
        verify(() => mockPresenceDocRef.set(any(), any())).called(1);
        final captured = verify(() => mockPresenceDocRef.set(captureAny(), any())).captured.single;
        expect(captured['displayName'], equals('Test User'));
        expect(captured['isActive'], isTrue);
      });

      test('should update user presence', () async {
        // Arrange
        final updateData = {
          'currentField': 'ingredients',
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        };
        
        // Setup presence collection
        final mockPresenceDocRef = MockDocumentReference<Map<String, dynamic>>();
        when(() => mockDocRef.collection('presence')).thenReturn(mockPresenceCollection);
        when(() => mockPresenceCollection.doc('user-123')).thenReturn(mockPresenceDocRef);
        when(() => mockPresenceDocRef.update(any())).thenAnswer((_) async {});
        
        // Act
        await repository.updatePresence('recipe-1', 'user-123', updateData);
        
        // Assert
        verify(() => mockPresenceDocRef.update(any())).called(1);
        final captured = verify(() => mockPresenceDocRef.update(captureAny())).captured.single;
        expect(captured['currentField'], equals('ingredients'));
      });

      test('should update presence with convenience method', () async {
        // Arrange
        final mockPresenceDocRef = MockDocumentReference<Map<String, dynamic>>();
        when(() => mockDocRef.collection('presence')).thenReturn(mockPresenceCollection);
        when(() => mockPresenceCollection.doc('user-123')).thenReturn(mockPresenceDocRef);
        when(() => mockPresenceDocRef.set(any(), any())).thenAnswer((_) async {});
        when(() => mockPresenceDocRef.set(any())).thenAnswer((_) async {});
        
        // Act
        await repository.updateUserPresence('recipe-1', 'user-123', 'Test User');
        
        // Assert
        verify(() => mockPresenceDocRef.set(any(), any())).called(1);
        final captured = verify(() => mockPresenceDocRef.set(captureAny(), any())).captured.single;
        expect(captured['userId'], equals('user-123'));
        expect(captured['displayName'], equals('Test User'));
        expect(captured['isActive'], isTrue);
        expect(captured['lastSeen'], isNotNull);
      });

      test('should update presence heartbeat', () async {
        // Arrange
        final initialTime = DateTime.now().millisecondsSinceEpoch - 60000; // 1 minute ago
        
        // Setup presence collection
        final mockPresenceDocRef = MockDocumentReference<Map<String, dynamic>>();
        when(() => mockDocRef.collection('presence')).thenReturn(mockPresenceCollection);
        when(() => mockPresenceCollection.doc('user-123')).thenReturn(mockPresenceDocRef);
        when(() => mockPresenceDocRef.update(any())).thenAnswer((_) async {});
        
        // Act
        await repository.updatePresenceHeartbeat('recipe-1', 'user-123');
        
        // Assert
        verify(() => mockPresenceDocRef.update(any())).called(1);
        final captured = verify(() => mockPresenceDocRef.update(captureAny())).captured.single;
        expect(captured['lastSeen'], greaterThan(initialTime));
        expect(captured['isActive'], isTrue);
      });

      test('should clear user presence', () async {
        // Arrange
        final mockPresenceDocRef = MockDocumentReference<Map<String, dynamic>>();
        when(() => mockDocRef.collection('presence')).thenReturn(mockPresenceCollection);
        when(() => mockPresenceCollection.doc('user-123')).thenReturn(mockPresenceDocRef);
        when(() => mockPresenceDocRef.update(any())).thenAnswer((_) async {});
        
        // Act
        await repository.clearUserPresence('recipe-1', 'user-123');
        
        // Assert
        verify(() => mockPresenceDocRef.update(any())).called(1);
        final captured = verify(() => mockPresenceDocRef.update(captureAny())).captured.single;
        expect(captured['isActive'], isFalse);
      });

      test('should remove presence completely', () async {
        // Arrange
        final mockPresenceDocRef = MockDocumentReference<Map<String, dynamic>>();
        when(() => mockDocRef.collection('presence')).thenReturn(mockPresenceCollection);
        when(() => mockPresenceCollection.doc('user-123')).thenReturn(mockPresenceDocRef);
        when(() => mockPresenceDocRef.delete()).thenAnswer((_) async {});
        
        // Act
        await repository.removePresence('recipe-1', 'user-123');
        
        // Assert
        verify(() => mockPresenceDocRef.delete()).called(1);
      });

      test('should watch active presence', () async {
        // Arrange
        final mockDoc1 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        final mockDoc2 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        
        when(() => mockDoc1.id).thenReturn('user-123');
        when(() => mockDoc1.data()).thenReturn({
          'userId': 'user-123',
          'displayName': 'User 1',
          'isActive': true,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        });
        
        when(() => mockDoc2.id).thenReturn('user-456');
        when(() => mockDoc2.data()).thenReturn({
          'userId': 'user-456',
          'displayName': 'User 2',
          'isActive': true,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        });
        
        // Note: user-789 is filtered out by the query (isActive: false)
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2]);
        
        when(() => mockDocRef.collection('presence')).thenReturn(mockPresenceCollection);
        when(() => mockPresenceCollection.where('isActive', isEqualTo: true))
            .thenReturn(mockQuery);
        when(() => mockQuery.orderBy(any(), descending: any(named: 'descending')))
            .thenReturn(mockQuery);
        when(() => mockQuery.snapshots()).thenAnswer((_) => Stream.value(mockQuerySnapshot));
        
        // Act
        final stream = repository.watchActivePresence('recipe-1');
        final snapshot = await stream.first;
        
        // Assert
        expect(snapshot.docs, hasLength(2));
      });

      test('should get participants stream', () async {
        // Arrange
        final mockDoc1 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        final mockDoc2 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        
        when(() => mockDoc1.id).thenReturn('user-123');
        when(() => mockDoc1.data()).thenReturn({
          'userId': 'user-123',
          'displayName': 'User 1',
          'isActive': true,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        });
        
        when(() => mockDoc2.id).thenReturn('user-456');
        when(() => mockDoc2.data()).thenReturn({
          'userId': 'user-456',
          'displayName': 'User 2',
          'isActive': true,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        });
        
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2]);
        when(() => mockDocRef.collection('presence')).thenReturn(mockPresenceCollection);
        when(() => mockPresenceCollection.where(any(), isEqualTo: any(named: 'isEqualTo')))
            .thenReturn(mockQuery);
        when(() => mockQuery.snapshots()).thenAnswer((_) => Stream.value(mockQuerySnapshot));
        
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
        
        final mockDoc1 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        final mockDoc2 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        
        when(() => mockDoc1.id).thenReturn('user-123');
        when(() => mockDoc1.data()).thenReturn({
          'displayName': 'Active User',
          'isActive': true,
          'lastSeen': now, // Recent
        });
        
        when(() => mockDoc2.id).thenReturn('user-456');
        when(() => mockDoc2.data()).thenReturn({
          'displayName': 'Old User',
          'isActive': true,
          'lastSeen': now - 120000, // 2 minutes ago (inactive)
        });
        
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2]);
        when(() => mockDocRef.collection('presence')).thenReturn(mockPresenceCollection);
        when(() => mockPresenceCollection.where(any(), isEqualTo: any(named: 'isEqualTo')))
            .thenReturn(mockQuery);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        
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
        
        final mockPresenceDocRef = MockDocumentReference<Map<String, dynamic>>();
        final mockPresenceSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockDocRef.collection('presence')).thenReturn(mockPresenceCollection);
        when(() => mockPresenceCollection.doc('user-123')).thenReturn(mockPresenceDocRef);
        when(() => mockPresenceDocRef.get()).thenAnswer((_) async => mockPresenceSnapshot);
        when(() => mockPresenceSnapshot.exists).thenReturn(true);
        when(() => mockPresenceSnapshot.data()).thenReturn({
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
        
        final mockPresenceDocRef = MockDocumentReference<Map<String, dynamic>>();
        final mockPresenceSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockDocRef.collection('presence')).thenReturn(mockPresenceCollection);
        when(() => mockPresenceCollection.doc('user-123')).thenReturn(mockPresenceDocRef);
        when(() => mockPresenceDocRef.get()).thenAnswer((_) async => mockPresenceSnapshot);
        when(() => mockPresenceSnapshot.exists).thenReturn(true);
        when(() => mockPresenceSnapshot.data()).thenReturn({
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
        final mockPresenceDocRef = MockDocumentReference<Map<String, dynamic>>();
        final mockPresenceSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockDocRef.collection('presence')).thenReturn(mockPresenceCollection);
        when(() => mockPresenceCollection.doc('non-existent')).thenReturn(mockPresenceDocRef);
        when(() => mockPresenceDocRef.get()).thenAnswer((_) async => mockPresenceSnapshot);
        when(() => mockPresenceSnapshot.exists).thenReturn(false);
        
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
        
        final mockDoc1 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        final mockDoc2 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        
        when(() => mockDoc1.id).thenReturn('user-active');
        when(() => mockDoc1.data()).thenReturn({
          'isActive': true,
          'lastSeen': now,
        });
        
        when(() => mockDoc2.id).thenReturn('user-old');
        when(() => mockDoc2.data()).thenReturn({
          'isActive': true,
          'lastSeen': oldTime,
        });
        
        final mockOldDocRef = MockDocumentReference<Map<String, dynamic>>();
        when(() => mockPresenceCollection.doc('user-old')).thenReturn(mockOldDocRef);
        when(() => mockOldDocRef.update(any())).thenAnswer((_) async {});
        
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2]);
        when(() => mockDocRef.collection('presence')).thenReturn(mockPresenceCollection);
        when(() => mockPresenceCollection.get()).thenAnswer((_) async => mockQuerySnapshot);
        
        // Act
        await repository.cleanupInactiveEditors('recipe-1');
        
        // Assert
        verify(() => mockOldDocRef.update(any())).called(1);
        final captured = verify(() => mockOldDocRef.update(captureAny())).captured.single;
        expect(captured['isActive'], isFalse);
      });

      test('should handle empty presence collection during cleanup', () async {
        // Arrange
        when(() => mockQuerySnapshot.docs).thenReturn([]);
        when(() => mockDocRef.collection('presence')).thenReturn(mockPresenceCollection);
        when(() => mockPresenceCollection.get()).thenAnswer((_) async => mockQuerySnapshot);
        
        // Act
        await repository.cleanupInactiveEditors('recipe-1');
        
        // Assert
        expect(true, isTrue); // If we get here, no error was thrown
      });
    });

    group('User Document', () {
      test('should get user document', () async {
        // Arrange
        final mockUsersCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockUserDoc = MockDocumentReference<Map<String, dynamic>>();
        final mockUserSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        
        when(() => mockFirestore.collection('users')).thenReturn(mockUsersCollection);
        when(() => mockUsersCollection.doc('user-123')).thenReturn(mockUserDoc);
        when(() => mockUserDoc.get()).thenAnswer((_) async => mockUserSnapshot);
        when(() => mockUserSnapshot.exists).thenReturn(true);
        when(() => mockUserSnapshot.data()).thenReturn({
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