/// Comprehensive unit tests for CollaborativeShoppingOperations
/// 
/// Tests the collaborative shopping operations coordinator that handles shared
/// shopping list management, member coordination, real-time sync, and permissions.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping_operations.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/services/permission_service.dart';

import '../../../infrastructure/helpers/_base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';

// Mock PermissionService
class MockPermissionService extends Mock implements PermissionService {}

// Mock parent service that CollaborativeShoppingOperations delegates to
class MockParentService extends Mock {
  List<UnifiedShoppingList> collaborativeLists = [];
  List<UnifiedShoppingList> personalLists = [];
  String? currentUserId;
  String? currentUserDisplayName;
  
  // Mock methods that operations will delegate to
  Future<String?> createCollaborativeList({
    required String name,
    String? description,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    List<UnifiedShoppingItem>? items,
    List<String>? categoryIds,
    bool allowGuestEditing = true,
    bool autoRemoveCompleted = false,
  }) async {
    final list = UnifiedShoppingList.collaborative(
      name: name,
      ownerId: 'test-user',
      ownerDisplayName: 'Test User',
      memberPermissions: Map.fromEntries(
        memberIds.map((id) => MapEntry(id, SharedListPermission.edit))
      ),
      description: description,
    );
    collaborativeLists.add(list);
    return list.id;
  }
  
  Future<String?> createPersonalList(String name, {List<UnifiedShoppingItem>? items}) async {
    final list = UnifiedShoppingList.personal(
      name: name,
      ownerId: 'test-user',
      ownerDisplayName: 'Test User',
      items: items ?? [],
    );
    personalLists.add(list);
    return list.id;
  }
  
  Future<bool> deleteList(String listId) async => true;
  Future<bool> _updateList(UnifiedShoppingList list) async => true;
  Future<bool> addItemToList(String listId, UnifiedShoppingItem item) async => true;
  Future<bool> removeItemFromList(String listId, String itemId) async => true;
  Future<bool> toggleItemInList(String listId, String itemId) async => true;
}

