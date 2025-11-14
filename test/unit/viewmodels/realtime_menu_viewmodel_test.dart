import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/realtime_menu_viewmodel.dart';
import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/models/realtime/realtime_menu_data.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/viewmodels/realtime_menu/realtime_menu_state.dart';
import 'package:butlery/services/realtime/modules/menu_operations.dart';
import 'package:butlery/services/realtime/realtime_types.dart' as sync_service;
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../test_support/base_unit_test.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;

// ============= USING CENTRALIZED MOCKS =============
// Removed local mock classes:
// - MockRealtimeMenuService (now in production_mocks.dart)
// - MockRealtimeSyncService (now in production_mocks.dart)
// - MockAuthService (now in production_mocks.dart)

void main() {
  late RealtimeMenuViewModel viewModel;
  late MockRealtimeMenuService mockMenuService;
  late MockRealtimeSyncService mockSyncService;
  late MockAuthService mockAuthService;

  // Test data
  late RealtimeMenu testMenu;
  late Recipe testRecipe1;
  late Recipe testRecipe2;
  late Recipe testRecipe3;

  setUpAll(() {
    registerFallbackValue(ResourcePermission.viewer);
    registerFallbackValue(MenuOperationType.createFromExisting);
    registerFallbackValue(MenuOperationError(
      operation: MenuOperationType.createFromExisting,
      message: 'Test error',
    ));

    // Register fallback for RealtimeMenu
    final fallbackMenuData = RealtimeMenuData(
      menuTitle: 'Fallback Menu',
      createdForDate: DateTime.now(),
      menuSnapshot: const {},
    );

    final fallbackMenu = RealtimeMenu(
      id: 'fallback-menu',
      ownerId: 'fallback-owner',
      ownerDisplayName: 'Fallback Owner',
      participants: const {},
      lastEditedAt: DateTime.now(),
      lastEditedBy: 'fallback-owner',
      lastEditedByDisplayName: 'Fallback Owner',
      data: fallbackMenuData,
    );

    registerFallbackValue(fallbackMenu);
    registerFallbackValue(RecipeFactory.build());
  });

  setUp(() async {
    await BaseUnitTest.setupUnit();
    await TestServiceLocator.initialize();

    // ULTRATHINK FIX: Bridge production ServiceLocator to test mocks
    // This solves "ServiceLocator not initialized" errors when production code
    // calls ServiceLocator.get() but only TestServiceLocator was initialized
    final productionContainer = DIContainer();
    prod_locator.ServiceLocator.initialize(productionContainer);

    // Initialize mocks using centralized versions
    mockMenuService = MockFactory.createRealtimeMenuService();
    mockSyncService = MockFactory.createRealtimeSyncService();
    mockAuthService = MockFactory.createAuthService();

    // Configure auth service state
    mockAuthService.setAuthState(
      currentUser: MockFactory.createMockUser(uid: 'test-user-123'),
      isAuthenticated: true,
    );

    // Create test data
    testRecipe1 = RecipeFactory.build(
      id: 'recipe-1',
      title: 'Tomatsoppa',
      mealType: 'Förrätt',
    );

    testRecipe2 = RecipeFactory.build(
      id: 'recipe-2',
      title: 'Köttbullar',
      mealType: 'Huvudrätt',
    );

    testRecipe3 = RecipeFactory.build(
      id: 'recipe-3',
      title: 'Kladdkaka',
      mealType: 'Efterrätt',
    );

    // Create test menu with data
    final menuData = RealtimeMenuData(
      menuTitle: 'Veckomeny',
      createdForDate: DateTime.now(),
      menuSnapshot: {
        'Förrätt': [testRecipe1],
        'Huvudrätt': [testRecipe2],
        'Efterrätt': [testRecipe3],
      },
      menuNotes: 'Test menu notes',
      favoriteRecipeIds: ['recipe-1'],
      originalPrompt: 'Skapa en veckomeny',
    );

    testMenu = RealtimeMenu(
      id: 'menu-123',
      ownerId: 'test-user-123',
      ownerDisplayName: 'Test User',
      participants: {
        'test-user-123': ResourcePermission.owner,
        'user-456': ResourcePermission.editor,
        'user-789': ResourcePermission.viewer,
      },
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      lastEditedAt: DateTime.now(),
      lastEditedBy: 'test-user-123',
      lastEditedByDisplayName: 'Test User',
      editCount: 5,
      data: menuData,
    );

    // Default stub behaviors
    when(() => mockMenuService.createPersonalCopy(any())).thenReturn({
      'Förrätt': [testRecipe1],
      'Huvudrätt': [testRecipe2],
      'Efterrätt': [testRecipe3],
    });

    when(() => mockMenuService.deleteRealtimeMenu(any()))
        .thenAnswer((_) async {});
    when(() => mockMenuService.updateBasicInfo(
          resourceId: any(named: 'resourceId'),
          menuTitle: any(named: 'menuTitle'),
          createdForDate: any(named: 'createdForDate'),
          menuNotes: any(named: 'menuNotes'),
          originalPrompt: any(named: 'originalPrompt'),
          favoriteRecipeIds: any(named: 'favoriteRecipeIds'),
        )).thenAnswer((_) async {});

    // Create viewModel
    viewModel = RealtimeMenuViewModel(
      menuService: mockMenuService,
      syncService: mockSyncService,
      authService: mockAuthService,
    );
  });

  tearDown(() async {
    viewModel.dispose();
    mockSyncService.disposeStreams();
    mockMenuService.dispose();
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  group('Initialization & Lifecycle', () {
    test('should initialize with correct default state', () {
      expect(viewModel.currentMenu, isNull);
      expect(viewModel.status, equals(RealtimeMenuStatus.idle));
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.selectedCategory, isNull);
      expect(viewModel.showParticipants, isFalse);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.hasUnsavedChanges, isFalse);
      expect(viewModel.categories, isEmpty);
    });

    test('should set up service listener on initialization', () {
      mockMenuService.setError(MenuOperationError(
        operation: MenuOperationType.createFromExisting,
        message: 'Test error',
      ));

      expect(viewModel.errorMessage, contains('Test error'));
    });

    test('should handle connection status correctly', () {
      expect(viewModel.isOnline, isTrue);
      expect(viewModel.connectionStatusDescription, isNotEmpty);
      expect(viewModel.connectionStatusEmoji, isNotEmpty);

      mockSyncService.setConnectionState(false);
      expect(viewModel.isOnline, isFalse);
    });

    test('should provide current user ID from auth service', () {
      expect(viewModel.currentUserId, equals('test-user-123'));

      mockAuthService.setAuthState(
          currentUser: MockFactory.createMockUser(uid: 'different-user'));
      expect(viewModel.currentUserId, equals('different-user'));
    });

    test('should dispose resources properly', () {
      expect(() => viewModel.dispose(), returnsNormally);

      // Create new viewModel for disposal test
      final testViewModel = RealtimeMenuViewModel(
        menuService: mockMenuService,
        syncService: mockSyncService,
        authService: mockAuthService,
      );

      expect(() => testViewModel.dispose(), returnsNormally);
    });
  });

  group('Stream Management', () {
    test('should start watching menu successfully', () async {
      await viewModel.startWatching('menu-123');

      expect(viewModel.status, equals(RealtimeMenuStatus.loading));

      // Emit menu data
      mockSyncService.emitMenu(testMenu);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(viewModel.currentMenu, isNotNull);
      expect(viewModel.currentMenu?.id, equals('menu-123'));
      expect(viewModel.status, equals(RealtimeMenuStatus.watching));
    });

    test('should handle stream errors gracefully', () async {
      await viewModel.startWatching('menu-123');

      mockSyncService.emitError(sync_service.SyncError(
        type: sync_service.SyncErrorType.connectionLost,
        message: 'Connection lost',
      ));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(viewModel.status, equals(RealtimeMenuStatus.error));
      expect(viewModel.errorMessage, contains('Real-time fel'));
    });

    test('should stop watching and reset state', () async {
      await viewModel.startWatching('menu-123');
      mockSyncService.emitMenu(testMenu);
      await Future.delayed(const Duration(milliseconds: 100));

      await viewModel.stopWatching();

      expect(viewModel.currentMenu, isNull);
      expect(viewModel.status, equals(RealtimeMenuStatus.idle));
    });

    test('should handle menu updates in real-time', () async {
      await viewModel.startWatching('menu-123');

      // First emission
      mockSyncService.emitMenu(testMenu);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(viewModel.currentMenu?.menuTitle, equals('Veckomeny'));

      // Update menu
      final updatedMenuData = RealtimeMenuData(
        menuTitle: 'Uppdaterad Meny',
        createdForDate: DateTime.now(),
        menuSnapshot: testMenu.menuSnapshot,
      );

      final updatedMenu = RealtimeMenu(
        id: 'menu-123',
        ownerId: 'test-user-123',
        ownerDisplayName: 'Test User',
        participants: testMenu.participants,
        lastEditedAt: DateTime.now(),
        lastEditedBy: 'test-user-123',
        lastEditedByDisplayName: 'Test User',
        data: updatedMenuData,
      );

      mockSyncService.emitMenu(updatedMenu);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(viewModel.currentMenu?.menuTitle, equals('Uppdaterad Meny'));
    });

    test('should clear optimistic changes when real update arrives', () async {
      await viewModel.startWatching('menu-123');
      mockSyncService.emitMenu(testMenu);
      await Future.delayed(const Duration(milliseconds: 100));

      // Should clear any optimistic changes (internal state)
      expect(viewModel.hasUnsavedChanges, isFalse);
    });
  });

  group('Recipe Operations', () {
    setUp(() async {
      // Set up menu in watching state
      await viewModel.startWatching('menu-123');
      mockSyncService.emitMenu(testMenu);
      await Future.delayed(const Duration(milliseconds: 100));

      // Stub recipe operations
      when(() => mockMenuService.addRecipeToCategory(
            resourceId: any(named: 'resourceId'),
            categoryName: any(named: 'categoryName'),
            recipe: any(named: 'recipe'),
          )).thenAnswer((_) async {});

      when(() => mockMenuService.removeRecipeFromCategory(
            resourceId: any(named: 'resourceId'),
            categoryName: any(named: 'categoryName'),
            recipeIndex: any(named: 'recipeIndex'),
          )).thenAnswer((_) async {});

      when(() => mockMenuService.moveRecipeBetweenCategories(
            resourceId: any(named: 'resourceId'),
            fromCategory: any(named: 'fromCategory'),
            fromIndex: any(named: 'fromIndex'),
            toCategory: any(named: 'toCategory'),
            toIndex: any(named: 'toIndex'),
          )).thenAnswer((_) async {});

      when(() => mockMenuService.clearCategory(
            resourceId: any(named: 'resourceId'),
            categoryName: any(named: 'categoryName'),
          )).thenAnswer((_) async {});

      when(() => mockMenuService.regenerateCategory(
            resourceId: any(named: 'resourceId'),
            categoryName: any(named: 'categoryName'),
            newRecipes: any(named: 'newRecipes'),
          )).thenAnswer((_) async {});
    });

    test('should add recipe to category', () async {
      final newRecipe = RecipeFactory.build(
        id: 'new-recipe',
        title: 'Caesarsallad',
        mealType: 'Förrätt',
      );

      await viewModel.addRecipeToCategory(
        categoryName: 'Förrätt',
        recipe: newRecipe,
      );

      verify(() => mockMenuService.addRecipeToCategory(
            resourceId: 'menu-123',
            categoryName: 'Förrätt',
            recipe: newRecipe,
          )).called(1);
    });

    test('should remove recipe from category', () async {
      await viewModel.removeRecipeFromCategory(
        categoryName: 'Huvudrätt',
        recipeIndex: 0,
      );

      verify(() => mockMenuService.removeRecipeFromCategory(
            resourceId: 'menu-123',
            categoryName: 'Huvudrätt',
            recipeIndex: 0,
          )).called(1);
    });

    test('should move recipe between categories', () async {
      await viewModel.moveRecipeBetweenCategories(
        fromCategory: 'Förrätt',
        fromIndex: 0,
        toCategory: 'Huvudrätt',
        toIndex: 1,
      );

      verify(() => mockMenuService.moveRecipeBetweenCategories(
            resourceId: 'menu-123',
            fromCategory: 'Förrätt',
            fromIndex: 0,
            toCategory: 'Huvudrätt',
            toIndex: 1,
          )).called(1);
    });

    test('should reorder recipe within category', () async {
      // Add multiple recipes to test reordering
      final menuData = RealtimeMenuData(
        menuTitle: 'Test Menu',
        createdForDate: DateTime.now(),
        menuSnapshot: {
          'Huvudrätt': [testRecipe1, testRecipe2, testRecipe3],
        },
      );

      final menuWithMultipleRecipes = RealtimeMenu(
        id: 'menu-123',
        ownerId: 'test-user-123',
        ownerDisplayName: 'Test User',
        participants: testMenu.participants,
        lastEditedAt: DateTime.now(),
        lastEditedBy: 'test-user-123',
        lastEditedByDisplayName: 'Test User',
        data: menuData,
      );

      mockSyncService.emitMenu(menuWithMultipleRecipes);
      await Future.delayed(const Duration(milliseconds: 100));

      await viewModel.reorderRecipeInCategory(
        categoryName: 'Huvudrätt',
        fromIndex: 0,
        toIndex: 2,
      );

      verify(() => mockMenuService.moveRecipeBetweenCategories(
            resourceId: 'menu-123',
            fromCategory: 'Huvudrätt',
            fromIndex: 0,
            toCategory: 'Huvudrätt',
            toIndex: 2,
          )).called(1);
    });

    test('should clear category', () async {
      await viewModel.clearCategory('Efterrätt');

      verify(() => mockMenuService.clearCategory(
            resourceId: 'menu-123',
            categoryName: 'Efterrätt',
          )).called(1);
    });

    test('should regenerate category', () async {
      await viewModel.regenerateCategory('Huvudrätt');

      expect(viewModel.status, equals(RealtimeMenuStatus.watching));
    });

    test('should not perform operations without menu', () async {
      // Clear menu state
      await viewModel.stopWatching();

      await viewModel.addRecipeToCategory(
        categoryName: 'Förrätt',
        recipe: testRecipe1,
      );

      expect(viewModel.errorMessage, equals('Ingen meny laddad'));
      verifyNever(() => mockMenuService.addRecipeToCategory(
            resourceId: any(named: 'resourceId'),
            categoryName: any(named: 'categoryName'),
            recipe: any(named: 'recipe'),
          ));
    });

    test('should not perform operations without edit permission', () async {
      // Create menu where current user is only viewer
      final viewerMenu = RealtimeMenu(
        id: 'menu-123',
        ownerId: 'other-user',
        ownerDisplayName: 'Other User',
        participants: {
          'other-user': ResourcePermission.owner,
          'test-user-123': ResourcePermission.viewer,
        },
        lastEditedAt: DateTime.now(),
        lastEditedBy: 'other-user',
        lastEditedByDisplayName: 'Other User',
        data: testMenu.menuSnapshot as RealtimeMenuData,
      );

      mockSyncService.emitMenu(viewerMenu);
      await Future.delayed(const Duration(milliseconds: 100));

      await viewModel.addRecipeToCategory(
        categoryName: 'Förrätt',
        recipe: testRecipe1,
      );

      expect(viewModel.errorMessage, equals('Ingen redigeringsbehörighet'));
    });

    test('should not perform operations when offline', () async {
      mockSyncService.setConnectionState(false);

      await viewModel.addRecipeToCategory(
        categoryName: 'Förrätt',
        recipe: testRecipe1,
      );

      expect(viewModel.errorMessage, equals('Ingen internetanslutning'));
    });
  });

  group('Participant Management', () {
    setUp(() async {
      await viewModel.startWatching('menu-123');
      mockSyncService.emitMenu(testMenu);
      await Future.delayed(const Duration(milliseconds: 100));

      when(() => mockMenuService.addParticipant(
            resourceId: any(named: 'resourceId'),
            userId: any(named: 'userId'),
            userDisplayName: any(named: 'userDisplayName'),
            permission: any(named: 'permission'),
          )).thenAnswer((_) async {});

      when(() => mockMenuService.removeParticipant(
            resourceId: any(named: 'resourceId'),
            userId: any(named: 'userId'),
          )).thenAnswer((_) async {});
    });

    test('should add participant with permission', () async {
      await viewModel.addParticipant(
        userId: 'new-user',
        userDisplayName: 'New User',
        permission: ResourcePermission.editor,
      );

      verify(() => mockMenuService.addParticipant(
            resourceId: 'menu-123',
            userId: 'new-user',
            userDisplayName: 'New User',
            permission: ResourcePermission.editor,
          )).called(1);
    });

    test('should remove participant', () async {
      await viewModel.removeParticipant('user-789');

      verify(() => mockMenuService.removeParticipant(
            resourceId: 'menu-123',
            userId: 'user-789',
          )).called(1);
    });

    test('should track active participant count', () {
      expect(viewModel.activeParticipantCount, greaterThanOrEqualTo(0));
    });

    test('should provide participant activities', () {
      expect(viewModel.participantActivities, isNotNull);
      expect(viewModel.participantActivities, isList);
    });

    test('should track online participants', () {
      expect(viewModel.onlineParticipants, isNotNull);
      expect(viewModel.onlineParticipants, isList);
    });

    test('should not add participant without menu', () async {
      await viewModel.stopWatching();

      await viewModel.addParticipant(
        userId: 'new-user',
        userDisplayName: 'New User',
        permission: ResourcePermission.editor,
      );

      expect(viewModel.errorMessage, equals('Ingen meny laddad'));
    });
  });

  group('State Management', () {
    setUp(() async {
      await viewModel.startWatching('menu-123');
      mockSyncService.emitMenu(testMenu);
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('should select category', () {
      viewModel.selectCategory('Huvudrätt');
      expect(viewModel.selectedCategory, equals('Huvudrätt'));

      viewModel.selectCategory(null);
      expect(viewModel.selectedCategory, isNull);
    });

    test('should get recipes for selected category', () {
      viewModel.selectCategory('Huvudrätt');
      final recipes = viewModel.selectedCategoryRecipes;

      expect(recipes, isNotEmpty);
      expect(recipes.first.title, equals('Köttbullar'));
    });

    test('should toggle participants panel', () {
      expect(viewModel.showParticipants, isFalse);

      viewModel.toggleParticipants();
      expect(viewModel.showParticipants, isTrue);

      viewModel.toggleParticipants();
      expect(viewModel.showParticipants, isFalse);
    });

    test('should clear error state', () {
      // Set error through failed operation
      mockAuthService.setAuthState(currentUser: null);
      viewModel.selectCategory('Test');

      // Clear error
      viewModel.clearError();
      expect(viewModel.errorMessage, isNull);
    });

    test('should refresh connection status', () {
      expect(() => viewModel.refreshConnection(), returnsNormally);
    });

    test('should provide menu with optimistic changes', () {
      final menuWithChanges = viewModel.menuWithOptimisticChanges;
      expect(menuWithChanges, isNotNull);
      expect(menuWithChanges, isMap);
    });

    test('should track loading state during operations', () {
      expect(viewModel.isLoading, isFalse);
      // Loading state is set during async operations
    });
  });

  group('Connection Handling', () {
    setUp(() async {
      await viewModel.startWatching('menu-123');
      mockSyncService.emitMenu(testMenu);
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('should transition to offline state when connection lost', () async {
      expect(viewModel.status, equals(RealtimeMenuStatus.watching));

      mockSyncService.setConnectionState(false);
      // Trigger connection change through internal mechanism
      await Future.delayed(const Duration(milliseconds: 100));

      // Status should indicate offline state
      expect(viewModel.isOnline, isFalse);
    });

    test('should recover from offline state when connection restored',
        () async {
      mockSyncService.setConnectionState(false);
      await Future.delayed(const Duration(milliseconds: 100));

      mockSyncService.setConnectionState(true);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(viewModel.isOnline, isTrue);
    });

    test('should provide connection status description', () {
      expect(viewModel.connectionStatusDescription, isNotEmpty);

      mockSyncService.setConnectionState(false);
      expect(viewModel.connectionStatusDescription, isNotEmpty);
    });

    test('should provide connection status emoji', () {
      expect(viewModel.connectionStatusEmoji, isNotEmpty);

      mockSyncService.setConnectionState(false);
      expect(viewModel.connectionStatusEmoji, isNotEmpty);
    });
  });

  group('UI State & Permissions', () {
    test('should check edit permission correctly', () async {
      await viewModel.startWatching('menu-123');
      mockSyncService.emitMenu(testMenu);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(viewModel.canEdit, isTrue);

      // Switch to viewer-only menu
      final viewerMenu = RealtimeMenu(
        id: 'menu-456',
        ownerId: 'other-user',
        ownerDisplayName: 'Other User',
        participants: {
          'other-user': ResourcePermission.owner,
          'test-user-123': ResourcePermission.viewer,
        },
        lastEditedAt: DateTime.now(),
        lastEditedBy: 'other-user',
        lastEditedByDisplayName: 'Other User',
        data: testMenu.menuSnapshot as RealtimeMenuData,
      );

      mockSyncService.emitMenu(viewerMenu);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(viewModel.canEdit, isFalse);
    });

    test('should check participant management permission', () async {
      await viewModel.startWatching('menu-123');
      mockSyncService.emitMenu(testMenu);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(viewModel.canManageParticipants, isTrue);

      // Non-owner cannot manage participants
      mockAuthService.setAuthState(
          currentUser: MockFactory.createMockUser(uid: 'user-456'));
      expect(viewModel.canManageParticipants, isFalse);
    });

    test('should provide available categories', () async {
      await viewModel.startWatching('menu-123');
      mockSyncService.emitMenu(testMenu);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(viewModel.categories, isNotEmpty);
      expect(viewModel.categories, contains('Förrätt'));
      expect(viewModel.categories, contains('Huvudrätt'));
      expect(viewModel.categories, contains('Efterrätt'));
    });

    test('should track unsaved changes', () {
      // Initially no unsaved changes
      expect(viewModel.hasUnsavedChanges, isFalse);

      // Optimistic updates would set this to true
      // This is managed internally by the operations module
    });
  });

  group('Utility Methods', () {
    setUp(() async {
      await viewModel.startWatching('menu-123');
      mockSyncService.emitMenu(testMenu);
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('should create personal copy of menu', () {
      final personalCopy = viewModel.createPersonalCopy();

      expect(personalCopy, isNotNull);
      expect(personalCopy, isMap);
      expect(personalCopy!['Förrätt'], isNotEmpty);
      expect(personalCopy['Huvudrätt'], isNotEmpty);
      expect(personalCopy['Efterrätt'], isNotEmpty);
    });

    test('should return null personal copy without menu', () async {
      await viewModel.stopWatching();

      final personalCopy = viewModel.createPersonalCopy();
      expect(personalCopy, isNull);
    });

    test('should delete menu if owner', () async {
      await viewModel.deleteMenu();

      verify(() => mockMenuService.deleteRealtimeMenu('menu-123')).called(1);
    });

    test('should not delete menu if not owner', () async {
      // Switch to non-owner user
      mockAuthService.setAuthState(
          currentUser: MockFactory.createMockUser(uid: 'user-456'));

      await viewModel.deleteMenu();

      verifyNever(() => mockMenuService.deleteRealtimeMenu(any()));
    });

    test('should update basic menu info', () async {
      await viewModel.updateBasicInfo(
        menuTitle: 'Ny Veckomeny',
        createdForDate: DateTime.now().add(const Duration(days: 7)),
        menuNotes: 'Uppdaterade anteckningar',
        originalPrompt: 'Ny prompt',
      );

      verify(() => mockMenuService.updateBasicInfo(
            resourceId: 'menu-123',
            menuTitle: 'Ny Veckomeny',
            createdForDate: any(named: 'createdForDate'),
            menuNotes: 'Uppdaterade anteckningar',
            originalPrompt: 'Ny prompt',
          )).called(1);
    });
  });

  group('Edge Cases & Error Scenarios', () {
    test('should handle null current user gracefully', () async {
      mockAuthService.setAuthState(currentUser: null);

      await viewModel.startWatching('menu-123');
      mockSyncService.emitMenu(testMenu);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(viewModel.currentUserId, isNull);
      expect(viewModel.canEdit, isFalse);
    });

    test('should handle service errors gracefully', () async {
      when(() => mockMenuService.addRecipeToCategory(
            resourceId: any(named: 'resourceId'),
            categoryName: any(named: 'categoryName'),
            recipe: any(named: 'recipe'),
          )).thenThrow(Exception('Service error'));

      await viewModel.startWatching('menu-123');
      mockSyncService.emitMenu(testMenu);
      await Future.delayed(const Duration(milliseconds: 100));

      await viewModel.addRecipeToCategory(
        categoryName: 'Förrätt',
        recipe: testRecipe1,
      );

      expect(viewModel.errorMessage, contains('Kunde inte lägga till recept'));
    });

    test('should handle concurrent operations safely', () async {
      await viewModel.startWatching('menu-123');
      mockSyncService.emitMenu(testMenu);
      await Future.delayed(const Duration(milliseconds: 100));

      // Start multiple operations concurrently
      final futures = [
        viewModel.addRecipeToCategory(
          categoryName: 'Förrätt',
          recipe: testRecipe1,
        ),
        viewModel.removeRecipeFromCategory(
          categoryName: 'Huvudrätt',
          recipeIndex: 0,
        ),
        viewModel.clearCategory('Efterrätt'),
      ];

      await Future.wait(futures);

      // All operations should complete without error
      verify(() => mockMenuService.addRecipeToCategory(
            resourceId: any(named: 'resourceId'),
            categoryName: any(named: 'categoryName'),
            recipe: any(named: 'recipe'),
          )).called(1);

      verify(() => mockMenuService.removeRecipeFromCategory(
            resourceId: any(named: 'resourceId'),
            categoryName: any(named: 'categoryName'),
            recipeIndex: any(named: 'recipeIndex'),
          )).called(1);

      verify(() => mockMenuService.clearCategory(
            resourceId: any(named: 'resourceId'),
            categoryName: any(named: 'categoryName'),
          )).called(1);
    });

    test('should handle empty menu categories', () async {
      final emptyMenu = RealtimeMenu(
        id: 'empty-menu',
        ownerId: 'test-user-123',
        ownerDisplayName: 'Test User',
        participants: testMenu.participants,
        lastEditedAt: DateTime.now(),
        lastEditedBy: 'test-user-123',
        lastEditedByDisplayName: 'Test User',
        data: RealtimeMenuData(
          menuTitle: 'Tom Meny',
          createdForDate: DateTime.now(),
          menuSnapshot: const {},
        ),
      );

      await viewModel.startWatching('empty-menu');
      mockSyncService.emitMenu(emptyMenu);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(viewModel.currentMenu, isNotNull);
      expect(viewModel.categories, isEmpty);
      expect(viewModel.selectedCategoryRecipes, isEmpty);
    });

    test('should handle rapid state transitions', () async {
      // Start watching
      await viewModel.startWatching('menu-123');

      // Quickly emit multiple states
      mockSyncService.emitMenu(testMenu);
      mockSyncService.emitError(sync_service.SyncError(
        type: sync_service.SyncErrorType.connectionLost,
        message: 'Error',
      ));
      mockSyncService.emitMenu(testMenu);

      await Future.delayed(const Duration(milliseconds: 200));

      // Should end in stable state
      expect(viewModel.currentMenu, isNotNull);
    });

    test('should handle permission changes during session', () async {
      await viewModel.startWatching('menu-123');
      mockSyncService.emitMenu(testMenu);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(viewModel.canEdit, isTrue);

      // Update menu with changed permissions
      final updatedMenu = RealtimeMenu(
        id: 'menu-123',
        ownerId: 'test-user-123',
        ownerDisplayName: 'Test User',
        participants: {
          'test-user-123': ResourcePermission.viewer, // Downgraded
          'user-456': ResourcePermission.owner,
        },
        lastEditedAt: DateTime.now(),
        lastEditedBy: 'user-456',
        lastEditedByDisplayName: 'Other User',
        data: testMenu.menuSnapshot as RealtimeMenuData,
      );

      mockSyncService.emitMenu(updatedMenu);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(viewModel.canEdit, isFalse);
    });
  });

  group('Swedish Localization', () {
    test('should use Swedish error messages', () async {
      await viewModel.startWatching('menu-123');
      mockSyncService.emitMenu(testMenu);
      await Future.delayed(const Duration(milliseconds: 100));

      // Test various error conditions with Swedish messages
      await viewModel.stopWatching();
      await viewModel.addRecipeToCategory(
        categoryName: 'Test',
        recipe: testRecipe1,
      );
      expect(viewModel.errorMessage, equals('Ingen meny laddad'));

      await viewModel.startWatching('menu-123');
      final viewerMenu = RealtimeMenu(
        id: 'menu-123',
        ownerId: 'other-user',
        ownerDisplayName: 'Other User',
        participants: {
          'other-user': ResourcePermission.owner,
          'test-user-123': ResourcePermission.viewer,
        },
        lastEditedAt: DateTime.now(),
        lastEditedBy: 'other-user',
        lastEditedByDisplayName: 'Other User',
        data: testMenu.menuSnapshot as RealtimeMenuData,
      );
      mockSyncService.emitMenu(viewerMenu);
      await Future.delayed(const Duration(milliseconds: 100));

      await viewModel.addRecipeToCategory(
        categoryName: 'Test',
        recipe: testRecipe1,
      );
      expect(viewModel.errorMessage, equals('Ingen redigeringsbehörighet'));

      mockSyncService.setConnectionState(false);
      await viewModel.addRecipeToCategory(
        categoryName: 'Test',
        recipe: testRecipe1,
      );
      expect(viewModel.errorMessage, equals('Ingen internetanslutning'));
    });

    test('should use Swedish category names', () async {
      await viewModel.startWatching('menu-123');
      mockSyncService.emitMenu(testMenu);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(viewModel.categories, contains('Förrätt'));
      expect(viewModel.categories, contains('Huvudrätt'));
      expect(viewModel.categories, contains('Efterrätt'));
    });
  });

  group('Performance & Optimization', () {
    test('should handle large menu efficiently', () async {
      // Create menu with many recipes
      final largeMenuSnapshot = <String, List<Recipe>>{};
      for (int i = 0; i < 10; i++) {
        final categoryRecipes = <Recipe>[];
        for (int j = 0; j < 20; j++) {
          categoryRecipes.add(RecipeFactory.build(
            id: 'recipe-$i-$j',
            title: 'Recipe $i-$j',
            mealType: 'Category $i',
          ));
        }
        largeMenuSnapshot['Category $i'] = categoryRecipes;
      }

      final largeMenu = RealtimeMenu(
        id: 'large-menu',
        ownerId: 'test-user-123',
        ownerDisplayName: 'Test User',
        participants: testMenu.participants,
        lastEditedAt: DateTime.now(),
        lastEditedBy: 'test-user-123',
        lastEditedByDisplayName: 'Test User',
        data: RealtimeMenuData(
          menuTitle: 'Large Menu',
          createdForDate: DateTime.now(),
          menuSnapshot: largeMenuSnapshot,
        ),
      );

      await viewModel.startWatching('large-menu');
      mockSyncService.emitMenu(largeMenu);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(viewModel.currentMenu, isNotNull);
      expect(viewModel.categories.length, equals(10));

      // Select category should work efficiently
      viewModel.selectCategory('Category 5');
      expect(viewModel.selectedCategoryRecipes.length, equals(20));
    });

    test('should debounce rapid updates', () async {
      await viewModel.startWatching('menu-123');

      // Emit multiple updates rapidly
      for (int i = 0; i < 10; i++) {
        final updatedMenu = RealtimeMenu(
          id: 'menu-123',
          ownerId: 'test-user-123',
          ownerDisplayName: 'Test User',
          participants: testMenu.participants,
          lastEditedAt: DateTime.now(),
          lastEditedBy: 'test-user-123',
          lastEditedByDisplayName: 'Test User',
          editCount: i,
          data: testMenu.menuSnapshot as RealtimeMenuData,
        );
        mockSyncService.emitMenu(updatedMenu);
      }

      await Future.delayed(const Duration(milliseconds: 200));

      // Should handle all updates without issues
      expect(viewModel.currentMenu, isNotNull);
      expect(viewModel.status, equals(RealtimeMenuStatus.watching));
    });
  });
}
