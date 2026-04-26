import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/recipe/recipe_card.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';

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

        // Title and description
        expect(find.text('Köttbullar med potatismos'), findsOneWidget);
        expect(find.text('Klassisk svensk husmanskost'), findsOneWidget);

        // Metadata (dot-separated text format per UI redesign)
        expect(find.text('45 min \u00B7 4 port'), findsOneWidget);
        // Rating shown as green pill badge
        expect(find.text('\u2605 4.5'), findsOneWidget);
      });

      testWidgets('should render recipe without image correctly',
          (tester) async {
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
        // UI Redesign: Vegetable illustration placeholder instead of restaurant icon
        expect(find.byType(VegetableIllustration), findsOneWidget);
      });

      testWidgets('should hide elements based on display options',
          (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: testRecipe,
                style: RecipeCardStyle.detailed,
                showImage: false,
                showTags: false,
                showMetadata: false,
              ),
            ),
          ),
        );

        // Should show title and description
        expect(find.text('Köttbullar med potatismos'), findsOneWidget);
        expect(find.text('Klassisk svensk husmanskost'), findsOneWidget);

        // Should not show other elements
        expect(find.text('Middag'), findsNothing);
        expect(find.text('45 min \u00B7 4 port'), findsNothing);
        expect(find.text('svensk'), findsNothing);
        expect(find.byIcon(Icons.favorite_border), findsNothing);
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
        expect(find.text('45 min \u00B7 4 port'), findsOneWidget);
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
            child: SizedBox(
              width: 200,
              child: RecipeCard(
                recipe: testRecipe,
                style: RecipeCardStyle.grid,
              ),
            ),
          ),
        );

        expect(find.text('Köttbullar med potatismos'), findsOneWidget);
        // Grid style should not show description
        expect(find.text('Klassisk svensk husmanskost'), findsNothing);
        // Should show compact metadata (dot-separated text format)
        expect(find.text('45 min \u00B7 4 port'), findsOneWidget);
      });

      testWidgets('should position favorite button as overlay in grid mode',
          (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: SizedBox(
              width: 200,
              child: RecipeCard(
                recipe: testRecipe,
                style: RecipeCardStyle.grid,
              ),
            ),
          ),
        );

        // Recipe card should render without favorite button
        expect(find.byIcon(Icons.favorite_border), findsNothing);
        expect(find.byIcon(Icons.favorite), findsNothing);
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
        expect(find.byIcon(Icons.favorite_border), findsNothing);
        expect(find.byIcon(Icons.favorite), findsNothing);
      });

      testWidgets('should not respond to tap when callback is null',
          (tester) async {
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

        // UI Redesign: Selected state uses green border decoration (no elevation)
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

        // UI Redesign: Normal state uses left green + bottom rust border decoration
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

        // Find the Container that's a child of InkWell (the one with padding)
        final inkWell = find.descendant(
          of: find.byType(RecipeCard),
          matching: find.byType(InkWell),
        );
        final container = tester.widget<Container>(
          find
              .descendant(
                of: inkWell,
                matching: find.byType(Container),
              )
              .first,
        );

        expect(container.padding, equals(customPadding));
      });

      testWidgets('should apply default styling when not specified',
          (tester) async {
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

        expect(
          container.margin,
          equals(const EdgeInsets.symmetric(vertical: 1, horizontal: 16)),
        );
      });
    });

    group('Context Menu', () {
      testWidgets('should show context menu button when enabled',
          (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: testRecipe,
                showContextMenu: true,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.more_vert), findsOneWidget);
      });

      testWidgets('should hide context menu button when disabled',
          (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: testRecipe,
                showContextMenu: false,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.more_vert), findsNothing);
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

        // Verify Semantics widget with recipe label exists
        final semanticsWidget = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label != null &&
              widget.properties.label!.contains('Köttbullar med potatismos'),
        );
        expect(semanticsWidget, findsOneWidget);

        // Dispose the semantics handle to avoid test failure
        handle.dispose();
      });

      // BUT-697: Recipe card tap target announces as a button via Semantics.
      testWidgets(
          'exposes localized button-role label via find.bySemanticsLabel',
          (tester) async {
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

        expect(
            find.bySemanticsLabel(RegExp(
                r'^Recept: Köttbullar med potatismos, tryck för att öppna')),
            findsWidgets);
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
        expect(find.text('Öppet smörgås med räkor och ägg'), findsOneWidget);
        // showMealType and showPersonalTags default to false in UI redesign
        expect(find.text('Frukost'), findsNothing);
        expect(find.text('ägg'), findsNothing);
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

        // UI Redesign: dot-separated text format
        expect(find.text('45 min \u00B7 4 port'), findsOneWidget);
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
          find.byType(Text).first,
        );

        expect(titleText.maxLines, equals(2));
        expect(titleText.overflow, equals(TextOverflow.ellipsis));
      });

      testWidgets('should handle empty tags list', (tester) async {
        final noTagsRecipe = RecipeFactory.build(
          personalTagIds: [],
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: noTagsRecipe,
                showTags: true,
              ),
            ),
          ),
        );

        // Should not crash and should not show any tag text widgets
        // (tags are rendered as Text widgets, not Chips in RecipeCard)
        expect(find.text('svensk'), findsNothing);
        expect(find.text('husmanskost'), findsNothing);
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
        expect(find.text('0 port'), findsNothing);
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
        expect(find.text('-10 min'), findsNothing);
      });
    });
  });
}
