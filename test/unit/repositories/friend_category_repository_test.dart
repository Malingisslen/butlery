// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/friends/friend_category_repository.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Test-specific mocks
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}
class MockQuerySnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}
class MockQueryDocumentSnapshot extends Mock implements QueryDocumentSnapshot<Map<String, dynamic>> {}
class MockWriteBatch extends Mock implements WriteBatch {}

// Fake classes for any() matching
class FakeFieldValue extends Fake implements FieldValue {}
class FakeDocumentReference extends Fake implements DocumentReference<Map<String, dynamic>> {}
class FakeMap extends Fake implements Map<String, dynamic> {}

void main() {
  group('FriendCategoryRepository', () {
    late FriendCategoryRepository repository;
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference mockUsersCollection;
    late MockCollectionReference mockCategoriesCollection;
    late MockDocumentReference mockUserDoc;
    late MockDocumentReference mockCategoryDoc;
    late MockAuthRepository mockAuthRepository;
    late MockWriteBatch mockBatch;
    
    // Test data
    const userId = 'test-user-123';
    const otherUserId = 'other-user-456';
    const categoryId = 'category-123';
    const friendId1 = 'friend-1';
    const friendId2 = 'friend-2';
    const friendId3 = 'friend-3';
    
    late FriendCategory testCategory;
    late Map<String, dynamic> testCategoryMap;
    
    setUpAll(() {
      registerFallbackValue(FakeFieldValue());
      registerFallbackValue(DateTime.now());
      registerFallbackValue(FakeDocumentReference());
      registerFallbackValue(FakeMap());
    });
    
    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      
      // Initialize mocks
      mockFirestore = MockFirebaseFirestore();
      mockUsersCollection = MockCollectionReference();
      mockCategoriesCollection = MockCollectionReference();
      mockUserDoc = MockDocumentReference();
      mockCategoryDoc = MockDocumentReference();
      mockAuthRepository = MockAuthRepository();
      mockBatch = MockWriteBatch();
      
      // Configure auth state
      mockAuthRepository.setAuthState(
        userId: userId,
        isAuthenticated: true,
      );
      
      // Setup test category
      testCategory = FriendCategory(
        id: categoryId,
        ownerId: userId,
        name: 'Work Friends',
        description: 'Colleagues from work',
        emoji: '💼',
        friendUserIds: [friendId1, friendId2],
        sortOrder: 1,
      );
      
      testCategoryMap = {
        'ownerId': userId,
        'name': 'Work Friends',
        'description': 'Colleagues from work',
        'emoji': '💼',
        'friendUserIds': [friendId1, friendId2],
        'createdAt': {'seconds': 1234567890, 'nanoseconds': 0},
        'updatedAt': {'seconds': 1234567890, 'nanoseconds': 0},
        'sortOrder': 1,
        'isDefault': false,
      };
      
      // Setup Firestore structure
      when(() => mockFirestore.collection('users')).thenReturn(mockUsersCollection);
      when(() => mockFirestore.batch()).thenReturn(mockBatch);
      when(() => mockUsersCollection.doc(any())).thenReturn(mockUserDoc);
      when(() => mockUserDoc.collection('friendCategories')).thenReturn(mockCategoriesCollection);
      when(() => mockCategoriesCollection.doc(any())).thenReturn(mockCategoryDoc);
      when(() => mockCategoriesCollection.snapshots()).thenAnswer(
        (_) => Stream.value(MockQuerySnapshot()),
      );
      when(() => mockCategoryDoc.set(any())).thenAnswer((_) async {});
      when(() => mockCategoryDoc.update(any())).thenAnswer((_) async {});
      when(() => mockCategoryDoc.delete()).thenAnswer((_) async {});
      when(() => mockCategoryDoc.get()).thenAnswer((_) async => MockDocumentSnapshot());
      // WriteBatch.update returns void, no stubbing needed
      when(() => mockBatch.commit()).thenAnswer((_) async {});
      
      // Create repository
      repository = FriendCategoryRepository(
        firestore: mockFirestore,
        authRepository: mockAuthRepository,
      );
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    group('saveCategory', () {
      test('should save category for current user', () async {
        // Arrange
        when(() => mockCategoryDoc.set(any())).thenAnswer((_) async {});
        
        // Act
        await repository.saveCategory(userId, testCategory);
        
        // Assert
        verify(() => mockCategoryDoc.set(any())).called(1);
        final captured = verify(() => mockCategoryDoc.set(captureAny())).captured.single;
        expect(captured['name'], equals('Work Friends'));
        expect(captured['friendUserIds'], equals([friendId1, friendId2]));
      });
      
      test('should prevent saving category for another user', () async {
        // Act & Assert
        expect(
          () => repository.saveCategory(otherUserId, testCategory),
          throwsA(isA<PermissionDeniedException>()
            .having((e) => e.message, 'message', contains('can only save friend category'))),
        );
      });
      
      test('should validate required fields', () async {
        // Arrange
        final invalidCategory = FriendCategory(
          id: categoryId,
          ownerId: userId,
          name: '', // Empty name - invalid
          friendUserIds: [],
        );
        
        // Act & Assert
        expect(
          () => repository.saveCategory(userId, invalidCategory),
          throwsA(isA<ValidationException>()),
        );
      });
    });
    
    group('updateCategory', () {
      test('should update category for current user', () async {
        // Arrange
        final updateData = {
          'name': 'Updated Friends',
          'emoji': '👥',
          'updatedAt': DateTime.now(),
        };
        
        when(() => mockCategoryDoc.update(any())).thenAnswer((_) async {});
        
        // Act
        await repository.updateCategory(userId, categoryId, updateData);
        
        // Assert
        verify(() => mockCategoryDoc.update(any())).called(1);
      });
      
      test('should prevent updating category for another user', () async {
        // Act & Assert
        expect(
          () => repository.updateCategory(otherUserId, categoryId, {'name': 'New'}),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });
    
    group('deleteCategory', () {
      test('should delete category for current user', () async {
        // Arrange
        when(() => mockCategoryDoc.delete()).thenAnswer((_) async {});
        
        // Act
        await repository.deleteCategory(userId, categoryId);
        
        // Assert
        verify(() => mockCategoryDoc.delete()).called(1);
      });
      
      test('should prevent deleting category for another user', () async {
        // Act & Assert
        expect(
          () => repository.deleteCategory(otherUserId, categoryId),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });
    
    group('fetchCategories', () {
      test('should fetch all categories for a user', () async {
        // Arrange
        final mockDoc1 = MockQueryDocumentSnapshot();
        final mockDoc2 = MockQueryDocumentSnapshot();
        
        when(() => mockDoc1.id).thenReturn('cat1');
        when(() => mockDoc1.data()).thenReturn(testCategoryMap);
        when(() => mockDoc2.id).thenReturn('cat2');
        when(() => mockDoc2.data()).thenReturn({
          ...testCategoryMap,
          'name': 'Family',
          'emoji': '👨‍👩‍👧‍👦',
        });
        
        final mockSnapshot = MockQuerySnapshot();
        when(() => mockSnapshot.docs).thenReturn([mockDoc1, mockDoc2]);
        when(() => mockCategoriesCollection.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final categories = await repository.fetchCategories(userId);
        
        // Assert
        expect(categories.length, equals(2));
        expect(categories[0].name, equals('Work Friends'));
        expect(categories[1].name, equals('Family'));
      });
      
      test('should return empty list when no categories exist', () async {
        // Arrange
        final mockSnapshot = MockQuerySnapshot();
        when(() => mockSnapshot.docs).thenReturn([]);
        when(() => mockCategoriesCollection.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final categories = await repository.fetchCategories(userId);
        
        // Assert
        expect(categories, isEmpty);
      });
    });
    
    group('updateCategoryMembers', () {
      test('should update category members for current user', () async {
        // Arrange
        final newMembers = [friendId1, friendId2, friendId3];
        when(() => mockCategoryDoc.update(any())).thenAnswer((_) async {});
        
        // Act
        await repository.updateCategoryMembers(userId, categoryId, newMembers);
        
        // Assert
        final captured = verify(() => mockCategoryDoc.update(captureAny())).captured.single;
        expect(captured['friendUserIds'], equals(newMembers));
        expect(captured['updatedAt'], isA<FieldValue>());
      });
      
      test('should prevent updating members for another user', () async {
        // Act & Assert
        expect(
          () => repository.updateCategoryMembers(otherUserId, categoryId, []),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });
    
    group('getCategory', () {
      test('should return category when it exists', () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.id).thenReturn(categoryId);
        when(() => mockSnapshot.data()).thenReturn(testCategoryMap);
        when(() => mockCategoryDoc.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final category = await repository.getCategory(userId, categoryId);
        
        // Assert
        expect(category, isNotNull);
        expect(category!.name, equals('Work Friends'));
        expect(category.friendUserIds, equals([friendId1, friendId2]));
      });
      
      test('should return null when category does not exist', () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockSnapshot.exists).thenReturn(false);
        when(() => mockCategoryDoc.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final category = await repository.getCategory(userId, categoryId);
        
        // Assert
        expect(category, isNull);
      });
    });
    
    group('addFriendToCategory', () {
      test('should add friend to category if not already present', () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.id).thenReturn(categoryId);
        when(() => mockSnapshot.data()).thenReturn(testCategoryMap);
        when(() => mockCategoryDoc.get()).thenAnswer((_) async => mockSnapshot);
        when(() => mockCategoryDoc.update(any())).thenAnswer((_) async {});
        
        // Act
        await repository.addFriendToCategory(userId, categoryId, friendId3);
        
        // Assert
        final captured = verify(() => mockCategoryDoc.update(captureAny())).captured.single;
        expect(captured['friendUserIds'], equals([friendId1, friendId2, friendId3]));
      });
      
      test('should not add duplicate friend to category', () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.id).thenReturn(categoryId);
        when(() => mockSnapshot.data()).thenReturn(testCategoryMap);
        when(() => mockCategoryDoc.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        await repository.addFriendToCategory(userId, categoryId, friendId1); // Already exists
        
        // Assert
        verifyNever(() => mockCategoryDoc.update(any()));
      });
      
      test('should do nothing if category does not exist', () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockSnapshot.exists).thenReturn(false);
        when(() => mockCategoryDoc.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        await repository.addFriendToCategory(userId, categoryId, friendId3);
        
        // Assert
        verifyNever(() => mockCategoryDoc.update(any()));
      });
    });
    
    group('removeFriendFromCategory', () {
      test('should remove friend from category if present', () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.id).thenReturn(categoryId);
        when(() => mockSnapshot.data()).thenReturn(testCategoryMap);
        when(() => mockCategoryDoc.get()).thenAnswer((_) async => mockSnapshot);
        when(() => mockCategoryDoc.update(any())).thenAnswer((_) async {});
        
        // Act
        await repository.removeFriendFromCategory(userId, categoryId, friendId2);
        
        // Assert
        final captured = verify(() => mockCategoryDoc.update(captureAny())).captured.single;
        expect(captured['friendUserIds'], equals([friendId1])); // friendId2 removed
      });
      
      test('should not update if friend not in category', () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.id).thenReturn(categoryId);
        when(() => mockSnapshot.data()).thenReturn(testCategoryMap);
        when(() => mockCategoryDoc.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        await repository.removeFriendFromCategory(userId, categoryId, friendId3); // Not in category
        
        // Assert
        verifyNever(() => mockCategoryDoc.update(any()));
      });
    });
    
    group('getCategoriesContainingFriend', () {
      test('should return categories containing specific friend', () async {
        // Arrange
        final mockDoc1 = MockQueryDocumentSnapshot();
        final mockDoc2 = MockQueryDocumentSnapshot();
        final mockDoc3 = MockQueryDocumentSnapshot();
        
        when(() => mockDoc1.id).thenReturn('cat1');
        when(() => mockDoc1.data()).thenReturn(testCategoryMap); // Contains friendId1
        
        when(() => mockDoc2.id).thenReturn('cat2');
        when(() => mockDoc2.data()).thenReturn({
          ...testCategoryMap,
          'friendUserIds': [friendId3], // Does not contain friendId1
        });
        
        when(() => mockDoc3.id).thenReturn('cat3');
        when(() => mockDoc3.data()).thenReturn({
          ...testCategoryMap,
          'friendUserIds': [friendId1, friendId3], // Contains friendId1
        });
        
        final mockSnapshot = MockQuerySnapshot();
        when(() => mockSnapshot.docs).thenReturn([mockDoc1, mockDoc2, mockDoc3]);
        when(() => mockCategoriesCollection.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final categories = await repository.getCategoriesContainingFriend(userId, friendId1);
        
        // Assert
        expect(categories.length, equals(2));
        expect(categories[0].friendUserIds, contains(friendId1));
        expect(categories[1].friendUserIds, contains(friendId1));
      });
    });
    
    group('categoriesStream', () {
      test('should return stream of categories', () async {
        // Arrange
        final mockDoc = MockQueryDocumentSnapshot();
        when(() => mockDoc.id).thenReturn(categoryId);
        when(() => mockDoc.data()).thenReturn(testCategoryMap);
        
        final mockSnapshot = MockQuerySnapshot();
        when(() => mockSnapshot.docs).thenReturn([mockDoc]);
        
        when(() => mockCategoriesCollection.snapshots()).thenAnswer(
          (_) => Stream.value(mockSnapshot),
        );
        
        // Act
        final stream = repository.categoriesStream(userId);
        final categories = await stream.first;
        
        // Assert
        expect(categories.length, equals(1));
        expect(categories[0].name, equals('Work Friends'));
      });
      
      test('should handle real-time updates in stream', () async {
        // Arrange
        final mockDoc = MockQueryDocumentSnapshot();
        when(() => mockDoc.id).thenReturn(categoryId);
        when(() => mockDoc.data()).thenReturn(testCategoryMap);
        
        final snapshot1 = MockQuerySnapshot();
        final snapshot2 = MockQuerySnapshot();
        final snapshot3 = MockQuerySnapshot();
        
        when(() => snapshot1.docs).thenReturn([]);
        when(() => snapshot2.docs).thenReturn([mockDoc]);
        when(() => snapshot3.docs).thenReturn([mockDoc, mockDoc]);
        
        when(() => mockCategoriesCollection.snapshots()).thenAnswer(
          (_) => Stream.fromIterable([snapshot1, snapshot2, snapshot3]),
        );
        
        // Act
        final stream = repository.categoriesStream(userId);
        final results = await stream.take(3).toList();
        
        // Assert
        expect(results[0].length, equals(0));
        expect(results[1].length, equals(1));
        expect(results[2].length, equals(2));
      });
    });
    
    group('getCategoryStatistics', () {
      test('should calculate category statistics correctly', () async {
        // Arrange
        final mockDoc1 = MockQueryDocumentSnapshot();
        final mockDoc2 = MockQueryDocumentSnapshot();
        final mockDoc3 = MockQueryDocumentSnapshot();
        
        when(() => mockDoc1.id).thenReturn('cat1');
        when(() => mockDoc1.data()).thenReturn({
          ...testCategoryMap,
          'name': 'Small Group',
          'friendUserIds': [friendId1],
        });
        
        when(() => mockDoc2.id).thenReturn('cat2');
        when(() => mockDoc2.data()).thenReturn({
          ...testCategoryMap,
          'name': 'Medium Group',
          'friendUserIds': [friendId1, friendId2, friendId3],
        });
        
        when(() => mockDoc3.id).thenReturn('cat3');
        when(() => mockDoc3.data()).thenReturn({
          ...testCategoryMap,
          'name': 'Large Group',
          'friendUserIds': ['f1', 'f2', 'f3', 'f4', 'f5'],
        });
        
        final mockSnapshot = MockQuerySnapshot();
        when(() => mockSnapshot.docs).thenReturn([mockDoc1, mockDoc2, mockDoc3]);
        when(() => mockCategoriesCollection.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final stats = await repository.getCategoryStatistics(userId);
        
        // Assert
        expect(stats['totalCategories'], equals(3));
        expect(stats['totalMembers'], equals(9)); // 1 + 3 + 5
        expect(stats['averageSize'], equals(3)); // 9 / 3
        expect(stats['largestCategorySize'], equals(5));
        expect(stats['largestCategoryName'], equals('Large Group'));
        expect(stats['hasCategories'], isTrue);
      });
      
      test('should handle empty categories correctly', () async {
        // Arrange
        final mockSnapshot = MockQuerySnapshot();
        when(() => mockSnapshot.docs).thenReturn([]);
        when(() => mockCategoriesCollection.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final stats = await repository.getCategoryStatistics(userId);
        
        // Assert
        expect(stats['totalCategories'], equals(0));
        expect(stats['totalMembers'], equals(0));
        expect(stats['averageSize'], equals(0));
        expect(stats['largestCategorySize'], equals(0));
        expect(stats['largestCategoryName'], isNull);
        expect(stats['hasCategories'], isFalse);
      });
    });
    
    group('searchCategories', () {
      test('should find categories by name', () async {
        // Arrange
        final mockDoc1 = MockQueryDocumentSnapshot();
        final mockDoc2 = MockQueryDocumentSnapshot();
        final mockDoc3 = MockQueryDocumentSnapshot();
        
        when(() => mockDoc1.id).thenReturn('cat1');
        when(() => mockDoc1.data()).thenReturn({
          ...testCategoryMap,
          'name': 'Work Friends',
        });
        
        when(() => mockDoc2.id).thenReturn('cat2');
        when(() => mockDoc2.data()).thenReturn({
          ...testCategoryMap,
          'name': 'Family',
        });
        
        when(() => mockDoc3.id).thenReturn('cat3');
        when(() => mockDoc3.data()).thenReturn({
          ...testCategoryMap,
          'name': 'Work Colleagues',
        });
        
        final mockSnapshot = MockQuerySnapshot();
        when(() => mockSnapshot.docs).thenReturn([mockDoc1, mockDoc2, mockDoc3]);
        when(() => mockCategoriesCollection.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final results = await repository.searchCategories(userId, 'work');
        
        // Assert
        expect(results.length, equals(2));
        expect(results[0].name, equals('Work Friends'));
        expect(results[1].name, equals('Work Colleagues'));
      });
      
      test('should find categories by description', () async {
        // Arrange
        final mockDoc1 = MockQueryDocumentSnapshot();
        final mockDoc2 = MockQueryDocumentSnapshot();
        
        when(() => mockDoc1.id).thenReturn('cat1');
        when(() => mockDoc1.data()).thenReturn({
          ...testCategoryMap,
          'name': 'Group A',
          'description': 'Professional network',
        });
        
        when(() => mockDoc2.id).thenReturn('cat2');
        when(() => mockDoc2.data()).thenReturn({
          ...testCategoryMap,
          'name': 'Group B',
          'description': 'Personal friends',
        });
        
        final mockSnapshot = MockQuerySnapshot();
        when(() => mockSnapshot.docs).thenReturn([mockDoc1, mockDoc2]);
        when(() => mockCategoriesCollection.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final results = await repository.searchCategories(userId, 'professional');
        
        // Assert
        expect(results.length, equals(1));
        expect(results[0].name, equals('Group A'));
      });
      
      test('should handle case-insensitive search', () async {
        // Arrange
        final mockDoc = MockQueryDocumentSnapshot();
        when(() => mockDoc.id).thenReturn('cat1');
        when(() => mockDoc.data()).thenReturn({
          ...testCategoryMap,
          'name': 'WORK Friends',
        });
        
        final mockSnapshot = MockQuerySnapshot();
        when(() => mockSnapshot.docs).thenReturn([mockDoc]);
        when(() => mockCategoriesCollection.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final results = await repository.searchCategories(userId, 'WoRk');
        
        // Assert
        expect(results.length, equals(1));
      });
    });
    
    group('getEmptyCategories', () {
      test('should return only empty categories', () async {
        // Arrange
        final mockDoc1 = MockQueryDocumentSnapshot();
        final mockDoc2 = MockQueryDocumentSnapshot();
        final mockDoc3 = MockQueryDocumentSnapshot();
        
        when(() => mockDoc1.id).thenReturn('cat1');
        when(() => mockDoc1.data()).thenReturn({
          ...testCategoryMap,
          'friendUserIds': [], // Empty
        });
        
        when(() => mockDoc2.id).thenReturn('cat2');
        when(() => mockDoc2.data()).thenReturn({
          ...testCategoryMap,
          'friendUserIds': [friendId1], // Not empty
        });
        
        when(() => mockDoc3.id).thenReturn('cat3');
        when(() => mockDoc3.data()).thenReturn({
          ...testCategoryMap,
          'friendUserIds': [], // Empty
        });
        
        final mockSnapshot = MockQuerySnapshot();
        when(() => mockSnapshot.docs).thenReturn([mockDoc1, mockDoc2, mockDoc3]);
        when(() => mockCategoriesCollection.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final emptyCategories = await repository.getEmptyCategories(userId);
        
        // Assert
        expect(emptyCategories.length, equals(2));
        expect(emptyCategories[0].friendUserIds, isEmpty);
        expect(emptyCategories[1].friendUserIds, isEmpty);
      });
    });
    
    group('getLargestCategories', () {
      test('should return categories sorted by member count', () async {
        // Arrange
        final mockDoc1 = MockQueryDocumentSnapshot();
        final mockDoc2 = MockQueryDocumentSnapshot();
        final mockDoc3 = MockQueryDocumentSnapshot();
        final mockDoc4 = MockQueryDocumentSnapshot();
        
        when(() => mockDoc1.id).thenReturn('cat1');
        when(() => mockDoc1.data()).thenReturn({
          ...testCategoryMap,
          'name': 'Small',
          'friendUserIds': ['f1'],
        });
        
        when(() => mockDoc2.id).thenReturn('cat2');
        when(() => mockDoc2.data()).thenReturn({
          ...testCategoryMap,
          'name': 'Large',
          'friendUserIds': ['f1', 'f2', 'f3', 'f4'],
        });
        
        when(() => mockDoc3.id).thenReturn('cat3');
        when(() => mockDoc3.data()).thenReturn({
          ...testCategoryMap,
          'name': 'Medium',
          'friendUserIds': ['f1', 'f2'],
        });
        
        when(() => mockDoc4.id).thenReturn('cat4');
        when(() => mockDoc4.data()).thenReturn({
          ...testCategoryMap,
          'name': 'Largest',
          'friendUserIds': ['f1', 'f2', 'f3', 'f4', 'f5'],
        });
        
        final mockSnapshot = MockQuerySnapshot();
        when(() => mockSnapshot.docs).thenReturn([mockDoc1, mockDoc2, mockDoc3, mockDoc4]);
        when(() => mockCategoriesCollection.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final largest = await repository.getLargestCategories(userId, limit: 3);
        
        // Assert
        expect(largest.length, equals(3));
        expect(largest[0].name, equals('Largest'));
        expect(largest[0].friendUserIds.length, equals(5));
        expect(largest[1].name, equals('Large'));
        expect(largest[1].friendUserIds.length, equals(4));
        expect(largest[2].name, equals('Medium'));
        expect(largest[2].friendUserIds.length, equals(2));
      });
    });
    
    group('categoryNameExists', () {
      test('should return true if category name exists', () async {
        // Arrange
        final mockDoc1 = MockQueryDocumentSnapshot();
        final mockDoc2 = MockQueryDocumentSnapshot();
        
        when(() => mockDoc1.id).thenReturn('cat1');
        when(() => mockDoc1.data()).thenReturn({
          ...testCategoryMap,
          'name': 'Work Friends',
        });
        
        when(() => mockDoc2.id).thenReturn('cat2');
        when(() => mockDoc2.data()).thenReturn({
          ...testCategoryMap,
          'name': 'Family',
        });
        
        final mockSnapshot = MockQuerySnapshot();
        when(() => mockSnapshot.docs).thenReturn([mockDoc1, mockDoc2]);
        when(() => mockCategoriesCollection.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final exists = await repository.categoryNameExists(userId, 'Work Friends');
        
        // Assert
        expect(exists, isTrue);
      });
      
      test('should return false if category name does not exist', () async {
        // Arrange
        final mockDoc = MockQueryDocumentSnapshot();
        when(() => mockDoc.id).thenReturn('cat1');
        when(() => mockDoc.data()).thenReturn({
          ...testCategoryMap,
          'name': 'Work Friends',
        });
        
        final mockSnapshot = MockQuerySnapshot();
        when(() => mockSnapshot.docs).thenReturn([mockDoc]);
        when(() => mockCategoriesCollection.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final exists = await repository.categoryNameExists(userId, 'New Category');
        
        // Assert
        expect(exists, isFalse);
      });
      
      test('should exclude specific category when checking', () async {
        // Arrange
        final mockDoc = MockQueryDocumentSnapshot();
        when(() => mockDoc.id).thenReturn('cat1');
        when(() => mockDoc.data()).thenReturn({
          ...testCategoryMap,
          'name': 'Work Friends',
        });
        
        final mockSnapshot = MockQuerySnapshot();
        when(() => mockSnapshot.docs).thenReturn([mockDoc]);
        when(() => mockCategoriesCollection.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final exists = await repository.categoryNameExists(
          userId, 
          'Work Friends',
          excludeCategoryId: 'cat1', // Exclude the category with this name
        );
        
        // Assert
        expect(exists, isFalse); // Should not find it since we excluded it
      });
      
      test('should be case-insensitive', () async {
        // Arrange
        final mockDoc = MockQueryDocumentSnapshot();
        when(() => mockDoc.id).thenReturn('cat1');
        when(() => mockDoc.data()).thenReturn({
          ...testCategoryMap,
          'name': 'Work Friends',
        });
        
        final mockSnapshot = MockQuerySnapshot();
        when(() => mockSnapshot.docs).thenReturn([mockDoc]);
        when(() => mockCategoriesCollection.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final exists = await repository.categoryNameExists(userId, 'WORK FRIENDS');
        
        // Assert
        expect(exists, isTrue);
      });
    });
    
    group('bulkUpdateCategories', () {
      test('should batch update multiple categories', () async {
        // Arrange
        final updates = {
          'cat1': {'name': 'Updated Cat 1', 'emoji': '🎉'},
          'cat2': {'description': 'New description'},
          'cat3': {'sortOrder': 5},
        };
        
        // Act
        await repository.bulkUpdateCategories(userId, updates);
        
        // Assert
        verify(() => mockBatch.update(any(), any())).called(3);
        verify(() => mockBatch.commit()).called(1);
      });
      
      test('should prevent bulk updates for another user', () async {
        // Arrange
        final updates = {'cat1': {'name': 'Updated'}};
        
        // Act & Assert
        expect(
          () => repository.bulkUpdateCategories(otherUserId, updates),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });
    
    group('inherited from BaseFirebaseRepository', () {
      test('should use correct collection name', () {
        // Assert
        expect(repository.collectionName, equals('friendCategories'));
      });
      
      test('should convert from Firestore correctly', () {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockSnapshot.id).thenReturn(categoryId);
        when(() => mockSnapshot.data()).thenReturn(testCategoryMap);
        
        // Act
        final result = repository.fromFirestore(mockSnapshot);
        
        // Assert
        expect(result.id, equals(categoryId));
        expect(result.name, equals('Work Friends'));
        expect(result.friendUserIds, equals([friendId1, friendId2]));
      });
      
      test('should convert to Firestore correctly', () {
        // Act
        final result = repository.toFirestore(testCategory);
        
        // Assert
        expect(result['name'], equals('Work Friends'));
        expect(result['friendUserIds'], equals([friendId1, friendId2]));
        expect(result['emoji'], equals('💼'));
      });
      
      test('should extract ID correctly', () {
        // Act
        final id = repository.getId(testCategory);
        
        // Assert
        expect(id, equals(categoryId));
      });
    });
    
    group('permission validation', () {
      test('should enforce self-operation validation for all write operations', () async {
        // Act & Assert
        expect(
          () => repository.saveCategory(otherUserId, testCategory),
          throwsA(isA<PermissionDeniedException>()),
        );
        
        expect(
          () => repository.updateCategory(otherUserId, categoryId, {}),
          throwsA(isA<PermissionDeniedException>()),
        );
        
        expect(
          () => repository.deleteCategory(otherUserId, categoryId),
          throwsA(isA<PermissionDeniedException>()),
        );
        
        expect(
          () => repository.createCategoryForUser(otherUserId, testCategory),
          throwsA(isA<PermissionDeniedException>()),
        );
        
        expect(
          () => repository.updateCategoryMembers(otherUserId, categoryId, []),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });
  });
}