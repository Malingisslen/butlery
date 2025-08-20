// test/unit/services/unified/operations/collaborative_shopping_operations_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping_operations.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:get_it/get_it.dart';
import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';

void main() {
  group('CollaborativeShoppingOperations', () {
    late MockUnifiedShoppingService mockParentService;
    late MockPermissionService mockPermissionService;
    late CollaborativeShoppingOperations operations;
    late UnifiedShoppingList testList1;
    late UnifiedShoppingList testList2;
    late UnifiedShoppingItem testItem1;
    late UnifiedShoppingItem testItem2;
    
    setUpAll(() async {
      // Register fallback values for mocktail
      registerFallbackValue(SharedListPermission.view);
      registerFallbackValue(<String>[]);
      registerFallbackValue(<String, String>{});
      registerFallbackValue(<UnifiedShoppingItem>[]);
    });

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      
      // Create mocks
      mockParentService = MockUnifiedShoppingService();
      mockPermissionService = MockPermissionService();
      
      // Register permission service
      if (GetIt.instance.isRegistered<PermissionService>()) {
        GetIt.instance.unregister<PermissionService>();
      }
      GetIt.instance.registerSingleton<PermissionService>(mockPermissionService);
      
      // Create test data
      testItem1 = UnifiedShoppingItem(
        id: 'item_1',
        name: 'Mjölk',
        amount: 2.0,
        unit: 'l',
        category: 'Mejeri',
        bought: false,
        addedByUserId: 'user_123',
        addedByDisplayName: 'Test User',
        addedAt: DateTime.now(),
      );
      
      testItem2 = UnifiedShoppingItem(
        id: 'item_2',
        name: 'Bröd',
        amount: 1.0,
        unit: 'st',
        category: 'Bageri',
        bought: false,
        addedByUserId: 'user_456',
        addedByDisplayName: 'Other User',
        addedAt: DateTime.now(),
      );
      
      testList1 = UnifiedShoppingList(
        id: 'list_1',
        name: 'Familjehandling',
        description: 'Veckans mat',
        ownerId: 'user_123',
        ownerDisplayName: 'Test User',
        memberPermissions: {
          'user_123': SharedListPermission.admin,
          'user_456': SharedListPermission.edit,
        },
        items: [testItem1],
        type: ListType.collaborative,
        allowGuestEditing: true,
        autoRemoveCompleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      testList2 = UnifiedShoppingList(
        id: 'list_2',
        name: 'Shared List',
        ownerId: 'user_456',
        ownerDisplayName: 'Other User',
        memberPermissions: {
          'user_456': SharedListPermission.admin,
          'user_123': SharedListPermission.view,
        },
        items: [testItem2],
        type: ListType.collaborative,
        allowGuestEditing: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Configure mock parent service using configuration methods
      mockParentService.setShoppingState(
        collaborativeLists: [testList1, testList2],
        currentUserId: 'user_123',
        currentUserDisplayName: 'Test User',
      );
      when(() => mockParentService.updateList(any())).thenAnswer((_) async => true);
      
      // Configure mock permission service using configuration methods
      mockPermissionService.setPermissionState(
        isAuthenticated: true,
        currentUserId: 'user_123',
        shoppingListOwnership: {
          'list_1': true,
          'list_2': false,
        },
        shoppingListEditPermissions: {
          'list_1': true,
          'list_2': false,
        },
      );
      when(() => mockPermissionService.canViewShoppingList(any())).thenReturn(true);
      when(() => mockPermissionService.canManageShoppingList(any())).thenReturn(true);
      when(() => mockPermissionService.canDeleteShoppingList(any())).thenReturn(true);
      
      // Create operations instance
      operations = CollaborativeShoppingOperations(mockParentService);
    });
    
    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      // Cleanup if needed
    });
    
    group('Collaborative List Management', () {
      test('should create collaborative list', () async {
        // Arrange
        when(() => mockParentService.createCollaborativeList(
          name: any(named: 'name'),
          description: any(named: 'description'),
          memberIds: any(named: 'memberIds'),
          memberDisplayNames: any(named: 'memberDisplayNames'),
          items: any(named: 'items'),
          categoryIds: any(named: 'categoryIds'),
          allowGuestEditing: any(named: 'allowGuestEditing'),
          autoRemoveCompleted: any(named: 'autoRemoveCompleted'),
        )).thenAnswer((_) async => 'new_list_id');
        
        // Act
        final listId = await operations.createList(
          name: 'New Collaborative List',
          description: 'Test description',
          memberIds: ['user_123', 'user_789'],
          memberDisplayNames: {
            'user_123': 'Test User',
            'user_789': 'New User',
          },
          allowGuestEditing: true,
          autoRemoveCompleted: false,
        );
        
        // Assert
        expect(listId, equals('new_list_id'));
        verify(() => mockParentService.createCollaborativeList(
          name: 'New Collaborative List',
          description: 'Test description',
          memberIds: ['user_123', 'user_789'],
          memberDisplayNames: any(named: 'memberDisplayNames'),
          items: null,
          categoryIds: null,
          allowGuestEditing: true,
          autoRemoveCompleted: false,
        )).called(1);
      });
      
      test('should get all collaborative lists', () {
        // Act
        final lists = operations.getAllLists();
        
        // Assert
        expect(lists.length, equals(2));
        expect(lists, contains(testList1));
        expect(lists, contains(testList2));
      });
      
      test('should get list by ID', () {
        // Act
        final list = operations.getListById('list_1');
        
        // Assert
        expect(list, isNotNull);
        expect(list?.id, equals('list_1'));
        expect(list?.name, equals('Familjehandling'));
      });
      
      test('should return null for non-existent list', () {
        // Act
        final list = operations.getListById('non_existent');
        
        // Assert
        expect(list, isNull);
      });
      
      test('should get owned lists', () {
        // Act
        final ownedLists = operations.getOwnedLists();
        
        // Assert
        expect(ownedLists.length, equals(1));
        expect(ownedLists.first.id, equals('list_1'));
      });
      
      test('should get lists shared with user', () {
        // Act
        final sharedLists = operations.getSharedWithMe();
        
        // Assert
        expect(sharedLists.length, equals(1));
        expect(sharedLists.first.id, equals('list_2'));
      });
    });
    
    group('Member Management', () {
      test('should add member to list', () async {
        // Arrange
        when(() => mockParentService.updateList(any())).thenAnswer((_) async => true);
        
        // Act
        final result = await operations.addMember(
          listId: 'list_1',
          userId: 'user_789',
          userDisplayName: 'New Member',
          permission: SharedListPermission.edit,
        );
        
        // Assert
        expect(result, isTrue);
        verify(() => mockParentService.updateList(any())).called(1);
      });
      
      test('should remove member from list', () async {
        // Arrange
        when(() => mockParentService.updateList(any())).thenAnswer((_) async => true);
        
        // Act
        final result = await operations.removeMember(
          listId: 'list_1',
          userId: 'user_456',
        );
        
        // Assert
        expect(result, isTrue);
        verify(() => mockParentService.updateList(any())).called(1);
      });
      
      test('should update member permission', () async {
        // Arrange
        when(() => mockParentService.updateList(any())).thenAnswer((_) async => true);
        
        // Act
        final result = await operations.updateMemberPermission(
          listId: 'list_1',
          userId: 'user_456',
          permission: SharedListPermission.admin,
        );
        
        // Assert
        expect(result, isTrue);
        verify(() => mockParentService.updateList(any())).called(1);
      });
      
      test('should get list members', () {
        // Act
        final members = operations.getListMembers('list_1');
        
        // Assert
        expect(members.length, equals(2));
        expect(members.keys, containsAll(['user_123', 'user_456']));
      });
      
      test('should check if user is member', () {
        // Act
        final members = operations.getListMembers('list_1');
        final isMember = members.containsKey('user_456');
        final isNotMember = members.containsKey('user_789');
        
        // Assert
        expect(isMember, isTrue);
        expect(isNotMember, isFalse);
      });
    });
    
    group('Item Management', () {
      test('should add item to collaborative list', () async {
        // Arrange
        // currentUserDisplayName already configured in setUp
        when(() => mockParentService.updateList(any())).thenAnswer((_) async => true);
        
        // Act
        final result = await operations.addItem(
          listId: 'list_1',
          name: 'Ägg',
          amount: 12.0,
          unit: 'st',
          category: 'Mejeri',
          note: 'Ekologiska',
        );
        
        // Assert
        expect(result, isTrue);
        verify(() => mockParentService.updateList(any())).called(1);
      });
      
      test('should toggle item bought status in collaborative list', () async {
        // Arrange
        // currentUserDisplayName already configured in setUp
        when(() => mockParentService.updateList(any())).thenAnswer((_) async => true);
        
        // Act
        final result = await operations.toggleItemBought(
          listId: 'list_1',
          itemId: 'item_1',
        );
        
        // Assert
        expect(result, isTrue);
        verify(() => mockParentService.updateList(any())).called(1);
      });
      
      test('should remove item from collaborative list', () async {
        // Arrange
        // currentUserDisplayName already configured in setUp
        when(() => mockParentService.updateList(any())).thenAnswer((_) async => true);
        
        // Act
        final result = await operations.removeItem(
          listId: 'list_1',
          itemId: 'item_1',
        );
        
        // Assert
        expect(result, isTrue);
        verify(() => mockParentService.updateList(any())).called(1);
      });
      
      test('should leave collaborative list', () async {
        // Arrange
        // isShoppingListOwner already configured in setUp
        when(() => mockParentService.updateList(any())).thenAnswer((_) async => true);
        
        // Act
        final result = await operations.leaveList('list_2');
        
        // Assert
        expect(result, isTrue);
      });
      
      test('should not allow owner to leave list', () async {
        // Arrange
        // isShoppingListOwner already configured in setUp
        
        // Act
        final result = await operations.leaveList('list_1');
        
        // Assert
        expect(result, isFalse);
      });
    });
    
    group('List Statistics and Activity', () {
      test('should get list statistics', () {
        // Act
        final result = operations.getListStats('list_1');
        
        // Assert
        expect(result['totalItems'], equals(1));
        expect(result['boughtItems'], equals(0));
        expect(result['remainingItems'], equals(1));
        expect(result['memberCount'], equals(2));
        expect(result['listName'], equals('Familjehandling'));
      });
      
      test('should get recent activity', () {
        // Act
        final result = operations.getRecentActivity('list_1');
        
        // Assert
        expect(result, isNotEmpty);
        expect(result.first['type'], equals('list_updated'));
        expect(result.first['description'], equals('Lista uppdaterad'));
      });
      
      test('should mark list as seen', () async {
        // Act
        final result = await operations.markListAsSeen('list_1');
        
        // Assert
        expect(result, isTrue);
      });
    });
    
    group('Permissions and Access Control', () {
      test('should check if user can edit list', () {
        // Act
        final canEdit1 = operations.canEdit('list_1');
        final canEdit2 = operations.canEdit('list_2');
        
        // Assert
        expect(canEdit1, isTrue);
        expect(canEdit2, isFalse);
      });
      
      test('should check if user can manage members', () {
        // Act
        when(() => mockPermissionService.canManageShoppingList('list_1')).thenReturn(true);
        when(() => mockPermissionService.canManageShoppingList('list_2')).thenReturn(false);
        
        final canManage1 = operations.canManageMembers('list_1');
        final canManage2 = operations.canManageMembers('list_2');
        
        // Assert
        expect(canManage1, isTrue);
        expect(canManage2, isFalse);
      });
      
      test('should get user permission for list', () {
        // Act
        when(() => mockPermissionService.canManageShoppingList('list_1')).thenReturn(true);
        when(() => mockPermissionService.canManageShoppingList('list_2')).thenReturn(false);
        
        final permission1 = operations.getUserPermission('list_1');
        final permission2 = operations.getUserPermission('list_2');
        
        // Assert
        expect(permission1, equals(SharedListPermission.admin));
        expect(permission2, equals(SharedListPermission.view));
      });
    });
    
    group('Edge Cases', () {
      test('should handle unauthenticated user', () {
        // Arrange
        mockPermissionService.setPermissionState(isAuthenticated: false);
        
        // Act
        final ownedLists = operations.getOwnedLists();
        final sharedLists = operations.getSharedWithMe();
        
        // Assert
        expect(ownedLists, isEmpty);
        expect(sharedLists, isEmpty);
      });
      
      test('should handle empty lists', () {
        // Arrange
        mockParentService.setShoppingState(collaborativeLists: []);
        
        // Act
        final allLists = operations.getAllLists();
        final list = operations.getListById('any_id');
        
        // Assert
        expect(allLists, isEmpty);
        expect(list, isNull);
      });
      
      test('should handle list without members', () {
        // Arrange
        final emptyList = UnifiedShoppingList(
          id: 'empty_list',
          name: 'Empty List',
          ownerId: 'user_123',
          ownerDisplayName: 'Test User',
          memberPermissions: {},
          items: [],
          type: ListType.collaborative,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        mockParentService.setShoppingState(collaborativeLists: [emptyList]);
        
        // Act
        final members = operations.getListMembers('empty_list');
        final isMember = members.containsKey('user_123');
        
        // Assert
        expect(members, isEmpty);
        expect(isMember, isFalse);
      });
    });
    
    group('Additional Permission Tests (Merged)', () {
      test('should check if can view list', () {
        // Arrange
        when(() => mockPermissionService.canViewShoppingList('list_1')).thenReturn(true);
        
        // Act - Check if user has permission to view the list
        final canView = operations.canView('list_1');
        
        // Assert
        expect(canView, isTrue); // User is a member
      });
      
      test('should check if can edit list', () {
        // Arrange
        mockPermissionService.setPermissionState(
          currentUserId: 'user_456',
          shoppingListEditPermissions: {'list_1': true},
        );
        
        // Act - Check if user has edit permission
        final canEdit = operations.canEdit('list_1');
        
        // Assert
        expect(canEdit, isTrue);
      });
      
      test('should check if can delete list', () {
        // Arrange
        when(() => mockPermissionService.canDeleteShoppingList('list_1')).thenReturn(true);
        
        // Act - Owner should be able to delete
        final canDelete = operations.canDelete('list_1');
        
        // Assert
        expect(canDelete, isTrue); // Owner can delete
      });
      
      test('should get user permission level', () {
        // Act - Get permission for user from the list
        final permission = testList1.memberPermissions['user_456'];
        
        // Assert
        expect(permission, equals(SharedListPermission.edit));
      });
    });
    
    group('List Conversion Operations (Merged)', () {
      test('should convert personal to collaborative', () async {
        // Arrange
        final personalList = UnifiedShoppingList(
          id: 'personal_1',
          name: 'Personal List',
          ownerId: 'user_123',
          ownerDisplayName: 'Test User',
          type: ListType.personal,
          items: [testItem1],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        mockParentService.setShoppingState(
          personalLists: [personalList],
        );
        
        when(() => mockParentService.createCollaborativeList(
          name: any(named: 'name'),
          description: any(named: 'description'),
          memberIds: any(named: 'memberIds'),
          memberDisplayNames: any(named: 'memberDisplayNames'),
          items: any(named: 'items'),
          categoryIds: any(named: 'categoryIds'),
          allowGuestEditing: any(named: 'allowGuestEditing'),
          autoRemoveCompleted: any(named: 'autoRemoveCompleted'),
        )).thenAnswer((_) async => 'collab_1');
        
        when(() => mockParentService.deleteList(any()))
            .thenAnswer((_) async => true);
        
        // Act - Convert personal list to collaborative
        final resultId = await operations.convertPersonalToCollaborative(
          personalListId: personalList.id,
          memberIds: ['user_456'],
          memberDisplayNames: {'user_456': 'Other User'},
        );
        
        // Assert
        expect(resultId, equals('collab_1'));
        verify(() => mockParentService.createCollaborativeList(
          name: any(named: 'name'),
          description: any(named: 'description'),
          memberIds: any(named: 'memberIds'),
          memberDisplayNames: any(named: 'memberDisplayNames'),
          items: any(named: 'items'),
          categoryIds: any(named: 'categoryIds'),
          allowGuestEditing: any(named: 'allowGuestEditing'),
          autoRemoveCompleted: any(named: 'autoRemoveCompleted'),
        )).called(1);
        verify(() => mockParentService.deleteList('personal_1')).called(1);
      });
      
      test('should convert collaborative to personal', () async {
        // Arrange
        when(() => mockParentService.createPersonalList(
          any(),
          items: any(named: 'items'),
        )).thenAnswer((_) async => 'personal_2');
        
        when(() => mockParentService.deleteList(any()))
            .thenAnswer((_) async => true);
        
        mockPermissionService.setPermissionState(
          currentUserId: 'user_123',
          shoppingListOwnership: {'list_1': true},
        );
        
        // Act - Convert collaborative to personal
        final resultId = await operations.convertCollaborativeToPersonal(
          testList1.id,
        );
        
        // Assert
        expect(resultId, equals('personal_2'));
        verify(() => mockParentService.createPersonalList(
          any(),
          items: any(named: 'items'),
        )).called(1);
        verify(() => mockParentService.deleteList('list_1')).called(1);
      });
      
      test('should not convert if not owner', () async {
        // Arrange
        mockPermissionService.setPermissionState(
          currentUserId: 'user_456',
          shoppingListOwnership: {'list_1': false},
        );
        
        // Act - Try to convert without being owner
        final resultId = await operations.convertCollaborativeToPersonal(
          testList1.id,
        );
        
        // Assert
        expect(resultId, isNull);
        verifyNever(() => mockParentService.updateList(any()));
      });
    });
    
    group('Advanced Collaborative Features (Merged)', () {
      test('should toggle item bought status with user tracking', () async {
        // Arrange
        final itemWithTracking = testItem1.copyWith(
          bought: false,
        );
        
        final listWithItem = testList1.copyWith(items: [itemWithTracking]);
        mockParentService.setShoppingState(
          collaborativeLists: [listWithItem],
        );
        
        when(() => mockParentService.updateList(any()))
            .thenAnswer((_) async => true);
        
        mockPermissionService.setPermissionState(
          currentUserId: 'user_123',
          shoppingListEditPermissions: {'list_1': true},
        );
        
        // Act - Toggle item bought status
        final result = await operations.toggleItemBought(
          listId: listWithItem.id,
          itemId: itemWithTracking.id,
        );
        
        // Assert
        expect(result, isTrue);
        verify(() => mockParentService.updateList(any())).called(1);
      });
      
      test('should get shared with me lists', () {
        // Arrange
        final sharedList = UnifiedShoppingList(
          id: 'shared_1',
          name: 'Shared with me',
          ownerId: 'user_999',
          ownerDisplayName: 'Another User',
          memberPermissions: {
            'user_123': SharedListPermission.view,
          },
          type: ListType.collaborative,
          items: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        mockParentService.setShoppingState(
          collaborativeLists: [testList1, testList2, sharedList],
          currentUserId: 'user_123',
        );
        
        // Act
        final sharedWithMe = operations.getSharedWithMe();
        
        // Assert
        expect(sharedWithMe.length, equals(2)); // list_2 and shared_1 where user is not owner
        expect(sharedWithMe.any((list) => list.ownerId == 'user_456'), isTrue);
        expect(sharedWithMe.any((list) => list.ownerId == 'user_999'), isTrue);
      });
      
      test('should leave list as member', () async {
        // Arrange
        mockParentService.setShoppingState(
          currentUserId: 'user_456',
        );
        
        mockPermissionService.setPermissionState(
          isAuthenticated: true,
          currentUserId: 'user_456',
          shoppingListOwnership: {'list_1': false},
        );
        
        when(() => mockParentService.updateList(any()))
            .thenAnswer((_) async => true);
        
        // Act - Leave the list
        final result = await operations.leaveList(testList1.id);
        
        // Assert
        expect(result, isTrue);
        verify(() => mockParentService.updateList(any())).called(1);
      });
    });
  });
}

// Mock classes for testing with configuration support
class MockUnifiedShoppingService extends Mock implements UnifiedShoppingService {
  List<UnifiedShoppingList> _collaborativeLists = [];
  List<UnifiedShoppingList> _personalLists = [];
  String? _currentUserId;
  String? _currentUserDisplayName;
  
  void setShoppingState({
    List<UnifiedShoppingList>? collaborativeLists,
    List<UnifiedShoppingList>? personalLists,
    String? currentUserId,
    String? currentUserDisplayName,
  }) {
    if (collaborativeLists != null) _collaborativeLists = collaborativeLists;
    if (personalLists != null) _personalLists = personalLists;
    if (currentUserId != null) _currentUserId = currentUserId;
    if (currentUserDisplayName != null) _currentUserDisplayName = currentUserDisplayName;
  }
  
  @override
  List<UnifiedShoppingList> get collaborativeLists => _collaborativeLists;
  
  @override
  List<UnifiedShoppingList> get personalLists => _personalLists;
  
  @override
  String? get currentUserId => _currentUserId;
  
  @override
  String? get currentUserDisplayName => _currentUserDisplayName;
}

class MockPermissionService extends Mock implements PermissionService {
  bool _isAuthenticated = false;
  String? _currentUserId;
  Map<String, bool> _shoppingListOwnership = {};
  Map<String, bool> _shoppingListEditPermissions = {};
  
  void setPermissionState({
    bool? isAuthenticated,
    String? currentUserId,
    Map<String, bool>? shoppingListOwnership,
    Map<String, bool>? shoppingListEditPermissions,
  }) {
    if (isAuthenticated != null) _isAuthenticated = isAuthenticated;
    if (currentUserId != null) _currentUserId = currentUserId;
    if (shoppingListOwnership != null) _shoppingListOwnership = shoppingListOwnership;
    if (shoppingListEditPermissions != null) _shoppingListEditPermissions = shoppingListEditPermissions;
  }
  
  @override
  bool get isAuthenticated => _isAuthenticated;
  
  @override
  String? get currentUserId => _currentUserId;
  
  @override
  bool isShoppingListOwner(String listId) => _shoppingListOwnership[listId] ?? false;
  
  @override
  bool canEditShoppingList(String listId) => _shoppingListEditPermissions[listId] ?? false;
}