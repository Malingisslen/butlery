import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import '../../../helpers/mock_factories.dart';

// Mocks
class MockAuthRepository extends Mock implements AuthRepository {}
class MockFirestoreRepository extends Mock implements FirestoreRepository {}

void main() {
  late UnifiedShoppingService sut;
  late MockAuthRepository mockAuthRepository;
  late MockFirestoreRepository mockFirestoreRepository;

  setUpAll(() {
    registerFallbackValue(UnifiedShoppingListFactory.empty());
    registerFallbackValue(UnifiedShoppingItemFactory.empty());
    registerFallbackValue(RecipeFactory.empty());
  });

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    mockFirestoreRepository = MockFirestoreRepository();

    // Setup default auth
    when(() => mockAuthRepository.currentUserId).thenReturn('test_user_id');
    when(() => mockAuthRepository.getCurrentUser()).thenReturn(null);

    sut = UnifiedShoppingService(
      authRepository: mockAuthRepository,
      firestoreRepository: mockFirestoreRepository,
    );
  });

  group('UnifiedShoppingService - List Management', () {
    test('should create personal shopping list', () async {
      // Given
      const listName = 'My Shopping List';

      // When
      final listId = await sut.createPersonalList(listName);

      // Then
      expect(listId, isNotNull);
      expect(listId, equals('mock-list-id'));
    });

    test('should create collaborative shopping list', () async {
      // Given
      const listName = 'Family Shopping';
      final memberIds = ['user1', 'user2'];
      final memberDisplayNames = {'user1': 'User 1', 'user2': 'User 2'};

      // When
      final listId = await sut.createCollaborativeList(
        name: listName,
        memberIds: memberIds,
        memberDisplayNames: memberDisplayNames,
      );

      // Then
      expect(listId, isNotNull);
      expect(listId, equals('mock-collaborative-list-id'));
    });

    test('should rename list', () async {
      // Given
      const listId = 'list_123';
      const newName = 'Updated List Name';

      // When
      final result = await sut.renameList(listId, newName);

      // Then
      expect(result, isTrue);
    });

    test('should delete list', () async {
      // Given
      const listId = 'list_123';

      // When
      final result = await sut.deleteList(listId);

      // Then
      expect(result, isTrue);
    });

    test('should set active list', () async {
      // Given
      const listId = 'list_123';

      // When
      final result = await sut.setActiveList(listId);

      // Then
      expect(result, isTrue);
    });

    test('should export list as text', () {
      // Given
      const listId = 'list_123';

      // When
      final exported = sut.exportListAsText(listId);

      // Then
      expect(exported, isNotEmpty);
      expect(exported, equals('Mock shopping list export'));
    });
  });

  group('UnifiedShoppingService - Item Management', () {
    test('should add item to active list', () async {
      // Given
      const itemName = 'Milk';

      // When
      final result = await sut.addItemToActiveList(
        name: itemName,
        amount: 2.0,
        unit: 'liter',
        category: 'Dairy',
      );

      // Then
      expect(result, isTrue);
    });

    test('should toggle item bought status', () async {
      // Given
      const itemId = 'item_123';

      // When
      final result = await sut.toggleItemBought(itemId);

      // Then
      expect(result, isTrue);
    });

    test('should remove item from active list', () async {
      // Given
      const itemId = 'item_123';

      // When
      final result = await sut.removeItemFromActiveList(itemId);

      // Then
      expect(result, isTrue);
    });

    test('should update item in active list', () async {
      // Given
      const itemId = 'item_123';

      // When
      final result = await sut.updateItemInActiveList(
        itemId: itemId,
        name: 'Updated Item',
        quantity: 3.0,
      );

      // Then
      expect(result, isTrue);
    });

    test('should clear completed items', () async {
      // When
      final result = await sut.clearBoughtItems();

      // Then
      expect(result, isTrue);
    });

    test('should uncheck all items', () async {
      // When
      final result = await sut.uncheckAllItems();

      // Then
      expect(result, isTrue);
    });
  });

  group('UnifiedShoppingService - State', () {
    test('should have correct initial state', () {
      expect(sut.lists, isEmpty);
      expect(sut.personalLists, isEmpty);
      expect(sut.collaborativeLists, isEmpty);
      expect(sut.activeList, isNull);
      expect(sut.hasLists, isFalse);
      expect(sut.isInitialized, isTrue); // Simplified implementation always returns true
      expect(sut.isLoading, isFalse);
      expect(sut.error, isNull);
      expect(sut.hasError, isFalse);
    });

    test('should initialize service', () async {
      // When
      await sut.initialize();

      // Then
      expect(sut.isInitialized, isTrue);
    });

    test('should clear error', () {
      // When
      sut.clearError();

      // Then
      expect(sut.error, isNull);
      expect(sut.hasError, isFalse);
    });
  });

  group('UnifiedShoppingService - Listener Management', () {
    test('should add and remove listeners', () {
      // Given
      void listener() {}

      // When/Then - should not throw
      sut.addListener(listener);
      sut.removeListener(listener);
    });

    test('should notify listeners', () {
      // Given
      var notified = false;
      void listener() {
        notified = true;
      }

      sut.addListener(listener);

      // When
      sut.notifyListeners();

      // Then
      expect(notified, isTrue);

      // Cleanup
      sut.removeListener(listener);
    });
  });
}