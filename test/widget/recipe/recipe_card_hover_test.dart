/// BUT-1308 (BUT-710 follow-up): pin that RecipeCard mounts a HoverableCard
/// ancestor whose rest decoration carries the square / design-token treatment.
///
/// Intent: BUT-710 wrapped the custom cards in HoverableCard to give them a
/// hover affordance on web/desktop. These render tests guard against a future
/// refactor silently dropping the HoverableCard wrapper or swapping the square
/// design-token decoration for a rounded / ad-hoc one.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/components/input_themes.dart';
import 'package:butlery/widgets/common/hoverable_card.dart';
import 'package:butlery/widgets/recipe/recipe_card.dart';

import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';

void main() {
  group('RecipeCard mounts HoverableCard (BUT-1308)', () {
    late Recipe testRecipe;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      testRecipe = RecipeFactory.build(
        id: 'hover_recipe',
        title: 'Köttbullar med potatismos',
        description: 'Klassisk svensk husmanskost',
        imageUrls: const [],
        personalTagIds: const [],
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
    });

    testWidgets('renders a HoverableCard ancestor', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: Scaffold(
            body: RecipeCard(recipe: testRecipe, onTap: (_) {}),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(RecipeCard),
          matching: find.byType(HoverableCard),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'unselected rest decoration is the square recipe-card design token',
        (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: Scaffold(
            body: RecipeCard(recipe: testRecipe, onTap: (_) {}),
          ),
        ),
      );

      final hoverable = tester.widget<HoverableCard>(
        find.descendant(
          of: find.byType(RecipeCard),
          matching: find.byType(HoverableCard),
        ),
      );

      final rest = hoverable.restDecoration as BoxDecoration;
      // Square design language: the recipe-card token uses an asymmetric
      // Border (green left + rust bottom) and never a rounded BorderRadius.
      expect(rest, equals(InputThemes.recipeCardDecoration));
      expect(rest.borderRadius, isNull,
          reason: 'Recipe card must stay square — no BorderRadius.');
      expect(rest.border, isA<Border>());

      // Hover variant only deepens the shadow; border + corners stay identical
      // so the square treatment is preserved under the cursor.
      final hover = hoverable.hoverDecoration as BoxDecoration;
      expect(hover.border, equals(rest.border));
      expect(hover.borderRadius, isNull);
    });

    testWidgets('hover affordance disabled when card is not tappable',
        (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: Scaffold(
            body: RecipeCard(recipe: testRecipe),
          ),
        ),
      );

      final hoverable = tester.widget<HoverableCard>(
        find.descendant(
          of: find.byType(RecipeCard),
          matching: find.byType(HoverableCard),
        ),
      );
      expect(hoverable.enabled, isFalse,
          reason: 'A card with no onTap should not imply clickability.');
    });
  });
}
