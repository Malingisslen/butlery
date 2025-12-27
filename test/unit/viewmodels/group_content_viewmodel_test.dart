// test/unit/viewmodels/group_content_viewmodel_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/group_content_viewmodel.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/shared_content.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// ULTRATHINK CONVERSION COMPLETE: Local mock classes removed - using centralized mocks

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSocialSharingRepository mockSharingRepository;
  late GroupContentViewModel viewModel;
  late FriendCategory testGroup;

  setUpAll(() async {
    // Initialize test locator once
    await TestServiceLocator.initialize();

    // Centralized fallback values already registered via registerAllFallbackValues()
    registerFallbackValue(''); // For String parameters used with any()
  });

  setUp(() {
    mockSharingRepository = MockSocialSharingRepository();

    viewModel = GroupContentViewModel(
      sharingRepository: mockSharingRepository,
    );

    testGroup = FriendCategory(
      id: 'group_123',
      ownerId: 'test_user',
      name: 'Test Group',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      friendUserIds: [
        'member_1',
        'member_2',
        'member_3',
        'member_4',
        'member_5'
      ],
    );
  });

  tearDown(() {
    viewModel.dispose();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
  });

  SharedContent createSharedContent({
    String id = 'content_1',
    String contentType = 'recipe',
    String contentId = 'recipe_1',
    String ownerId = 'owner_1',
    List<String> sharedWithGroupIds = const ['group_123'],
    Map<String, dynamic>? metadata,
  }) {
    return SharedContent(
      id: id,
      contentType: contentType,
      contentId: contentId,
      ownerId: ownerId,
      sharedWithUserIds: [],
      sharedWithGroupIds: sharedWithGroupIds,
      sharedAt: DateTime.now(),
      metadata: metadata ??
          {
            'title': 'Test Recipe',
            'description': 'Test Description',
            'ingredients': ['Ingredient 1', 'Ingredient 2'],
            'instructions': ['Step 1', 'Step 2'],
            'ownerDisplayName': 'Test Owner',
            'ownerAvatarUrl': 'https://example.com/avatar.jpg',
          },
      viewedBy: {},
      acceptedBy: {},
      declinedBy: {},
      permissions: SharingPermissions(),
    );
  }

  group('GroupContentViewModel - Initialization', () {
    test('should initialize with default state', () {
      expect(viewModel.group, isNull);
      expect(viewModel.searchQuery, isEmpty);
      expect(viewModel.currentTabIndex, equals(0));
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, isNull);
      expect(viewModel.hasError, isFalse);
      expect(viewModel.isSharing, isFalse);
      expect(viewModel.hasGroupContent, isFalse);
      expect(viewModel.hasGroupActivity, isFalse);
    });

    test('should initialize with group', () async {
      final sharedContent = [
        createSharedContent(contentType: 'recipe'),
      ];

      when(() => mockSharingRepository.getSharedWithMe(any()))
          .thenAnswer((_) => Stream.value(sharedContent));

      await viewModel.initialize(testGroup);

      expect(viewModel.group, equals(testGroup));
      verify(() => mockSharingRepository.getSharedWithMe(any())).called(1);
    });
  });

  group('GroupContentViewModel - Content Loading', () {
    test('should load group content successfully', () async {
      viewModel.initialize(testGroup);

      final sharedContent = [
        createSharedContent(id: 'content_1', contentType: 'recipe'),
        createSharedContent(id: 'content_2', contentType: 'menu', metadata: {
          'title': 'Test Menu',
          'ownerDisplayName': 'Menu Owner',
          'menuSnapshot': {
            'Monday': [
              {
                'id': 'recipe_1',
                'title': 'Monday Recipe',
                'description': 'Description',
                'ingredients': ['Ingredient'],
                'instructions': ['Step'],
              }
            ],
          },
        }),
        createSharedContent(
            id: 'content_3',
            contentType: 'shopping_list',
            metadata: {
              'listName': 'Test Shopping List',
              'ownerDisplayName': 'List Owner',
            }),
      ];

      when(() => mockSharingRepository.getSharedWithMe(any()))
          .thenAnswer((_) => Stream.value(sharedContent));

      await viewModel.loadGroupContent();

      expect(viewModel.groupSharedContent.length, equals(3));
      expect(viewModel.groupSharedRecipes.length, equals(1));
      expect(viewModel.groupSharedMenus.length, equals(1));
      expect(viewModel.groupSharedShoppingLists.length, equals(1));
      expect(viewModel.hasGroupContent, isTrue);
      expect(viewModel.totalGroupContent, equals(3));
    });

    test('should filter content by group ID', () async {
      viewModel.initialize(testGroup);

      final sharedContent = [
        createSharedContent(sharedWithGroupIds: ['group_123']),
        createSharedContent(sharedWithGroupIds: ['group_456']),
        createSharedContent(sharedWithGroupIds: ['group_123', 'group_456']),
      ];

      when(() => mockSharingRepository.getSharedWithMe(any()))
          .thenAnswer((_) => Stream.value(sharedContent));

      await viewModel.loadGroupContent();

      expect(viewModel.groupSharedContent.length, equals(2));
    });

    test('should handle loading error', () async {
      viewModel.initialize(testGroup);

      when(() => mockSharingRepository.getSharedWithMe(any()))
          .thenThrow(Exception('Loading failed'));

      await viewModel.loadGroupContent();

      expect(viewModel.hasError, isTrue);
      expect(viewModel.error, contains('Kunde inte ladda gruppinnehåll'));
      expect(viewModel.isLoading, isFalse);
    });

    test('should generate activity feed from shared content', () async {
      viewModel.initialize(testGroup);

      final sharedContent = [
        createSharedContent(
          id: 'content_1',
          contentType: 'recipe',
          metadata: {
            'title': 'Recipe 1',
            'ownerDisplayName': 'User 1',
          },
        ),
        createSharedContent(
          id: 'content_2',
          contentType: 'menu',
          metadata: {
            'title': 'Menu 1',
            'ownerDisplayName': 'User 2',
          },
        ),
      ];

      when(() => mockSharingRepository.getSharedWithMe(any()))
          .thenAnswer((_) => Stream.value(sharedContent));

      await viewModel.loadGroupContent();

      expect(viewModel.groupActivityFeed.length, equals(2));
      expect(viewModel.hasGroupActivity, isTrue);

      final activity = viewModel.groupActivityFeed.first;
      expect(activity['type'], isNotNull);
      expect(activity['title'], isNotNull);
      expect(activity['ownerName'], isNotNull);
      expect(activity['action'], equals('shared_to_group'));
      expect(activity['groupName'], equals('Test Group'));
    });
  });

  group('GroupContentViewModel - Search and Filtering', () {
    setUp(() async {
      viewModel.initialize(testGroup);

      final sharedContent = [
        createSharedContent(
          contentType: 'recipe',
          metadata: {
            'title': 'Pasta Carbonara',
            'description': 'Italian classic',
            'ownerDisplayName': 'Chef Anna',
            'ingredients': ['Pasta', 'Eggs', 'Bacon'],
            'instructions': ['Cook pasta', 'Mix eggs'],
          },
        ),
        createSharedContent(
          contentType: 'recipe',
          metadata: {
            'title': 'Vegetarian Soup',
            'description': 'Healthy soup',
            'ownerDisplayName': 'Chef Erik',
            'ingredients': ['Vegetables', 'Broth'],
            'instructions': ['Chop vegetables', 'Simmer'],
          },
        ),
      ];

      when(() => mockSharingRepository.getSharedWithMe(any()))
          .thenAnswer((_) => Stream.value(sharedContent));

      await viewModel.loadGroupContent();
    });

    test('should update search query', () {
      viewModel.updateSearchQuery('pasta');

      expect(viewModel.searchQuery, equals('pasta'));
      expect(viewModel.filteredGroupRecipes.length, equals(1));
      expect(
          viewModel.filteredGroupRecipes.first.recipeTitle, contains('Pasta'));
    });

    test('should filter recipes by title', () {
      viewModel.updateSearchQuery('carbonara');

      expect(viewModel.filteredGroupRecipes.length, equals(1));
    });

    test('should filter recipes by description', () {
      viewModel.updateSearchQuery('italian');

      expect(viewModel.filteredGroupRecipes.length, equals(1));
    });

    test('should filter recipes by owner name', () {
      viewModel.updateSearchQuery('anna');

      expect(viewModel.filteredGroupRecipes.length, equals(1));
    });

    test('should clear search', () {
      viewModel.updateSearchQuery('pasta');
      expect(viewModel.searchQuery, equals('pasta'));

      viewModel.clearSearch();

      expect(viewModel.searchQuery, isEmpty);
      expect(viewModel.filteredGroupRecipes.length, equals(2));
    });

    test('should return all items when search is empty', () {
      expect(viewModel.filteredGroupRecipes.length, equals(2));
    });
  });

  group('GroupContentViewModel - Tab Management', () {
    test('should set tab index', () {
      expect(viewModel.currentTabIndex, equals(0));

      viewModel.setTabIndex(1);
      expect(viewModel.currentTabIndex, equals(1));

      viewModel.setTabIndex(2);
      expect(viewModel.currentTabIndex, equals(2));
    });

    test('should not notify if tab index is same', () {
      var notificationCount = 0;
      viewModel.addListener(() => notificationCount++);

      viewModel.setTabIndex(0);
      expect(notificationCount, equals(0));

      viewModel.setTabIndex(1);
      expect(notificationCount, equals(1));
    });
  });

  group('GroupContentViewModel - Content Sharing', () {
    test('should share content to group successfully', () async {
      viewModel.initialize(testGroup);

      final content = createSharedContent();

      when(() => mockSharingRepository.shareToGroup(any(), any()))
          .thenAnswer((_) async => {});
      when(() => mockSharingRepository.getSharedWithMe(any()))
          .thenAnswer((_) => Stream.value([content]));

      final success = await viewModel.shareContentToGroup(content);

      expect(success, isTrue);
      expect(viewModel.isSharing, isFalse);
      verify(() => mockSharingRepository.shareToGroup(testGroup.id, content))
          .called(1);
    });

    test('should handle share error', () async {
      viewModel.initialize(testGroup);

      final content = createSharedContent();

      when(() => mockSharingRepository.shareToGroup(any(), any()))
          .thenThrow(Exception('Share failed'));

      final success = await viewModel.shareContentToGroup(content);

      expect(success, isFalse);
      expect(viewModel.hasError, isTrue);
      expect(
          viewModel.error, contains('Kunde inte dela innehåll till gruppen'));
      expect(viewModel.isSharing, isFalse);
    });

    test('should not share without group', () async {
      final content = createSharedContent();

      final success = await viewModel.shareContentToGroup(content);

      expect(success, isFalse);
      verifyNever(() => mockSharingRepository.shareToGroup(any(), any()));
    });
  });

  group('GroupContentViewModel - Content Conversion', () {
    test('should convert SharedContent to SharedRecipe', () async {
      viewModel.initialize(testGroup);

      final sharedContent = [
        createSharedContent(
          contentType: 'recipe',
          metadata: {
            'title': 'Test Recipe',
            'description': 'Description',
            'ingredients': ['Ingredient 1'],
            'instructions': ['Step 1'],
            'imageUrl': 'https://example.com/image.jpg',
            'mealType': 'Middag',
            'portions': 4,
            'timeMinutes': 30,
            'rating': 4.5,
            'tags': ['vegetarisk'],
            'sourceUrl': 'https://source.com',
            'ownerDisplayName': 'Test Owner',
            'shareMessage': 'Try this!',
          },
        ),
      ];

      when(() => mockSharingRepository.getSharedWithMe(any()))
          .thenAnswer((_) => Stream.value(sharedContent));

      await viewModel.loadGroupContent();

      expect(viewModel.groupSharedRecipes.length, equals(1));

      final recipe = viewModel.groupSharedRecipes.first;
      expect(recipe.recipeTitle, equals('Test Recipe'));
      expect(recipe.sharedByDisplayName, equals('Test Owner'));
      expect(recipe.shareMessage, equals('Try this!'));
      expect(recipe.allowImport, isTrue);
    });

    test('should convert SharedContent to SharedMenu', () async {
      viewModel.initialize(testGroup);

      final sharedContent = [
        createSharedContent(
          contentType: 'menu',
          metadata: {
            'title': 'Weekly Menu',
            'ownerDisplayName': 'Menu Owner',
            'shareMessage': 'This week menu',
            'menuSnapshot': {
              'Monday': [
                {
                  'id': 'recipe_1',
                  'title': 'Monday Recipe',
                  'description': 'Description',
                  'ingredients': ['Ingredient'],
                  'instructions': ['Step'],
                  'imageUrls': ['https://example.com/image.jpg'],
                  'mealType': 'Lunch',
                  'portions': 2,
                  'timeMinutes': 20,
                  'rating': 4.0,
                  'tags': ['quick'],
                },
              ],
              'Tuesday': [],
            },
          },
        ),
      ];

      when(() => mockSharingRepository.getSharedWithMe(any()))
          .thenAnswer((_) => Stream.value(sharedContent));

      await viewModel.loadGroupContent();

      expect(viewModel.groupSharedMenus.length, equals(1));

      final menu = viewModel.groupSharedMenus.first;
      expect(menu.menuTitle, equals('Weekly Menu'));
      expect(menu.sharedByDisplayName, equals('Menu Owner'));
      expect(menu.shareMessage, equals('This week menu'));
      expect(menu.menuSnapshot.keys.length, equals(2));
      expect(menu.menuSnapshot['Monday']?.length, equals(1));
    });

    test('should convert SharedContent to UnifiedShoppingList', () async {
      viewModel.initialize(testGroup);

      final sharedContent = [
        createSharedContent(
          contentType: 'shopping_list',
          metadata: {
            'listName': 'Grocery List',
            'ownerDisplayName': 'List Owner',
          },
        ),
      ];

      when(() => mockSharingRepository.getSharedWithMe(any()))
          .thenAnswer((_) => Stream.value(sharedContent));

      await viewModel.loadGroupContent();

      expect(viewModel.groupSharedShoppingLists.length, equals(1));

      final list = viewModel.groupSharedShoppingLists.first;
      expect(list.name, equals('Grocery List'));
      expect(list.ownerDisplayName, equals('List Owner'));
    });

    test('should handle invalid content conversion gracefully', () async {
      viewModel.initialize(testGroup);

      final sharedContent = [
        createSharedContent(
          contentType: 'recipe',
          metadata: {}, // Empty metadata
        ),
      ];

      when(() => mockSharingRepository.getSharedWithMe(any()))
          .thenAnswer((_) => Stream.value(sharedContent));

      await viewModel.loadGroupContent();

      // Should still create recipe with default values
      expect(viewModel.groupSharedRecipes.length, equals(1));

      final recipe = viewModel.groupSharedRecipes.first;
      expect(recipe.recipeTitle, equals('Namnlöst recept'));
      expect(recipe.sharedByDisplayName, equals('Okänd användare'));
    });
  });

  group('GroupContentViewModel - Statistics', () {
    test('should calculate group content statistics', () async {
      viewModel.initialize(testGroup);

      final sharedContent = [
        createSharedContent(contentType: 'recipe'),
        createSharedContent(contentType: 'recipe'),
        createSharedContent(contentType: 'menu'),
        createSharedContent(contentType: 'shopping_list'),
      ];

      when(() => mockSharingRepository.getSharedWithMe(any()))
          .thenAnswer((_) => Stream.value(sharedContent));

      await viewModel.loadGroupContent();

      final stats = viewModel.groupContentStats;

      expect(stats['totalRecipes'], equals(2));
      expect(stats['totalMenus'], equals(1));
      expect(stats['totalShoppingLists'], equals(1));
      expect(stats['totalContent'], equals(4));
      expect(stats['groupMembers'], equals(5));
    });

    test('should get group sharing statistics', () async {
      viewModel.initialize(testGroup);

      final stats = await viewModel.getGroupSharingStats();

      expect(stats, isA<Map<String, dynamic>>());
    });
  });

  group('GroupContentViewModel - Refresh', () {
    test('should refresh all group content', () async {
      viewModel.initialize(testGroup);

      when(() => mockSharingRepository.getSharedWithMe(any()))
          .thenAnswer((_) => Stream.value(<SharedContent>[]));

      await viewModel.refresh();

      verify(() => mockSharingRepository.getSharedWithMe(any()))
          .called(greaterThanOrEqualTo(1));
    });
  });

  group('GroupContentViewModel - Error Handling', () {
    test('should clear error', () {
      viewModel.initialize(testGroup);

      // Set error through failed operation
      when(() => mockSharingRepository.getSharedWithMe(any()))
          .thenThrow(Exception('Test error'));

      viewModel.loadGroupContent();

      // Wait for async operation
      Future.delayed(Duration(milliseconds: 100), () {
        expect(viewModel.hasError, isTrue);

        viewModel.clearError();

        expect(viewModel.hasError, isFalse);
        expect(viewModel.error, isNull);
      });
    });
  });
}
