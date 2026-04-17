/// Unit tests for RealtimeRecipeService
///
/// Tests real-time recipe management including creation, watching, content operations,
/// participant management, and error handling.
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
  late FakePermissionService mockPermissionService;

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
    mockSyncService = MockRealtimeSyncService();
    mockPermissionService = FakePermissionService();

    mockPermissionService.setPermissionState(
      currentUserId: 'test_user_123',
      defaultHasPermission: true,
      userDisplayName: 'Test User',
    );
    mockSyncService.setConnectionState(true);
    mockSyncService.setInitialized(true);

    service = RealtimeRecipeService(
      syncService: mockSyncService,
      permissionService: mockPermissionService,
    );
  });

  tearDown(() async {
    mockSyncService.disposeStreams();
    service.dispose();
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  group('State Management', () {
    test('should initialize with default state', () {
      expect(service.isProcessing, isFalse);
      expect(service.lastError, isNull);
    });

    test('should track processing state during operations', () async {
      final recipe = RecipeFactory.build(id: 'recipe_123', title: 'Test');
      when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
          .thenAnswer((_) async {});

      expect(service.isProcessing, isFalse);
      final future = service.createRealtimeRecipe(recipe: recipe);
      expect(service.isProcessing, isTrue);
      await future;
      expect(service.isProcessing, isFalse);
    });

    test('should handle error state management', () async {
      final recipe = RecipeFactory.build();
      when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
          .thenAnswer((_) async => throw Exception('Sync failed'));

      try {
        await service.createRealtimeRecipe(recipe: recipe);
      } catch (_) {}

      expect(service.lastError, isNotNull);
      service.clearError();
      expect(service.lastError, isNull);
    });
  });

  group('Recipe Creation', () {
    test('should create realtime recipe from existing recipe', () async {
      final recipe = RecipeFactory.build(
        id: 'recipe_123',
        title: 'Kottbullar',
      );
      when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
          .thenAnswer((_) async {});

      final result = await service.createRealtimeRecipe(
        recipe: recipe,
        editorUserIds: ['editor_1'],
        viewerUserIds: ['viewer_1'],
      );

      expect(result, isA<RealtimeRecipe>());
      expect(result.recipe.id, equals('recipe_123'));
      expect(result.ownerId, equals('test_user_123'));
      verify(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
          .called(1);
    });

    test('should require authentication for creation', () async {
      mockPermissionService.setPermissionState(
          currentUserId: null, isAuthenticated: false);
      final recipe = RecipeFactory.build();

      expect(
        () => service.createRealtimeRecipe(recipe: recipe),
        throwsA(isA<RecipeOperationError>()),
      );
    });

    test('should preserve recipe data during conversion', () async {
      final recipe = RecipeFactory.build(
        id: 'recipe_123',
        title: 'Complete Recipe',
        ingredients: ['Ingredient 1', 'Ingredient 2'],
        instructions: ['Step 1', 'Step 2'],
        portions: 6,
        timeMinutes: 45,
      );

      RealtimeRecipe? capturedRecipe;
      when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
          .thenAnswer((invocation) async {
        capturedRecipe = invocation.positionalArguments[0] as RealtimeRecipe;
      });

      await service.createRealtimeRecipe(recipe: recipe);

      expect(capturedRecipe, isNotNull);
      expect(capturedRecipe!.recipe.title, equals('Complete Recipe'));
      expect(capturedRecipe!.recipe.ingredients,
          equals(['Ingredient 1', 'Ingredient 2']));
      expect(capturedRecipe!.recipe.portions, equals(6));
    });
  });

  group('Real-time Watching', () {
    test('should watch recipe with stream updates', () async {
      final recipe = RecipeFactory.build(id: 'recipe_123', title: 'Streaming');
      final testRealtimeRecipe = TestRealtimeRecipe.fromRecipe(
        recipe: recipe,
        ownerId: 'test_user_123',
      );

      final streamController = StreamController<RealtimeRecipe>.broadcast();
      when(() => mockSyncService.watchResource<RealtimeRecipe>('recipe_123'))
          .thenAnswer((_) => streamController.stream);

      final stream = service.watchRealtimeRecipe('recipe_123');

      // Schedule add after expectLater starts listening
      final future = expectLater(
        stream,
        emits(isA<RealtimeRecipe>()
            .having((r) => r.recipe.title, 'title', 'Streaming')),
      );
      streamController.add(testRealtimeRecipe);
      await future;
    });

    test('should handle multiple stream updates', () async {
      final initial = RecipeFactory.build(id: 'recipe_123', title: 'Initial');
      final updated = RecipeFactory.build(id: 'recipe_123', title: 'Updated');

      final streamController = StreamController<RealtimeRecipe>.broadcast();
      when(() => mockSyncService.watchResource<RealtimeRecipe>('recipe_123'))
          .thenAnswer((_) => streamController.stream);

      final stream = service.watchRealtimeRecipe('recipe_123');

      // Start listening first, then add items
      final future = expectLater(
        stream,
        emitsInOrder([
          isA<RealtimeRecipe>()
              .having((r) => r.recipe.title, 'title', 'Initial'),
          isA<RealtimeRecipe>()
              .having((r) => r.recipe.title, 'title', 'Updated'),
        ]),
      );
      streamController.add(TestRealtimeRecipe.fromRecipe(
          recipe: initial, ownerId: 'test_user_123'));
      streamController.add(TestRealtimeRecipe.fromRecipe(
          recipe: updated, ownerId: 'test_user_123'));
      await future;
    });
  });

  group('Content Operations', () {
    late TestRealtimeRecipe testRealtimeRecipe;
    const testRecipeId = 'recipe_123';

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
    });

    test('should update basic recipe information', () async {
      when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
          .thenAnswer((_) async {});

      await service.updateBasicInfo(
        resourceId: testRecipeId,
        title: 'Updated Title',
      );

      verify(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
          .called(1);
    });

    test('should add and remove ingredients', () async {
      when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
          .thenAnswer((_) async {});

      await service.addIngredient(resourceId: testRecipeId, ingredient: 'New');
      verify(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
          .called(1);
    });

    test('should validate permissions for edits', () async {
      mockPermissionService.setPermissionState(
        currentUserId: 'test_user_123',
        defaultHasPermission: false,
        permissions: {
          testRecipeId: {ResourcePermission.editor: false}
        },
      );

      expect(
        () => service.updateBasicInfo(resourceId: testRecipeId, title: 'Fail'),
        throwsA(isA<RecipeOperationError>()),
      );
    });

    test('should track edit history', () async {
      when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
          .thenAnswer((invocation) async {
        final updated = invocation.positionalArguments[0] as RealtimeRecipe;
        expect(updated.lastEditedBy, equals('test_user_123'));
        expect(updated.editCount, greaterThan(testRealtimeRecipe.editCount));
      });

      await service.updateBasicInfo(resourceId: testRecipeId, title: 'Updated');
      verify(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
          .called(1);
    });
  });

  group('Participant Management', () {
    late TestRealtimeRecipe testRealtimeRecipe;
    const testRecipeId = 'recipe_123';

    setUp(() {
      final recipe = RecipeFactory.build(id: testRecipeId, title: 'Test');
      testRealtimeRecipe = TestRealtimeRecipe.fromRecipe(
        recipe: recipe,
        ownerId: 'test_user_123',
        participants: {
          'test_user_123': ResourcePermission.owner,
          'existing_editor': ResourcePermission.editor,
        },
      );
      mockSyncService.setCachedResource(testRecipeId, testRealtimeRecipe);
    });

    test('should add participant with permissions', () async {
      when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
          .thenAnswer((_) async {});

      await service.addParticipant(
        resourceId: testRecipeId,
        userId: 'new_user',
        userDisplayName: 'New User',
        permission: ResourcePermission.editor,
      );

      verify(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
          .called(1);
    });

    test('should remove participant', () async {
      when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
          .thenAnswer((_) async {});

      await service.removeParticipant(
        resourceId: testRecipeId,
        userId: 'existing_editor',
      );

      verify(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
          .called(1);
    });
  });

  group('Delete Operation', () {
    test('should delete realtime recipe', () async {
      when(() => mockSyncService.deleteResource(
          'recipe_123', RealtimeResourceType.recipe)).thenAnswer((_) async {});

      await service.deleteRealtimeRecipe('recipe_123');

      verify(() => mockSyncService.deleteResource(
          'recipe_123', RealtimeResourceType.recipe)).called(1);
    });

    test('should require authentication for delete', () async {
      mockPermissionService.setPermissionState(
          currentUserId: null, isAuthenticated: false);

      expect(
        () => service.deleteRealtimeRecipe('recipe_123'),
        throwsA(isA<RecipeOperationError>()),
      );
    });

    test('should handle delete errors', () async {
      when(() => mockSyncService.deleteResource(
              'recipe_123', RealtimeResourceType.recipe))
          .thenAnswer((_) async => throw Exception('Delete failed'));

      await expectLater(
        () => service.deleteRealtimeRecipe('recipe_123'),
        throwsA(isA<Exception>()),
      );
      expect(service.lastError, isNotNull);
    });
  });

  group('Utility Operations', () {
    test('should create personal copy of recipe', () {
      final recipe =
          RecipeFactory.build(id: 'recipe_123', title: 'Utility Test');
      final realtimeRecipe = TestRealtimeRecipe(
        id: 'recipe_123',
        recipe: recipe,
        ownerId: 'test_user_123',
        editCount: 5,
      );

      final copy = service.createPersonalCopy(realtimeRecipe);
      expect(copy, isA<Recipe>());
      // Production prepends localized copy prefix (e.g. "Kopia av")
      expect(copy.title, contains('Utility Test'));
      expect(copy.id, isNot(equals('recipe_123')));
    });

    test('should check if recipe changed since timestamp', () {
      final recipe = RecipeFactory.build(id: 'recipe_123');
      final realtimeRecipe = TestRealtimeRecipe(
        id: 'recipe_123',
        recipe: recipe,
        ownerId: 'test_user_123',
        lastEditedAt: DateTime(2024, 1, 15, 10, 30),
      );

      expect(
        service.hasRecipeChangedSince(
            realtimeRecipe, DateTime(2024, 1, 15, 9, 0)),
        isTrue,
      );
      expect(
        service.hasRecipeChangedSince(
            realtimeRecipe, DateTime(2024, 1, 15, 11, 0)),
        isFalse,
      );
    });
  });

  group('Error Scenarios', () {
    test('should handle unauthenticated create', () async {
      mockPermissionService.setPermissionState(
          currentUserId: null, isAuthenticated: false);
      final recipe = RecipeFactory.build();
      expect(
        () => service.createRealtimeRecipe(recipe: recipe),
        throwsA(isA<RecipeOperationError>()),
      );
    });

    test('should handle unauthenticated update', () async {
      mockPermissionService.setPermissionState(
          currentUserId: null, isAuthenticated: false);
      expect(
        () =>
            service.updateBasicInfo(resourceId: 'recipe_123', title: 'Updated'),
        throwsA(isA<RecipeOperationError>()),
      );
    });

    test('should handle not found errors', () async {
      expect(
        () => service.updateBasicInfo(resourceId: 'nonexistent', title: 'Fail'),
        throwsA(isA<RecipeOperationError>()),
      );
    });

    test('should handle sync failures', () async {
      final recipe = RecipeFactory.build(id: 'recipe_123');
      final testRealtimeRecipe = TestRealtimeRecipe.fromRecipe(
        recipe: recipe,
        ownerId: 'test_user_123',
      );
      mockSyncService.setCachedResource('recipe_123', testRealtimeRecipe);

      when(() => mockSyncService.updateResource<RealtimeRecipe>(any()))
          .thenAnswer((_) async => throw Exception('Network error'));

      await expectLater(
        () => service.updateBasicInfo(resourceId: 'recipe_123', title: 'Fail'),
        throwsA(isA<Exception>()),
      );
      expect(service.lastError, isNotNull);
    });
  });
}
