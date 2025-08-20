import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/unified/operations/friend_categories_operations.dart';
import 'package:butlery/services/unified/operations/friends_management_operations.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart' as app;
import 'package:mocktail/mocktail.dart';

import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/builders/user_builder.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';

// Mock for UnifiedFriendsService
class MockUnifiedFriendsService extends Mock implements UnifiedFriendsService {
  final List<FriendCategory> _categories = [];
  final List<UserProfile> _friends = [];
  final Map<String, Set<String>> _friendCategoryRelationships = {};
  String? _currentUserId;
  
  @override
  String? get currentUserId => _currentUserId;
  
  @override
  List<FriendCategory> get categoriesList => _categories;
  
  @override
  List<UserProfile> get friendsList => _friends;
  
  @override
  Map<String, Set<String>> get friendCategoryRelationshipsInternal => _friendCategoryRelationships;
  
  void setServiceState({
    String? currentUserId,
    List<FriendCategory>? categories,
    List<UserProfile>? friends,
    Map<String, Set<String>>? relationships,
  }) {
    if (currentUserId != null) _currentUserId = currentUserId;
    if (categories != null) {
      _categories.clear();
      _categories.addAll(categories);
    }
    if (friends != null) {
      _friends.clear();
      _friends.addAll(friends);
    }
    if (relationships != null) {
      _friendCategoryRelationships.clear();
      _friendCategoryRelationships.addAll(relationships);
    }
  }
  
  @override
  void addCategoryInternal(FriendCategory category) {
    _categories.add(category);
  }
  
  @override
  void updateCategoryInternal(String categoryId, FriendCategory updatedCategory) {
    final index = _categories.indexWhere((c) => c.id == categoryId);
    if (index != -1) {
      _categories[index] = updatedCategory;
    }
  }
  
  @override
  void removeCategoryInternal(String categoryId) {
    _categories.removeWhere((c) => c.id == categoryId);
  }
  
  @override
  void addFriendToCategoryInternal(String friendId, String categoryId) {
    _friendCategoryRelationships.putIfAbsent(friendId, () => {}).add(categoryId);
    
    // Also update the category's member list
    final category = _categories.firstWhere((c) => c.id == categoryId);
    if (!category.friendUserIds.contains(friendId)) {
      final updatedCategory = category.copyWith(
        friendUserIds: [...category.friendUserIds, friendId],
      );
      updateCategoryInternal(categoryId, updatedCategory);
    }
  }
  
  @override
  Future<void> syncCategoryToFirebaseInternal(FriendCategory category) async {
    // Mock implementation - just return success
    await Future.delayed(const Duration(milliseconds: 10));
  }
  
  @override
  Future<void> deleteCategoryFromFirebaseInternal(String categoryId) async {
    // Mock implementation - just return success
    await Future.delayed(const Duration(milliseconds: 10));
  }
  
  @override
  Future<void> refresh() async {
    // Mock implementation
    await Future.delayed(const Duration(milliseconds: 10));
  }
}

// Mock for FriendsManagementOperations 
class MockFriendsManagementOperations extends Mock implements FriendsManagementOperations {
  final List<String> _friendIds = [];
  
  void setFriends(List<String> friendIds) {
    _friendIds.clear();
    _friendIds.addAll(friendIds);
  }
  
  @override
  bool isFriend(String userId) {
    return _friendIds.contains(userId);
  }
}

