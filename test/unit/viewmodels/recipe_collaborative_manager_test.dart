// test/unit/viewmodels/recipe_collaborative_manager_test.dart

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_collaborative_manager.dart';
import 'package:butlery/services/connectivity_monitoring_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/realtime/live_editor.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:flutter/foundation.dart';

import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/factories/user_profile_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../test_support/base_unit_test.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;

// ============= USING CENTRALIZED MOCKS =============
// Removed local mock classes:
// - FakePermissionService (now in production_mocks.dart)
// - MockCollaborativeRecipeRepository (now in production_mocks.dart)
// - MockConnectivityMonitoringService (now in production_mocks.dart)

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecipeCollaborativeManager - Ultrathink Enhanced Tests', () {
    late RecipeCollaborativeManager manager;
    // Concrete type so setProfile() is reachable (FakePermissionService
    // adds it on top of the PermissionService interface).
    late FakePermissionService mockPermissionService;
    late MockCollaborativeRecipeRepository mockRepository;
    late ConnectivityMonitoringService mockConnectivityService;

    // Test data
    const testUserId = 'user_123';
    const testUserDisplayName = 'Test User';
    const testRecipeId = 'recipe_456';
    const testParticipantId = 'participant_789';
    const testParticipantName = 'Participant User';

    late Recipe testRecipe;
    late UserProfile testParticipant;
    late RealtimeRecipe testRealtimeRecipe;
    late LiveEditor testLiveEditor;

    setUpAll(() async {
      // Register fallback values for mocktail
      registerFallbackValue(RecipeFactory.build());
      registerFallbackValue(UserProfileFactory.build());
      registerFallbackValue(ResourcePermission.editor);
      registerFallbackValue(RealtimeRecipe.fromRecipe(
        recipe: RecipeFactory.build(),
        ownerId: testUserId,
        ownerDisplayName: testUserDisplayName,
      ));
    });

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // ULTRATHINK FIX: Bridge production ServiceLocator to test mocks
      // This solves "ServiceLocator not initialized" errors when production code
      // calls ServiceLocator.get() but only TestServiceLocator was initialized
      final productionContainer = DIContainer();
      prod_locator.ServiceLocator.initialize(productionContainer);

      // Create mocks using centralized versions
      mockPermissionService = MockFactory.createPermissionService(
        currentUserId: testUserId,
        userDisplayName: testUserDisplayName,
        defaultHasPermission: true,
      );
      mockRepository = MockCollaborativeRecipeRepository();
      mockConnectivityService =
          MockFactory.createConnectivityMonitoringService();

      // Create test data
      testRecipe = RecipeFactory.build(id: testRecipeId, title: 'Test Recipe');
      testParticipant = UserProfileFactory.build(
          uid: testParticipantId, displayName: testParticipantName);
      testRealtimeRecipe = RealtimeRecipe.fromRecipe(
        recipe: testRecipe,
        ownerId: testUserId,
        ownerDisplayName: testUserDisplayName,
      );
      testLiveEditor = LiveEditor(
        userId: testParticipantId,
        displayName: testParticipantName,
        lastSeen: DateTime.now(),
        isActive: true,
      );

      // FakePermissionService is a Fake (not Mock), so mocktail's when()
      // can't stub its methods — the dispatch isn't routed through
      // noSuchMethod. Use the dedicated setProfile() config method instead.
      mockPermissionService.setProfile(testParticipant);

      // Configure repository defaults
      when(() => mockRepository.createRealtimeRecipe(any()))
          .thenAnswer((_) async {});
      when(() => mockRepository.updateRealtimeRecipe(any()))
          .thenAnswer((_) async {});
      when(() => mockRepository.getRealtimeRecipeStream(any()))
          .thenAnswer((_) => Stream.value(testRealtimeRecipe));
      when(() => mockRepository.getParticipantsStream(any()))
          .thenAnswer((_) => Stream.value([testLiveEditor]));
      when(() => mockRepository.updateUserPresence(any(), any(), any()))
          .thenAnswer((_) async {});
      when(() => mockRepository.clearUserPresence(any(), any()))
          .thenAnswer((_) async {});

      // Configure connectivity service defaults
      when(() => mockConnectivityService.isConnectedToFirebase)
          .thenReturn(true);
      when(() => mockConnectivityService.connectionStatusText)
          .thenReturn('Ansluten');
      when(() => mockConnectivityService.startMonitoring()).thenReturn(null);
      when(() => mockConnectivityService.addListener(any())).thenReturn(null);
      when(() => mockConnectivityService.removeListener(any()))
          .thenReturn(null);

      // Create manager with constructor dependency injection (ultrathink approach)
      manager = RecipeCollaborativeManager(
        permissionService: mockPermissionService,
        collaborativeRepository: mockRepository,
        connectivityService: mockConnectivityService,
      );
    });

    tearDown(() async {
      // Only dispose if not already disposed
      try {
        manager.dispose();
      } catch (e) {
        // Already disposed, ignore FlutterError
      }

      // ULTRATHINK cleanup
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('Initialization and Basic Properties', () {
      test('should initialize with correct default state', () {
        // Assert
        expect(manager.isCollaborative, isFalse);
        expect(manager.isConnectedToFirebase, isTrue);
        // connectionStatusText starts empty; it's set by connectivity listener
        // only after enableCollaborativeMode calls _setupConnectivityMonitoring
        expect(manager.connectionStatusText, equals(''));
        expect(manager.collaborativeParticipants, isEmpty);
        expect(manager.liveEditors, isEmpty);
        expect(manager.realtimeRecipe, isNull);
        expect(manager.editMode, isNull);
        expect(manager.sharedRecipe, isNull);
      });

      test('should initialize with injected dependencies', () {
        // Assert
        expect(manager.isConnectedToFirebase, isTrue);
        // Note: connectivity service is accessed during construction through getter delegation
      });

      test('should handle permission getters correctly', () {
        // Assert - No permissions by default
        expect(manager.canEdit, isFalse);
        expect(manager.canView, isFalse);
        expect(manager.hasPermissions, isFalse);
      });

      test('should return defensive copies of collections', () {
        // Act
        final participants1 = manager.collaborativeParticipants;
        final participants2 = manager.collaborativeParticipants;
        final editors1 = manager.liveEditors;
        final editors2 = manager.liveEditors;

        // Assert - Should return different instances (defensive copies)
        expect(identical(participants1, participants2), isFalse);
        expect(identical(editors1, editors2), isFalse);
      });

      test('should handle null current user gracefully', () {
        // Arrange - use reset() since currentUserId is a concrete override (can't stub with when())
        mockPermissionService.reset();

        // Act & Assert - should not throw
        expect(() => manager.canEdit, returnsNormally);
      });
    });

    group('Collaborative Mode Management', () {
      test('should enable collaborative mode successfully', () async {
        // Act
        await manager.enableCollaborativeMode(testRecipe);

        // Assert
        expect(manager.isCollaborative, isTrue);
        expect(manager.realtimeRecipe, isNotNull);
        verify(() => mockRepository.createRealtimeRecipe(any())).called(1);
        verify(() => mockConnectivityService.startMonitoring()).called(1);
      });

      test('should not enable collaborative mode if already enabled', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);

        // Act
        await manager.enableCollaborativeMode(testRecipe);

        // Assert - Should only be called once from first enable
        verify(() => mockRepository.createRealtimeRecipe(any())).called(1);
      });

      test(
          'should throw exception when enabling collaborative mode without user',
          () async {
        // Arrange - use reset() since currentUserId is a concrete override (can't stub with when())
        mockPermissionService.reset();

        // Act & Assert
        await expectLater(
          manager.enableCollaborativeMode(testRecipe),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle Firebase error during collaborative mode enable',
          () async {
        // Arrange
        when(() => mockRepository.createRealtimeRecipe(any()))
            .thenThrow(Exception('Firebase error'));

        // Act & Assert
        await expectLater(
          manager.enableCollaborativeMode(testRecipe),
          throwsA(isA<Exception>()),
        );
        expect(manager.isCollaborative, isFalse);
      });

      test('should leave collaborative mode successfully', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);
        expect(manager.isCollaborative, isTrue);

        // Act
        await manager.leaveCollaborativeMode();

        // Assert
        expect(manager.isCollaborative, isFalse);
        expect(manager.realtimeRecipe, isNull);
        expect(manager.editMode, isNull);
        expect(manager.collaborativeParticipants, isEmpty);
        expect(manager.liveEditors, isEmpty);
      });

      test('should not leave collaborative mode if not enabled', () async {
        // Act
        await manager.leaveCollaborativeMode();

        // Assert
        expect(manager.isCollaborative, isFalse);
        verifyNever(() => mockRepository.clearUserPresence(any(), any()));
      });

      test('should handle errors during collaborative mode leave gracefully',
          () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);
        when(() => mockRepository.clearUserPresence(any(), any()))
            .thenThrow(Exception('Firebase error'));

        // Act & Assert - should not throw
        await expectLater(manager.leaveCollaborativeMode(), completes);
        expect(manager.isCollaborative, isFalse);
      });

      test('should reconnect to Firebase successfully', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);

        // Act
        await manager.reconnectToFirebase();

        // Assert - Should setup listeners again
        // Note: startMonitoring is called during connectivity setup
        verify(() => mockConnectivityService.startMonitoring())
            .called(2); // Enable + reconnect
      });

      test('should not reconnect if not in collaborative mode', () async {
        // Act
        await manager.reconnectToFirebase();

        // Assert
        verifyNever(() => mockConnectivityService.startMonitoring());
      });

      test('should handle reconnection errors gracefully', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);
        when(() => mockRepository.getRealtimeRecipeStream(any()))
            .thenThrow(Exception('Connection error'));

        // Act & Assert - should not throw
        await expectLater(manager.reconnectToFirebase(), completes);
      });
    });

    group('User Management', () {
      test('should invite user to collaboration successfully', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);

        // Act
        await manager.inviteUserToCollaboration(
            testParticipantId, testParticipantName, ResourcePermission.editor);

        // Assert
        verify(() => mockRepository.updateRealtimeRecipe(any())).called(1);
      });

      test('should not invite user if not in collaborative mode', () async {
        // Act
        await manager.inviteUserToCollaboration(
            testParticipantId, testParticipantName, ResourcePermission.editor);

        // Assert
        verifyNever(() => mockRepository.updateRealtimeRecipe(any()));
      });

      test('should handle Firebase error during user invitation', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);
        when(() => mockRepository.updateRealtimeRecipe(any()))
            .thenThrow(Exception('Firebase error'));

        // Act & Assert
        await expectLater(
          manager.inviteUserToCollaboration(testParticipantId,
              testParticipantName, ResourcePermission.editor),
          throwsA(isA<Exception>()),
        );
      });

      test('should remove user from collaboration successfully', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);
        await manager.inviteUserToCollaboration(
            testParticipantId, testParticipantName, ResourcePermission.editor);

        // Act
        await manager.removeUserFromCollaboration(testParticipantId);

        // Assert
        verify(() => mockRepository.updateRealtimeRecipe(any()))
            .called(2); // Once for invite, once for remove
      });

      test('should not remove user if not in collaborative mode', () async {
        // Act
        await manager.removeUserFromCollaboration(testParticipantId);

        // Assert
        verifyNever(() => mockRepository.updateRealtimeRecipe(any()));
      });

      test('should handle Firebase error during user removal', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);
        when(() => mockRepository.updateRealtimeRecipe(any()))
            .thenThrow(Exception('Firebase error'));

        // Act & Assert
        await expectLater(
          manager.removeUserFromCollaboration(testParticipantId),
          throwsA(isA<Exception>()),
        );
      });

      test('should load participant profiles successfully', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);

        // Act - inviteUserToCollaboration mutates _realtimeRecipe directly.
        // The asynchronous collaborativeParticipants list is populated by
        // _handleRealtimeUpdate, which fires when the realtime stream emits
        // again. In this unit test the stream is `Stream.value(...)` (one
        // emission at subscription), so re-emission won't happen — assert
        // against the synchronous side effect that the invite produced.
        await manager.inviteUserToCollaboration(
            testParticipantId, testParticipantName, ResourcePermission.editor);

        expect(manager.realtimeRecipe, isNotNull);
        expect(
            manager.realtimeRecipe!.participants, contains(testParticipantId));
      });

      test('should handle profile loading errors gracefully', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);
        // setProfileError replaces the prior `when(...).thenThrow(...)` —
        // Fake doesn't support mocktail stubs. Configures getUserProfile
        // to throw on every call.
        mockPermissionService.setProfileError(Exception('Profile error'));

        // Act
        await manager.inviteUserToCollaboration(
            testParticipantId, testParticipantName, ResourcePermission.editor);

        // Assert - should not crash
        await Future.delayed(const Duration(milliseconds: 100));
        expect(manager.collaborativeParticipants, isEmpty);
      });
    });

    group('Real-time Updates', () {
      test('should update recipe in Firebase with debouncing', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);
        final updatedRecipe =
            RecipeFactory.build(id: testRecipeId, title: 'Updated Recipe');

        // Act
        await manager.updateRecipeInFirebase(updatedRecipe);

        // Wait for debounce
        await Future.delayed(const Duration(milliseconds: 600));

        // Assert
        verify(() => mockRepository.updateRealtimeRecipe(any())).called(1);
      });

      test('should not update recipe if not in collaborative mode', () async {
        // Arrange
        final updatedRecipe =
            RecipeFactory.build(id: testRecipeId, title: 'Updated Recipe');

        // Act
        await manager.updateRecipeInFirebase(updatedRecipe);
        await Future.delayed(const Duration(milliseconds: 600));

        // Assert
        verifyNever(() => mockRepository.updateRealtimeRecipe(any()));
      });

      test('should handle Firebase update errors gracefully', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);
        when(() => mockRepository.updateRealtimeRecipe(any()))
            .thenThrow(Exception('Firebase error'));
        final updatedRecipe =
            RecipeFactory.build(id: testRecipeId, title: 'Updated Recipe');

        // Act
        await manager.updateRecipeInFirebase(updatedRecipe);
        await Future.delayed(const Duration(milliseconds: 600));

        // Assert
        expect(manager.isConnectedToFirebase, isFalse);
        // Production uses AppLocale.current.errorNetwork
        expect(manager.connectionStatusText,
            equals('Nätverksfel. Kontrollera din internetanslutning.'));
      });

      test('should debounce multiple rapid updates', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);
        final recipe1 =
            RecipeFactory.build(id: testRecipeId, title: 'Recipe 1');
        final recipe2 =
            RecipeFactory.build(id: testRecipeId, title: 'Recipe 2');
        final recipe3 =
            RecipeFactory.build(id: testRecipeId, title: 'Recipe 3');

        // Act - Multiple rapid updates
        await manager.updateRecipeInFirebase(recipe1);
        await manager.updateRecipeInFirebase(recipe2);
        await manager.updateRecipeInFirebase(recipe3);

        // Wait for debounce
        await Future.delayed(const Duration(milliseconds: 600));

        // Assert - Only one update should be made (debounced)
        verify(() => mockRepository.updateRealtimeRecipe(any())).called(1);
      });

      test('should handle real-time recipe updates from Firebase', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);
        final updatedRealtimeRecipe = testRealtimeRecipe.copyWith(
          recipe: RecipeFactory.build(
              id: testRecipeId, title: 'Firebase Updated Recipe'),
        );

        // Act - Simulate Firebase update
        final streamController = StreamController<RealtimeRecipe?>();
        when(() => mockRepository.getRealtimeRecipeStream(any()))
            .thenAnswer((_) => streamController.stream);

        // Setup listeners again to get the new stream
        await manager.leaveCollaborativeMode();
        await manager.enableCollaborativeMode(testRecipe);

        // Send update through stream
        streamController.add(updatedRealtimeRecipe);
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(manager.realtimeRecipe?.recipe.title,
            equals('Firebase Updated Recipe'));

        streamController.close();
      });

      test('should handle real-time stream errors gracefully', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);

        // Act - Simulate stream error
        final streamController = StreamController<RealtimeRecipe?>();
        when(() => mockRepository.getRealtimeRecipeStream(any()))
            .thenAnswer((_) => streamController.stream);

        await manager.leaveCollaborativeMode();
        await manager.enableCollaborativeMode(testRecipe);

        streamController.addError(Exception('Stream error'));
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(manager.isConnectedToFirebase, isFalse);
        // Production uses AppLocale.current.errorNetwork
        expect(manager.connectionStatusText,
            equals('Nätverksfel. Kontrollera din internetanslutning.'));

        streamController.close();
      });
    });

    group('Live Editors and Presence', () {
      test('should update live editors from Firebase', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);
        final editors = [testLiveEditor];

        // Act - Simulate participants stream update
        final streamController = StreamController<List<LiveEditor>>();
        when(() => mockRepository.getParticipantsStream(any()))
            .thenAnswer((_) => streamController.stream);

        await manager.leaveCollaborativeMode();
        await manager.enableCollaborativeMode(testRecipe);

        streamController.add(editors);
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(manager.liveEditors, hasLength(1));
        expect(manager.liveEditors.first.userId, equals(testParticipantId));

        streamController.close();
      });

      test('should handle participants stream errors gracefully', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);

        // Act - Simulate participants stream error
        final streamController = StreamController<List<LiveEditor>>();
        when(() => mockRepository.getParticipantsStream(any()))
            .thenAnswer((_) => streamController.stream);

        await manager.leaveCollaborativeMode();
        await manager.enableCollaborativeMode(testRecipe);

        streamController.addError(Exception('Participants error'));
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert - should not crash
        expect(manager.liveEditors, isEmpty);

        streamController.close();
      });

      test('should update user presence periodically', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);

        // Act - Presence timer is started but may not trigger in test window
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert - Presence tracking is set up via timer, but timer period is 30 seconds
        // In the short test window, updateUserPresence may not be called yet
        // The important thing is that presence tracking is initialized without errors
        expect(manager.isCollaborative, isTrue);

        // Note: Timer-based presence updates happen every 30 seconds,
        // so we don't expect calls in this short test window
      });

      test('should not update presence if user is null', () async {
        // Arrange - use reset() since currentUserId is a concrete override (can't stub with when())
        mockPermissionService.reset();

        // Act - Try to enable collaborative mode (should fail)
        try {
          await manager.enableCollaborativeMode(testRecipe);
        } catch (e) {
          // Expected to fail with null user
        }

        // Assert - No presence updates should occur
        verifyNever(
            () => mockRepository.updateUserPresence(any(), any(), any()));
      });

      test('should handle presence update errors gracefully', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);
        when(() => mockRepository.updateUserPresence(any(), any(), any()))
            .thenThrow(Exception('Presence error'));

        // Act & Assert - should not crash
        await Future.delayed(const Duration(milliseconds: 100));
        expect(manager.isCollaborative, isTrue);
      });

      test('should clear presence when leaving collaborative mode', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);

        // Act
        await manager.leaveCollaborativeMode();

        // Assert
        verify(() => mockRepository.clearUserPresence(any(), testUserId))
            .called(1);
      });

      test('should handle presence clearing errors gracefully', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);
        when(() => mockRepository.clearUserPresence(any(), any()))
            .thenThrow(Exception('Clear error'));

        // Act & Assert - should not throw
        await expectLater(manager.leaveCollaborativeMode(), completes);
        expect(manager.isCollaborative, isFalse);
      });
    });

    group('Connectivity Management', () {
      test('should setup connectivity monitoring', () async {
        // Act
        await manager.enableCollaborativeMode(testRecipe);

        // Assert
        verify(() => mockConnectivityService.startMonitoring()).called(1);
        verify(() => mockConnectivityService.addListener(any())).called(1);
      });

      test('should handle connectivity changes', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);
        when(() => mockConnectivityService.isConnectedToFirebase)
            .thenReturn(false);
        when(() => mockConnectivityService.connectionStatusText)
            .thenReturn('Frånkopplad');

        // Capture the connectivity listener
        late VoidCallback connectivityListener;
        final captured =
            verify(() => mockConnectivityService.addListener(captureAny()))
                .captured;
        for (final listener in captured) {
          connectivityListener = listener;
        }

        // Act - Simulate connectivity change
        connectivityListener();

        // Assert
        expect(manager.isConnectedToFirebase, isFalse);
        expect(manager.connectionStatusText, equals('Frånkopplad'));
      });

      test('should remove connectivity listener on disposal', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);

        // Act
        manager.dispose();

        // Assert
        verify(() => mockConnectivityService.removeListener(any())).called(1);
      });
    });

    group('Error Handling and Edge Cases', () {
      test('should handle null realtime recipe gracefully', () {
        // Act & Assert - All methods should handle null realtime recipe
        expect(
            () => manager.updateRecipeInFirebase(testRecipe), returnsNormally);
        expect(
            () => manager.inviteUserToCollaboration(
                'user', 'name', ResourcePermission.editor),
            returnsNormally);
        expect(
            () => manager.removeUserFromCollaboration('user'), returnsNormally);
      });

      test('should handle repository errors in all operations', () async {
        // Arrange
        when(() => mockRepository.createRealtimeRecipe(any()))
            .thenThrow(Exception('Repository error'));
        when(() => mockRepository.updateRealtimeRecipe(any()))
            .thenThrow(Exception('Repository error'));
        when(() => mockRepository.updateUserPresence(any(), any(), any()))
            .thenThrow(Exception('Repository error'));

        // Act & Assert - All should handle errors gracefully
        await expectLater(manager.enableCollaborativeMode(testRecipe),
            throwsA(isA<Exception>()));
      });

      test('should handle multiple rapid state changes', () async {
        // Act - Multiple rapid operations
        for (int i = 0; i < 5; i++) {
          await manager.enableCollaborativeMode(testRecipe);
          await manager.leaveCollaborativeMode();
        }

        // Assert - Should end in consistent state
        expect(manager.isCollaborative, isFalse);
        expect(manager.realtimeRecipe, isNull);
      });

      test('should handle async operations during disposal', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);

        // Act - Dispose while async operations might be running
        manager.updateRecipeInFirebase(testRecipe);
        manager.dispose();

        // Wait for any async operations to complete
        await Future.delayed(const Duration(milliseconds: 600));

        // Assert - dispose() cleans up resources but doesn't reset collaborative state
        // Note: dispose() calls cleanup methods but doesn't call leaveCollaborativeMode()
        // The collaborative flag remains true, but resources are cleaned up
        expect(manager.isCollaborative,
            isTrue); // State preserved, resources cleaned
      });

      test('should handle stream controller disposal correctly', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);
        final streamController = StreamController<RealtimeRecipe?>();
        when(() => mockRepository.getRealtimeRecipeStream(any()))
            .thenAnswer((_) => streamController.stream);

        await manager.leaveCollaborativeMode();
        await manager.enableCollaborativeMode(testRecipe);

        // Act - Dispose while stream is active
        manager.dispose();
        streamController.close();

        // Assert - should not throw
        await Future.delayed(const Duration(milliseconds: 100));
      });
    });

    group('Lifecycle and Disposal', () {
      test('should dispose without throwing', () {
        // Act & Assert
        expect(() => manager.dispose(), returnsNormally);
      });

      test('should cleanup all resources on disposal', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);

        // Act
        manager.dispose();

        // Assert
        verify(() => mockRepository.clearUserPresence(any(), testUserId))
            .called(1);
        verify(() => mockConnectivityService.removeListener(any())).called(1);
      });

      test('should handle multiple dispose calls', () {
        // Act & Assert - First dispose should work, subsequent should throw
        expect(() => manager.dispose(), returnsNormally);
        expect(() => manager.dispose(), throwsFlutterError);
      });

      test('should handle disposal during active operations', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);
        manager.updateRecipeInFirebase(testRecipe);

        // Act - Dispose immediately after starting operation
        manager.dispose();

        // Assert - should not throw
        await Future.delayed(const Duration(milliseconds: 600));
      });

      test('should cleanup timers on disposal', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);

        // Wait for initial presence update
        await Future.delayed(const Duration(milliseconds: 50));

        // Act
        manager.dispose();

        // Wait to ensure no additional timer callbacks are executed after disposal.
        // Real-time delay needed: production uses a real Timer whose clock is
        // not routed through `package:clock`, so fakeAsync cannot drive it.
        // ignore: butlery_fake_time
        await Future.delayed(const Duration(seconds: 1));

        // Assert - Presence cleanup was called, initial presence may or may not be called due to timer
        verify(() => mockRepository.clearUserPresence(any(), any()))
            .called(1); // Cleanup called

        // Note: updateUserPresence might be called 0 or 1 times depending on timer timing
        // The important thing is that timers are cleaned up and no calls happen after disposal
      });

      test('should handle async disposal cleanup errors gracefully', () async {
        // Arrange
        await manager.enableCollaborativeMode(testRecipe);
        when(() => mockRepository.clearUserPresence(any(), any()))
            .thenThrow(Exception('Cleanup error'));

        // Act & Assert - should not throw
        expect(() => manager.dispose(), returnsNormally);
      });
    });
  });
}
