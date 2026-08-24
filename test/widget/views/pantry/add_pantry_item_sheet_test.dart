/// Behavioral widget tests for AddPantryItemSheet.
///
/// Contracts added by successive tickets:
///   - BUT-1344 COOK-07 — the *routing decision* _submit() makes: an
///     autocomplete pick goes to addItemFromIngredient, a raw name to
///     addItemFromText, and edit mode to updateItem. Both add branches write
///     to the same collection. What the routing decides is whether the
///     ingredient is the one the user EXACTLY picked or whatever a fuzzy
///     search finds for the typed text (possibly nothing) — and so the
///     ingredientId link, plus, on the text branch only, whether the stored
///     NAME is the user's raw string or the match's canonical Swedish one.
///     The service's typicalUnit/typicalStorage fallbacks never fire from
///     this sheet: both ADD branches send a non-null unit (`_unit` starts at
///     'st' and only edit mode can null it) and a non-nullable location. The
///     edit branch CAN send unit: null — test 9 — but routes to updateItem,
///     which has no such fallback.
///   - BUT-1379 — a failed save keeps the sheet open; a successful one
///     dismisses it.
///   - BUT-1849 — an ON-LIST stored unit is read back into the dropdown, and
///     the picked unit is what gets written.
///   - BUT-1858 — the same now holds for a unit the sheet does not offer: it
///     is added to the dropdown for that item rather than clamped to 'st', so
///     an untouched save no longer rewrites it. An empty stored unit selects
///     nothing and survives. BOTH add branches assert the picked unit — test
///     1 for the ingredient path, test 10 for raw text. They have to: a
///     wildcard `unit` matcher, which is all they had before, cannot tell a
///     forwarded selection from a hardcoded default.
///
/// None of these are structural tests. Disclosed reads of internals: the
/// OFFERED LIST is read off `DropdownButton<String>.items`,
/// which is `DropdownButtonFormField`'s internal composition (tests 7-9), and
/// the SELECTION is read off the FormField's own `initialValue` (tests 2, 7,
/// 9) rather than off rendered pixels.
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
  // It also picks a unit and asserts it, which is what makes the ingredient
  // add branch non-wildcarded: `_submit` has TWO add branches and test 10 only
  // covers the raw-text one, so without this a hardcoded `unit: 'st'` here
  // would survive the whole suite (BUT-1858).
  //
  // Would fail if: _submit() dropped the `_selectedIngredient != null` branch,
  //   or stopped forwarding the dropdown selection on that branch.
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

      // Pick a unit other than the 'st' default, so the assertion below can
      // tell a forwarded selection from a hardcoded one. The closed button
      // renders every item in an IndexedStack, so the open menu's entry is the
      // hit-testable one.
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('dl').hitTestable().last);
      await tester.pumpAndSettle();

      // Submit the form (the primary button text is "LÄGG TILL" in add mode).
      await tester.tap(find.text('LÄGG TILL'));
      await tester.pump();

      verify(
        () => vm.addItemFromIngredient(
          lax,
          quantity: any(named: 'quantity'),
          unit: 'dl',
          location: any(named: 'location'),
          expiryDate: any(named: 'expiryDate'),
          note: any(named: 'note'),
        ),
      ).called(1);
      verifyNever(
        () => vm.addItemFromText(
          any(),
          quantity: any(named: 'quantity'),
          unit: any(named: 'unit'),
          location: any(named: 'location'),
          expiryDate: any(named: 'expiryDate'),
          note: any(named: 'note'),
        ),
      );
    },
  );

  // ────────────────────────────────────────────────────────────────────────────
  // Test 2: raw text (no suggestion picked) → addItemFromText
  //
  // Intent: when the user types a name but never taps a suggestion, the sheet
  // must call addItemFromText so the item is stored with the user's raw string.
  //
  // It also pins the ADD-MODE DEFAULT, both on screen and in the write.
  // BUT-1858 made `_unit` nullable so an empty stored unit can select nothing;
  // dropping the `= 'st'` initialiser in the same field would open every new
  // item with a blank unit box and SEND no unit — the service would then
  // store `match?.typicalUnit ?? 'st'`, the very fallback the header says
  // never fires from here — and nothing else in the suite would notice.
  //
  // Would fail if: the `else` branch in _submit() were removed, if
  //   _selectedIngredient were never cleared on text-only input, or if the
  //   add-mode default stopped being 'st'.
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets(
    'typing raw text without picking a suggestion calls addItemFromText',
    (tester) async {
      await tester.pumpWidget(buildSheet());
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>),
            )
            .initialValue,
        'st',
        reason: 'A new item opens on the default unit, not on nothing.',
      );

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
          unit: 'st',
          location: any(named: 'location'),
          expiryDate: any(named: 'expiryDate'),
          note: any(named: 'note'),
        ),
      ).called(1);
      verifyNever(
        () => vm.addItemFromIngredient(
          any(),
          quantity: any(named: 'quantity'),
          unit: any(named: 'unit'),
          location: any(named: 'location'),
          expiryDate: any(named: 'expiryDate'),
          note: any(named: 'note'),
        ),
      );
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
            // `unit` is asserted here on purpose: it proves the sheet READS
            // the stored unit. It cannot prove the WRITE — this one alone
            // would stay green if `_submit` stopped sending `_unit`, because
            // `copyWith` without it preserves the item's stored value, which
            // is the very 'g' asserted here. Test 6 covers the write on this
            // EDIT path; tests 1 and 10 cover it on the two add paths;
            // tests 7-9 do NOT — their fixtures are off-list or empty, so
            // `copyWith` preserving them produces the asserted value either
            // way. Do not read those three as backing up 6 and 10.
            (item) =>
                item.id == 'p_42' &&
                item.ingredientName == 'Smör' &&
                item.unit == 'g',
            'updated item must preserve id, name and an on-list unit',
          ),
        ),
      ),
    ).called(1);
    verifyNever(
      () => vm.addItemFromIngredient(
        any(),
        quantity: any(named: 'quantity'),
        unit: any(named: 'unit'),
        location: any(named: 'location'),
        expiryDate: any(named: 'expiryDate'),
        note: any(named: 'note'),
      ),
    );
    verifyNever(
      () => vm.addItemFromText(
        any(),
        quantity: any(named: 'quantity'),
        unit: any(named: 'unit'),
        location: any(named: 'location'),
        expiryDate: any(named: 'expiryDate'),
        note: any(named: 'note'),
      ),
    );
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
  // The write leg test 3 cannot cover: there the stored and saved unit are the
  // same value, so dropping `unit: _unit` from _submit's copyWith would go
  // unnoticed. Here they differ, so only a real read of the dropdown can
  // produce 'dl'.
  //
  // This covers the EDIT branch of _submit. The two ADD branches are covered
  // by test 1 (ingredient) and test 10 (raw text), which assert the picked
  // unit for the same reason this one does.
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
  // Test 7 (BUT-1858): an off-list unit is shown, selected, and SURVIVES a save
  //
  // The inverse of the test this replaces. Until BUT-1858 the sheet clamped any
  // unit outside its eight to 'st' to satisfy the dropdown's one-match assert,
  // and `_submit` then wrote the clamped value — so opening a 'knippe' row and
  // pressing Save silently rewrote it. Off-list units arrive from the
  // shopping-checkoff flow, which stores a free-text unit verbatim; the sheet
  // itself never produces one.
  //
  // Would fail if: `unitOptions` stopped prepending the stored unit — the
  //   dropdown's one-match assert fires and takeException() is non-null.
  // Would NOT fail if: _submit stopped sending `unit`. `copyWith` then falls
  //   back to the stored 'knippe', which is the value asserted. This test pins
  //   the WIDENING; tests 6, 1 and 10 pin the write.
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets('an off-list unit is offered, selected, and survives a save', (
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

    expect(tester.takeException(), isNull);
    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(
      dropdown.initialValue,
      'knippe',
      reason: 'The stored unit is what the control must show.',
    );
    // The whole offered list, not just the selection: the stored unit rides on
    // top and the eight follow unchanged. Pins the widening against a
    // half-applied edit that selects the value without offering it.
    expect(
      tester
          .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
          .items
          ?.map((i) => i.value)
          .toList(),
      ['knippe', ...AddPantryItemSheet.offeredUnits],
    );

    await tester.tap(find.text('Spara'));
    await tester.pumpAndSettle();

    final saved =
        verify(() => vm.updateItem(captureAny())).captured.single as PantryItem;
    expect(
      saved.unit,
      'knippe',
      reason: 'An untouched save must not rewrite the stored unit.',
    );
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Test 8 (BUT-1858): the injected row SURVIVES a pick and can be chosen back
  //
  // The dropdown's items are derived from the STORED unit, not from the current
  // selection — the one place this seam diverges from
  // `RecipeFormState.mealTypeOptions`, whose injected row disappears the moment
  // you pick something else. Without this test the divergence is a comment
  // only: keying the list off `_unit` instead leaves every other test green,
  // and the user who mis-picks 'dl' on a 'knippe' row can never get 'knippe'
  // back — then Save rewrites it, which is the whole defect returning by
  // another door.
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets('the off-list row stays on offer after a different pick', (
    tester,
  ) async {
    final existing = PantryItem(
      id: 'p_101',
      ingredientName: 'Rosmarin',
      quantity: 1,
      unit: 'knippe',
      location: PantryLocation.pantry,
      addedAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(buildSheet(existingItem: existing));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('dl').hitTestable().last);
    await tester.pumpAndSettle();

    // The stored unit must still be offered, so the mis-pick is undoable.
    expect(
      tester
          .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
          .items
          ?.map((i) => i.value)
          .toList(),
      ['knippe', ...AddPantryItemSheet.offeredUnits],
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('knippe').hitTestable().last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Spara'));
    await tester.pumpAndSettle();

    final saved =
        verify(() => vm.updateItem(captureAny())).captured.single as PantryItem;
    expect(
      saved.unit,
      'knippe',
      reason: 'A mis-pick must be undoable all the way back to storage.',
    );
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Test 9 (BUT-1858): an EMPTY stored unit selects nothing and is preserved
  //
  // Empty is a real stored value — an amount-less recipe line produces it and
  // the checkoff flow stores it verbatim. It matches no dropdown item by
  // design, so `_unit` stays null and `copyWith(unit: null)` keeps what is
  // stored rather than inventing 'st'.
  //
  // Would fail if: unitOptions returned '' as the selection (assert fires), or
  //   if _submit coalesced null to a default before writing.
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets('an empty stored unit selects nothing and is not invented', (
    tester,
  ) async {
    final existing = PantryItem(
      id: 'p_100',
      ingredientName: 'Persilja',
      quantity: 1,
      unit: '',
      location: PantryLocation.fridge,
      addedAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(buildSheet(existingItem: existing));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(dropdown.initialValue, isNull);
    expect(
      tester
          .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
          .items
          ?.map((i) => i.value)
          .toList(),
      AddPantryItemSheet.offeredUnits,
    );

    await tester.tap(find.text('Spara'));
    await tester.pumpAndSettle();

    final saved =
        verify(() => vm.updateItem(captureAny())).captured.single as PantryItem;
    expect(
      saved.unit,
      '',
      reason: 'Nothing was picked, so the stored empty unit must survive.',
    );
  });

  // ────────────────────────────────────────────────────────────────────────────
  // Test 10 (BUT-1858): the raw-text ADD path sends the picked unit too
  //
  // Covers the RAW-TEXT add branch; test 1 covers the ingredient one the same
  // way. Together they close the gap an earlier round disclosed, where a
  // wildcard `unit` matcher let a hardcoded 'st' survive the whole suite.
  // This is the add-mode twin of test 6.
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets('adding by raw text sends the picked unit, not the default', (
    tester,
  ) async {
    await tester.pumpWidget(buildSheet());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Ingrediens'),
      'Grädde',
    );
    await tester.pump();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    // The closed button renders every item in an IndexedStack, so the open
    // menu's entry is the hit-testable one.
    await tester.tap(find.text('dl').hitTestable().last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('LÄGG TILL'));
    await tester.pump();

    verify(
      () => vm.addItemFromText(
        'Grädde',
        quantity: any(named: 'quantity'),
        unit: 'dl',
        location: any(named: 'location'),
        expiryDate: any(named: 'expiryDate'),
        note: any(named: 'note'),
      ),
    ).called(1);
  });
  // ────────────────────────────────────────────────────────────────────────────
  // BUT-1910 — the amount field speaks Swedish
  //
  // The field parsed with a hand-rolled `replaceAll(',', '.')` and had no input
  // formatter at all, so it was a spelling of a decision BUT-1891 already
  // made for the shopping surface.
  //
  // The "0,5" and ",5" cases are CONTROLS: measured, the old path already read
  // both as 0.5. They are kept because they kill the BUT-1891 defect class — a
  // formatter that eats the separator — which is how this fix could go wrong.
  // ────────────────────────────────────────────────────────────────────────────
  testWidgets('a comma decimal reaches the view model as a fraction', (
    tester,
  ) async {
    await tester.pumpWidget(buildSheet());

    await tester.enterText(
      find.widgetWithText(TextField, 'Ingrediens'),
      'Mjölk',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Mängd'), '0,5');
    await tester.pump();

    await tester.tap(find.text('LÄGG TILL'));
    await tester.pump();

    verify(
      () => vm.addItemFromText(
        'Mjölk',
        quantity: 0.5,
        unit: any(named: 'unit'),
        location: any(named: 'location'),
        expiryDate: any(named: 'expiryDate'),
        note: any(named: 'note'),
      ),
    ).called(1);
  });

  testWidgets('a leading comma is 0.5, not the 1.0 fallback', (tester) async {
    await tester.pumpWidget(buildSheet());

    await tester.enterText(
      find.widgetWithText(TextField, 'Ingrediens'),
      'Mjölk',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Mängd'), ',5');
    await tester.pump();

    await tester.tap(find.text('LÄGG TILL'));
    await tester.pump();

    // 1.0 here would mean the parse failed and the default took over. A control,
    // not a regression test: the old path got this right too.
    verify(
      () => vm.addItemFromText(
        'Mjölk',
        quantity: 0.5,
        unit: any(named: 'unit'),
        location: any(named: 'location'),
        expiryDate: any(named: 'expiryDate'),
        note: any(named: 'note'),
      ),
    ).called(1);
  });

  testWidgets('the field refuses a second separator', (tester) async {
    await tester.pumpWidget(buildSheet());

    await tester.enterText(find.widgetWithText(TextField, 'Mängd'), '1,5,5');
    await tester.pump();

    // The formatter keeps the first separator and drops the second, so the
    // digits after it join the fraction rather than producing an unparseable
    // string. Asserting the FIELD, not the submit, because this is the
    // formatter's job and the parser never sees the rejected keystroke.
    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Mängd'),
    );
    expect(field.controller!.text, '1,55');
  });
  // The arm the fix ADDED, and the one nothing else in this file can reach:
  // every other edit fixture seeds the amount from `formattedQuantity` with a
  // parseable value, so `existing?.quantity` is never consulted. It is reachable
  // in production — the formatter permits an empty field and `_submit` only
  // early-returns on an empty NAME — and clearing the amount on a 250 g item
  // used to write 1.0.
  //
  // Deleting `existing?.quantity ??` from the fallback chain reddens exactly
  // this case and nothing else.
  testWidgets('clearing the amount in edit mode keeps the stored quantity', (
    tester,
  ) async {
    final existing = PantryItem(
      id: 'p_43',
      ingredientName: 'Smör',
      quantity: 250,
      unit: 'g',
      location: PantryLocation.fridge,
      addedAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(buildSheet(existingItem: existing));

    await tester.enterText(find.widgetWithText(TextField, 'Mängd'), '');
    await tester.pump();

    // The premise, asserted rather than assumed: if the formatter refused the
    // empty string the field would still read 250, the fallback would never be
    // reached, and this test would pass for the wrong reason.
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Mängd'))
          .controller!
          .text,
      isEmpty,
    );

    await tester.tap(find.text('Spara'));
    await tester.pump();

    final saved =
        verify(() => vm.updateItem(captureAny())).captured.single as PantryItem;
    expect(
      saved.quantity,
      250.0,
      reason:
          'an unreadable amount on EDIT means the amount the item already had, '
          'not the add-mode default of 1',
    );
  });

  // The sibling the case above cannot be without. On its own, "saved 250" is
  // over-determined: dropping `quantity:` from the edit branch's `copyWith`
  // also yields 250, so it cannot tell a working fallback from an edit path
  // that stopped writing the amount at all. Nothing else in this file pinned
  // that write — the same gap test 6 closed for `unit`, still open for
  // `quantity` until now.
  testWidgets('a typed amount in edit mode reaches the saved item', (
    tester,
  ) async {
    final existing = PantryItem(
      id: 'p_44',
      ingredientName: 'Smör',
      quantity: 250,
      unit: 'g',
      location: PantryLocation.fridge,
      addedAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(buildSheet(existingItem: existing));

    await tester.enterText(find.widgetWithText(TextField, 'Mängd'), '0,5');
    await tester.pump();

    await tester.tap(find.text('Spara'));
    await tester.pump();

    final saved =
        verify(() => vm.updateItem(captureAny())).captured.single as PantryItem;
    expect(saved.quantity, 0.5);
  });
}
