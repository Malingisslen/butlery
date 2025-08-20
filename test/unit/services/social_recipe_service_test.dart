import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/di/test_service_locator.dart';

// ============= LOCAL MOCKS =============
// Only for classes not in production_mocks.dart

class FakeSharedRecipe extends Fake implements SharedRecipe {
  @override
  final String id;
  @override
  final String originalRecipeId;
  @override
  final String sharedByUserId;
  @override
  final String sharedByDisplayName;
  @override
  final List<String> sharedToUserIds;
  @override
  final DateTime sharedAt;
  @override
  final Recipe recipeSnapshot;
  final List<String> _viewedByUserIds;
  final List<String> _dismissedByUserIds;
  
  FakeSharedRecipe({
    required this.id,
    required this.originalRecipeId,
    required this.sharedByUserId,
    required this.sharedByDisplayName,
    required this.sharedToUserIds,
    required this.recipeSnapshot,
    DateTime? sharedAt,
    List<String>? viewedByUserIds,
    List<String>? dismissedByUserIds,
  }) : sharedAt = sharedAt ?? DateTime.now(),
       _viewedByUserIds = viewedByUserIds ?? [],
       _dismissedByUserIds = dismissedByUserIds ?? [];
  
  @override
  bool isDismissedBy(String userId) => _dismissedByUserIds.contains(userId);
  
  @override
  SharedRecipe markViewedBy(String userId) {
    if (!_viewedByUserIds.contains(userId)) {
      _viewedByUserIds.add(userId);
    }
    return this;
  }
}

class FakeSharedMenu extends Fake implements SharedMenu {
  @override
  final String id;
  
  final String originalMenuId; // Not part of SharedMenu interface
  @override
  final String sharedByUserId;
  @override
  final String sharedByDisplayName;
  @override
  final List<String> sharedToUserIds;
  @override
  final DateTime sharedAt;
  @override
  final Map<String, List<Recipe>> menuSnapshot;
  final List<String> _viewedByUserIds;
  final List<String> _dismissedByUserIds;
  
  FakeSharedMenu({
    required this.id,
    required this.originalMenuId,
    required this.sharedByUserId,
    required this.sharedByDisplayName,
    required this.sharedToUserIds,
    required this.menuSnapshot,
    DateTime? sharedAt,
    List<String>? viewedByUserIds,
    List<String>? dismissedByUserIds,
  }) : sharedAt = sharedAt ?? DateTime.now(),
       _viewedByUserIds = viewedByUserIds ?? [],
       _dismissedByUserIds = dismissedByUserIds ?? [];
  
  @override
  bool isDismissedBy(String userId) => _dismissedByUserIds.contains(userId);
  
  @override
  SharedMenu markViewedBy(String userId) {
    if (!_viewedByUserIds.contains(userId)) {
      _viewedByUserIds.add(userId);
    }
    return this;
  }
}

// ============= TESTS =============

