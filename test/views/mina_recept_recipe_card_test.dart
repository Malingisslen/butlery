// BUT-1895 item 2: `MinaReceptRecipeCard` had no tests at all, and it holds the
// switch that decides whether allergen information reaches a recipe card.
//
// One line does it:
//
//   userAllergenPrefs: allergenPrefs.showOnCards ? allergenPrefs.trackedAllergens : null
//
// If `showOnCards` turns false, `null` travels down, `ContentCard` derives
// `showAllergenBadges: false`, and no badge appears anywhere — which is exactly
// the symptom BUT-1780 was reported as. Nothing in any layer pinned that
// connection, so a regression in it was invisible to the whole suite.
//
// The file lives under `test/views/` because the widget lives under `lib/views/`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/views/mina_recept/recipe_card_widget.dart';
import 'package:butlery/widgets/tagging/tag_result_display.dart';

import '../infrastructure/builders/recipe_builder.dart';
import '../infrastructure/helpers/widget_test_app.dart';
import '../test_support/base_unit_test.dart';

class _MockRecipeListViewModel extends Mock implements RecipeListViewModel {}

void main() {
  late _MockRecipeListViewModel viewModel;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  Recipe assessed() =>
      (RecipeBuilder()
            ..id = 'assessed'
            ..title = 'Köttbullar'
            ..imageUrls = []
            ..withTagResult(
              TagResult(
                tags: const {},
                allergenStatus: const {
                  'gluten': TriState.free,
                  'mjölk': TriState.contains,
                },
                dietaryStatus: const {},
                coverage: 1.0,
                generatedAt: DateTime(2026, 1, 1),
                generatorVersion: '1.0',
                hasCoverageAnomaly: false,
              ),
            ))
          .build();

  setUp(() {
    viewModel = _MockRecipeListViewModel();
    when(() => viewModel.selectedIds).thenReturn(const <String>{});
    when(() => viewModel.isSelectionMode).thenReturn(false);
    when(() => viewModel.isGridView).thenReturn(false);
    when(() => viewModel.pantryOnly).thenReturn(false);
    when(() => viewModel.pantryMatches).thenReturn(const {});
    when(() => viewModel.pooledStats).thenReturn(const {});
  });

  UserAllergenPreferences prefs({required bool showOnCards}) =>
      UserAllergenPreferences(
        trackedAllergens: const {'gluten', 'mjölk'},
        trackedDietary: const {},
        showOnCards: showOnCards,
      );

  Future<void> pumpCard(
    WidgetTester tester, {
    required bool showOnCards,
    bool gridView = false,
  }) async {
    when(() => viewModel.isGridView).thenReturn(gridView);

    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: Scaffold(
          body: SizedBox(
            width: 360,
            child: MinaReceptRecipeCard(
              viewModel: viewModel,
              recipe: assessed(),
              allergenPrefs: prefs(showOnCards: showOnCards),
              onDelete: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  group('the "visa på kort" setting reaches the card', () {
    testWidgets('badges appear in list view when the setting is on', (
      tester,
    ) async {
      await pumpCard(tester, showOnCards: true);

      expect(find.byType(CompactAllergenRow), findsOneWidget);
    });

    testWidgets('badges appear in GRID view when the setting is on', (
      tester,
    ) async {
      // The half BUT-1895 was filed for: the same setting, the other view.
      await pumpCard(tester, showOnCards: true, gridView: true);

      expect(find.byType(CompactAllergenRow), findsOneWidget);
    });

    testWidgets('the setting off silences the badges in list view', (
      tester,
    ) async {
      await pumpCard(tester, showOnCards: false);

      expect(find.byType(CompactAllergenRow), findsNothing);
    });

    testWidgets('the setting off silences the badges in grid view', (
      tester,
    ) async {
      // Both views are asserted in both directions on purpose: a fix that wired
      // the grid up but ignored the setting there would satisfy the positive
      // case above and quietly override a user who opted out.
      await pumpCard(tester, showOnCards: false, gridView: true);

      expect(find.byType(CompactAllergenRow), findsNothing);
    });
  });
}
