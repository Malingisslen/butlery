/// Unit tests for services using ShoppingRepository
///
/// Tests business logic using mocked repository, avoiding Firebase implementation details.
/// For Firebase-specific tests, see integration tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('ShoppingRepository Mock Tests', () {
    late MockShoppingRepository mockRepository;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(
        UnifiedShoppingList.personal(
          name: 'Fallback List',
          ownerId: 'test-user',
          ownerDisplayName: 'Test User',
        ),
      );
      registerFallbackValue(
        UnifiedShoppingItem.basic(
          name: 'Fallback Item',
          amount: 1,
          unit: 'st',
          category: 'Test',
        ),
      );
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      mockRepository = MockShoppingRepository();
      TestServiceLocator.registerMock(mockRepository);
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('CRUD Operations', () {
      test('should create shopping list', () async {
        // Arrange
        final list = UnifiedShoppingList.personal(
          name: 'Weekly Groceries',
          ownerId: 'test-user-123',
          ownerDisplayName: 'Test User',
        );

        when(() => mockRepository.create(list)).thenAnswer((_) async => list);

        // Act
        final created = await mockRepository.create(list);

        // Assert
        expect(created.name, equals('Weekly Groceries'));
        expect(created.ownerId, equals('test-user-123'));
        expect(created.isPersonal, isTrue);
        expect(created.isCollaborative, isFalse);

        verify(() => mockRepository.create(list)).called(1);
      });

      test('should read shopping list by ID', () async {
        // Arrange
        const listId = 'list-1';
        final expectedList = UnifiedShoppingList(
          id: listId,
          name: 'Test List',
          ownerId: 'test-user-123',
          ownerDisplayName: 'Test User',
        );

        when(
          () => mockRepository.read(listId),
        ).thenAnswer((_) async => expectedList);

        // Act
        final list = await mockRepository.read(listId);

        // Assert
        expect(list, isNotNull);
        expect(list!.id, equals(listId));
        expect(list.name, equals('Test List'));

        verify(() => mockRepository.read(listId)).called(1);
      });

      test('should return null for non-existent list', () async {
        // Arrange
        const listId = 'non-existent';

        when(() => mockRepository.read(listId)).thenAnswer((_) async => null);

        // Act
        final list = await mockRepository.read(listId);

        // Assert
        expect(list, isNull);
        verify(() => mockRepository.read(listId)).called(1);
      });

      test('should read all shopping lists', () async {
        // Arrange
        final lists = [
          UnifiedShoppingList.personal(
            name: 'Personal List',
            ownerId: 'test-user-123',
            ownerDisplayName: 'Test User',
          ),
          UnifiedShoppingList.collaborative(
            name: 'Shared List',
            ownerId: 'test-user-123',
            ownerDisplayName: 'Test User',
            memberPermissions: {
              'friend-1': SharedListPermission.edit,
              'friend-2': SharedListPermission.view,
            },
          ),
        ];

        when(() => mockRepository.readAll()).thenAnswer((_) async => lists);

        // Act
        final result = await mockRepository.readAll();

        // Assert
        expect(result, hasLength(2));
        expect(result[0].isPersonal, isTrue);
        expect(result[1].isCollaborative, isTrue);
        expect(result[1].memberPermissions, hasLength(3)); // Owner + 2 friends

        verify(() => mockRepository.readAll()).called(1);
      });

      test('should update shopping list', () async {
        // Arrange
        final list = UnifiedShoppingList(
          id: 'list-1',
          name: 'Updated List Name',
          ownerId: 'test-user-123',
          ownerDisplayName: 'Test User',
        );

        when(() => mockRepository.update(list)).thenAnswer((_) async {});

        // Act
        await mockRepository.update(list);

        // Assert
        verify(() => mockRepository.update(list)).called(1);
      });

      test('should delete shopping list', () async {
        // Arrange
        const listId = 'list-1';

        when(() => mockRepository.delete(listId)).thenAnswer((_) async {});

        // Act
        await mockRepository.delete(listId);

        // Assert
        verify(() => mockRepository.delete(listId)).called(1);
      });
    });

    group('Item Operations', () {
      test('should add item to shopping list', () async {
        // Arrange
        const listId = 'list-1';
        final item = UnifiedShoppingItem.basic(
          name: 'Milk',
          amount: 2,
          unit: 'liter',
          category: 'Dairy',
        );

        when(
          () => mockRepository.addItem(listId, item),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.addItem(listId, item);

        // Assert
        verify(() => mockRepository.addItem(listId, item)).called(1);
      });

      test('should remove item from shopping list', () async {
        // Arrange
        const listId = 'list-1';
        const itemId = 'item-1';

        when(
          () => mockRepository.removeItem(listId, itemId),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.removeItem(listId, itemId);

        // Assert
        verify(() => mockRepository.removeItem(listId, itemId)).called(1);
      });

      test('should handle collaborative item with metadata', () async {
        // Arrange
        const listId = 'list-1';
        final item = UnifiedShoppingItem.collaborative(
          name: 'Eggs',
          amount: 12,
          unit: 'styck',
          category: 'Dairy',
          addedByUserId: 'user-123',
          addedByDisplayName: 'Anna Andersson',
          note: 'Organic if possible',
          estimatedPrice: 45.0,
          priority: 4,
        );

        when(
          () => mockRepository.addItem(listId, item),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.addItem(listId, item);

        // Assert
        verify(() => mockRepository.addItem(listId, item)).called(1);
      });
    });

    group('Template Operations', () {
      test('should save list as template', () async {
        // Arrange
        const listId = 'list-1';
        const templateName = 'Weekly Template';
        const description = 'My weekly shopping template';
        final tags = ['weekly', 'groceries'];
        const isPublic = true;

        when(
          () => mockRepository.saveAsTemplate(
            listId: listId,
            templateName: templateName,
            description: description,
            tags: tags,
            isPublic: isPublic,
          ),
        ).thenAnswer((_) async => 'template-1');

        // Act
        final templateId = await mockRepository.saveAsTemplate(
          listId: listId,
          templateName: templateName,
          description: description,
          tags: tags,
          isPublic: isPublic,
        );

        // Assert
        expect(templateId, equals('template-1'));
        verify(
          () => mockRepository.saveAsTemplate(
            listId: listId,
            templateName: templateName,
            description: description,
            tags: tags,
            isPublic: isPublic,
          ),
        ).called(1);
      });

      test('should update template', () async {
        // Arrange
        const templateId = 'template-1';
        const name = 'Updated Template';
        const description = 'Updated description';
        final tags = ['updated', 'template'];
        const isPublic = false;

        when(
          () => mockRepository.updateTemplate(
            templateId: templateId,
            name: name,
            description: description,
            tags: tags,
            isPublic: isPublic,
          ),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.updateTemplate(
          templateId: templateId,
          name: name,
          description: description,
          tags: tags,
          isPublic: isPublic,
        );

        // Assert
        verify(
          () => mockRepository.updateTemplate(
            templateId: templateId,
            name: name,
            description: description,
            tags: tags,
            isPublic: isPublic,
          ),
        ).called(1);
      });

      test('should delete template', () async {
        // Arrange
        const templateId = 'template-1';

        when(
          () => mockRepository.deleteTemplate(templateId),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.deleteTemplate(templateId);

        // Assert
        verify(() => mockRepository.deleteTemplate(templateId)).called(1);
      });

      test('should get user templates', () async {
        // Arrange
        final templates = [
          {
            'id': 'template-1',
            'name': 'Weekly Template',
            'description': 'My weekly shopping',
            'itemCount': 10,
            'createdAt': DateTime.now().toIso8601String(),
            'tags': ['weekly', 'groceries'],
            'isPublic': false,
          },
          {
            'id': 'template-2',
            'name': 'Party Template',
            'description': 'Party shopping list',
            'itemCount': 25,
            'createdAt': DateTime.now().toIso8601String(),
            'tags': ['party', 'event'],
            'isPublic': true,
          },
        ];

        when(
          () => mockRepository.getUserTemplates(),
        ).thenAnswer((_) async => templates);

        // Act
        final result = await mockRepository.getUserTemplates();

        // Assert
        expect(result, hasLength(2));
        expect(result[0]['name'], equals('Weekly Template'));
        expect(result[1]['isPublic'], isTrue);

        verify(() => mockRepository.getUserTemplates()).called(1);
      });

      test('should get public templates with filters', () async {
        // Arrange
        const limit = 10;
        const searchQuery = 'weekly';
        final tags = ['groceries'];

        final templates = [
          {
            'id': 'template-1',
            'name': 'Public Weekly Template',
            'description': 'Shared weekly shopping',
            'itemCount': 15,
            'createdAt': DateTime.now().toIso8601String(),
            'tags': ['weekly', 'groceries'],
            'isPublic': true,
            'createdBy': 'user-456',
            'createdByDisplayName': 'Erik Svensson',
          },
        ];

        when(
          () => mockRepository.getPublicTemplates(
            limit: limit,
            searchQuery: searchQuery,
            tags: tags,
          ),
        ).thenAnswer((_) async => templates);

        // Act
        final result = await mockRepository.getPublicTemplates(
          limit: limit,
          searchQuery: searchQuery,
          tags: tags,
        );

        // Assert
        expect(result, hasLength(1));
        expect(result[0]['name'], contains('Weekly'));
        expect(result[0]['isPublic'], isTrue);

        verify(
          () => mockRepository.getPublicTemplates(
            limit: limit,
            searchQuery: searchQuery,
            tags: tags,
          ),
        ).called(1);
      });

      test('should create list from template', () async {
        // Arrange
        const templateId = 'template-1';
        const listName = 'This Week Shopping';
        const description = 'Shopping for this week';

        when(
          () => mockRepository.createListFromTemplate(
            templateId: templateId,
            listName: listName,
            description: description,
          ),
        ).thenAnswer((_) async => 'new-list-1');

        // Act
        final listId = await mockRepository.createListFromTemplate(
          templateId: templateId,
          listName: listName,
          description: description,
        );

        // Assert
        expect(listId, equals('new-list-1'));
        verify(
          () => mockRepository.createListFromTemplate(
            templateId: templateId,
            listName: listName,
            description: description,
          ),
        ).called(1);
      });
    });

    group('Configuration Methods', () {
      test('should configure shopping state', () {
        // Arrange
        final personalList = UnifiedShoppingList.personal(
          name: 'Personal List',
          ownerId: 'test-user',
          ownerDisplayName: 'Test User',
        );

        final sharedList = UnifiedShoppingList.collaborative(
          name: 'Shared List',
          ownerId: 'test-user',
          ownerDisplayName: 'Test User',
          memberPermissions: {'friend-1': SharedListPermission.edit},
        );

        // Act
        mockRepository.setShoppingState(
          currentUserId: 'test-user',
          activeListId: personalList.id,
          listsById: {
            personalList.id: personalList,
            sharedList.id: sharedList,
          },
          personalLists: {personalList.id: personalList},
          sharedLists: {sharedList.id: sharedList},
        );

        // Assert
        expect(mockRepository.currentUserId, equals('test-user'));
        expect(mockRepository.activeListId, equals(personalList.id));
        expect(mockRepository.listsById, hasLength(2));
        expect(mockRepository.personalLists, hasLength(1));
        expect(mockRepository.sharedLists, hasLength(1));
      });

      test('should add and remove lists', () {
        // Arrange
        final list = UnifiedShoppingList.personal(
          name: 'Test List',
          ownerId: 'test-user',
          ownerDisplayName: 'Test User',
        );

        // Act - Add list
        mockRepository.addList(list);

        // Assert - List added
        expect(mockRepository.listsById[list.id], equals(list));
        expect(mockRepository.personalLists[list.id], equals(list));

        // Act - Remove list
        mockRepository.removeList(list.id);

        // Assert - List removed
        expect(mockRepository.listsById.containsKey(list.id), isFalse);
        expect(mockRepository.personalLists.containsKey(list.id), isFalse);
      });

      test('should update list items', () {
        // Arrange
        final list = UnifiedShoppingList.personal(
          name: 'Test List',
          ownerId: 'test-user',
          ownerDisplayName: 'Test User',
          items: [],
        );

        final items = [
          UnifiedShoppingItem.basic(
            name: 'Milk',
            amount: 1,
            unit: 'liter',
            category: 'Dairy',
          ),
          UnifiedShoppingItem.basic(
            name: 'Bread',
            amount: 2,
            unit: 'st',
            category: 'Bakery',
          ),
        ];

        mockRepository.addList(list);

        // Act
        mockRepository.updateListItems(list.id, items);

        // Assert
        final updatedList = mockRepository.getListById(list.id);
        expect(updatedList, isNotNull);
        expect(updatedList!.items, hasLength(2));
        expect(updatedList.items[0].name, equals('Milk'));
        expect(updatedList.items[1].name, equals('Bread'));
      });

      test('should add templates', () {
        // Arrange
        const templateId = 'template-1';
        final template = {
          'id': templateId,
          'name': 'Test Template',
          'isPublic': true,
          'items': [],
        };

        // Act
        mockRepository.addTemplate(templateId, template);

        // Assert
        expect(mockRepository.templates[templateId], equals(template));
        expect(mockRepository.publicTemplates[templateId], equals(template));
      });

      test('should handle private templates', () {
        // Arrange
        const templateId = 'template-1';
        final template = {
          'id': templateId,
          'name': 'Private Template',
          'isPublic': false,
          'items': [],
        };

        // Act
        mockRepository.addTemplate(templateId, template);

        // Assert
        expect(mockRepository.templates[templateId], equals(template));
        expect(mockRepository.publicTemplates.containsKey(templateId), isFalse);
      });
    });

    group('Helper Methods', () {
      test('should get list by ID', () {
        // Arrange
        final list = UnifiedShoppingList.personal(
          name: 'Test List',
          ownerId: 'test-user',
          ownerDisplayName: 'Test User',
        );
        mockRepository.addList(list);

        // Act
        final result = mockRepository.getListById(list.id);

        // Assert
        expect(result, equals(list));
      });

      test('should get all lists', () {
        // Arrange
        final list1 = UnifiedShoppingList.personal(
          name: 'List 1',
          ownerId: 'test-user',
          ownerDisplayName: 'Test User',
        );
        final list2 = UnifiedShoppingList.personal(
          name: 'List 2',
          ownerId: 'test-user',
          ownerDisplayName: 'Test User',
        );

        mockRepository.addList(list1);
        mockRepository.addList(list2);

        // Act
        final result = mockRepository.getAllLists();

        // Assert
        expect(result, hasLength(2));
        expect(result.any((l) => l.id == list1.id), isTrue);
        expect(result.any((l) => l.id == list2.id), isTrue);
      });

      test('should get personal lists only', () {
        // Arrange
        final personal = UnifiedShoppingList.personal(
          name: 'Personal',
          ownerId: 'test-user',
          ownerDisplayName: 'Test User',
        );
        final shared = UnifiedShoppingList.collaborative(
          name: 'Shared',
          ownerId: 'test-user',
          ownerDisplayName: 'Test User',
          memberPermissions: {'friend-1': SharedListPermission.edit},
        );

        mockRepository.addList(personal);
        mockRepository.addList(shared);

        // Act
        final result = mockRepository.getPersonalLists();

        // Assert
        expect(result, hasLength(1));
        expect(result[0].isPersonal, isTrue);
        expect(result[0].name, equals('Personal'));
      });

      test('should get shared lists only', () {
        // Arrange
        final personal = UnifiedShoppingList.personal(
          name: 'Personal',
          ownerId: 'test-user',
          ownerDisplayName: 'Test User',
        );
        final shared = UnifiedShoppingList.collaborative(
          name: 'Shared',
          ownerId: 'test-user',
          ownerDisplayName: 'Test User',
          memberPermissions: {'friend-1': SharedListPermission.edit},
        );

        mockRepository.addList(personal);
        mockRepository.addList(shared);

        // Act
        final result = mockRepository.getSharedLists();

        // Assert
        expect(result, hasLength(1));
        expect(result[0].isCollaborative, isTrue);
        expect(result[0].name, equals('Shared'));
      });

      test('should get active list', () {
        // Arrange
        final list = UnifiedShoppingList.personal(
          name: 'Active List',
          ownerId: 'test-user',
          ownerDisplayName: 'Test User',
        );

        mockRepository.addList(list);
        mockRepository.setShoppingState(activeListId: list.id);

        // Act
        final result = mockRepository.getActiveListSync();

        // Assert
        expect(result, equals(list));
        expect(result!.name, equals('Active List'));
      });

      test('should return null for no active list', () {
        // Arrange
        mockRepository.setShoppingState(activeListId: null);

        // Act
        final result = mockRepository.getActiveListSync();

        // Assert
        expect(result, isNull);
      });
    });
  });
}
