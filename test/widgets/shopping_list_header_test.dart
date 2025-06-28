// test/widgets/shopping_list_header_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:butlery/widgets/shopping_list_header.dart';
import 'package:butlery/viewmodels/shopping_list_viewmodel.dart';
import 'package:butlery/models/shopping_list.dart';
import 'package:butlery/models/shopping_item.dart';
import 'package:butlery/theme/app_theme.dart';

// Import generated mocks
import '../helpers/test_helpers.mocks.dart';

void main() {
  group('ShoppingListHeader Widget Tests', () {
    late MockShoppingListViewModel mockViewModel;

    setUp(() {
      mockViewModel = MockShoppingListViewModel();

      // Default stubs
      when(mockViewModel.hasItems).thenReturn(false);
      when(mockViewModel.activeList).thenReturn(null);
      when(mockViewModel.isChangingList).thenReturn(false);
      when(mockViewModel.totalCount).thenReturn(0);
      when(mockViewModel.checkedCount).thenReturn(0);
      when(mockViewModel.uncheckedCount).thenReturn(0);
    });

    Widget createTestWidget({
      required VoidCallback onListTap,
    }) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ChangeNotifierProvider<ShoppingListViewModel>.value(
            value: mockViewModel,
            child: ShoppingListHeader(
              onListTap: onListTap,
            ),
          ),
        ),
      );
    }

    testWidgets('displays "Välj lista" when no active list', (tester) async {
      // Arrange
      // Act
      await tester.pumpWidget(
        createTestWidget(
          onListTap: () {},
        ),
      );

      // Assert
      expect(find.text('Välj lista'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_cart), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
    });

    testWidgets('displays active list information', (tester) async {
      // Arrange
      final activeList = ShoppingList(
        id: 'test-list',
        name: 'Veckans inköp',
        items: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        ownerId: 'test-owner-id',
      );

      when(mockViewModel.activeList).thenReturn(activeList);

      // Act
      await tester.pumpWidget(
        createTestWidget(onListTap: () {}),
      );

      // Assert
      expect(find.text('Veckans inköp'), findsOneWidget);
      expect(find.text('0 artiklar'), findsOneWidget);
    });

    testWidgets('shows sync status emoji', (tester) async {
      // Arrange
      final activeList = ShoppingList(
        id: 'test-list',
        name: 'Test List',
        items: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        ownerId: 'test-owner-id',
      );

      when(mockViewModel.activeList).thenReturn(activeList);

      // Act
      await tester.pumpWidget(
        createTestWidget(onListTap: () {}),
      );

      // Assert
      expect(find.text(activeList.syncStatusEmoji), findsOneWidget);
    });

    testWidgets('calls onListTap when selector tapped', (tester) async {
      // Arrange
      await tester.pumpWidget(
        createTestWidget(
          onListTap: () {},
        ),
      );

      // Act
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Assert
      expect(tapCalled, isTrue);
    });

    testWidgets('shows loading indicator when changing list', (tester) async {
      // Arrange
      when(mockViewModel.isChangingList).thenReturn(true);

      // Act
      await tester.pumpWidget(
        createTestWidget(onListTap: () {}),
      );

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    });

    testWidgets('disables tap when changing list', (tester) async {
      // Arrange
      when(mockViewModel.isChangingList).thenReturn(true);

      await tester.pumpWidget(
        createTestWidget(
          onListTap: () {},
        ),
      );

      // Act
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Assert
      expect(tapCalled, isFalse);
    });

    testWidgets('shows statistics when has items', (tester) async {
      // Arrange
      final items = [
        ShoppingItem(name: 'Item 1', amount: 1, bought: false),
        ShoppingItem(name: 'Item 2', amount: 1, bought: true),
        ShoppingItem(name: 'Item 3', amount: 1, bought: false),
      ];

      final activeList = ShoppingList(
        id: 'test-list',
        name: 'Test List',
        items: items,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        ownerId: 'test-owner-id',
      );

      when(mockViewModel.hasItems).thenReturn(true);
      when(mockViewModel.activeList).thenReturn(activeList);
      when(mockViewModel.totalCount).thenReturn(3);
      when(mockViewModel.checkedCount).thenReturn(1);
      when(mockViewModel.uncheckedCount).thenReturn(2);

      // Act
      await tester.pumpWidget(
        createTestWidget(onListTap: () {}),
      );

      // Assert - Statistics section
      expect(find.text('Totalt'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Köpt'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Kvar'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // Check icons
      expect(find.byIcon(Icons.shopping_basket), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.pending), findsOneWidget);
    });

    testWidgets('hides statistics when no items', (tester) async {
      // Arrange
      when(mockViewModel.hasItems).thenReturn(false);

      // Act
      await tester.pumpWidget(
        createTestWidget(onListTap: () {}),
      );

      // Assert
      expect(find.text('Totalt'), findsNothing);
      expect(find.text('Köpt'), findsNothing);
      expect(find.text('Kvar'), findsNothing);
    });

    testWidgets('updates when viewmodel changes', (tester) async {
      // Arrange
      when(mockViewModel.hasItems).thenReturn(false);

      await tester.pumpWidget(
        createTestWidget(onListTap: () {}),
      );

      expect(find.text('Totalt'), findsNothing);

      // Act - Simulate viewmodel update
      when(mockViewModel.hasItems).thenReturn(true);
      when(mockViewModel.totalCount).thenReturn(5);
      when(mockViewModel.checkedCount).thenReturn(2);
      when(mockViewModel.uncheckedCount).thenReturn(3);

      // Trigger rebuild
      mockViewModel.notifyListeners();
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Totalt'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('has correct container styling', (tester) async {
      // Act
      await tester.pumpWidget(
        createTestWidget(onListTap: () {}),
      );

      // Assert
      final container = tester.widget<Container>(
        find.byType(Container).first,
      );

      expect(container.padding, equals(AppTheme.cardPadding));

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
    });

    testWidgets('animates border when loading', (tester) async {
      // Arrange
      when(mockViewModel.isChangingList).thenReturn(false);

      await tester.pumpWidget(
        createTestWidget(onListTap: () {}),
      );

      // Get initial border
      final initialContainer = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      final initialDecoration = initialContainer.decoration as BoxDecoration;
      final initialBorder = initialDecoration.border as Border;

      // Act - Start loading
      when(mockViewModel.isChangingList).thenReturn(true);
      mockViewModel.notifyListeners();
      await tester.pump();

      // Assert - Border should animate
      final loadingContainer = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      final loadingDecoration = loadingContainer.decoration as BoxDecoration;
      final loadingBorder = loadingDecoration.border as Border;

      expect(loadingBorder.top.width, greaterThan(initialBorder.top.width));
    });

    testWidgets('stat items have correct semantics', (tester) async {
      // Arrange
      when(mockViewModel.hasItems).thenReturn(true);
      when(mockViewModel.totalCount).thenReturn(10);
      when(mockViewModel.checkedCount).thenReturn(3);
      when(mockViewModel.uncheckedCount).thenReturn(7);

      // Act
      await tester.pumpWidget(
        createTestWidget(onListTap: () {}),
      );

      // Assert
      final totalSemantics = tester.getSemantics(
        find
            .ancestor(
              of: find.text('10'),
              matching: find.byType(Column),
            )
            .first,
      );
      expect(totalSemantics.label, contains('Totalt: 10'));
    });

    testWidgets('displays long list names with ellipsis', (tester) async {
      // Arrange
      final activeList = ShoppingList(
        id: 'test-list',
        name:
            'Detta är ett väldigt långt namn för en inköpslista som borde klippas av',
        items: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        ownerId: 'test-owner-id',
      );

      when(mockViewModel.activeList).thenReturn(activeList);

      // Act
      await tester.pumpWidget(
        createTestWidget(onListTap: () {}),
      );

      // Assert
      final text = tester.widget<Text>(
        find.text(activeList.name),
      );
      expect(text.overflow, equals(TextOverflow.ellipsis));
    });
  });
}
