/// BUT-1250: widget test for the link button → picker → onLink flow in
/// [RelatedRecipesEditor].
///
/// The existing [related_recipes_test.dart] covers chip rendering, the unlink
/// callback, section visibility, and thumbnail navigation. This file adds the
/// one missing flow: tapping "Länka relaterat recept" opens the
/// [RelatedRecipesPickerDialog], selecting a recipe and confirming fires
/// [onLink] with that recipe's id.
///
/// Intent: "This test proves that tapping the link button opens the picker,
/// selecting a recipe and confirming fires onLink with the selected recipe's
/// id — so a broken onPressed or a disconnected _confirm would cause a
/// failure here."
///
/// Intent for the optimistic-chip test: "This test proves that after the
/// picker confirms, the onLink callback fires — proving the dialog's
/// _confirm → Navigator.pop(context, selected) → _openPicker receives it
/// chain is intact."
///
/// The [RelatedRecipesPickerDialog] resolves [RecipeListViewModel] from the
/// production [ServiceLocator] in initState. We wire the prod↔test bridge
/// and register a [MockRecipeListViewModel] pre-seeded with one selectable
/// recipe so the dialog renders a populated list without needing real DI.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/widgets/recipe/related_recipes_editor.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/widget_mocks.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// A recipe with distinct ingredients so the editor chip and picker row show
/// different text and finders are unambiguous.
Recipe _pickable({
  String id = 'r-pasta',
  String title = 'Pastasås',
  String mealType = 'Middag',
}) {
  return Recipe(
    core: RecipeCore(
      id: id,
      title: title,
      description: '',
      ingredients: const ['tomat', 'lök', 'vitlök'],
      instructions: const [],
      mealType: mealType,
    ),
    type: RecipeType.personal,
  );
}

Widget _wrap(Widget child) {
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
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

void main() {
  late MockRecipeListViewModel mockVm;

  setUpAll(() {
    // Production ServiceLocator wraps the same GetIt.instance that
    // TestServiceLocator populates with mocks. Calling this once is
    // sufficient — it survives setUp/tearDown reset cycles on GetIt because
    // ServiceLocator._container stores the DIContainer singleton, which in
    // turn holds GetIt.instance.
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await TestServiceLocator.initialize();

    mockVm = MockRecipeListViewModel();
    // Seed one pickable recipe; isLoading=false so the dialog renders the
    // list immediately.
    mockVm.setRecipeListState(recipes: [_pickable()], isLoading: false);

    // Register the specific instance as the RecipeListViewModel singleton so
    // the dialog's ServiceLocator.get<RecipeListViewModel>() returns OUR mock.
    TestServiceLocator.registerMock<RecipeListViewModel>(mockVm);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  // ── Link button → picker → onLink ────────────────────────────────────────

  testWidgets(
    'tapping the link button opens the picker dialog and confirming a '
    'selection fires onLink with the selected recipe id',
    (tester) async {
      // This test would fail if:
      //   • the link button's onPressed is disconnected (dialog never opens)
      //   • _confirm does not pop with the selected recipes (onLink never
      //     fires)
      //   • the dialog's ServiceLocator.get<RecipeListViewModel>() resolves to
      //     a different (empty) instance (list appears empty, nothing to tap)

      String? linkedId;

      await tester.pumpWidget(
        _wrap(
          RelatedRecipesEditor(
            currentRecipeId: 'r-current',
            relatedRecipes: const [],
            onLink: (id) async {
              linkedId = id;
              return true;
            },
            onUnlink: (_) async => true,
          ),
        ),
      );
      await tester.pump();

      // The link button is present (covered by related_recipes_test.dart but
      // verified here as a precondition so a missing button fails loudly).
      final linkBtn = find.text('+ Länka relaterat recept');
      expect(linkBtn, findsOneWidget);

      // Tap → showDialog → RelatedRecipesPickerDialog.initState resolves the
      // mocked RecipeListViewModel.
      await tester.tap(linkBtn);
      await tester.pump(); // kick off showDialog
      await tester.pump(); // complete dialog route push

      // Dialog title confirms the picker is open.
      expect(find.text('Välj relaterade recept'), findsOneWidget);

      // The seeded recipe should appear as a ListTile.
      expect(find.text('Pastasås'), findsOneWidget);

      // Select it — tapping the ListTile calls onSelectionChanged(true) via
      // the internal _RecipePickerItem.onTap callback.
      await tester.tap(find.text('Pastasås'));
      await tester.pump(); // setState rebuilds the dialog with the selection

      // Confirm button appears after at least one recipe is selected.
      // Label is "Lägg till (1)" from l10n.commonAdd + " (1)".
      final confirmBtn = find.text('Lägg till (1)');
      expect(
        confirmBtn,
        findsOneWidget,
        reason:
            'The confirm button must appear after a recipe is selected. '
            'If this is missing, _selectedIds was not updated.',
      );

      // Tap confirm — _confirm pops the dialog with the selected Recipe list.
      await tester.tap(confirmBtn);
      await tester.pump(); // pops the dialog
      await tester.pump(); // _openPicker receives result, calls onLink

      // Assert onLink fired with the correct id.
      expect(
        linkedId,
        'r-pasta',
        reason:
            'onLink must be called with the id of the confirmed recipe. '
            'A broken _confirm or a disconnected onPressed would leave '
            'linkedId null.',
      );
    },
  );

  // ── Optimistic chip: after onLink succeeds, caller controls state ─────────
  //
  // RelatedRecipesEditor is purely presentational — it does NOT add an
  // optimistic chip itself; the parent ViewModel is expected to update
  // relatedRecipes after onLink returns true. This test documents that
  // contract rather than asserting a chip appears (which would require
  // wiring a full StatefulWidget parent).
  //
  // The chip-appears-after-link invariant is tested at the ViewModel layer in
  // test/unit/viewmodels/recipe_form_viewmodel_test.dart (BUT-1057).

  testWidgets(
    'onLink receives exactly the id of the confirmed recipe — confirms the '
    '_confirm → Navigator.pop(context, selected) → onLink chain',
    (tester) async {
      // Seed two recipes so we can assert that ONLY the selected one's id
      // is passed to onLink (the non-selected recipe must not appear).
      mockVm.setRecipeListState(
        recipes: [
          _pickable(id: 'r-pasta', title: 'Pastasås'),
          _pickable(id: 'r-tacos', title: 'Tacos'),
        ],
        isLoading: false,
      );
      // Re-register with updated state.
      TestServiceLocator.registerMock<RecipeListViewModel>(mockVm);

      final List<String> linkedIds = [];

      await tester.pumpWidget(
        _wrap(
          RelatedRecipesEditor(
            currentRecipeId: 'r-current',
            relatedRecipes: const [],
            onLink: (id) async {
              linkedIds.add(id);
              return true;
            },
            onUnlink: (_) async => true,
          ),
        ),
      );
      await tester.pump();

      // Open the picker.
      await tester.tap(find.text('+ Länka relaterat recept'));
      await tester.pump();
      await tester.pump();

      // Select only "Pastasås".
      await tester.tap(find.text('Pastasås'));
      await tester.pump();

      // Confirm.
      await tester.tap(find.text('Lägg till (1)'));
      await tester.pump();
      await tester.pump();

      expect(
        linkedIds,
        ['r-pasta'],
        reason:
            'Only the selected recipe id must reach onLink. "r-tacos" '
            'was never selected so it must be absent.',
      );
    },
  );
}
