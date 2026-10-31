// Mina recept recipe cards show no allergen information at all.
//
// The file lives under `test/views/` because the widget lives under `lib/views/`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/views/mina_recept/recipe_card_widget.dart';
import 'package:butlery/widgets/common/layout/detail_pane.dart';
import 'package:butlery/widgets/common/swipe_hint_banner.dart';
import 'package:butlery/widgets/recipe/recipe_card.dart';
import 'package:butlery/widgets/tagging/allergen_status_badge.dart';

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

  Future<void> pumpCard(WidgetTester tester, {bool gridView = false}) async {
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
              onDelete: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  group('allergen info', () {
    for (final gridView in [false, true]) {
      testWidgets(
        'never reaches the card in ${gridView ? 'grid' : 'list'} view',
        (
          tester,
        ) async {
          await pumpCard(tester, gridView: gridView);

          expect(find.byType(AllergenStatusBadge), findsNothing);
          expect(find.text('Ej kontrollerat'), findsNothing);
        },
      );
    }
  });

  group('in selection mode', () {
    Future<void> pumpSelecting(
      WidgetTester tester, {
      required bool gridView,
      required bool selected,
    }) async {
      when(() => viewModel.isSelectionMode).thenReturn(true);
      when(() => viewModel.isGridView).thenReturn(gridView);
      when(
        () => viewModel.selectedIds,
      ).thenReturn(selected ? const {'assessed'} : const <String>{});
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: MinaReceptRecipeCard(
                  viewModel: viewModel,
                  recipe: assessed(),
                  onDelete: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
    }

    Finder check(String label) => find.bySemanticsLabel(label);

    testWidgets('the check announces marked / not marked with the title', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpSelecting(tester, gridView: false, selected: false);
        expect(check('Köttbullar, ej markerad'), findsOneWidget);
        expect(check('Köttbullar, markerad'), findsNothing);

        await pumpSelecting(tester, gridView: false, selected: true);
        expect(check('Köttbullar, markerad'), findsOneWidget);
        expect(check('Köttbullar, ej markerad'), findsNothing);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('a list row carries the check to the left of the row', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpSelecting(tester, gridView: false, selected: false);
        expect(tester.takeException(), isNull);

        final checkRect = tester.getRect(check('Köttbullar, ej markerad'));
        final cardRect = tester.getRect(find.byType(RecipeCard));
        expect(checkRect.right, lessThanOrEqualTo(cardRect.left));
      } finally {
        handle.dispose();
      }
    });

    testWidgets('a grid card carries the check in its top-right corner', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpSelecting(tester, gridView: true, selected: true);
        expect(tester.takeException(), isNull);

        final checkRect = tester.getRect(check('Köttbullar, markerad'));
        final cardRect = tester.getRect(find.byType(RecipeCard));
        expect(
          cardRect.contains(checkRect.center),
          isTrue,
          reason: '$checkRect vs $cardRect',
        );
        expect(checkRect.center.dx, greaterThan(cardRect.center.dx));
        expect(checkRect.center.dy, lessThan(cardRect.center.dy));
      } finally {
        handle.dispose();
      }
    });
  });

  // BUT-723: the card whose recipe is open on the right is marked.
  group('beside a detail pane', () {
    Future<DetailPaneController> pumpInPane(WidgetTester tester) async {
      final controller = DetailPaneController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: DetailPaneScope(
            controller: controller,
            child: Scaffold(
              body: SizedBox(
                width: 360,
                child: MinaReceptRecipeCard(
                  viewModel: viewModel,
                  recipe: assessed(),
                  onDelete: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      return controller;
    }

    testWidgets('a tap opens the recipe on the right and marks the card', (
      tester,
    ) async {
      final controller = await pumpInPane(tester);
      expect(
        tester.widget<RecipeCard>(find.byType(RecipeCard)).isSelected,
        isFalse,
      );

      await tester.tap(find.byType(RecipeCard));
      await tester.pump();

      expect(controller.selected?.name, Routes.recipeDetail);
      expect(controller.selected?.arguments, isA<Recipe>());
      expect(controller.isSelected('assessed'), isTrue);
      expect(
        tester.widget<RecipeCard>(find.byType(RecipeCard)).isSelected,
        isTrue,
      );
    });

    testWidgets('another recipe on the right leaves the card unmarked', (
      tester,
    ) async {
      final controller = await pumpInPane(tester);

      controller.open(const RouteSettings(name: '/x'), key: 'other');
      await tester.pump();

      expect(
        tester.widget<RecipeCard>(find.byType(RecipeCard)).isSelected,
        isFalse,
      );
    });
  });

  group('the actions behind the card', () {
    late List<Recipe> deleted;
    late List<RouteSettings> pushed;

    Future<void> pumpActions(WidgetTester tester, {bool grid = false}) async {
      deleted = [];
      pushed = [];
      when(() => viewModel.isGridView).thenReturn(grid);
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          onGenerateRoute: (settings) {
            pushed.add(settings);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('route')),
            );
          },
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: grid ? 300 : null,
                child: MinaReceptRecipeCard(
                  viewModel: viewModel,
                  recipe: assessed(),
                  onDelete: deleted.add,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final button = find.byKey(const ValueKey('recipe-actions-assessed'));

    testWidgets('Redigera in the sheet opens the editor with the recipe', (
      tester,
    ) async {
      await pumpActions(tester);

      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Redigera'));
      await tester.pumpAndSettle();

      expect(pushed.last.name, Routes.editRecipe);
      expect((pushed.last.arguments as Recipe).id, 'assessed');
    });

    testWidgets('Radera deletes only after the user confirms', (
      tester,
    ) async {
      await pumpActions(tester);

      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Radera'));
      await tester.pumpAndSettle();

      expect(deleted, isEmpty);

      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();
      expect(deleted, isEmpty);

      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Radera'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(
          of: find.text(AppLocalizationsSv().recipeDelete),
          matching: find.bySubtype<FilledButton>(),
        ),
      );
      await tester.pumpAndSettle();

      expect(deleted.map((r) => r.id), ['assessed']);
    });

    testWidgets('swiping the card counts as having used the swipe', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await pumpActions(tester);

      await tester.fling(
        find.byType(Dismissible),
        const Offset(-300, 0),
        1000,
      );
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(SwipeHintBanner.recipeSwipeSeenKey), isTrue);
    });

    testWidgets('the grid card carries one actions button; selecting hides '
        'it', (tester) async {
      await pumpActions(tester, grid: true);
      expect(button, findsOneWidget);

      when(() => viewModel.isSelectionMode).thenReturn(true);
      await pumpActions(tester, grid: true);
      expect(button, findsNothing);
    });
  });
}
