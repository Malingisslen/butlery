/// Unit tests for RealtimeSessionManager - Handles real-time session management
///
/// Tests session management operations including:
/// - Session lifecycle (start, stop, stop all)
/// - Session state tracking and validation
/// - Session health monitoring and cleanup
/// - Session diagnostics and recovery
///
/// NOTE: Methods requiring DocumentSnapshot (sealed class) are tested
/// in integration tests, following the hybrid testing strategy
library;

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Production imports
import 'package:butlery/services/unified/modules/realtime_session_manager.dart';

// Test infrastructure
import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';

// ULTRATHINK CONVERSION COMPLETE: Local mock classes removed - using centralized mocks

void main() {
  group('RealtimeSessionManager', () {
    late Map<String, StreamSubscription<DocumentSnapshot>> activeEditingSessions;
    late Map<String, List<Map<String, dynamic>>> pendingRealtimeEdits;
    late Map<String, Timer> conflictResolutionTimers;
    late String? lastError;
    late int registerEditorCallCount;
    late Map<String, bool> registeredEditors;
    
    // Helper function to create mock subscription using centralized infrastructure
    StreamSubscription<DocumentSnapshot> createMockSubscription({bool isPaused = false}) {
      final mockSub = MockStreamSubscription<DocumentSnapshot>();
      when(() => mockSub.isPaused).thenReturn(isPaused);
      when(() => mockSub.cancel()).thenAnswer((_) async {});
      return mockSub;
    }
    
    // Helper function to create mock timer using centralized infrastructure
    Timer createMockTimer({bool isActive = false}) {
      final mockTimer = MockTimer();
      when(() => mockTimer.isActive).thenReturn(isActive);
      when(() => mockTimer.cancel()).thenAnswer((_) {});
      return mockTimer;
    }
    
    setUpAll(() {
      // Centralized fallback values already registered via TestServiceLocator
    });
    
    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      
      // Initialize test state
      activeEditingSessions = {};
      pendingRealtimeEdits = {};
      conflictResolutionTimers = {};
      lastError = null;
      registerEditorCallCount = 0;
      registeredEditors = {};
    });
    
    tearDown(() async {
      // Reset mocks and service locator after each test
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
      
      // Cancel any remaining subscriptions
      for (final sub in activeEditingSessions.values) {
        await sub.cancel();
      }
      activeEditingSessions.clear();
      
      // Cancel any remaining timers
      for (final timer in conflictResolutionTimers.values) {
        timer.cancel();
      }
      conflictResolutionTimers.clear();
    });
    
    tearDownAll(() async {
      // Final cleanup after all tests
      await BaseUnitTest.teardownUnit();
    });
    
    // Helper functions for callbacks
    Future<void> registerActiveEditor(String recipeId, bool isActive) async {
      registerEditorCallCount++;
      registeredEditors[recipeId] = isActive;
    }
    
    void setError(String error) {
      lastError = error;
    }
    
    group('Session Lifecycle', () {
      test('should check if session can be started', () {
        // Arrange
        const recipeId = 'recipe-1';
        const currentUserId = 'user-123';
        
        // Act
        final canStart = RealtimeSessionManager.canStartRealtimeEditing(
          currentUserId: currentUserId,
          recipeId: recipeId,
          activeEditingSessions: activeEditingSessions,
        );
        
        // Assert
        expect(canStart, isTrue);
      });
      
      test('should not allow starting session without user', () {
        // Arrange
        const recipeId = 'recipe-1';
        
        // Act
        final canStart = RealtimeSessionManager.canStartRealtimeEditing(
          currentUserId: null,
          recipeId: recipeId,
          activeEditingSessions: activeEditingSessions,
        );
        
        // Assert
        expect(canStart, isFalse);
      });
      
      test('should allow existing session (already editing)', () {
        // Arrange
        const recipeId = 'recipe-1';
        const currentUserId = 'user-123';
        activeEditingSessions[recipeId] = createMockSubscription();
        
        // Act
        final canStart = RealtimeSessionManager.canStartRealtimeEditing(
          currentUserId: currentUserId,
          recipeId: recipeId,
          activeEditingSessions: activeEditingSessions,
        );
        
        // Assert
        expect(canStart, isTrue); // Already editing is valid
      });
      
      test('should stop real-time editing session', () async {
        // Arrange
        const recipeId = 'recipe-1';
        final mockSubscription = createMockSubscription();
        activeEditingSessions[recipeId] = mockSubscription;
        pendingRealtimeEdits[recipeId] = [{'edit': 'test'}];
        conflictResolutionTimers[recipeId] = createMockTimer();
        
        // Act
        final result = await RealtimeSessionManager.stopRealtimeEditing(
          recipeId: recipeId,
          activeEditingSessions: activeEditingSessions,
          pendingRealtimeEdits: pendingRealtimeEdits,
          conflictResolutionTimers: conflictResolutionTimers,
          registerActiveEditor: registerActiveEditor,
        );
        
        // Assert
        expect(result, isTrue);
        expect(activeEditingSessions.containsKey(recipeId), isFalse);
        expect(pendingRealtimeEdits.containsKey(recipeId), isFalse);
        expect(conflictResolutionTimers.containsKey(recipeId), isFalse);
        expect(registeredEditors[recipeId], isFalse);
        verify(() => mockSubscription.cancel()).called(1);
      });
      
      test('should handle stop session with no active subscription', () async {
        // Arrange
        const recipeId = 'recipe-1';
        
        // Act
        final result = await RealtimeSessionManager.stopRealtimeEditing(
          recipeId: recipeId,
          activeEditingSessions: activeEditingSessions,
          pendingRealtimeEdits: pendingRealtimeEdits,
          conflictResolutionTimers: conflictResolutionTimers,
          registerActiveEditor: registerActiveEditor,
        );
        
        // Assert
        expect(result, isTrue);
        expect(registeredEditors[recipeId], isFalse);
      });
      
      test('should stop all real-time sessions', () async {
        // Arrange
        final mockSub1 = createMockSubscription();
        final mockSub2 = createMockSubscription();
        activeEditingSessions['recipe-1'] = mockSub1;
        activeEditingSessions['recipe-2'] = mockSub2;
        pendingRealtimeEdits['recipe-1'] = [{'edit': '1'}];
        pendingRealtimeEdits['recipe-2'] = [{'edit': '2'}];
        
        // Act
        await RealtimeSessionManager.stopAllRealtimeSessions(
          activeEditingSessions: activeEditingSessions,
          pendingRealtimeEdits: pendingRealtimeEdits,
          conflictResolutionTimers: conflictResolutionTimers,
          registerActiveEditor: registerActiveEditor,
        );
        
        // Assert
        expect(activeEditingSessions.isEmpty, isTrue);
        expect(pendingRealtimeEdits.isEmpty, isTrue);
        expect(registerEditorCallCount, equals(2));
        verify(() => mockSub1.cancel()).called(1);
        verify(() => mockSub2.cancel()).called(1);
      });
      
      test('should handle error when stopping session', () async {
        // Arrange
        const recipeId = 'recipe-1';
        final mockSubscription = createMockSubscription();
        when(() => mockSubscription.cancel()).thenThrow(Exception('Cancel failed'));
        activeEditingSessions[recipeId] = mockSubscription;
        
        // Act
        final result = await RealtimeSessionManager.stopRealtimeEditing(
          recipeId: recipeId,
          activeEditingSessions: activeEditingSessions,
          pendingRealtimeEdits: pendingRealtimeEdits,
          conflictResolutionTimers: conflictResolutionTimers,
          registerActiveEditor: registerActiveEditor,
        );
        
        // Assert
        expect(result, isFalse);
      });
    });
    
    group('Session State Queries', () {
      test('should check if in real-time editing session', () {
        // Arrange
        const recipeId = 'recipe-1';
        activeEditingSessions[recipeId] = createMockSubscription();
        
        // Act
        final inSession = RealtimeSessionManager.isInRealtimeEditingSession(
          recipeId: recipeId,
          activeEditingSessions: activeEditingSessions,
        );
        
        // Assert
        expect(inSession, isTrue);
      });
      
      test('should return false when not in session', () {
        // Arrange
        const recipeId = 'recipe-1';
        
        // Act
        final inSession = RealtimeSessionManager.isInRealtimeEditingSession(
          recipeId: recipeId,
          activeEditingSessions: activeEditingSessions,
        );
        
        // Assert
        expect(inSession, isFalse);
      });
      
      test('should get all active editing sessions', () {
        // Arrange
        activeEditingSessions['recipe-1'] = createMockSubscription();
        activeEditingSessions['recipe-2'] = createMockSubscription();
        activeEditingSessions['recipe-3'] = createMockSubscription();
        
        // Act
        final sessions = RealtimeSessionManager.getActiveEditingSessions(
          activeEditingSessions,
        );
        
        // Assert
        expect(sessions.length, equals(3));
        expect(sessions, contains('recipe-1'));
        expect(sessions, contains('recipe-2'));
        expect(sessions, contains('recipe-3'));
      });
      
      test('should get active session count', () {
        // Arrange
        activeEditingSessions['recipe-1'] = createMockSubscription();
        activeEditingSessions['recipe-2'] = createMockSubscription();
        
        // Act
        final count = RealtimeSessionManager.getActiveSessionCount(
          activeEditingSessions,
        );
        
        // Assert
        expect(count, equals(2));
      });
      
      test('should check if has active sessions', () {
        // No sessions
        expect(
          RealtimeSessionManager.hasActiveSessions(activeEditingSessions),
          isFalse,
        );
        
        // With sessions
        activeEditingSessions['recipe-1'] = createMockSubscription();
        expect(
          RealtimeSessionManager.hasActiveSessions(activeEditingSessions),
          isTrue,
        );
      });
    });
    
    group('Session Validation', () {
      test('should validate session for operation', () {
        // Arrange
        const recipeId = 'recipe-1';
        const currentUserId = 'user-123';
        activeEditingSessions[recipeId] = createMockSubscription();
        
        // Act
        final isValid = RealtimeSessionManager.validateSessionForOperation(
          recipeId: recipeId,
          currentUserId: currentUserId,
          activeEditingSessions: activeEditingSessions,
          setError: setError,
        );
        
        // Assert
        expect(isValid, isTrue);
        expect(lastError, isNull);
      });
      
      test('should fail validation without user', () {
        // Arrange
        const recipeId = 'recipe-1';
        
        // Act
        final isValid = RealtimeSessionManager.validateSessionForOperation(
          recipeId: recipeId,
          currentUserId: null,
          activeEditingSessions: activeEditingSessions,
          setError: setError,
        );
        
        // Assert
        expect(isValid, isFalse);
        expect(lastError, contains('Du måste vara inloggad'));
      });
      
      test('should fail validation without active session', () {
        // Arrange
        const recipeId = 'recipe-1';
        const currentUserId = 'user-123';
        
        // Act
        final isValid = RealtimeSessionManager.validateSessionForOperation(
          recipeId: recipeId,
          currentUserId: currentUserId,
          activeEditingSessions: activeEditingSessions,
          setError: setError,
        );
        
        // Assert
        expect(isValid, isFalse);
        expect(lastError, contains('Inte i realtidsredigeringsläge'));
      });
    });
    
    group('Session Health Monitoring', () {
      test('should check session health', () {
        // Arrange
        activeEditingSessions['recipe-1'] = createMockSubscription(isPaused: false);
        activeEditingSessions['recipe-2'] = createMockSubscription(isPaused: true);
        activeEditingSessions['recipe-3'] = createMockSubscription(isPaused: false);
        
        // Act
        final health = RealtimeSessionManager.checkSessionHealth(
          activeEditingSessions,
        );
        
        // Assert
        expect(health['total_sessions'], equals(3));
        expect(health['healthy_sessions'], equals(2));
        expect(health['problematic_sessions'], hasLength(1));
        expect(health['problematic_sessions'], contains('recipe-2 (paused)'));
      });
      
      test('should handle health check errors', () {
        // Arrange
        final badSubscription = MockStreamSubscription<DocumentSnapshot>();
        when(() => badSubscription.isPaused).thenThrow(Exception('Bad state'));
        when(() => badSubscription.cancel()).thenAnswer((_) async {});
        activeEditingSessions['recipe-1'] = badSubscription;
        
        // Act
        final health = RealtimeSessionManager.checkSessionHealth(
          activeEditingSessions,
        );
        
        // Assert
        expect(health['total_sessions'], equals(1));
        expect(health['healthy_sessions'], equals(0));
        expect(health['problematic_sessions'], hasLength(1));
      });
      
      test('should cleanup orphaned sessions', () async {
        // Arrange
        final pausedSub = createMockSubscription(isPaused: true);
        final healthySub = createMockSubscription(isPaused: false);
        activeEditingSessions['recipe-1'] = pausedSub;
        activeEditingSessions['recipe-2'] = healthySub;
        
        // Act
        await RealtimeSessionManager.cleanupOrphanedSessions(
          activeEditingSessions: activeEditingSessions,
          pendingRealtimeEdits: pendingRealtimeEdits,
          conflictResolutionTimers: conflictResolutionTimers,
          registerActiveEditor: registerActiveEditor,
        );
        
        // Assert
        expect(activeEditingSessions.containsKey('recipe-1'), isFalse);
        expect(activeEditingSessions.containsKey('recipe-2'), isTrue);
        verify(() => pausedSub.cancel()).called(1);
        verifyNever(() => healthySub.cancel());
      });
    });
    
    group('Session Diagnostics', () {
      test('should get session diagnostics', () {
        // Arrange
        activeEditingSessions['recipe-1'] = createMockSubscription();
        activeEditingSessions['recipe-2'] = createMockSubscription();
        pendingRealtimeEdits['recipe-1'] = [{'edit': '1'}, {'edit': '2'}];
        conflictResolutionTimers['recipe-1'] = createMockTimer(isActive: true);
        conflictResolutionTimers['recipe-2'] = createMockTimer(isActive: false);
        
        // Act
        final diagnostics = RealtimeSessionManager.getSessionDiagnostics(
          activeEditingSessions: activeEditingSessions,
          pendingRealtimeEdits: pendingRealtimeEdits,
          conflictResolutionTimers: conflictResolutionTimers,
        );
        
        // Assert
        expect(diagnostics['active_sessions_count'], equals(2));
        expect(diagnostics['total_pending_edits'], equals(2));
        expect(diagnostics['active_conflict_timers'], equals(1));
        
        final recipe1Details = diagnostics['session_details']['recipe-1'];
        expect(recipe1Details['has_subscription'], isTrue);
        expect(recipe1Details['pending_edits_count'], equals(2));
        expect(recipe1Details['has_conflict_timer'], isTrue);
        expect(recipe1Details['conflict_timer_active'], isTrue);
      });
      
      test('should get session status summary', () {
        // Arrange
        activeEditingSessions['recipe-1'] = createMockSubscription();
        activeEditingSessions['recipe-2'] = createMockSubscription();
        pendingRealtimeEdits['recipe-1'] = [{'edit': '1'}];
        conflictResolutionTimers['recipe-1'] = createMockTimer();
        
        // Act
        final status = RealtimeSessionManager.getSessionStatus(
          activeEditingSessions: activeEditingSessions,
          pendingRealtimeEdits: pendingRealtimeEdits,
          conflictResolutionTimers: conflictResolutionTimers,
        );
        
        // Assert
        expect(status['activeEditingSessions'], equals(2));
        expect(status['pendingEdits'], equals(1));
        expect(status['conflictTimers'], equals(1));
        expect(status['recipeIds'], contains('recipe-1'));
        expect(status['recipeIds'], contains('recipe-2'));
      });
    });
    
    group('Session Recovery', () {
      test('should check if session needs recovery', () {
        // Scenario 1: Has pending edits but no subscription (needs recovery)
        pendingRealtimeEdits['recipe-1'] = [{'edit': 'test'}];
        expect(
          RealtimeSessionManager.needsSessionRecovery(
            recipeId: 'recipe-1',
            activeEditingSessions: activeEditingSessions,
            pendingRealtimeEdits: pendingRealtimeEdits,
          ),
          isTrue,
        );
        
        // Scenario 2: Has subscription and pending edits (no recovery needed)
        activeEditingSessions['recipe-2'] = createMockSubscription();
        pendingRealtimeEdits['recipe-2'] = [{'edit': 'test'}];
        expect(
          RealtimeSessionManager.needsSessionRecovery(
            recipeId: 'recipe-2',
            activeEditingSessions: activeEditingSessions,
            pendingRealtimeEdits: pendingRealtimeEdits,
          ),
          isFalse,
        );
        
        // Scenario 3: No pending edits (no recovery needed)
        expect(
          RealtimeSessionManager.needsSessionRecovery(
            recipeId: 'recipe-3',
            activeEditingSessions: activeEditingSessions,
            pendingRealtimeEdits: pendingRealtimeEdits,
          ),
          isFalse,
        );
      });
    });
  });
}

// NOTE: Methods requiring DocumentSnapshot and FirebaseFirestore (startRealtimeEditing, 
// recoverSession) should be tested in integration tests
// See: test/integration/firebase/realtime_session_manager_integration_test.dart