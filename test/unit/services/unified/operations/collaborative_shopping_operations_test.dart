// test/unit/services/unified/operations/collaborative_shopping_operations_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping_operations.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping/list_lifecycle_operations.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping/list_member_operations.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping/list_item_operations.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping/list_activity_operations.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:get_it/get_it.dart';
import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('CollaborativeShoppingOperations', () {
    late MockUnifiedShoppingService mockParentService;
    late MockPermissionService mockPermissionService;
    late CollaborativeShoppingOperations operations;
    late UnifiedShoppingList testCollaborativeList;
    late UnifiedShoppingList testSharedList;
    late UnifiedShoppingList testPersonalList;
    late UnifiedShoppingItem testItem1;
    late UnifiedShoppingItem testItem2;

    setUpAll(() async {
      // Register fallback values for mocktail
      registerFallbackValue(SharedListPermission.view);
      registerFallbackValue(<String>[]);
      registerFallbackValue(<String, String>{});
      registerFallbackValue(<UnifiedShoppingItem>[]);
      registerFallbackValue(UnifiedShoppingList(
        id: 'test',
        name: 'Test',
        ownerId: 'test',
        ownerDisplayName: 'Test',
        items: [],
        type: ListType.collaborative,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    });

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Bridge production ServiceLocator to GetIt so ServiceLocator.get<T>() works
      production.ServiceLocator.initialize(DIContainer());

      // Create mocks
      mockParentService = MockUnifiedShoppingService();
      mockPermissionService = MockPermissionService();

      // Register permission service
      if (GetIt.instance.isRegistered<PermissionService>()) {
        GetIt.instance.unregister<PermissionService>();
      }
      GetIt.instance
          .registerSingleton<PermissionService>(mockPermissionService);

      // Create test items
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
        bought: true,
        addedByUserId: 'user_456',
        addedByDisplayName: 'Other User',
        addedAt: DateTime.now(),
      );

      // Create test lists
      testCollaborativeList = UnifiedShoppingList(
        id: 'collab_list_1',
        name: 'Familjehandling',
        description: 'Veckans mat',
        ownerId: 'user_123',
        ownerDisplayName: 'Test User',
        memberPermissions: {
          'user_123': SharedListPermission.admin,
          'user_456': SharedListPermission.edit,
          'user_789': SharedListPermission.view,
        },
        items: [testItem1],
        type: ListType.collaborative,
        allowGuestEditing: true,
        autoRemoveCompleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        lastActivityByUserId: 'user_123',
        lastActivityByDisplayName: 'Test User',
      );

      testSharedList = UnifiedShoppingList(
        id: 'shared_list_2',
        name: 'Shared List',
        description: 'Shared shopping',
        ownerId: 'user_456',
        ownerDisplayName: 'Other User',
        memberPermissions: {
          'user_456': SharedListPermission.admin,
          'user_123': SharedListPermission.view,
        },
        items: [testItem2],
        type: ListType.collaborative,
        allowGuestEditing: false,
        autoRemoveCompleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      testPersonalList = UnifiedShoppingList(
        id: 'personal_list_1',
        name: 'Min lista',
        ownerId: 'user_123',
        ownerDisplayName: 'Test User',
        items: [],
        type: ListType.personal,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Set up mock parent service state
      mockParentService.setShoppingState(
        collaborativeLists: [testCollaborativeList, testSharedList],
        personalLists: [testPersonalList],
        currentUserId: 'user_123',
        currentUserDisplayName: 'Test User',
      );

      // Set up permission service using configuration
      // The mock now has concrete implementations that use this configuration
      mockPermissionService.setPermissionState(
        isAuthenticated: true,
        currentUserId: 'user_123',
        defaultHasPermission:
            false, // Default to false for more controlled testing
        permissions: {
          'collab_list_1': {
            ResourcePermission.owner: true,
            ResourcePermission.admin: true,
            ResourcePermission.write: true,
            ResourcePermission.editor: true,
            ResourcePermission.read: true,
            ResourcePermission.viewer: true,
          },
          'shared_list_2': {
            ResourcePermission.owner: false,
            ResourcePermission.admin: false,
            ResourcePermission.write: false,
            ResourcePermission.editor: false,
            ResourcePermission.read: true,
            ResourcePermission.viewer: true,
          },
          'personal_list_1': {
            ResourcePermission.owner: true,
            ResourcePermission.admin: true,
            ResourcePermission.write: true,
            ResourcePermission.editor: true,
            ResourcePermission.read: true,
            ResourcePermission.viewer: true,
          },
        },
      );

      // No need to stub these methods anymore - they have concrete implementations
      // that use the configuration above

      // Default stub behaviors for parent service methods
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

      when(() => mockParentService.createPersonalList(
            any(),
            items: any(named: 'items'),
          )).thenAnswer((_) async => 'new_personal_list_id');

      when(() => mockParentService.updateList(any()))
          .thenAnswer((_) async => true);
      when(() => mockParentService.deleteList(any()))
          .thenAnswer((_) async => true);

      // Build operations with typed deps (no _parent back-reference)
      final lifecycleOps = ListLifecycleOperations(
        getCollaborativeLists: () => mockParentService.collaborativeLists,
        getPersonalLists: () => mockParentService.personalLists,
        createCollaborativeList: mockParentService.createCollaborativeList,
        deleteList: mockParentService.deleteList,
        createPersonalList: mockParentService.createPersonalList,
      );

      final memberOps = ListMemberOperations(
        getCurrentUserId: () => mockParentService.currentUserId,
        updateList: mockParentService.updateList,
        lifecycleOps: lifecycleOps,
      );

      final itemOps = ListItemOperations(
        getCurrentUserId: () => mockParentService.currentUserId,
        getCurrentUserDisplayName: () =>
            mockParentService.currentUserDisplayName,
        updateList: mockParentService.updateList,
        lifecycleOps: lifecycleOps,
      );

      final activityOps = ListActivityOperations(lifecycleOps);

      // Create operations under test
      operations = CollaborativeShoppingOperations(
        lifecycleOps: lifecycleOps,
        memberOps: memberOps,
        itemOps: itemOps,
        activityOps: activityOps,
      );
    });

    tearDown(() async {
      if (GetIt.instance.isRegistered<PermissionService>()) {
        GetIt.instance.unregister<PermissionService>();
      }
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('List Management', () {
      test('should create collaborative list', () async {
        // Act
        final listId = await operations.createList(
          name: 'Ny lista',
          description: 'Test beskrivning',
          memberIds: ['user_456', 'user_789'],
          memberDisplayNames: {
            'user_456': 'Anna',
            'user_789': 'Erik',
          },
          allowGuestEditing: true,
        );

        // Assert
        expect(listId, equals('new_list_id'));
        verify(() => mockParentService.createCollaborativeList(
              name: 'Ny lista',
              description: 'Test beskrivning',
              memberIds: ['user_456', 'user_789'],
              memberDisplayNames: {
                'user_456': 'Anna',
                'user_789': 'Erik',
              },
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
        expect(lists, hasLength(2));
        expect(lists[0].name, equals('Familjehandling'));
        expect(lists[1].name, equals('Shared List'));
      });

      test('should get list by ID', () {
        // Act
        final list = operations.getListById('collab_list_1');

        // Assert
        expect(list, isNotNull);
        expect(list!.name, equals('Familjehandling'));
      });

      test('should return null for non-existent list', () {
        // Act
        final list = operations.getListById('non_existent');

        // Assert
        expect(list, isNull);
      });

      test('should get owned lists', () {
        // Act
        final lists = operations.getOwnedLists();

        // Assert
        expect(lists, hasLength(1));
        expect(lists[0].id, equals('collab_list_1'));
      });

      test('should get lists shared with current user', () {
        // Act
        final lists = operations.getSharedWithMe();

        // Assert
        expect(lists, hasLength(1));
        expect(lists[0].id, equals('shared_list_2'));
      });

      test('should convert personal list to collaborative', () async {
        // Act
        final collaborativeId = await operations.convertPersonalToCollaborative(
          personalListId: 'personal_list_1',
          memberIds: ['user_456'],
          memberDisplayNames: {'user_456': 'Anna'},
          description: 'Now collaborative',
        );

        // Assert
        expect(collaborativeId, equals('new_list_id'));
        verify(() => mockParentService.createCollaborativeList(
              name: 'Min lista',
              description: 'Now collaborative',
              memberIds: ['user_456'],
              memberDisplayNames: {'user_456': 'Anna'},
              items: [],
              categoryIds: null,
              allowGuestEditing: true,
              autoRemoveCompleted: false,
            )).called(1);
        verify(() => mockParentService.deleteList('personal_list_1')).called(1);
      });

      test('should convert collaborative list to personal', () async {
        // Act
        final personalId =
            await operations.convertCollaborativeToPersonal('collab_list_1');

        // Assert
        expect(personalId, equals('new_personal_list_id'));
        verify(() => mockParentService.createPersonalList(
              'Familjehandling',
              items: [testItem1],
            )).called(1);
        verify(() => mockParentService.deleteList('collab_list_1')).called(1);
      });
    });

    group('Member Management', () {
      test('should add member to list', () async {
        // Act
        final result = await operations.addMember(
          listId: 'collab_list_1',
          userId: 'user_999',
          userDisplayName: 'New User',
          permission: SharedListPermission.edit,
        );

        // Assert
        expect(result, isTrue);
        verify(() => mockParentService.updateList(any())).called(1);
      });

      test('should not add existing member', () async {
        // Act
        final result = await operations.addMember(
          listId: 'collab_list_1',
          userId: 'user_456',
          userDisplayName: 'Existing User',
          permission: SharedListPermission.edit,
        );

        // Assert
        expect(result, isFalse);
        verifyNever(() => mockParentService.updateList(any()));
      });

      test('should not add member without permission', () async {
        // Act
        final result = await operations.addMember(
          listId: 'shared_list_2',
          userId: 'user_999',
          userDisplayName: 'New User',
          permission: SharedListPermission.edit,
        );

        // Assert
        expect(result, isFalse);
        verifyNever(() => mockParentService.updateList(any()));
      });

      test('should remove member from list', () async {
        // Act
        final result = await operations.removeMember(
          listId: 'collab_list_1',
          userId: 'user_456',
        );

        // Assert
        expect(result, isTrue);
        verify(() => mockParentService.updateList(any())).called(1);
      });

      test('should update member permission', () async {
        // Act
        final result = await operations.updateMemberPermission(
          listId: 'collab_list_1',
          userId: 'user_456',
          permission: SharedListPermission.admin,
        );

        // Assert
        expect(result, isTrue);
        verify(() => mockParentService.updateList(any())).called(1);
      });

      test('should get list members', () {
        // Act
        final members = operations.getListMembers('collab_list_1');

        // Assert
        expect(members, hasLength(3));
        expect(members['user_123'], equals(SharedListPermission.admin));
        expect(members['user_456'], equals(SharedListPermission.edit));
        expect(members['user_789'], equals(SharedListPermission.view));
      });

      test('should allow non-owner to leave list', () async {
        // Arrange
        mockParentService.setShoppingState(
          collaborativeLists: [testCollaborativeList, testSharedList],
          personalLists: [testPersonalList],
          currentUserId: 'user_456',
          currentUserDisplayName: 'Other User',
        );
        mockPermissionService.setPermissionState(
          isAuthenticated: true,
          currentUserId: 'user_456',
          permissions: {
            'collab_list_1': {
              ResourcePermission.owner: false, // user_456 is not owner
              ResourcePermission.admin: false, // and not admin
              ResourcePermission.write: true, // but can edit
              ResourcePermission.editor: true,
              ResourcePermission.read: true,
              ResourcePermission.viewer: true,
            },
          },
        );

        // Act
        final result = await operations.leaveList('collab_list_1');

        // Assert
        // FIXED: Users can now leave collaborative lists regardless of permission level
        // (as long as they're not the owner)
        expect(result, isTrue);
        verify(() => mockParentService.updateList(any())).called(1);
      });

      test('should not allow owner to leave list', () async {
        // Act
        final result = await operations.leaveList('collab_list_1');

        // Assert
        expect(result, isFalse);
        verifyNever(() => mockParentService.updateList(any()));
      });
    });

    group('Item Management', () {
      test('should add item to collaborative list', () async {
        // Arrange
        final originalList = testCollaborativeList;
        when(() => mockParentService.updateList(any()))
            .thenAnswer((invocation) async {
          final list = invocation.positionalArguments[0] as UnifiedShoppingList;
          // Verify the list has a new item
          expect(list.items.length, greaterThan(originalList.items.length));
          return true;
        });

        // Act
        final result = await operations.addItem(
          listId: 'collab_list_1',
          name: 'Ost',
          amount: 500,
          unit: 'g',
          category: 'Mejeri',
          note: 'Gärna lagrad',
          estimatedPrice: 89.90,
        );

        // Assert
        expect(result, isTrue);
        verify(() => mockParentService.updateList(any())).called(1);
      });

      test('should not add item without edit permission', () async {
        // Act
        final result = await operations.addItem(
          listId: 'shared_list_2',
          name: 'Ost',
          amount: 500,
          unit: 'g',
          category: 'Mejeri',
        );

        // Assert
        expect(result, isFalse);
        verifyNever(() => mockParentService.updateList(any()));
      });

      test('should toggle item bought status', () async {
        // Act
        final result = await operations.toggleItemBought(
          listId: 'collab_list_1',
          itemId: 'item_1',
        );

        // Assert
        expect(result, isTrue);
        verify(() => mockParentService.updateList(any())).called(1);
      });

      test('should remove item from list', () async {
        // Act
        final result = await operations.removeItem(
          listId: 'collab_list_1',
          itemId: 'item_1',
        );

        // Assert
        expect(result, isTrue);
        verify(() => mockParentService.updateList(any())).called(1);
      });
    });

    group('Activity and Statistics', () {
      test('should get recent activity', () {
        // Act
        final activity = operations.getRecentActivity('collab_list_1');

        // Assert
        expect(activity, isNotEmpty);
        expect(activity[0]['type'], equals('list_updated'));
        expect(activity[0]['userId'], equals('user_123'));
        expect(activity[0]['userName'], equals('Test User'));
      });

      test('should get list statistics', () {
        // Act
        final stats = operations.getListStats('collab_list_1');

        // Assert
        expect(stats['listName'], equals('Familjehandling'));
        expect(stats['totalItems'], equals(1));
        expect(stats['boughtItems'], equals(0));
        expect(stats['remainingItems'], equals(1));
        expect(stats['memberCount'], equals(3));
        expect(stats['allowGuestEditing'], isTrue);
        expect(stats['autoRemoveCompleted'], isFalse);
      });

      test('should calculate completion percentage', () {
        // Arrange - Add a bought item
        final listWithBoughtItem = testCollaborativeList.copyWith(
          items: [testItem1, testItem2], // testItem2 is bought
        );
        mockParentService.setShoppingState(
          collaborativeLists: [listWithBoughtItem, testSharedList],
          personalLists: [testPersonalList],
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
        );

        // Act
        final stats = operations.getListStats('collab_list_1');

        // Assert
        expect(stats['totalItems'], equals(2));
        expect(stats['boughtItems'], equals(1));
        expect(stats['completionPercentage'], equals(50));
      });
    });

    group('Permission Helpers', () {
      test('should check edit permission', () {
        // Act & Assert
        expect(operations.canEdit('collab_list_1'), isTrue);
        expect(operations.canEdit('shared_list_2'), isFalse);
      });

      test('should check view permission', () {
        // Act & Assert
        expect(operations.canView('collab_list_1'), isTrue);
        expect(operations.canView('shared_list_2'), isTrue);
      });

      test('should check member management permission', () {
        // Act & Assert
        expect(operations.canManageMembers('collab_list_1'), isTrue);
        expect(operations.canManageMembers('shared_list_2'), isFalse);
      });

      test('should check delete permission', () {
        // Act & Assert
        expect(operations.canDelete('collab_list_1'), isTrue);
        expect(operations.canDelete('shared_list_2'), isFalse);
      });

      test('should get user permission level', () {
        // Arrange - permissions are already configured in setUp
        // collab_list_1 has owner permissions for user_123
        // shared_list_2 has only view permissions for user_123

        // Act
        final permission1 = operations.getUserPermission('collab_list_1');
        final permission2 = operations.getUserPermission('shared_list_2');

        // Assert
        expect(permission1, equals(SharedListPermission.admin));
        expect(permission2, equals(SharedListPermission.view));
      });
    });

    group('Notifications', () {
      test('should get notification count', () {
        // Act
        final count = operations.getNotificationCount();

        // Assert
        expect(count, greaterThanOrEqualTo(0));
      });

      test('should mark list as seen', () async {
        // Act
        final result = await operations.markListAsSeen('collab_list_1');

        // Assert
        expect(result, isTrue);
      });
    });
  });
}
