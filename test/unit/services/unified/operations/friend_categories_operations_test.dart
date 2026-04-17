// test/unit/services/unified/operations/friend_categories_operations_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:butlery/services/unified/operations/friend_categories_operations.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FriendsCategoriesOperations', () {
    late MockUnifiedFriendsService mockParentService;
    late MockPermissionService mockPermissionService;
    late MockFriendsManagementOperations mockManagement;
    late FriendsCategoriesOperations operations;
    late FriendCategory testCategory1;
    late FriendCategory testCategory2;
    late UserProfile testFriend1;
    late UserProfile testFriend2;

    setUpAll(() async {
      // Register fallback values for mocktail
      registerFallbackValue(FriendCategory(
        id: 'test',
        name: 'Test',
        description: '',
        ownerId: 'test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        friendUserIds: [],
      ));
      registerFallbackValue(UserProfile(
        uid: 'test',
        displayName: 'Test',
        email: 'test@example.com',
        joinedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      ));
    });

    setUp(() async {
      await BaseUnitTest.setupUnit();

      // Bridge production ServiceLocator to GetIt so ServiceLocator.get<T>() works
      production.ServiceLocator.initialize(DIContainer());

      // Create mocks
      mockParentService = MockUnifiedFriendsService();
      mockPermissionService = MockPermissionService();
      mockManagement = MockFriendsManagementOperations();

      // Register permission service in GetIt
      final getIt = GetIt.instance;
      if (getIt.isRegistered<PermissionService>()) {
        getIt.unregister<PermissionService>();
      }
      getIt.registerSingleton<PermissionService>(mockPermissionService);

      // Create test data
      testCategory1 = FriendCategory(
        id: 'category_1',
        name: 'Arbetskamrater',
        description: 'Kollegor och arbetskamrater',
        ownerId: 'user_123',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        emoji: '💼',
        friendUserIds: [
          'friend_1'
        ], // memberIds is a getter that returns friendUserIds
      );

      testCategory2 = FriendCategory(
        id: 'category_2',
        name: 'Familj',
        description: 'Familjemedlemmar',
        ownerId: 'user_123',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        emoji: '👨‍👩‍👧‍👦',
        friendUserIds: [
          'friend_2'
        ], // memberIds is a getter that returns friendUserIds
      );

      testFriend1 = UserProfile(
        uid: 'friend_1',
        displayName: 'Friend One',
        email: 'friend1@example.com',
        joinedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );

      testFriend2 = UserProfile(
        uid: 'friend_2',
        displayName: 'Friend Two',
        email: 'friend2@example.com',
        joinedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );

      // Configure parent service mock using configuration methods
      mockParentService.setFriendsState(
        friends: [testFriend1, testFriend2],
        categoriesList: [testCategory1, testCategory2],
        management: mockManagement,
        currentUserId: 'user_123',
        currentUserDisplayName: 'Test User',
      );

      // Configure management mock using configuration methods
      mockManagement.setManagementState(
        friends: [testFriend1, testFriend2],
      );

      // Configure permission service mock
      mockPermissionService.setPermissionState(
        currentUserId: 'user_123',
        defaultHasPermission: true,
      );
      when(() => mockPermissionService.isGroupAdmin(any())).thenReturn(true);
      when(() => mockPermissionService.canDeleteGroup(any())).thenReturn(true);

      // Mock internal methods - Fix addCategoryInternal to work properly
      when(() => mockParentService.addCategoryInternal(any())).thenAnswer(
        (invocation) {
          // Simulate adding the category to the list
          final category = invocation.positionalArguments[0] as FriendCategory;
          final currentList = mockParentService.categoriesList;
          mockParentService.updateCategoriesList([...currentList, category]);
          return;
        },
      );
      when(() => mockParentService.updateCategoryInternal(any(), any()))
          .thenReturn(null);
      when(() => mockParentService.removeCategoryInternal(any()))
          .thenReturn(null);
      when(() => mockParentService.syncCategoryToFirebaseInternal(any()))
          .thenAnswer((_) async => {});
      when(() => mockParentService.deleteCategoryFromFirebaseInternal(any()))
          .thenAnswer((_) async => {});
      when(() => mockParentService.addFriendToCategoryInternal(any(), any()))
          .thenReturn(null);
      when(() => mockParentService.refresh()).thenAnswer((_) async => {});

      // Create operations instance with typed deps from mock
      operations = FriendsCategoriesOperations(
        getCurrentUserId: () => mockParentService.currentUserId,
        getCategoriesList: () => mockParentService.categoriesList,
        getFriendsList: () => mockParentService.friendsList,
        getFriendCategoryRelationshipsInternal: () =>
            mockParentService.friendCategoryRelationshipsInternal,
        addCategoryInternal: mockParentService.addCategoryInternal,
        updateCategoryInternal: mockParentService.updateCategoryInternal,
        removeCategoryInternal: mockParentService.removeCategoryInternal,
        addFriendToCategoryInternal:
            mockParentService.addFriendToCategoryInternal,
        syncCategoryToFirebaseInternal:
            mockParentService.syncCategoryToFirebaseInternal,
        deleteCategoryFromFirebaseInternal:
            mockParentService.deleteCategoryFromFirebaseInternal,
        refresh: mockParentService.refresh,
        getManagement: () => mockManagement,
        getInvitations: () =>
            mockParentService.invitations as MockFriendsInvitationsOperations,
      );
    });

    tearDown(() async {
      // Unregister permission service from GetIt
      final getIt = GetIt.instance;
      if (getIt.isRegistered<PermissionService>()) {
        getIt.unregister<PermissionService>();
      }
      BaseUnitTest.resetMocks();
    });

    group('Category CRUD Operations', () {
      test('should create category successfully', () async {
        // Arrange
        mockParentService.updateCategoriesList([]);

        // Act
        final categoryId = await operations.createCategory(
          name: 'New Category',
          description: 'Test description',
          icon: '🎯',
        );

        // Assert
        expect(categoryId, isNotNull);
        verify(() => mockParentService.addCategoryInternal(any())).called(1);
        verify(() => mockParentService.syncCategoryToFirebaseInternal(any()))
            .called(1);
      });

      test('should not create category with empty name', () async {
        // Act
        final categoryId = await operations.createCategory(
          name: '  ',
          description: 'Test description',
        );

        // Assert
        expect(categoryId, isNull);
        verifyNever(() => mockParentService.addCategoryInternal(any()));
      });

      test('should not create category with duplicate name', () async {
        // Act
        final categoryId = await operations.createCategory(
          name: 'Arbetskamrater',
          description: 'Duplicate name',
        );

        // Assert
        expect(categoryId, isNull);
        verifyNever(() => mockParentService.addCategoryInternal(any()));
      });

      test('should update category successfully', () async {
        // Act
        final result = await operations.updateCategory(
          categoryId: 'category_1',
          name: 'Updated Name',
          description: 'Updated description',
          icon: '🌟',
        );

        // Assert
        expect(result, isTrue);
        verify(() =>
                mockParentService.updateCategoryInternal('category_1', any()))
            .called(1);
        // BUG FIX: Should only call syncCategoryToFirebaseInternal once
        // (duplicate call was causing false failure even when Firebase write succeeded)
        verify(() => mockParentService.syncCategoryToFirebaseInternal(any()))
            .called(1);
      });

      test('should not update non-existent category', () async {
        // Act
        final result = await operations.updateCategory(
          categoryId: 'non_existent',
          name: 'Updated Name',
        );

        // Assert
        expect(result, isFalse);
        verifyNever(
            () => mockParentService.updateCategoryInternal(any(), any()));
      });

      test('should delete category successfully', () async {
        // Act
        final result = await operations.deleteCategory('category_1');

        // Assert
        expect(result, isTrue);
        verify(() => mockParentService
            .deleteCategoryFromFirebaseInternal('category_1')).called(1);
        verify(() => mockParentService.removeCategoryInternal('category_1'))
            .called(1);
      });

      test('should not delete without permission', () async {
        // Arrange - Use a category owned by someone else
        final otherCategory = FriendCategory(
          id: 'other_cat',
          name: 'Other',
          description: '',
          ownerId: 'other_user', // Not current user
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          friendUserIds: [],
        );
        mockParentService.updateCategoriesList(
            [testCategory1, testCategory2, otherCategory]);
        when(() => mockPermissionService.isGroupAdmin('other_cat'))
            .thenReturn(false);
        when(() => mockPermissionService.canDeleteGroup('other_cat'))
            .thenReturn(false);

        // Act
        final result = await operations.deleteCategory('other_cat');

        // Assert
        expect(result, isFalse);
        verifyNever(
            () => mockParentService.deleteCategoryFromFirebaseInternal(any()));
      });
    });

    group('Category Membership Operations', () {
      test('should add friend to category', () async {
        // Arrange - friend_2 must be in management's friends list to pass isFriend check
        mockManagement.setManagementState(
          friends: [testFriend1, testFriend2],
        );

        // Act
        final result =
            await operations.addFriendToCategory('friend_2', 'category_1');

        // Assert
        expect(result, isTrue);
        verify(() => mockParentService.addFriendToCategoryInternal(
            'friend_2', 'category_1')).called(1);
      });

      test('should not add non-friend to category', () async {
        // Act
        final result =
            await operations.addFriendToCategory('friend_3', 'category_1');

        // Assert
        expect(result, isFalse);
        verifyNever(
            () => mockParentService.addFriendToCategoryInternal(any(), any()));
      });

      test('should remove friend from category', () async {
        // Act
        final result =
            await operations.removeFriendFromCategory('friend_1', 'category_1');

        // Assert
        expect(result, isTrue);
        verify(() =>
                mockParentService.updateCategoryInternal('category_1', any()))
            .called(1);
        // Single sync call after removing friend from category
        verify(() => mockParentService.syncCategoryToFirebaseInternal(any()))
            .called(1);
      });

      test('should move friend between categories', () async {
        // Act
        final result = await operations.moveFriendToCategory(
          friendId: 'friend_1',
          fromCategoryId: 'category_1',
          toCategoryId: 'category_2',
        );

        // Assert
        expect(result, isTrue);
      });

      test('should handle moving to same category', () async {
        // Act
        final result = await operations.moveFriendToCategory(
          friendId: 'friend_1',
          fromCategoryId: 'category_1',
          toCategoryId: 'category_1',
        );

        // Assert
        expect(result, isTrue);
      });
    });

    group('Bulk Operations', () {
      test('should add multiple friends to category', () async {
        // Arrange - friend_2 must be a friend; friend_3 is not
        mockManagement.setManagementState(
          friends: [testFriend1, testFriend2],
        );

        // Act
        final results = await operations.addMultipleFriendsToCategory(
          ['friend_2', 'friend_3'],
          'category_1',
        );

        // Assert
        expect(results['friend_2'], isTrue);
        expect(results['friend_3'], isFalse);
      });

      test('should remove multiple friends from category', () async {
        // Act
        final results = await operations.removeMultipleFriendsFromCategory(
          ['friend_1', 'friend_2'],
          'category_1',
        );

        // Assert
        expect(results['friend_1'], isTrue);
        expect(results['friend_2'], isTrue);
      });

      test('should create category with initial friends', () async {
        // Arrange
        final initialCategories = <FriendCategory>[];
        mockParentService.updateCategoriesList(initialCategories);
        mockManagement.setManagementState(
          friends: [],
        );

        // Mock the addCategoryInternal to actually add the category
        when(() => mockParentService.addCategoryInternal(any())).thenAnswer(
          (invocation) {
            final category =
                invocation.positionalArguments[0] as FriendCategory;
            initialCategories.add(category);
            mockParentService.updateCategoriesList(initialCategories);
            return;
          },
        );

        // Act
        final categoryId = await operations.createCategoryWithFriends(
          name: 'New Group',
          description: 'Test group',
          friendIds: ['friend_1', 'friend_2'],
        );

        // Assert
        expect(categoryId, isNotNull);
        expect(initialCategories.length, equals(1));
        expect(initialCategories.first.name, equals('New Group'));
      });
    });

    group('Category Queries', () {
      test('should get category by ID', () {
        // Act
        final category = operations.getCategoryById('category_1');

        // Assert
        expect(category, isNotNull);
        expect(category!.name, equals('Arbetskamrater'));
      });

      test('should get category by name', () {
        // Act
        final category = operations.getCategoryByName('Familj');

        // Assert
        expect(category, isNotNull);
        expect(category!.id, equals('category_2'));
      });

      test('should get all categories', () {
        // Act
        final categories = operations.getAllCategories();

        // Assert
        expect(categories.length, equals(2));
      });

      test('should get owned categories', () {
        // Act
        final owned = operations.getOwnedCategories();

        // Assert
        expect(owned.length, equals(2));
      });

      test('should get friends in category', () {
        // Act
        final friends = operations.getFriendsInCategory('category_1');

        // Assert
        expect(friends.length, equals(1));
        expect(friends.first.uid, equals('friend_1'));
      });

      test('should get categories for friend', () {
        // Act
        final categories = operations.getCategoriesForFriend('friend_1');

        // Assert
        expect(categories.length, equals(1));
        expect(categories.first.id, equals('category_1'));
      });

      test('should get uncategorized friends', () {
        // Arrange
        final friend3 = UserProfile(
          uid: 'friend_3',
          displayName: 'Friend Three',
          email: 'friend3@example.com',
          joinedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        );
        mockParentService
            .updateFriendsList([testFriend1, testFriend2, friend3]);

        // Act
        final uncategorized = operations.getUncategorizedFriends();

        // Assert
        expect(uncategorized.length, equals(1));
        expect(uncategorized.first.uid, equals('friend_3'));
      });
    });

    group('Category Status Checks', () {
      test('should check if friend is in category', () {
        // Act & Assert
        expect(operations.isFriendInCategory('friend_1', 'category_1'), isTrue);
        expect(
            operations.isFriendInCategory('friend_2', 'category_1'), isFalse);
      });

      test('should get category member count', () {
        // Act
        final count = operations.getCategoryMemberCount('category_1');

        // Assert
        expect(count, equals(1));
      });

      test('should check if category is empty', () {
        // Arrange
        final emptyCategory = FriendCategory(
          id: 'empty_category',
          name: 'Empty',
          description: '',
          ownerId: 'user_123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          friendUserIds: [], // memberIds is a getter that returns friendUserIds
        );
        mockParentService.updateCategoriesList([
          emptyCategory,
          testCategory1
        ]); // Include testCategory1 for second assertion

        // Act & Assert
        expect(operations.isCategoryEmpty('empty_category'), isTrue);
        expect(operations.isCategoryEmpty('category_1'), isFalse);
      });
    });

    group('Category Statistics', () {
      test('should get category statistics', () {
        // Act
        final stats = operations.getCategoryStats();

        // Assert
        expect(stats['totalCategories'], equals(2));
        expect(stats['ownedCategories'], equals(2));
        expect(stats['averageMembersPerCategory'], greaterThan(0));
      });
    });

    group('Privacy Features', () {
      test('should handle privacy settings gracefully (not yet implemented)',
          () async {
        // Production code logs a warning and returns without error
        await expectLater(
          operations.setCategoryPrivacy('category_1', isPublic: true),
          completes,
        );
      });
    });

    group('ViewModel Compatibility', () {
      test('should get categories list', () {
        // Act
        final categories = operations.categoriesList;

        // Assert
        expect(categories.length, equals(2));
      });

      test('should assign friend to category', () async {
        // Arrange - friend_2 must be a friend to pass isFriend check
        mockManagement.setManagementState(
          friends: [testFriend1, testFriend2],
        );

        // Act
        final result =
            await operations.assignFriendToCategory('friend_2', 'category_1');

        // Assert
        expect(result, isTrue);
      });

      test('should not add friend to non-existent category', () async {
        // Act
        final result = await operations.assignFriendToCategory(
            'friend_1', 'invalid_category');

        // Assert
        expect(result, isFalse);
      });

      test('should refresh data', () async {
        // Act & Assert - should not throw
        await expectLater(operations.refresh(), completes);
        verify(() => mockParentService.refresh()).called(1);
      });
    });
  });
}

// All mocks are now imported from production_mocks.dart
