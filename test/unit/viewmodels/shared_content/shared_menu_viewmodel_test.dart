import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/shared_content/shared_menu_viewmodel.dart';
import 'package:butlery/repositories/firebase/firebase_shared_menu_repository.dart';
import 'package:butlery/services/unified/modules/social_menu/social_menu_coordinator.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';

// Mock dependencies
class MockFirebaseSharedMenuRepository extends Mock implements FirebaseSharedMenuRepository {}
class MockSocialMenuCoordinator extends Mock implements SocialMenuCoordinator {}

void main() {
  group('SharedMenuViewModel - Shared Menu Management Tests', () {
    late SharedMenuViewModel viewModel;
    late MockFirebaseSharedMenuRepository mockRepository;
    late MockSocialMenuCoordinator mockCoordinator;

    // Test data
    const testUserId = 'current-user-123';
    const testOtherUserId = 'other-user-456';
    const testMenuId1 = 'menu-1';
    const testMenuId2 = 'menu-2';

    late SharedMenu testMenu1;
    late SharedMenu testMenu2;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();

      // Register fallback values for mocktail
      registerFallbackValue(<String>[]);
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create mocks
      mockRepository = MockFirebaseSharedMenuRepository();
      mockCoordinator = MockSocialMenuCoordinator();

      // Create test recipes for menu snapshots
      final recipe1 = Recipe(
        core: RecipeCore(
          id: 'recipe-1',
          title: 'Pannkakor',
          description: 'Goda pannkakor',
          ingredients: ['Mjöl', 'Mjölk', 'Ägg'],
          instructions: ['Blanda', 'Stek'],
          mealType: 'Frukost',
          createdBy: testOtherUserId,
          createdAt: DateTime(2025, 1, 20),
          updatedAt: DateTime(2025, 1, 20),
        ),
        type: RecipeType.personal,
      );

      final recipe2 = Recipe(
        core: RecipeCore(
          id: 'recipe-2',
          title: 'Köttbullar',
          description: 'Klassiska köttbullar',
          ingredients: ['Köttfärs', 'Ägg', 'Mjölk'],
          instructions: ['Blanda', 'Forma', 'Stek'],
          mealType: 'Middag',
          createdBy: testOtherUserId,
          createdAt: DateTime(2025, 1, 20),
          updatedAt: DateTime(2025, 1, 20),
        ),
        type: RecipeType.personal,
      );

      // Create menu snapshots
      final menuSnapshot1 = <String, List<Recipe>>{
        'Måndag': [recipe1],
        'Tisdag': [recipe2],
      };

      final menuSnapshot2 = <String, List<Recipe>>{
        'Förrätt': [recipe1],
        'Huvudrätt': [recipe2],
        'Efterrätt': [recipe1],
      };

      testMenu1 = SharedMenu(
        id: testMenuId1,
        menuTitle: 'Veckomeny',
        menuSnapshot: menuSnapshot1,
        sharedByUserId: testOtherUserId,
        sharedByDisplayName: 'Anna',
        sharedToUserIds: [testUserId],
        sharedAt: DateTime(2025, 1, 20),
        viewedByUserIds: [],
        engagedByUserIds: [],
        dismissedByUserIds: [],
        allowCollaboration: false,
      );

      testMenu2 = SharedMenu(
        id: testMenuId2,
        menuTitle: 'Festmeny',
        menuSnapshot: menuSnapshot2,
        sharedByUserId: testOtherUserId,
        sharedByDisplayName: 'Erik',
        sharedToUserIds: [testUserId],
        sharedAt: DateTime(2025, 1, 21),
        viewedByUserIds: [testUserId], // Already viewed
        engagedByUserIds: [],
        dismissedByUserIds: [],
        allowCollaboration: false,
      );

      // Setup default mock behavior
      when(() => mockRepository.getSharedMenusForUser(testUserId))
          .thenAnswer((_) async => [testMenu1, testMenu2]);

      when(() => mockRepository.markAsViewed(any(), any()))
          .thenAnswer((_) async {});

      when(() => mockRepository.markAsDismissed(any(), any()))
          .thenAnswer((_) async {});

      when(() => mockRepository.undismiss(any(), any()))
          .thenAnswer((_) async {});

      when(() => mockCoordinator.joinSharedMenu(
        sharedMenuId: any(named: 'sharedMenuId'),
        newTitle: any(named: 'newTitle'),
      )).thenAnswer((_) async => 'new-menu-id');

      when(() => mockCoordinator.startCollaborativeMenuEditing(
        sharedMenuId: any(named: 'sharedMenuId'),
      )).thenAnswer((_) async => 'collaborative-menu-id');
    });

    tearDown(() async {
      try {
        viewModel.dispose();
      } catch (e) {
        // Already disposed in test
      }
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    // Helper to create ViewModel
    SharedMenuViewModel createViewModel() {
      return SharedMenuViewModel(
        sharedMenuRepository: mockRepository,
        socialMenuCoordinator: mockCoordinator,
      );
    }

    // ===== INITIALIZATION AND LOADING =====

    group('Initialization and Loading', () {
      test('should initialize with menu content type', () async {
        // Act
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Assert
        expect(viewModel.contentTypeName, 'menu');
        verify(() => mockRepository.getSharedMenusForUser(testUserId)).called(1);
      });

      test('should load menus successfully', () async {
        // Arrange
        viewModel = createViewModel();

        // Act
        await Future.delayed(const Duration(milliseconds: 150));

        // Assert
        expect(viewModel.hasContent, true);
        expect(viewModel.totalCount, 2);
        expect(viewModel.hasError, false);
      });

      test('should handle load error gracefully', () async {
        // Arrange
        when(() => mockRepository.getSharedMenusForUser(testUserId))
            .thenThrow(Exception('Network error'));

        viewModel = createViewModel();

        // Act
        await Future.delayed(const Duration(milliseconds: 150));

        // Assert
        expect(viewModel.hasError, true);
        expect(viewModel.error, contains('Failed to load menu content'));
      });
    });

    // ===== CONTENT GETTERS =====

    group('Content Getters', () {
      test('should provide unread count', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act & Assert
        // testMenu1 is unread, testMenu2 is viewed
        expect(testMenu1.isViewedBy(testUserId), false);
        expect(testMenu2.isViewedBy(testUserId), true);
      });

      test('should provide importable menus', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act
        final importable = viewModel.importableMenus;

        // Assert
        expect(importable.length, 2, reason: 'Both menus can be imported');
      });

      test('should provide menus with content', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act
        final menusWithContent = viewModel.menusWithContent;

        // Assert
        // Both test menus have categories, so they have content
        expect(menusWithContent.length, greaterThan(0));
      });
    });

    // ===== SEARCH AND FILTERING =====

    group('Search and Filtering', () {
      test('should filter menus by title', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act
        viewModel.updateSearchQuery('Veckomeny');

        // Assert
        expect(viewModel.filteredCount, 1);
        expect(viewModel.filteredContent.first.id, testMenuId1);
      });

      test('should filter menus by categories', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act
        viewModel.updateSearchQuery('Förrätt');

        // Assert
        expect(viewModel.filteredCount, 1);
        expect(viewModel.filteredContent.first.id, testMenuId2);
      });

      test('should filter menus by sharer name', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act
        viewModel.updateSearchQuery('Anna');

        // Assert
        expect(viewModel.filteredCount, 1);
        expect(viewModel.filteredContent.first.id, testMenuId1);
      });

      test('should be case insensitive', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act
        viewModel.updateSearchQuery('VECKOMENY');

        // Assert
        expect(viewModel.filteredCount, 1);
      });

      test('should clear search', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));
        viewModel.updateSearchQuery('Veckomeny');

        // Act
        viewModel.clearSearch();

        // Assert
        expect(viewModel.searchQuery, '');
        expect(viewModel.filteredCount, 2);
      });
    });

    // ===== IMPORT OPERATIONS =====

    group('Import Operations', () {
      test('should import menu successfully', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act
        final menuId = await viewModel.importSharedMenu(testMenu1);

        // Assert
        expect(menuId, 'new-menu-id');
        expect(viewModel.isOperating, false);
        verify(() => mockCoordinator.joinSharedMenu(
          sharedMenuId: testMenuId1,
          newTitle: null,
        )).called(1);
      });

      test('should import menu with custom title', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));
        const customTitle = 'Min veckomeny';

        // Act
        await viewModel.importSharedMenu(testMenu1, newTitle: customTitle);

        // Assert
        verify(() => mockCoordinator.joinSharedMenu(
          sharedMenuId: testMenuId1,
          newTitle: customTitle,
        )).called(1);
      });

      test('should handle import error', () async {
        // Arrange
        when(() => mockCoordinator.joinSharedMenu(
          sharedMenuId: any(named: 'sharedMenuId'),
          newTitle: any(named: 'newTitle'),
        )).thenThrow(Exception('Import failed'));

        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act
        final result = await viewModel.importSharedMenu(testMenu1);

        // Assert
        expect(result, null);
        expect(viewModel.hasError, true);
      });
    });

    // ===== COLLABORATIVE EDITING =====

    group('Collaborative Editing', () {
      test('should start collaborative editing successfully', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act
        final menuId = await viewModel.startCollaborativeEditing(testMenu1);

        // Assert
        expect(menuId, 'collaborative-menu-id');
        verify(() => mockCoordinator.startCollaborativeMenuEditing(
          sharedMenuId: testMenuId1,
        )).called(1);
      });

      test('should handle collaborative editing error', () async {
        // Arrange
        when(() => mockCoordinator.startCollaborativeMenuEditing(
          sharedMenuId: any(named: 'sharedMenuId'),
        )).thenThrow(Exception('Failed to start collaboration'));

        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act
        final result = await viewModel.startCollaborativeEditing(testMenu1);

        // Assert
        expect(result, null);
        expect(viewModel.hasError, true);
      });
    });

    // ===== MARK AS VIEWED =====

    group('Mark As Viewed', () {
      test('should mark menu as viewed', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act
        final result = await viewModel.markAsViewed(testMenu1);

        // Assert
        expect(result, true);
        verify(() => mockRepository.markAsViewed(testMenuId1, testUserId)).called(1);
      });

      test('should skip if already viewed', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act - testMenu2 is already viewed
        final result = await viewModel.markAsViewed(testMenu2);

        // Assert
        expect(result, true);
        verifyNever(() => mockRepository.markAsViewed(testMenuId2, testUserId));
      });
    });

    // ===== DISMISS AND UNDISMISS =====

    group('Dismiss and Undismiss', () {
      test('should dismiss menu', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));
        final initialCount = viewModel.totalCount;

        // Act
        final result = await viewModel.dismissSharedMenu(testMenu1);

        // Assert
        expect(result, true);
        expect(viewModel.totalCount, initialCount - 1, reason: 'Menu removed from list');
        verify(() => mockRepository.markAsDismissed(testMenuId1, testUserId)).called(1);
      });

      test('should undismiss menu', () async {
        // Arrange
        final dismissedMenu = SharedMenu(
          id: 'dismissed-menu',
          menuTitle: 'Dismissed Meny',
          menuSnapshot: testMenu1.menuSnapshot,
          sharedByUserId: testOtherUserId,
          sharedByDisplayName: 'Anna',
          sharedToUserIds: [testUserId],
          sharedAt: DateTime(2025, 1, 20),
          viewedByUserIds: [],
          engagedByUserIds: [],
          dismissedByUserIds: [testUserId],
          allowCollaboration: false,
        );

        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));
        final initialCount = viewModel.totalCount;

        // Act
        final result = await viewModel.undismissSharedMenu(dismissedMenu);

        // Assert
        expect(result, true);
        expect(viewModel.totalCount, initialCount + 1, reason: 'Menu added back to list');
        verify(() => mockRepository.undismiss('dismissed-menu', testUserId)).called(1);
      });
    });

    // ===== BULK OPERATIONS =====

    group('Bulk Operations', () {
      test('should mark all menus as viewed', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act
        await viewModel.markAllAsViewed();

        // Assert
        verify(() => mockRepository.markAsViewed(testMenuId1, testUserId)).called(1);
        // testMenu2 already viewed, should not be called
      });
    });

    // ===== REFRESH =====

    group('Refresh Content', () {
      test('should refresh content successfully', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Reset mock to count only the refresh call
        reset(mockRepository);
        when(() => mockRepository.getSharedMenusForUser(testUserId))
            .thenAnswer((_) async => [testMenu1, testMenu2]);

        // Act
        await viewModel.refreshContent();

        // Assert
        verify(() => mockRepository.getSharedMenusForUser(testUserId)).called(1);
      });
    });

    // ===== DISPOSAL =====

    group('Disposal', () {
      test('should dispose without errors', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act & Assert
        expect(() => viewModel.dispose(), returnsNormally);
      });
    });
  });
}
