/// Unit tests for ShoppingFirebaseSync - Handles Firebase synchronization for shopping lists
///
/// Tests business logic for shopping list synchronization including:
/// - Sync collection configuration
/// - User authentication checks
/// - List type handling
/// - Error callback management
///
/// NOTE: Actual Firebase operations (requiring FirebaseFirestore, DocumentSnapshot, and Query)
/// are tested in integration tests, following the hybrid testing strategy
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

// Production imports
import 'package:butlery/services/unified/modules/shopping_firebase_sync.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';

// Test infrastructure
import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';

void main() {
  group('ShoppingFirebaseSync', () {
    late FakeFirebaseFirestore fakeFirestore;
    late ShoppingFirebaseSync shoppingSync;
    late String? currentUserId;
    late List<UnifiedShoppingList> updatedLists;
    late List<String> removedListIds;
    late List<String> errors;
    
    setUpAll(() async {
      // Initialize test infrastructure once for all tests
      await BaseUnitTest.setupUnit();
    });
    
    setUp(() async {
      // Initialize service locator for each test
      await TestServiceLocator.initialize();
      
      // Initialize test state
      fakeFirestore = FakeFirebaseFirestore();
      currentUserId = 'user-123';
      updatedLists = [];
      removedListIds = [];
      errors = [];
      
      // Create ShoppingFirebaseSync instance
      shoppingSync = ShoppingFirebaseSync(
        firestore: fakeFirestore,
        getCurrentUserId: () => currentUserId,
        updateLocalList: (list) => updatedLists.add(list),
        removeLocalList: (id) => removedListIds.add(id),
        setError: (error) => errors.add(error),
      );
    });
    
    tearDown(() async {
      // Reset mocks and service locator after each test
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    tearDownAll(() async {
      // Final cleanup after all tests
      await BaseUnitTest.teardownUnit();
    });
    
    group('Personal List Sync', () {
      test('should sync personal list to Firebase', () async {
        // Arrange
        final list = UnifiedShoppingList.personal(
          name: 'Veckans inköp',
          ownerId: currentUserId!,
          ownerDisplayName: 'Test User',
          items: [
            UnifiedShoppingItem(
              name: 'Mjölk',
              amount: 1,
              unit: 'l',
              category: 'Mejeri',
            ),
          ],
        );
        
        // Act
        await shoppingSync.syncPersonalListToFirebase(list);
        
        // Assert
        final doc = await fakeFirestore
            .collection('users')
            .doc(currentUserId!)
            .collection('unified_shopping_lists')
            .doc(list.id)
            .get();
        
        expect(doc.exists, isTrue);
        expect(doc.data()?['name'], equals('Veckans inköp'));
      });
      
      test('should not sync personal list when user not authenticated', () async {
        // Arrange
        currentUserId = null;
        final list = UnifiedShoppingList.personal(
          name: 'Test List',
          ownerId: 'owner-123',
          ownerDisplayName: 'Test User',
        );
        
        // Act
        await shoppingSync.syncPersonalListToFirebase(list);
        
        // Assert
        final snapshot = await fakeFirestore
            .collection('users')
            .get();
        expect(snapshot.docs, isEmpty);
      });
    });
    
    group('Collaborative List Sync', () {
      test('should sync collaborative list to Firebase', () async {
        // Arrange
        final list = UnifiedShoppingList.collaborative(
          name: 'Gemensam lista',
          ownerId: currentUserId!,
          ownerDisplayName: 'Test User',
          memberPermissions: {
            'friend-1': SharedListPermission.edit,
            'friend-2': SharedListPermission.view,
          },
        );
        
        // Act
        await shoppingSync.syncCollaborativeListToFirebase(list);
        
        // Assert
        final doc = await fakeFirestore
            .collection('unified_shared_shopping_lists')
            .doc(list.id)
            .get();
        
        expect(doc.exists, isTrue);
        expect(doc.data()?['name'], equals('Gemensam lista'));
      });
      
      test('should not sync collaborative list when user not authenticated', () async {
        // Arrange
        currentUserId = null;
        final list = UnifiedShoppingList.collaborative(
          name: 'Test List',
          ownerId: 'owner-123',
          ownerDisplayName: 'Test User',
          memberPermissions: {},
        );
        
        // Act
        await shoppingSync.syncCollaborativeListToFirebase(list);
        
        // Assert
        final snapshot = await fakeFirestore
            .collection('unified_shared_shopping_lists')
            .get();
        expect(snapshot.docs, isEmpty);
      });
    });
    
    group('List Deletion', () {
      test('should delete personal list from Firebase', () async {
        // Arrange
        const listId = 'list-123';
        const isCollaborative = false;
        
        // First add a list to delete
        await fakeFirestore
            .collection('users')
            .doc(currentUserId!)
            .collection('unified_shopping_lists')
            .doc(listId)
            .set({'name': 'Test List'});
        
        // Act
        await shoppingSync.deleteListFromFirebase(listId, isCollaborative);
        
        // Assert
        final doc = await fakeFirestore
            .collection('users')
            .doc(currentUserId!)
            .collection('unified_shopping_lists')
            .doc(listId)
            .get();
        
        expect(doc.exists, isFalse);
      });
      
      test('should delete collaborative list from Firebase', () async {
        // Arrange
        const listId = 'list-123';
        const isCollaborative = true;
        
        // First add a list to delete
        await fakeFirestore
            .collection('unified_shared_shopping_lists')
            .doc(listId)
            .set({'name': 'Test List'});
        
        // Act
        await shoppingSync.deleteListFromFirebase(listId, isCollaborative);
        
        // Assert
        final doc = await fakeFirestore
            .collection('unified_shared_shopping_lists')
            .doc(listId)
            .get();
        
        expect(doc.exists, isFalse);
      });
      
      test('should not delete list when user not authenticated', () async {
        // Arrange
        const listId = 'list-123';
        
        // Add a list first
        await fakeFirestore
            .collection('users')
            .doc('user-123')
            .collection('unified_shopping_lists')
            .doc(listId)
            .set({'name': 'Test List'});
        
        // Change user to null
        currentUserId = null;
        
        // Act
        await shoppingSync.deleteListFromFirebase(listId, false);
        
        // Assert - List should still exist
        final doc = await fakeFirestore
            .collection('users')
            .doc('user-123')
            .collection('unified_shopping_lists')
            .doc(listId)
            .get();
        
        expect(doc.exists, isTrue);
      });
    });
    
    group('Item Sync', () {
      test('should sync item for personal list', () async {
        // Arrange
        final personalList = UnifiedShoppingList.personal(
          name: 'Personal List',
          ownerId: currentUserId!,
          ownerDisplayName: 'Test User',
        );
        
        final lists = [personalList];
        
        // Act
        await shoppingSync.syncItemToFirebase(personalList.id, lists);
        
        // Assert
        final doc = await fakeFirestore
            .collection('users')
            .doc(currentUserId!)
            .collection('unified_shopping_lists')
            .doc(personalList.id)
            .get();
        
        expect(doc.exists, isTrue);
      });
      
      test('should sync item for collaborative list', () async {
        // Arrange
        final collabList = UnifiedShoppingList.collaborative(
          name: 'Collab List',
          ownerId: currentUserId!,
          ownerDisplayName: 'Test User',
          memberPermissions: {'friend-1': SharedListPermission.edit},
        );
        
        final lists = [collabList];
        
        // Act
        await shoppingSync.syncItemToFirebase(collabList.id, lists);
        
        // Assert
        final doc = await fakeFirestore
            .collection('unified_shared_shopping_lists')
            .doc(collabList.id)
            .get();
        
        expect(doc.exists, isTrue);
      });
      
      test('should not sync item when list not found', () async {
        // Arrange
        const itemId = 'non-existent';
        final lists = <UnifiedShoppingList>[];
        
        // Act
        await shoppingSync.syncItemToFirebase(itemId, lists);
        
        // Assert - No documents should be created
        final personalSnapshot = await fakeFirestore
            .collection('users')
            .doc(currentUserId!)
            .collection('unified_shopping_lists')
            .get();
        final collabSnapshot = await fakeFirestore
            .collection('unified_shared_shopping_lists')
            .get();
        
        expect(personalSnapshot.docs, isEmpty);
        expect(collabSnapshot.docs, isEmpty);
      });
      
      test('should not sync template list', () async {
        // Arrange
        final templateList = UnifiedShoppingList(
          name: 'Template',
          ownerId: currentUserId!,
          ownerDisplayName: 'Test User',
          type: ListType.template,
        );
        
        final lists = [templateList];
        
        // Act
        await shoppingSync.syncItemToFirebase(templateList.id, lists);
        
        // Assert - No documents should be created
        final personalSnapshot = await fakeFirestore
            .collection('users')
            .doc(currentUserId!)
            .collection('unified_shopping_lists')
            .get();
        final collabSnapshot = await fakeFirestore
            .collection('unified_shared_shopping_lists')
            .get();
        
        expect(personalSnapshot.docs, isEmpty);
        expect(collabSnapshot.docs, isEmpty);
      });
    });
    
    group('Sync Collections Configuration', () {
      test('should define sync collections configuration', () {
        // Act
        final collections = shoppingSync.syncCollections;
        
        // Assert
        expect(collections.length, equals(2));
        expect(collections[0].name, equals('personal_shopping_lists'));
        expect(collections[1].name, equals('collaborative_shopping_lists'));
      });
      
      test('should have proper handlers for personal lists', () {
        // Arrange
        final collection = shoppingSync.syncCollections[0];
        
        // Assert
        expect(collection.onAdded, isNotNull);
        expect(collection.onModified, isNotNull);
        expect(collection.onRemoved, isNotNull);
        expect(collection.onError, isNotNull);
        expect(collection.query, isNotNull);
      });
      
      test('should have proper handlers for collaborative lists', () {
        // Arrange
        final collection = shoppingSync.syncCollections[1];
        
        // Assert
        expect(collection.onAdded, isNotNull);
        expect(collection.onModified, isNotNull);
        expect(collection.onRemoved, isNotNull);
        expect(collection.onError, isNotNull);
        expect(collection.query, isNotNull);
      });
      
      test('should handle error callbacks', () {
        // Arrange
        final personalCollection = shoppingSync.syncCollections[0];
        final collabCollection = shoppingSync.syncCollections[1];
        
        // Act
        personalCollection.onError!('Personal error');
        collabCollection.onError!('Collab error');
        
        // Assert
        expect(errors.length, equals(2));
        expect(errors[0], contains('Personal lists sync error'));
        expect(errors[1], contains('Collaborative lists sync error'));
      });
    });
  });
}

// NOTE: Methods requiring DocumentSnapshot and Query (syncCollections callbacks with actual documents)
// should be tested in integration tests with Firebase emulator
// See: test/integration/firebase/shopping_firebase_sync_integration_test.dart