void main() {
  group('SocialRecipeService', () {
    late SocialRecipeService socialRecipeService;
    late MockSocialRecipeRepository mockRepository;
    late MockUnifiedRecipeService mockRecipeService;
    late MockUserService mockUserService;
    late MockPermissionService mockPermissionService;
    late MockPersonalRecipeOperations mockPersonalOps;
    late Recipe testRecipe;
    late FakeSharedRecipe testSharedRecipe;
    late FakeSharedMenu testSharedMenu;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
    });
    
    setUp(() {
      // Create mocks
      mockRepository = MockSocialRecipeRepository();
      mockRecipeService = MockUnifiedRecipeService();
      mockUserService = MockUserService();
      mockPermissionService = MockPermissionService();
      mockPersonalOps = MockPersonalRecipeOperations();
      
      // Create test data
      testRecipe = RecipeFactory.build(
        id: 'test-recipe-1',
        title: 'Köttbullar',
        description: 'Svenska köttbullar',
        ingredients: ['500g köttfärs', '1 dl ströbröd'],
        instructions: ['Blanda', 'Forma', 'Stek'],
      );
      
      testSharedRecipe = FakeSharedRecipe(
        id: 'shared-recipe-1',
        originalRecipeId: 'test-recipe-1',
        sharedByUserId: 'user-1',
        sharedByDisplayName: 'Anna Andersson',
        sharedToUserIds: ['user-2', 'user-3'],
        recipeSnapshot: testRecipe,
      );
      
      testSharedMenu = FakeSharedMenu(
        id: 'shared-menu-1',
        originalMenuId: 'menu-1',
        sharedByUserId: 'user-1',
        sharedByDisplayName: 'Anna Andersson',
        sharedToUserIds: ['user-2', 'user-3'],
        menuSnapshot: {
          'Måndag': [testRecipe],
          'Tisdag': [RecipeFactory.build(title: 'Pasta')],
        },
      );
      
      // Configure permission service using state methods
      mockPermissionService.setPermissionState(
        currentUserId: 'current-user',
        defaultHasPermission: true,
      );
      // Note: isAuthenticated is properly configured via setPermissionState above
      // Configure personal operations on the recipe service
      mockRecipeService.setRecipeState(
        personalOperations: mockPersonalOps,
      );
      
      // Setup repository stubs
      when(() => mockRepository.getSharedRecipes(any()))
          .thenAnswer((_) async => [testSharedRecipe]);
      when(() => mockRepository.getSharedMenus(any()))
          .thenAnswer((_) async => [testSharedMenu]);
      
      // Create service
      socialRecipeService = SocialRecipeService(
        repository: mockRepository,
        userService: mockUserService,
        recipeService: mockRecipeService,
        permissionService: mockPermissionService,
      );
    });
    
    tearDown(() {
      TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });
    
    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });
    
    group('Initialization', () {
      test('should initialize successfully when authenticated', () async {
        // Act
        await socialRecipeService.initialize();
        
        // Assert
        expect(socialRecipeService.sharedRecipes, hasLength(1));
        expect(socialRecipeService.sharedMenus, hasLength(1));
        expect(socialRecipeService.isLoading, isFalse);
        expect(socialRecipeService.hasError, isFalse);
        verify(() => mockRepository.getSharedRecipes('current-user')).called(1);
        verify(() => mockRepository.getSharedMenus('current-user')).called(1);
      });
      
      test('should skip loading when not authenticated', () async {
        // Arrange
        mockPermissionService.setPermissionState(
          currentUserId: null,  // Setting to null makes isAuthenticated return false
          defaultHasPermission: true,
        );
        
        // Act
        await socialRecipeService.initialize();
        
        // Assert
        expect(socialRecipeService.sharedRecipes, isEmpty);
        expect(socialRecipeService.sharedMenus, isEmpty);
        verifyNever(() => mockRepository.getSharedRecipes(any()));
        verifyNever(() => mockRepository.getSharedMenus(any()));
      });
      
      test('should handle repository errors gracefully', () async {
        // Arrange
        when(() => mockRepository.getSharedRecipes(any()))
            .thenAnswer((_) async => throw Exception('Repository error'));
        
        // Act
        await socialRecipeService.initialize();
        
        // Assert
        // Error is caught internally, so service should still work but with empty data
        expect(socialRecipeService.hasError, isFalse);
        expect(socialRecipeService.sharedRecipes, isEmpty);
        expect(socialRecipeService.sharedMenus, isEmpty);
      });
      
      test('should set loading states correctly during initialization', () async {
        // Arrange
        bool loadingDuringOperation = false;
        socialRecipeService.addListener(() {
          if (socialRecipeService.isLoading) {
            loadingDuringOperation = true;
          }
        });
        
        // Act
        await socialRecipeService.initialize();
        
        // Assert
        expect(loadingDuringOperation, isTrue);
        expect(socialRecipeService.isLoading, isFalse);
      });
    });
    
    group('Visibility Management', () {
      test('should filter visible shared recipes', () async {
        // Arrange
        await socialRecipeService.initialize();
        final dismissedRecipe = FakeSharedRecipe(
          id: 'dismissed-recipe',
          originalRecipeId: 'recipe-2',
          sharedByUserId: 'user-1',
          sharedByDisplayName: 'Test User',
          sharedToUserIds: ['current-user'],
          recipeSnapshot: testRecipe,
          dismissedByUserIds: ['current-user'],
        );
        
        when(() => mockRepository.getSharedRecipes(any()))
            .thenAnswer((_) async => [testSharedRecipe, dismissedRecipe]);
        await socialRecipeService.refresh();
        
        // Act
        final visible = socialRecipeService.getVisibleSharedRecipes('current-user');
        
        // Assert
        expect(visible, hasLength(1));
        expect(visible.first.id, equals('shared-recipe-1'));
      });
      
      test('should filter visible shared menus', () async {
        // Arrange
        await socialRecipeService.initialize();
        final dismissedMenu = FakeSharedMenu(
          id: 'dismissed-menu',
          originalMenuId: 'menu-2',
          sharedByUserId: 'user-1',
          sharedByDisplayName: 'Test User',
          sharedToUserIds: ['current-user'],
          menuSnapshot: {},
          dismissedByUserIds: ['current-user'],
        );
        
        when(() => mockRepository.getSharedMenus(any()))
            .thenAnswer((_) async => [testSharedMenu, dismissedMenu]);
        await socialRecipeService.refresh();
        
        // Act
        final visible = socialRecipeService.getVisibleSharedMenus('current-user');
        
        // Assert
        expect(visible, hasLength(1));
        expect(visible.first.id, equals('shared-menu-1'));
      });
    });
    
    group('View Tracking', () {
      test('should mark shared recipe as viewed', () async {
        // Arrange
        await socialRecipeService.initialize();
        when(() => mockRepository.markSharedRecipeAsViewed(any(), any()))
            .thenAnswer((_) async {});
        
        // Act
        final result = await socialRecipeService.markSharedRecipeAsViewed(
          'shared-recipe-1',
          'current-user',
        );
        
        // Assert
        expect(result, isTrue);
        verify(() => mockRepository.markSharedRecipeAsViewed(
          'shared-recipe-1',
          'current-user',
        )).called(1);
      });
      
      test('should mark shared menu as viewed', () async {
        // Arrange
        await socialRecipeService.initialize();
        when(() => mockRepository.markSharedMenuAsViewed(any(), any()))
            .thenAnswer((_) async {});
        
        // Act
        final result = await socialRecipeService.markSharedMenuAsViewed(
          'shared-menu-1',
          'current-user',
        );
        
        // Assert
        expect(result, isTrue);
        verify(() => mockRepository.markSharedMenuAsViewed(
          'shared-menu-1',
          'current-user',
        )).called(1);
      });
      
      test('should handle view tracking errors', () async {
        // Arrange
        await socialRecipeService.initialize();
        when(() => mockRepository.markSharedRecipeAsViewed(any(), any()))
            .thenAnswer((_) async => throw Exception('View tracking error'));
        
        // Act
        final result = await socialRecipeService.markSharedRecipeAsViewed(
          'shared-recipe-1',
          'current-user',
        );
        
        // Assert
        expect(result, isFalse);
      });
    });
    
    group('Import Functionality', () {
      test('should import shared recipe successfully', () async {
        // Arrange
        await socialRecipeService.initialize();
        when(() => mockPersonalOps.createRecipe(
          title: any(named: 'title'),
          description: any(named: 'description'),
          ingredients: any(named: 'ingredients'),
          instructions: any(named: 'instructions'),
          imageUrls: any(named: 'imageUrls'),
          mealType: any(named: 'mealType'),
          portions: any(named: 'portions'),
          timeMinutes: any(named: 'timeMinutes'),
          tags: any(named: 'tags'),
          rating: any(named: 'rating'),
        )).thenAnswer((_) async => 'new-recipe-id');
        
        when(() => mockRepository.markSharedRecipeAsImported(any(), any()))
            .thenAnswer((_) async {});
        
        // Act
        final result = await socialRecipeService.importSharedRecipe('shared-recipe-1');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockPersonalOps.createRecipe(
          title: 'Köttbullar',
          description: 'Svenska köttbullar',
          ingredients: ['500g köttfärs', '1 dl ströbröd'],
          instructions: ['Blanda', 'Forma', 'Stek'],
          imageUrls: [],
          mealType: 'Lunch',
          portions: 4,
          timeMinutes: 30,
          rating: 4.5,
          tags: ['test', 'recipe'],
          sourceUrl: null,
        )).called(1);
        verify(() => mockRepository.markSharedRecipeAsImported(
          'shared-recipe-1',
          'current-user',
        )).called(1);
      });
      
      test('should return false when recipe not found', () async {
        // Arrange
        await socialRecipeService.initialize();
        
        // Act
        final result = await socialRecipeService.importSharedRecipe('non-existent');
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockPersonalOps.createRecipe(
          title: any(named: 'title'),
          description: any(named: 'description'),
          ingredients: any(named: 'ingredients'),
          instructions: any(named: 'instructions'),
          imageUrls: any(named: 'imageUrls'),
          mealType: any(named: 'mealType'),
        ));
      });
      
      test('should handle import errors gracefully', () async {
        // Arrange
        await socialRecipeService.initialize();
        when(() => mockPersonalOps.createRecipe(
          title: any(named: 'title'),
          description: any(named: 'description'),
          ingredients: any(named: 'ingredients'),
          instructions: any(named: 'instructions'),
          imageUrls: any(named: 'imageUrls'),
          mealType: any(named: 'mealType'),
          portions: any(named: 'portions'),
          timeMinutes: any(named: 'timeMinutes'),
          tags: any(named: 'tags'),
          rating: any(named: 'rating'),
        )).thenAnswer((_) async => throw Exception('Import error'));
        
        // Act
        final result = await socialRecipeService.importSharedRecipe('shared-recipe-1');
        
        // Assert
        expect(result, isFalse);
      });
      
      test('should import shared menu successfully', () async {
        // Arrange
        await socialRecipeService.initialize();
        when(() => mockPersonalOps.createRecipe(
          title: any(named: 'title'),
          description: any(named: 'description'),
          ingredients: any(named: 'ingredients'),
          instructions: any(named: 'instructions'),
          imageUrls: any(named: 'imageUrls'),
          mealType: any(named: 'mealType'),
          portions: any(named: 'portions'),
          timeMinutes: any(named: 'timeMinutes'),
          tags: any(named: 'tags'),
          rating: any(named: 'rating'),
        )).thenAnswer((_) async => 'new-recipe-id');
        
        when(() => mockRepository.markSharedMenuAsImported(any(), any()))
            .thenAnswer((_) async {});
        
        // Act
        final result = await socialRecipeService.importSharedMenu('shared-menu-1');
        
        // Assert
        expect(result, isTrue);
        // Should be called twice - once for each recipe in the menu
        verify(() => mockPersonalOps.createRecipe(
          title: any(named: 'title'),
          description: any(named: 'description'),
          ingredients: any(named: 'ingredients'),
          instructions: any(named: 'instructions'),
          imageUrls: any(named: 'imageUrls'),
          mealType: any(named: 'mealType'),
          portions: any(named: 'portions'),
          timeMinutes: any(named: 'timeMinutes'),
          rating: any(named: 'rating'),
          tags: any(named: 'tags'),
          sourceUrl: any(named: 'sourceUrl'),
        )).called(2); // Two recipes in the menu
        verify(() => mockRepository.markSharedMenuAsImported(
          'shared-menu-1',
          'current-user',
        )).called(1);
      });
    });
    
    group('Dismissal Management', () {
      test('should dismiss shared recipe', () async {
        // Arrange
        await socialRecipeService.initialize();
        when(() => mockRepository.dismissSharedRecipe(any(), any()))
            .thenAnswer((_) async {});
        
        // Act
        final result = await socialRecipeService.dismissSharedRecipe('shared-recipe-1');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockRepository.dismissSharedRecipe(
          'shared-recipe-1',
          'current-user',
        )).called(1);
      });
      
      test('should dismiss shared menu', () async {
        // Arrange
        await socialRecipeService.initialize();
        when(() => mockRepository.dismissSharedMenu(any(), any()))
            .thenAnswer((_) async {});
        
        // Act
        final result = await socialRecipeService.dismissSharedMenu('shared-menu-1');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockRepository.dismissSharedMenu(
          'shared-menu-1',
          'current-user',
        )).called(1);
      });
      
      test('should undismiss shared recipe', () async {
        // Arrange
        when(() => mockRepository.undismissSharedRecipe(any(), any()))
            .thenAnswer((_) async {});
        
        // Act
        final result = await socialRecipeService.undismissSharedRecipe('shared-recipe-1');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockRepository.undismissSharedRecipe(
          'shared-recipe-1',
          'current-user',
        )).called(1);
      });
      
      test('should undismiss shared menu', () async {
        // Arrange
        when(() => mockRepository.undismissSharedMenu(any(), any()))
            .thenAnswer((_) async {});
        
        // Act
        final result = await socialRecipeService.undismissSharedMenu('shared-menu-1');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockRepository.undismissSharedMenu(
          'shared-menu-1',
          'current-user',
        )).called(1);
      });
      
      test('should handle dismissal when not authenticated', () async {
        // Arrange
        mockPermissionService.setPermissionState(
          currentUserId: null,  // Setting to null makes isAuthenticated return false
          defaultHasPermission: true,
        );
        
        // Act
        final result = await socialRecipeService.dismissSharedRecipe('shared-recipe-1');
        
        // Assert
        expect(result, isFalse);
        expect(socialRecipeService.error, contains('not authenticated'));
        verifyNever(() => mockRepository.dismissSharedRecipe(any(), any()));
      });
    });
    
    group('Content Sharing', () {
      test('should share content to friend', () async {
        // Arrange
        when(() => mockRepository.shareContent(
          fromUserId: any(named: 'fromUserId'),
          toUserId: any(named: 'toUserId'),
          contentType: any(named: 'contentType'),
          contentData: any(named: 'contentData'),
        )).thenAnswer((_) async {});
        
        // Act
        await socialRecipeService.shareContent(
          friendId: 'friend-1',
          contentType: 'recipe',
          contentData: {'recipeId': 'test-recipe-1'},
        );
        
        // Assert
        verify(() => mockRepository.shareContent(
          fromUserId: 'current-user',
          toUserId: 'friend-1',
          contentType: 'recipe',
          contentData: {'recipeId': 'test-recipe-1'},
        )).called(1);
      });
      
      test('should throw when sharing without authentication', () async {
        // Arrange
        mockPermissionService.setPermissionState(
          currentUserId: null,  // Setting to null makes isAuthenticated return false
          defaultHasPermission: true,
        );
        
        // Act & Assert
        await expectLater(
          socialRecipeService.shareContent(
            friendId: 'friend-1',
            contentType: 'recipe',
            contentData: {},
          ),
          throwsA(isA<Exception>()),
        );
        
        verifyNever(() => mockRepository.shareContent(
          fromUserId: any(named: 'fromUserId'),
          toUserId: any(named: 'toUserId'),
          contentType: any(named: 'contentType'),
          contentData: any(named: 'contentData'),
        ));
      });
      
      test('should share recipe to multiple friends', () async {
        // Arrange
        when(() => mockRepository.shareContent(
          fromUserId: any(named: 'fromUserId'),
          toUserId: any(named: 'toUserId'),
          contentType: any(named: 'contentType'),
          contentData: any(named: 'contentData'),
        )).thenAnswer((_) async {});
        
        // Act
        await socialRecipeService.shareRecipeToFriends(
          'test-recipe-1',
          ['friend-1', 'friend-2', 'friend-3'],
        );
        
        // Assert
        verify(() => mockRepository.shareContent(
          fromUserId: 'current-user',
          toUserId: any(named: 'toUserId'),
          contentType: 'recipe',
          contentData: {'recipeId': 'test-recipe-1'},
        )).called(3);
      });
    });
    
    group('Participant Management', () {
      test('should get recipe participants', () async {
        // Arrange
        await socialRecipeService.initialize();
        final userProfiles = [
          UserProfile(
            uid: 'user-1',
            displayName: 'Anna Andersson',
            email: 'anna@test.com',
            joinedAt: DateTime.now(),
            lastActiveAt: DateTime.now(),
          ),
          UserProfile(
            uid: 'user-2',
            displayName: 'Erik Eriksson',
            email: 'erik@test.com',
            joinedAt: DateTime.now(),
            lastActiveAt: DateTime.now(),
          ),
        ];
        
        when(() => mockUserService.getUserProfiles(any()))
            .thenAnswer((_) async => userProfiles);
        
        // Act
        final participants = await socialRecipeService.getRecipeParticipants('shared-recipe-1');
        
        // Assert
        expect(participants, hasLength(2));
        verify(() => mockUserService.getUserProfiles(
          ['user-1', 'user-2', 'user-3'],
        )).called(1);
      });
      
      test('should get menu participants', () async {
        // Arrange
        await socialRecipeService.initialize();
        final userProfiles = [
          UserProfile(
            uid: 'user-1',
            displayName: 'Anna Andersson',
            email: 'anna@test.com',
            joinedAt: DateTime.now(),
            lastActiveAt: DateTime.now(),
          ),
        ];
        
        when(() => mockUserService.getUserProfiles(any()))
            .thenAnswer((_) async => userProfiles);
        
        // Act
        final participants = await socialRecipeService.getMenuParticipants('shared-menu-1');
        
        // Assert
        expect(participants, hasLength(1));
        verify(() => mockUserService.getUserProfiles(
          ['user-1', 'user-2', 'user-3'],
        )).called(1);
      });
      
      test('should return empty list for non-existent recipe', () async {
        // Arrange
        await socialRecipeService.initialize();
        
        // Act
        final participants = await socialRecipeService.getRecipeParticipants('non-existent');
        
        // Assert
        expect(participants, isEmpty);
        verifyNever(() => mockUserService.getUserProfiles(any()));
      });
    });
    
    group('Ownership Checks', () {
      test('should check if recipe is shared by user', () async {
        // Arrange
        await socialRecipeService.initialize();
        
        // Act
        final isSharedByUser1 = await socialRecipeService.isRecipeSharedByUser(
          'shared-recipe-1',
          'user-1',
        );
        final isSharedByUser2 = await socialRecipeService.isRecipeSharedByUser(
          'shared-recipe-1',
          'user-2',
        );
        
        // Assert
        expect(isSharedByUser1, isTrue);
        expect(isSharedByUser2, isFalse);
      });
      
      test('should check if menu is shared by user', () async {
        // Arrange
        await socialRecipeService.initialize();
        
        // Act
        final isSharedByUser = await socialRecipeService.isMenuSharedByUser(
          'shared-menu-1',
          'user-1',
        );
        
        // Assert
        expect(isSharedByUser, isTrue);
      });
    });
    
    group('Compatibility Getters', () {
      test('should provide backward compatibility getters', () async {
        // Arrange
        await socialRecipeService.initialize();
        
        // Assert
        expect(socialRecipeService.sharedWithMe, equals(socialRecipeService.sharedRecipes));
        expect(socialRecipeService.recipesSharedWithMe, equals(socialRecipeService.sharedRecipes));
        expect(socialRecipeService.menusSharedWithMe, equals(socialRecipeService.sharedMenus));
      });
    });
    
    group('Edge Cases', () {
      test('should handle null personal operations gracefully', () async {
        // Arrange
        await socialRecipeService.initialize();
        when(() => mockPersonalOps.createRecipe(
          title: any(named: 'title'),
          description: any(named: 'description'),
          ingredients: any(named: 'ingredients'),
          instructions: any(named: 'instructions'),
          imageUrls: any(named: 'imageUrls'),
          mealType: any(named: 'mealType'),
          portions: any(named: 'portions'),
          timeMinutes: any(named: 'timeMinutes'),
          tags: any(named: 'tags'),
          rating: any(named: 'rating'),
        )).thenAnswer((_) async => null); // Returns null indicating failure
        
        // Act
        final result = await socialRecipeService.importSharedRecipe('shared-recipe-1');
        
        // Assert
        expect(result, isFalse);
      });
      
      test('should handle concurrent refresh calls', () async {
        // Arrange
        await socialRecipeService.initialize();
        
        // Act
        final future1 = socialRecipeService.refresh();
        final future2 = socialRecipeService.refresh();
        await Future.wait([future1, future2]);
        
        // Assert
        verify(() => mockRepository.getSharedRecipes(any())).called(3); // 1 init + 2 refresh
      });
      
      test('should handle empty shared content lists', () async {
        // Arrange
        when(() => mockRepository.getSharedRecipes(any()))
            .thenAnswer((_) async => []);
        when(() => mockRepository.getSharedMenus(any()))
            .thenAnswer((_) async => []);
        
        // Act
        await socialRecipeService.initialize();
        
        // Assert
        expect(socialRecipeService.sharedRecipes, isEmpty);
        expect(socialRecipeService.sharedMenus, isEmpty);
        expect(socialRecipeService.hasError, isFalse);
      });
    });
    
    group('Performance', () {
      test('should handle large lists efficiently', () async {
        // Arrange
        final largeRecipeList = List.generate(
          100,
          (i) => FakeSharedRecipe(
            id: 'shared-$i',
            originalRecipeId: 'recipe-$i',
            sharedByUserId: 'user-$i',
            sharedByDisplayName: 'User $i',
            sharedToUserIds: ['current-user'],
            recipeSnapshot: testRecipe,
          ),
        );
        
        when(() => mockRepository.getSharedRecipes(any()))
            .thenAnswer((_) async => largeRecipeList);
        
        // Act
        final stopwatch = Stopwatch()..start();
        await socialRecipeService.initialize();
        final visible = socialRecipeService.getVisibleSharedRecipes('current-user');
        stopwatch.stop();
        
        // Assert
        expect(visible, hasLength(100));
        expect(stopwatch.elapsedMilliseconds, lessThan(100),
               reason: 'Should process large lists quickly');
      });
    });
  });
}