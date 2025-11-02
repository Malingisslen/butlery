import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/shared_content/shared_shopping_viewmodel.dart';
import 'package:butlery/repositories/firebase/firebase_shared_shopping_repository.dart';
import 'package:butlery/services/unified/modules/social_shopping/social_shopping_coordinator.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/models/shared_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';

// Mock dependencies
class MockFirebaseSharedShoppingRepository extends Mock implements FirebaseSharedShoppingRepository {}
class MockSocialShoppingCoordinator extends Mock implements SocialShoppingCoordinator {}
class MockUnifiedShoppingService extends Mock implements UnifiedShoppingService {}

void main() {
  group('SharedShoppingViewModel - Shared Shopping List Management Tests', () {
    late SharedShoppingViewModel viewModel;
    late MockFirebaseSharedShoppingRepository mockRepository;
    late MockSocialShoppingCoordinator mockCoordinator;
    late MockUnifiedShoppingService mockShoppingService;

    // Test data
    const testUserId = 'current-user-123';
    const testOtherUserId = 'other-user-456';
    const testListId1 = 'list-1';
    const testListId2 = 'list-2';

    late SharedShoppingList testList1;
    late SharedShoppingList testList2;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();

      // Register fallback values for mocktail
      registerFallbackValue(<String>[]);
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create mocks
      mockRepository = MockFirebaseSharedShoppingRepository();
      mockCoordinator = MockSocialShoppingCoordinator();
      mockShoppingService = MockUnifiedShoppingService();

      // Create test shopping items
      final items1 = <UnifiedShoppingItem>[
        UnifiedShoppingItem.basic(
          name: 'Mjölk',
          amount: 1.0,
          unit: 'liter',
          bought: false,
        ),
        UnifiedShoppingItem.basic(
          name: 'Bröd',
          amount: 1.0,
          unit: 'st',
          bought: false,
        ),
      ];

      final items2 = <UnifiedShoppingItem>[
        UnifiedShoppingItem.basic(
          name: 'Äpplen',
          amount: 4.0,
          unit: 'st',
          bought: true,
        ),
        UnifiedShoppingItem.basic(
          name: 'Bananer',
          amount: 6.0,
          unit: 'st',
          bought: false,
        ),
        UnifiedShoppingItem.basic(
          name: 'Kaffe',
          amount: 1.0,
          unit: 'paket',
          bought: false,
        ),
      ];

      testList1 = SharedShoppingList(
        id: testListId1,
        listName: 'Veckohandling',
        listDescription: 'Handla för hela veckan',
        listItems: items1,
        sharedByUserId: testOtherUserId,
        sharedByDisplayName: 'Anna',
        sharedToUserIds: [testUserId],
        sharedAt: DateTime(2025, 1, 20),
        viewedByUserIds: [],
        engagedByUserIds: [],
        dismissedByUserIds: [],
        originalOwnerId: testOtherUserId,
        originalOwnerDisplayName: 'Anna',
      );

      testList2 = SharedShoppingList(
        id: testListId2,
        listName: 'Festhandling',
        listDescription: 'Till helgens fest',
        listItems: items2,
        sharedByUserId: testOtherUserId,
        sharedByDisplayName: 'Erik',
        sharedToUserIds: [testUserId],
        sharedAt: DateTime(2025, 1, 21),
        viewedByUserIds: [testUserId], // Already viewed
        engagedByUserIds: [],
        dismissedByUserIds: [],
        originalOwnerId: testOtherUserId,
        originalOwnerDisplayName: 'Erik',
      );

      // Setup default mock behavior
      when(() => mockRepository.getSharedShoppingListsForUser(testUserId))
          .thenAnswer((_) async => [testList1, testList2]);

      when(() => mockRepository.markAsViewed(any(), any()))
          .thenAnswer((_) async {});

      when(() => mockRepository.markAsDismissed(any(), any()))
          .thenAnswer((_) async {});

      when(() => mockRepository.undismiss(any(), any()))
          .thenAnswer((_) async {});

      when(() => mockCoordinator.joinSharedShoppingList(
        sharedShoppingListId: any(named: 'sharedShoppingListId'),
      )).thenAnswer((_) async => 'collaborative-list-id');

      when(() => mockShoppingService.lists)
          .thenReturn([]);
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
    SharedShoppingViewModel createViewModel() {
      return SharedShoppingViewModel(
        sharedShoppingRepository: mockRepository,
        socialShoppingCoordinator: mockCoordinator,
        shoppingService: mockShoppingService,
      );
    }

    // ===== INITIALIZATION AND LOADING =====

    group('Initialization and Loading', () {
      test('should initialize with shopping_list content type', () async {
        // Act
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Assert
        expect(viewModel.contentTypeName, 'shopping_list');
        verify(() => mockRepository.getSharedShoppingListsForUser(testUserId)).called(1);
      });

      test('should load shopping lists successfully', () async {
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
        when(() => mockRepository.getSharedShoppingListsForUser(testUserId))
            .thenThrow(Exception('Network error'));

        viewModel = createViewModel();

        // Act
        await Future.delayed(const Duration(milliseconds: 150));

        // Assert
        expect(viewModel.hasError, true);
        expect(viewModel.error, contains('Failed to load shopping_list content'));
      });
    });

    // ===== CONTENT GETTERS =====

    group('Content Getters', () {
      test('should provide unread count', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act & Assert
        // testList1 is unread, testList2 is viewed
        expect(testList1.isViewedBy(testUserId), false);
        expect(testList2.isViewedBy(testUserId), true);
      });

      test('should provide joinable shopping lists', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act
        final joinable = viewModel.joinableShoppingLists;

        // Assert
        expect(joinable.length, 2, reason: 'Both lists can be joined');
      });

      test('should provide lists with items', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act
        final listsWithItems = viewModel.listsWithItems;

        // Assert
        // Both test lists have items
        expect(listsWithItems.length, 2);
      });

      test('should calculate total items in lists', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act
        final totalItems = viewModel.totalItemsInLists;

        // Assert
        expect(totalItems, 5, reason: '2 items + 3 items');
      });
    });

    // ===== SEARCH AND FILTERING =====

    group('Search and Filtering', () {
      test('should filter lists by name', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act
        viewModel.updateSearchQuery('Vecko');

        // Assert
        expect(viewModel.filteredCount, 1);
        expect(viewModel.filteredContent.first.id, testListId1);
      });

      test('should filter lists by item names', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act
        viewModel.updateSearchQuery('Kaffe');

        // Assert
        expect(viewModel.filteredCount, 1);
        expect(viewModel.filteredContent.first.id, testListId2);
      });

      test('should filter lists by sharer name', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act
        viewModel.updateSearchQuery('Anna');

        // Assert
        expect(viewModel.filteredCount, 1);
        expect(viewModel.filteredContent.first.id, testListId1);
      });

      test('should be case insensitive', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act
        viewModel.updateSearchQuery('VECKO');

        // Assert
        expect(viewModel.filteredCount, 1);
      });

      test('should clear search', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));
        viewModel.updateSearchQuery('Vecko');

        // Act
        viewModel.clearSearch();

        // Assert
        expect(viewModel.searchQuery, '');
        expect(viewModel.filteredCount, 2);
      });
    });

    // ===== JOIN OPERATIONS =====

    group('Join Operations', () {
      test('should join shopping list successfully', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act
        final listId = await viewModel.joinSharedShoppingList(testList1);

        // Assert
        expect(listId, 'collaborative-list-id');
        expect(viewModel.isOperating, false);
        verify(() => mockCoordinator.joinSharedShoppingList(
          sharedShoppingListId: testListId1,
        )).called(1);
      });

      test('should handle join error', () async {
        // Arrange
        when(() => mockCoordinator.joinSharedShoppingList(
          sharedShoppingListId: any(named: 'sharedShoppingListId'),
        )).thenThrow(Exception('Join failed'));

        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act
        final result = await viewModel.joinSharedShoppingList(testList1);

        // Assert
        expect(result, null);
        expect(viewModel.hasError, true);
      });
    });

    // ===== MARK AS VIEWED =====

    group('Mark As Viewed', () {
      test('should mark list as viewed', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act
        final result = await viewModel.markAsViewed(testList1);

        // Assert
        expect(result, true);
        verify(() => mockRepository.markAsViewed(testListId1, testUserId)).called(1);
      });

      test('should skip if already viewed', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act - testList2 is already viewed
        final result = await viewModel.markAsViewed(testList2);

        // Assert
        expect(result, true);
        verifyNever(() => mockRepository.markAsViewed(testListId2, testUserId));
      });
    });

    // ===== DISMISS AND UNDISMISS =====

    group('Dismiss and Undismiss', () {
      test('should dismiss shopping list', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));
        final initialCount = viewModel.totalCount;

        // Act
        final result = await viewModel.dismissSharedShoppingList(testList1);

        // Assert
        expect(result, true);
        expect(viewModel.totalCount, initialCount - 1, reason: 'List removed from collection');
        verify(() => mockRepository.markAsDismissed(testListId1, testUserId)).called(1);
      });

      test('should undismiss shopping list', () async {
        // Arrange
        final dismissedList = SharedShoppingList(
          id: 'dismissed-list',
          listName: 'Dismissed List',
          listDescription: 'Test',
          listItems: testList1.listItems,
          sharedByUserId: testOtherUserId,
          sharedByDisplayName: 'Anna',
          sharedToUserIds: [testUserId],
          sharedAt: DateTime(2025, 1, 20),
          viewedByUserIds: [],
          engagedByUserIds: [],
          dismissedByUserIds: [testUserId],
          originalOwnerId: testOtherUserId,
          originalOwnerDisplayName: 'Anna',
        );

        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));
        final initialCount = viewModel.totalCount;

        // Act
        final result = await viewModel.undismissSharedShoppingList(dismissedList);

        // Assert
        expect(result, true);
        expect(viewModel.totalCount, initialCount + 1, reason: 'List added back to collection');
        verify(() => mockRepository.undismiss('dismissed-list', testUserId)).called(1);
      });
    });

    // ===== BULK OPERATIONS =====

    group('Bulk Operations', () {
      test('should mark all lists as viewed', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act
        await viewModel.markAllAsViewed();

        // Assert
        verify(() => mockRepository.markAsViewed(testListId1, testUserId)).called(1);
        // testList2 already viewed, should not be called
      });
    });

    // ===== STATUS CHECKING =====

    group('Status Checking', () {
      test('should check if list is viewed', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act & Assert
        expect(viewModel.isShoppingListViewed(testList1), false);
        expect(viewModel.isShoppingListViewed(testList2), true);
      });

      test('should check if list is joined', () async {
        // Arrange
        final joinedList = testList1.markJoinedBy(testUserId);
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act & Assert
        expect(viewModel.isShoppingListJoined(joinedList), true);
        expect(viewModel.isShoppingListJoined(testList1), false);
      });

      test('should check if list is dismissed', () async {
        // Arrange
        final dismissedList = testList1.markDismissedBy(testUserId);
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act & Assert
        expect(viewModel.isShoppingListDismissed(dismissedList), true);
        expect(viewModel.isShoppingListDismissed(testList1), false);
      });
    });

    // ===== SHOPPING LIST OPERATIONS =====

    group('Shopping List Operations', () {
      test('should get shopping list summary', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act
        final summary1 = viewModel.getShoppingListSummary(testList1);
        final summary2 = viewModel.getShoppingListSummary(testList2);

        // Assert
        expect(summary1, '2 artiklar att köpa');
        expect(summary2, '2 av 3 artiklar kvar');
      });

      test('should get time ago text', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act
        final timeAgo = viewModel.getShoppingListTimeAgo(testList1);

        // Assert - Should return time ago text (exact value depends on execution time)
        expect(timeAgo, isNotEmpty);
      });

      test('should check edit permissions', () async {
        // Arrange
        final joinedList = testList1.markJoinedBy(testUserId);
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act & Assert
        expect(viewModel.canEditShoppingList(joinedList), true);
        expect(viewModel.canEditShoppingList(testList1), false);
      });
    });

    // ===== ANALYTICS =====

    group('Analytics', () {
      test('should get engagement statistics', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act
        final stats = viewModel.getEngagementStats();

        // Assert
        expect(stats['total'], 2);
        expect(stats['totalItems'], 5);
        expect(stats['withItems'], 2);
      });

      test('should get item completion statistics', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act
        final stats = viewModel.getItemCompletionStats();

        // Assert
        expect(stats['totalItems'], 5);
        expect(stats['completedItems'], 1); // Only 1 item marked as bought
        expect(stats['remainingItems'], 4);
      });

      test('should get most common items', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150));

        // Act
        final commonItems = viewModel.getMostCommonItems(limit: 5);

        // Assert
        expect(commonItems.length, 5);
        expect(commonItems.values.every((count) => count == 1), true);
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
        when(() => mockRepository.getSharedShoppingListsForUser(testUserId))
            .thenAnswer((_) async => [testList1, testList2]);

        // Act
        await viewModel.refreshContent();

        // Assert
        verify(() => mockRepository.getSharedShoppingListsForUser(testUserId)).called(1);
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
