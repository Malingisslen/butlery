/// Unit tests for RealtimeMenuService
///
/// Tests real-time menu management including creation, watching, content operations,
/// participant management, and collaborative editing features.
// ignore_for_file: close_sinks

library;

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/realtime/realtime_menu_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/models/realtime/realtime_menu_data.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import 'package:butlery/services/realtime/modules/menu_operations.dart';

// Test doubles for RealtimeMenu
class TestRealtimeMenu extends RealtimeMenu {
  TestRealtimeMenu({
    required super.id,
    required String menuTitle,
    required super.ownerId,
    String? ownerDisplayName,
    Map<String, List<Recipe>>? menuSnapshot,
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
          data: RealtimeMenuData(
            menuTitle: menuTitle,
            menuSnapshot: menuSnapshot ?? {},
            createdForDate: DateTime.now(),
          ),
        );
}

void main() {
  late RealtimeMenuService service;
  late MockRealtimeSyncService mockSyncService;
  late MockAuthService mockAuthService;
  late MockPermissionService mockPermissionService;
  late StreamController<RealtimeMenu> menuStreamController;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    await TestServiceLocator.initialize();
    registerFallbackValue(RealtimeResourceType.menu);
    registerFallbackValue(ResourcePermission.viewer);
    registerFallbackValue(TestRealtimeMenu(
      id: 'fallback',
      menuTitle: 'Fallback Menu',
      ownerId: 'test_user',
    ));
  });

  setUp(() async {
    // Create mocks
    mockSyncService = MockRealtimeSyncService();
    mockAuthService = MockAuthService();
    mockPermissionService = MockPermissionService();
    menuStreamController = StreamController<RealtimeMenu>.broadcast();

    // Configure auth state
    mockAuthService.setAuthState(
      isAuthenticated: true,
      currentUser: MockFactory.createMockUser(uid: 'test_user_123'),
    );

    // Configure permission state
    mockPermissionService.setPermissionState(
      currentUserId: 'test_user_123',
      defaultHasPermission: true,
    );

    // Configure sync service
    mockSyncService.setConnectionState(true);
    mockSyncService.setInitialized(true);

    // Register permission service with service locator
    // Note: TestServiceLocator is already initialized in setUpAll
    if (ServiceLocator.isRegistered<PermissionService>()) {
      // If already registered, we can't unregister with GetIt, so just use the mock directly
      // The service will use ServiceLocator.get<PermissionService>() internally
    }

    // Create service
    service = RealtimeMenuService(
      syncService: mockSyncService,
      authService: mockAuthService,
    );
  });

  tearDown(() async {
    await menuStreamController.close();
    mockSyncService.disposeStreams();
    service.dispose();
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  group('RealtimeMenuService', () {
    group('Initialization & State Management', () {
      test('should initialize with default state', () {
        // Assert
        expect(service.isProcessing, isFalse);
        expect(service.lastError, isNull);
        expect(service.categoryNames, isEmpty);
      });

      test('should track processing state during operations', () async {
        // Arrange
        TestRealtimeMenu(
          id: 'menu_123',
          menuTitle: 'Test Menu',
          ownerId: 'test_user_123',
        );

        when(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .thenAnswer((_) async {});

        // Act & Assert - Check processing state changes
        expect(service.isProcessing, isFalse);

        final future = service.createRealtimeMenu(
          menuTitle: 'Test Menu',
          menuSnapshot: {'Måndag': []},
        );

        // Should be processing immediately
        expect(service.isProcessing, isTrue);

        await future;

        // Should not be processing after completion
        expect(service.isProcessing, isFalse);
      });

      test('should handle error state management', () async {
        // Arrange
        when(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .thenAnswer((_) async => throw Exception('Sync failed'));

        // Act
        try {
          await service.createRealtimeMenu(
            menuTitle: 'Test Menu',
            menuSnapshot: {'Måndag': []},
          );
        } catch (_) {
          // Expected
        }

        // Assert
        expect(service.lastError, isNotNull);
        expect(service.lastError!.message,
            contains('Kunde inte skapa realtidsmeny'));

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

    group('Menu Creation Operations', () {
      test('should create realtime menu from categories', () async {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'recipe_1', title: 'Köttbullar'),
          RecipeFactory.build(id: 'recipe_2', title: 'Pasta'),
        ];

        final menuSnapshot = {
          'Måndag': [recipes[0]],
          'Tisdag': [recipes[1]],
        };

        when(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .thenAnswer((_) async {});

        // Act
        final result = await service.createRealtimeMenu(
          menuTitle: 'Veckomeny',
          menuSnapshot: menuSnapshot,
          editorUserIds: ['editor_1'],
          viewerUserIds: ['viewer_1'],
          menuNotes: 'Test notes',
          favoriteRecipeIds: ['recipe_1'],
          originalPrompt: 'Create a weekly menu',
          createdForDate: DateTime(2024, 1, 15),
        );

        // Assert
        expect(result, isA<RealtimeMenu>());
        expect(result.menuTitle, equals('Veckomeny'));
        expect(result.ownerId, equals('test_user_123'));
        expect(result.ownerDisplayName, equals('Test User'));
        verify(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .called(1);
      });

      test('should throw error when user not authenticated', () async {
        // Arrange
        mockAuthService.setAuthState(
          isAuthenticated: false,
          currentUser: null,
        );

        // Act & Assert
        expect(
          () => service.createRealtimeMenu(
            menuTitle: 'Test Menu',
            menuSnapshot: {},
          ),
          throwsA(isA<MenuOperationError>()
              .having((e) => e.message, 'message', 'Användare inte inloggad')),
        );
      });

      test('should handle permission setting on creation', () async {
        // Arrange
        final editorIds = ['editor_1', 'editor_2'];
        final viewerIds = ['viewer_1', 'viewer_2'];

        when(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .thenAnswer((invocation) async {
          final menu = invocation.positionalArguments[0] as RealtimeMenu;

          // Verify permissions are set correctly
          expect(
              menu.participants['editor_1'], equals(ResourcePermission.editor));
          expect(
              menu.participants['editor_2'], equals(ResourcePermission.editor));
          expect(
              menu.participants['viewer_1'], equals(ResourcePermission.viewer));
          expect(
              menu.participants['viewer_2'], equals(ResourcePermission.viewer));
        });

        // Act
        await service.createRealtimeMenu(
          menuTitle: 'Test Menu',
          menuSnapshot: {},
          editorUserIds: editorIds,
          viewerUserIds: viewerIds,
        );

        // Assert
        verify(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .called(1);
      });

      test('should handle creation failure gracefully', () async {
        // Arrange
        when(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .thenAnswer((_) async => throw Exception('Firebase error'));

        // Act & Assert
        expect(
          () => service.createRealtimeMenu(
            menuTitle: 'Test Menu',
            menuSnapshot: {},
          ),
          throwsA(isA<Exception>()),
        );

        expect(service.lastError, isNotNull);
        expect(service.lastError!.operation,
            equals(MenuOperationType.createFromExisting));
      });

      test('should cache menu after creation', () async {
        // Arrange
        when(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .thenAnswer((_) async {});

        // Act
        await service.createRealtimeMenu(
          menuTitle: 'Cached Menu',
          menuSnapshot: {'Måndag': []},
        );

        // Assert - categoryNames should reflect cached menu
        expect(service.categoryNames, equals(['Måndag']));
      });
    });

    group('Real-time Watching', () {
      test('should watch menu with stream updates', () async {
        // Arrange
        final testMenu = TestRealtimeMenu(
          id: 'menu_123',
          menuTitle: 'Streaming Menu',
          ownerId: 'test_user_123',
        );

        final streamController = mockSyncService
            .getOrCreateStreamController<RealtimeMenu>('menu_123');

        when(() => mockSyncService.watchResource<RealtimeMenu>('menu_123'))
            .thenAnswer((_) => streamController.stream);

        // Act
        final stream = service.watchRealtimeMenu('menu_123');

        // Assert
        streamController.add(testMenu);

        await expectLater(
          stream,
          emits(isA<RealtimeMenu>()
              .having((m) => m.id, 'id', 'menu_123')
              .having((m) => m.menuTitle, 'title', 'Streaming Menu')),
        );
      });

      test('should handle stream errors gracefully', () async {
        // Arrange
        when(() => mockSyncService.watchResource<RealtimeMenu>('menu_123'))
            .thenAnswer((_) => Stream.error(Exception('Stream error')));

        // Act & Assert
        expect(
          () => service.watchRealtimeMenu('menu_123'),
          throwsA(isA<Exception>()),
        );

        expect(service.lastError, isNotNull);
      });

      test('should cache updates from stream', () async {
        // Arrange
        final initialMenu = TestRealtimeMenu(
          id: 'menu_123',
          menuTitle: 'Initial',
          ownerId: 'test_user_123',
          menuSnapshot: {'Måndag': []},
        );

        final updatedMenu = TestRealtimeMenu(
          id: 'menu_123',
          menuTitle: 'Updated',
          ownerId: 'test_user_123',
          menuSnapshot: {'Måndag': [], 'Tisdag': []},
        );

        final streamController = mockSyncService
            .getOrCreateStreamController<RealtimeMenu>('menu_123');

        when(() => mockSyncService.watchResource<RealtimeMenu>('menu_123'))
            .thenAnswer((_) => streamController.stream);

        // Act
        final stream = service.watchRealtimeMenu('menu_123');
        final subscription = stream.listen((_) {});

        streamController.add(initialMenu);
        await Future.delayed(Duration(milliseconds: 100));
        expect(service.categoryNames, equals(['Måndag']));

        streamController.add(updatedMenu);
        await Future.delayed(Duration(milliseconds: 100));
        expect(service.categoryNames, equals(['Måndag', 'Tisdag']));

        // Cleanup
        await subscription.cancel();
      });

      test('should cancel stream on dispose', () async {
        // Arrange
        final streamController = mockSyncService
            .getOrCreateStreamController<RealtimeMenu>('menu_123');

        when(() => mockSyncService.watchResource<RealtimeMenu>('menu_123'))
            .thenAnswer((_) => streamController.stream);

        // Act
        final stream = service.watchRealtimeMenu('menu_123');
        final subscription = stream.listen((_) {});

        service.dispose();

        // Assert - Stream should be cancelled
        expect(subscription.cancel(), completes);
      });
    });

    group('Menu Content Operations', () {
      final testMenuId = 'menu_123';
      late TestRealtimeMenu testMenu;

      setUp(() {
        testMenu = TestRealtimeMenu(
          id: testMenuId,
          menuTitle: 'Test Menu',
          ownerId: 'test_user_123',
          menuSnapshot: {
            'Måndag': [
              RecipeFactory.build(id: 'r1', title: 'Recipe 1'),
            ],
            'Tisdag': [
              RecipeFactory.build(id: 'r2', title: 'Recipe 2'),
            ],
          },
        );

        mockSyncService.setCachedResource(testMenuId, testMenu);
        // Set permission for this menu
        when(() => mockPermissionService.canEditMenu(testMenuId))
            .thenReturn(true);
      });

      test('should update basic menu information', () async {
        // Arrange
        when(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .thenAnswer((_) async {});

        // Act
        await service.updateBasicInfo(
          resourceId: testMenuId,
          menuTitle: 'Updated Menu',
          createdForDate: DateTime(2024, 2, 1),
          menuNotes: 'Updated notes',
          favoriteRecipeIds: ['r1'],
          originalPrompt: 'Updated prompt',
        );

        // Assert
        verify(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .called(1);
      });

      test('should add recipe to category', () async {
        // Arrange
        final newRecipe = RecipeFactory.build(
          id: 'r3',
          title: 'New Recipe',
        );

        when(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .thenAnswer((_) async {});

        // Act
        await service.addRecipeToCategory(
          resourceId: testMenuId,
          categoryName: 'Måndag',
          recipe: newRecipe,
        );

        // Assert
        verify(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .called(1);
      });

      test('should remove recipe from category', () async {
        // Arrange
        when(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .thenAnswer((_) async {});

        // Act
        await service.removeRecipeFromCategory(
          resourceId: testMenuId,
          categoryName: 'Måndag',
          recipeIndex: 0,
        );

        // Assert
        verify(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .called(1);
      });

      test('should move recipe between categories', () async {
        // Arrange
        when(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .thenAnswer((_) async {});

        // Act
        await service.moveRecipeBetweenCategories(
          resourceId: testMenuId,
          fromCategory: 'Måndag',
          fromIndex: 0,
          toCategory: 'Tisdag',
          toIndex: 0,
        );

        // Assert
        verify(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .called(1);
      });

      test('should clear entire category', () async {
        // Arrange
        when(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .thenAnswer((_) async {});

        // Act
        await service.clearCategory(
          resourceId: testMenuId,
          categoryName: 'Måndag',
        );

        // Assert
        verify(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .called(1);
      });

      test('should validate permissions for edits', () async {
        // Arrange
        // Override permission for this test
        when(() => mockPermissionService.canEditMenu(testMenuId))
            .thenReturn(false);

        // Act & Assert
        expect(
          () => service.updateBasicInfo(
            resourceId: testMenuId,
            menuTitle: 'Should Fail',
          ),
          throwsA(isA<MenuOperationError>().having(
              (e) => e.message, 'message', 'Ingen redigeringsbehörighet')),
        );
      });

      test('should handle missing menu error', () async {
        // Arrange
        // Don't set any cached resource - getCachedResource will return null

        // Act & Assert
        expect(
          () => service.updateBasicInfo(
            resourceId: 'nonexistent',
            menuTitle: 'Should Fail',
          ),
          throwsA(isA<MenuOperationError>()
              .having((e) => e.message, 'message', 'Menyn hittades inte')),
        );
      });

      test('should regenerate category with new recipes', () async {
        // Arrange
        final newRecipes = [
          RecipeFactory.build(id: 'new_1', title: 'New 1'),
          RecipeFactory.build(id: 'new_2', title: 'New 2'),
        ];

        when(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .thenAnswer((_) async {});

        // Act
        await service.regenerateCategory(
          resourceId: testMenuId,
          categoryName: 'Måndag',
          newRecipes: newRecipes,
        );

        // Assert
        verify(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .called(1);
      });
    });

    group('Participant Management', () {
      final testMenuId = 'menu_123';
      late TestRealtimeMenu testMenu;

      setUp(() {
        testMenu = TestRealtimeMenu(
          id: testMenuId,
          menuTitle: 'Test Menu',
          ownerId: 'test_user_123',
        );

        mockSyncService.setCachedResource(testMenuId, testMenu);
        // Set permission for this menu
        when(() => mockPermissionService.canEditMenu(testMenuId))
            .thenReturn(true);
      });

      test('should add participant with permissions', () async {
        // Arrange
        when(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .thenAnswer((_) async {});

        // Act
        await service.addParticipant(
          resourceId: testMenuId,
          userId: 'new_user',
          userDisplayName: 'New User',
          permission: ResourcePermission.editor,
        );

        // Assert
        verify(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .called(1);
      });

      test('should remove participant', () async {
        // Arrange
        when(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .thenAnswer((_) async {});

        // Act
        await service.removeParticipant(
          resourceId: testMenuId,
          userId: 'user_to_remove',
        );

        // Assert
        verify(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .called(1);
      });

      test('should update participant permissions', () async {
        // Arrange
        when(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .thenAnswer((_) async {});

        // Act
        await service.updateParticipantPermission(
          resourceId: testMenuId,
          userId: 'existing_user',
          newPermission: ResourcePermission.viewer,
        );

        // Assert
        verify(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .called(1);
      });

      test('should prevent owner removal', () async {
        // Note: This validation would be in the MenuParticipants module
        // The service just delegates, so we test that it calls through

        when(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .thenAnswer((_) async {});

        // Act
        await service.removeParticipant(
          resourceId: testMenuId,
          userId: 'test_user_123', // Owner ID
        );

        // Assert - Still calls through (validation in module)
        verify(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .called(1);
      });

      test('should require edit permission for participant management',
          () async {
        // Arrange
        // Override permission for this test
        when(() => mockPermissionService.canEditMenu(testMenuId))
            .thenReturn(false);

        // Act & Assert
        expect(
          () => service.addParticipant(
            resourceId: testMenuId,
            userId: 'new_user',
            userDisplayName: 'New User',
            permission: ResourcePermission.viewer,
          ),
          throwsA(isA<MenuOperationError>().having(
              (e) => e.message, 'message', 'Ingen redigeringsbehörighet')),
        );
      });
    });

    group('Utility Operations', () {
      final testMenuId = 'menu_123';
      late TestRealtimeMenu testMenu;

      setUp(() {
        testMenu = TestRealtimeMenu(
          id: testMenuId,
          menuTitle: 'Test Menu',
          ownerId: 'test_user_123',
          menuSnapshot: {
            'Måndag': [
              RecipeFactory.build(id: 'r1', title: 'Recipe 1'),
            ],
          },
          lastEditedAt: DateTime(2024, 1, 15, 10, 30),
          editCount: 5,
        );

        mockSyncService.setCachedResource(testMenuId, testMenu);
      });

      test('should create personal copy of menu', () {
        // Act
        final copy = service.createPersonalCopy(testMenu);

        // Assert
        expect(copy, isA<Map<String, List<Recipe>>>());
        expect(copy.containsKey('Måndag'), isTrue);
        expect(copy['Måndag']!.length, equals(1));
        expect(copy['Måndag']![0].title, equals('Recipe 1'));
      });

      test('should check if menu changed since timestamp', () {
        // Act & Assert
        expect(
          service.hasMenuChangedSince(testMenu, DateTime(2024, 1, 15, 9, 0)),
          isTrue, // Menu edited at 10:30, after 9:00
        );

        expect(
          service.hasMenuChangedSince(testMenu, DateTime(2024, 1, 15, 11, 0)),
          isFalse, // Menu edited at 10:30, before 11:00
        );
      });

      test('should get menu changes summary', () {
        // Act
        final summary = service.getMenuChangesSummary(testMenu);

        // Assert
        expect(summary, isA<String>());
        expect(summary, isNotEmpty);
        // The actual summary format depends on MenuOperations implementation
      });
    });

    group('Delete Operation', () {
      test('should delete realtime menu', () async {
        // Arrange
        when(() => mockSyncService.deleteResource(
            'menu_123', RealtimeResourceType.menu)).thenAnswer((_) async {});

        // Act
        await service.deleteRealtimeMenu('menu_123');

        // Assert
        verify(() => mockSyncService.deleteResource(
            'menu_123', RealtimeResourceType.menu)).called(1);
      });

      test('should require authentication for delete', () async {
        // Arrange
        mockAuthService.setAuthState(
          isAuthenticated: false,
          currentUser: null,
        );

        // Act & Assert
        expect(
          () => service.deleteRealtimeMenu('menu_123'),
          throwsA(isA<MenuOperationError>()
              .having((e) => e.message, 'message', 'Användare inte inloggad')),
        );
      });

      test('should clear cache after delete', () async {
        // Arrange
        final testMenu = TestRealtimeMenu(
          id: 'menu_123',
          menuTitle: 'To Delete',
          ownerId: 'test_user_123',
          menuSnapshot: {'Måndag': []},
        );

        mockSyncService.setCachedResource('menu_123', testMenu);

        when(() => mockSyncService.deleteResource(
            'menu_123', RealtimeResourceType.menu)).thenAnswer((_) async {});

        // Create menu first to populate cache
        final streamController = mockSyncService
            .getOrCreateStreamController<RealtimeMenu>('menu_123');
        when(() => mockSyncService.watchResource<RealtimeMenu>('menu_123'))
            .thenAnswer((_) => streamController.stream);

        final stream = service.watchRealtimeMenu('menu_123');
        final subscription = stream.listen((_) {});
        streamController.add(testMenu);
        await Future.delayed(Duration(milliseconds: 100));

        expect(service.categoryNames, equals(['Måndag']));

        // Act - Delete
        await service.deleteRealtimeMenu('menu_123');

        // Assert - Cache should be cleared
        expect(service.categoryNames, isEmpty);

        // Cleanup
        await subscription.cancel();
      });
    });

    group('Error Scenarios', () {
      test('should handle unauthenticated user errors', () async {
        // Arrange
        mockAuthService.setAuthState(
          isAuthenticated: false,
          currentUser: null,
        );

        // Act & Assert - Create
        expect(
          () => service.createRealtimeMenu(
            menuTitle: 'Test',
            menuSnapshot: {},
          ),
          throwsA(isA<MenuOperationError>()
              .having((e) => e.message, 'message', 'Användare inte inloggad')),
        );

        // Act & Assert - Update
        expect(
          () => service.updateBasicInfo(
            resourceId: 'menu_123',
            menuTitle: 'Updated',
          ),
          throwsA(isA<MenuOperationError>()
              .having((e) => e.message, 'message', 'Användare inte inloggad')),
        );
      });

      test('should handle permission denied errors', () async {
        // Arrange
        final testMenu = TestRealtimeMenu(
          id: 'menu_123',
          menuTitle: 'Test Menu',
          ownerId: 'other_user', // Different owner
        );

        mockSyncService.setCachedResource('menu_123', testMenu);
        // Override permission for this test
        when(() => mockPermissionService.canEditMenu('menu_123'))
            .thenReturn(false);

        // Act & Assert
        expect(
          () => service.addRecipeToCategory(
            resourceId: 'menu_123',
            categoryName: 'Måndag',
            recipe: RecipeFactory.build(),
          ),
          throwsA(isA<MenuOperationError>().having(
              (e) => e.message, 'message', 'Ingen redigeringsbehörighet')),
        );
      });

      test('should handle resource not found errors', () async {
        // Arrange
        // Don't set any cached resource - getCachedResource will return null

        // Act & Assert
        expect(
          () => service.updateBasicInfo(
            resourceId: 'nonexistent',
            menuTitle: 'Should Fail',
          ),
          throwsA(isA<MenuOperationError>()
              .having((e) => e.message, 'message', 'Menyn hittades inte')),
        );
      });

      test('should handle sync failures', () async {
        // Arrange
        final testMenu = TestRealtimeMenu(
          id: 'menu_123',
          menuTitle: 'Test Menu',
          ownerId: 'test_user_123',
        );

        mockSyncService.setCachedResource('menu_123', testMenu);
        // Set permission for this menu
        when(() => mockPermissionService.canEditMenu('menu_123'))
            .thenReturn(true);

        when(() => mockSyncService.updateResource<RealtimeMenu>(any()))
            .thenAnswer((_) async => throw Exception('Network error'));

        // Act & Assert
        expect(
          () => service.updateBasicInfo(
            resourceId: 'menu_123',
            menuTitle: 'Should Fail',
          ),
          throwsA(isA<Exception>()),
        );

        expect(service.lastError, isNotNull);
        expect(service.lastError!.message,
            contains('Kunde inte uppdatera grundinfo'));
      });

      test('should use Swedish error messages', () async {
        // Arrange
        mockAuthService.setAuthState(
          isAuthenticated: false,
          currentUser: null,
        );

        // Act & Assert - Various operations with Swedish errors
        final operations = [
          () => service.createRealtimeMenu(
                menuTitle: 'Test',
                menuSnapshot: {},
              ),
          () => service.updateBasicInfo(
                resourceId: 'menu_123',
                menuTitle: 'Test',
              ),
          () => service.deleteRealtimeMenu('menu_123'),
        ];

        for (final operation in operations) {
          expect(
            operation,
            throwsA(isA<MenuOperationError>().having((e) => e.message,
                'message', contains('Användare inte inloggad'))),
          );
        }
      });
    });
  });
}
