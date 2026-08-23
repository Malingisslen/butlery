// BUT-1895: the allergen row, and the marker that says the allergens were never
// assessed, were drawn in the DETAILED layout only. `MinaReceptRecipeCard`
// picks the GRID style the moment the saved view toggle is on, so on Mina
// recept the setting that shows allergen status on recipe cards was honoured in
// list mode and silently ignored in grid mode — quite possibly the mode the
// original report was written from.
//
// The suite is geometry-first on purpose. A tile used to get its height from a
// grid delegate and so could not grow the way the detailed Column can, and it
// overflowed its own box for EVERY recipe — in a release build that is silent
// clipping with no stripes to see. BUT-1911 removed the delegate; the geometry
// cases stay, because a test that only asserted "the badge widget is in the
// tree" would pass over a tile whose bottom was being cut off.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/widgets/common/content_sized_grid.dart';
import 'package:butlery/widgets/common/content_card.dart';
import 'package:butlery/widgets/recipe/recipe_card.dart';
import 'package:butlery/widgets/tagging/allergen_status_badge.dart';
import 'package:butlery/widgets/tagging/tag_result_display.dart';

import '../../infrastructure/builders/recipe_builder.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  /// A recipe the tagger settled: one FREE allergen and one CONTAINS.
  Recipe assessed() =>
      (RecipeBuilder()
            ..id = 'assessed'
            ..title = 'Köttbullar med potatismos och lingonsylt'
            ..imageUrls = []
            ..withTagResult(
              TagResult(
                tags: const {},
                // Four SETTLED allergens, not two. The geometry cases run on
                // this fixture and their whole subject is how the badge row
                // wraps; an UNKNOWN allergen draws nothing, so a fixture that
                // settles two while the harness tracks four measures a
                // two-badge row under a four-badge name.
                allergenStatus: const {
                  'gluten': TriState.free,
                  'mjölk': TriState.contains,
                  'ägg': TriState.free,
                  'fisk': TriState.free,
                },
                dietaryStatus: const {'vegansk': TriState.free},
                coverage: 1.0,
                generatedAt: DateTime(2026, 1, 1),
                generatorVersion: '1.0',
                hasCoverageAnomaly: false,
              ),
            ))
          .build();

  /// A recipe the tagger settled NOTHING about. Every allergen is UNKNOWN, and
  /// UNKNOWN is not drawn, so the row has nothing to say — which is precisely
  /// when silence would read as "nothing flagged".
  Recipe unassessed() =>
      (RecipeBuilder()
            ..id = 'unassessed'
            ..title = 'Obedömd rätt'
            ..imageUrls = []
            ..withTagResult(
              TagResult(
                tags: const {},
                allergenStatus: const {},
                dietaryStatus: const {},
                coverage: 0.0,
                generatedAt: DateTime(2026, 1, 1),
                generatorVersion: '1.0',
                hasCoverageAnomaly: false,
              ),
            ))
          .build();

  /// Everything a screen reader would announce, as one string.
  ///
  /// Flattened deliberately: a card merges its whole subtree into a single
  /// node whose label is newline-joined, so asking whether a given wording is
  /// announced is a question about that joined text, not about which node it
  /// landed on. The screen-reader wording of a marker is a string no visual
  /// assertion can see, so it needs its own read of the tree.
  String semanticsLabels(WidgetTester tester) {
    final labels = <String>[];
    void walk(SemanticsNode node) {
      if (node.label.isNotEmpty) labels.add(node.label);
      node.visitChildren((child) {
        walk(child);
        return true;
      });
    }

    walk(tester.binding.rootElement!.renderObject!.debugSemantics!);
    return labels.join('\n');
  }

  Future<void> pumpCard(
    WidgetTester tester, {
    required Recipe recipe,
    required RecipeCardStyle style,
    Set<String>? allergenPrefs = const {'gluten', 'mjölk'},
    Set<String>? dietaryPrefs,
  }) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: Scaffold(
          // Wide enough that the DETAILED layout's own rows are not the thing
          // under test. It used to be load-bearing for a different reason —
          // the completeness chip overflowed in a narrow box — and that is no
          // longer true: all three chips wrap since BUT-1911.
          body: SizedBox(
            width: 360,
            child: RecipeCard(
              recipe: recipe,
              style: style,
              showAllergenBadges: true,
              userAllergenPrefs: allergenPrefs,
              showDietaryBadges: dietaryPrefs != null,
              userDietaryPrefs: dietaryPrefs,
            ),
          ),
        ),
      ),
    );
  }

  group('the allergen row reaches the grid layout', () {
    testWidgets('grid draws the badges', (tester) async {
      await pumpCard(
        tester,
        recipe: assessed(),
        style: RecipeCardStyle.grid,
      );

      expect(find.byType(CompactAllergenRow), findsOneWidget);
      expect(find.byType(AllergenStatusBadge), findsWidgets);
    });

    testWidgets('detailed still draws them', (tester) async {
      // The same assertion against the layout the fix did NOT touch, so a
      // regression there cannot hide behind a green grid case.
      await pumpCard(
        tester,
        recipe: assessed(),
        style: RecipeCardStyle.detailed,
      );

      expect(find.byType(CompactAllergenRow), findsOneWidget);
    });

    testWidgets('grid draws the unassessed marker when it has nothing to say', (
      tester,
    ) async {
      // Shipping the row without this marker would reopen, in the grid, the
      // exact bug the marker was built to close: on a screen of mostly-green
      // cards a silent card reads as "nothing flagged".
      await pumpCard(
        tester,
        recipe: unassessed(),
        style: RecipeCardStyle.grid,
      );

      expect(find.byType(CompactAllergenRow), findsNothing);
      expect(find.text('Allergener ej bedömda'), findsOneWidget);
    });

    testWidgets('the marker carries its screen-reader text in the grid too', (
      tester,
    ) async {
      // The marker's screen-reader wording is a SEPARATE string from the chip's
      // visible one, and it was the only user-visible surface of BUT-1780 with
      // no coverage at all — so it could be deleted today in silence.
      //
      // Read off the accessibility TREE rather than through
      // `find.bySemanticsLabel`. The card contributes ONE semantics node for
      // its whole subtree, so this announcement arrives as one newline-joined
      // line inside the card's merged label — an exact-match finder aimed at
      // the string alone reports zero for a label that is demonstrably there.
      //
      // `ensureSemantics` is not optional either: without it no accessibility
      // tree is built in a widget test at all.
      final handle = tester.ensureSemantics();

      await pumpCard(
        tester,
        recipe: unassessed(),
        style: RecipeCardStyle.grid,
      );

      expect(
        semanticsLabels(tester),
        contains('Allergener är inte bedömda för det här receptet'),
        reason:
            'this string is what a screen reader announces about the marker, '
            'and nothing else in the suite reads it',
      );

      // Disposed here rather than in addTearDown: the framework verifies that
      // no handle is live BEFORE tear-downs run, so a deferred dispose fails
      // the test after its assertion has already passed.
      handle.dispose();
    });

    testWidgets('the user turning badges off silences the grid as well', (
      tester,
    ) async {
      // An empty set, not null, because that is the branch worth pinning: an
      // opted-out user reaches the card with NULL
      // (`showOnCards ? trackedAllergens : null`), which the sibling test in
      // `test/views/` covers.
      //
      // The empty set arrives from that SAME call site, with `showOnCards` left
      // on and `trackedAllergens` empty — onboarding persists exactly that for
      // a "vegan, no allergies" answer, since it writes preferences whenever
      // EITHER set is non-empty. That is the case `_allergenBadgesRequested`
      // exists for. Neither the row nor the marker may appear.
      //
      // (The ungated detail-view call site feeds `TagResultDisplay`, where an
      // empty set means the OPPOSITE — show every allergen the tagger settled —
      // so it cannot reach this branch. An earlier version of this comment said
      // it could.)
      await pumpCard(
        tester,
        recipe: assessed(),
        style: RecipeCardStyle.grid,
        allergenPrefs: const <String>{},
      );

      expect(find.byType(CompactAllergenRow), findsNothing);
      expect(find.text('Allergener ej bedömda'), findsNothing);
    });

    testWidgets('the compact layout is deliberately unchanged', (tester) async {
      // The 60px compact row is a separate design call and was left out of this
      // change on purpose. Pinned so the omission is a decision on the record
      // rather than something that looks like an oversight.
      await pumpCard(
        tester,
        recipe: assessed(),
        style: RecipeCardStyle.compact,
      );

      expect(find.byType(CompactAllergenRow), findsNothing);
    });
  });

  group('a grid tile holds its content at every text size', () {
    // These cases build their grid from `ContentSizedGrid`, the SAME widget
    // Mina recept builds its grid from — imported, not reproduced. The
    // previous version of this suite imported the production aspect ratio for
    // the same reason, and the reason outlived the number: a layout copied
    // into a test goes stale silently, and the suite then reports on a grid
    // the app no longer ships.
    //
    // The widths are held to ONE standard — clean everywhere — and that is the
    // change. The old suite had to record a boundary instead, because an
    // aspect ratio cannot be right at both ends.
    //
    // 280dp is below the two-column threshold, so it is here to prove the
    // single-column fallback and not a two-column tile: measured, two columns
    // at that width leaves the title row 48 logical pixels while its two
    // trailing icons alone need 52.
    const geometries = <String, Size>{
      '412dp phone': Size(1236, 2600),
      '360dp phone': Size(1080, 2400),
      '320dp phone': Size(960, 1704),
      '280dp phone': Size(840, 1704),
    };

    Future<void> pumpGrid(
      WidgetTester tester, {
      required Size size,
      required double scale,
      Set<String> allergenPrefs = const {'gluten', 'mjölk', 'ägg', 'fisk'},
      Recipe? recipe,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              // A second Builder, and it is load-bearing: the card must read
              // the text scale from BELOW the MediaQuery above, exactly as the
              // view's own build does. Reading it from the outer context
              // silently measures an unscaled tile, which happened here once.
              child: Builder(
                builder: (context) => Scaffold(
                  body: ContentSizedGrid(
                    padding: const EdgeInsets.all(16),
                    spacing: 16,
                    // The app's own rule, not a hardcoded 2. A test that pins
                    // two columns at a width the app renders in one reports
                    // coverage it does not have.
                    columns: AppDimensions.recipeGridColumns(context),
                    itemCount: 2,
                    itemBuilder: (context, _) => ContentCard(
                      item: recipe ?? assessed(),
                      type: ContentCardType.recipe,
                      style: ContentCardStyle.grid,
                      userAllergenPrefs: allergenPrefs,
                      // `MinaReceptRecipeCard` always passes one outside
                      // selection mode, and it puts a 32px button in the title
                      // row. Without it the harness measures a card the screen
                      // never draws — and the title row is the tightest thing
                      // on a narrow tile.
                      onFavoriteToggle: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    for (final entry in geometries.entries) {
      for (final scale in <double>[1.0, 1.3, 1.5, 1.75, 2.0]) {
        testWidgets('no overflow on a ${entry.key} at text scale $scale', (
          tester,
        ) async {
          await pumpGrid(tester, size: entry.value, scale: scale);

          // Premise first: "no overflow" is satisfied for free by a tile that
          // rendered nothing. Without this line a regression in ContentCard's
          // badge derivation would turn the whole group green while measuring
          // the wrong tile.
          expect(
            find.byType(CompactAllergenRow),
            findsWidgets,
            reason:
                'the geometry cases must be measuring a tile that actually '
                'draws the badge row whose wrapping is the thing under test',
          );
          // And the row must carry FOUR badges, not merely be present. The
          // row collapses to nothing when empty, so its presence proves one
          // badge — never four. Lower `maxBadges` in `_buildGridLayout` from
          // 4 to 2, a plausible narrow-tile tweak, and every case here stays
          // green while measuring a row half the width of the one the fixture
          // was built to produce.
          expect(
            find.byType(AllergenStatusBadge),
            findsNWidgets(8),
            reason: 'four settled allergens on each of two cards',
          );

          expect(
            tester.takeException(),
            isNull,
            reason:
                'nothing in a grid tile may be clipped away — in a release '
                'build there are no stripes to see, only missing content: '
                '${entry.key} at scale $scale',
          );
        });

        testWidgets(
          'no overflow on the unassessed marker, ${entry.key} at scale $scale',
          (tester) async {
            // The OTHER thing a grid tile can draw, and the loop above cannot
            // see it: an assessed recipe draws the badge row INSTEAD of this
            // marker, so twenty green cases said nothing about a chip that
            // overflowed at every width and every text size. It is the marker
            // that stops a quiet card reading as "nothing flagged", so a
            // clipped one is worse than a missing one.
            await pumpGrid(
              tester,
              size: entry.value,
              scale: scale,
              recipe: unassessed(),
            );

            expect(
              find.textContaining('bedömda'),
              findsWidgets,
              reason: 'the premise: this tile must draw the marker at all',
            );
            expect(
              find.byType(CompactAllergenRow),
              findsNothing,
              reason:
                  'and it must be drawing the marker INSTEAD of the badge row '
                  '— otherwise this case duplicates the one above',
            );
            expect(
              tester.takeException(),
              isNull,
              reason:
                  'the unassessed marker must not be clipped either: '
                  '${entry.key} at scale $scale',
            );
          },
        );
      }
    }

    testWidgets('the picture survives at the largest text size', (
      tester,
    ) async {
      // The bug this replaced was not only clipped text. The image was the
      // slack in a fixed box, so it lost its height first — on the narrower
      // phones it reached zero outright while the text kept growing. A card
      // sized to its own content cannot do that, and this is the assertion
      // that reddens if a fixed tile height ever comes back — the no-overflow
      // cases above do not, since a collapsed image leaves MORE room, not
      // less.
      await pumpGrid(
        tester,
        size: const Size(960, 1704),
        scale: 2.0,
        allergenPrefs: const {'gluten', 'mjölk'},
      );

      // The invariant is the SHAPE, not a pixel count: the photo is the one
      // fixed dimension left in the card, so it keeps its declared ratio no
      // matter how tall the text under it grows. A pixel threshold would have
      // to be re-tuned for every screen width and would say nothing about why.
      final photo = tester.getRect(
        find
            .descendant(
              of: find.byType(RecipeCard).first,
              matching: find.byType(AspectRatio),
            )
            .first,
      );
      expect(photo.width, greaterThan(0));
      // The LITERAL 0.75, not `recipeGridImageAspectRatio`. Dividing by the
      // same constant the widget reads restates `AspectRatio`'s own guarantee
      // and cannot fail; the finder above is then the only thing doing work.
      // The number is the covered fact here, so it is written out.
      expect(
        photo.height,
        closeTo(photo.width * 0.75, 0.5),
        reason:
            'the recipe photo must keep its 4:3 shape at 2x on a 320dp phone '
            '— it was the slack in a fixed box before BUT-1911 and rendered '
            'zero pixels tall there',
      );
    });

    testWidgets('the grid draws no dietary row', (tester) async {
      // A decision, not an omission (BUT-1906, Malin 2026-08-23). A dietary
      // badge carries its WORD and the word does not fit: the row has 88
      // logical pixels on a 360dp tile and 68 on a 320dp one, while "vegansk"
      // needs 111 and "vegetarisk" 145 at NORMAL text size, growing to 188 and
      // 255 at 2x. Icon-only was the alternative and it does not exist — the
      // badge takes its icon from the STATUS, so both diets render the same
      // green leaf.
      //
      // `assessed()` is FREE on a diet and the card is handed dietary
      // preferences, so this case fails the moment the row is added back.
      await pumpCard(
        tester,
        recipe: assessed(),
        style: RecipeCardStyle.grid,
        dietaryPrefs: const {'vegansk'},
      );

      expect(find.byType(CompactDietaryRow), findsNothing);
      expect(find.textContaining('vegansk'), findsNothing);
    });

    testWidgets('the detailed layout still draws it', (tester) async {
      // The control. Without it the case above is satisfied by a card that
      // lost the dietary row everywhere, which is a different, worse bug.
      await pumpCard(
        tester,
        recipe: assessed(),
        style: RecipeCardStyle.detailed,
        dietaryPrefs: const {'vegansk'},
      );

      expect(find.byType(CompactDietaryRow), findsOneWidget);
      expect(find.textContaining('vegansk'), findsWidgets);
    });
  });
}
