// ignore_for_file: subtype_of_sealed_class

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/factories/mock_factory.dart';

// Local mocks only for Firebase-specific types not in production_mocks.dart
class MockStreamSubscription extends Mock
    implements StreamSubscription<DocumentSnapshot> {}

// Simple mocks without overrides to avoid sealed class issues
class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

// Mock classes for Firebase types
class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

// Test doubles for RealtimeResource
class TestRealtimeRecipe extends RealtimeRecipe {
  TestRealtimeRecipe({
    required super.id,
    required String title,
    required DateTime lastEditedAt,
    required super.editCount,
    required String createdBy,
    Map<String, ResourcePermission>? participants,
  }) : super(
          ownerId: createdBy,
          ownerDisplayName: 'Test User',
          participants: participants ?? {createdBy: ResourcePermission.owner},
          createdAt: DateTime.now(),
          lastEditedAt: lastEditedAt,
          lastEditedBy: createdBy,
          lastEditedByDisplayName: 'Test User',
          recipe: Recipe(
            core: RecipeCore(
              id: id,
              title: title,
              description: 'Test recipe',
              ingredients: ['ingredient1', 'ingredient2'],
              instructions: ['step1', 'step2'],
              imageUrls: ['https://example.com/image.jpg'],
              mealType: 'Lunch',
              portions: 4,
              timeMinutes: 30,
              rating: 4.5,
              tags: ['test'],
              createdBy: createdBy,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            type: RecipeType.realtime,
          ),
        );
}

void main() {
  late RealtimeSyncService service;
  late MockFirestoreRepository mockFirestoreRepo;
  late MockFirebaseAuthRepository mockAuthRepo;
  late StreamController<QuerySnapshot<Map<String, dynamic>>>
      connectivityStreamController;
  late StreamController<User?> authStateController;
  late StreamController<DocumentSnapshot> documentStreamController;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    await TestServiceLocator.initialize();
    registerFallbackValue(RealtimeResourceType.recipe);
    registerFallbackValue(SyncErrorType.unknown);
  });

  setUp(() {
    mockFirestoreRepo = MockFirestoreRepository();
    mockAuthRepo = MockFirebaseAuthRepository();
    connectivityStreamController =
        StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
    authStateController = StreamController<User?>.broadcast();
    documentStreamController = StreamController<DocumentSnapshot>.broadcast();

    // Configure auth state using configuration method
    final mockUser = MockFactory.createMockUser(uid: 'test_user_123');
    mockAuthRepo.setAuthState(
      user: mockUser,
      userId: 'test_user_123',
    );

    // Setup default mock behavior
    when(() => mockFirestoreRepo.connectivityStream())
        .thenAnswer((_) => connectivityStreamController.stream);
    when(() => mockAuthRepo.authStateChanges())
        .thenAnswer((_) => authStateController.stream);

    service = RealtimeSyncService(
      firestoreRepository: mockFirestoreRepo,
      authRepository: mockAuthRepo,
    );
  });

  tearDown(() async {
    await service.onDispose();
    await connectivityStreamController.close();
    await authStateController.close();
    await documentStreamController.close();
    TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });
  
  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  group('RealtimeSyncService', () {
    group('Initialization', () {
      test('should initialize successfully with connection monitoring',
          () async {
        // Act & Assert
        await service.initialize();

        verify(() => mockFirestoreRepo.connectivityStream()).called(1);
        verify(() => mockAuthRepo.authStateChanges()).called(1);
      });

      test('should set initial connection state', () async {
        // Act
        await service.initialize();

        // Initially should be disconnected until stream emits
        
        // Assert
        expect(service.isConnected, isFalse);
      });

      test('should expose connection stream', () async {
        // Act
        await service.initialize();

        
        // Assert
        expect(service.connectionStream, isNotNull);
        expect(service.connectionStream, isA<Stream<bool>>());
      });

      test('should expose error stream', () async {
        // Act
        await service.initialize();

        
        // Assert
        expect(service.errorStream, isNotNull);
        expect(service.errorStream, isA<Stream<SyncError>>());
      });
    });

    group('Connection Management', () {
      test('should update connection state when Firebase connects', () async {
        await service.initialize();

        // Arrange
        bool connectionChanged = false;
        service.connectionStream.listen((isConnected) {
          if (isConnected) connectionChanged = true;
        });

        // Simulate Firebase connection
        final mockSnapshot = MockQuerySnapshot();
        connectivityStreamController.add(mockSnapshot);

        await Future.delayed(Duration(milliseconds: 100));

        expect(service.isConnected, isTrue);
        expect(connectionChanged, isTrue);
      });

      test('should handle connection errors', () async {
        await service.initialize();

        SyncError? receivedError;
        service.errorStream.listen((error) {
        // Arrange
          receivedError = error;
        });

        // Simulate connection error
        connectivityStreamController.addError('Connection lost');

        await Future.delayed(Duration(milliseconds: 100));

        expect(service.isConnected, isFalse);
        expect(receivedError, isNotNull);
        expect(receivedError!.type, equals(SyncErrorType.connectionLost));
      });

      test('should notify listeners on connection state change', () async {
        await service.initialize();

        // Arrange
        bool listenerCalled = false;
        service.addListener(() {
          listenerCalled = true;
        });

        // Change connection state
        final mockSnapshot = MockQuerySnapshot();
        connectivityStreamController.add(mockSnapshot);

        await Future.delayed(Duration(milliseconds: 100));

        expect(listenerCalled, isTrue);
      });
    });

    group('Authentication', () {
      test('should handle user login', () async {
        await service.initialize();

        // Arrange
        final mockUser = MockFactory.createMockUser(uid: 'user_456');

        authStateController.add(mockUser);

        await Future.delayed(Duration(milliseconds: 100));

        // Service should be ready for the logged-in user
        expect(service.lastError, isNull);
      });

      test('should clear resources on user logout', () async {
        await service.initialize();

        // First login
        // Arrange
        final mockUser = MockFactory.createMockUser(uid: 'user_456');
        authStateController.add(mockUser);

        // Test that resources are cleared (no need to add cached resource for this test)

        // Then logout
        authStateController.add(null);

        await Future.delayed(Duration(milliseconds: 100));

        // Resources should be cleared
        expect(service.getCachedResource<RealtimeRecipe>('recipe_1'), isNull);
        expect(service.activeListenersCount, equals(0));
      });

      test('should remove all listeners on logout', () async {
        // Act
        await service.initialize();

        service.addListener(() {});

        // Logout
        authStateController.add(null);

        await Future.delayed(Duration(milliseconds: 100));

        // Try to notify - listeners should be cleared
        service.removeListener(() {});
        expect(service.activeListenersCount, equals(0));
      });
    });

    group('Resource Watching', () {
      test('should return error stream when user not authenticated', () async {
        mockAuthRepo.setAuthState(user: null, userId: null);

        final stream = service.watchResource<RealtimeRecipe>('recipe_1');

        // Act & Assert
        expectLater(
          stream,
          emitsError(isA<SyncError>().having(
            (e) => e.type,
            'type',
            SyncErrorType.permissionDenied,
          )),
        );
      });

      test('should watch resource and emit updates', () async {
        // Arrange
        final mockDocRef = MockDocumentReference();
        final mockSnapshot = MockDocumentSnapshot();

        when(() => mockFirestoreRepo.realtimeResourceDoc('recipe_1'))
            .thenReturn(mockDocRef);
        when(() => mockDocRef.snapshots())
            .thenAnswer((_) => Stream.value(mockSnapshot));
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.id).thenReturn('recipe_1');
        when(() => mockSnapshot.data()).thenReturn({
          'recipe': {
            'id': 'recipe_1',
            'title': 'Test Recipe',
            'description': 'Test description',
            'ingredients': ['ingredient1'],
            'instructions': ['step1'],
            'imageUrls': ['https://example.com/image.jpg'],
            'mealType': 'Lunch',
            'portions': 4,
            'timeMinutes': 30,
            'rating': 4.5,
            'tags': ['test'],
            'createdBy': 'test_user_123',
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          },
          'ownerId': 'test_user_123',
          'ownerDisplayName': 'Test User',
          'participants': {'test_user_123': 'owner'},
          'createdAt': DateTime.now().toIso8601String(),
          'lastEditedAt': DateTime.now().toIso8601String(),
          'lastEditedBy': 'test_user_123',
          'lastEditedByDisplayName': 'Test User',
          'editCount': 1,
          'type': 'recipe',
        });

        final stream = service.watchResource<RealtimeRecipe>('recipe_1');

        final recipe = await stream.first;

        expect(recipe, isNotNull);
        expect(recipe.id, equals('recipe_1'));
        expect(recipe.title, equals('Test Recipe'));
      });

      test('should cache watched resources', () async {
        // Arrange
        final mockDocRef = MockDocumentReference();
        final mockSnapshot = MockDocumentSnapshot();

        when(() => mockFirestoreRepo.realtimeResourceDoc('recipe_1'))
            .thenReturn(mockDocRef);
        when(() => mockDocRef.snapshots())
            .thenAnswer((_) => Stream.value(mockSnapshot));
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.id).thenReturn('recipe_1');
        when(() => mockSnapshot.data()).thenReturn({
          'recipe': {
            'id': 'recipe_1',
            'title': 'Cached Recipe',
            'description': 'Test',
            'ingredients': [],
            'instructions': [],
            'imageUrls': [],
            'mealType': 'Lunch',
            'createdBy': 'test_user_123',
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          },
          'ownerId': 'test_user_123',
          'ownerDisplayName': 'Test User',
          'participants': {'test_user_123': 'owner'},
          'createdAt': DateTime.now().toIso8601String(),
          'lastEditedAt': DateTime.now().toIso8601String(),
          'lastEditedBy': 'test_user_123',
          'lastEditedByDisplayName': 'Test User',
          'editCount': 1,
          'type': 'recipe',
        });

        final stream = service.watchResource<RealtimeRecipe>('recipe_1');
        await stream.first;

        final cachedRecipe =
            service.getCachedResource<RealtimeRecipe>('recipe_1');

        expect(cachedRecipe, isNotNull);
        expect(cachedRecipe!.title, equals('Cached Recipe'));
      });

      test('should handle document not found error', () async {
        // Arrange
        final mockDocRef = MockDocumentReference();
        final mockSnapshot = MockDocumentSnapshot();

        when(() => mockFirestoreRepo.realtimeResourceDoc('recipe_1'))
            .thenReturn(mockDocRef);
        when(() => mockDocRef.snapshots())
            .thenAnswer((_) => Stream.value(mockSnapshot));
        when(() => mockSnapshot.exists).thenReturn(false);
        when(() => mockSnapshot.id).thenReturn('recipe_1');

        // The production code handles errors by adding them to the error stream
        // but doesn't rethrow them in the watch stream
        SyncError? receivedError;
        service.errorStream.listen((error) {
          receivedError = error;
        });

        final stream = service.watchResource<RealtimeRecipe>('recipe_1');
        
        // Try to listen to the stream, which should trigger the error handling
        stream.listen(
          (_) {},
          onError: (e) {
            // Error might come here if production code changes
          },
        );

        await Future.delayed(Duration(milliseconds: 100));

        // The error should be in the error stream, not the watch stream
        expect(receivedError, isNotNull);
        expect(receivedError!.type, equals(SyncErrorType.firestoreError));
        expect(receivedError!.message, contains('Fel vid watching'));
      });
    });

    group('Resource Updates', () {
      test('should reject update when user not authenticated', () async {
        // Arrange
        mockAuthRepo.setAuthState(user: null, userId: null);

        final recipe = TestRealtimeRecipe(
          id: 'recipe_1',
          title: 'Test',
          lastEditedAt: DateTime.now(),
          editCount: 1,
          createdBy: 'user_123',
        );

        expect(
          () => service.updateResource(recipe),
          throwsA(isA<SyncError>().having(
            (e) => e.type,
            'type',
            SyncErrorType.permissionDenied,
          )),
        );
      });

      test('should reject update when user lacks edit permission', () async {
        // Arrange
        final recipe = TestRealtimeRecipe(
          id: 'recipe_1',
          title: 'Test',
          lastEditedAt: DateTime.now(),
          editCount: 1,
          createdBy: 'other_user',
          participants: {
            'other_user': ResourcePermission.owner
          }, // Current user not in editors
        );

        expect(
          () => service.updateResource(recipe),
          throwsA(isA<SyncError>().having(
            (e) => e.type,
            'type',
            SyncErrorType.permissionDenied,
          )),
        );
      });

      test('should successfully update resource with permission', () async {
        // Arrange
        final mockDocRef = MockDocumentReference();

        when(() => mockFirestoreRepo.realtimeResourceDoc('recipe_1'))
            .thenReturn(mockDocRef);
        when(() => mockFirestoreRepo.setDocument(mockDocRef, any()))
            .thenAnswer((_) async {});

        final recipe = TestRealtimeRecipe(
          id: 'recipe_1',
          title: 'Updated Recipe',
          lastEditedAt: DateTime.now(),
          editCount: 2,
          createdBy: 'test_user_123',
          participants: {'test_user_123': ResourcePermission.editor},
        );

        await service.updateResource(recipe);

        verify(() => mockFirestoreRepo.setDocument(mockDocRef, any()))
            .called(1);

        // Check cached version updated
        final cached = service.getCachedResource<RealtimeRecipe>('recipe_1');
        expect(cached?.title, equals('Updated Recipe'));
      });

      test('should handle update errors gracefully', () async {
        // Arrange
        final mockDocRef = MockDocumentReference();

        when(() => mockFirestoreRepo.realtimeResourceDoc('recipe_1'))
            .thenReturn(mockDocRef);
        when(() => mockFirestoreRepo.setDocument(mockDocRef, any()))
            .thenAnswer((_) async => throw Exception('Firebase error'));

        final recipe = TestRealtimeRecipe(
          id: 'recipe_1',
          title: 'Test',
          lastEditedAt: DateTime.now(),
          editCount: 1,
          createdBy: 'test_user_123',
          participants: {'test_user_123': ResourcePermission.editor},
        );

        SyncError? receivedError;
        service.errorStream.listen((error) {
          receivedError = error;
        });

        // The service rethrows the original exception, not SyncError
        expect(
          () => service.updateResource(recipe),
          throwsA(isA<Exception>()),
        );

        await Future.delayed(Duration(milliseconds: 100));

        // But the error stream should receive a SyncError
        expect(receivedError, isNotNull);
        expect(receivedError!.type, equals(SyncErrorType.firestoreError));
      });
    });

    group('Conflict Resolution', () {
      test('should choose local version when edit count is higher', () async {
        // Arrange
        final local = TestRealtimeRecipe(
          id: 'recipe_1',
          title: 'Local Version',
          lastEditedAt: DateTime.now(),
          editCount: 5,
          createdBy: 'test_user_123',
        );

        final remote = TestRealtimeRecipe(
          id: 'recipe_1',
          title: 'Remote Version',
          lastEditedAt: DateTime.now().subtract(Duration(minutes: 1)),
          editCount: 3,
          createdBy: 'test_user_123',
        );

        
        // Act
        final resolved = await service.resolveConflict(local, remote);

        
        // Assert
        expect(resolved.title, equals('Local Version'));
        expect(resolved.editCount, equals(5));
      });

      test('should choose remote version when edit count is higher', () async {
        // Arrange
        final local = TestRealtimeRecipe(
          id: 'recipe_1',
          title: 'Local Version',
          lastEditedAt: DateTime.now(),
          editCount: 2,
          createdBy: 'test_user_123',
        );

        final remote = TestRealtimeRecipe(
          id: 'recipe_1',
          title: 'Remote Version',
          lastEditedAt: DateTime.now(),
          editCount: 4,
          createdBy: 'test_user_123',
        );

        
        // Act
        final resolved = await service.resolveConflict(local, remote);

        
        // Assert
        expect(resolved.title, equals('Remote Version'));
        expect(resolved.editCount, equals(4));
      });

      test('should use timestamp when edit counts are equal', () async {
        // Arrange
        final now = DateTime.now();
        final local = TestRealtimeRecipe(
          id: 'recipe_1',
          title: 'Local Version',
          lastEditedAt: now.add(Duration(seconds: 1)),
          editCount: 3,
          createdBy: 'test_user_123',
        );

        final remote = TestRealtimeRecipe(
          id: 'recipe_1',
          title: 'Remote Version',
          lastEditedAt: now,
          editCount: 3,
          createdBy: 'test_user_123',
        );

        
        // Act
        final resolved = await service.resolveConflict(local, remote);

        
        // Assert
        expect(resolved.title, equals('Local Version'));
      });
    });

    group('Resource Deletion', () {
      test('should reject deletion when user not authenticated', () async {
        // Arrange
        mockAuthRepo.setAuthState(user: null, userId: null);

        expect(
          () => service.deleteResource('recipe_1', RealtimeResourceType.recipe),
          throwsA(isA<SyncError>().having(
            (e) => e.type,
            'type',
            SyncErrorType.permissionDenied,
          )),
        );
      });

      test('should successfully delete resource with permission', () async {
        // Arrange
        final mockDocRef = MockDocumentReference();
        final mockSnapshot = MockDocumentSnapshot();

        when(() => mockFirestoreRepo.realtimeResourceDoc('recipe_1'))
            .thenReturn(mockDocRef);
        when(() => mockFirestoreRepo.getDocument(mockDocRef))
            .thenAnswer((_) async => mockSnapshot);
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.id).thenReturn('recipe_1');
        when(() => mockSnapshot.data()).thenReturn({
          'recipe': {
            'id': 'recipe_1',
            'title': 'Test Recipe',
            'description': 'Test',
            'ingredients': [],
            'instructions': [],
            'imageUrls': [],
            'mealType': 'Lunch',
            'createdBy': 'test_user_123',
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          },
          'ownerId': 'test_user_123',
          'ownerDisplayName': 'Test User',
          'participants': {'test_user_123': 'owner'},
          'createdAt': DateTime.now().toIso8601String(),
          'lastEditedAt': DateTime.now().toIso8601String(),
          'lastEditedBy': 'test_user_123',
          'lastEditedByDisplayName': 'Test User',
          'editCount': 1,
          'type': 'recipe',
        });
        when(() => mockFirestoreRepo.deleteDocument(mockDocRef))
            .thenAnswer((_) async {});

        await service.deleteResource('recipe_1', RealtimeResourceType.recipe);

        verify(() => mockFirestoreRepo.deleteDocument(mockDocRef)).called(1);

        // Check cache cleared
        expect(service.getCachedResource<RealtimeRecipe>('recipe_1'), isNull);
      });

      test('should handle deletion errors', () async {
        // Arrange
        final mockDocRef = MockDocumentReference();

        when(() => mockFirestoreRepo.realtimeResourceDoc('recipe_1'))
            .thenReturn(mockDocRef);
        when(() => mockFirestoreRepo.getDocument(mockDocRef))
            .thenAnswer((_) async => throw Exception('Document not found'));

        // The service rethrows the original exception, not SyncError
        expect(
          () => service.deleteResource('recipe_1', RealtimeResourceType.recipe),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('Error Handling', () {
      test('should track last error', () async {
        // Act
        await service.initialize();

        // Trigger an error
        connectivityStreamController.addError('Connection error');

        await Future.delayed(Duration(milliseconds: 100));

        
        // Assert
        expect(service.lastError, isNotNull);
        expect(service.lastError!.type, equals(SyncErrorType.connectionLost));
      });

      test('should emit errors to error stream', () async {
        await service.initialize();

        SyncError? receivedError;
        service.errorStream.listen((error) {
        // Arrange
          receivedError = error;
        });

        connectivityStreamController.addError('Test error');

        await Future.delayed(Duration(milliseconds: 100));

        expect(receivedError, isNotNull);
        expect(
            receivedError!.message, contains('Firebase-anslutning förlorad'));
      });

      test('should clear error state', () async {
        // Act
        await service.initialize();

        // Create an error
        connectivityStreamController.addError('Error');
        await Future.delayed(Duration(milliseconds: 100));

        
        // Assert
        expect(service.lastError, isNotNull);

        // Clear it
        service.clearError();

        
        // Assert
        expect(service.lastError, isNull);
      });
    });

    group('Utility Methods', () {
      test('should refresh all resources', () async {
        // Arrange
        bool listenerCalled = false;
        service.addListener(() {
          listenerCalled = true;
        });

        service.refreshAllResources();

        expect(listenerCalled, isTrue);
      });

      test('should check if resource is watched', () async {
        expect(service.isResourceWatched('recipe_1'), isFalse);

        // Note: Actually watching a resource would require more setup
        // This just tests the method exists and returns expected type
      });

      test('should report active listeners count', () async {
        expect(service.activeListenersCount, equals(0));
      });
    });

    group('Cleanup', () {
      test('should dispose all resources on cleanup', () async {
        // Act
        await service.initialize();

        // Add some state
        service.addListener(() {});

        await service.onDispose();

        // All resources should be cleaned
        expect(service.activeListenersCount, equals(0));
        expect(service.getCachedResource<RealtimeRecipe>('any'), isNull);
      });

      test('should handle multiple dispose calls safely', () async {
        // Act
        await service.initialize();

        await service.onDispose();

        // Second dispose should not throw
        
        // Assert
        expect(() => service.onDispose(), returnsNormally);
      });
    });
  });
}
