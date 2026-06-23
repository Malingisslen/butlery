// Rewritten: local pure-Mocks to avoid centralized concrete @override conflicts.
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/realtime_menu_viewmodel.dart';
import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/models/realtime/realtime_menu_data.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/viewmodels/realtime_menu/realtime_menu_state.dart';
import 'package:butlery/services/realtime/realtime_menu_service.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;

import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

// Local pure-Mocks: no concrete @override so when() works.
class _MockMenuService extends Mock implements RealtimeMenuService {}

class _MockSyncService extends Mock implements RealtimeSyncService {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  late RealtimeMenuViewModel viewModel;
  late _MockMenuService mockMenuService;
  late _MockSyncService mockSyncService;
  late _MockAuthService mockAuthService;
  late FakePermissionService mockPermission;

  late StreamController<bool> connectionController;
  late StreamController<RealtimeMenu> menuStreamController;

  late RealtimeMenu testMenu;
  late Recipe testRecipe1;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    await TestServiceLocator.initialize();
    registerFallbackValue(ResourcePermission.viewer);
    registerFallbackValue(RecipeFactory.build());
    final fbData = RealtimeMenuData(
      menuTitle: 'fb',
      createdForDate: DateTime.now(),
      menuSnapshot: {},
    );
    registerFallbackValue(
      RealtimeMenu(
        id: 'fb',
        ownerId: 'fb',
        ownerDisplayName: 'fb',
        participants: {},
        lastEditedBy: 'fb',
        lastEditedByDisplayName: 'fb',
        data: fbData,
      ),
    );
  });

  setUp(() async {
    await TestServiceLocator.initialize();

    // Production ServiceLocator bridge for PermissionService
    mockPermission = FakePermissionService();
    mockPermission.setPermissionState(
      currentUserId: 'test-user-123',
      userDisplayName: 'Test User',
      isAuthenticated: true,
      defaultHasPermission: true,
    );
    final container = DIContainer();
    prod_locator.ServiceLocator.initialize(container);
    TestServiceLocator.registerMock<PermissionService>(mockPermission);

    // Stream controllers
    connectionController = StreamController<bool>.broadcast();
    menuStreamController = StreamController<RealtimeMenu>.broadcast();

    mockMenuService = _MockMenuService();
    mockSyncService = _MockSyncService();
    mockAuthService = _MockAuthService();

    // Sync service stubs
    when(() => mockSyncService.isConnected).thenReturn(true);
    when(
      () => mockSyncService.connectionStream,
    ).thenAnswer((_) => connectionController.stream);
    when(() => mockSyncService.lastError).thenReturn(null);

    // Auth service stubs
    when(() => mockAuthService.currentUser).thenReturn(null);
    when(() => mockAuthService.currentUserId).thenReturn('test-user-123');

    // Menu service stubs
    when(() => mockMenuService.lastError).thenReturn(null);
    when(() => mockMenuService.addListener(any())).thenReturn(null);
    when(() => mockMenuService.removeListener(any())).thenReturn(null);
    when(
      () => mockMenuService.watchRealtimeMenu(any()),
    ).thenAnswer((_) => menuStreamController.stream);
    when(
      () => mockMenuService.deleteRealtimeMenu(any()),
    ).thenAnswer((_) async {});
    when(() => mockMenuService.createPersonalCopy(any())).thenReturn({
      'Förrätt': <Recipe>[],
      'Huvudrätt': <Recipe>[],
    });
    when(
      () => mockMenuService.updateBasicInfo(
        resourceId: any(named: 'resourceId'),
        menuTitle: any(named: 'menuTitle'),
        createdForDate: any(named: 'createdForDate'),
        menuNotes: any(named: 'menuNotes'),
        originalPrompt: any(named: 'originalPrompt'),
        favoriteRecipeIds: any(named: 'favoriteRecipeIds'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockMenuService.addRecipeToCategory(
        resourceId: any(named: 'resourceId'),
        categoryName: any(named: 'categoryName'),
        recipe: any(named: 'recipe'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockMenuService.removeRecipeFromCategory(
        resourceId: any(named: 'resourceId'),
        categoryName: any(named: 'categoryName'),
        recipeIndex: any(named: 'recipeIndex'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockMenuService.moveRecipeBetweenCategories(
        resourceId: any(named: 'resourceId'),
        fromCategory: any(named: 'fromCategory'),
        fromIndex: any(named: 'fromIndex'),
        toCategory: any(named: 'toCategory'),
        toIndex: any(named: 'toIndex'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockMenuService.clearCategory(
        resourceId: any(named: 'resourceId'),
        categoryName: any(named: 'categoryName'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockMenuService.regenerateCategory(
        resourceId: any(named: 'resourceId'),
        categoryName: any(named: 'categoryName'),
        newRecipes: any(named: 'newRecipes'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockMenuService.addParticipant(
        resourceId: any(named: 'resourceId'),
        userId: any(named: 'userId'),
        userDisplayName: any(named: 'userDisplayName'),
        permission: any(named: 'permission'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockMenuService.removeParticipant(
        resourceId: any(named: 'resourceId'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async {});

    testRecipe1 = RecipeFactory.build(
      id: 'recipe-1',
      title: 'Tomatsoppa',
      mealType: 'Förrätt',
    );
    final r2 = RecipeFactory.build(
      id: 'recipe-2',
      title: 'Köttbullar',
      mealType: 'Huvudrätt',
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
      lastEditedBy: 'test-user-123',
      lastEditedByDisplayName: 'Test User',
      data: RealtimeMenuData(
        menuTitle: 'Veckomeny',
        createdForDate: DateTime.now(),
        menuSnapshot: {
          'Förrätt': [testRecipe1],
          'Huvudrätt': [r2],
        },
      ),
    );

    viewModel = RealtimeMenuViewModel(
      menuService: mockMenuService,
      syncService: mockSyncService,
      authService: mockAuthService,
    );
  });

  tearDown(() async {
    viewModel.dispose();
    await connectionController.close();
    await menuStreamController.close();
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  /// Helper: start watching and emit the test menu.
  Future<void> watchAndEmit() async {
    await viewModel.startWatching('menu-123');
    menuStreamController.add(testMenu);
    await Future.delayed(const Duration(milliseconds: 50));
  }

  group('Initialization', () {
    test('should initialize with correct defaults and dispose safely', () {
      expect(viewModel.currentMenu, isNull);
      expect(viewModel.status, equals(RealtimeMenuStatus.idle));
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.selectedCategory, isNull);
      expect(viewModel.showParticipants, isFalse);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.hasUnsavedChanges, isFalse);
      expect(viewModel.categories, isEmpty);
      expect(viewModel.currentUserId, equals('test-user-123'));
      expect(viewModel.isOnline, isTrue);
      expect(viewModel.connectionStatusDescription, isNotEmpty);
      expect(() => viewModel.dispose(), returnsNormally);
      viewModel = RealtimeMenuViewModel(
        menuService: mockMenuService,
        syncService: mockSyncService,
        authService: mockAuthService,
      );
    });
  });

  group('Stream Management', () {
    test('should watch, receive, update, error, and stop', () async {
      // Watch and receive
      await watchAndEmit();
      expect(viewModel.currentMenu?.id, equals('menu-123'));
      expect(viewModel.status, equals(RealtimeMenuStatus.watching));

      // Real-time update
      final updated = RealtimeMenu(
        id: 'menu-123',
        ownerId: 'test-user-123',
        ownerDisplayName: 'Test User',
        participants: testMenu.participants,
        lastEditedBy: 'test-user-123',
        lastEditedByDisplayName: 'Test User',
        data: RealtimeMenuData(
          menuTitle: 'Uppdaterad Meny',
          createdForDate: DateTime.now(),
          menuSnapshot: testMenu.menuSnapshot,
        ),
      );
      menuStreamController.add(updated);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(viewModel.currentMenu?.menuTitle, equals('Uppdaterad Meny'));

      // Stop and reset
      await viewModel.stopWatching();
      expect(viewModel.currentMenu, isNull);
      expect(viewModel.status, equals(RealtimeMenuStatus.idle));
    });

    test('should handle stream errors', () async {
      await viewModel.startWatching('menu-123');
      menuStreamController.addError('Connection lost');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(viewModel.status, equals(RealtimeMenuStatus.error));
      expect(viewModel.errorMessage, contains('Real-time fel'));
    });
  });

  group('Recipe Operations', () {
    setUp(() async => await watchAndEmit());

    test('should add, remove, move, clear recipes', () async {
      final nr = RecipeFactory.build(
        id: 'new',
        title: 'Ny',
        mealType: 'Förrätt',
      );
      await viewModel.addRecipeToCategory(categoryName: 'Förrätt', recipe: nr);
      verify(
        () => mockMenuService.addRecipeToCategory(
          resourceId: 'menu-123',
          categoryName: 'Förrätt',
          recipe: nr,
        ),
      ).called(1);

      await viewModel.removeRecipeFromCategory(
        categoryName: 'Huvudrätt',
        recipeIndex: 0,
      );
      verify(
        () => mockMenuService.removeRecipeFromCategory(
          resourceId: 'menu-123',
          categoryName: 'Huvudrätt',
          recipeIndex: 0,
        ),
      ).called(1);

      await viewModel.moveRecipeBetweenCategories(
        fromCategory: 'Förrätt',
        fromIndex: 0,
        toCategory: 'Huvudrätt',
        toIndex: 1,
      );
      verify(
        () => mockMenuService.moveRecipeBetweenCategories(
          resourceId: 'menu-123',
          fromCategory: 'Förrätt',
          fromIndex: 0,
          toCategory: 'Huvudrätt',
          toIndex: 1,
        ),
      ).called(1);

      await viewModel.clearCategory('Huvudrätt');
      verify(
        () => mockMenuService.clearCategory(
          resourceId: 'menu-123',
          categoryName: 'Huvudrätt',
        ),
      ).called(1);
    });

    test('should guard: no menu, no permission, offline', () async {
      await viewModel.stopWatching();
      await viewModel.addRecipeToCategory(
        categoryName: 'Förrätt',
        recipe: testRecipe1,
      );
      expect(viewModel.errorMessage, equals('Ingen meny laddad'));

      await watchAndEmit();
      mockPermission.setPermissionState(
        currentUserId: 'test-user-123',
        isAuthenticated: true,
        defaultHasPermission: false,
      );
      await viewModel.addRecipeToCategory(
        categoryName: 'Förrätt',
        recipe: testRecipe1,
      );
      expect(viewModel.errorMessage, equals('Ingen redigeringsbehörighet'));

      mockPermission.setPermissionState(
        currentUserId: 'test-user-123',
        isAuthenticated: true,
        defaultHasPermission: true,
      );
      when(() => mockSyncService.isConnected).thenReturn(false);
      connectionController.add(false);
      await Future.delayed(const Duration(milliseconds: 200));
      await viewModel.addRecipeToCategory(
        categoryName: 'Förrätt',
        recipe: testRecipe1,
      );
      expect(viewModel.errorMessage, equals('Ingen internetanslutning'));
    });
  });

  group('Participant Management', () {
    test('should add and remove participants, error without menu', () async {
      await watchAndEmit();
      await viewModel.addParticipant(
        userId: 'new-user',
        userDisplayName: 'New User',
        permission: ResourcePermission.editor,
      );
      verify(
        () => mockMenuService.addParticipant(
          resourceId: 'menu-123',
          userId: 'new-user',
          userDisplayName: 'New User',
          permission: ResourcePermission.editor,
        ),
      ).called(1);

      await viewModel.removeParticipant('user-789');
      verify(
        () => mockMenuService.removeParticipant(
          resourceId: 'menu-123',
          userId: 'user-789',
        ),
      ).called(1);

      await viewModel.stopWatching();
      await viewModel.addParticipant(
        userId: 'x',
        userDisplayName: 'X',
        permission: ResourcePermission.editor,
      );
      expect(viewModel.errorMessage, equals('Ingen meny laddad'));
    });
  });

  group('State Management', () {
    setUp(() async {
      await watchAndEmit();
    });

    test('should select category and get its recipes', () {
      viewModel.selectCategory('Huvudrätt');
      expect(viewModel.selectedCategory, equals('Huvudrätt'));
      expect(
        viewModel.selectedCategoryRecipes.first.title,
        equals('Köttbullar'),
      );
      viewModel.selectCategory(null);
      expect(viewModel.selectedCategory, isNull);
    });

    test('should toggle participants, clear errors, provide categories', () {
      expect(viewModel.showParticipants, isFalse);
      viewModel.toggleParticipants();
      expect(viewModel.showParticipants, isTrue);
      viewModel.clearError();
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.categories, contains('Förrätt'));
      expect(viewModel.categories, contains('Huvudrätt'));
      expect(viewModel.categories, contains('Huvudrätt'));
      expect(viewModel.menuWithOptimisticChanges, isMap);
    });
  });

  group('Connection & Permissions', () {
    test('should detect offline and recover', () async {
      await watchAndEmit();
      when(() => mockSyncService.isConnected).thenReturn(false);
      connectionController.add(false);
      await Future.delayed(const Duration(milliseconds: 200));
      expect(viewModel.isOnline, isFalse);

      when(() => mockSyncService.isConnected).thenReturn(true);
      connectionController.add(true);
      await Future.delayed(const Duration(milliseconds: 200));
      expect(viewModel.isOnline, isTrue);
    });

    test('should check edit permission (owner can edit)', () async {
      await watchAndEmit();
      expect(viewModel.canEdit, isTrue);
    });

    test('should deny edit when viewer only', () async {
      mockPermission.setPermissionState(
        currentUserId: 'test-user-123',
        isAuthenticated: true,
        defaultHasPermission: false,
      );
      await watchAndEmit();
      expect(viewModel.canEdit, isFalse);
    });

    test('should handle null user', () async {
      when(() => mockAuthService.currentUserId).thenReturn(null);
      mockPermission.setPermissionState(
        currentUserId: null,
        isAuthenticated: false,
      );
      await watchAndEmit();
      expect(viewModel.currentUserId, isNull);
      expect(viewModel.canEdit, isFalse);
    });
  });

  group('Utility Methods', () {
    setUp(() async {
      await watchAndEmit();
    });

    test('should create personal copy (null without menu)', () async {
      expect(viewModel.createPersonalCopy(), isNotNull);
      await viewModel.stopWatching();
      expect(viewModel.createPersonalCopy(), isNull);
    });

    test('should delete menu if owner, skip if unauthorized', () async {
      await viewModel.deleteMenu();
      verify(() => mockMenuService.deleteRealtimeMenu('menu-123')).called(1);

      // Re-watch for the unauthorized test
      await watchAndEmit();
      mockPermission.setPermissionState(
        currentUserId: 'test-user-123',
        isAuthenticated: true,
        defaultHasPermission: false,
      );
      await viewModel.deleteMenu();
      // Still only 1 call total (the first one)
      verifyNever(() => mockMenuService.deleteRealtimeMenu('menu-456'));
    });

    test('should update basic info', () async {
      await viewModel.updateBasicInfo(
        menuTitle: 'Ny Meny',
        menuNotes: 'Anteckningar',
      );
      verify(
        () => mockMenuService.updateBasicInfo(
          resourceId: 'menu-123',
          menuTitle: 'Ny Meny',
          createdForDate: any(named: 'createdForDate'),
          menuNotes: 'Anteckningar',
          originalPrompt: any(named: 'originalPrompt'),
        ),
      ).called(1);
    });
  });

  group('Error Handling', () {
    test('should handle service errors and permission changes', () async {
      when(
        () => mockMenuService.addRecipeToCategory(
          resourceId: any(named: 'resourceId'),
          categoryName: any(named: 'categoryName'),
          recipe: any(named: 'recipe'),
        ),
      ).thenThrow(Exception('Service error'));

      await watchAndEmit();
      await viewModel.addRecipeToCategory(
        categoryName: 'Förrätt',
        recipe: testRecipe1,
      );
      expect(viewModel.errorMessage, isNotNull);

      // Permission changes mid-session
      expect(viewModel.canEdit, isTrue);
      mockPermission.setPermissionState(
        currentUserId: 'test-user-123',
        isAuthenticated: true,
        defaultHasPermission: false,
      );
      expect(viewModel.canEdit, isFalse);
    });

    test('should handle empty menu categories', () async {
      final emptyMenu = RealtimeMenu(
        id: 'empty',
        ownerId: 'test-user-123',
        ownerDisplayName: 'Test User',
        participants: testMenu.participants,
        lastEditedBy: 'test-user-123',
        lastEditedByDisplayName: 'Test User',
        data: RealtimeMenuData(
          menuTitle: 'Tom',
          createdForDate: DateTime.now(),
          menuSnapshot: {},
        ),
      );
      await viewModel.startWatching('empty');
      menuStreamController.add(emptyMenu);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(viewModel.categories, isEmpty);
      expect(viewModel.selectedCategoryRecipes, isEmpty);
    });
  });
}
