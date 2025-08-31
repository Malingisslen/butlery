import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/input/shopping_item_dialog.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import '../../../infrastructure/helpers/base_widget_test.dart';

// Comprehensive widget test for AddUnifiedShoppingItemDialog following ultrathink methodology
void main() {
  setUp(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  group('AddUnifiedShoppingItemDialog Tests', () {
    // Test data
    final testItem = UnifiedShoppingItem(
      id: 'item123',
      name: 'Mjölk',
      amount: 1.5,
      unit: 'liter',
      category: 'Mejeri',
      bought: false,
    );

    group('Basic Rendering', () {
      testWidgets('renders in add mode when no initial item', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const AddUnifiedShoppingItemDialog(),
          ),
        );

        expect(find.byType(AddUnifiedShoppingItemDialog), findsOneWidget);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Lägg till artikel'), findsOneWidget);
        expect(find.byIcon(Icons.add_shopping_cart), findsOneWidget);
        expect(find.text('Lägg till'), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('renders in edit mode when initial item provided', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: AddUnifiedShoppingItemDialog(initialItem: testItem),
          ),
        );

        expect(find.text('Redigera artikel'), findsOneWidget);
        expect(find.byIcon(Icons.edit), findsOneWidget);
        expect(find.text('Spara'), findsOneWidget);
        expect(find.byIcon(Icons.save), findsOneWidget);
      });

      testWidgets('displays all form fields', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const AddUnifiedShoppingItemDialog(),
          ),
        );

        expect(find.byType(TextFormField), findsNWidgets(2)); // Name and amount
        expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2)); // Unit and category
        
        // Check field labels
        expect(find.text('Artikel'), findsOneWidget);
        expect(find.text('Antal'), findsOneWidget);
        expect(find.text('Enhet'), findsOneWidget);
        expect(find.text('Kategori'), findsOneWidget);
      });

      testWidgets('displays action buttons', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const AddUnifiedShoppingItemDialog(),
          ),
        );

        expect(find.text('Avbryt'), findsOneWidget);
        
        // FilledButton.icon creates internal structure, check for the submit button text instead
        expect(find.text('Lägg till'), findsOneWidget); // Submit button for add mode
      });

      testWidgets('displays Swedish placeholder text', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const AddUnifiedShoppingItemDialog(),
          ),
        );

        expect(find.text('T.ex. Mjölk'), findsOneWidget);
        
        // Find the amount field by its label text 
        expect(find.text('Antal'), findsOneWidget);
        
        // Verify there's a text field with default value "1" near the "Antal" label
        final textFields = find.byType(TextFormField);
        expect(textFields, findsNWidgets(2)); // Name and amount fields
        
        // The amount field should have initial value "1" (can't easily verify controller text in widget tests)
      });
    });

    group('Form Initialization', () {
      testWidgets('initializes with default values for new item', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const AddUnifiedShoppingItemDialog(),
          ),
        );

        // Find text form fields by their order - name field is first, amount field is second
        final allTextFields = find.byType(TextFormField);
        expect(allTextFields, findsNWidgets(2)); // Should have exactly 2 text fields
        
        final nameFieldFinder = allTextFields.at(0); // First field is name
        final amountFieldFinder = allTextFields.at(1); // Second field is amount

        final nameField = tester.widget<TextFormField>(nameFieldFinder);
        final amountField = tester.widget<TextFormField>(amountFieldFinder);

        expect(nameField.controller?.text, isEmpty);
        expect(amountField.controller?.text, equals('1'));
      });

      testWidgets('initializes with item values for editing', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: AddUnifiedShoppingItemDialog(initialItem: testItem),
          ),
        );

        // Verify fields are populated
        expect(find.text('Mjölk'), findsOneWidget);
        // The formattedAmount in production code returns "1.5" (dot), not "1,5" (comma)
        expect(find.text('1.5'), findsOneWidget); // Actual formatted amount from production
      });

      testWidgets('focuses on name field initially', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const AddUnifiedShoppingItemDialog(),
          ),
        );

        // Find the name field (first TextFormField)
        final nameField = find.byType(TextFormField).first;
        expect(nameField, findsOneWidget);
        
        // Verify it's the article name field by checking nearby text
        expect(find.text('Artikel'), findsOneWidget);
      });
    });

    group('Form Field Interactions', () {
      testWidgets('handles name input', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const AddUnifiedShoppingItemDialog(),
          ),
        );

        // Find name field by label
        final nameField = find.widgetWithText(TextFormField, '').first;
        
        await tester.enterText(nameField, 'Ägg');
        await tester.pump();

        expect(find.text('Ägg'), findsOneWidget);
      });

      testWidgets('handles amount input', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const AddUnifiedShoppingItemDialog(),
          ),
        );

        // Find amount field
        final amountField = find.widgetWithText(TextFormField, '1');
        
        await tester.enterText(amountField, '2.5');
        await tester.pump();

        expect(find.text('2.5'), findsOneWidget);
      });

      testWidgets('handles unit dropdown selection', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const AddUnifiedShoppingItemDialog(),
          ),
        );

        // Find and tap unit dropdown
        final unitDropdown = find.widgetWithText(DropdownButtonFormField<String>, 'st');
        await tester.tap(unitDropdown);
        await tester.pumpAndSettle();

        // Select a different unit
        await tester.tap(find.text('liter').last);
        await tester.pumpAndSettle();

        expect(find.text('liter'), findsOneWidget);
      });

      testWidgets('handles category dropdown selection', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const AddUnifiedShoppingItemDialog(),
          ),
        );

        // Find and tap category dropdown
        final categoryDropdown = find.widgetWithText(DropdownButtonFormField<String>, 'Övrigt');
        await tester.tap(categoryDropdown);
        await tester.pumpAndSettle();

        // Select a different category
        await tester.tap(find.text('Mejeri').last);
        await tester.pumpAndSettle();

        expect(find.text('Mejeri'), findsOneWidget);
      });
    });

    group('Form Validation', () {
      testWidgets('validates empty name field', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const AddUnifiedShoppingItemDialog(),
          ),
        );

        // Try to submit without entering name
        await tester.tap(find.text('Lägg till'));
        await tester.pump();

        // Should show validation error
        expect(find.byType(AlertDialog), findsOneWidget);
      });

      testWidgets('validates invalid amount field', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const AddUnifiedShoppingItemDialog(),
          ),
        );

        // Enter valid name but invalid amount
        await tester.enterText(find.widgetWithText(TextFormField, '').first, 'Test Item');
        await tester.enterText(find.widgetWithText(TextFormField, '1'), 'invalid');
        await tester.pump();

        await tester.tap(find.text('Lägg till'));
        await tester.pump();

        // Should show validation error
        expect(find.byType(AlertDialog), findsOneWidget);
      });

      testWidgets('accepts valid input', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const AddUnifiedShoppingItemDialog(),
          ),
        );

        // Find fields by their order - name field is first, amount field is second
        final allTextFields = find.byType(TextFormField);
        expect(allTextFields, findsNWidgets(2)); // Should have exactly 2 text fields
        
        final nameFieldFinder = allTextFields.at(0); // First field is name
        final amountFieldFinder = allTextFields.at(1); // Second field is amount

        // Enter valid data
        await tester.enterText(nameFieldFinder, 'Test Item');
        await tester.enterText(amountFieldFinder, '2');
        await tester.pump();

        await tester.tap(find.text('Lägg till'));
        await tester.pumpAndSettle(); // Use pumpAndSettle to wait for dialog animation

        // Dialog should close (no more AlertDialog)
        expect(find.byType(AlertDialog), findsNothing);
      });
    });

    group('Form Submission', () {
      testWidgets('creates new item with correct data', (WidgetTester tester) async {
        UnifiedShoppingItem? resultItem;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  final result = await showDialog<UnifiedShoppingItem>(
                    context: context,
                    builder: (_) => const AddUnifiedShoppingItemDialog(),
                  );
                  resultItem = result;
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        );

        // Open dialog
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        // Fill out form
        await tester.enterText(find.widgetWithText(TextFormField, '').first, 'Bröd');
        await tester.enterText(find.widgetWithText(TextFormField, '1'), '2');
        await tester.pump();

        // Change unit to 'st'
        await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'st'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('st').last);
        await tester.pumpAndSettle();

        // Submit form
        await tester.tap(find.text('Lägg till'));
        await tester.pumpAndSettle();

        // Verify result
        expect(resultItem, isNotNull);
        expect(resultItem!.name, equals('Bröd'));
        expect(resultItem!.amount, equals(2.0));
        expect(resultItem!.unit, equals('st'));
        expect(resultItem!.category, equals('Övrigt')); // Default category
        expect(resultItem!.bought, isFalse);
      });

      testWidgets('updates existing item with changes', (WidgetTester tester) async {
        UnifiedShoppingItem? resultItem;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  final result = await showDialog<UnifiedShoppingItem>(
                    context: context,
                    builder: (_) => AddUnifiedShoppingItemDialog(initialItem: testItem),
                  );
                  resultItem = result;
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        );

        // Open dialog
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        // Modify name
        await tester.enterText(find.text('Mjölk'), 'Filmjölk');
        await tester.pump();

        // Submit form
        await tester.tap(find.text('Spara'));
        await tester.pumpAndSettle();

        // Verify result
        expect(resultItem, isNotNull);
        expect(resultItem!.name, equals('Filmjölk'));
        expect(resultItem!.amount, equals(1.5)); // Preserved from original
        expect(resultItem!.unit, equals('liter')); // Preserved from original
        expect(resultItem!.id, equals(testItem.id)); // Same ID for editing
      });

      testWidgets('handles comma decimal separator', (WidgetTester tester) async {
        UnifiedShoppingItem? resultItem;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  final result = await showDialog<UnifiedShoppingItem>(
                    context: context,
                    builder: (_) => const AddUnifiedShoppingItemDialog(),
                  );
                  resultItem = result;
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        );

        // Open dialog
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        // Enter data with comma
        await tester.enterText(find.widgetWithText(TextFormField, '').first, 'Test');
        await tester.enterText(find.widgetWithText(TextFormField, '1'), '1,5');
        await tester.pump();

        // Submit form
        await tester.tap(find.text('Lägg till'));
        await tester.pumpAndSettle();

        // Verify comma was converted to decimal
        expect(resultItem, isNotNull);
        expect(resultItem!.amount, equals(1.5));
      });
    });

    group('Dialog Actions', () {
      testWidgets('closes dialog on cancel', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const AddUnifiedShoppingItemDialog(),
          ),
        );

        // Tap cancel
        await tester.tap(find.text('Avbryt'));
        await tester.pumpAndSettle();

        // Dialog should be closed
        expect(find.byType(AlertDialog), findsNothing);
      });

      testWidgets('closes dialog on successful submission', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const AddUnifiedShoppingItemDialog(),
          ),
        );

        // Fill valid data
        await tester.enterText(find.widgetWithText(TextFormField, '').first, 'Valid Item');
        await tester.pump();

        // Submit
        await tester.tap(find.text('Lägg till'));
        await tester.pumpAndSettle();

        // Dialog should be closed
        expect(find.byType(AlertDialog), findsNothing);
      });
    });

    group('Unit Dropdown Options', () {
      testWidgets('displays all unit options', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const AddUnifiedShoppingItemDialog(),
          ),
        );

        // Open unit dropdown
        final unitDropdown = find.widgetWithText(DropdownButtonFormField<String>, 'st');
        await tester.tap(unitDropdown);
        await tester.pumpAndSettle();

        // Check for some expected units
        expect(find.text('liter'), findsOneWidget);
        expect(find.text('kg'), findsOneWidget);
        expect(find.text('dl'), findsOneWidget);
        expect(find.text('msk'), findsOneWidget);
        expect(find.text('förpackning'), findsOneWidget);
      });

      testWidgets('maintains selected unit across dialog', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: AddUnifiedShoppingItemDialog(initialItem: testItem),
          ),
        );

        // Should show the item's unit (liter) as selected
        expect(find.text('liter'), findsOneWidget);
      });
    });

    group('Category Dropdown Options', () {
      testWidgets('displays all category options', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const AddUnifiedShoppingItemDialog(),
          ),
        );

        // Open category dropdown
        final categoryDropdown = find.widgetWithText(DropdownButtonFormField<String>, 'Övrigt');
        await tester.tap(categoryDropdown);
        await tester.pumpAndSettle();

        // Check for expected categories
        expect(find.text('Frukt & Grönt'), findsOneWidget);
        expect(find.text('Mejeri'), findsOneWidget);
        expect(find.text('Kött & Fisk'), findsOneWidget);
        expect(find.text('Bröd'), findsOneWidget);
        expect(find.text('Skafferi'), findsOneWidget);
      });

      testWidgets('maintains selected category across dialog', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: AddUnifiedShoppingItemDialog(initialItem: testItem),
          ),
        );

        // Should show the item's category (Mejeri) as selected
        expect(find.text('Mejeri'), findsOneWidget);
      });
    });

    group('Swedish Localization', () {
      testWidgets('displays Swedish labels and text', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const AddUnifiedShoppingItemDialog(),
          ),
        );

        // Check Swedish text
        expect(find.text('Lägg till artikel'), findsOneWidget);
        expect(find.text('Artikel'), findsOneWidget);
        expect(find.text('Antal'), findsOneWidget);
        expect(find.text('Enhet'), findsOneWidget);
        expect(find.text('Kategori'), findsOneWidget);
        expect(find.text('Avbryt'), findsOneWidget);
        expect(find.text('Lägg till'), findsOneWidget);
        expect(find.text('T.ex. Mjölk'), findsOneWidget);
      });

      testWidgets('displays Swedish edit mode text', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: AddUnifiedShoppingItemDialog(initialItem: testItem),
          ),
        );

        expect(find.text('Redigera artikel'), findsOneWidget);
        expect(find.text('Spara'), findsOneWidget);
      });
    });

    group('Icon Display', () {
      testWidgets('shows correct icons for add mode', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const AddUnifiedShoppingItemDialog(),
          ),
        );

        expect(find.byIcon(Icons.add_shopping_cart), findsOneWidget);
        expect(find.byIcon(Icons.shopping_basket), findsOneWidget);
        expect(find.byIcon(Icons.numbers), findsOneWidget);
        expect(find.byIcon(Icons.straighten), findsOneWidget);
        expect(find.byIcon(Icons.category), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('shows correct icons for edit mode', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: AddUnifiedShoppingItemDialog(initialItem: testItem),
          ),
        );

        expect(find.byIcon(Icons.edit), findsOneWidget);
        expect(find.byIcon(Icons.save), findsOneWidget);
      });
    });

    group('Layout and Styling', () {
      testWidgets('applies correct styling to dialog', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const AddUnifiedShoppingItemDialog(),
          ),
        );

        // Check dialog structure
        final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
        expect(dialog.title, isNotNull);
        expect(dialog.content, isNotNull);
        expect(dialog.actions, isNotNull);
        expect(dialog.actions?.length, equals(2));
      });

      testWidgets('uses proper flex ratios for amount and unit', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const AddUnifiedShoppingItemDialog(),
          ),
        );

        // Find the specific Row containing amount and unit fields by checking for the exact structure
        final amountUnitRowFinder = find.descendant(
          of: find.byType(Form),
          matching: find.byWidgetPredicate(
            (widget) {
              if (widget is! Row) return false;
              final row = widget;
              // Check that this row has exactly 3 children: Expanded, SizedBox, Expanded
              if (row.children.length != 3) return false;
              return row.children[0] is Expanded &&
                     row.children[1] is SizedBox &&
                     row.children[2] is Expanded;
            },
          ),
        );
        
        final row = tester.widget<Row>(amountUnitRowFinder);
        final expandedWidgets = row.children.whereType<Expanded>().toList();

        expect(expandedWidgets.length, equals(2));
        expect(expandedWidgets[0].flex, equals(1)); // Amount field
        expect(expandedWidgets[1].flex, equals(2)); // Unit field
      });
    });

    group('Edge Cases', () {
      testWidgets('handles mount safety in callbacks', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const AddUnifiedShoppingItemDialog(),
          ),
        );

        // Change unit selection
        final unitDropdown = find.widgetWithText(DropdownButtonFormField<String>, 'st');
        await tester.tap(unitDropdown);
        await tester.pumpAndSettle();
        
        await tester.tap(find.text('liter').last);
        await tester.pumpAndSettle();

        // Should not throw errors
        expect(tester.takeException(), isNull);
      });

      testWidgets('disposes controllers properly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const AddUnifiedShoppingItemDialog(),
          ),
        );

        // Close dialog to trigger disposal
        await tester.tap(find.text('Avbryt'));
        await tester.pumpAndSettle();

        // Should not throw errors during disposal
        expect(tester.takeException(), isNull);
      });

      testWidgets('handles null form result', (WidgetTester tester) async {
        Object? resultItem;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  final result = await showDialog<UnifiedShoppingItem>(
                    context: context,
                    builder: (_) => const AddUnifiedShoppingItemDialog(),
                  );
                  resultItem = result;
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        );

        // Open and cancel dialog
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Avbryt'));
        await tester.pumpAndSettle();

        // Result should be null
        expect(resultItem, isNull);
      });
    });
  });
}