import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:get_it/get_it.dart';
import '../../../helpers/mock_factories.dart';

// Mocks
class MockUnifiedShoppingService extends Mock
    implements UnifiedShoppingService {}

class MockPermissionService extends Mock implements PermissionService {}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockUnifiedShoppingService mockShoppingService;
  late MockPermissionService mockPermissionService;
  late GetIt sl;

  setUpAll(() {
    registerFallbackValue(UnifiedShoppingListFactory.empty());
    registerFallbackValue(UnifiedShoppingItemFactory.empty());
    registerFallbackValue(RecipeFactory.empty());
  });

  setUp(() async {
    // Setup service locator
    sl = GetIt.instance;
    if (sl.isRegistered<UnifiedShoppingService>()) {
      sl.unregister<UnifiedShoppingService>();
    }
    if (sl.isRegistered<PermissionService>()) {
      sl.unregister<PermissionService>();
    }

    // Create mocks
    mockShoppingService = MockUnifiedShoppingService();
    mockPermissionService = MockPermissionService();

    // Register mocks
    sl.registerSingleton<UnifiedShoppingService>(mockShoppingService);
    sl.registerSingleton<PermissionService>(mockPermissionService);

    // Setup default mocks
    when(() => mockShoppingService.lists).thenReturn([]);
    when(() => mockShoppingService.personalLists).thenReturn([]);
    when(() => mockShoppingService.collaborativeLists).thenReturn([]);
    when(() => mockShoppingService.activeList).thenReturn(null);
    when(() => mockShoppingService.isLoading).thenReturn(false);
    when(() => mockShoppingService.isSyncing).thenReturn(false);
    when(() => mockShoppingService.isInitialized).thenReturn(false);
    when(() => mockShoppingService.error).thenReturn(null);
    when(() => mockShoppingService.hasError).thenReturn(false);
    when(() => mockShoppingService.hasLists).thenReturn(false);
    when(() => mockShoppingService.currentUserDisplayName).thenReturn('Test User');
    when(() => mockShoppingService.addListener(any())).thenReturn(null);
    when(() => mockShoppingService.removeListener(any())).thenReturn(null);

    when(() => mockPermissionService.currentUserId).thenReturn('current_user');
  });

  tearDown(() {
    sl.unregister<UnifiedShoppingService>();
    sl.unregister<PermissionService>();
  });

  group('Shopping Workflow Integration Tests', () {
    testWidgets('Complete personal shopping workflow', (tester) async {
      // Step 1: Create a shopping list
      const listName = 'Veckohandling';
      final newList = UnifiedShoppingListFactory.build(
        id: 'list_123',
        name: listName,
        ownerId: 'current_user',
        createdAt: DateTime.now(),
      );

      when(() => mockShoppingService.createPersonalList(any()))
          .thenAnswer((_) async => 'list_123');
      when(() => mockShoppingService.initialize()).thenAnswer((_) async {});
      when(() => mockShoppingService.hasLists).thenReturn(true);
      when(() => mockShoppingService.lists).thenReturn([newList]);
      when(() => mockShoppingService.personalLists).thenReturn([newList]);
      when(() => mockShoppingService.activeList).thenReturn(newList);

      final shoppingViewModel = UnifiedShoppingViewModel();
      await shoppingViewModel.initialize();

      final created = await shoppingViewModel.createPersonalList(listName);

      expect(created, isTrue);
      expect(shoppingViewModel.lists.length, equals(1));
      expect(shoppingViewModel.activeList, equals(newList));

      // Step 2: Add items manually
      final manualItems = [
        UnifiedShoppingItemFactory.build(
          id: 'item_1',
          name: 'Mjölk',
          amount: 2.0,
          unit: 'liter',
          category: 'Mejeri',
        ),
        UnifiedShoppingItemFactory.build(
          id: 'item_2',
          name: 'Bröd',
          amount: 1.0,
          unit: 'st',
          category: 'Bageri',
        ),
        UnifiedShoppingItemFactory.build(
          id: 'item_3',
          name: 'Äpplen',
          amount: 1.0,
          unit: 'kg',
          category: 'Frukt',
        ),
      ];

      for (final item in manualItems) {
        when(() => mockShoppingService.addItemToActiveList(
              name: any(named: 'name'),
              amount: any(named: 'amount'),
              unit: any(named: 'unit'),
              category: any(named: 'category'),
              note: any(named: 'note'),
              estimatedPrice: any(named: 'estimatedPrice'),
              priority: any(named: 'priority'),
            )).thenAnswer((_) async => true);

        await shoppingViewModel.addItem(
          name: item.name,
          amount: item.amount,
          unit: item.unit,
          category: item.category,
        );
      }

      // Update list with items
      final updatedList = newList.copyWith(items: manualItems);
      when(() => mockShoppingService.activeList).thenReturn(updatedList);

      // Step 3: Check off items while shopping
      when(() => mockShoppingService.toggleItemBought(any()))
          .thenAnswer((_) async => true);

      // Check off milk and bread
      final toggled1 = await shoppingViewModel.toggleItemBought('item_1');
      final toggled2 = await shoppingViewModel.toggleItemBought('item_2');

      expect(toggled1, isTrue);
      expect(toggled2, isTrue);

      verify(() => mockShoppingService.toggleItemBought('item_1')).called(1);
      verify(() => mockShoppingService.toggleItemBought('item_2')).called(1);

      // Step 4: Clear bought items
      when(() => mockShoppingService.clearBoughtItems())
          .thenAnswer((_) async => true);

      final cleared = await shoppingViewModel.clearBoughtItems();

      expect(cleared, isTrue);
      verify(() => mockShoppingService.clearBoughtItems()).called(1);
    });

    testWidgets('Collaborative shopping workflow', (tester) async {
      // Step 1: Create collaborative list
      const listName = 'Familjelista';
      final participants = ['user1', 'user2', 'user3'];
      final participantDisplayNames = {
        'user1': 'Anna',
        'user2': 'Erik',
        'user3': 'Lisa',
      };

      final collaborativeList = UnifiedShoppingListFactory.build(
        id: 'collab_123',
        name: listName,
        // isCollaborative is derived from memberPermissions, not set directly
        memberPermissions: {
          'current_user': SharedListPermission.admin,
          'user1': SharedListPermission.edit,
          'user2': SharedListPermission.edit,
          'user3': SharedListPermission.view,
        },
      );

      when(() => mockShoppingService.createCollaborativeList(
            name: any(named: 'name'),
            description: any(named: 'description'),
            memberIds: any(named: 'memberIds'),
            memberDisplayNames: any(named: 'memberDisplayNames'),
            items: any(named: 'items'),
            categoryIds: any(named: 'categoryIds'),
            allowGuestEditing: any(named: 'allowGuestEditing'),
            autoRemoveCompleted: any(named: 'autoRemoveCompleted'),
          )).thenAnswer((_) async => 'collab_123');

      when(() => mockShoppingService.initialize()).thenAnswer((_) async {});
      when(() => mockShoppingService.hasLists).thenReturn(true);
      when(() => mockShoppingService.lists).thenReturn([collaborativeList]);
      when(() => mockShoppingService.collaborativeLists)
          .thenReturn([collaborativeList]);
      when(() => mockShoppingService.activeList).thenReturn(collaborativeList);

      final shoppingViewModel = UnifiedShoppingViewModel();
      await shoppingViewModel.initialize();

      final created = await shoppingViewModel.createCollaborativeList(
        name: listName,
        memberIds: participants,
        memberDisplayNames: participantDisplayNames,
      );

      expect(created, isTrue);
      expect(shoppingViewModel.collaborativeLists.length, equals(1));
      expect(shoppingViewModel.activeList?.isCollaborative, isTrue);
    });

    testWidgets('Recipe to shopping list workflow', (tester) async {
      // Given - Active shopping list and recipe
      final activeList = UnifiedShoppingListFactory.build(
        id: 'list_123',
        name: 'Veckohandling',
      );


      when(() => mockShoppingService.activeList).thenReturn(activeList);
      when(() => mockShoppingService.hasLists).thenReturn(true);
      when(() => mockShoppingService.lists).thenReturn([activeList]);

      final shoppingViewModel = UnifiedShoppingViewModel();

      // When - Add recipe ingredients to shopping list
      when(() => mockShoppingService.addItemToActiveList(
            name: any(named: 'name'),
            amount: any(named: 'amount'),
            unit: any(named: 'unit'),
            category: any(named: 'category'),
            note: any(named: 'note'),
            estimatedPrice: any(named: 'estimatedPrice'),
            priority: any(named: 'priority'),
          )).thenAnswer((_) async => true);

      final ingredientData = [
        {'name': 'blandfärs', 'amount': 500.0, 'unit': 'g'},
        {'name': 'ägg', 'amount': 1.0, 'unit': 'st'},
        {'name': 'ströbröd', 'amount': 1.0, 'unit': 'dl'},
        {'name': 'mjölk', 'amount': 1.0, 'unit': 'dl'},
        {'name': 'lök', 'amount': 1.0, 'unit': 'st'},
      ];

      final added = await shoppingViewModel.addItemsFromRecipe(ingredientData);

      // Then
      expect(added, isTrue);
      verify(() => mockShoppingService.addItemToActiveList(
            name: 'blandfärs',
            amount: 500.0,
            unit: 'g',
            category: 'Övrigt',
            note: null,
            estimatedPrice: null,
            priority: 3,
          )).called(1);
    });
  });
}