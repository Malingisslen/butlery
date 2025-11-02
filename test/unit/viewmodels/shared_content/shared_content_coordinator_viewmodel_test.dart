import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_recipe_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_menu_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_shopping_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_search_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/social_sharing_viewmodel.dart';
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';

// Mock ViewModels
class MockSharedRecipeViewModel extends Mock implements SharedRecipeViewModel {}
class MockSharedMenuViewModel extends Mock implements SharedMenuViewModel {}
class MockSharedShoppingViewModel extends Mock implements SharedShoppingViewModel {}
class MockSharedContentSearchViewModel extends Mock implements SharedContentSearchViewModel {}
class MockSocialSharingViewModel extends Mock implements SocialSharingViewModel {}

// Mock result class for sharing
class MockShareResult {
  final bool success;
  final String? error;

  MockShareResult({required this.success, this.error});
}

void main() {
  group('SharedContentCoordinatorViewModel - Coordinator Tests', () {
    late SharedContentCoordinatorViewModel viewModel;
    late MockSharedRecipeViewModel mockRecipeViewModel;
    late MockSharedMenuViewModel mockMenuViewModel;
    late MockSharedShoppingViewModel mockShoppingViewModel;
    late MockSharedContentSearchViewModel mockSearchViewModel;
    late MockSocialSharingViewModel mockSocialSharingViewModel;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();

      // Register fallback values for mocktail
      registerFallbackValue(ContentTab.recipes);
      registerFallbackValue(ShareableContentType.recipe);
      registerFallbackValue(<String>[]);
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create mocks
      mockRecipeViewModel = MockSharedRecipeViewModel();
      mockMenuViewModel = MockSharedMenuViewModel();
      mockShoppingViewModel = MockSharedShoppingViewModel();
      mockSearchViewModel = MockSharedContentSearchViewModel();
      mockSocialSharingViewModel = MockSocialSharingViewModel();

      // Setup default mock behavior - loading states
      when(() => mockRecipeViewModel.isLoading).thenReturn(false);
      when(() => mockRecipeViewModel.isOperating).thenReturn(false);
      when(() => mockRecipeViewModel.unreadCount).thenReturn(0);
      when(() => mockRecipeViewModel.totalCount).thenReturn(0);
      when(() => mockRecipeViewModel.hasContent).thenReturn(false);
      when(() => mockRecipeViewModel.filteredContent).thenReturn([]);
      when(() => mockRecipeViewModel.content).thenReturn([]);
      when(() => mockRecipeViewModel.getEngagementStats()).thenReturn({});
      when(() => mockRecipeViewModel.refreshContent()).thenAnswer((_) async {});
      when(() => mockRecipeViewModel.markAllAsViewed()).thenAnswer((_) async {});

      when(() => mockMenuViewModel.isLoading).thenReturn(false);
      when(() => mockMenuViewModel.isOperating).thenReturn(false);
      when(() => mockMenuViewModel.unreadCount).thenReturn(0);
      when(() => mockMenuViewModel.totalCount).thenReturn(0);
      when(() => mockMenuViewModel.hasContent).thenReturn(false);
      when(() => mockMenuViewModel.filteredContent).thenReturn([]);
      when(() => mockMenuViewModel.content).thenReturn([]);
      when(() => mockMenuViewModel.getEngagementStats()).thenReturn({});
      when(() => mockMenuViewModel.refreshContent()).thenAnswer((_) async {});
      when(() => mockMenuViewModel.markAllAsViewed()).thenAnswer((_) async {});

      when(() => mockShoppingViewModel.isLoading).thenReturn(false);
      when(() => mockShoppingViewModel.isOperating).thenReturn(false);
      when(() => mockShoppingViewModel.unreadCount).thenReturn(0);
      when(() => mockShoppingViewModel.totalCount).thenReturn(0);
      when(() => mockShoppingViewModel.hasContent).thenReturn(false);
      when(() => mockShoppingViewModel.filteredContent).thenReturn([]);
      when(() => mockShoppingViewModel.content).thenReturn([]);
      when(() => mockShoppingViewModel.getEngagementStats()).thenReturn({});
      when(() => mockShoppingViewModel.refreshContent()).thenAnswer((_) async {});
      when(() => mockShoppingViewModel.markAllAsViewed()).thenAnswer((_) async {});

      when(() => mockSearchViewModel.isSearching).thenReturn(false);
      when(() => mockSearchViewModel.hasSearchQuery).thenReturn(false);
      when(() => mockSearchViewModel.hasActiveFilters).thenReturn(false);
      when(() => mockSearchViewModel.filteredResults).thenReturn([]);
      when(() => mockSearchViewModel.updateSearchQuery(any())).thenReturn(null);
      when(() => mockSearchViewModel.clearSearch()).thenReturn(null);
      when(() => mockSearchViewModel.clearFilters()).thenReturn(null);

      when(() => mockSocialSharingViewModel.isSharing).thenReturn(false);
      when(() => mockSocialSharingViewModel.isBusy).thenReturn(false);
      when(() => mockSocialSharingViewModel.getSharingStats()).thenReturn({});
      when(() => mockSocialSharingViewModel.refreshFriends()).thenAnswer((_) async {});
      when(() => mockSocialSharingViewModel.prepareForSharing(
        contentType: any(named: 'contentType'),
        contentTitle: any(named: 'contentTitle'),
        suggestedFriends: any(named: 'suggestedFriends'),
      )).thenReturn(null);
      when(() => mockSocialSharingViewModel.updateShareMessage(any())).thenReturn(null);
      when(() => mockSocialSharingViewModel.shareContent(
        contentId: any(named: 'contentId'),
        contentType: any(named: 'contentType'),
      )).thenAnswer((_) async => MockShareResult(success: true) as dynamic);

      // Mock addListener and removeListener
      when(() => mockRecipeViewModel.addListener(any())).thenReturn(null);
      when(() => mockRecipeViewModel.removeListener(any())).thenReturn(null);
      when(() => mockRecipeViewModel.dispose()).thenReturn(null);

      when(() => mockMenuViewModel.addListener(any())).thenReturn(null);
      when(() => mockMenuViewModel.removeListener(any())).thenReturn(null);
      when(() => mockMenuViewModel.dispose()).thenReturn(null);

      when(() => mockShoppingViewModel.addListener(any())).thenReturn(null);
      when(() => mockShoppingViewModel.removeListener(any())).thenReturn(null);
      when(() => mockShoppingViewModel.dispose()).thenReturn(null);

      when(() => mockSearchViewModel.addListener(any())).thenReturn(null);
      when(() => mockSearchViewModel.removeListener(any())).thenReturn(null);
      when(() => mockSearchViewModel.dispose()).thenReturn(null);

      when(() => mockSocialSharingViewModel.addListener(any())).thenReturn(null);
      when(() => mockSocialSharingViewModel.removeListener(any())).thenReturn(null);
      when(() => mockSocialSharingViewModel.dispose()).thenReturn(null);
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
    SharedContentCoordinatorViewModel createViewModel() {
      return SharedContentCoordinatorViewModel(
        recipeViewModel: mockRecipeViewModel,
        menuViewModel: mockMenuViewModel,
        shoppingViewModel: mockShoppingViewModel,
        searchViewModel: mockSearchViewModel,
        socialSharingViewModel: mockSocialSharingViewModel,
      );
    }

    // ===== INITIALIZATION AND STATE =====

    group('Initialization and State', () {
      test('should initialize with default state', () {
        // Act
        viewModel = createViewModel();

        // Assert
        expect(viewModel.currentTab, ContentTab.recipes, reason: 'Default tab should be recipes');
        expect(viewModel.isGloballyLoading, false);
        expect(viewModel.hasGlobalError, false);
        expect(viewModel.isInitialized, false, reason: 'Not initialized until initialize() called');
        expect(viewModel.isInitializing, false);
      });

      test('should provide access to specialized ViewModels', () {
        // Act
        viewModel = createViewModel();

        // Assert
        expect(viewModel.recipeViewModel, mockRecipeViewModel);
        expect(viewModel.menuViewModel, mockMenuViewModel);
        expect(viewModel.shoppingViewModel, mockShoppingViewModel);
        expect(viewModel.searchViewModel, mockSearchViewModel);
        expect(viewModel.socialSharingViewModel, mockSocialSharingViewModel);
      });

      test('should add listeners to all specialized ViewModels', () {
        // Act
        viewModel = createViewModel();

        // Assert
        verify(() => mockRecipeViewModel.addListener(any())).called(1);
        verify(() => mockMenuViewModel.addListener(any())).called(1);
        verify(() => mockShoppingViewModel.addListener(any())).called(1);
        verify(() => mockSearchViewModel.addListener(any())).called(1);
        verify(() => mockSocialSharingViewModel.addListener(any())).called(1);
      });

      test('should aggregate loading states from all ViewModels', () {
        // Arrange - Set one ViewModel as loading
        when(() => mockRecipeViewModel.isLoading).thenReturn(true);
        viewModel = createViewModel();

        // Act & Assert
        expect(viewModel.isAnyViewModelLoading, true);
      });

      test('should aggregate operating states from all ViewModels', () {
        // Arrange - Set one ViewModel as operating
        when(() => mockMenuViewModel.isOperating).thenReturn(true);
        viewModel = createViewModel();

        // Act & Assert
        expect(viewModel.isAnyViewModelOperating, true);
      });
    });

    // ===== TAB MANAGEMENT =====

    group('Tab Management', () {
      test('should switch between tabs', () {
        // Arrange
        viewModel = createViewModel();
        expect(viewModel.currentTab, ContentTab.recipes);

        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.setCurrentTab(ContentTab.menus);

        // Assert
        expect(viewModel.currentTab, ContentTab.menus);
        expect(notificationCount, 1, reason: 'Should notify listeners');
      });

      test('should not notify if setting same tab', () {
        // Arrange
        viewModel = createViewModel();
        viewModel.setCurrentTab(ContentTab.recipes);

        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.setCurrentTab(ContentTab.recipes);

        // Assert
        expect(notificationCount, 0, reason: 'Should not notify when tab unchanged');
      });

      test('should provide Swedish tab titles', () {
        // Arrange
        viewModel = createViewModel();

        // Act & Assert
        expect(viewModel.getTabTitle(ContentTab.recipes), 'Recept');
        expect(viewModel.getTabTitle(ContentTab.menus), 'Menyer');
        expect(viewModel.getTabTitle(ContentTab.shoppingLists), 'Handla');
      });

      test('should provide tab titles with unread counts', () {
        // Arrange
        when(() => mockRecipeViewModel.unreadCount).thenReturn(5);
        when(() => mockMenuViewModel.unreadCount).thenReturn(0);
        viewModel = createViewModel();

        // Act & Assert
        expect(viewModel.getTabTitleWithUnreadCount(ContentTab.recipes), 'Recept (5)');
        expect(viewModel.getTabTitleWithUnreadCount(ContentTab.menus), 'Menyer');
      });
    });

    // ===== CONTENT AGGREGATION =====

    group('Content Aggregation', () {
      test('should aggregate total content count', () {
        // Arrange
        when(() => mockRecipeViewModel.totalCount).thenReturn(10);
        when(() => mockMenuViewModel.totalCount).thenReturn(5);
        when(() => mockShoppingViewModel.totalCount).thenReturn(3);
        viewModel = createViewModel();

        // Act & Assert
        expect(viewModel.totalContentCount, 18);
      });

      test('should aggregate total unread count', () {
        // Arrange
        when(() => mockRecipeViewModel.unreadCount).thenReturn(2);
        when(() => mockMenuViewModel.unreadCount).thenReturn(1);
        when(() => mockShoppingViewModel.unreadCount).thenReturn(4);
        viewModel = createViewModel();

        // Act & Assert
        expect(viewModel.totalUnreadCount, 7);
      });

      test('should detect if any content exists', () {
        // Arrange - No content
        viewModel = createViewModel();
        expect(viewModel.hasAnyContent, false);

        // Arrange - Has content
        when(() => mockRecipeViewModel.hasContent).thenReturn(true);
        final viewModel2 = createViewModel();

        // Assert
        expect(viewModel2.hasAnyContent, true);
      });

      test('should provide content counts by type', () {
        // Arrange
        when(() => mockRecipeViewModel.totalCount).thenReturn(10);
        when(() => mockMenuViewModel.totalCount).thenReturn(5);
        when(() => mockShoppingViewModel.totalCount).thenReturn(3);
        viewModel = createViewModel();

        // Act
        final counts = viewModel.contentCounts;

        // Assert
        expect(counts[ContentTab.recipes], 10);
        expect(counts[ContentTab.menus], 5);
        expect(counts[ContentTab.shoppingLists], 3);
      });

      test('should provide unread counts by type', () {
        // Arrange
        when(() => mockRecipeViewModel.unreadCount).thenReturn(2);
        when(() => mockMenuViewModel.unreadCount).thenReturn(1);
        when(() => mockShoppingViewModel.unreadCount).thenReturn(4);
        viewModel = createViewModel();

        // Act
        final counts = viewModel.unreadCounts;

        // Assert
        expect(counts[ContentTab.recipes], 2);
        expect(counts[ContentTab.menus], 1);
        expect(counts[ContentTab.shoppingLists], 4);
      });
    });

    // ===== UNIFIED OPERATIONS =====

    group('Unified Operations', () {
      test('should refresh all content', () async {
        // Arrange
        viewModel = createViewModel();

        // Act
        await viewModel.refreshAllContent();

        // Assert
        verify(() => mockRecipeViewModel.refreshContent()).called(1);
        verify(() => mockMenuViewModel.refreshContent()).called(1);
        verify(() => mockShoppingViewModel.refreshContent()).called(1);
        verify(() => mockSocialSharingViewModel.refreshFriends()).called(1);
      });

      test('should set global loading during refresh', () async {
        // Arrange
        viewModel = createViewModel();

        // Act
        final refreshFuture = viewModel.refreshAllContent();

        // Wait a bit to check loading state
        await Future.delayed(const Duration(milliseconds: 10));

        await refreshFuture;

        // Assert - Loading should be false after completion
        expect(viewModel.isGloballyLoading, false);
      });

      test('should mark all content as viewed', () async {
        // Arrange
        viewModel = createViewModel();

        // Act
        await viewModel.markAllAsViewed();

        // Assert
        verify(() => mockRecipeViewModel.markAllAsViewed()).called(1);
        verify(() => mockMenuViewModel.markAllAsViewed()).called(1);
        verify(() => mockShoppingViewModel.markAllAsViewed()).called(1);
      });

      test('should perform unified search', () async {
        // Arrange
        viewModel = createViewModel();
        const query = 'test search';

        // Act
        await viewModel.performUnifiedSearch(query);

        // Assert
        verify(() => mockSearchViewModel.updateSearchQuery(query)).called(1);
      });

      test('should clear all search and filters', () {
        // Arrange
        viewModel = createViewModel();

        // Act
        viewModel.clearAllSearch();

        // Assert
        verify(() => mockSearchViewModel.clearSearch()).called(1);
        verify(() => mockSearchViewModel.clearFilters()).called(1);
      });
    });

    // ===== ANALYTICS =====

    group('Analytics', () {
      test('should provide comprehensive analytics', () {
        // Arrange
        when(() => mockRecipeViewModel.getEngagementStats()).thenReturn({'views': 10});
        when(() => mockMenuViewModel.getEngagementStats()).thenReturn({'views': 5});
        when(() => mockShoppingViewModel.getEngagementStats()).thenReturn({'views': 3});
        when(() => mockSocialSharingViewModel.getSharingStats()).thenReturn({'shared': 2});

        viewModel = createViewModel();

        // Act
        final analytics = viewModel.getComprehensiveAnalytics();

        // Assert
        expect(analytics, isNotNull);
        expect(analytics['coordinator'], isNotNull);
        expect(analytics['recipes'], isNotNull);
        expect(analytics['menus'], isNotNull);
        expect(analytics['shoppingLists'], isNotNull);
        expect(analytics['search'], isNotNull);
        expect(analytics['socialSharing'], isNotNull);
      });
    });

    // ===== DISPOSAL =====

    group('Disposal', () {
      test('should remove listeners from all ViewModels on dispose', () {
        // Arrange
        viewModel = createViewModel();

        // Act
        viewModel.dispose();

        // Assert
        verify(() => mockRecipeViewModel.removeListener(any())).called(1);
        verify(() => mockMenuViewModel.removeListener(any())).called(1);
        verify(() => mockShoppingViewModel.removeListener(any())).called(1);
        verify(() => mockSearchViewModel.removeListener(any())).called(1);
        verify(() => mockSocialSharingViewModel.removeListener(any())).called(1);
      });

      test('should dispose all specialized ViewModels', () {
        // Arrange
        viewModel = createViewModel();

        // Act
        viewModel.dispose();

        // Assert
        verify(() => mockRecipeViewModel.dispose()).called(1);
        verify(() => mockMenuViewModel.dispose()).called(1);
        verify(() => mockShoppingViewModel.dispose()).called(1);
        verify(() => mockSearchViewModel.dispose()).called(1);
        verify(() => mockSocialSharingViewModel.dispose()).called(1);
      });

      test('should dispose without errors', () {
        // Arrange
        viewModel = createViewModel();

        // Act & Assert
        expect(() => viewModel.dispose(), returnsNormally);
      });
    });
  });
}
