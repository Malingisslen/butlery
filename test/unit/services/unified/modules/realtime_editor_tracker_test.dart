/// Unit tests for RealtimeEditorTracker - Handles real-time editor tracking
///
/// Tests editor tracking operations including:
/// - Editor registration and presence tracking
/// - Active editor queries and status
/// - Editor presence heartbeat management
/// - Collaborative editing indicators
/// - Statistics and cleanup
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';

// Production imports
import 'package:butlery/services/unified/modules/realtime_editor_tracker.dart';
import 'package:butlery/repositories/collaborative_recipe_repository.dart';

// Test infrastructure
import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('RealtimeEditorTracker', () {
    late MockCollaborativeRecipeRepository mockCollaborativeRepo;
    late GetIt getIt;
    
    setUpAll(() async {
      // Initialize test infrastructure once for all tests
      await BaseUnitTest.setupUnit();
    });
    
    setUp(() async {
      // Initialize service locator for each test
      await TestServiceLocator.initialize();
      
      // Create mock
      mockCollaborativeRepo = MockCollaborativeRecipeRepository();
      
      // Register mock with GetIt
      getIt = GetIt.instance;
      if (getIt.isRegistered<CollaborativeRecipeRepository>()) {
        getIt.unregister<CollaborativeRecipeRepository>();
      }
      getIt.registerSingleton<CollaborativeRecipeRepository>(mockCollaborativeRepo);
    });
    
    tearDown(() async {
      // Reset mocks and service locator after each test
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
      
      // Clear GetIt registrations
      if (getIt.isRegistered<CollaborativeRecipeRepository>()) {
        getIt.unregister<CollaborativeRecipeRepository>();
      }
    });
    
    tearDownAll(() async {
      // Final cleanup after all tests
      await BaseUnitTest.teardownUnit();
    });
    
    group('Editor Registration', () {
      test('should register active editor', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const currentUserId = 'user-123';
        const currentUserDisplayName = 'Test User';
        
        when(() => mockCollaborativeRepo.setPresence(
          any(), 
          any(), 
          any(),
        )).thenAnswer((_) async {});
        
        // Act
        await RealtimeEditorTracker.registerActiveEditor(
          recipeId: recipeId,
          isActive: true,
          currentUserId: currentUserId,
          currentUserDisplayName: currentUserDisplayName,
        );
        
        // Assert
        verify(() => mockCollaborativeRepo.setPresence(
          recipeId,
          currentUserId,
          any(that: allOf(
            containsPair('displayName', currentUserDisplayName),
            containsPair('isActive', true),
            contains('lastSeen'),
          )),
        )).called(1);
      });
      
      test('should unregister active editor', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const currentUserId = 'user-123';
        
        when(() => mockCollaborativeRepo.removePresence(any(), any()))
            .thenAnswer((_) async {});
        
        // Act
        await RealtimeEditorTracker.registerActiveEditor(
          recipeId: recipeId,
          isActive: false,
          currentUserId: currentUserId,
          currentUserDisplayName: null,
        );
        
        // Assert
        verify(() => mockCollaborativeRepo.removePresence(recipeId, currentUserId))
            .called(1);
      });
      
      test('should handle registration with null display name', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const currentUserId = 'user-123';
        
        when(() => mockCollaborativeRepo.setPresence(
          any(), 
          any(), 
          any(),
        )).thenAnswer((_) async {});
        
        // Act
        await RealtimeEditorTracker.registerActiveEditor(
          recipeId: recipeId,
          isActive: true,
          currentUserId: currentUserId,
          currentUserDisplayName: null,
        );
        
        // Assert
        verify(() => mockCollaborativeRepo.setPresence(
          recipeId,
          currentUserId,
          any(that: containsPair('displayName', 'Okänd användare')),
        )).called(1);
      });
      
      test('should handle registration errors', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const currentUserId = 'user-123';
        
        when(() => mockCollaborativeRepo.setPresence(any(), any(), any()))
            .thenThrow(Exception('Registration failed'));
        
        // Act & Assert
        await expectLater(
          RealtimeEditorTracker.registerActiveEditor(
            recipeId: recipeId,
            isActive: true,
            currentUserId: currentUserId,
            currentUserDisplayName: null,
          ),
          throwsException,
        );
      });
    });
    
    group('Presence Updates', () {
      test('should update active editor presence', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const currentUserId = 'user-123';
        
        when(() => mockCollaborativeRepo.updatePresenceHeartbeat(any(), any()))
            .thenAnswer((_) async {});
        
        // Act
        await RealtimeEditorTracker.updateActiveEditorPresence(
          recipeId: recipeId,
          currentUserId: currentUserId,
        );
        
        // Assert
        verify(() => mockCollaborativeRepo.updatePresenceHeartbeat(
          recipeId,
          currentUserId,
        )).called(1);
      });
      
      test('should handle presence update errors silently', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const currentUserId = 'user-123';
        
        when(() => mockCollaborativeRepo.updatePresenceHeartbeat(any(), any()))
            .thenThrow(Exception('Update failed'));
        
        // Act & Assert - Should not throw
        await expectLater(
          RealtimeEditorTracker.updateActiveEditorPresence(
            recipeId: recipeId,
            currentUserId: currentUserId,
          ),
          completes,
        );
      });
      
      test('should update presence for multiple recipes', () async {
        // Arrange
        final recipeIds = ['recipe-1', 'recipe-2', 'recipe-3'];
        const currentUserId = 'user-123';
        
        when(() => mockCollaborativeRepo.updatePresenceHeartbeat(any(), any()))
            .thenAnswer((_) async {});
        
        // Act
        await RealtimeEditorTracker.updatePresenceForMultipleRecipes(
          recipeIds: recipeIds,
          currentUserId: currentUserId,
        );
        
        // Assert
        for (final recipeId in recipeIds) {
          verify(() => mockCollaborativeRepo.updatePresenceHeartbeat(
            recipeId,
            currentUserId,
          )).called(1);
        }
      });
      
      test('should handle batch presence update errors', () async {
        // Arrange
        final recipeIds = ['recipe-1', 'recipe-2'];
        const currentUserId = 'user-123';
        
        when(() => mockCollaborativeRepo.updatePresenceHeartbeat(any(), any()))
            .thenThrow(Exception('Batch update failed'));
        
        // Act & Assert - Should not throw
        await expectLater(
          RealtimeEditorTracker.updatePresenceForMultipleRecipes(
            recipeIds: recipeIds,
            currentUserId: currentUserId,
          ),
          completes,
        );
      });
    });
    
    group('Editor Queries', () {
      test('should get active editors for recipe', () async {
        // Arrange
        const recipeId = 'recipe-1';
        final mockEditors = [
          {'userId': 'user-1', 'displayName': 'User 1', 'isActive': true},
          {'userId': 'user-2', 'displayName': 'User 2', 'isActive': true},
        ];
        
        when(() => mockCollaborativeRepo.getActiveEditors(any()))
            .thenAnswer((_) async => mockEditors);
        
        // Act
        final result = await RealtimeEditorTracker.getActiveEditors(
          recipeId: recipeId,
        );
        
        // Assert
        expect(result, equals(mockEditors));
        verify(() => mockCollaborativeRepo.getActiveEditors(recipeId)).called(1);
      });
      
      test('should return empty list on error', () async {
        // Arrange
        const recipeId = 'recipe-1';
        
        when(() => mockCollaborativeRepo.getActiveEditors(any()))
            .thenThrow(Exception('Query failed'));
        
        // Act
        final result = await RealtimeEditorTracker.getActiveEditors(
          recipeId: recipeId,
        );
        
        // Assert
        expect(result, isEmpty);
      });
      
      test('should get currently active editors', () async {
        // Arrange
        const recipeId = 'recipe-1';
        final mockEditors = [
          {'userId': 'user-1', 'isCurrentlyActive': true},
          {'userId': 'user-2', 'isCurrentlyActive': false},
          {'userId': 'user-3', 'isCurrentlyActive': true},
        ];
        
        when(() => mockCollaborativeRepo.getActiveEditors(any()))
            .thenAnswer((_) async => mockEditors);
        
        // Act
        final result = await RealtimeEditorTracker.getCurrentlyActiveEditors(
          recipeId: recipeId,
        );
        
        // Assert
        expect(result.length, equals(2));
        expect(result.every((e) => e['isCurrentlyActive'] == true), isTrue);
      });
      
      test('should get active editor count', () async {
        // Arrange
        const recipeId = 'recipe-1';
        final mockEditors = [
          {'userId': 'user-1', 'isCurrentlyActive': true},
          {'userId': 'user-2', 'isCurrentlyActive': true},
          {'userId': 'user-3', 'isCurrentlyActive': false},
        ];
        
        when(() => mockCollaborativeRepo.getActiveEditors(any()))
            .thenAnswer((_) async => mockEditors);
        
        // Act
        final count = await RealtimeEditorTracker.getActiveEditorCount(
          recipeId: recipeId,
        );
        
        // Assert
        expect(count, equals(2)); // Only currently active ones
      });
      
      test('should check if user is actively editing', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const userId = 'user-123';
        
        when(() => mockCollaborativeRepo.isUserActivelyEditing(any(), any()))
            .thenAnswer((_) async => true);
        
        // Act
        final result = await RealtimeEditorTracker.isUserActivelyEditing(
          recipeId: recipeId,
          userId: userId,
        );
        
        // Assert
        expect(result, isTrue);
        verify(() => mockCollaborativeRepo.isUserActivelyEditing(
          recipeId,
          userId,
        )).called(1);
      });
      
      test('should return false when checking active editing fails', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const userId = 'user-123';
        
        when(() => mockCollaborativeRepo.isUserActivelyEditing(any(), any()))
            .thenThrow(Exception('Check failed'));
        
        // Act
        final result = await RealtimeEditorTracker.isUserActivelyEditing(
          recipeId: recipeId,
          userId: userId,
        );
        
        // Assert
        expect(result, isFalse);
      });
    });
    
    group('Statistics and Activity', () {
      test('should get editor statistics', () async {
        // Arrange
        const recipeId = 'recipe-1';
        final mockEditors = [
          {'userId': 'user-1', 'isCurrentlyActive': true},
          {'userId': 'user-2', 'isCurrentlyActive': true},
        ];
        
        when(() => mockCollaborativeRepo.getActiveEditors(any()))
            .thenAnswer((_) async => mockEditors);
        
        // Act
        final stats = await RealtimeEditorTracker.getEditorStatistics(
          recipeId: recipeId,
        );
        
        // Assert
        expect(stats['activeEditorCount'], equals(2));
        expect(stats['hasActiveEditors'], isTrue);
        expect(stats.containsKey('lastUpdated'), isTrue);
      });
      
      test('should return default statistics on error', () async {
        // Arrange
        const recipeId = 'recipe-1';
        
        when(() => mockCollaborativeRepo.getActiveEditors(any()))
            .thenThrow(Exception('Stats failed'));
        
        // Act
        final stats = await RealtimeEditorTracker.getEditorStatistics(
          recipeId: recipeId,
        );
        
        // Assert
        expect(stats['activeEditorCount'], equals(0));
        expect(stats['hasActiveEditors'], isFalse);
      });
      
      test('should check for collaborative activity', () async {
        // Arrange
        const recipeId = 'recipe-1';
        final mockEditors = [
          {'userId': 'user-1', 'isCurrentlyActive': true},
          {'userId': 'user-2', 'isCurrentlyActive': true},
        ];
        
        when(() => mockCollaborativeRepo.getActiveEditors(any()))
            .thenAnswer((_) async => mockEditors);
        
        // Act
        final hasActivity = await RealtimeEditorTracker.hasCollaborativeActivity(
          recipeId: recipeId,
        );
        
        // Assert
        expect(hasActivity, isTrue); // More than 1 editor
      });
      
      test('should detect no collaborative activity with single editor', () async {
        // Arrange
        const recipeId = 'recipe-1';
        final mockEditors = [
          {'userId': 'user-1', 'isCurrentlyActive': true},
        ];
        
        when(() => mockCollaborativeRepo.getActiveEditors(any()))
            .thenAnswer((_) async => mockEditors);
        
        // Act
        final hasActivity = await RealtimeEditorTracker.hasCollaborativeActivity(
          recipeId: recipeId,
        );
        
        // Assert
        expect(hasActivity, isFalse); // Only 1 editor
      });
      
      test('should return false for collaborative activity on error', () async {
        // Arrange
        const recipeId = 'recipe-1';
        
        when(() => mockCollaborativeRepo.getActiveEditors(any()))
            .thenThrow(Exception('Activity check failed'));
        
        // Act
        final hasActivity = await RealtimeEditorTracker.hasCollaborativeActivity(
          recipeId: recipeId,
        );
        
        // Assert
        expect(hasActivity, isFalse);
      });
    });
    
    group('Cleanup Operations', () {
      test('should cleanup inactive editors', () async {
        // Arrange
        const recipeId = 'recipe-1';
        
        when(() => mockCollaborativeRepo.cleanupInactiveEditors(any()))
            .thenAnswer((_) async {});
        
        // Act
        await RealtimeEditorTracker.cleanupInactiveEditors(
          recipeId: recipeId,
        );
        
        // Assert
        verify(() => mockCollaborativeRepo.cleanupInactiveEditors(recipeId))
            .called(1);
      });
      
      test('should handle cleanup errors', () async {
        // Arrange
        const recipeId = 'recipe-1';
        
        when(() => mockCollaborativeRepo.cleanupInactiveEditors(any()))
            .thenThrow(Exception('Cleanup failed'));
        
        // Act & Assert - Should not throw
        await expectLater(
          RealtimeEditorTracker.cleanupInactiveEditors(
            recipeId: recipeId,
          ),
          completes,
        );
      });
    });
  });
}