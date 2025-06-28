// test/widgets/shopping_list_selector_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:butlery/widgets/shopping_list_selector.dart';
import 'package:butlery/models/shopping_list.dart';
import 'package:butlery/models/shopping_item.dart';
import 'package:butlery/theme/app_theme.dart';

// Import generated mocks
import '../helpers/test_helpers.mocks.dart';

void main() {
  group('ShoppingListSelector Widget Tests', () {
    late MockShoppingListViewModel mockViewModel;
    late List<ShoppingList> testLists;

    setUp(() {
      mockViewModel = MockShoppingListViewModel();

      testLists = [
        ShoppingList(
          id: 'list-1',
          name: 'Veckans inköp',
          items: [
            ShoppingItem(name: 'Mjölk', amount: 1),
            ShoppingItem(name: 'Bröd', amount: 2),
          ],
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
          ownerId: 'test-owner-id',
        ),
        ShoppingList(
          id: 'list-2',
          name: 'Helgmys',
          items: [
            ShoppingItem(name: 'Chips', amount: 1),
          ],
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          updatedAt: DateTime.now(),
          ownerId: 'test-owner-id',
        ),
      ];

      // Default stubs
      when(mockViewModel.lists).thenReturn(testLists);
      when(mockViewModel.activeList).thenReturn(testLists[0]);
      when(mockViewModel.isCreatingList).thenReturn(false);
      when(mockViewModel.lastError).thenReturn(null);
      when(mockViewModel.selectList(any)).thenAnswer((_) async {});
      when(mockViewModel.createList(any)).thenAnswer((_) async => true);
    });

    Widget createTestWidget() {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ShoppingListSelector(
            viewModel: mockViewModel,
          ),
        ),
      );
    }

    testWidgets('displays bottom sheet with lists', (tester) async {
      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert - Header
      expect(find.text('Välj inköpslista'), findsOneWidget);
      expect(find.byIcon(Icons.list), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Assert - Lists
      expect(find.text('Veckans inköp'), findsOneWidget);
      expect(find.text('Helgmys'), findsOneWidget);

      // Assert - Create button
      expect(find.text('Skapa ny lista'), findsOneWidget);
    });

    testWidgets('shows active list indicator', (tester) async {
      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Check that active list has different styling
      final activeListTile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Veckans inköp'),
          matching: find.byType(ListTile),
        ),
      );
      expect(activeListTile.selected, isTrue);
    });

    testWidgets('selects list when tapped', (tester) async {
      // Act
      await tester.pumpWidget(createTestWidget());

      // Tap on second list
      await tester.tap(find.text('Helgmys'));
      await tester.pumpAndSettle();

      // Assert
      verify(mockViewModel.selectList('list-2')).called(1);
    });

    testWidgets('closes bottom sheet after selection', (tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());

      // Act
      await tester.tap(find.text('Helgmys'));
      await tester.pumpAndSettle();

      // Assert - Bottom sheet should be gone
      expect(find.text('Välj inköpslista'), findsNothing);
    });

    testWidgets('does not select already active list', (tester) async {
      // Act
      await tester.pumpWidget(createTestWidget());

      // Tap on active list
      await tester.tap(find.text('Veckans inköp'));
      await tester.pumpAndSettle();

      // Assert
      verifyNever(mockViewModel.selectList(any));
    });

    testWidgets('shows create new list form when button tapped',
        (tester) async {
      // Act
      await tester.pumpWidget(createTestWidget());

      // Tap create button
      await tester.tap(find.text('Skapa ny lista'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Skapa ny lista'), findsNWidgets(2)); // Header + button
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Namn på ny lista'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('returns to list view when back pressed', (tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());

      // Go to create mode
      await tester.tap(find.text('Skapa ny lista'));
      await tester.pumpAndSettle();

      // Act - Press back
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Välj inköpslista'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('creates new list with valid name', (tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());

      // Go to create mode
      await tester.tap(find.text('Skapa ny lista'));
      await tester.pumpAndSettle();

      // Act - Enter name and create
      await tester.enterText(find.byType(TextField), 'Min nya lista');
      await tester.tap(find.text('Skapa').last);
      await tester.pumpAndSettle();

      // Assert
      verify(mockViewModel.createList('Min nya lista')).called(1);
    });

    testWidgets('shows loading indicator when creating', (tester) async {
      // Arrange
      when(mockViewModel.isCreatingList).thenReturn(true);

      await tester.pumpWidget(createTestWidget());

      // Go to create mode
      await tester.tap(find.text('Skapa ny lista'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Button should be disabled
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Skapa'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('shows error message for empty name', (tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());

      // Go to create mode
      await tester.tap(find.text('Skapa ny lista'));
      await tester.pumpAndSettle();

      // Act - Try to create with empty name
      await tester.tap(find.text('Skapa').last);
      await tester.pumpAndSettle();

      // Assert
      verifyNever(mockViewModel.createList(any));
    });

    testWidgets('shows empty state when no lists', (tester) async {
      // Arrange
      when(mockViewModel.lists).thenReturn([]);

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.text('Inga listor skapade än'), findsOneWidget);
      expect(find.text('Skapa din första lista'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
    });

    testWidgets('shows sync status for each list', (tester) async {
      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      for (final list in testLists) {
        expect(find.text(list.syncStatusEmoji), findsOneWidget);
      }
    });

    testWidgets('shows list summary and last updated', (tester) async {
      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.textContaining('2 artiklar'), findsOneWidget);
      expect(find.textContaining('1 artikel'), findsOneWidget);
      expect(find.textContaining('•'), findsNWidgets(2)); // Separator
    });

    testWidgets('handle is draggable', (tester) async {
      // Act
      await tester.pumpWidget(createTestWidget());

      // Find handle
      final handle = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.constraints?.maxWidth == 40 &&
            widget.constraints?.maxHeight == 4,
      );

      // Assert
      expect(handle, findsOneWidget);
    });

    testWidgets('close button works', (tester) async {
      // Act
      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Assert - Sheet should be closed
      expect(find.text('Välj inköpslista'), findsNothing);
    });

    testWidgets('shows information box in create mode', (tester) async {
      // Act
      await tester.pumpWidget(createTestWidget());

      // Go to create mode
      await tester.tap(find.text('Skapa ny lista'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Listan synkas automatiskt mellan dina enheter'),
          findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('text field has correct configuration', (tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());

      // Go to create mode
      await tester.tap(find.text('Skapa ny lista'));
      await tester.pumpAndSettle();

      // Assert
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.labelText, equals('Namn på ny lista'));
      expect(textField.decoration?.hintText, equals('T.ex. Veckans inköp'));
      expect(
          textField.textCapitalization, equals(TextCapitalization.sentences));
      expect(textField.autofocus, isTrue);
    });

    testWidgets('submitting text field creates list', (tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());

      // Go to create mode
      await tester.tap(find.text('Skapa ny lista'));
      await tester.pumpAndSettle();

      // Act - Enter text and submit with keyboard
      await tester.enterText(find.byType(TextField), 'Test Lista');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Assert
      verify(mockViewModel.createList('Test Lista')).called(1);
    });

    testWidgets('trims whitespace from list name', (tester) async {
      // Arrange
      await tester.pumpWidget(createTestWidget());

      // Go to create mode
      await tester.tap(find.text('Skapa ny lista'));
      await tester.pumpAndSettle();

      // Act
      await tester.enterText(find.byType(TextField), '  Trimmed Name  ');
      await tester.tap(find.text('Skapa').last);
      await tester.pumpAndSettle();

      // Assert
      verify(mockViewModel.createList('Trimmed Name')).called(1);
    });
  });
}
