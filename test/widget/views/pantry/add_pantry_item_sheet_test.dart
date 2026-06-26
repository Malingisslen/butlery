/// BUT-1344 COOK-07: behavioral widget tests for AddPantryItemSheet.
///
/// Proves three user-visible contracts:
///   1. Selecting an autocomplete suggestion routes the submit to addItemFromIngredient.
///   2. Typing a raw name (no suggestion chosen) routes to addItemFromText.
///   3. Opening in edit mode pre-populates the form and routes submit to updateItem.
///
/// These are not structural tests — they verify the *routing decision* the
/// sheet makes in _submit(), which is the domain invariant: the right VM
/// method must be called so the item lands in the correct Firestore collection.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';
import 'package:butlery/views/pantry/add_pantry_item_sheet.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/helpers/base_widget_test.dart';

class _MockPantryViewModel extends Mock implements PantryViewModel {}

void main() {
  setUpAll(() async {
    await BaseWidgetTest.setupWidget();
    registerFallbackValue(
      const IngredientData(
        id: 'fallback',
        swedish: 'fallback',
        english: 'fallback',
        group: 'test',
        properties: {},
      ),
    );
    registerFallbackValue(PantryLocation.pantry);
    registerFallbackValue(
      PantryItem(
        id: 'fallback',
        ingredientName: 'fallback',
        quantity: 1,
        unit: 'st',
        location: PantryLocation.pantry,
        addedAt: DateTime(2026, 1, 1),
      ),
    );
  });

  late _MockPantryViewModel vm;

  setUp(() {
    vm = _MockPantryViewModel();
    when(() => vm.searchResults).thenReturn(const []);
    when(() => vm.isLoading).thenReturn(false);
    when(() => vm.error).thenReturn(null);
    when(() => vm.hasError).thenReturn(false);
    when(() => vm.searchIngredient(any())).thenReturn(null);
    when(
      () => vm.addItemFromIngredient(
        any(),
        quantity: any(named: 'quantity'),
        unit: any(named: 'unit'),
        location: any(named: 'location'),
        expiryDate: any(named: 'expiryDate'),
        note: any(named: 'note'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => vm.addItemFromText(
        any(),
        quantity: any(named: 'quantity'),
        unit: any(named: 'unit'),
        location: any(named: 'location'),
        expiryDate: any(named: 'expiryDate'),
        note: any(named: 'note'),
      ),
    ).thenAnswer((_) async {});
    when(() => vm.updateItem(any())).thenAnswer((_) async {});
  });

  Widget buildSheet({PantryItem? existingItem}) {
    return createLocalizedTestApp(
      child: ChangeNotifierProvider<PantryViewModel>.value(
        value: vm,
        child: Scaffold(
          body: AddPantryItemSheet(existingItem: existingItem),
        ),
      ),
    );
  }

  /// Pumps the sheet pushed as a real modal route, so `Navigator.pop()` actually
  /// removes it from the tree — required for the dismiss-on-success /
  /// stays-open-on-failure assertions to be load-bearing rather than vacuous.
  Future<void> pumpRoutedSheet(
    WidgetTester tester, {
    PantryItem? existingItem,
  }) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: ChangeNotifierProvider<PantryViewModel>.value(
          value: vm,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) =>
                        ChangeNotifierProvider<PantryViewModel>.value(
                          value: vm,
                          child: AddPantryItemSheet(existingItem: existingItem),
                        ),
                  ),
                  child: const Text('open-sheet'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open-sheet'));
    await tester.pumpAndSettle();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Test 1: autocomplete pick → addItemFromIngredient
  //
  // Intent: when a user picks a suggestion from the autocomplete list, the
  // sheet must call addItemFromIngredient (not addItemFromText), so the item
  // is linked to the canonical ingredient and its allergen / storage data
  // is correctly set.
  //
  // Would fail if: _submit() dropped the `_selectedIngredient != null` branch.
  // Won't break from: padding changes, unit-dropdown reorder, label copy edits.
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets(
    'selecting an autocomplete suggestion calls addItemFromIngredient on submit',
    (tester) async {
      const lax = IngredientData(
        id: 'salmon',
        swedish: 'Lax',
        english: 'Salmon',
        group: 'protein/fish',
        properties: {'fish'},
      );

      // After the user types, the VM will have results; simulate via stub.
      when(() => vm.searchResults).thenReturn([lax]);

      await tester.pumpWidget(buildSheet());

      // Type in the ingredient field — triggers _onSearchChanged which
      // sets _showSuggestions=true if results are non-empty.
      await tester.enterText(
        find.widgetWithText(TextField, 'Ingrediens'),
        'lax',
      );
      await tester.pump();

      // Tap the suggestion in IngredientSuggestionList — triggers _onSuggestionTap
      // which sets _selectedIngredient = lax.
      await tester.tap(find.text('Lax'));
      await tester.pump();

      // Submit the form (the primary button text is "LÄGG TILL" in add mode).
      await tester.tap(find.text('LÄGG TILL'));
      await tester.pump();

      verify(
        () => vm.addItemFromIngredient(
          lax,
          quantity: any(named: 'quantity'),
          unit: any(named: 'unit'),
          location: any(named: 'location'),
          expiryDate: any(named: 'expiryDate'),
          note: any(named: 'note'),
        ),
      ).called(1);
      verifyNever(() => vm.addItemFromText(any()));
    },
  );

  // ────────────────────────────────────────────────────────────────────────────
  // Test 2: raw text (no suggestion picked) → addItemFromText
  //
  // Intent: when the user types a name but never taps a suggestion, the sheet
  // must call addItemFromText so the item is stored with the user's raw string.
  //
  // Would fail if: the `else` branch in _submit() were removed or if
  //   _selectedIngredient were never cleared on text-only input.
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets(
    'typing raw text without picking a suggestion calls addItemFromText',
    (tester) async {
      await tester.pumpWidget(buildSheet());

      await tester.enterText(
        find.widgetWithText(TextField, 'Ingrediens'),
        'Hemlagad buljong',
      );
      await tester.pump();

      await tester.tap(find.text('LÄGG TILL'));
      await tester.pump();

      verify(
        () => vm.addItemFromText(
          'Hemlagad buljong',
          quantity: any(named: 'quantity'),
          unit: any(named: 'unit'),
          location: any(named: 'location'),
          expiryDate: any(named: 'expiryDate'),
          note: any(named: 'note'),
        ),
      ).called(1);
      verifyNever(() => vm.addItemFromIngredient(any()));
    },
  );

  // ────────────────────────────────────────────────────────────────────────────
  // Test 3: edit mode — form is pre-populated and submit calls updateItem
  //
  // Intent: opening the sheet with an existingItem must pre-fill the name field
  // and route the submit to updateItem (not addItem*), preserving the id so
  // the correct Firestore document is overwritten.
  //
  // Would fail if: initState() forgot to populate _nameController, or if
  //   _submit() routed to addItemFromText instead of updateItem when _isEditing.
  // Won't break from: new fields added to PantryItem (they have defaults).
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets('edit mode pre-fills name and calls updateItem on submit', (
    tester,
  ) async {
    final existing = PantryItem(
      id: 'p_42',
      ingredientName: 'Smör',
      quantity: 250,
      unit: 'g',
      location: PantryLocation.fridge,
      addedAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(buildSheet(existingItem: existing));

    // The ingredient name field must be pre-populated.
    final nameField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Smör'),
    );
    expect(
      nameField.controller?.text,
      'Smör',
      reason:
          'edit mode must populate the ingredient name from the existing item',
    );

    // The primary button in edit mode shows "Spara", not "LÄGG TILL".
    expect(find.text('Spara'), findsOneWidget);

    await tester.tap(find.text('Spara'));
    await tester.pump();

    verify(
      () => vm.updateItem(
        any(
          that: predicate<PantryItem>(
            (item) => item.id == 'p_42' && item.ingredientName == 'Smör',
            'updated item must preserve id and name',
          ),
        ),
      ),
    ).called(1);
    verifyNever(() => vm.addItemFromIngredient(any()));
    verifyNever(() => vm.addItemFromText(any()));
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Test 4 (BUT-1379): a failed save must NOT silently dismiss the sheet
  //
  // Intent: the VM swallows write failures into `hasError` (offline / Firestore
  // error). The sheet must detect that and keep itself open with an error
  // message, instead of popping and silently losing the item the user believes
  // they added.
  //
  // Would fail if: _submit() popped unconditionally (the original bug) or didn't
  //   check viewModel.hasError before dismissing.
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets('keeps the sheet open and shows an error when the save fails', (
    tester,
  ) async {
    // The save attempt sets the VM into an error state.
    when(() => vm.hasError).thenReturn(true);

    await pumpRoutedSheet(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Ingrediens'),
      'Mjölk',
    );
    await tester.pump();

    await tester.tap(find.text('LÄGG TILL'));
    await tester.pumpAndSettle(); // run _submit + surface the snackbar

    // The save WAS attempted...
    verify(
      () => vm.addItemFromText(
        'Mjölk',
        quantity: any(named: 'quantity'),
        unit: any(named: 'unit'),
        location: any(named: 'location'),
        expiryDate: any(named: 'expiryDate'),
        note: any(named: 'note'),
      ),
    ).called(1);

    // ...but the sheet did not silently dismiss (it's a real modal route here,
    // so a stray pop would remove it) and it tells the user it failed.
    expect(find.byType(AddPantryItemSheet), findsOneWidget);
    expect(
      find.text('Kunde inte spara i skafferiet. Försök igen.'),
      findsOneWidget,
    );
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Test 5 (BUT-1379): a successful save dismisses the sheet
  //
  // Guards the other direction of the fix: when the VM reports no error, the
  // sheet must still pop. A regression that suppressed pop on success (e.g. an
  // over-eager `return` after the hasError check) would leave the sheet stuck.
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets('dismisses the sheet on a successful save', (tester) async {
    // hasError stays false (default stub); addItemFromText completes normally.
    await pumpRoutedSheet(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Ingrediens'),
      'Mjölk',
    );
    await tester.pump();

    await tester.tap(find.text('LÄGG TILL'));
    await tester.pumpAndSettle();

    expect(find.byType(AddPantryItemSheet), findsNothing);
  });
}
