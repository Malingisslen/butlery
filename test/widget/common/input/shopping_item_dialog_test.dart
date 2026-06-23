// test/widget/common/input/shopping_item_dialog_test.dart
// Widget tests for AddUnifiedShoppingItemDialog — rewritten to match current production widget

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/input/shopping_item_dialog.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import '../../../infrastructure/helpers/base_widget_test.dart';

void main() {
  setUp(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  // Localized MaterialApp wrapper for dialog tests
  Widget createDialogApp({Widget? child}) {
    return MaterialApp(
      locale: const Locale('sv'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: child ?? const Scaffold(body: AddUnifiedShoppingItemDialog()),
    );
  }

  // Helper to open dialog via showDialog (for result capture tests)
  Widget createDialogLauncher({
    UnifiedShoppingItem? initialItem,
    void Function(UnifiedShoppingItem?)? onResult,
  }) {
    return MaterialApp(
      locale: const Locale('sv'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              final result = await showDialog<UnifiedShoppingItem>(
                context: context,
                builder: (_) =>
                    AddUnifiedShoppingItemDialog(initialItem: initialItem),
              );
              onResult?.call(result);
            },
            child: const Text('Open Dialog'),
          ),
        ),
      ),
    );
  }

  group('AddUnifiedShoppingItemDialog Tests', () {
    // Use correct category constant — production stores 'other', not 'Mejeri'
    final testItem = UnifiedShoppingItem(
      id: 'item123',
      name: 'Mj\u00f6lk',
      amount: 1.5,
      unit: 'liter',
      category: ShoppingCategory.dairy,
      bought: false,
    );

    group('Basic Rendering', () {
      testWidgets('renders add mode when no initial item', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createDialogApp());
        await tester.pumpAndSettle();

        expect(find.byType(AddUnifiedShoppingItemDialog), findsOneWidget);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byIcon(Icons.add_shopping_cart), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('renders edit mode when initial item provided', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createDialogApp(
            child: Scaffold(
              body: AddUnifiedShoppingItemDialog(initialItem: testItem),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.edit), findsOneWidget);
        expect(find.byIcon(Icons.save), findsOneWidget);
      });

      testWidgets('displays form field icons', (WidgetTester tester) async {
        await tester.pumpWidget(createDialogApp());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.shopping_basket), findsOneWidget);
        expect(find.byIcon(Icons.numbers), findsOneWidget);
        expect(find.byIcon(Icons.straighten), findsOneWidget);
        expect(find.byIcon(Icons.category), findsOneWidget);
      });

      testWidgets('has two action buttons', (WidgetTester tester) async {
        await tester.pumpWidget(createDialogApp());
        await tester.pumpAndSettle();

        final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
        expect(dialog.actions, isNotNull);
        expect(dialog.actions!.length, equals(2));
      });
    });

    group('Form Initialization', () {
      testWidgets('empty name and default amount for new item', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createDialogApp());
        await tester.pumpAndSettle();

        // StyledInput wraps TextFormField — find them
        final allTextFields = find.byType(TextFormField);
        expect(allTextFields, findsNWidgets(2));

        final nameField = tester.widget<TextFormField>(allTextFields.at(0));
        final amountField = tester.widget<TextFormField>(allTextFields.at(1));

        expect(nameField.controller?.text, isEmpty);
        expect(amountField.controller?.text, equals('1'));
      });

      testWidgets('populates fields for editing', (WidgetTester tester) async {
        await tester.pumpWidget(
          createDialogApp(
            child: Scaffold(
              body: AddUnifiedShoppingItemDialog(initialItem: testItem),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Mj\u00f6lk'), findsOneWidget);
        expect(find.text('1.5'), findsOneWidget);
      });
    });

    group('Form Interactions', () {
      testWidgets('handles name input', (WidgetTester tester) async {
        await tester.pumpWidget(createDialogApp());
        await tester.pumpAndSettle();

        final nameField = find.byType(TextFormField).first;
        await tester.enterText(nameField, '\u00c4gg');
        await tester.pump();

        expect(find.text('\u00c4gg'), findsOneWidget);
      });

      testWidgets('handles amount input', (WidgetTester tester) async {
        await tester.pumpWidget(createDialogApp());
        await tester.pumpAndSettle();

        final amountField = find.byType(TextFormField).at(1);
        await tester.enterText(amountField, '2.5');
        await tester.pump();

        expect(find.text('2.5'), findsOneWidget);
      });

      testWidgets('handles unit dropdown selection', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createDialogApp());
        await tester.pumpAndSettle();

        // The unit dropdown has 'st' as its initial value display
        // DropdownButtonFormField shows items with 'dropdown' display text
        final unitDropdowns = find.byType(DropdownButtonFormField<String>);
        expect(unitDropdowns, findsNWidgets(2));

        // Tap first dropdown (unit)
        await tester.tap(unitDropdowns.first);
        await tester.pumpAndSettle();

        // Select 'liter' from the dropdown
        await tester.tap(find.text('liter').last);
        await tester.pumpAndSettle();

        // Should not throw
        expect(tester.takeException(), isNull);
      });
    });

    group('Form Validation', () {
      testWidgets('prevents submit with empty name', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createDialogApp());
        await tester.pumpAndSettle();

        // Find and tap the submit button (ActionButtons.primaryButton)
        // It contains an Icon(Icons.add) — find the button's parent
        final addIcon = find.byIcon(Icons.add);
        await tester.tap(addIcon);
        await tester.pump();

        // Dialog should still be visible (validation failed)
        expect(find.byType(AlertDialog), findsOneWidget);
      });

      testWidgets('accepts valid input and closes dialog', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createDialogApp());
        await tester.pumpAndSettle();

        // Enter valid name
        final nameField = find.byType(TextFormField).first;
        await tester.enterText(nameField, 'Test Item');
        await tester.pump();

        // Submit
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        // Dialog should close
        expect(find.byType(AlertDialog), findsNothing);
      });
    });

    group('Form Submission', () {
      testWidgets('creates new item with correct data', (
        WidgetTester tester,
      ) async {
        UnifiedShoppingItem? resultItem;

        await tester.pumpWidget(
          createDialogLauncher(
            onResult: (item) => resultItem = item,
          ),
        );
        await tester.pumpAndSettle();

        // Open dialog
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        // Fill out form
        final nameField = find.byType(TextFormField).first;
        final amountField = find.byType(TextFormField).at(1);
        await tester.enterText(nameField, 'Br\u00f6d');
        await tester.enterText(amountField, '2');
        await tester.pump();

        // Submit
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        expect(resultItem, isNotNull);
        expect(resultItem!.name, equals('Br\u00f6d'));
        expect(resultItem!.amount, equals(2.0));
        expect(resultItem!.unit, equals('st'));
        expect(resultItem!.category, equals(ShoppingCategory.other));
        expect(resultItem!.bought, isFalse);
      });

      testWidgets('updates existing item preserving unchanged fields', (
        WidgetTester tester,
      ) async {
        UnifiedShoppingItem? resultItem;

        await tester.pumpWidget(
          createDialogLauncher(
            initialItem: testItem,
            onResult: (item) => resultItem = item,
          ),
        );
        await tester.pumpAndSettle();

        // Open dialog
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        // Modify name
        final nameField = find.text('Mj\u00f6lk');
        await tester.enterText(nameField, 'Filmj\u00f6lk');
        await tester.pump();

        // Submit via save icon
        await tester.tap(find.byIcon(Icons.save));
        await tester.pumpAndSettle();

        expect(resultItem, isNotNull);
        expect(resultItem!.name, equals('Filmj\u00f6lk'));
        expect(resultItem!.amount, equals(1.5));
        expect(resultItem!.unit, equals('liter'));
        expect(resultItem!.id, equals(testItem.id));
      });

      testWidgets('handles comma decimal separator', (
        WidgetTester tester,
      ) async {
        UnifiedShoppingItem? resultItem;

        await tester.pumpWidget(
          createDialogLauncher(
            onResult: (item) => resultItem = item,
          ),
        );
        await tester.pumpAndSettle();

        // Open dialog
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        // Enter data with comma
        final nameField = find.byType(TextFormField).first;
        final amountField = find.byType(TextFormField).at(1);
        await tester.enterText(nameField, 'Test');
        await tester.enterText(amountField, '1,5');
        await tester.pump();

        // Submit
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        expect(resultItem, isNotNull);
        expect(resultItem!.amount, equals(1.5));
      });
    });

    group('Dialog Actions', () {
      testWidgets('cancel returns null result', (WidgetTester tester) async {
        UnifiedShoppingItem? resultItem;
        bool callbackFired = false;

        await tester.pumpWidget(
          createDialogLauncher(
            onResult: (item) {
              resultItem = item;
              callbackFired = true;
            },
          ),
        );
        await tester.pumpAndSettle();

        // Open dialog
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        // Find the ActionButtons.secondaryButton (cancel) — it's the first action button
        // The cancel button uses ActionButtons.secondaryButton which renders an ElevatedButton
        // Just find by the dialog actions and tap the first one
        // Production cancel button calls Navigator.pop(context) without result
        // Find the cancel action — it's a widget in the actions row
        final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
        expect(dialog.actions!.length, equals(2));

        // Both ActionButtons.secondaryButton and .primaryButton render as ElevatedButton
        // The cancel button is the first ElevatedButton in the dialog actions
        // Find it by locating the first ElevatedButton within the dialog
        final elevatedButtons = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(ElevatedButton),
        );
        // First is cancel (secondary), second is submit (primary with icon)
        await tester.tap(elevatedButtons.first);
        await tester.pumpAndSettle();

        expect(callbackFired, isTrue);
        expect(resultItem, isNull);
      });
    });

    group('Layout and Styling', () {
      testWidgets('amount and unit fields use correct flex ratios', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createDialogApp());
        await tester.pumpAndSettle();

        // Find the Row containing Expanded children with flex 1 and 2
        final amountUnitRow = find.byWidgetPredicate((widget) {
          if (widget is! Row) return false;
          if (widget.children.length != 3) return false;
          return widget.children[0] is Expanded &&
              widget.children[1] is SizedBox &&
              widget.children[2] is Expanded;
        });

        final row = tester.widget<Row>(amountUnitRow);
        final expanded = row.children.whereType<Expanded>().toList();

        expect(expanded.length, equals(2));
        expect(expanded[0].flex, equals(1));
        expect(expanded[1].flex, equals(2));
      });
    });

    group('Edge Cases', () {
      testWidgets('handles mount safety in dropdown callbacks', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createDialogApp());
        await tester.pumpAndSettle();

        // Open and select from unit dropdown
        final unitDropdown = find.byType(DropdownButtonFormField<String>).first;
        await tester.tap(unitDropdown);
        await tester.pumpAndSettle();

        await tester.tap(find.text('liter').last);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('disposes controllers without error', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(createDialogApp());
        await tester.pumpAndSettle();

        // Close dialog to trigger dispose — cancel is first ElevatedButton
        final elevatedButtons = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(ElevatedButton),
        );
        await tester.tap(elevatedButtons.first);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    });
  });
}
