/// BUT-1308 (BUT-710 follow-up): pin that RecipeCard mounts a HoverableCard
/// ancestor whose rest decoration carries the square / design-token treatment.
///
/// Intent: BUT-710 wrapped the custom cards in HoverableCard to give them a
/// hover affordance on web/desktop. These render tests guard against a future
/// refactor silently dropping the HoverableCard wrapper or swapping the square
/// design-token decoration for a rounded / ad-hoc one.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/components/input_themes.dart';
import 'package:butlery/widgets/common/hoverable_card.dart';
import 'package:butlery/widgets/recipe/recipe_card.dart';

import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';

/// Paints an ink highlight in [color]: any drawRRect whose paint is exactly
/// it. `paints..rrect` would stop at the first, transparent, rrect the
/// enclosing Material draws.
PaintPattern paintsRaisedHighlight(Color color) => paints
  ..something(
    (Symbol method, List<dynamic> arguments) =>
        method == #drawRRect &&
        (arguments[1] as Paint).color.toARGB32() == color.toARGB32(),
  );

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
        // Three ingredients keep the recipe above the completeness threshold:
        // the incomplete chip is a surface.raised fill, and the highlight
        // matcher below counts any raised rrect the card draws.
        ingredients: const ['Köttfärs', 'Ströbröd', 'Mjölk'],
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
        late ColorScheme cs;
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  cs = Theme.of(context).colorScheme;
                  return RecipeCard(recipe: testRecipe, onTap: (_) {});
                },
              ),
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
        expect(
          rest.borderRadius,
          isNull,
          reason: 'Recipe card must stay square — no BorderRadius.',
        );
        expect(rest.border, isA<Border>());

        // Hover fills to surface.raised (B83-1 = A, BUT-2183); border +
        // corners stay identical so the square treatment is preserved under
        // the cursor.
        final hover = hoverable.hoverDecoration as BoxDecoration;
        expect(hover.border, equals(rest.border));
        expect(hover.borderRadius, isNull);
        expect(
          hover.color,
          cs.surfaceContainerHighest,
          reason:
              'Pressed/hover on rows, cards and icon buttons fills to '
              'surface.raised.',
        );
      },
    );

    // BUT-1308: drive a real mouse pointer over the card and assert the
    // RENDERED decoration lifts to the hover variant, then reverts on exit.
    // This exercises _HoverableCardState's onEnter/onExit wiring — removing it
    // would make this test fail, unlike the constructor-arg assertions above.
    testWidgets(
      'pointer enter lifts rendered decoration to hover variant '
      '(surface.raised), exit reverts',
      (tester) async {
        late ColorScheme cs;
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  cs = Theme.of(context).colorScheme;
                  return RecipeCard(recipe: testRecipe, onTap: (_) {});
                },
              ),
            ),
          ),
        );

        final hoverable = tester.widget<HoverableCard>(
          find.descendant(
            of: find.byType(RecipeCard),
            matching: find.byType(HoverableCard),
          ),
        );
        final restDecoration = hoverable.restDecoration;
        final hoverDecoration = hoverable.hoverDecoration;

        // The decoration is painted by the AnimatedContainer inside HoverableCard.
        Decoration? renderedDecoration() {
          final container = tester.widget<AnimatedContainer>(
            find.descendant(
              of: find.byType(HoverableCard),
              matching: find.byType(AnimatedContainer),
            ),
          );
          return container.decoration;
        }

        // At rest (no pointer), the rendered decoration is the rest variant.
        expect(renderedDecoration(), equals(restDecoration));

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);

        // Move the cursor onto the card → onEnter fires → hover decoration paints.
        await gesture.moveTo(tester.getCenter(find.byType(HoverableCard)));
        await tester.pumpAndSettle();
        expect(
          renderedDecoration(),
          equals(hoverDecoration),
          reason:
              'Pointer entering the card must lift the rendered decoration '
              'to the hover variant (BUT-710 hover feature).',
        );
        expect(
          (renderedDecoration() as BoxDecoration).color,
          cs.surfaceContainerHighest,
          reason:
              'A real mouse hover must paint surface.raised (B83-1 = A, BUT-2183).',
        );

        // Move the cursor to a point guaranteed outside the card's hit area →
        // onExit fires → reverts to rest. (The card's MouseRegion covers its
        // margin, so Offset.zero is not reliably outside; use just past the
        // bottom-right corner of the rendered card.)
        final cardRect = tester.getRect(find.byType(HoverableCard));
        await gesture.moveTo(cardRect.bottomRight + const Offset(50, 50));
        await tester.pumpAndSettle();
        expect(
          renderedDecoration(),
          equals(restDecoration),
          reason:
              'Pointer leaving the card must revert to the rest '
              'decoration.',
        );
      },
    );

    testWidgets(
      'tappable card renders a click cursor; non-tappable defers the cursor',
      (tester) async {
        // The cursor is the observable affordance the user sees, so assert the
        // RENDERED MouseRegion.cursor rather than reading the enabled bool.
        MouseCursor cursorOf(Finder cardFinder) {
          final mouseRegion = tester.widget<MouseRegion>(
            find
                .descendant(
                  of: cardFinder,
                  matching: find.byType(MouseRegion),
                )
                .first,
          );
          return mouseRegion.cursor;
        }

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(recipe: testRecipe, onTap: (_) {}),
            ),
          ),
        );
        expect(
          cursorOf(find.byType(HoverableCard)),
          SystemMouseCursors.click,
          reason: 'A card with an onTap must show the click cursor.',
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(recipe: testRecipe),
            ),
          ),
        );
        expect(
          cursorOf(find.byType(HoverableCard)),
          MouseCursor.defer,
          reason: 'A card with no onTap should not imply clickability.',
        );
      },
    );

    // BUT-1313: the isSelected:true branch swaps in a distinct green-outline
    // decoration (multi-select / bulk-action affordance). It is genuine
    // user-visible logic — a refactor that dropped the selected styling would
    // make the user unable to see which cards are selected — and was previously
    // untested: every other case builds the unselected card.
    testWidgets('selected card renders the green-outline selected decoration', (
      tester,
    ) async {
      // Capture the live theme so a forestGreen→cs.primary token migration
      // does not break this test (the "no hardcoded theme value" rule).
      late ColorScheme cs;
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: Scaffold(
            body: Builder(
              builder: (context) {
                cs = Theme.of(context).colorScheme;
                return RecipeCard(
                  recipe: testRecipe,
                  isSelected: true,
                  onTap: (_) {},
                );
              },
            ),
          ),
        ),
      );

      final hoverable = tester.widget<HoverableCard>(
        find.descendant(
          of: find.byType(RecipeCard),
          matching: find.byType(HoverableCard),
        ),
      );
      final selected = hoverable.restDecoration as BoxDecoration;

      // Distinct from the unselected square token: the selected state is a
      // rounded primary-tinted fill with a primary outline (BUT-948 bulk
      // multi-select affordance).
      expect(
        selected,
        isNot(equals(InputThemes.recipeCardDecoration)),
        reason:
            'Selected card must use its own decoration, not the default '
            'recipe-card token.',
      );
      final border = selected.border as Border;
      expect(
        border.top.color,
        cs.onSurface,
        reason:
            'Selected outline is text.primary (ink on light, paper on dark) '
            'so the user can see which cards are selected (#flerbar).',
      );
      expect(
        selected.borderRadius,
        isNotNull,
        reason:
            'Selected state uses a rounded outline (distinct from the '
            'square unselected card).',
      );
      // P4-U04: surface.selected, never a tint (tokens.json:116-119,
      // opacityLadder :40-53).
      expect(
        selected.color,
        cs.surfaceContainerHighest,
        reason: 'Selected fill is surface.selected, fully opaque.',
      );
    });

    testWidgets(
      'hover does NOT override the selected decoration under the cursor',
      (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: testRecipe,
                isSelected: true,
                onTap: (_) {},
              ),
            ),
          ),
        );

        final hoverable = tester.widget<HoverableCard>(
          find.descendant(
            of: find.byType(RecipeCard),
            matching: find.byType(HoverableCard),
          ),
        );
        final selectedRest = hoverable.restDecoration as BoxDecoration;

        Decoration? renderedDecoration() {
          final container = tester.widget<AnimatedContainer>(
            find.descendant(
              of: find.byType(HoverableCard),
              matching: find.byType(AnimatedContainer),
            ),
          );
          return container.decoration;
        }

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);

        await gesture.moveTo(tester.getCenter(find.byType(HoverableCard)));
        await tester.pumpAndSettle();

        // The card derives its hover variant from the selected decoration, so the
        // hover shadow may deepen — but the user-visible selected affordance
        // (primary outline + rounded fill) must NOT be replaced by the plain
        // unselected square token, and the border/corners must stay the selected
        // ones so the selection remains visible while hovered.
        final rendered = renderedDecoration() as BoxDecoration;
        expect(
          rendered.border,
          equals(selectedRest.border),
          reason:
              'Hovering a selected card must keep the selected outline — '
              'hover must not strip the selection affordance.',
        );
        expect(
          rendered.borderRadius,
          equals(selectedRest.borderRadius),
          reason:
              'Hovering a selected card must keep the selected (rounded) '
              'corners.',
        );
        expect(
          rendered.color,
          equals(selectedRest.color),
          reason: 'Hovering a selected card must keep the selected fill tint.',
        );
        expect(
          rendered,
          isNot(equals(InputThemes.recipeCardDecoration)),
          reason:
              'Hover must never replace the selected decoration with the '
              'unselected recipe-card token.',
        );
      },
    );

    testWidgets(
      'pressing the card paints surface.raised as the ink highlight, '
      'not the default rust/grey tint (B83-1 = A, BUT-2183)',
      (tester) async {
        late ColorScheme cs;
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  cs = Theme.of(context).colorScheme;
                  return RecipeCard(recipe: testRecipe, onTap: (_) {});
                },
              ),
            ),
          ),
        );

        final ink = tester.renderObject(
          find
              .ancestor(
                of: find.descendant(
                  of: find.byType(RecipeCard),
                  matching: find.byType(InkWell),
                ),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(ink, isNot(paintsRaisedHighlight(cs.surfaceContainerHighest)));

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(InkWell).first),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          ink,
          paintsRaisedHighlight(cs.surfaceContainerHighest),
          reason: 'Pressed on a card fills to surface.raised.',
        );

        await gesture.up();
        await tester.pumpAndSettle();
      },
    );
  });
}
