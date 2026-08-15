/// Behavioral widget tests for AddPantryItemSheet.
///
/// Three contracts, added by three tickets:
///   - BUT-1344 COOK-07 — the *routing decision* _submit() makes: an
///     autocomplete pick goes to addItemFromIngredient, a raw name to
///     addItemFromText, and edit mode to updateItem, so the item lands in the
///     right Firestore collection.
///   - BUT-1379 — a failed save keeps the sheet open; a successful one
///     dismisses it.
///   - BUT-1849 — an ON-LIST stored unit is read back into the dropdown, and
///     the picked unit is what gets written. The last test pins the OFF-LIST
///     case, where neither holds, as a known defect for BUT-1858 to invert.
///
/// None of these are structural tests.
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
            // `unit` is asserted here on purpose: it is what proves the sheet
            // still READS the stored unit once the defect test below is
            // rewritten by BUT-1858. The write leg has its own test after it,
            // because this one alone would stay green if `_submit` stopped
            // sending `_unit` — `copyWith` without it preserves the item's
            // stored value, which is the very 'g' asserted here.
            (item) =>
                item.id == 'p_42' &&
                item.ingredientName == 'Smör' &&
                item.unit == 'g',
            'updated item must preserve id, name and an on-list unit',
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

  // ────────────────────────────────────────────────────────────────────────────
  // Test 6: the unit the user PICKS is the unit that gets saved.
  //
  // The write leg the test above cannot cover: there the stored and saved unit
  // are the same value, so dropping `unit: _unit` from _submit's copyWith
  // would go unnoticed. Here they differ, so only a real read of the dropdown
  // can produce 'dl'.
  //
  // This one is deliberately NOT tied to BUT-1858 — it must outlive the defect
  // test below, which is the suite's only other assertion that REDDENS when
  // the write drops `unit`. Note what stays open even so: `_submit`'s two ADD
  // branches pass
  // `unit` too, and tests 1-2 match it with a wildcard, so hardcoding 'st'
  // there survives the whole suite. Editing is the only leg proven here.
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets('picking a different unit saves the picked unit', (tester) async {
    final existing = PantryItem(
      id: 'p_7',
      ingredientName: 'Grädde',
      quantity: 2,
      unit: 'g',
      location: PantryLocation.fridge,
      addedAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(buildSheet(existingItem: existing));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    // The closed button renders every item in an IndexedStack, so the open
    // menu's entry is the hit-testable one.
    await tester.tap(find.text('dl').hitTestable().last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Spara'));
    await tester.pumpAndSettle();

    final saved =
        verify(() => vm.updateItem(captureAny())).captured.single as PantryItem;
    expect(
      saved.unit,
      'dl',
      reason: 'The dropdown selection must reach the saved item.',
    );
  });

  // ────────────────────────────────────────────────────────────────────────────
  // DOCUMENTS A DEFECT — when BUT-1858 lands, REPLACE this test with its
  // inverse rather than deleting it. It holds the suite's only off-list
  // fixture, so a plain deletion would leave nothing asserting that such an
  // item renders at all. The inverse: 'knippe' survives the save.
  //
  // The unit dropdown offers eight values. Off-list units reach pantry rows
  // from the shopping-checkoff flow, which stores an item's FREE-TEXT unit
  // verbatim (`ShoppingCheckoffPantryService` -> `PantryService
  // .addFromShoppingItem`); the sheet itself never produces one. The clamp
  // substitutes 'st' so `DropdownButton`'s one-match assert cannot fire — but
  // `_submit` writes `_unit` unconditionally, so opening such an item and
  // saving REWRITES the user's unit. This test pins that data loss as KNOWN,
  // not as desired: it asserts the current behaviour so a future fix has
  // something to redden.
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets('an off-list unit is clamped to st, and saving rewrites it', (
    tester,
  ) async {
    final existing = PantryItem(
      id: 'p_99',
      ingredientName: 'Rosmarin',
      quantity: 1,
      unit: 'knippe',
      location: PantryLocation.pantry,
      addedAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(buildSheet(existingItem: existing));
    await tester.pumpAndSettle();

    // The screen renders rather than asserting — that is what the clamp buys.
    expect(tester.takeException(), isNull);
    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(
      dropdown.initialValue,
      'st',
      reason: 'The stored unit is not on offer, so the clamp substitutes st.',
    );

    await tester.tap(find.text('Spara'));
    await tester.pumpAndSettle();

    final saved =
        verify(() => vm.updateItem(captureAny())).captured.single as PantryItem;
    expect(
      saved.unit,
      'st',
      reason:
          'The cost of the clamp: an untouched save silently replaces the '
          "user's 'knippe' with 'st'. Pinned so the loss is known.",
    );
  });
}
