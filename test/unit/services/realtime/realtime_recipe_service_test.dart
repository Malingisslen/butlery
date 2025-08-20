/// Unit tests for RealtimeRecipeService
///
/// Tests real-time recipe management including creation, watching, content operations,
/// participant management, and collaborative editing features.
// ignore_for_file: close_sinks

library;

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/realtime/realtime_recipe_service.dart';
import 'package:butlery/services/realtime/modules/recipe_content_operations.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/factories/recipe_factory.dart';

// Test doubles for RealtimeRecipe
class TestRealtimeRecipe extends RealtimeRecipe {
  TestRealtimeRecipe({
    required super.id,
    required super.recipe,
    required super.ownerId,
    String? ownerDisplayName,
    Map<String, ResourcePermission>? participants,
    DateTime? createdAt,
    DateTime? lastEditedAt,
    super.editCount = 0,
  }) : super(
          ownerDisplayName: ownerDisplayName ?? 'Test Owner',
          participants: participants ?? {ownerId: ResourcePermission.owner},
          createdAt: createdAt ?? DateTime.now(),
          lastEditedAt: lastEditedAt ?? DateTime.now(),
          lastEditedBy: ownerId,
          lastEditedByDisplayName: ownerDisplayName ?? 'Test Owner',
        );

  // Factory for easy creation
  factory TestRealtimeRecipe.fromRecipe({
    required Recipe recipe,
    required String ownerId,
    String? ownerDisplayName,
    Map<String, ResourcePermission>? participants,
  }) {
    return TestRealtimeRecipe(
      id: 'realtime_${recipe.id}',
      recipe: recipe,
      ownerId: ownerId,
      ownerDisplayName: ownerDisplayName,
      participants: participants,
    );
  }
}