void main() {
  group('FriendsCategoriesOperations', () {
    late FriendsCategoriesOperations operations;
    late MockUnifiedFriendsService mockParentService;
    late MockFriendsManagementOperations mockManagement;
    late List<UserProfile> testFriends;
    late List<FriendCategory> testCategories;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });
    
    setUp(() async {
      await TestServiceLocator.initialize();
      
      // Configure permission service
      final permissionService = app.ServiceLocator.get<PermissionService>();
      if (permissionService is MockPermissionService) {
        permissionService.setPermissionState(
          currentUserId: 'test-user-123',
          defaultHasPermission: true,
        );
      }
      
      // Create test friends
      testFriends = [
        UserBuilder()
            .withId('friend-1')
            .withName('Anna Andersson')
            .build(),
        UserBuilder()
            .withId('friend-2')
            .withName('Erik Eriksson')
            .build(),
        UserBuilder()
            .withId('friend-3')
            .withName('Maria Nilsson')
            .build(),
      ];
      
      // Create test categories
      testCategories = [
        FriendCategory(
          id: 'category-1',
          name: 'Family',
          description: 'Family members',
          ownerId: 'test-user-123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          friendUserIds: ['friend-1'],
        ),
        FriendCategory(
          id: 'category-2',
          name: 'Work',
          description: 'Work colleagues',
          ownerId: 'test-user-123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          friendUserIds: [],
        ),
      ];
      
      // Create mock parent service
      mockParentService = MockUnifiedFriendsService();
      mockParentService.setServiceState(
        currentUserId: 'test-user-123',
        categories: testCategories,
        friends: testFriends,
        relationships: {
          'friend-1': {'category-1'},
        },
      );
      
      // Create mock management operations
      mockManagement = MockFriendsManagementOperations();
      mockManagement.setFriends(['friend-1', 'friend-2', 'friend-3']);
      
      // Stub the management getter
      when(() => mockParentService.management).thenReturn(mockManagement);
      
      // Create operations instance
      operations = FriendsCategoriesOperations(mockParentService);
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });
    
    group('Category CRUD Operations', () {
      test('should create new category', () async {
        // Act
        final categoryId = await operations.createCategory(
          name: 'Friends',
          description: 'Close friends',
          isPrivate: false,
        );
        
        // Assert
        expect(categoryId, isNotNull);
        expect(mockParentService.categoriesList.length, equals(3));
        
        final newCategory = operations.getCategoryByName('Friends');
        expect(newCategory, isNotNull);
        expect(newCategory!.name, equals('Friends'));
        expect(newCategory.description, equals('Close friends'));
        expect(newCategory.ownerId, equals('test-user-123'));
      });
      
      test('should not create category with empty name', () async {
        // Act
        final categoryId = await operations.createCategory(
          name: '',
          description: 'Empty name',
        );
        
        // Assert
        expect(categoryId, isNull);
        expect(mockParentService.categoriesList.length, equals(2));
      });
      
      test('should not create duplicate category name', () async {
        // Act
        final categoryId = await operations.createCategory(
          name: 'Family',
          description: 'Duplicate name',
        );
        
        // Assert
        expect(categoryId, isNull);
        expect(mockParentService.categoriesList.length, equals(2));
      });
      
      test('should create category with initial members', () async {
        // Act
        final categoryId = await operations.createCategory(
          name: 'Sports Team',
          description: 'Basketball team',
          initialMemberIds: ['friend-2', 'friend-3'],
        );
        
        // Assert
        expect(categoryId, isNotNull);
        
        final category = operations.getCategoryByName('Sports Team');
        expect(category, isNotNull);
        expect(category!.friendUserIds, containsAll(['friend-2', 'friend-3']));
      });
      
      test('should update category details', () async {
        // Arrange
        final permissionService = app.ServiceLocator.get<PermissionService>();
        when(() => permissionService.isGroupAdmin('category-1'))
            .thenReturn(true);
        
        // Act
        final result = await operations.updateCategory(
          categoryId: 'category-1',
          name: 'Close Family',
          description: 'Immediate family members',
          icon: '👨‍👩‍👧‍👦',
        );
        
        // Assert
        expect(result, isTrue);
        
        final category = operations.getCategoryById('category-1');
        expect(category, isNotNull);
        expect(category!.name, equals('Close Family'));
        expect(category.description, equals('Immediate family members'));
        expect(category.emoji, equals('👨‍👩‍👧‍👦'));
      });
      
      test('should not update category with invalid ID', () async {
        // Act
        final result = await operations.updateCategory(
          categoryId: 'invalid-id',
          name: 'New Name',
        );
        
        // Assert
        expect(result, isFalse);
      });
      
      test('should delete category', () async {
        // Arrange
        final permissionService = app.ServiceLocator.get<PermissionService>();
        when(() => permissionService.canDeleteGroup('category-2'))
            .thenReturn(true);
        
        // Act
        final result = await operations.deleteCategory('category-2');
        
        // Assert
        expect(result, isTrue);
        expect(mockParentService.categoriesList.length, equals(1));
        expect(operations.getCategoryById('category-2'), isNull);
      });
      
      test('should not delete category without permission', () async {
        // Arrange
        final permissionService = app.ServiceLocator.get<PermissionService>();
        when(() => permissionService.canDeleteGroup('category-1'))
            .thenReturn(false);
        
        // Act
        final result = await operations.deleteCategory('category-1');
        
        // Assert
        expect(result, isFalse);
        expect(mockParentService.categoriesList.length, equals(2));
      });
    });
    
    group('Category Membership Operations', () {
      test('should add friend to category', () async {
        // Arrange
        final permissionService = app.ServiceLocator.get<PermissionService>();
        when(() => permissionService.isGroupAdmin('category-2'))
            .thenReturn(true);
        
        // Act
        final result = await operations.addFriendToCategory('friend-2', 'category-2');
        
        // Assert
        expect(result, isTrue);
        expect(operations.isFriendInCategory('friend-2', 'category-2'), isTrue);
        
        final category = operations.getCategoryById('category-2');
        expect(category!.friendUserIds, contains('friend-2'));
      });
      
      test('should not add non-friend to category', () async {
        // Act
        final result = await operations.addFriendToCategory('stranger-1', 'category-1');
        
        // Assert
        expect(result, isFalse);
      });
      
      test('should not add friend to non-existent category', () async {
        // Act
        final result = await operations.addFriendToCategory('friend-1', 'invalid-category');
        
        // Assert
        expect(result, isFalse);
      });
      
      test('should remove friend from category', () async {
        // Arrange
        final permissionService = app.ServiceLocator.get<PermissionService>();
        when(() => permissionService.isGroupAdmin('category-1'))
            .thenReturn(true);
        
        // Act
        final result = await operations.removeFriendFromCategory('friend-1', 'category-1');
        
        // Assert
        expect(result, isTrue);
        expect(operations.isFriendInCategory('friend-1', 'category-1'), isFalse);
        
        final category = operations.getCategoryById('category-1');
        expect(category!.friendUserIds, isNot(contains('friend-1')));
      });
      
      test('should move friend between categories', () async {
        // Arrange
        final permissionService = app.ServiceLocator.get<PermissionService>();
        when(() => permissionService.isGroupAdmin('category-1'))
            .thenReturn(true);
        when(() => permissionService.isGroupAdmin('category-2'))
            .thenReturn(true);
        
        // Act
        final result = await operations.moveFriendToCategory(
          friendId: 'friend-1',
          fromCategoryId: 'category-1',
          toCategoryId: 'category-2',
        );
        
        // Assert
        expect(result, isTrue);
        expect(operations.isFriendInCategory('friend-1', 'category-1'), isFalse);
        expect(operations.isFriendInCategory('friend-1', 'category-2'), isTrue);
      });
    });
    
    group('Bulk Operations', () {
      test('should add multiple friends to category', () async {
        // Arrange
        final permissionService = app.ServiceLocator.get<PermissionService>();
        when(() => permissionService.isGroupAdmin('category-2'))
            .thenReturn(true);
        
        // Act
        final results = await operations.addMultipleFriendsToCategory(
          ['friend-2', 'friend-3'],
          'category-2',
        );
        
        // Assert
        expect(results['friend-2'], isTrue);
        expect(results['friend-3'], isTrue);
        expect(operations.isFriendInCategory('friend-2', 'category-2'), isTrue);
        expect(operations.isFriendInCategory('friend-3', 'category-2'), isTrue);
      });
      
      test('should remove multiple friends from category', () async {
        // Arrange
        final permissionService = app.ServiceLocator.get<PermissionService>();
        when(() => permissionService.isGroupAdmin('category-1'))
            .thenReturn(true);
        
        // First add friends to remove
        await operations.addFriendToCategory('friend-2', 'category-1');
        await operations.addFriendToCategory('friend-3', 'category-1');
        
        // Act
        final results = await operations.removeMultipleFriendsFromCategory(
          ['friend-1', 'friend-2', 'friend-3'],
          'category-1',
        );
        
        // Assert
        expect(results['friend-1'], isTrue);
        expect(results['friend-2'], isTrue);
        expect(results['friend-3'], isTrue);
        expect(operations.isFriendInCategory('friend-1', 'category-1'), isFalse);
        expect(operations.isFriendInCategory('friend-2', 'category-1'), isFalse);
        expect(operations.isFriendInCategory('friend-3', 'category-1'), isFalse);
      });
      
      test('should create category with friends', () async {
        // Act
        final categoryId = await operations.createCategoryWithFriends(
          name: 'Gym Buddies',
          description: 'Workout partners',
          friendIds: ['friend-2', 'friend-3'],
        );
        
        // Assert
        expect(categoryId, isNotNull);
        
        final category = operations.getCategoryByName('Gym Buddies');
        expect(category, isNotNull);
        expect(category!.friendUserIds, containsAll(['friend-2', 'friend-3']));
      });
    });
    
    group('Category Queries', () {
      test('should get category by ID', () {
        // Act
        final category = operations.getCategoryById('category-1');
        
        // Assert
        expect(category, isNotNull);
        expect(category!.id, equals('category-1'));
        expect(category.name, equals('Family'));
      });
      
      test('should get category by name', () {
        // Act
        final category = operations.getCategoryByName('Work');
        
        // Assert
        expect(category, isNotNull);
        expect(category!.id, equals('category-2'));
        expect(category.name, equals('Work'));
      });
      
      test('should get all categories', () {
        // Act
        final categories = operations.getAllCategories();
        
        // Assert
        expect(categories.length, equals(2));
        expect(categories.map((c) => c.id), containsAll(['category-1', 'category-2']));
      });
      
      test('should get owned categories', () {
        // Act
        final categories = operations.getOwnedCategories();
        
        // Assert
        expect(categories.length, equals(2));
        expect(categories.every((c) => c.ownerId == 'test-user-123'), isTrue);
      });
      
      test('should get friends in category', () {
        // Act
        final friends = operations.getFriendsInCategory('category-1');
        
        // Assert
        expect(friends.length, equals(1));
        expect(friends.first.uid, equals('friend-1'));
        expect(friends.first.displayName, equals('Anna Andersson'));
      });
      
      test('should get categories for friend', () {
        // Act
        final categories = operations.getCategoriesForFriend('friend-1');
        
        // Assert
        expect(categories.length, equals(1));
        expect(categories.first.id, equals('category-1'));
      });
      
      test('should get uncategorized friends', () {
        // Act
        final uncategorized = operations.getUncategorizedFriends();
        
        // Assert
        expect(uncategorized.length, equals(2));
        expect(uncategorized.map((f) => f.uid), containsAll(['friend-2', 'friend-3']));
      });
    });
    
    group('Category Status Checks', () {
      test('should check if friend is in category', () {
        // Act & Assert
        expect(operations.isFriendInCategory('friend-1', 'category-1'), isTrue);
        expect(operations.isFriendInCategory('friend-2', 'category-1'), isFalse);
      });
      
      test('should get category member count', () {
        // Act & Assert
        expect(operations.getCategoryMemberCount('category-1'), equals(1));
        expect(operations.getCategoryMemberCount('category-2'), equals(0));
      });
      
      test('should check if category is empty', () {
        // Act & Assert
        expect(operations.isCategoryEmpty('category-1'), isFalse);
        expect(operations.isCategoryEmpty('category-2'), isTrue);
      });
    });
    
    group('Category Statistics', () {
      test('should get category statistics', () {
        // Act
        final stats = operations.getCategoryStats();
        
        // Assert
        expect(stats['totalCategories'], equals(2));
        expect(stats['ownedCategories'], equals(2));
        expect(stats['memberCategories'], equals(0));
        expect(stats['uncategorizedFriends'], equals(2));
        expect(stats['averageMembersPerCategory'], equals(0.5));
      });
    });
    
    group('ViewModels Compatibility', () {
      test('should get categories list', () {
        // Act
        final categories = operations.categoriesList;
        
        // Assert
        expect(categories.length, equals(2));
        expect(categories, equals(testCategories));
      });
      
      test('should assign friend to category', () async {
        // Arrange
        final permissionService = app.ServiceLocator.get<PermissionService>();
        when(() => permissionService.isGroupAdmin('category-2'))
            .thenReturn(true);
        
        // Act
        final result = await operations.assignFriendToCategory('friend-3', 'category-2');
        
        // Assert
        expect(result, isTrue);
        expect(operations.isFriendInCategory('friend-3', 'category-2'), isTrue);
      });
      
      test('should refresh categories data', () async {
        // Act & Assert - Should not throw
        await operations.refresh();
      });
    });
    
    group('Privacy Features (Not Implemented)', () {
      test('should throw UnimplementedError for privacy settings', () async {
        // Act & Assert
        expect(
          () => operations.setCategoryPrivacy('category-1', isPublic: true),
          throwsUnimplementedError,
        );
      });
    });
  });
}