void main() {
  group('CollaborativeShoppingOperations', () {
    late CollaborativeShoppingOperations operations;
    late MockParentService mockParent;
    late MockPermissionService mockPermissionService;
    late UnifiedShoppingList testCollabList;
    late UnifiedShoppingList testPersonalList;
    late UnifiedShoppingItem testItem;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(UnifiedShoppingList.personal(
        name: 'Test',
        ownerId: 'test',
        ownerDisplayName: 'Test',
      ));
      registerFallbackValue(UnifiedShoppingItem.basic(
        name: 'Test',
        amount: 1.0,
        unit: 'st',
        category: 'Test',
      ));
      registerFallbackValue(SharedListPermission.view);
    });
    
    setUp(() async {
      await TestServiceLocator.initialize();
      
      mockParent = MockParentService();
      mockPermissionService = MockPermissionService();
      
      // Register mock with TestServiceLocator
      TestServiceLocator.registerMock<PermissionService>(mockPermissionService);
      
      operations = CollaborativeShoppingOperations(mockParent);
      
      testItem = UnifiedShoppingItem.basic(
        name: 'Mjölk',
        amount: 1.5,
        unit: 'liter',
        category: 'Mejeri',
      );
      
      testCollabList = UnifiedShoppingList.collaborative(
        name: 'Familjehandling',
        ownerId: 'test-user',
        ownerDisplayName: 'Test User',
        memberPermissions: {
          'member-1': SharedListPermission.edit,
          'member-2': SharedListPermission.view,
        },
        description: 'Gemensam lista för familjen',
      );
      
      testPersonalList = UnifiedShoppingList.personal(
        name: 'Min lista',
        ownerId: 'test-user',
        ownerDisplayName: 'Test User',
        items: [testItem],
      );
      
      mockParent.collaborativeLists = [testCollabList];
      mockParent.personalLists = [testPersonalList];
      
      // Setup permission service mock
      when(() => mockPermissionService.isAuthenticated).thenReturn(true);
      when(() => mockPermissionService.isShoppingListOwner(any())).thenReturn(true);
      when(() => mockPermissionService.canViewShoppingList(any())).thenReturn(true);
      when(() => mockPermissionService.canEditShoppingList(any())).thenReturn(true);
      when(() => mockPermissionService.canManageShoppingList(any())).thenReturn(true);
      when(() => mockPermissionService.canDeleteShoppingList(any())).thenReturn(true);
    });
    
    tearDown(() {
      BaseUnitTest.resetMocks();
      TestServiceLocator.reset();
    });
    
    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });
    
    group('Collaborative List Management', () {
      test('should create collaborative shopping list', () async {
        // Act
        final listId = await operations.createList(
          name: 'Veckans inköp',
          description: 'Gemensam veckolista',
          memberIds: ['friend-1', 'friend-2'],
          memberDisplayNames: {
            'friend-1': 'Anna',
            'friend-2': 'Erik',
          },
          allowGuestEditing: true,
        );
        
        // Assert
        expect(listId, isNotNull);
        expect(mockParent.collaborativeLists.length, equals(2));
      });
      
      test('should get all collaborative lists', () {
        // Act
        final lists = operations.getAllLists();
        
        // Assert
        expect(lists, isNotEmpty);
        expect(lists.first.name, equals('Familjehandling'));
      });
      
      test('should get list by ID', () {
        // Act
        final list = operations.getListById(testCollabList.id);
        
        // Assert
        expect(list, isNotNull);
        expect(list?.name, equals('Familjehandling'));
      });
      
      test('should get owned lists', () {
        // Act
        final ownedLists = operations.getOwnedLists();
        
        // Assert
        expect(ownedLists, isNotEmpty);
      });
      
      test('should get shared with me lists', () {
        // Arrange
        when(() => mockPermissionService.isShoppingListOwner(any())).thenReturn(false);
        
        // Act
        final sharedLists = operations.getSharedWithMe();
        
        // Assert
        expect(sharedLists, isNotEmpty);
      });
      
      test('should convert personal to collaborative', () async {
        // Act
        final collaborativeId = await operations.convertPersonalToCollaborative(
          personalListId: testPersonalList.id,
          memberIds: ['friend-1'],
          memberDisplayNames: {'friend-1': 'Maria'},
          description: 'Nu delad lista',
        );
        
        // Assert
        expect(collaborativeId, isNotNull);
      });
      
      test('should convert collaborative to personal', () async {
        // Arrange
        when(() => mockParent.createPersonalList(any(), items: any(named: 'items')))
            .thenAnswer((_) async => 'personal-list-id');
        when(() => mockParent.deleteList(any())).thenAnswer((_) async => true);
        
        // Act
        final personalId = await operations.convertCollaborativeToPersonal(testCollabList.id);
        
        // Assert
        expect(personalId, isNotNull);
      });
      
      test('should not convert if not owner', () async {
        // Arrange
        when(() => mockPermissionService.isShoppingListOwner(any())).thenReturn(false);
        
        // Act
        final personalId = await operations.convertCollaborativeToPersonal(testCollabList.id);
        
        // Assert
        expect(personalId, isNull);
      });
    });
    
    group('Member Management', () {
      test('should add member to list', () async {
        // Arrange
        when(() => mockParent._updateList(any())).thenAnswer((_) async => true);
        
        // Act
        final success = await operations.addMember(
          listId: testCollabList.id,
          userId: 'new-member',
          userDisplayName: 'New Member',
          permission: SharedListPermission.edit,
        );
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should remove member from list', () async {
        // Arrange
        when(() => mockParent._updateList(any())).thenAnswer((_) async => true);
        
        // Act
        final success = await operations.removeMember(
          listId: testCollabList.id,
          userId: 'member-1',
        );
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should update member permission', () async {
        // Arrange
        when(() => mockParent._updateList(any())).thenAnswer((_) async => true);
        
        // Act
        final success = await operations.updateMemberPermission(
          listId: testCollabList.id,
          userId: 'member-2',
          permission: SharedListPermission.edit,
        );
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should get list members', () {
        // Act
        final members = operations.getListMembers(testCollabList.id);
        
        // Assert
        expect(members, isNotEmpty);
        expect(members.containsKey('member-1'), isTrue);
        expect(members.containsKey('member-2'), isTrue);
      });
      
      test('should check if can manage members', () {
        // Act
        final canManage = operations.canManageMembers(testCollabList.id);
        
        // Assert
        expect(canManage, isTrue);
      });
      
      test('should not manage if not owner', () {
        // Arrange
        when(() => mockPermissionService.canManageShoppingList(any())).thenReturn(false);
        
        // Act
        final canManage = operations.canManageMembers(testCollabList.id);
        
        // Assert
        expect(canManage, isFalse);
      });
      
      test('should leave list as member', () async {
        // Arrange
        mockParent.currentUserId = 'member-1';
        when(() => mockParent._updateList(any())).thenAnswer((_) async => true);
        when(() => mockPermissionService.isAuthenticated).thenReturn(true);
        when(() => mockPermissionService.isShoppingListOwner(any())).thenReturn(false);
        
        // Act
        final success = await operations.leaveList(testCollabList.id);
        
        // Assert
        expect(success, isTrue);
      });
    });
    
    group('Collaborative Item Management', () {
      test('should add item to collaborative list', () async {
        // Arrange
        when(() => mockParent.addItemToList(any(), any())).thenAnswer((_) async => true);
        
        // Act
        final success = await operations.addItem(
          listId: testCollabList.id,
          name: 'Bröd',
          amount: 2.0,
          unit: 'st',
          category: 'Bageri',
        );
        
        // Assert
        expect(success, isTrue);
      });
      
      
      test('should toggle item bought status with user tracking', () async {
        // Arrange
        mockParent.currentUserId = 'member-1';
        mockParent.currentUserDisplayName = 'Anna';
        when(() => mockParent._updateList(any())).thenAnswer((_) async => true);
        
        // Act
        final success = await operations.toggleItemBought(
          listId: testCollabList.id,
          itemId: testItem.id,
        );
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should remove item from collaborative list', () async {
        // Arrange
        when(() => mockParent.removeItemFromList(any(), any())).thenAnswer((_) async => true);
        
        // Act
        final success = await operations.removeItem(
          listId: testCollabList.id,
          itemId: testItem.id,
        );
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should not modify item without permission', () async {
        // Arrange
        when(() => mockPermissionService.canEditShoppingList(any())).thenReturn(false);
        
        // Act
        final success = await operations.addItem(
          listId: testCollabList.id,
          name: 'Test',
          amount: 1.0,
        );
        
        // Assert
        expect(success, isFalse);
      });
    });
    
    group('Activity and Statistics', () {
      test('should get list statistics', () {
        // Act
        final stats = operations.getListStats(testCollabList.id);
        
        // Assert
        expect(stats, isNotEmpty);
        expect(stats['listId'], equals(testCollabList.id));
        expect(stats['memberCount'], isNotNull);
      });
      
      test('should get recent activity', () {
        // Act
        final activity = operations.getRecentActivity(testCollabList.id);
        
        // Assert
        expect(activity, isA<List>());
      });
      
    });
    
    group('Permission Helpers', () {
      test('should check if can edit list', () {
        // Act
        final canEdit = operations.canEdit(testCollabList.id);
        
        // Assert
        expect(canEdit, isTrue);
      });
      
      test('should check if can view list', () {
        // Act
        final canView = operations.canView(testCollabList.id);
        
        // Assert
        expect(canView, isTrue);
      });
      
      test('should check if can delete list', () {
        // Act
        final canDelete = operations.canDelete(testCollabList.id);
        
        // Assert
        expect(canDelete, isTrue);
      });
      
      test('should get user permission', () {
        // Act
        final permission = operations.getUserPermission(testCollabList.id);
        
        // Assert
        expect(permission, isNotNull);
      });
      
      test('should get notification count', () {
        // Act
        final count = operations.getNotificationCount();
        
        // Assert
        expect(count, isA<int>());
      });
      
      test('should mark list as seen', () async {
        // Act
        final success = await operations.markListAsSeen(testCollabList.id);
        
        // Assert
        expect(success, isTrue);
      });
    });
    
    group('Edge Cases', () {
      test('should handle list not found', () async {
        // Act
        final list = operations.getListById('non-existent');
        final members = operations.getListMembers('non-existent');
        
        // Assert
        expect(list, isNull);
        expect(members, isEmpty);
      });
      
      test('should handle empty member lists', () async {
        // Act
        final listId = await operations.createList(
          name: 'Solo list',
          memberIds: [],
          memberDisplayNames: {},
        );
        
        // Assert
        expect(listId, isNotNull);
      });
      
      test('should handle permission errors gracefully', () async {
        // Arrange
        when(() => mockPermissionService.isAuthenticated).thenReturn(false);
        
        // Act
        final ownedLists = operations.getOwnedLists();
        final sharedLists = operations.getSharedWithMe();
        
        // Assert
        expect(ownedLists, isEmpty);
        expect(sharedLists, isEmpty);
      });
      
      test('should handle member not found in removal', () async {
        // Act
        final success = await operations.removeMember(
          listId: testCollabList.id,
          userId: 'non-existent-member',
        );
        
        // Assert
        expect(success, isFalse);
      });
      
    });
  });
}