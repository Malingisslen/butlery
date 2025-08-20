/// Comprehensive unit tests for FirebaseShoppingRepository Template Operations
/// 
/// Tests template management functionality including creating templates from lists,
/// updating template metadata, searching public templates, and creating lists from templates.
library;

// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
class MockUser extends Mock implements User {}

void main() {
  group('FirebaseShoppingRepository Template Operations', () {
    late FirebaseShoppingRepository repository;
    late MockFirebaseFirestore mockFirestore;
    late MockAuthRepository mockAuthRepo;
    late MockCollectionReference<Map<String, dynamic>> mockUsersCollection;
    late MockCollectionReference<Map<String, dynamic>> mockListsCollection;
    late MockCollectionReference<Map<String, dynamic>> mockTemplatesCollection;
    late MockDocumentReference<Map<String, dynamic>> mockUserDoc;
    late MockDocumentReference<Map<String, dynamic>> mockListDoc;
    late MockDocumentReference<Map<String, dynamic>> mockTemplateDoc;
    late MockDocumentSnapshot<Map<String, dynamic>> mockDocSnapshot;
    late MockQuery<Map<String, dynamic>> mockQuery;
    late MockQuerySnapshot<Map<String, dynamic>> mockQuerySnapshot;
    late MockUser mockUser;
    
    // Test data
    late UnifiedShoppingList testList;
    late List<UnifiedShoppingItem> testItems;
    late Map<String, dynamic> testTemplateData;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(<String, dynamic>{});
      registerFallbackValue(SetOptions(merge: true));
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      
      // Initialize all mocks
      mockFirestore = MockFirebaseFirestore();
      mockAuthRepo = MockAuthRepository();
      mockUsersCollection = MockCollectionReference<Map<String, dynamic>>();
      mockListsCollection = MockCollectionReference<Map<String, dynamic>>();
      mockTemplatesCollection = MockCollectionReference<Map<String, dynamic>>();
      mockUserDoc = MockDocumentReference<Map<String, dynamic>>();
      mockListDoc = MockDocumentReference<Map<String, dynamic>>();
      mockTemplateDoc = MockDocumentReference<Map<String, dynamic>>();
      mockDocSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
      mockQuery = MockQuery<Map<String, dynamic>>();
      mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      mockUser = MockUser();
      
      // Setup user mock
      when(() => mockUser.uid).thenReturn('test-user-123');
      when(() => mockUser.displayName).thenReturn('Test User');
      
      // Setup default auth state
      mockAuthRepo.setAuthState(
        userId: 'test-user-123',
        isAuthenticated: true,
        user: mockUser,
      );
      
      // Setup test data
      testItems = [
        UnifiedShoppingItem(
          id: 'item-1',
          name: 'Mjölk',
          amount: 2,
          unit: 'liter',
          category: 'Mejeri',
          priority: 1,
        ),
        UnifiedShoppingItem(
          id: 'item-2',
          name: 'Bröd',
          amount: 1,
          unit: 'st',
          category: 'Bageri',
          priority: 2,
        ),
        UnifiedShoppingItem(
          id: 'item-3',
          name: 'Äpplen',
          amount: 6,
          unit: 'st',
          category: 'Frukt & Grönt',
          priority: 3,
        ),
      ];
      
      testList = UnifiedShoppingList(
        id: 'list-123',
        name: 'Veckohandling',
        ownerId: 'test-user-123',
        ownerDisplayName: 'Test User',
        items: testItems,
        type: ListType.personal,
        description: 'Min vanliga veckohandling',
      );
      
      testTemplateData = {
        'id': 'template-456',
        'name': 'Veckomall',
        'description': 'Mall för veckohandling',
        'ownerId': 'test-user-123',
        'ownerDisplayName': 'Test User',
        'originalListId': 'list-123',
        'items': testItems.map((item) => item.toFirestore()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isPublic': false,
        'tags': ['vecka', 'standard'],
        'metadata': {
          'itemCount': 3,
          'version': '1.0',
        },
      };
      
      // Setup Firestore mock structure
      when(() => mockFirestore.collection('users')).thenReturn(mockUsersCollection);
      when(() => mockFirestore.collection('shoppingListTemplates')).thenReturn(mockTemplatesCollection);
      when(() => mockUsersCollection.doc(any())).thenReturn(mockUserDoc);
      when(() => mockUserDoc.collection('unified_shopping_lists')).thenReturn(mockListsCollection);
      when(() => mockListsCollection.doc(any())).thenReturn(mockListDoc);
      when(() => mockTemplatesCollection.doc(any())).thenReturn(mockTemplateDoc);
      when(() => mockTemplatesCollection.add(any())).thenAnswer((_) async => mockTemplateDoc);
      
      // Setup default doc operations
      when(() => mockListDoc.set(any())).thenAnswer((_) async {});
      when(() => mockListDoc.update(any())).thenAnswer((_) async {});
      when(() => mockListDoc.delete()).thenAnswer((_) async {});
      when(() => mockListDoc.get()).thenAnswer((_) async => mockDocSnapshot);
      when(() => mockTemplateDoc.id).thenReturn('template-456');
      when(() => mockTemplateDoc.set(any())).thenAnswer((_) async {});
      when(() => mockTemplateDoc.update(any())).thenAnswer((_) async {});
      when(() => mockTemplateDoc.delete()).thenAnswer((_) async {});
      when(() => mockTemplateDoc.get()).thenAnswer((_) async => mockDocSnapshot);
      
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

    group('saveAsTemplate', () {
      test('should create template from existing shopping list', () async {
        // Arrange
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.id).thenReturn('list-123');
        when(() => mockDocSnapshot.data()).thenReturn(testList.toFirestore());
        
        // Act
        final templateId = await repository.saveAsTemplate(
          listId: 'list-123',
          templateName: 'Veckomall',
          description: 'Min standardmall för veckohandling',
          tags: ['vecka', 'standard'],
          isPublic: false,
        );
        
        // Assert
        expect(templateId, equals('template-456'));
        
        // Verify template data was saved correctly
        final captured = verify(() => mockTemplatesCollection.add(captureAny())).captured.single as Map<String, dynamic>;
        expect(captured['name'], equals('Veckomall'));
        expect(captured['description'], equals('Min standardmall för veckohandling'));
        expect(captured['ownerId'], equals('test-user-123'));
        expect(captured['ownerDisplayName'], equals('Test User'));
        expect(captured['originalListId'], equals('list-123'));
        expect(captured['isPublic'], equals(false));
        expect(captured['tags'], equals(['vecka', 'standard']));
        expect((captured['items'] as List).length, equals(3));
        expect(captured['metadata']['itemCount'], equals(3));
      });

      test('should create public template with visibility flag', () async {
        // Arrange
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.id).thenReturn('list-123');
        when(() => mockDocSnapshot.data()).thenReturn(testList.toFirestore());
        
        // Act
        final templateId = await repository.saveAsTemplate(
          listId: 'list-123',
          templateName: 'Offentlig Veckomall',
          isPublic: true,
        );
        
        // Assert
        expect(templateId, equals('template-456'));
        
        final captured = verify(() => mockTemplatesCollection.add(captureAny())).captured.single as Map<String, dynamic>;
        expect(captured['name'], equals('Offentlig Veckomall'));
        expect(captured['isPublic'], equals(true));
      });

      test('should throw exception when list not found', () async {
        // Arrange
        when(() => mockDocSnapshot.exists).thenReturn(false);
        
        // Act & Assert
        expect(
          () => repository.saveAsTemplate(
            listId: 'non-existent',
            templateName: 'Test Template',
          ),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });

      test('should throw exception when user does not own the list', () async {
        // Arrange
        final otherUserList = UnifiedShoppingList(
          id: 'list-123',
          name: 'Veckohandling',
          ownerId: 'other-user-456',  // Different owner
          ownerDisplayName: 'Other User',
          items: testItems,
          type: ListType.personal,
          description: 'Min vanliga veckohandling',
        );
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.id).thenReturn('list-123');
        when(() => mockDocSnapshot.data()).thenReturn(otherUserList.toFirestore());
        
        // Act & Assert
        expect(
          () => repository.saveAsTemplate(
            listId: 'list-123',
            templateName: 'Test Template',
          ),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should trim whitespace from template name and description', () async {
        // Arrange
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.id).thenReturn('list-123');
        when(() => mockDocSnapshot.data()).thenReturn(testList.toFirestore());
        
        // Act
        await repository.saveAsTemplate(
          listId: 'list-123',
          templateName: '  Veckomall  ',
          description: '  Min mall  ',
        );
        
        // Assert
        final captured = verify(() => mockTemplatesCollection.add(captureAny())).captured.single as Map<String, dynamic>;
        expect(captured['name'], equals('Veckomall'));
        expect(captured['description'], equals('Min mall'));
      });
    });

    group('updateTemplate', () {
      test('should update template metadata', () async {
        // Arrange
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.data()).thenReturn(testTemplateData);
        
        // Act
        await repository.updateTemplate(
          templateId: 'template-456',
          name: 'Uppdaterad Veckomall',
          description: 'Ny beskrivning',
          tags: ['vecka', 'uppdaterad'],
          isPublic: true,
        );
        
        // Assert
        final captured = verify(() => mockTemplateDoc.update(captureAny())).captured.single as Map<String, dynamic>;
        expect(captured['name'], equals('Uppdaterad Veckomall'));
        expect(captured['description'], equals('Ny beskrivning'));
        expect(captured['tags'], equals(['vecka', 'uppdaterad']));
        expect(captured['isPublic'], equals(true));
        expect(captured.containsKey('updatedAt'), isTrue);
      });

      test('should update only specified fields', () async {
        // Arrange
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.data()).thenReturn(testTemplateData);
        
        // Act
        await repository.updateTemplate(
          templateId: 'template-456',
          name: 'Nytt Namn',
          // Other fields not specified
        );
        
        // Assert
        final captured = verify(() => mockTemplateDoc.update(captureAny())).captured.single as Map<String, dynamic>;
        expect(captured['name'], equals('Nytt Namn'));
        expect(captured.containsKey('description'), isFalse);
        expect(captured.containsKey('tags'), isFalse);
        expect(captured.containsKey('isPublic'), isFalse);
      });

      test('should throw exception when template not found', () async {
        // Arrange
        when(() => mockDocSnapshot.exists).thenReturn(false);
        
        // Act & Assert
        expect(
          () => repository.updateTemplate(
            templateId: 'non-existent',
            name: 'New Name',
          ),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });

      test('should throw exception when user does not own template', () async {
        // Arrange
        final otherUserTemplate = Map<String, dynamic>.from(testTemplateData);
        otherUserTemplate['ownerId'] = 'other-user-456';
        
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.data()).thenReturn(otherUserTemplate);
        
        // Act & Assert
        expect(
          () => repository.updateTemplate(
            templateId: 'template-456',
            name: 'New Name',
          ),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });

    group('deleteTemplate', () {
      test('should delete user template', () async {
        // Arrange
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.data()).thenReturn(testTemplateData);
        
        // Act
        await repository.deleteTemplate('template-456');
        
        // Assert
        verify(() => mockTemplateDoc.delete()).called(1);
      });

      test('should throw exception when template not found', () async {
        // Arrange
        when(() => mockDocSnapshot.exists).thenReturn(false);
        
        // Act & Assert
        expect(
          () => repository.deleteTemplate('non-existent'),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });

      test('should throw exception when user does not own template', () async {
        // Arrange
        final otherUserTemplate = Map<String, dynamic>.from(testTemplateData);
        otherUserTemplate['ownerId'] = 'other-user-456';
        
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.data()).thenReturn(otherUserTemplate);
        
        // Act & Assert
        expect(
          () => repository.deleteTemplate('template-456'),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });

    group('getUserTemplates', () {
      test('should retrieve all user templates', () async {
        // Arrange
        final template1 = Map<String, dynamic>.from(testTemplateData);
        template1['name'] = 'Mall 1';
        
        final template2 = Map<String, dynamic>.from(testTemplateData);
        template2['name'] = 'Mall 2';
        
        final mockDoc1 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        final mockDoc2 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        
        when(() => mockDoc1.id).thenReturn('template-1');
        when(() => mockDoc1.data()).thenReturn(template1);
        when(() => mockDoc2.id).thenReturn('template-2');
        when(() => mockDoc2.data()).thenReturn(template2);
        
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2]);
        
        when(() => mockTemplatesCollection.where('ownerId', isEqualTo: 'test-user-123'))
            .thenReturn(mockQuery);
        when(() => mockQuery.orderBy('createdAt', descending: true))
            .thenReturn(mockQuery);
        when(() => mockQuery.limit(50))
            .thenReturn(mockQuery);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        
        // Act
        final templates = await repository.getUserTemplates();
        
        // Assert
        expect(templates.length, equals(2));
        expect(templates[0]['id'], isNotNull);
        expect(templates[0]['name'], equals('Mall 1'));
        expect(templates[1]['id'], isNotNull);
        expect(templates[1]['name'], equals('Mall 2'));
      });

      test('should return empty list when user has no templates', () async {
        // Arrange
        when(() => mockQuerySnapshot.docs).thenReturn([]);
        
        when(() => mockTemplatesCollection.where('ownerId', isEqualTo: 'test-user-123'))
            .thenReturn(mockQuery);
        when(() => mockQuery.orderBy('createdAt', descending: true))
            .thenReturn(mockQuery);
        when(() => mockQuery.limit(50))
            .thenReturn(mockQuery);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        
        // Act
        final templates = await repository.getUserTemplates();
        
        // Assert
        expect(templates, isEmpty);
      });

      test('should limit results to prevent unbounded query', () async {
        // Arrange
        when(() => mockQuerySnapshot.docs).thenReturn([]);
        
        when(() => mockTemplatesCollection.where('ownerId', isEqualTo: any(named: 'isEqualTo')))
            .thenReturn(mockQuery);
        when(() => mockQuery.orderBy(any(), descending: any(named: 'descending')))
            .thenReturn(mockQuery);
        when(() => mockQuery.limit(any())).thenReturn(mockQuery);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        
        // Act
        await repository.getUserTemplates();
        
        // Assert
        verify(() => mockQuery.limit(50)).called(1);
      });
    });

    group('getPublicTemplates', () {
      test('should retrieve public templates with default limit', () async {
        // Arrange
        final publicTemplate1 = Map<String, dynamic>.from(testTemplateData);
        publicTemplate1['name'] = 'Offentlig Mall 1';
        publicTemplate1['isPublic'] = true;
        
        final publicTemplate2 = Map<String, dynamic>.from(testTemplateData);
        publicTemplate2['name'] = 'Offentlig Mall 2';
        publicTemplate2['isPublic'] = true;
        
        final mockDoc1 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        final mockDoc2 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        
        when(() => mockDoc1.id).thenReturn('public-1');
        when(() => mockDoc1.data()).thenReturn(publicTemplate1);
        when(() => mockDoc2.id).thenReturn('public-2');
        when(() => mockDoc2.data()).thenReturn(publicTemplate2);
        
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2]);
        
        when(() => mockTemplatesCollection.where('isPublic', isEqualTo: true))
            .thenReturn(mockQuery);
        when(() => mockQuery.orderBy('createdAt', descending: true))
            .thenReturn(mockQuery);
        when(() => mockQuery.limit(20))
            .thenReturn(mockQuery);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        
        // Act
        final templates = await repository.getPublicTemplates();
        
        // Assert
        expect(templates.length, equals(2));
        expect(templates[0]['name'], equals('Offentlig Mall 1'));
        expect(templates[1]['name'], equals('Offentlig Mall 2'));
      });

      test('should filter by search query', () async {
        // Arrange
        final template1 = Map<String, dynamic>.from(testTemplateData);
        template1['name'] = 'Veckohandling Mall';
        template1['description'] = 'För vardagar';
        template1['isPublic'] = true;
        
        final template2 = Map<String, dynamic>.from(testTemplateData);
        template2['name'] = 'Helgmall';
        template2['description'] = 'För helgen';
        template2['isPublic'] = true;
        
        final mockDoc1 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        final mockDoc2 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        
        when(() => mockDoc1.id).thenReturn('template-1');
        when(() => mockDoc1.data()).thenReturn(template1);
        when(() => mockDoc2.id).thenReturn('template-2');
        when(() => mockDoc2.data()).thenReturn(template2);
        
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2]);
        
        when(() => mockTemplatesCollection.where('isPublic', isEqualTo: true))
            .thenReturn(mockQuery);
        when(() => mockQuery.orderBy('createdAt', descending: true))
            .thenReturn(mockQuery);
        when(() => mockQuery.limit(any())).thenReturn(mockQuery);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        
        // Act
        final templates = await repository.getPublicTemplates(
          searchQuery: 'vecko',
        );
        
        // Assert
        expect(templates.length, equals(1));
        expect(templates[0]['name'], equals('Veckohandling Mall'));
      });

      test('should filter by tags', () async {
        // Arrange
        final template1 = Map<String, dynamic>.from(testTemplateData);
        template1['name'] = 'Mall 1';
        template1['tags'] = ['vecka', 'standard'];
        template1['isPublic'] = true;
        
        final template2 = Map<String, dynamic>.from(testTemplateData);
        template2['name'] = 'Mall 2';
        template2['tags'] = ['helg', 'special'];
        template2['isPublic'] = true;
        
        final template3 = Map<String, dynamic>.from(testTemplateData);
        template3['name'] = 'Mall 3';
        template3['tags'] = ['vecka', 'budget'];
        template3['isPublic'] = true;
        
        final mockDoc1 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        final mockDoc2 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        final mockDoc3 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        
        when(() => mockDoc1.id).thenReturn('template-1');
        when(() => mockDoc1.data()).thenReturn(template1);
        when(() => mockDoc2.id).thenReturn('template-2');
        when(() => mockDoc2.data()).thenReturn(template2);
        when(() => mockDoc3.id).thenReturn('template-3');
        when(() => mockDoc3.data()).thenReturn(template3);
        
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2, mockDoc3]);
        
        when(() => mockTemplatesCollection.where('isPublic', isEqualTo: true))
            .thenReturn(mockQuery);
        when(() => mockQuery.orderBy('createdAt', descending: true))
            .thenReturn(mockQuery);
        when(() => mockQuery.limit(any())).thenReturn(mockQuery);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        
        // Act
        final templates = await repository.getPublicTemplates(
          tags: ['vecka'],
        );
        
        // Assert
        expect(templates.length, equals(2));
        expect(templates[0]['name'], equals('Mall 1'));
        expect(templates[1]['name'], equals('Mall 3'));
      });

      test('should respect custom limit', () async {
        // Arrange
        final templates = List.generate(10, (i) {
          final template = Map<String, dynamic>.from(testTemplateData);
          template['name'] = 'Mall $i';
          template['isPublic'] = true;
          return template;
        });
        
        final mockDocs = templates.map((template) {
          final mockDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();
          when(() => mockDoc.id).thenReturn(template['name']);
          when(() => mockDoc.data()).thenReturn(template);
          return mockDoc;
        }).toList();
        
        when(() => mockQuerySnapshot.docs).thenReturn(mockDocs);
        
        when(() => mockTemplatesCollection.where('isPublic', isEqualTo: true))
            .thenReturn(mockQuery);
        when(() => mockQuery.orderBy('createdAt', descending: true))
            .thenReturn(mockQuery);
        when(() => mockQuery.limit(any())).thenReturn(mockQuery);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        
        // Act
        final result = await repository.getPublicTemplates(limit: 5);
        
        // Assert
        expect(result.length, equals(5));
      });

      test('should handle combined search and tag filters', () async {
        // Arrange
        final template1 = Map<String, dynamic>.from(testTemplateData);
        template1['name'] = 'Veckohandling Standard';
        template1['tags'] = ['vecka', 'standard'];
        template1['isPublic'] = true;
        
        final template2 = Map<String, dynamic>.from(testTemplateData);
        template2['name'] = 'Helghandling';
        template2['tags'] = ['helg'];
        template2['isPublic'] = true;
        
        final template3 = Map<String, dynamic>.from(testTemplateData);
        template3['name'] = 'Veckomiddag';
        template3['tags'] = ['middag'];
        template3['isPublic'] = true;
        
        final mockDoc1 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        final mockDoc2 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        final mockDoc3 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        
        when(() => mockDoc1.id).thenReturn('template-1');
        when(() => mockDoc1.data()).thenReturn(template1);
        when(() => mockDoc2.id).thenReturn('template-2');
        when(() => mockDoc2.data()).thenReturn(template2);
        when(() => mockDoc3.id).thenReturn('template-3');
        when(() => mockDoc3.data()).thenReturn(template3);
        
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2, mockDoc3]);
        
        when(() => mockTemplatesCollection.where('isPublic', isEqualTo: true))
            .thenReturn(mockQuery);
        when(() => mockQuery.orderBy('createdAt', descending: true))
            .thenReturn(mockQuery);
        when(() => mockQuery.limit(any())).thenReturn(mockQuery);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        
        // Act
        final templates = await repository.getPublicTemplates(
          searchQuery: 'vecko',
          tags: ['standard'],
        );
        
        // Assert
        expect(templates.length, equals(1));
        expect(templates[0]['name'], equals('Veckohandling Standard'));
      });
    });

    group('createListFromTemplate', () {
      test('should create new list from template', () async {
        // Arrange
        final templateDoc = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => templateDoc.exists).thenReturn(true);
        when(() => templateDoc.data()).thenReturn(testTemplateData);
        when(() => mockTemplateDoc.get()).thenAnswer((_) async => templateDoc);
        
        // Setup for list creation
        when(() => mockListsCollection.doc()).thenReturn(mockListDoc);
        when(() => mockListDoc.id).thenReturn('new-list-789');
        
        // Act
        final newListId = await repository.createListFromTemplate(
          templateId: 'template-456',
          listName: 'Ny Veckolista',
          description: 'Skapad från mall',
        );
        
        // Assert
        expect(newListId, isNotNull);
        expect(newListId, isNotEmpty);
        
        // Verify the new list was created with template items
        final captured = verify(() => mockListDoc.set(captureAny())).captured.single as Map<String, dynamic>;
        expect(captured['name'], equals('Ny Veckolista'));
        expect(captured['description'], equals('Skapad från mall'));
        expect(captured['ownerId'], equals('test-user-123'));
        expect((captured['items'] as List).length, equals(3));
      });

      test('should create list from public template', () async {
        // Arrange
        final publicTemplate = Map<String, dynamic>.from(testTemplateData);
        publicTemplate['ownerId'] = 'other-user-456';
        publicTemplate['isPublic'] = true;
        
        final templateDoc = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => templateDoc.exists).thenReturn(true);
        when(() => templateDoc.data()).thenReturn(publicTemplate);
        when(() => mockTemplateDoc.get()).thenAnswer((_) async => templateDoc);
        
        when(() => mockListsCollection.doc()).thenReturn(mockListDoc);
        when(() => mockListDoc.id).thenReturn('new-list-789');
        
        // Act
        final newListId = await repository.createListFromTemplate(
          templateId: 'template-456',
          listName: 'Från Offentlig Mall',
        );
        
        // Assert
        expect(newListId, isNotNull);
        expect(newListId, isNotEmpty);
        verify(() => mockListDoc.set(any())).called(1);
      });

      test('should throw exception when template not found', () async {
        // Arrange
        final templateDoc = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => templateDoc.exists).thenReturn(false);
        when(() => mockTemplateDoc.get()).thenAnswer((_) async => templateDoc);
        
        // Act & Assert
        expect(
          () => repository.createListFromTemplate(
            templateId: 'non-existent',
            listName: 'Test List',
          ),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });

      test('should throw exception when accessing private template of another user', () async {
        // Arrange
        final privateTemplate = Map<String, dynamic>.from(testTemplateData);
        privateTemplate['ownerId'] = 'other-user-456';
        privateTemplate['isPublic'] = false;
        
        final templateDoc = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => templateDoc.exists).thenReturn(true);
        when(() => templateDoc.data()).thenReturn(privateTemplate);
        when(() => mockTemplateDoc.get()).thenAnswer((_) async => templateDoc);
        
        // Act & Assert
        expect(
          () => repository.createListFromTemplate(
            templateId: 'template-456',
            listName: 'Test List',
          ),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should trim whitespace from list name and description', () async {
        // Arrange
        final templateDoc = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => templateDoc.exists).thenReturn(true);
        when(() => templateDoc.data()).thenReturn(testTemplateData);
        when(() => mockTemplateDoc.get()).thenAnswer((_) async => templateDoc);
        
        when(() => mockListsCollection.doc()).thenReturn(mockListDoc);
        when(() => mockListDoc.id).thenReturn('new-list-789');
        
        // Act
        await repository.createListFromTemplate(
          templateId: 'template-456',
          listName: '  Ny Lista  ',
          description: '  Beskrivning  ',
        );
        
        // Assert
        final captured = verify(() => mockListDoc.set(captureAny())).captured.single as Map<String, dynamic>;
        expect(captured['name'], equals('Ny Lista'));
        expect(captured['description'], equals('Beskrivning'));
      });

      test('should preserve all items from template', () async {
        // Arrange
        final templateWithManyItems = Map<String, dynamic>.from(testTemplateData);
        final manyItems = List.generate(10, (i) => UnifiedShoppingItem(
          id: 'item-$i',
          name: 'Artikel $i',
          amount: i.toDouble(),
          unit: 'st',
          category: 'Kategori ${i % 3}',
        ));
        templateWithManyItems['items'] = manyItems.map((item) => item.toFirestore()).toList();
        
        final templateDoc = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => templateDoc.exists).thenReturn(true);
        when(() => templateDoc.data()).thenReturn(templateWithManyItems);
        when(() => mockTemplateDoc.get()).thenAnswer((_) async => templateDoc);
        
        when(() => mockListsCollection.doc()).thenReturn(mockListDoc);
        when(() => mockListDoc.id).thenReturn('new-list-789');
        
        // Act
        await repository.createListFromTemplate(
          templateId: 'template-456',
          listName: 'Lista med många artiklar',
        );
        
        // Assert
        final captured = verify(() => mockListDoc.set(captureAny())).captured.single as Map<String, dynamic>;
        final items = captured['items'] as List;
        expect(items.length, equals(10));
        
        // Verify item details are preserved
        for (int i = 0; i < 10; i++) {
          final item = items[i] as Map<String, dynamic>;
          expect(item['name'], equals('Artikel $i'));
          expect(item['amount'], equals(i.toDouble()));
          expect(item['category'], equals('Kategori ${i % 3}'));
        }
      });
    });

    group('Template Security and Validation', () {
      test('should enforce authentication for all template operations', () async {
        // Arrange
        mockAuthRepo.setAuthState(
          user: null,
          userId: null,
          isAuthenticated: false,
        );
        
        // Act & Assert - saveAsTemplate
        expect(
          () => repository.saveAsTemplate(
            listId: 'list-123',
            templateName: 'Test',
          ),
          throwsA(isA<Exception>()),
        );
        
        // Act & Assert - updateTemplate
        expect(
          () => repository.updateTemplate(
            templateId: 'template-456',
            name: 'New Name',
          ),
          throwsA(isA<Exception>()),
        );
        
        // Act & Assert - deleteTemplate
        expect(
          () => repository.deleteTemplate('template-456'),
          throwsA(isA<Exception>()),
        );
        
        // Act & Assert - getUserTemplates
        expect(
          () => repository.getUserTemplates(),
          throwsA(isA<Exception>()),
        );
        
        // Act & Assert - createListFromTemplate
        expect(
          () => repository.createListFromTemplate(
            templateId: 'template-456',
            listName: 'Test',
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('should validate required fields when creating template', () async {
        // Arrange
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.id).thenReturn('list-123');
        when(() => mockDocSnapshot.data()).thenReturn(testList.toFirestore());
        
        // Act
        await repository.saveAsTemplate(
          listId: 'list-123',
          templateName: 'Valid Name',
        );
        
        // Assert
        final captured = verify(() => mockTemplatesCollection.add(captureAny())).captured.single as Map<String, dynamic>;
        
        // Verify required fields are present
        expect(captured.containsKey('name'), isTrue);
        expect(captured.containsKey('ownerId'), isTrue);
        expect(captured.containsKey('items'), isTrue);
        expect(captured.containsKey('createdAt'), isTrue);
        expect(captured.containsKey('isPublic'), isTrue);
      });
    });

    group('Swedish Language Support', () {
      test('should handle Swedish characters in template names', () async {
        // Arrange
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.id).thenReturn('list-123');
        when(() => mockDocSnapshot.data()).thenReturn(testList.toFirestore());
        
        // Act
        await repository.saveAsTemplate(
          listId: 'list-123',
          templateName: 'Påsk Köttbullar Ägg Öl',
          description: 'Svensk måltid med åäö ÅÄÖ',
          tags: ['påsk', 'ägg', 'öl'],
        );
        
        // Assert
        final captured = verify(() => mockTemplatesCollection.add(captureAny())).captured.single as Map<String, dynamic>;
        expect(captured['name'], equals('Påsk Köttbullar Ägg Öl'));
        expect(captured['description'], equals('Svensk måltid med åäö ÅÄÖ'));
        expect(captured['tags'], equals(['påsk', 'ägg', 'öl']));
      });

      test('should handle Swedish characters in search queries', () async {
        // Arrange
        final mockSnapshot1 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        final mockSnapshot2 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        
        when(() => mockSnapshot1.data()).thenReturn({
          'name': 'Köttbullar Recept',
          'ownerId': 'user-123',
        });
        when(() => mockSnapshot2.data()).thenReturn({
          'name': 'Räksmörgås Mall',
          'ownerId': 'user-456',
        });
        
        when(() => mockQuerySnapshot.docs).thenReturn([mockSnapshot1, mockSnapshot2]);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(() => mockTemplatesCollection.where('name', isGreaterThanOrEqualTo: any())).thenReturn(mockQuery);
        when(() => mockQuery.where('name', isLessThan: any())).thenReturn(mockQuery);
        when(() => mockQuery.where('isPublic', isEqualTo: true)).thenReturn(mockQuery);
        when(() => mockQuery.orderBy('createdAt', descending: true)).thenReturn(mockQuery);
        when(() => mockQuery.limit(20)).thenReturn(mockQuery);
        
        // Act
        await repository.getPublicTemplates(
          searchQuery: 'köttbullar',
        );
        
        // Assert
        verify(() => mockTemplatesCollection.where('name', isGreaterThanOrEqualTo: 'köttbullar')).called(1);
      });
    });

    group('Performance and Large Data Sets', () {
      test('should handle templates with 100+ items efficiently', () async {
        // Arrange
        final largeItemList = List.generate(150, (i) => UnifiedShoppingItem(
          id: 'item-$i',
          name: 'Produkt $i',
          amount: (i + 1).toDouble(),
          unit: i % 2 == 0 ? 'kg' : 'st',
          category: 'Kategori ${i % 10}',
          priority: i % 3,
        ));
        
        final largeList = UnifiedShoppingList(
          id: 'large-list',
          name: 'Stor Lista',
          ownerId: 'test-user-123',
          ownerDisplayName: 'Test User',
          items: largeItemList,
          type: ListType.personal,
        );
        
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.id).thenReturn('large-list');
        when(() => mockDocSnapshot.data()).thenReturn(largeList.toFirestore());
        
        // Act
        final templateId = await repository.saveAsTemplate(
          listId: 'large-list',
          templateName: 'Stor Mall',
        );
        
        // Assert
        expect(templateId, equals('template-456'));
        final captured = verify(() => mockTemplatesCollection.add(captureAny())).captured.single as Map<String, dynamic>;
        expect((captured['items'] as List).length, equals(150));
        expect(captured['metadata']['itemCount'], equals(150));
      });

      test('should paginate when retrieving many public templates', () async {
        // Arrange
        final manyTemplates = List.generate(50, (i) {
          final mockDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();
          when(() => mockDoc.data()).thenReturn({
            'name': 'Template $i',
            'ownerId': 'user-$i',
            'isPublic': true,
          });
          return mockDoc;
        });
        
        when(() => mockQuerySnapshot.docs).thenReturn(manyTemplates.take(20).toList());
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(() => mockTemplatesCollection.where('isPublic', isEqualTo: true)).thenReturn(mockQuery);
        when(() => mockQuery.orderBy('createdAt', descending: true)).thenReturn(mockQuery);
        when(() => mockQuery.limit(20)).thenReturn(mockQuery);
        
        // Act
        final results = await repository.getPublicTemplates(limit: 20);
        
        // Assert
        expect(results.length, equals(20));
        verify(() => mockQuery.limit(20)).called(1);
      });
    });

    group('Template Sharing and Collaboration', () {
      test('should track template usage statistics', () async {
        // Arrange
        final templateWithStats = Map<String, dynamic>.from(testTemplateData);
        templateWithStats['metadata'] = {
          'itemCount': 5,
          'version': '1.0',
          'usageCount': 42,
          'lastUsed': Timestamp.now(),
        };
        
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.data()).thenReturn(templateWithStats);
        
        // Act
        await repository.updateTemplate(
          templateId: 'template-456',
          name: 'Popular Template',
        );
        
        // Assert
        verify(() => mockTemplateDoc.update(any())).called(1);
      });

      test('should handle template versioning on update', () async {
        // Arrange
        final versionedTemplate = Map<String, dynamic>.from(testTemplateData);
        versionedTemplate['metadata']['version'] = '1.0';
        
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.data()).thenReturn(versionedTemplate);
        
        // Act
        await repository.updateTemplate(
          templateId: 'template-456',
          name: 'Updated Template v2',
        );
        
        // Assert
        final captured = verify(() => mockTemplateDoc.update(captureAny())).captured.single as Map<String, dynamic>;
        expect(captured['name'], equals('Updated Template v2'));
      });
    });

    group('Edge Cases and Error Scenarios', () {
      test('should handle empty shopping list when creating template', () async {
        // Arrange
        final emptyList = UnifiedShoppingList(
          id: 'empty-list',
          name: 'Tom Lista',
          ownerId: 'test-user-123',
          ownerDisplayName: 'Test User',
          items: [], // Empty items
          type: ListType.personal,
        );
        
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.id).thenReturn('empty-list');
        when(() => mockDocSnapshot.data()).thenReturn(emptyList.toFirestore());
        
        // Act
        final templateId = await repository.saveAsTemplate(
          listId: 'empty-list',
          templateName: 'Tom Mall',
        );
        
        // Assert
        expect(templateId, equals('template-456'));
        final captured = verify(() => mockTemplatesCollection.add(captureAny())).captured.single as Map<String, dynamic>;
        expect((captured['items'] as List).isEmpty, isTrue);
        expect(captured['metadata']['itemCount'], equals(0));
      });

      test('should handle null description gracefully', () async {
        // Arrange
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.id).thenReturn('list-123');
        when(() => mockDocSnapshot.data()).thenReturn(testList.toFirestore());
        
        // Act
        await repository.saveAsTemplate(
          listId: 'list-123',
          templateName: 'Template Without Description',
          description: null,
        );
        
        // Assert
        final captured = verify(() => mockTemplatesCollection.add(captureAny())).captured.single as Map<String, dynamic>;
        expect(captured['description'], isNull);
      });

      test('should handle special characters in template names', () async {
        // Arrange
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.id).thenReturn('list-123');
        when(() => mockDocSnapshot.data()).thenReturn(testList.toFirestore());
        
        // Act
        await repository.saveAsTemplate(
          listId: 'list-123',
          templateName: 'Template @#\$% & (Special)',
          tags: ['special!', 'test@123'],
        );
        
        // Assert
        final captured = verify(() => mockTemplatesCollection.add(captureAny())).captured.single as Map<String, dynamic>;
        expect(captured['name'], equals('Template @#\$% & (Special)'));
        expect(captured['tags'], equals(['special!', 'test@123']));
      });

      test('should handle concurrent template operations safely', () async {
        // Arrange
        when(() => mockDocSnapshot.exists).thenReturn(true);
        when(() => mockDocSnapshot.id).thenReturn('list-123');
        when(() => mockDocSnapshot.data()).thenReturn(testList.toFirestore());
        
        // Act - Simulate concurrent operations
        final future1 = repository.saveAsTemplate(
          listId: 'list-123',
          templateName: 'Concurrent Template 1',
        );
        
        final future2 = repository.saveAsTemplate(
          listId: 'list-123',
          templateName: 'Concurrent Template 2',
        );
        
        final results = await Future.wait([future1, future2]);
        
        // Assert
        expect(results.length, equals(2));
        expect(results[0], equals('template-456'));
        expect(results[1], equals('template-456'));
        verify(() => mockTemplatesCollection.add(any())).called(2);
      });
    });

    group('Complex Search and Filter Scenarios', () {
      test('should combine multiple tag filters correctly', () async {
        // Arrange
        when(() => mockQuerySnapshot.docs).thenReturn([]);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(() => mockTemplatesCollection.where('isPublic', isEqualTo: true)).thenReturn(mockQuery);
        when(() => mockQuery.where('tags', arrayContainsAny: any())).thenReturn(mockQuery);
        when(() => mockQuery.orderBy('createdAt', descending: true)).thenReturn(mockQuery);
        when(() => mockQuery.limit(10)).thenReturn(mockQuery);
        
        // Act
        await repository.getPublicTemplates(
          tags: ['vecka', 'budget', 'vegetarisk'],
          limit: 10,
        );
        
        // Assert
        verify(() => mockQuery.where(
          'tags',
          arrayContainsAny: ['vecka', 'budget', 'vegetarisk']
        )).called(1);
        verify(() => mockQuery.limit(10)).called(1);
      });

      test('should handle case-insensitive search', () async {
        // Arrange
        when(() => mockQuerySnapshot.docs).thenReturn([]);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(() => mockTemplatesCollection.where('name', isGreaterThanOrEqualTo: any())).thenReturn(mockQuery);
        when(() => mockQuery.where('name', isLessThan: any())).thenReturn(mockQuery);
        when(() => mockQuery.where('isPublic', isEqualTo: true)).thenReturn(mockQuery);
        when(() => mockQuery.orderBy('createdAt', descending: true)).thenReturn(mockQuery);
        when(() => mockQuery.limit(20)).thenReturn(mockQuery);
        
        // Act
        await repository.getPublicTemplates(
          searchQuery: 'VECKOHANDLING',
        );
        
        // Assert
        // Repository should lowercase the search query
        verify(() => mockTemplatesCollection.where(
          'name',
          isGreaterThanOrEqualTo: 'VECKOHANDLING'
        )).called(1);
      });

      test('should sort templates by creation date', () async {
        // Arrange
        final template1 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        final template2 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        
        when(() => template1.data()).thenReturn({
          'name': 'Older Template',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
        });
        when(() => template2.data()).thenReturn({
          'name': 'Newer Template',
          'createdAt': Timestamp.fromDate(DateTime(2024, 12, 1)),
        });
        
        when(() => mockQuerySnapshot.docs).thenReturn([template2, template1]);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(() => mockTemplatesCollection.where('isPublic', isEqualTo: true)).thenReturn(mockQuery);
        when(() => mockQuery.orderBy('createdAt', descending: true)).thenReturn(mockQuery);
        when(() => mockQuery.limit(20)).thenReturn(mockQuery);
        
        // Act
        await repository.getPublicTemplates();
        
        // Assert
        verify(() => mockQuery.orderBy('createdAt', descending: true)).called(1);
      });
    });
  });
}