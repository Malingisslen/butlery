// test/widget/recipe/related_recipes_test.dart
//
// BUT-1057: Widget tests for the related-recipes feature.
//
// Covers:
//   1. Editor chip rendering — chips shown for resolved related recipes.
//   2. Editor chip remove — tap X fires onUnlink with the correct id.
//   3. Detail RelatedRecipesSection — hidden when the related list is empty.
//   4. Detail RelatedRecipesSection — shows thumbnails when populated.
//   5. Detail UsedInSection — hidden when the used-in list is empty.
//   6. Detail UsedInSection — shows thumbnails for reverse-linked recipes.
//   7. Related thumbnail — tap navigates to the linked recipe's detail route.
//
// All three widgets are purely presentational — they receive resolved data
// from the parent and never touch the ServiceLocator, so these tests need no
// DI scaffolding. The viewmodel-level resolution + optimistic link/unlink
// behaviour (the Critical regression) is pinned in
// test/unit/viewmodels/recipe_form_viewmodel_test.dart where the full DI graph
// is wired via TestServiceLocator.

library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/recipe_detail/recipe_related_recipes_section.dart';
import 'package:butlery/widgets/recipe/related_recipes_editor.dart';

// ── Test helpers ─────────────────────────────────────────────────────────────

Recipe _recipe({
  String id = 'r1',
  String title = 'Recepttitel',
  List<String>? relatedIds,
}) {
  return Recipe(
    core: RecipeCore(
      id: id,
      title: title,
      description: '',
      ingredients: const [],
      instructions: const [],
      mealType: 'Middag',
      relatedRecipeIds: relatedIds,
    ),
    type: RecipeType.personal,
  );
}

Widget _wrap(
  Widget child, {
  Route<dynamic>? Function(RouteSettings)? onGenerateRoute,
}) =>
    MaterialApp(
      locale: const Locale('sv'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.lightTheme,
      home: Scaffold(body: SingleChildScrollView(child: child)),
      onGenerateRoute: onGenerateRoute,
    );

void main() {
  // ── 1 + 2: Editor chips ────────────────────────────────────────────────────

  group('RelatedRecipesEditor', () {
    testWidgets('shows a chip for each resolved related recipe',
        (tester) async {
      // Editor is purely presentational — it receives resolved (id, title)
      // records and never touches the ServiceLocator.
      await tester.pumpWidget(_wrap(
        RelatedRecipesEditor(
          currentRecipeId: 'r1',
          relatedRecipes: const [
            (id: 'r2', title: 'Pastasås'),
            (id: 'r3', title: 'Köttbullar'),
          ],
          onLink: (_) async => true,
          onUnlink: (_) async => true,
        ),
      ));
      await tester.pump();

      expect(find.text('Pastasås'), findsOneWidget);
      expect(find.text('Köttbullar'), findsOneWidget);
    });

    testWidgets('tapping X chip calls onUnlink with the target id',
        (tester) async {
      String? unlinkedId;
      await tester.pumpWidget(_wrap(
        RelatedRecipesEditor(
          currentRecipeId: 'r1',
          relatedRecipes: const [(id: 'r2', title: 'Pastasås')],
          onLink: (_) async => true,
          onUnlink: (id) async {
            unlinkedId = id;
            return true;
          },
        ),
      ));
      await tester.pump();

      // Find the close icon inside the chip and tap it.
      final closeIcon = find.byIcon(Icons.close);
      expect(closeIcon, findsOneWidget);
      await tester.tap(closeIcon);
      await tester.pump();

      expect(unlinkedId, 'r2');
    });

    testWidgets('link button is present with correct label text',
        (tester) async {
      await tester.pumpWidget(_wrap(
        RelatedRecipesEditor(
          currentRecipeId: 'r1',
          relatedRecipes: const [],
          onLink: (_) async => true,
          onUnlink: (_) async => true,
        ),
      ));
      await tester.pump();

      // The button label text confirms the button is rendered and localized.
      expect(find.text('+ Länka relaterat recept'), findsOneWidget);
    });
  });

  // ── 3 + 4: RelatedRecipesSection ──────────────────────────────────────────

  // The sections are purely presentational — they render whatever list they
  // are handed (resolved upstream in the viewmodel) and never touch a service.

  group('RelatedRecipesSection', () {
    testWidgets('hidden when the related list is empty', (tester) async {
      await tester.pumpWidget(_wrap(
        const RelatedRecipesSection(related: []),
      ));
      await tester.pump();

      expect(find.text('Relaterade recept'), findsNothing);
    });

    testWidgets('shows section title and thumbnails when related list is set',
        (tester) async {
      await tester.pumpWidget(_wrap(
        RelatedRecipesSection(
          related: [_recipe(id: 'r2', title: 'Pastasås')],
        ),
      ));
      await tester.pump();

      expect(find.text('Relaterade recept'), findsOneWidget);
      expect(find.text('Pastasås'), findsOneWidget);
    });
  });

  // ── 5 + 6: UsedInSection ──────────────────────────────────────────────────

  group('UsedInSection', () {
    testWidgets('hidden when the used-in list is empty', (tester) async {
      await tester.pumpWidget(_wrap(
        const UsedInSection(usedIn: []),
      ));
      await tester.pump();

      expect(find.text('Används i'), findsNothing);
    });

    testWidgets('shows reverse-linked recipes when the list is set',
        (tester) async {
      await tester.pumpWidget(_wrap(
        UsedInSection(
          usedIn: [_recipe(id: 'r2', title: 'Grundrecept')],
        ),
      ));
      await tester.pump();

      expect(find.text('Används i'), findsOneWidget);
      expect(find.text('Grundrecept'), findsOneWidget);
    });
  });

  // ── 7: Thumbnail navigation ────────────────────────────────────────────────

  group('Related thumbnail navigation', () {
    testWidgets(
        'tapping a thumbnail pushes Routes.recipeDetail with the recipe',
        (tester) async {
      final linkedRecipe = _recipe(id: 'r2', title: 'Pastasås');

      Recipe? navigatedRecipe;

      await tester.pumpWidget(_wrap(
        RelatedRecipesSection(related: [linkedRecipe]),
        onGenerateRoute: (settings) {
          if (settings.name == Routes.recipeDetail) {
            navigatedRecipe = settings.arguments as Recipe?;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => Scaffold(
                body: Text(navigatedRecipe?.title ?? ''),
              ),
            );
          }
          return null;
        },
      ));
      await tester.pump();

      // Tap the thumbnail (the InkWell wrapping it has the semantics label).
      final handle = tester.ensureSemantics();
      final thumb = find.bySemanticsLabel(
        RegExp(r'Öppna relaterat recept: Pastasås'),
      );
      expect(thumb, findsOneWidget);
      handle.dispose();

      await tester.tap(thumb);
      await tester.pumpAndSettle();

      expect(navigatedRecipe?.id, 'r2');
      expect(find.text('Pastasås'), findsOneWidget);
    });
  });
}
