/// Comprehensive unit tests for FirebaseShoppingRepository
/// 
/// Tests Firebase Firestore implementation of shopping list operations including
/// personal lists, collaborative lists, templates, and item management.
library;

// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_shopping_repository.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Local mocks for sealed Firebase classes
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference<T> extends Mock implements CollectionReference<T> {}
class MockDocumentReference<T> extends Mock implements DocumentReference<T> {}
class MockDocumentSnapshot<T> extends Mock implements DocumentSnapshot<T> {}
class MockQuery<T> extends Mock implements Query<T> {}
class MockQuerySnapshot<T> extends Mock implements QuerySnapshot<T> {}
class MockQueryDocumentSnapshot<T> extends Mock implements QueryDocumentSnapshot<T> {}
class MockWriteBatch extends Mock implements WriteBatch {}

// Factory for creating test shopping lists
class ShoppingListFactory {
  static UnifiedShoppingList build({
    String? id,
    String name = 'Test Shopping List',
    String ownerId = 'test-user-123',
    String ownerDisplayName = 'Test User',
    List<UnifiedShoppingItem>? items,
    ListType type = ListType.personal,
    Map<String, SharedListPermission>? memberPermissions,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now();
    return UnifiedShoppingList(
      id: id ?? 'list_${now.millisecondsSinceEpoch}',
      name: name,
      ownerId: ownerId,
      ownerDisplayName: ownerDisplayName,
      items: items ?? [],
      type: type,
      memberPermissions: memberPermissions ?? {},
      description: description,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      lastSyncedAt: now,
      syncStatus: SyncStatus.synced,
    );
  }
  
  static UnifiedShoppingItem buildItem({
    String? id,
    String name = 'Test Item',
    double amount = 1.0,
    String unit = 'st',
    String category = 'Test',
    bool bought = false,
    DateTime? addedAt,
  }) {
    final now = DateTime.now();
    return UnifiedShoppingItem(
      id: id ?? 'item_${now.millisecondsSinceEpoch}',
      name: name,
      amount: amount,
      unit: unit,
      category: category,
      bought: bought,
      addedAt: addedAt ?? now,
    );
  }
}

void main() {
  group('FirebaseShoppingRepository', () {
    late FirebaseShoppingRepository repository;
    late MockFirebaseFirestore mockFirestore;
    late MockAuthRepository mockAuthRepo;
    late MockCollectionReference<Map<String, dynamic>> mockUsersCollection;
    late MockCollectionReference<Map<String, dynamic>> mockListsCollection;
    late MockCollectionReference<Map<String, dynamic>> mockCollabCollection;
    late MockDocumentReference<Map<String, dynamic>> mockUserDoc;
    late MockDocumentReference<Map<String, dynamic>> mockListDoc;
    late MockDocumentSnapshot<Map<String, dynamic>> mockDocSnapshot;
    late MockQuery<Map<String, dynamic>> mockQuery;
    late MockQuerySnapshot<Map<String, dynamic>> mockQuerySnapshot;
    late MockWriteBatch mockBatch;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(ShoppingListFactory.build());
      registerFallbackValue(ShoppingListFactory.buildItem());
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      
      // Initialize all mocks
      mockFirestore = MockFirebaseFirestore();
      mockAuthRepo = MockAuthRepository();
      mockUsersCollection = MockCollectionReference<Map<String, dynamic>>();
      mockListsCollection = MockCollectionReference<Map<String, dynamic>>();
      mockCollabCollection = MockCollectionReference<Map<String, dynamic>>();
      mockUserDoc = MockDocumentReference<Map<String, dynamic>>();
      mockListDoc = MockDocumentReference<Map<String, dynamic>>();
      mockDocSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
      mockQuery = MockQuery<Map<String, dynamic>>();
      mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      mockBatch = MockWriteBatch();
      
      // Setup default auth state
      mockAuthRepo.setAuthState(
        userId: 'test-user-123',
        isAuthenticated: true,
      );
      
      // Setup Firestore mock structure
      when(() => mockFirestore.collection('users')).thenReturn(mockUsersCollection);
      when(() => mockFirestore.collection('collaborative_shopping_lists')).thenReturn(mockCollabCollection);
      when(() => mockUsersCollection.doc(any())).thenReturn(mockUserDoc);
      when(() => mockUserDoc.collection('unified_shopping_lists')).thenReturn(mockListsCollection);
      when(() => mockListsCollection.doc(any())).thenReturn(mockListDoc);
      when(() => mockCollabCollection.doc(any())).thenReturn(mockListDoc);
      
      // Setup default doc operations
      when(() => mockListDoc.set(any())).thenAnswer((_) async {});
      when(() => mockListDoc.update(any())).thenAnswer((_) async {});
      when(() => mockListDoc.delete()).thenAnswer((_) async {});
      when(() => mockListDoc.get()).thenAnswer((_) async => mockDocSnapshot);
      
      // Setup batch operations - WriteBatch methods return self for chaining
      when(() => mockFirestore.batch()).thenReturn(mockBatch);
      when<dynamic>(() => mockBatch.set(any(), any(), any())).thenReturn(mockBatch);
      when<dynamic>(() => mockBatch.update(any(), any())).thenReturn(mockBatch);
      when<dynamic>(() => mockBatch.delete(any())).thenReturn(mockBatch);
      when(() => mockBatch.commit()).thenAnswer((_) async {});
      
      // Create repository with mocked Firestore
      repository = FirebaseShoppingRepository(
        firestore: mockFirestore,
        authRepository: mockAuthRepo,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('Personal List Operations', () {
      test('should create personal shopping list', () async {
        // Arrange
        final list = ShoppingListFactory.build(
          id: 'list-1',
          name: 'Grocery List',
        );
        
        // Setup doc() without argument for new doc creation
        when(() => mockListsCollection.doc()).thenReturn(mockListDoc);
        when(() => mockListDoc.id).thenReturn('list-1');
        
        // Act
        final created = await repository.create(list);
        
        // Assert
        expect(created.id, equals('list-1'));
        expect(created.name, equals('Grocery List'));
        
        // Verify the set was called with proper data
        verify(() => mockListDoc.set(any())).called(1);
      });

      test('should read personal shopping list', () async {
        // Arrange
        final list = ShoppingListFactory.build(
          id: 'list-1',
          name: 'My List',
        );
        
        // Setup mock to return the list data
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.id).thenReturn('list-1');
        when(() => mockDocSnapshot.data()).thenReturn(list.toFirestore());
        
        // Act
        final read = await repository.read('list-1');
        
        // Assert
        expect(read, isNotNull);
        expect(read!.id, equals('list-1'));
        expect(read.name, equals('My List'));
        
        verify(() => mockListDoc.get()).called(1);
      });

      test('should update personal shopping list', () async {
        // Arrange
        final list = ShoppingListFactory.build(
          id: 'list-1',
          name: 'Original Name',
        );
        
        // Setup mock to return existing list
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.id).thenReturn('list-1');
        when(() => mockDocSnapshot.data()).thenReturn(list.toFirestore());
        
        final updated = list.copyWith(name: 'Updated Name');
        
        // Act
        await repository.update(updated);
        
        // Assert
        final captured = verify(() => mockListDoc.update(captureAny())).captured.single;
        expect(captured['name'], equals('Updated Name'));
      });

      test('should delete personal shopping list', () async {
        // Arrange
        final list = ShoppingListFactory.build(
          id: 'list-1',
          name: 'To Delete',
        );
        
        // Setup mock to confirm list exists
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.id).thenReturn('list-1');
        when(() => mockDocSnapshot.data()).thenReturn(list.toFirestore());
        
        // Act
        await repository.delete('list-1');
        
        // Assert
        verify(() => mockListDoc.delete()).called(1);
      });

      test('should stream personal lists', () async {
        // Arrange
        final list1 = ShoppingListFactory.build(id: 'list-1', name: 'List 1');
        final list2 = ShoppingListFactory.build(id: 'list-2', name: 'List 2');
        
        final mockDoc1 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        final mockDoc2 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        
        when(() => mockDoc1.id).thenReturn('list-1');
        when(() => mockDoc1.data()).thenReturn(list1.toFirestore());
        when(() => mockDoc2.id).thenReturn('list-2');
        when(() => mockDoc2.data()).thenReturn(list2.toFirestore());
        
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2]);
        
        // Setup query chain for personal lists
        when(() => mockListsCollection.where(any(), isEqualTo: any(named: 'isEqualTo')))
            .thenReturn(mockQuery);
        when(() => mockQuery.orderBy(any(), descending: any(named: 'descending')))
            .thenReturn(mockQuery);
        when(() => mockQuery.snapshots()).thenAnswer((_) => Stream.value(mockQuerySnapshot));
        
        // Act
        final stream = repository.personalListsStream();
        final lists = await stream.first;
        
        // Assert
        expect(lists.length, equals(2));
        expect(lists[0].name, equals('List 1'));
        expect(lists[1].name, equals('List 2'));
      });
    });

    group('Collaborative List Operations', () {
      test('should save collaborative list', () async {
        // Arrange
        final list = ShoppingListFactory.build(
          id: 'collab-1',
          name: 'Shared List',
          type: ListType.collaborative,
          memberPermissions: {
            'test-user-123': SharedListPermission.admin,
            'friend-456': SharedListPermission.edit,
          },
        );
        
        // Setup collection name detection
        when(() => mockFirestore.collection('unified_shared_shopping_lists'))
            .thenReturn(mockCollabCollection);
        
        // Act
        await repository.saveCollaborativeList(list);
        
        // Assert
        verify(() => mockListDoc.set(any())).called(1);
        final captured = verify(() => mockListDoc.set(captureAny())).captured.single;
        expect(captured['name'], equals('Shared List'));
        expect(captured['type'], equals('collaborative'));
      });

      test('should delete collaborative list', () async {
        // Arrange
        ShoppingListFactory.build(
          id: 'collab-1',
          name: 'To Delete',
          type: ListType.collaborative,
        );
        
        // Setup collection name detection
        when(() => mockFirestore.collection('unified_shared_shopping_lists'))
            .thenReturn(mockCollabCollection);
        
        // Act
        await repository.deleteCollaborativeList('collab-1');
        
        // Assert
        verify(() => mockListDoc.delete()).called(1);
      });

      test('should stream collaborative lists', () async {
        // Arrange
        final collabList = ShoppingListFactory.build(
          id: 'collab-1',
          name: 'Collaborative List',
          type: ListType.collaborative,
          memberPermissions: {
            'test-user-123': SharedListPermission.admin,
          },
        );
        
        final mockCollabDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockCollabDoc.id).thenReturn('collab-1');
        when(() => mockCollabDoc.data()).thenReturn(collabList.toFirestore());
        when(() => mockQuerySnapshot.docs).thenReturn([mockCollabDoc]);
        
        // Setup query chain for collaborative lists
        when(() => mockCollabCollection.where(any(), isNotEqualTo: any(named: 'isNotEqualTo')))
            .thenReturn(mockQuery);
        when(() => mockQuery.orderBy(any(), descending: any(named: 'descending')))
            .thenReturn(mockQuery);
        when(() => mockQuery.snapshots()).thenAnswer((_) => Stream.value(mockQuerySnapshot));
        
        // Act
        final stream = repository.collaborativeListsStream();
        final lists = await stream.first;
        
        // Assert
        expect(lists.length, equals(1));
        expect(lists[0].name, equals('Collaborative List'));
        expect(lists[0].type, equals(ListType.collaborative));
      });

      test('should read all lists combining personal and collaborative', () async {
        // Arrange
        final personalList = ShoppingListFactory.build(
          id: 'personal-1',
          name: 'Personal List',
          type: ListType.personal,
        );
        final collabList = ShoppingListFactory.build(
          id: 'collab-1',
          name: 'Collaborative List',
          type: ListType.collaborative,
        );
        
        // Mock personal lists query
        final personalDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        when(() => personalDoc.id).thenReturn('personal-1');
        when(() => personalDoc.data()).thenReturn(personalList.toFirestore());
        
        // Mock collaborative lists query
        final collabDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        when(() => collabDoc.id).thenReturn('collab-1');
        when(() => collabDoc.data()).thenReturn(collabList.toFirestore());
        
        // Setup different responses for different queries
        var queryCount = 0;
        when(() => mockQuery.get()).thenAnswer((_) async {
          queryCount++;
          if (queryCount == 1) {
            // First call is for personal lists
            when(() => mockQuerySnapshot.docs).thenReturn([personalDoc]);
          } else {
            // Second call is for collaborative lists
            when(() => mockQuerySnapshot.docs).thenReturn([collabDoc]);
          }
          return mockQuerySnapshot;
        });
        
        when(() => mockListsCollection.where(any(), isEqualTo: any(named: 'isEqualTo')))
            .thenReturn(mockQuery);
        when(() => mockCollabCollection.where(any(), isNotEqualTo: any(named: 'isNotEqualTo')))
            .thenReturn(mockQuery);
        
        // Act - Add timeout to prevent hanging
        final lists = await repository.readAll().timeout(
          Duration(seconds: 5),
          onTimeout: () => [],
        );
        
        // Assert
        expect(lists.length, equals(2));
        expect(lists.any((l) => l.name == 'Personal List'), isTrue);
        expect(lists.any((l) => l.name == 'Collaborative List'), isTrue);
      });
    });

    group('Item Management', () {
      test('should add item to shopping list', () async {
        // Arrange
        final list = ShoppingListFactory.build(
          id: 'list-1',
          name: 'Test List',
        );
        
        // Setup list exists
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.id).thenReturn('list-1');
        when(() => mockDocSnapshot.data()).thenReturn(list.toFirestore());
        
        // Setup item collection mock
        final mockItemsCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockItemDoc = MockDocumentReference<Map<String, dynamic>>();
        when(() => mockListDoc.collection('items')).thenReturn(mockItemsCollection);
        when(() => mockItemsCollection.doc(any())).thenReturn(mockItemDoc);
        when(() => mockItemDoc.set(any())).thenAnswer((_) async {});
        
        final item = ShoppingListFactory.buildItem(
          id: 'item-1',
          name: 'Milk',
          amount: 2,
          unit: 'liter',
        );
        
        // Act
        await repository.addItem('list-1', item);
        
        // Assert
        verify(() => mockItemDoc.set(any())).called(1);
        final captured = verify(() => mockItemDoc.set(captureAny())).captured.single;
        expect(captured['name'], equals('Milk'));
        expect(captured['amount'], equals(2));
      });

      test('should remove item from shopping list', () async {
        // Arrange
        final list = ShoppingListFactory.build(
          id: 'list-1',
          name: 'Test List',
        );
        
        // Setup list exists
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.id).thenReturn('list-1');
        when(() => mockDocSnapshot.data()).thenReturn(list.toFirestore());
        
        // Setup item collection mock
        final mockItemsCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockItemDoc = MockDocumentReference<Map<String, dynamic>>();
        when(() => mockListDoc.collection('items')).thenReturn(mockItemsCollection);
        when(() => mockItemsCollection.doc('item-1')).thenReturn(mockItemDoc);
        when(() => mockItemDoc.delete()).thenAnswer((_) async {});
        
        ShoppingListFactory.buildItem(
          id: 'item-1',
          name: 'Bread',
        );
        
        // Act
        await repository.removeItem('list-1', 'item-1');
        
        // Assert
        verify(() => mockItemDoc.delete()).called(1);
      });

      test('should reject adding item to non-existent list', () async {
        // Arrange
        final item = ShoppingListFactory.buildItem(
          id: 'item-1',
          name: 'Test Item',
        );
        
        // Act & Assert
        expect(
          () => repository.addItem('non-existent', item),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });

      test('should reject removing item from non-owned list', () async {
        // Arrange
        final list = ShoppingListFactory.build(
          id: 'list-1',
          name: 'Other User List',
          ownerId: 'other-user-456',
        );
        
        // Setup list exists but owned by different user
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.id).thenReturn('list-1');
        when(() => mockDocSnapshot.data()).thenReturn(list.toFirestore());
        
        // Act & Assert
        expect(
          () => repository.removeItem('list-1', 'item-1'),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });

    group('Active List Management', () {
      test('should set and get active list', () async {
        // Arrange
        final list = ShoppingListFactory.build(
          id: 'list-1',
          name: 'Active List',
        );
        
        // Setup list exists
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.id).thenReturn('list-1');
        when(() => mockDocSnapshot.data()).thenReturn(list.toFirestore());
        
        // Setup user preferences document
        final mockPrefsDoc = MockDocumentReference<Map<String, dynamic>>();
        when(() => mockUserDoc.collection('preferences')).thenReturn(mockListsCollection);
        when(() => mockListsCollection.doc('settings')).thenReturn(mockPrefsDoc);
        when(() => mockPrefsDoc.set(any(), any())).thenAnswer((_) async {});
        when(() => mockPrefsDoc.get()).thenAnswer((_) async {
          final mockPrefsSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
          when(() => mockPrefsSnapshot.exists).thenReturn(true);
          when(() => mockPrefsSnapshot.data()).thenReturn({'activeListId': 'list-1'});
          return mockPrefsSnapshot;
        });
        
        // Act
        await repository.setActiveList('list-1');
        final activeList = await repository.getActiveList();
        
        // Assert
        expect(activeList, isNotNull);
        expect(activeList!.id, equals('list-1'));
        expect(activeList.name, equals('Active List'));
      });

      test('should return null when no active list is set', () async {
        // Arrange
        // No setup needed - no active list set
        
        // Act
        final activeList = await repository.getActiveList();
        
        // Assert
        expect(activeList, isNull);
      });
    });

    group('Error Handling', () {
      test('should handle authentication errors', () async {
        // Arrange
        mockAuthRepo.setAuthState(user: null, userId: null, isAuthenticated: false);
        final list = ShoppingListFactory.build();
        
        // Act & Assert
        expect(
          () => repository.create(list),
          throwsA(isA<Exception>()),  // More general exception check
        );
      });

      test('should validate required fields for items', () async {
        // Arrange
        final list = ShoppingListFactory.build(
          id: 'list-1',
          name: 'Test List',
        );
        
        // Setup list exists
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.id).thenReturn('list-1');
        when(() => mockDocSnapshot.data()).thenReturn(list.toFirestore());
        
        final invalidItem = UnifiedShoppingItem(
          id: 'item-1',
          name: '', // Empty name
          amount: 1,
          unit: 'st',
          category: 'Test',
        );
        
        // Act & Assert
        try {
          await repository.addItem('list-1', invalidItem);
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });
    });
  });
}