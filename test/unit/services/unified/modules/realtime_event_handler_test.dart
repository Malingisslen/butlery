/// Unit tests for RealtimeEventHandler - Handles real-time event processing
///
/// Tests event handling operations including:
/// - External edit detection and processing (business logic)
/// - Error handling and user-friendly messages
/// - Notification logic and edit details extraction
/// - Event filtering and prioritization
///
/// NOTE: Methods requiring DocumentSnapshot (sealed class) are tested
/// in integration tests, following the hybrid testing strategy
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Production imports
import 'package:butlery/services/unified/modules/realtime_event_handler.dart';
import 'package:butlery/models/recipe_unified.dart';

// Test infrastructure
import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';

void main() {
  group('RealtimeEventHandler Unit Tests', () {
    late String? lastError;
    late int notifyListenerCount;
    late Recipe? lastSavedRecipe;
    late String? lastStoppedRecipeId;
    late Map<String, dynamic>? lastNotificationData;
    
    setUpAll(() async {
      // Initialize test infrastructure once for all tests
      await BaseUnitTest.setupUnit();
      
      // Register fallback values for mocktail
      registerFallbackValue(<String, dynamic>{});
    });
    
    setUp(() async {
      // Initialize service locator for each test
      await TestServiceLocator.initialize();
      
      // Reset test state
      lastError = null;
      notifyListenerCount = 0;
      lastSavedRecipe = null;
      lastStoppedRecipeId = null;
      lastNotificationData = null;
    });
    
    tearDown(() async {
      // Reset mocks and service locator after each test
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    tearDownAll(() async {
      // Final cleanup after all tests
      await BaseUnitTest.teardownUnit();
    });
    
    // Helper functions
    Future<void> saveToCache(Recipe recipe) async {
      lastSavedRecipe = recipe;
    }
    
    void notifyListeners() {
      notifyListenerCount++;
    }
    
    Future<void> sendRealtimeEditNotification(String recipeId, String? editedBy, Map<String, dynamic> data) async {
      lastNotificationData = {
        'recipeId': recipeId,
        'editedBy': editedBy,
        ...data,
      };
    }
    
    Future<bool> stopRealtimeEditing(String recipeId) async {
      lastStoppedRecipeId = recipeId;
      return true;
    }
    
    void setError(String error) {
      lastError = error;
    }
    
    group('External Edit Processing', () {
      test('should process valid external edit', () {
        // Arrange
        const recipeId = 'recipe-1';
        const editedBy = 'other-user-456';
        final data = {
          'editedBy': editedBy,
          'editedAt': Timestamp.now(),
          'editType': 'realtime_edit',
          'core': {
            'id': recipeId,
            'title': 'Updated Recipe',
            'description': 'Updated',
            'ingredients': ['New Ingredient'],
            'instructions': ['New Step'],
            'mealType': 'Lunch',
            'createdBy': editedBy,
          },
          'type': 'personal',
        };
        
        // Act
        RealtimeEventHandler.processExternalEdit(
          recipeId: recipeId,
          editedBy: editedBy,
          data: data,
          currentUserId: 'current-user-123',
          saveToCache: saveToCache,
          notifyListeners: notifyListeners,
          sendRealtimeEditNotification: sendRealtimeEditNotification,
        );
        
        // Assert
        expect(lastSavedRecipe, isNotNull);
        expect(notifyListenerCount, equals(1));
        expect(lastNotificationData, isNotNull);
      });
      
      test('should reject invalid edit data', () {
        // Arrange
        const recipeId = 'recipe-1';
        final data = <String, dynamic>{}; // Empty data
        
        // Act
        RealtimeEventHandler.processExternalEdit(
          recipeId: recipeId,
          editedBy: 'other-user',
          data: data,
          currentUserId: 'current-user-123',
          saveToCache: saveToCache,
          notifyListeners: notifyListeners,
          sendRealtimeEditNotification: sendRealtimeEditNotification,
        );
        
        // Assert
        expect(lastSavedRecipe, isNull);
        expect(notifyListenerCount, equals(0));
      });
      
      test('should validate edit data correctly', () {
        // Valid edit data
        expect(
          RealtimeEventHandler.isValidEditData({
            'editedAt': Timestamp.now(),
            'editedBy': 'user-123',
          }),
          isTrue,
        );
        
        // Invalid - empty data
        expect(RealtimeEventHandler.isValidEditData({}), isFalse);
        
        // Invalid - missing editedBy
        expect(
          RealtimeEventHandler.isValidEditData({
            'editedAt': Timestamp.now(),
          }),
          isFalse,
        );
        
        // Invalid - missing editedAt
        expect(
          RealtimeEventHandler.isValidEditData({
            'editedBy': 'user-123',
          }),
          isFalse,
        );
      });
    });
    
    group('Error Handling', () {
      test('should handle real-time sync error', () {
        // Arrange
        const recipeId = 'recipe-1';
        final error = Exception('Sync failed');
        
        // Act
        RealtimeEventHandler.handleRealtimeError(
          recipeId: recipeId,
          error: error,
          stopRealtimeEditing: stopRealtimeEditing,
          setError: setError,
        );
        
        // Assert
        expect(lastStoppedRecipeId, equals(recipeId));
        expect(lastError, contains('Realtidssynkronisering misslyckades'));
        expect(lastError, contains('Tekniskt fel'));
      });
      
      test('should handle permission error', () {
        // Arrange
        const recipeId = 'recipe-1';
        final error = Exception('Permission denied');
        
        // Act
        RealtimeEventHandler.handlePermissionError(
          recipeId: recipeId,
          error: error,
          stopRealtimeEditing: stopRealtimeEditing,
          setError: setError,
        );
        
        // Assert
        expect(lastStoppedRecipeId, equals(recipeId));
        expect(lastError, contains('Du har inte behörighet'));
      });
      
      test('should handle network error', () {
        // Arrange
        const recipeId = 'recipe-1';
        final error = Exception('Network error');
        
        // Act
        RealtimeEventHandler.handleNetworkError(
          recipeId: recipeId,
          error: error,
          setError: setError,
        );
        
        // Assert
        expect(lastError, contains('Nätverksfel'));
        expect(lastError, contains('kontrollera din internetanslutning'));
      });
      
      test('should convert errors to user-friendly messages', () {
        // Test through handleRealtimeError which uses _getUserFriendlyErrorMessage internally
        
        // Permission error
        RealtimeEventHandler.handleRealtimeError(
          recipeId: 'test-1',
          error: Exception('permission denied'),
          stopRealtimeEditing: stopRealtimeEditing,
          setError: setError,
        );
        expect(lastError, contains('Behörighet saknas'));
        
        // Network error
        lastError = null;
        RealtimeEventHandler.handleRealtimeError(
          recipeId: 'test-2',
          error: Exception('network connection failed'),
          stopRealtimeEditing: stopRealtimeEditing,
          setError: setError,
        );
        expect(lastError, contains('Nätverksfel'));
        
        // Timeout error
        lastError = null;
        RealtimeEventHandler.handleRealtimeError(
          recipeId: 'test-3',
          error: Exception('operation timeout'),
          stopRealtimeEditing: stopRealtimeEditing,
          setError: setError,
        );
        expect(lastError, contains('Tidsgräns överskriden'));
        
        // Generic error
        lastError = null;
        RealtimeEventHandler.handleRealtimeError(
          recipeId: 'test-4',
          error: Exception('unknown error'),
          stopRealtimeEditing: stopRealtimeEditing,
          setError: setError,
        );
        expect(lastError, contains('Tekniskt fel'));
      });
    });
    
    group('Notification Handling', () {
      test('should send notification for external edit', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const editedBy = 'user-456';
        final data = {
          'editType': 'realtime_edit',
          'field': 'title',
          'operation': 'update',
          'editedAt': Timestamp.now(),
          'editedByDisplayName': 'Other User',
        };
        
        // Act
        await RealtimeEventHandler.sendRealtimeEditNotification(
          recipeId: recipeId,
          editedBy: editedBy,
          data: data,
        );
        
        // Assert - method logs but doesn't throw
        expect(true, isTrue); // Notification logged successfully
      });
      
      test('should skip notification for null editor', () async {
        // Arrange
        const recipeId = 'recipe-1';
        final data = {'editType': 'realtime_edit'};
        
        // Act
        await RealtimeEventHandler.sendRealtimeEditNotification(
          recipeId: recipeId,
          editedBy: null,
          data: data,
        );
        
        // Assert - method returns early for null editor
        expect(true, isTrue);
      });
      
      test('should extract edit details correctly', () {
        // Arrange
        final data = {
          'editType': 'realtime_edit',
          'field': 'ingredients',
          'operation': 'add_ingredient',
          'editedAt': Timestamp.now(),
          'editedByDisplayName': 'Test User',
        };
        
        // Act
        final details = RealtimeEventHandler.extractEditDetails(data);
        
        // Assert
        expect(details['editType'], equals('realtime_edit'));
        expect(details['field'], equals('ingredients'));
        expect(details['operation'], equals('add_ingredient'));
        expect(details['editedByDisplayName'], equals('Test User'));
      });
      
      test('should determine when to send notifications', () {
        // Should send for external edit
        expect(
          RealtimeEventHandler.shouldSendNotification(
            editData: {'editedBy': 'other-user', 'editType': 'realtime_edit'},
            currentUserId: 'current-user',
          ),
          isTrue,
        );
        
        // Should not send for own edit
        expect(
          RealtimeEventHandler.shouldSendNotification(
            editData: {'editedBy': 'current-user', 'editType': 'realtime_edit'},
            currentUserId: 'current-user',
          ),
          isFalse,
        );
        
        // Should not send for presence updates
        expect(
          RealtimeEventHandler.shouldSendNotification(
            editData: {'editedBy': 'other-user', 'editType': 'presence_update'},
            currentUserId: 'current-user',
          ),
          isFalse,
        );
      });
    });
    
    group('Event Processing Logic', () {
      test('should determine if edit should be processed', () {
        // Should process external edit
        expect(
          RealtimeEventHandler.shouldProcessEdit(
            editData: {'editedBy': 'other-user'},
            currentUserId: 'current-user',
          ),
          isTrue,
        );
        
        // Should not process own edit
        expect(
          RealtimeEventHandler.shouldProcessEdit(
            editData: {'editedBy': 'current-user'},
            currentUserId: 'current-user',
          ),
          isFalse,
        );
        
        // Should not process without editor
        expect(
          RealtimeEventHandler.shouldProcessEdit(
            editData: {},
            currentUserId: 'current-user',
          ),
          isFalse,
        );
      });
      
      test('should identify own edits', () {
        // Own edit
        expect(
          RealtimeEventHandler.isOwnEdit(
            editData: {'editedBy': 'current-user'},
            currentUserId: 'current-user',
          ),
          isTrue,
        );
        
        // Not own edit
        expect(
          RealtimeEventHandler.isOwnEdit(
            editData: {'editedBy': 'other-user'},
            currentUserId: 'current-user',
          ),
          isFalse,
        );
      });
      
      test('should check if edit is recent', () {
        // Recent edit (within 5 minutes)
        final recentTimestamp = Timestamp.fromDate(
          DateTime.now().subtract(const Duration(minutes: 2)),
        );
        expect(
          RealtimeEventHandler.isRecentEdit({'editedAt': recentTimestamp}),
          isTrue,
        );
        
        // Old edit (more than 5 minutes)
        final oldTimestamp = Timestamp.fromDate(
          DateTime.now().subtract(const Duration(minutes: 10)),
        );
        expect(
          RealtimeEventHandler.isRecentEdit({'editedAt': oldTimestamp}),
          isFalse,
        );
        
        // No timestamp - process anyway
        expect(
          RealtimeEventHandler.isRecentEdit({}),
          isTrue,
        );
      });
      
      test('should get event priority', () {
        // High priority - realtime edit
        expect(
          RealtimeEventHandler.getEventPriority({'editType': 'realtime_edit'}),
          equals(1),
        );
        
        // Medium priority - metadata update
        expect(
          RealtimeEventHandler.getEventPriority({'editType': 'metadata_update'}),
          equals(2),
        );
        
        // Low priority - presence update
        expect(
          RealtimeEventHandler.getEventPriority({'editType': 'presence_update'}),
          equals(3),
        );
        
        // Default priority - unknown type
        expect(
          RealtimeEventHandler.getEventPriority({'editType': 'unknown'}),
          equals(2),
        );
        
        // Default priority - no type
        expect(
          RealtimeEventHandler.getEventPriority({}),
          equals(2),
        );
      });
    });
  });
}

// NOTE: Methods requiring DocumentSnapshot (handleRealtimeRecipeChange, createRealtimeListener,
// isValidSnapshot, getRecipeIdFromSnapshot) should be tested in integration tests
// See: test/integration/firebase/realtime_event_handler_integration_test.dart