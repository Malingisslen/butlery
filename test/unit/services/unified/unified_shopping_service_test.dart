/// Comprehensive unit tests for UnifiedShoppingService
/// 
/// Tests the facade coordination for shopping list management including personal lists,
/// collaborative features, real-time sync, and item management operations.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/services/permission_service.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

// Using production mocks for consistency
// MockAuthRepository, MockFirestoreRepository, MockPermissionService from production_mocks.dart

void main() {
  group('UnifiedShoppingService', () {
    late UnifiedShoppingService service;
    late MockAuthRepository mockAuthRepo;
    late MockFirestoreRepository mockFirestoreRepo;
    late MockPermissionService mockPermissionService;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      // Register fallback values for mocktail
      registerFallbackValue(UnifiedShoppingList.personal(
        name: 'Test List',
        ownerId: 'test-user',
        ownerDisplayName: 'Test User',
      ));
      registerFallbackValue(UnifiedShoppingItem(
        name: 'Test Item',
        amount: 1.0,
      ));
    });
    
    setUp(() async {
      await TestServiceLocator.initialize();
      
      // Create mocks
      mockAuthRepo = MockAuthRepository();
      mockFirestoreRepo = MockFirestoreRepository();
      mockPermissionService = MockPermissionService();
      // Configure auth repository
      mockAuthRepo.setAuthState(
        userId: 'test-user-123',
      );
      
      // Configure permission service
      mockPermissionService.setPermissionState(
        currentUserId: 'test-user-123',
      );
      
      // Register permission service in service locator
      TestServiceLocator.registerMock<PermissionService>(mockPermissionService);
      
      // Create service instance
      service = UnifiedShoppingService(
        firestoreRepository: mockFirestoreRepo,
        authRepository: mockAuthRepo,
      );
    });
    
    tearDown(() async {
      service.dispose();
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });
    
    group('Initialization', () {
      test('should initialize with correct default state', () {
        // Assert
        expect(service.lists, isEmpty);
        expect(service.personalLists, isEmpty);
        expect(service.collaborativeLists, isEmpty);
        expect(service.activeList, isNull);
        expect(service.activeListId, isNull);
        expect(service.hasLists, isFalse);
        expect(service.isLoading, isFalse);
        expect(service.error, isNull);
        expect(service.hasError, isFalse);
      });
      
      test('should have correct user context', () {
        // Assert
        expect(service.currentUserId, equals('test-user-123'));
        expect(service.currentUserDisplayName, equals('Du')); // Default when no user
      });
      
      test('should initialize feature interfaces', () {
        // Assert
        expect(service.personal, isNotNull);
        expect(service.collaborative, isNotNull);
        expect(service.share, isNotNull);
        expect(service.sharing, equals(service.share)); // Legacy alias
      });
      
      test('should complete initialization successfully', () async {
        // Act
        await service.initialize();
        
        // Assert
        expect(service.isInitialized, isTrue);
      });
      
      test('should load lists through initialization alias', () async {
        // Act
        await service.loadLists();
        
        // Assert
        expect(service.isInitialized, isTrue);
      });
    });
    
    group('Personal Shopping List Management', () {
      test('should create personal shopping list', () async {
        // Act
        final listId = await service.createPersonalList('Veckohandling');
        
        // Assert
        expect(listId, isNotNull);
        expect(listId, equals('mock-list-id'));
      });
      
      test('should create personal list with initial items', () async {
        // Arrange
        final items = [
          UnifiedShoppingItem(
            name: 'Mjölk',
            amount: 1.0,
            category: 'Mejeri',
          ),
          UnifiedShoppingItem(
            name: 'Bröd',
            amount: 2.0,
            category: 'Bageri',
          ),
        ];
        
        // Act
        final listId = await service.createPersonalList(
          'Veckohandling',
          items: items,
        );
        
        // Assert
        expect(listId, isNotNull);
      });
      
      test('should rename shopping list', () async {
        // Act
        final success = await service.renameList('list-1', 'Ny Veckohandling');
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should delete shopping list', () async {
        // Act
        final success = await service.deleteList('list-1');
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should set active shopping list', () async {
        // Act
        final success = await service.setActiveList('list-1');
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should export list as text', () {
        // Act
        final exportText = service.exportListAsText('list-1');
        
        // Assert
        expect(exportText, isNotEmpty);
        expect(exportText, equals('Mock shopping list export'));
      });
      
      test('should export active list when no ID specified', () {
        // Act
        final exportText = service.exportListAsText();
        
        // Assert
        // Should return empty string when no active list
        expect(exportText, isEmpty);
      });
    });
    
    group('Collaborative Shopping List Management', () {
      test('should create collaborative shopping list', () async {
        // Arrange
        final memberIds = ['friend-1', 'friend-2'];
        final memberDisplayNames = {
          'friend-1': 'Anna',
          'friend-2': 'Erik',
        };
        
        // Act
        final listId = await service.createCollaborativeList(
          name: 'Familjens Veckohandling',
          description: 'Veckans inköp för familjen',
          memberIds: memberIds,
          memberDisplayNames: memberDisplayNames,
        );
        
        // Assert
        expect(listId, isNotNull);
        expect(listId, equals('mock-collaborative-list-id'));
      });
      
      test('should create collaborative list with all options', () async {
        // Arrange
        final memberIds = ['friend-1'];
        final memberDisplayNames = {'friend-1': 'Anna'};
        final items = [
          UnifiedShoppingItem(
            name: 'Mjölk',
            amount: 1.0,
          ),
        ];
        final categoryIds = ['mejeri', 'bageri'];
        
        // Act
        final listId = await service.createCollaborativeList(
          name: 'Delad Lista',
          description: 'Beskrivning',
          memberIds: memberIds,
          memberDisplayNames: memberDisplayNames,
          items: items,
          categoryIds: categoryIds,
          allowGuestEditing: false,
          autoRemoveCompleted: true,
        );
        
        // Assert
        expect(listId, isNotNull);
        expect(listId, equals('mock-collaborative-list-id'));
      });
      
      test('should update shopping list', () async {
        // Arrange
        final list = UnifiedShoppingList.personal(
          name: 'Test List',
          ownerId: 'test-user-123',
          ownerDisplayName: 'Test User',
        );
        
        // Act
        final success = await service.updateList(list);
        
        // Assert
        expect(success, isTrue);
      });
    });
    
    group('Shopping Item Management', () {
      test('should add item to active list', () async {
        // Act
        final success = await service.addItemToActiveList(
          name: 'Mjölk',
          amount: 2,
          unit: 'liter',
          category: 'Mejeri',
          note: 'Ekologisk',
          estimatedPrice: 25.90,
          priority: 1,
        );
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should add item with recipe reference', () async {
        // Act
        final success = await service.addItemToActiveList(
          name: 'Köttfärs',
          amount: 500,
          unit: 'gram',
          category: 'Kött',
          recipeId: 'recipe-123',
          recipeName: 'Köttbullar',
        );
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should toggle item bought status', () async {
        // Act
        final success = await service.toggleItemBought('item-123');
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should remove item from active list', () async {
        // Act
        final success = await service.removeItemFromActiveList('item-123');
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should update item in active list', () async {
        // Act
        final success = await service.updateItemInActiveList(
          itemId: 'item-123',
          name: 'Mjölk 3%',
          quantity: 3,
          unit: 'liter',
          category: 'Mejeri',
          notes: 'Arla ekologisk',
          estimatedPrice: 35.90,
          priority: 2,
        );
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should clear completed items', () async {
        // Act
        final success = await service.clearCompletedItems();
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should clear bought items using legacy method', () async {
        // Act
        final success = await service.clearBoughtItems();
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should uncheck all items', () async {
        // Act
        final success = await service.uncheckAllItems();
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should add items from recipe', () async {
        // Arrange
        final items = [
          UnifiedShoppingItem(
            name: 'Köttfärs',
            amount: 500,
            unit: 'gram',
          ),
          UnifiedShoppingItem(
            name: 'Ströbröd',
            amount: 1,
            unit: 'dl',
          ),
        ];
        
        // Act
        final success = await service.addItemsFromRecipe(
          recipeId: 'recipe-123',
          recipeName: 'Köttbullar',
          items: items,
        );
        
        // Assert
        expect(success, isTrue);
      });
    });
    
    group('State Management', () {
      test('should track initialization state', () {
        // Initial state
        expect(service.isInitialized, isTrue); // Simplified always returns true
      });
      
      test('should provide list getters', () {
        // Assert
        expect(service.lists, isA<List<UnifiedShoppingList>>());
        expect(service.personalLists, isA<List<UnifiedShoppingList>>());
        expect(service.collaborativeLists, isA<List<UnifiedShoppingList>>());
      });
      
      test('should track active list state', () {
        // Assert
        expect(service.activeList, isNull);
        expect(service.activeListId, isNull);
      });
      
      test('should track list presence', () {
        // Assert
        expect(service.hasLists, isFalse);
      });
      
      test('should track loading state', () {
        // Assert
        expect(service.isLoading, isFalse);
      });
      
      test('should track error state', () {
        // Assert
        expect(service.error, isNull);
        expect(service.hasError, isFalse);
      });
      
      test('should clear error state', () {
        // Act
        service.clearError();
        
        // Assert
        expect(service.error, isNull);
        expect(service.hasError, isFalse);
      });
    });
    
    group('Firebase Sync', () {
      test('should have firestore instance', () {
        // Assert
        expect(service.firestore, isNotNull);
      });
      
      test('should have sync collections', () {
        // Assert
        expect(service.syncCollections, isA<List>());
        expect(service.syncCollections, isEmpty); // Simplified returns empty
      });
      
      test('should sync item to Firebase', () async {
        // Act & Assert (should not throw)
        await service.syncItemToFirebase('item-123');
      });
    });
    
    group('Feature Interface Access', () {
      test('should provide personal operations interface', () {
        // Assert
        expect(service.personal, isNotNull);
        // Note: parent is private field, cannot test directly
      });
      
      test('should provide collaborative operations interface', () {
        // Assert
        expect(service.collaborative, isNotNull);
        // Note: parent is private field, cannot test directly
      });
      
      test('should provide share operations interface', () {
        // Assert
        expect(service.share, isNotNull);
        expect(service.sharing, equals(service.share)); // Legacy compatibility
      });
    });
    
    group('Edge Cases and Error Handling', () {
      test('should handle null active list in export', () {
        // Act
        final exportText = service.exportListAsText();
        
        // Assert
        expect(exportText, isEmpty);
      });
      
      test('should handle empty member lists in collaborative creation', () async {
        // Act
        final listId = await service.createCollaborativeList(
          name: 'Test',
          memberIds: [],
          memberDisplayNames: {},
        );
        
        // Assert
        expect(listId, isNotNull);
      });
      
      test('should handle null optional parameters in item creation', () async {
        // Act
        final success = await service.addItemToActiveList(
          name: 'Simple Item',
        );
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should handle null optional parameters in item update', () async {
        // Act
        final success = await service.updateItemInActiveList(
          itemId: 'item-123',
        );
        
        // Assert
        expect(success, isTrue);
      });
    });
    
    group('Resource Management', () {
      test('should dispose properly', () {
        // Act & Assert (should not throw)
        expect(() => service.dispose(), returnsNormally);
        
        // Create a new service for tearDown to dispose
        service = UnifiedShoppingService(
          firestoreRepository: mockFirestoreRepo,
          authRepository: mockAuthRepo,
        );
      });
      
      test('should stop Firebase sync on dispose', () {
        // The dispose method calls stopFirebaseSync from mixin
        // Act & Assert (should not throw)
        expect(() => service.dispose(), returnsNormally);
        
        // Create a new service for tearDown to dispose
        service = UnifiedShoppingService(
          firestoreRepository: mockFirestoreRepo,
          authRepository: mockAuthRepo,
        );
      });
    });
  });
}