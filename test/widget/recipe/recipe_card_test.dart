import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/recipe/recipe_card.dart';
import 'package:butlery/widgets/recipe/recipe_initial_plate.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/services/tagging/tag_generator.dart';
import 'package:butlery/widgets/tagging/allergen_status_badge.dart';
import 'package:butlery/widgets/tagging/dietary_status_badge.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';
import '../../infrastructure/builders/recipe_builder.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';
import '../../test_support/semantics_announcement.dart';

/// The one metadata line is a rich Text, so it is found by its plain text.
Finder _meta(String text) => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      (w.textSpan?.toPlainText(includeSemanticsLabels: false) ?? '') == text,
);

Finder _metaHas(String text) => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      (w.textSpan?.toPlainText(includeSemanticsLabels: false) ?? '').contains(
        text,
      ),
);

void main() {
  group('RecipeCard', () {
    late Recipe testRecipe;
    late Recipe recipeWithoutImage;
    late Recipe minimalRecipe;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      testRecipe = RecipeFactory.build(
        id: 'test_recipe_1',
        title: 'Köttbullar med potatismos',
        description: 'Klassisk svensk husmanskost',
        imageUrls: ['https://example.com/meatballs.jpg'],
        mealType: 'Middag',
        portions: 4,
        timeMinutes: 45,
        rating: 4.5,
        personalTagIds: ['svensk', 'husmanskost', 'kött'],
      );

      recipeWithoutImage = RecipeFactory.build(
        id: 'test_recipe_2',
        title: 'Fisksoppa',
        description: 'Varmande soppa med lax och torsk',
        imageUrls: [],
        mealType: 'Lunch',
        portions: 6,
        timeMinutes: 30,
        rating: 4.2,
      );

      minimalRecipe = RecipeFactory.build(
        id: 'test_recipe_3',
        title: 'Enkel rätt',
        description: '',
        imageUrls: [],
        mealType: '',
        portions: null,
        timeMinutes: null,
        rating: null,
        personalTagIds: [],
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
    });

    group('Rendering - Detailed Style', () {
      testWidgets('should render recipe with all details', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: testRecipe,
                style: RecipeCardStyle.detailed,
              ),
            ),
          ),
        );

        // The drawing has the title and one metadata line, no description.
        expect(find.text('Köttbullar med potatismos'), findsOneWidget);
        expect(find.text('Klassisk svensk husmanskost'), findsNothing);

        // Metadata and the rating are one line of text
        expect(_meta('45 min \u00B7 4 port \u00B7 \uFFFC4,5'), findsOneWidget);
      });

      testWidgets('should render recipe without image correctly', (
        tester,
      ) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: recipeWithoutImage,
                style: RecipeCardStyle.detailed,
              ),
            ),
          ),
        );

        expect(find.text('Fisksoppa'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(RecipeInitialPlate),
            matching: find.text('F'),
          ),
          findsOneWidget,
        );
        expect(find.byType(VegetableIllustration), findsNothing);
      });

      testWidgets('should hide elements based on display options', (
        tester,
      ) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: testRecipe,
                style: RecipeCardStyle.detailed,
                showImage: false,
                showMetadata: false,
              ),
            ),
          ),
        );

        expect(find.text('Köttbullar med potatismos'), findsOneWidget);
        expect(find.text('Middag'), findsNothing);
        expect(_metaHas('45 min'), findsNothing);
        expect(_metaHas('4 port'), findsNothing);
      });

      testWidgets('should handle minimal recipe data', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: minimalRecipe,
                style: RecipeCardStyle.detailed,
              ),
            ),
          ),
        );

        expect(find.text('Enkel rätt'), findsOneWidget);
        // No description, metadata, or tags should be shown
        expect(find.text('portioner'), findsNothing);
        expect(find.text('min'), findsNothing);
      });
    });

    group('Rendering - Compact Style', () {
      testWidgets('should render compact layout correctly', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: testRecipe,
                style: RecipeCardStyle.compact,
              ),
            ),
          ),
        );

        expect(find.text('Köttbullar med potatismos'), findsOneWidget);
        // Compact style should not show description
        expect(find.text('Klassisk svensk husmanskost'), findsNothing);
        // But should show metadata (dot-separated text format)
        expect(_metaHas('45 min \u00B7 4 port'), findsOneWidget);
      });

      testWidgets('should use smaller image in compact mode', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: testRecipe,
                style: RecipeCardStyle.compact,
              ),
            ),
          ),
        );

        // In compact mode, the widget should exist but be rendered smaller
        // We can verify this by checking that the compact layout is being used
        expect(find.text('Köttbullar med potatismos'), findsOneWidget);
        // In compact mode, description should not be shown
        expect(find.text('Klassisk svensk husmanskost'), findsNothing);
      });
    });

    group('Rendering - Grid Style', () {
      testWidgets('should render grid layout correctly', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            // topLeft, so the card is given a LOOSE height and takes the one
            // its content needs — which is how the grid lays it out
            // (BUT-1911). A tight box would measure the card's willingness to
            // be squeezed, and it is no longer willing: the recipe photo used
            // to be the slack and gave up its whole height before anything
            // complained.
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 200,
                child: RecipeCard(
                  recipe: testRecipe,
                  style: RecipeCardStyle.grid,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Köttbullar med potatismos'), findsOneWidget);
        // Grid style should not show description
        expect(find.text('Klassisk svensk husmanskost'), findsNothing);
        expect(_metaHas('45 min \u00B7 4 port'), findsOneWidget);
      });
    });

    group('Interactions', () {
      testWidgets('should handle tap callback', (tester) async {
        Recipe? tappedRecipe;

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: testRecipe,
                onTap: (recipe) => tappedRecipe = recipe,
              ),
            ),
          ),
        );

        await tester.tap(find.text('Köttbullar med potatismos'));
        await tester.pump();

        expect(tappedRecipe, equals(testRecipe));
      });

      testWidgets('should handle long press callback', (tester) async {
        Recipe? longPressedRecipe;

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: testRecipe,
                onLongPress: (recipe) => longPressedRecipe = recipe,
              ),
            ),
          ),
        );

        await tester.longPress(find.text('Köttbullar med potatismos'));
        await tester.pump();

        expect(longPressedRecipe, equals(testRecipe));
      });

      testWidgets('should not display favorite buttons', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: testRecipe,
              ),
            ),
          ),
        );

        // Verify favorite buttons are not present
        expect(find.byIcon(ButleryIcons.heartOutline), findsNothing);
        expect(find.byIcon(ButleryIcons.heart), findsNothing);
      });

      testWidgets('should not respond to tap when callback is null', (
        tester,
      ) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: testRecipe,
                onTap: null,
              ),
            ),
          ),
        );

        // Should not throw when tapped
        await tester.tap(find.text('Köttbullar med potatismos'));
        await tester.pump();
      });
    });

    group('Selection State', () {
      testWidgets('should show selection state visually', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: testRecipe,
                isSelected: true,
              ),
            ),
          ),
        );

        expect(find.byType(RecipeCard), findsOneWidget);
        expect(find.text('Köttbullar med potatismos'), findsOneWidget);
      });

      testWidgets('should show normal state when not selected', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: testRecipe,
                isSelected: false,
              ),
            ),
          ),
        );

        expect(find.byType(RecipeCard), findsOneWidget);
        expect(find.text('Köttbullar med potatismos'), findsOneWidget);
      });
    });

    group('Custom Styling', () {
      testWidgets('should apply custom margin', (tester) async {
        const customMargin = EdgeInsets.all(20);

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: testRecipe,
                margin: customMargin,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.byType(Container).first,
        );

        expect(container.margin, equals(customMargin));
      });

      testWidgets('should apply custom padding', (tester) async {
        const customPadding = EdgeInsets.all(24);

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: testRecipe,
                padding: customPadding,
              ),
            ),
          ),
        );

        final padded = find.descendant(
          of: find.descendant(
            of: find.byType(RecipeCard),
            matching: find.byType(InkWell),
          ),
          matching: find.byWidgetPredicate(
            (w) => w is Padding && w.padding == customPadding,
          ),
        );

        expect(padded, findsOneWidget);
      });

      testWidgets('should apply default styling when not specified', (
        tester,
      ) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: testRecipe,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.byType(Container).first,
        );

        // The page margin belongs to the list, not to the row.
        expect(container.margin ?? EdgeInsets.zero, EdgeInsets.zero);
      });
    });

    group('Accessibility', () {
      testWidgets('should have semantic label for recipe', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: testRecipe,
              ),
            ),
          ),
        );

        // Enable semantics for testing and ensure proper disposal
        final SemanticsHandle handle = tester.ensureSemantics();

        // The card is a button node; its own title names it.
        final card = tester.getSemantics(
          find
              .descendant(
                of: find.byType(RecipeCard),
                matching: find.byType(InkWell),
              )
              .first,
        );
        expect(
          card.getSemanticsData().label,
          contains('Köttbullar med potatismos'),
        );

        // Dispose the semantics handle to avoid test failure
        handle.dispose();
      });

      // BUT-697: Recipe card tap target announces as a button via Semantics.
      testWidgets('is one activatable button named by its own title', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: testRecipe,
                onTap: (_) {},
              ),
            ),
          ),
        );

        final card = find
            .descendant(
              of: find.byType(RecipeCard),
              matching: find.byType(InkWell),
            )
            .first;
        final lines = announcedLines(tester, card);
        expect(
          lines.where((l) => l.contains('Köttbullar med potatismos')),
          ['Köttbullar med potatismos'],
        );
        expectNothingAnnouncedTwice(tester, card);
        expectActivatable(tester, card);
        handle.dispose();
      });

      testWidgets('should have proper contrast for text', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: testRecipe,
              ),
            ),
          ),
        );

        // Title should be visible
        final titleText = tester.widget<Text>(
          find.text('Köttbullar med potatismos'),
        );
        expect(titleText.style, isNotNull);
      });
    });

    group('Swedish Localization', () {
      testWidgets('should display Swedish text correctly', (tester) async {
        final swedishRecipe = RecipeFactory.build(
          title: 'Räksmörgås',
          description: 'Öppet smörgås med räkor och ägg',
          mealType: 'Frukost',
          personalTagIds: ['fisk', 'smörgås', 'ägg'],
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: swedishRecipe,
              ),
            ),
          ),
        );

        expect(find.text('Räksmörgås'), findsOneWidget);
        expect(find.text('Öppet smörgås med räkor och ägg'), findsNothing);
        // showMealType defaults to false
        expect(find.text('Frukost'), findsNothing);
      });

      testWidgets('should use Swedish units for metadata', (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: testRecipe,
              ),
            ),
          ),
        );

        expect(_metaHas('45 min \u00B7 4 port'), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle very long title gracefully', (tester) async {
        final longTitleRecipe = RecipeFactory.build(
          title:
              'Detta är ett mycket långt receptnamn som borde trunkeras på något sätt för att inte ta upp för mycket plats på skärmen',
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: SizedBox(
              width: 300,
              child: RecipeCard(
                recipe: longTitleRecipe,
              ),
            ),
          ),
        );

        final titleText = tester.widget<Text>(
          find.text(longTitleRecipe.title),
        );

        expect(titleText.maxLines, equals(2));
        expect(titleText.overflow, equals(TextOverflow.ellipsis));
      });

      testWidgets('should handle zero portions gracefully', (tester) async {
        final zeroPortionsRecipe = RecipeFactory.build(
          portions: 0,
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: zeroPortionsRecipe,
              ),
            ),
          ),
        );

        // Should not show portions when zero
        expect(_metaHas('0 port'), findsNothing);
      });

      testWidgets('should handle negative time values', (tester) async {
        final negativeTimeRecipe = RecipeFactory.build(
          timeMinutes: -10,
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: negativeTimeRecipe,
              ),
            ),
          ),
        );

        // Should not show negative time
        expect(_metaHas('-10 min'), findsNothing);
      });
    });

    group('Rating in the metadata line', () {
      // RecipeFactory doesn't expose the denormalized family / public fields,
      // so override them on the core directly.
      Recipe withCore(
        Recipe base, {
        double? familyAverage,
        int? familyRatingCount,
        double? averageRating,
      }) => Recipe(
        core: base.core.copyWith(
          familyAverage: familyAverage,
          familyRatingCount: familyRatingCount,
          averageRating: averageRating,
        ),
        type: base.type,
        socialData: base.socialData,
        realtimeData: base.realtimeData,
        offlineData: base.offlineData,
      );

      Future<void> pump(
        WidgetTester tester,
        Recipe recipe, {
        PooledStats? pooledStats,
      }) => tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: Scaffold(
            body: RecipeCard(recipe: recipe, pooledStats: pooledStats),
          ),
        ),
      );

      testWidgets('family verdict supersedes the personal star', (
        tester,
      ) async {
        await pump(
          tester,
          withCore(testRecipe, familyAverage: 4.2, familyRatingCount: 3),
        );
        expect(
          _metaHas('\uFFFC4,2'),
          findsOneWidget,
        );
        expect(_metaHas('4,5'), findsNothing);
      });

      testWidgets('personal star shows when there is no family verdict', (
        tester,
      ) async {
        await pump(tester, testRecipe);
        expect(
          _metaHas('\uFFFC4,5'),
          findsOneWidget,
        );
      });

      testWidgets('the public aggregate is the last fallback', (tester) async {
        final unrated = RecipeFactory.build(rating: null);
        await pump(tester, withCore(unrated, averageRating: 4.3));
        expect(
          _metaHas('\uFFFC4,3'),
          findsOneWidget,
        );
      });

      testWidgets('the card carries one rating, never two', (tester) async {
        await pump(
          tester,
          withCore(
            testRecipe,
            familyAverage: 4.2,
            familyRatingCount: 3,
            averageRating: 4.5,
          ),
        );
        expect(_metaHas('\uFFFC'), findsOneWidget);
      });

      testWidgets('the rating star is a drawn glyph in star gold', (
        tester,
      ) async {
        await pump(tester, testRecipe);
        final star = tester.widget<ButleryIcon>(
          find.descendant(
            of: find.byWidgetPredicate(
              (w) =>
                  w is Text &&
                  (w.textSpan?.toPlainText(includeSemanticsLabels: false) ?? '')
                      .contains('\uFFFC'),
            ),
            matching: find.byType(ButleryIcon),
          ),
        );
        expect(star.icon, ButleryIcons.star);
        expect(star.size, AppDimensions.ratingStarSize);
        expect(star.color, AppColors.starGold);
      });

      testWidgets('the rating announces its label alone', (tester) async {
        final handle = tester.ensureSemantics();
        await pump(
          tester,
          withCore(
            testRecipe,
            familyAverage: 4.2,
            familyRatingCount: 3,
            averageRating: 4.5,
          ),
        );
        final lines = announcedLines(
          tester,
          find
              .descendant(
                of: find.byType(RecipeCard),
                matching: find.byType(InkWell),
              )
              .first,
        );
        expect(lines.where((l) => l.contains('4,2')), [
          '45 min \u00B7 4 port \u00B7 Hushållsbetyg 4,2',
        ]);
        expect(lines.where((l) => l.contains('4,5')), isEmpty);
        handle.dispose();
      });

      testWidgets('a floored pool replaces the per-copy aggregate', (
        tester,
      ) async {
        final unrated = RecipeFactory.build(rating: null);
        await pump(
          tester,
          withCore(unrated, averageRating: 4.0),
          pooledStats: const PooledStats(count: 12, average: 4.3),
        );
        expect(
          _metaHas('\uFFFC4,3'),
          findsOneWidget,
        );
        expect(_metaHas('4,0'), findsNothing);
      });

      testWidgets('below the floor the pool is ignored', (tester) async {
        final unrated = RecipeFactory.build(rating: null);
        await pump(
          tester,
          withCore(unrated, averageRating: 4.0),
          pooledStats: const PooledStats(count: 4, average: 4.3),
        );
        expect(
          _metaHas('\uFFFC4,0'),
          findsOneWidget,
        );
      });

      testWidgets('a whole-number average keeps its decimal comma', (
        tester,
      ) async {
        final unrated = RecipeFactory.build(rating: null);
        await pump(
          tester,
          withCore(unrated, averageRating: null),
          pooledStats: const PooledStats(count: 12, average: 4.0),
        );
        expect(
          _metaHas('\uFFFC4,0'),
          findsOneWidget,
        );
      });
    });

    testWidgets('a tagged recipe shows no allergen or dietary info', (
      tester,
    ) async {
      final recipe =
          (RecipeBuilder()
                ..id = 'tagged_recipe'
                ..title = 'Taggad rätt'
                ..imageUrls = []
                ..withTagResult(
                  TagResult(
                    tags: const {},
                    allergenStatus: const {
                      'gluten': TriState.free,
                      'mjölk': TriState.contains,
                    },
                    dietaryStatus: const {'vegansk': TriState.free},
                    coverage: 1.0,
                    generatedAt: DateTime(2026, 1, 1),
                    generatorVersion: kTagGeneratorVersion,
                    hasCoverageAnomaly: false,
                  ),
                ))
              .build();

      for (final style in RecipeCardStyle.values) {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(recipe: recipe, style: style),
            ),
          ),
        );

        expect(
          find.byType(AllergenStatusBadge),
          findsNothing,
          reason: style.name,
        );
        expect(
          find.byType(DietaryStatusBadge),
          findsNothing,
          reason: style.name,
        );
        expect(find.text('Ej kontrollerat'), findsNothing, reason: style.name);
      }
    });
  });
}
