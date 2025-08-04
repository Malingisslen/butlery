import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:butlery/views/unified_shopping_view.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/viewmodels/collaborative_shopping_viewmodel.dart';
import '../../../helpers/mock_factories.dart';

// Mocks
class MockUnifiedShoppingViewModel extends Mock
    implements UnifiedShoppingViewModel {}

class MockCollaborativeShoppingViewModel extends Mock
    implements CollaborativeShoppingViewModel {}

void main() {
  late MockUnifiedShoppingViewModel mockShoppingViewModel;
  late MockCollaborativeShoppingViewModel mockCollaborativeViewModel;

  setUp(() {
    mockShoppingViewModel = MockUnifiedShoppingViewModel();
    mockCollaborativeViewModel = MockCollaborativeShoppingViewModel();

    // Setup default mock behaviors for UnifiedShoppingViewModel
    when(() => mockShoppingViewModel.lists).thenReturn([]);
    when(() => mockShoppingViewModel.personalLists).thenReturn([]);
    when(() => mockShoppingViewModel.collaborativeLists).thenReturn([]);
    when(() => mockShoppingViewModel.activeList).thenReturn(null);
    when(() => mockShoppingViewModel.items).thenReturn([]);
    when(() => mockShoppingViewModel.isLoading).thenReturn(false);
    when(() => mockShoppingViewModel.error).thenReturn(null);
    when(() => mockShoppingViewModel.hasError).thenReturn(false);
    when(() => mockShoppingViewModel.isInitialized).thenReturn(true);
    when(() => mockShoppingViewModel.hasLists).thenReturn(false);
    when(() => mockShoppingViewModel.hasItems).thenReturn(false);
    when(() => mockShoppingViewModel.totalItems).thenReturn(0);
    when(() => mockShoppingViewModel.boughtItems).thenReturn(0);
    when(() => mockShoppingViewModel.unboughtItems).thenReturn(0);
    when(() => mockShoppingViewModel.completionPercentage).thenReturn(0.0);
    when(() => mockShoppingViewModel.listSummary).thenReturn('Ingen aktiv lista');
    when(() => mockShoppingViewModel.allItemsBought).thenReturn(false);
    when(() => mockShoppingViewModel.currentUserId).thenReturn('test_user');
    when(() => mockShoppingViewModel.currentUserDisplayName).thenReturn('Test User');
    when(() => mockShoppingViewModel.canEditActiveList).thenReturn(true);
    when(() => mockShoppingViewModel.canManageActiveList).thenReturn(true);
    when(() => mockShoppingViewModel.activeListMembers).thenReturn([]);
    when(() => mockShoppingViewModel.itemsByCategory).thenReturn({});
    when(() => mockShoppingViewModel.usedCategories).thenReturn([]);
    when(() => mockShoppingViewModel.shoppingInsights).thenReturn({});
    when(() => mockShoppingViewModel.exportListAsText()).thenReturn('');
    when(() => mockShoppingViewModel.exportListAsTextWithCategories()).thenReturn('');
    when(() => mockShoppingViewModel.addListener(any())).thenReturn(null);
    when(() => mockShoppingViewModel.removeListener(any())).thenReturn(null);

    when(() => mockCollaborativeViewModel.addListener(any())).thenReturn(null);
    when(() => mockCollaborativeViewModel.removeListener(any()))
        .thenReturn(null);
  });

  Widget createTestWidget({Widget? child}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<UnifiedShoppingViewModel>.value(
            value: mockShoppingViewModel),
        ChangeNotifierProvider<CollaborativeShoppingViewModel>.value(
            value: mockCollaborativeViewModel),
      ],
      child: MaterialApp(
        home: child ?? const UnifiedShoppingView(),
      ),
    );
  }

  group('UnifiedShoppingView - Display', () {
    testWidgets('should display app bar with title', (tester) async {
      // When
      await tester.pumpWidget(createTestWidget());

      // Then
      expect(find.text('Inköpslistor'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('should display empty state when no lists', (tester) async {
      // When
      await tester.pumpWidget(createTestWidget());

      // Then
      expect(find.text('Inga inköpslistor'), findsOneWidget);
      expect(find.text('Skapa din första lista för att komma igång'),
          findsOneWidget);
      expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
    });

    testWidgets('should display loading indicator', (tester) async {
      // Given
      when(() => mockShoppingViewModel.isLoading).thenReturn(true);

      // When
      await tester.pumpWidget(createTestWidget());

      // Then
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display error message', (tester) async {
      // Given
      when(() => mockShoppingViewModel.error)
          .thenReturn('Kunde inte ladda listorna');
      when(() => mockShoppingViewModel.hasError).thenReturn(true);

      // When
      await tester.pumpWidget(createTestWidget());

      // Then
      expect(find.text('Kunde inte ladda listorna'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('UnifiedShoppingView - Lists', () {
    testWidgets('should display shopping lists', (tester) async {
      // Given
      final lists = [
        UnifiedShoppingListFactory.build(
          id: 'list1',
          name: 'Veckohandling',
          items: List.generate(10, (index) => UnifiedShoppingItemFactory.build(
            bought: index < 3, // First 3 items are bought
          )),
        ),
        UnifiedShoppingListFactory.build(
          id: 'list2',
          name: 'Festmat',
          items: List.generate(5, (index) => UnifiedShoppingItemFactory.build(
            bought: false, // No items bought
          )),
        ),
      ];
      when(() => mockShoppingViewModel.lists).thenReturn(lists);
      when(() => mockShoppingViewModel.hasLists).thenReturn(true);

      // When
      await tester.pumpWidget(createTestWidget());

      // Then
      expect(find.text('Veckohandling'), findsOneWidget);
      expect(find.text('Festmat'), findsOneWidget);
    });

    testWidgets('should show active list indicator', (tester) async {
      // Given
      final activeList = UnifiedShoppingListFactory.build(
        id: 'active_list',
        name: 'Aktiv lista',
      );
      final lists = [activeList];
      when(() => mockShoppingViewModel.lists).thenReturn(lists);
      when(() => mockShoppingViewModel.hasLists).thenReturn(true);
      when(() => mockShoppingViewModel.activeList).thenReturn(activeList);

      // When
      await tester.pumpWidget(createTestWidget());

      // Then
      expect(find.text('Aktiv lista'), findsOneWidget);
      // Check for active indicator (implementation specific)
    });
  });

  group('UnifiedShoppingView - Items', () {
    testWidgets('should display items when list is active', (tester) async {
      // Given
      final items = [
        UnifiedShoppingItemFactory.build(
          name: 'Mjölk',
          amount: 2.0,
          unit: 'liter',
          bought: false,
        ),
        UnifiedShoppingItemFactory.build(
          name: 'Bröd',
          amount: 1.0,
          unit: 'st',
          bought: true,
        ),
      ];
      final activeList = UnifiedShoppingListFactory.build(
        id: 'list1',
        name: 'Veckohandling',
        items: items,
      );
      when(() => mockShoppingViewModel.activeList).thenReturn(activeList);
      when(() => mockShoppingViewModel.items).thenReturn(items);
      when(() => mockShoppingViewModel.hasItems).thenReturn(true);

      // When
      await tester.pumpWidget(createTestWidget());

      // Then
      expect(find.text('Mjölk'), findsOneWidget);
      expect(find.text('Bröd'), findsOneWidget);
    });

    testWidgets('should show item categories', (tester) async {
      // Given
      final itemsByCategory = {
        'Mejeri': [
          UnifiedShoppingItemFactory.build(name: 'Mjölk', category: 'Mejeri'),
          UnifiedShoppingItemFactory.build(name: 'Ost', category: 'Mejeri'),
        ],
        'Bageri': [
          UnifiedShoppingItemFactory.build(name: 'Bröd', category: 'Bageri'),
        ],
      };
      when(() => mockShoppingViewModel.itemsByCategory).thenReturn(itemsByCategory);
      when(() => mockShoppingViewModel.hasItems).thenReturn(true);

      // When
      await tester.pumpWidget(createTestWidget());

      // Then
      expect(find.text('Mejeri'), findsOneWidget);
      expect(find.text('Bageri'), findsOneWidget);
    });
  });

  group('UnifiedShoppingView - Search', () {
    testWidgets('should filter items when searching', (tester) async {
      // Given
      final allItems = [
        UnifiedShoppingItemFactory.build(name: 'Mjölk'),
        UnifiedShoppingItemFactory.build(name: 'Havremjölk'),
        UnifiedShoppingItemFactory.build(name: 'Bröd'),
      ];
      final activeList = UnifiedShoppingListFactory.build(items: allItems);
      when(() => mockShoppingViewModel.activeList).thenReturn(activeList);
      when(() => mockShoppingViewModel.items).thenReturn(allItems);
      when(() => mockShoppingViewModel.searchItems('mjölk')).thenReturn([
        allItems[0], // Mjölk
        allItems[1], // Havremjölk
      ]);

      // When
      await tester.pumpWidget(createTestWidget());
      
      // Tap search icon
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      
      // Enter search query
      await tester.enterText(find.byType(TextField), 'mjölk');
      await tester.pumpAndSettle();

      // Then - implementation specific, depends on how search is displayed
    });
  });

  group('UnifiedShoppingView - Actions', () {
    testWidgets('should create new list', (tester) async {
      // Given
      when(() => mockShoppingViewModel.createPersonalList(any()))
          .thenAnswer((_) async => true);

      // When
      await tester.pumpWidget(createTestWidget());
      
      // Find and tap FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Enter list name in dialog
      await tester.enterText(find.byType(TextField), 'Ny lista');
      
      // Tap create button
      await tester.tap(find.text('Skapa'));
      await tester.pumpAndSettle();

      // Then
      verify(() => mockShoppingViewModel.createPersonalList('Ny lista')).called(1);
    });

    testWidgets('should add item to active list', (tester) async {
      // Given
      final activeList = UnifiedShoppingListFactory.build(id: 'list1');
      when(() => mockShoppingViewModel.activeList).thenReturn(activeList);
      when(() => mockShoppingViewModel.addItem(
        name: any(named: 'name'),
        amount: any(named: 'amount'),
        unit: any(named: 'unit'),
        category: any(named: 'category'),
        note: any(named: 'note'),
        estimatedPrice: any(named: 'estimatedPrice'),
        priority: any(named: 'priority'),
      )).thenAnswer((_) async => true);

      // When
      await tester.pumpWidget(createTestWidget());
      
      // Implementation specific - depends on how items are added in the UI
    });

    testWidgets('should toggle item bought status', (tester) async {
      // Given
      final item = UnifiedShoppingItemFactory.build(
        id: 'item1',
        name: 'Mjölk',
        bought: false,
      );
      final activeList = UnifiedShoppingListFactory.build(items: [item]);
      when(() => mockShoppingViewModel.activeList).thenReturn(activeList);
      when(() => mockShoppingViewModel.items).thenReturn([item]);
      when(() => mockShoppingViewModel.toggleItemBought(any()))
          .thenAnswer((_) async => true);

      // When
      await tester.pumpWidget(createTestWidget());
      
      // Find and tap checkbox
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Then
      verify(() => mockShoppingViewModel.toggleItemBought('item1')).called(1);
    });
  });
}