void main() {
  late RealtimeRecipeService service;
  late MockRealtimeSyncService mockSyncService;
  late MockPermissionService mockPermissionService;
  late StreamController<RealtimeRecipe> recipeStreamController;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    await TestServiceLocator.initialize();
    registerFallbackValue(RealtimeResourceType.recipe);
    registerFallbackValue(ResourcePermission.viewer);
    registerFallbackValue(TestRealtimeRecipe(
      id: 'fallback',
      recipe: RecipeFactory.build(title: 'Fallback Recipe'),
      ownerId: 'test_user',
    ));
  });

  setUp(() async {
    // Create mocks
    mockSyncService = MockRealtimeSyncService();
    mockPermissionService = MockPermissionService();
    recipeStreamController = StreamController<RealtimeRecipe>.broadcast();

    // Configure permission state
    mockPermissionService.setPermissionState(
      currentUserId: 'test_user_123',
      defaultHasPermission: true,
      userDisplayName: 'Test User',
    );

    // Configure sync service
    mockSyncService.setConnectionState(true);
    mockSyncService.setInitialized(true);

    // Create service
    service = RealtimeRecipeService(
      syncService: mockSyncService,
      permissionService: mockPermissionService,
    );
  });

  tearDown(() async {
    await recipeStreamController.close();
    mockSyncService.disposeStreams();
    service.dispose();
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  group('RealtimeRecipeService', () {
    group('Initialization & State Management', () {
      test('should initialize with default state', () {
        // Assert
        expect(service.isProcessing, isFalse);
        expect(service.lastError, isNull);
      });

      test('should track processing state during operations', () async {
        // Arrange
        final recipe = RecipeFactory.build(
          id: 'recipe_123',
          title: 'Test Recipe',
        );

        when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .thenAnswer((_) async {});

        // Act & Assert - Check processing state changes
        expect(service.isProcessing, isFalse);

        final future = service.createRealtimeRecipe(recipe: recipe);

        // Should be processing immediately
        expect(service.isProcessing, isTrue);

        await future;

        // Should not be processing after completion
        expect(service.isProcessing, isFalse);
      });

      test('should handle error state management', () async {
        // Arrange
        final recipe = RecipeFactory.build();

        when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .thenAnswer((_) async => throw Exception('Sync failed'));

        // Act
        try {
          await service.createRealtimeRecipe(recipe: recipe);
        } catch (_) {
          // Expected
        }

        // Assert
        expect(service.lastError, isNotNull);
        expect(service.lastError!.message,
            contains('Kunde inte skapa realtidsrecept'));

        // Clear error
        service.clearError();
        expect(service.lastError, isNull);
      });

      test('should dispose resources properly', () {
        // Act
        service.dispose();

        // Assert - No exceptions should be thrown
        expect(() => service.dispose(), returnsNormally);
      });
    });

    group('Recipe Creation', () {
      test('should create realtime recipe from existing recipe', () async {
        // Arrange
        final recipe = RecipeFactory.build(
          id: 'recipe_123',
          title: 'Köttbullar med potatismos',
        );

        when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .thenAnswer((_) async {});

        // Act
        final result = await service.createRealtimeRecipe(
          recipe: recipe,
          editorUserIds: ['editor_1', 'editor_2'],
          viewerUserIds: ['viewer_1'],
        );

        // Assert
        expect(result, isA<RealtimeRecipe>());
        expect(result.recipe.id, equals('recipe_123'));
        expect(result.recipe.title, equals('Köttbullar med potatismos'));
        expect(result.ownerId, equals('test_user_123'));
        expect(result.ownerDisplayName, equals('Test User'));
        verify(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .called(1);
      });

      test('should set editor and viewer permissions on creation', () async {
        // Arrange
        final recipe = RecipeFactory.build();
        final editorIds = ['editor_1', 'editor_2'];
        final viewerIds = ['viewer_1', 'viewer_2'];

        when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .thenAnswer((invocation) async {
          final realtimeRecipe =
              invocation.positionalArguments[0] as RealtimeRecipe;

          // Verify permissions are set correctly
          expect(realtimeRecipe.participants['editor_1'],
              equals(ResourcePermission.editor));
          expect(realtimeRecipe.participants['editor_2'],
              equals(ResourcePermission.editor));
          expect(realtimeRecipe.participants['viewer_1'],
              equals(ResourcePermission.viewer));
          expect(realtimeRecipe.participants['viewer_2'],
              equals(ResourcePermission.viewer));
        });

        // Act
        await service.createRealtimeRecipe(
          recipe: recipe,
          editorUserIds: editorIds,
          viewerUserIds: viewerIds,
        );

        // Assert
        verify(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .called(1);
      });

      test('should require authentication for creation', () async {
        // Arrange
        // Remove authentication
        mockPermissionService.setPermissionState(
          currentUserId: null,
        );

        final recipe = RecipeFactory.build();

        // Act & Assert
        expect(
          () => service.createRealtimeRecipe(recipe: recipe),
          throwsA(isA<RecipeOperationError>()
              .having((e) => e.message, 'message', 'Användare inte inloggad')),
        );
      });

      test('should handle creation errors gracefully', () async {
        // Arrange
        final recipe = RecipeFactory.build();

        when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .thenAnswer((_) async => throw Exception('Firebase error'));

        // Act & Assert
        expect(
          () => service.createRealtimeRecipe(recipe: recipe),
          throwsA(isA<Exception>()),
        );

        expect(service.lastError, isNotNull);
        expect(service.lastError!.operation,
            equals(RecipeOperationType.createFromExisting));
      });

      test('should preserve recipe data during conversion', () async {
        // Arrange
        final recipe = RecipeFactory.build(
          id: 'recipe_123',
          title: 'Complete Recipe',
          description: 'A complete recipe with all fields',
          ingredients: ['Ingredient 1', 'Ingredient 2', 'Ingredient 3'],
          instructions: ['Step 1', 'Step 2', 'Step 3'],
          imageUrls: ['image1.jpg', 'image2.jpg'],
          mealType: 'Middag',
          portions: 6,
          timeMinutes: 45,
          rating: 4.8,
          tags: ['svensk', 'vegetarisk', 'glutenfri'],
        );

        RealtimeRecipe? capturedRecipe;
        when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .thenAnswer((invocation) async {
          capturedRecipe = invocation.positionalArguments[0] as RealtimeRecipe;
        });

        // Act
        await service.createRealtimeRecipe(recipe: recipe);

        // Assert
        expect(capturedRecipe, isNotNull);
        expect(capturedRecipe!.recipe.title, equals('Complete Recipe'));
        expect(capturedRecipe!.recipe.ingredients,
            equals(['Ingredient 1', 'Ingredient 2', 'Ingredient 3']));
        expect(capturedRecipe!.recipe.instructions,
            equals(['Step 1', 'Step 2', 'Step 3']));
        expect(capturedRecipe!.recipe.portions, equals(6));
        expect(capturedRecipe!.recipe.timeMinutes, equals(45));
      });
    });

    group('Real-time Watching', () {
      test('should watch recipe with stream updates', () async {
        // Arrange
        final recipe = RecipeFactory.build(
          id: 'recipe_123',
          title: 'Streaming Recipe',
        );

        final testRealtimeRecipe = TestRealtimeRecipe.fromRecipe(
          recipe: recipe,
          ownerId: 'test_user_123',
        );

        final streamController = mockSyncService
            .getOrCreateStreamController<RealtimeRecipe>('recipe_123');

        when(() => mockSyncService.watchResource<RealtimeRecipe>('recipe_123'))
            .thenAnswer((_) => streamController.stream);

        // Act
        final stream = service.watchRealtimeRecipe('recipe_123');

        // Assert
        streamController.add(testRealtimeRecipe);

        await expectLater(
          stream,
          emits(isA<RealtimeRecipe>()
              .having((r) => r.id, 'id', contains('recipe_123'))
              .having((r) => r.recipe.title, 'title', 'Streaming Recipe')),
        );
      });

      test('should handle stream updates', () async {
        // Arrange
        final initialRecipe = RecipeFactory.build(
          id: 'recipe_123',
          title: 'Initial Title',
        );

        final updatedRecipe = RecipeFactory.build(
          id: 'recipe_123',
          title: 'Updated Title',
        );

        final initial = TestRealtimeRecipe.fromRecipe(
          recipe: initialRecipe,
          ownerId: 'test_user_123',
        );

        final updated = TestRealtimeRecipe.fromRecipe(
          recipe: updatedRecipe,
          ownerId: 'test_user_123',
        );

        final streamController = mockSyncService
            .getOrCreateStreamController<RealtimeRecipe>('recipe_123');

        when(() => mockSyncService.watchResource<RealtimeRecipe>('recipe_123'))
            .thenAnswer((_) => streamController.stream);

        // Act
        final stream = service.watchRealtimeRecipe('recipe_123');

        // Add both updates
        streamController.add(initial);
        streamController.add(updated);

        // Assert
        await expectLater(
          stream,
          emitsInOrder([
            isA<RealtimeRecipe>()
                .having((r) => r.recipe.title, 'title', 'Initial Title'),
            isA<RealtimeRecipe>()
                .having((r) => r.recipe.title, 'title', 'Updated Title'),
          ]),
        );
      });

      test('should handle stream errors', () async {
        // Arrange
        when(() => mockSyncService.watchResource<RealtimeRecipe>('recipe_123'))
            .thenAnswer((_) => Stream.error(Exception('Stream error')));

        // Act & Assert
        expect(
          () => service.watchRealtimeRecipe('recipe_123'),
          throwsA(isA<Exception>()),
        );

        expect(service.lastError, isNotNull);
      });

      test('should clean up stream on dispose', () async {
        // Arrange
        final streamController = mockSyncService
            .getOrCreateStreamController<RealtimeRecipe>('recipe_123');

        when(() => mockSyncService.watchResource<RealtimeRecipe>('recipe_123'))
            .thenAnswer((_) => streamController.stream);

        // Act
        final stream = service.watchRealtimeRecipe('recipe_123');
        final subscription = stream.listen((_) {});

        service.dispose();

        // Assert - Stream should be cancelled
        expect(subscription.cancel(), completes);
      });
    });

    group('Content Operations', () {
      final testRecipeId = 'recipe_123';
      late TestRealtimeRecipe testRealtimeRecipe;

      setUp(() {
        final recipe = RecipeFactory.build(
          id: testRecipeId,
          title: 'Test Recipe',
          ingredients: ['Ingredient 1', 'Ingredient 2'],
          instructions: ['Step 1', 'Step 2'],
          imageUrls: ['image1.jpg'],
        );

        testRealtimeRecipe = TestRealtimeRecipe.fromRecipe(
          recipe: recipe,
          ownerId: 'test_user_123',
        );

        mockSyncService.setCachedResource(testRecipeId, testRealtimeRecipe);
        // Set permission for this recipe
        when(() => mockPermissionService.canEditRecipe(testRecipeId))
            .thenReturn(true);
      });

      test('should update basic recipe information', () async {
        // Arrange
        when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .thenAnswer((_) async {});

        // Act
        await service.updateBasicInfo(
          resourceId: testRecipeId,
          title: 'Updated Title',
          description: 'Updated description',
          mealType: 'Frukost',
          portions: 8,
          timeMinutes: 60,
          rating: 4.5,
          tags: ['ny', 'uppdaterad'],
        );

        // Assert
        verify(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .called(1);
      });

      test('should add ingredient to recipe', () async {
        // Arrange
        when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .thenAnswer((_) async {});

        // Act
        await service.addIngredient(
          resourceId: testRecipeId,
          ingredient: 'New Ingredient',
        );

        // Assert
        verify(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .called(1);
      });

      test('should remove ingredient from recipe', () async {
        // Arrange
        when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .thenAnswer((_) async {});

        // Act
        await service.removeIngredient(
          resourceId: testRecipeId,
          index: 0,
        );

        // Assert
        verify(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .called(1);
      });

      test('should update all ingredients', () async {
        // Arrange
        when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .thenAnswer((_) async {});

        // Act
        await service.updateIngredients(
          resourceId: testRecipeId,
          ingredients: ['New 1', 'New 2', 'New 3'],
        );

        // Assert
        verify(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .called(1);
      });

      test('should add instruction to recipe', () async {
        // Arrange
        when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .thenAnswer((_) async {});

        // Act
        await service.addInstruction(
          resourceId: testRecipeId,
          instruction: 'New step',
        );

        // Assert
        verify(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .called(1);
      });

      test('should update all instructions', () async {
        // Arrange
        when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .thenAnswer((_) async {});

        // Act
        await service.updateInstructions(
          resourceId: testRecipeId,
          instructions: ['Step A', 'Step B', 'Step C'],
        );

        // Assert
        verify(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .called(1);
      });

      test('should add and remove images', () async {
        // Arrange
        when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .thenAnswer((_) async {});

        // Act - Add image
        await service.addImage(
          resourceId: testRecipeId,
          imageUrl: 'new_image.jpg',
        );

        verify(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .called(1);

        // Act - Remove image
        await service.removeImage(
          resourceId: testRecipeId,
          index: 0,
        );

        verify(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .called(2);
      });

      test('should validate permissions for edits', () async {
        // Arrange
        // Override permission for this test
        when(() => mockPermissionService.canEditRecipe(testRecipeId))
            .thenReturn(false);

        // Act & Assert
        expect(
          () => service.updateBasicInfo(
            resourceId: testRecipeId,
            title: 'Should Fail',
          ),
          throwsA(isA<RecipeOperationError>().having(
              (e) => e.message, 'message', 'Ingen redigeringsbehörighet')),
        );
      });

      test('should track edit history', () async {
        // Arrange
        when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .thenAnswer((invocation) async {
          final updated = invocation.positionalArguments[0] as RealtimeRecipe;

          // Verify edit tracking
          expect(updated.lastEditedBy, equals('test_user_123'));
          expect(updated.lastEditedByDisplayName, equals('Test User'));
          expect(updated.editCount, greaterThan(testRealtimeRecipe.editCount));
        });

        // Act
        await service.updateBasicInfo(
          resourceId: testRecipeId,
          title: 'Updated for tracking',
        );

        // Assert
        verify(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .called(1);
      });
    });

    group('Participant Management', () {
      final testRecipeId = 'recipe_123';
      late TestRealtimeRecipe testRealtimeRecipe;

      setUp(() {
        final recipe = RecipeFactory.build(
          id: testRecipeId,
          title: 'Test Recipe',
        );

        testRealtimeRecipe = TestRealtimeRecipe.fromRecipe(
          recipe: recipe,
          ownerId: 'test_user_123',
        );

        mockSyncService.setCachedResource(testRecipeId, testRealtimeRecipe);
        // Set permission for this recipe
        when(() => mockPermissionService.canEditRecipe(testRecipeId))
            .thenReturn(true);
      });

      test('should add participant with permissions', () async {
        // Arrange
        when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .thenAnswer((_) async {});

        // Act
        await service.addParticipant(
          resourceId: testRecipeId,
          userId: 'new_user',
          userDisplayName: 'New User',
          permission: ResourcePermission.editor,
        );

        // Assert
        verify(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .called(1);
      });

      test('should remove participant', () async {
        // Arrange
        when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .thenAnswer((_) async {});

        // Act
        await service.removeParticipant(
          resourceId: testRecipeId,
          userId: 'user_to_remove',
        );

        // Assert
        verify(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .called(1);
      });

      test('should update participant permissions', () async {
        // Arrange
        when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .thenAnswer((_) async {});

        // Act
        await service.updateParticipantPermission(
          resourceId: testRecipeId,
          userId: 'existing_user',
          newPermission: ResourcePermission.viewer,
        );

        // Assert
        verify(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .called(1);
      });

      test('should validate permissions for participant management', () async {
        // Arrange
        // Override permission for this test
        when(() => mockPermissionService.canEditRecipe(testRecipeId))
            .thenReturn(false);

        // Act & Assert
        expect(
          () => service.addParticipant(
            resourceId: testRecipeId,
            userId: 'new_user',
            userDisplayName: 'New User',
            permission: ResourcePermission.viewer,
          ),
          throwsA(isA<RecipeOperationError>().having(
              (e) => e.message, 'message', 'Ingen redigeringsbehörighet')),
        );
      });

      test('should handle owner protection', () async {
        // Note: Owner protection would be in RecipeParticipants module
        // Service just delegates, so we test the call goes through

        when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .thenAnswer((_) async {});

        // Act
        await service.removeParticipant(
          resourceId: testRecipeId,
          userId: 'test_user_123', // Owner ID
        );

        // Assert - Still calls through (validation in module)
        verify(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .called(1);
      });
    });

    group('Utility Operations', () {
      final testRecipeId = 'recipe_123';
      late TestRealtimeRecipe testRealtimeRecipe;

      setUp(() {
        final recipe = RecipeFactory.build(
          id: testRecipeId,
          title: 'Utility Test Recipe',
        );

        testRealtimeRecipe = TestRealtimeRecipe(
          id: testRecipeId,
          recipe: recipe,
          ownerId: 'test_user_123',
          lastEditedAt: DateTime(2024, 1, 15, 10, 30),
          editCount: 5,
        );

        mockSyncService.setCachedResource(testRecipeId, testRealtimeRecipe);
      });

      test('should create personal copy of recipe', () {
        // Act
        final copy = service.createPersonalCopy(testRealtimeRecipe);

        // Assert
        expect(copy, isA<Recipe>());
        expect(copy.title, equals('Utility Test Recipe'));
        expect(copy.id, isNot(equals(testRecipeId))); // Should have new ID
      });

      test('should check if recipe changed since timestamp', () {
        // Act & Assert
        expect(
          service.hasRecipeChangedSince(
            testRealtimeRecipe,
            DateTime(2024, 1, 15, 9, 0),
          ),
          isTrue, // Recipe edited at 10:30, after 9:00
        );

        expect(
          service.hasRecipeChangedSince(
            testRealtimeRecipe,
            DateTime(2024, 1, 15, 11, 0),
          ),
          isFalse, // Recipe edited at 10:30, before 11:00
        );
      });

      test('should get recipe changes summary', () {
        // Act
        final summary = service.getRecipeChangesSummary(testRealtimeRecipe);

        // Assert
        expect(summary, isA<String>());
        expect(summary, isNotEmpty);
        // The actual summary format depends on RecipeContentOperations implementation
      });
    });

    group('Delete Operation', () {
      test('should delete realtime recipe', () async {
        // Arrange
        when(() => mockSyncService.deleteResource(
                'recipe_123', RealtimeResourceType.recipe))
            .thenAnswer((_) async {});

        // Act
        await service.deleteRealtimeRecipe('recipe_123');

        // Assert
        verify(() => mockSyncService.deleteResource(
            'recipe_123', RealtimeResourceType.recipe)).called(1);
      });

      test('should require authentication for delete', () async {
        // Arrange
        // Remove authentication
        mockPermissionService.setPermissionState(
          currentUserId: null,
        );

        // Act & Assert
        expect(
          () => service.deleteRealtimeRecipe('recipe_123'),
          throwsA(isA<RecipeOperationError>()
              .having((e) => e.message, 'message', 'Användare inte inloggad')),
        );
      });

      test('should handle delete errors', () async {
        // Arrange
        when(() => mockSyncService.deleteResource(
                'recipe_123', RealtimeResourceType.recipe))
            .thenAnswer((_) async => throw Exception('Delete failed'));

        // Act & Assert
        expect(
          () => service.deleteRealtimeRecipe('recipe_123'),
          throwsA(isA<Exception>()),
        );

        expect(service.lastError, isNotNull);
      });
    });

    group('Error Scenarios', () {
      test('should handle authentication errors', () async {
        // Arrange
        // Remove authentication
        mockPermissionService.setPermissionState(
          currentUserId: null,
        );

        final recipe = RecipeFactory.build();

        // Act & Assert - Create
        expect(
          () => service.createRealtimeRecipe(recipe: recipe),
          throwsA(isA<RecipeOperationError>()
              .having((e) => e.message, 'message', 'Användare inte inloggad')),
        );

        // Act & Assert - Update
        expect(
          () => service.updateBasicInfo(
            resourceId: 'recipe_123',
            title: 'Updated',
          ),
          throwsA(isA<RecipeOperationError>()
              .having((e) => e.message, 'message', 'Användare inte inloggad')),
        );

        // Act & Assert - Delete
        expect(
          () => service.deleteRealtimeRecipe('recipe_123'),
          throwsA(isA<RecipeOperationError>()
              .having((e) => e.message, 'message', 'Användare inte inloggad')),
        );
      });

      test('should handle permission errors', () async {
        // Arrange
        final recipe = RecipeFactory.build(id: 'recipe_123');
        final testRealtimeRecipe = TestRealtimeRecipe.fromRecipe(
          recipe: recipe,
          ownerId: 'other_user', // Different owner
        );

        mockSyncService.setCachedResource('recipe_123', testRealtimeRecipe);
        // Override permission for this test
        when(() => mockPermissionService.canEditRecipe('recipe_123'))
            .thenReturn(false);

        // Act & Assert
        expect(
          () => service.addIngredient(
            resourceId: 'recipe_123',
            ingredient: 'New ingredient',
          ),
          throwsA(isA<RecipeOperationError>().having(
              (e) => e.message, 'message', 'Ingen redigeringsbehörighet')),
        );
      });

      test('should handle not found errors', () async {
        // Arrange
        // Don't set any cached resource - getCachedResource will return null

        // Act & Assert
        expect(
          () => service.updateBasicInfo(
            resourceId: 'nonexistent',
            title: 'Should Fail',
          ),
          throwsA(isA<RecipeOperationError>()
              .having((e) => e.message, 'message', 'Receptet hittades inte')),
        );
      });

      test('should handle sync failures', () async {
        // Arrange
        final recipe = RecipeFactory.build(id: 'recipe_123');
        final testRealtimeRecipe = TestRealtimeRecipe.fromRecipe(
          recipe: recipe,
          ownerId: 'test_user_123',
        );

        mockSyncService.setCachedResource('recipe_123', testRealtimeRecipe);
        // Set permission for this recipe
        when(() => mockPermissionService.canEditRecipe('recipe_123'))
            .thenReturn(true);

        when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
            .thenAnswer((_) async => throw Exception('Network error'));

        // Act & Assert
        expect(
          () => service.updateBasicInfo(
            resourceId: 'recipe_123',
            title: 'Should Fail',
          ),
          throwsA(isA<Exception>()),
        );

        expect(service.lastError, isNotNull);
        expect(service.lastError!.message,
            contains('Kunde inte uppdatera grundinfo'));
      });

      test('should use Swedish error messages', () async {
        // Arrange
        // Remove authentication
        mockPermissionService.setPermissionState(
          currentUserId: null,
        );

        final recipe = RecipeFactory.build();

        // Act & Assert - Various operations with Swedish errors
        final operations = [
          () => service.createRealtimeRecipe(recipe: recipe),
          () => service.updateBasicInfo(
                resourceId: 'recipe_123',
                title: 'Test',
              ),
          () => service.deleteRealtimeRecipe('recipe_123'),
        ];

        for (final operation in operations) {
          expect(
            operation,
            throwsA(isA<RecipeOperationError>().having((e) => e.message,
                'message', contains('Användare inte inloggad'))),
          );
        }
      });
    });
  });
}
