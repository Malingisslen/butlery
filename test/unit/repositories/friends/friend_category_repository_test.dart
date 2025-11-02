/// Comprehensive unit tests for FriendCategoryRepository.
///
/// Tests friend category management including create, read, update, delete operations,
/// member management, and real-time streams.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/repositories/firebase/friends/friend_category_repository.dart';
import 'package:butlery/models/friend_category.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FriendCategoryRepository - Friend Category Management', () {
    late FriendCategoryRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepo;
    late FakeUser mockUser;

    // Test data
    const testUserId = 'user-123';
    const testFriendId = 'friend-456';
    const testOtherUserId = 'other-789';
    const testCategoryId = 'category-1';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      // Create fake Firestore instance
      fakeFirestore = FakeFirebaseFirestore();

      // Create mocks
      mockAuthRepo = MockAuthRepository();
      mockUser = FakeUser(uid: testUserId, displayName: 'Test User');

      // Setup default auth state
      mockAuthRepo.setAuthState(
        user: mockUser,
        userId: testUserId,
        isAuthenticated: true,
      );

      // Create repository with fake Firestore
      repository = FriendCategoryRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    // ===== HELPER METHODS =====

    FriendCategory createTestCategory({
      String? id,
      String? ownerId,
      String? name,
      String? emoji,
      List<String>? friendUserIds,
      int? sortOrder,
    }) {
      return FriendCategory(
        id: id ?? testCategoryId,
        ownerId: ownerId ?? testUserId,
        name: name ?? 'Family',
        emoji: emoji,
        friendUserIds: friendUserIds ?? [testFriendId],
        sortOrder: sortOrder ?? 0,
      );
    }

    Future<void> seedCategory(String userId, FriendCategory category) async {
      await fakeFirestore
          .collection('users')
          .doc(userId)
          .collection('friendCategories')
          .doc(category.id)
          .set(category.toFirestore());
    }

    // ===== PERMISSION VALIDATION TESTS =====

    group('Permission Validation', () {
      test('should allow creating category', () async {
        // Arrange
        final category = createTestCategory();

        // Act
        final hasPermission =
            await repository.validateCreatePermission(testUserId, category);

        // Assert
        expect(hasPermission, isTrue);
      });

      test('should allow reading own category', () async {
        // Arrange
        final category = createTestCategory();

        // Act
        final hasPermission = await repository.validateReadPermission(
            testUserId, testCategoryId, category);

        // Assert
        expect(hasPermission, isTrue);
      });

      test('should allow updating own category', () async {
        // Arrange
        final category = createTestCategory();

        // Act
        final hasPermission = await repository.validateUpdatePermission(
            testUserId, testCategoryId, category);

        // Assert
        expect(hasPermission, isTrue);
      });

      test('should allow deleting own category', () async {
        // Act
        final hasPermission = await repository.validateDeletePermission(
            testUserId, testCategoryId);

        // Assert
        expect(hasPermission, isTrue);
      });
    });

    // ===== CATEGORY OPERATIONS =====

    group('Category Operations', () {
      test('should save category successfully', () async {
        // Arrange
        final category = createTestCategory();

        // Act
        await repository.saveCategory(testUserId, category);

        // Assert
        final doc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('friendCategories')
            .doc(testCategoryId)
            .get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['name'], 'Family');
      });

      test('should reject saving category for another user', () async {
        // Arrange
        final category = createTestCategory(ownerId: testOtherUserId);

        // Act & Assert
        expect(
          () => repository.saveCategory(testOtherUserId, category),
          throwsA(isA<Exception>()),
        );
      });

      test('should fetch categories for user', () async {
        // Arrange
        final category1 = createTestCategory(id: 'cat-1', name: 'Family');
        final category2 = createTestCategory(id: 'cat-2', name: 'Work');
        await seedCategory(testUserId, category1);
        await seedCategory(testUserId, category2);

        // Act
        final categories = await repository.fetchCategories(testUserId);

        // Assert
        expect(categories.length, 2);
        expect(categories.any((c) => c.name == 'Family'), isTrue);
        expect(categories.any((c) => c.name == 'Work'), isTrue);
      });

      test('should return empty list if no categories', () async {
        // Act
        final categories = await repository.fetchCategories(testUserId);

        // Assert
        expect(categories, isEmpty);
      });

      test('should get category by ID', () async {
        // Arrange
        final category = createTestCategory();
        await seedCategory(testUserId, category);

        // Act
        final result = await repository.getCategory(testUserId, testCategoryId);

        // Assert
        expect(result, isNotNull);
        expect(result!.id, testCategoryId);
        expect(result.name, 'Family');
      });

      test('should return null for non-existent category', () async {
        // Act
        final result = await repository.getCategory(testUserId, 'non-existent');

        // Assert
        expect(result, isNull);
      });

      test('should delete category', () async {
        // Arrange
        final category = createTestCategory();
        await seedCategory(testUserId, category);

        // Act
        await repository.deleteCategory(testUserId, testCategoryId);

        // Assert
        final doc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('friendCategories')
            .doc(testCategoryId)
            .get();
        expect(doc.exists, isFalse);
      });

      test('should update category', () async {
        // Arrange
        final category = createTestCategory();
        await seedCategory(testUserId, category);

        // Act
        await repository.updateCategory(testUserId, testCategoryId, {
          'name': 'Updated Family',
          'emoji': '👨‍👩‍👧‍👦',
        });

        // Assert
        final doc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('friendCategories')
            .doc(testCategoryId)
            .get();
        expect(doc.data()?['name'], 'Updated Family');
        expect(doc.data()?['emoji'], '👨‍👩‍👧‍👦');
      });
    });

    // ===== MEMBER MANAGEMENT =====

    group('Member Management', () {
      test('should add friend to category', () async {
        // Arrange
        final category = createTestCategory(friendUserIds: [testFriendId]);
        await seedCategory(testUserId, category);
        const newFriendId = 'new-friend-123';

        // Act
        await repository.addFriendToCategory(
            testUserId, testCategoryId, newFriendId);

        // Assert
        final doc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('friendCategories')
            .doc(testCategoryId)
            .get();
        final friendIds = List<String>.from(doc.data()?['friendUserIds'] ?? []);
        expect(friendIds, contains(newFriendId));
      }, skip: 'Requires FieldValue.arrayUnion support');

      test('should remove friend from category', () async {
        // Arrange
        final category =
            createTestCategory(friendUserIds: [testFriendId, testOtherUserId]);
        await seedCategory(testUserId, category);

        // Act
        await repository.removeFriendFromCategory(
            testUserId, testCategoryId, testFriendId);

        // Assert
        final doc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('friendCategories')
            .doc(testCategoryId)
            .get();
        final friendIds = List<String>.from(doc.data()?['friendUserIds'] ?? []);
        expect(friendIds, isNot(contains(testFriendId)));
        expect(friendIds, contains(testOtherUserId));
      }, skip: 'Requires FieldValue.arrayRemove support');

      test('should update category members', () async {
        // Arrange
        final category = createTestCategory(friendUserIds: [testFriendId]);
        await seedCategory(testUserId, category);
        final newMemberIds = [testFriendId, testOtherUserId, 'new-friend-789'];

        // Act
        await repository.updateCategoryMembers(
            testUserId, testCategoryId, newMemberIds);

        // Assert
        final doc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('friendCategories')
            .doc(testCategoryId)
            .get();
        final friendIds = List<String>.from(doc.data()?['friendUserIds'] ?? []);
        expect(friendIds.length, 3);
        expect(friendIds, containsAll(newMemberIds));
      }, skip: 'Requires FieldValue support');
    });

    // ===== SEARCH AND QUERY =====

    group('Search and Query', () {
      test('should search categories by name', () async {
        // Arrange
        final family = createTestCategory(id: 'cat-1', name: 'Family');
        final work = createTestCategory(id: 'cat-2', name: 'Work Friends');
        final school = createTestCategory(id: 'cat-3', name: 'School Buddies');
        await seedCategory(testUserId, family);
        await seedCategory(testUserId, work);
        await seedCategory(testUserId, school);

        // Act
        final results = await repository.searchCategories(testUserId, 'friend');

        // Assert - Should find 'Work Friends' (case-insensitive)
        expect(results.length, 1);
        expect(results.first.name, 'Work Friends');
      });

      test('should return empty list for no search matches', () async {
        // Arrange
        final category = createTestCategory(name: 'Family');
        await seedCategory(testUserId, category);

        // Act
        final results =
            await repository.searchCategories(testUserId, 'nonexistent');

        // Assert
        expect(results, isEmpty);
      });
    });

    // ===== REAL-TIME STREAMS =====

    group('Real-time Streams', () {
      test('should stream categories', () async {
        // Arrange
        final category = createTestCategory();
        await seedCategory(testUserId, category);

        // Act
        final stream = repository.categoriesStream(testUserId);

        // Assert
        await expectLater(
          stream.first,
          completion(predicate<List<FriendCategory>>((categories) {
            return categories.length == 1 && categories.first.name == 'Family';
          })),
        );
      });

      test('should stream empty list if no categories', () async {
        // Act
        final stream = repository.categoriesStream(testUserId);

        // Assert
        await expectLater(
          stream.first,
          completion(predicate<List<FriendCategory>>((categories) {
            return categories.isEmpty;
          })),
        );
      });
    });

    // ===== EDGE CASES =====

    group('Edge Cases', () {
      test('should handle user not authenticated', () async {
        // Arrange
        mockAuthRepo.setAuthState(
          user: null,
          userId: null,
          isAuthenticated: false,
        );
        final category = createTestCategory();

        // Act & Assert
        expect(
          () => repository.saveCategory(testUserId, category),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle category with empty member list', () async {
        // Arrange
        final category = createTestCategory(friendUserIds: []);

        // Act
        await repository.saveCategory(testUserId, category);

        // Assert
        final doc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('friendCategories')
            .doc(testCategoryId)
            .get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['friendUserIds'], isEmpty);
      });

      test('should handle deleting non-existent category', () async {
        // Act & Assert - Should not throw
        await repository.deleteCategory(testUserId, 'non-existent');
      });
    });

    // ===== BASE REPOSITORY IMPLEMENTATION =====

    group('Base Repository Implementation', () {
      test('should use correct collection name', () {
        expect(repository.collectionName, 'friendCategories');
      });

      test('should convert entity to ID correctly', () {
        // Arrange
        final category = createTestCategory();

        // Act
        final id = repository.getId(category);

        // Assert
        expect(id, testCategoryId);
      });

      test('should serialize to Firestore correctly', () {
        // Arrange
        final category = createTestCategory();

        // Act
        final data = repository.toFirestore(category);

        // Assert
        expect(data['name'], 'Family');
        expect(data['ownerId'], testUserId);
        expect(data['friendUserIds'], contains(testFriendId));
      });

      test('should deserialize from Firestore correctly', () async {
        // Arrange
        final category = createTestCategory();
        await seedCategory(testUserId, category);

        // Act
        final doc = await fakeFirestore
            .collection('users')
            .doc(testUserId)
            .collection('friendCategories')
            .doc(testCategoryId)
            .get();
        final result = repository.fromFirestore(doc);

        // Assert
        expect(result.id, testCategoryId);
        expect(result.name, 'Family');
        expect(result.ownerId, testUserId);
      });
    });
  });
}
