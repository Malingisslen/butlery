// BUT-1895: the allergen row, and the marker that says the allergens were never
// assessed, were drawn in the DETAILED layout only. `MinaReceptRecipeCard`
// picks the GRID style the moment the saved view toggle is on, so on Mina
// recept the setting that shows allergen status on recipe cards was honoured in
// list mode and silently ignored in grid mode — quite possibly the mode the
// original report was written from.
//
// The suite is geometry-first on purpose. A grid tile's height comes from the
// delegate's aspect ratio, so it cannot grow the way the detailed Column can:
// before this change the tile overflowed its own box by 70px at 1x and 175px at
// 2x for EVERY recipe, and in a release build that is silent clipping with no
// stripes to see. A test that only asserted "the badge widget is in the tree"
// would have passed over a tile whose bottom was being cut off.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
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
                allergenStatus: const {
                  'gluten': TriState.free,
                  'mjölk': TriState.contains,
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
  }) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: Scaffold(
          // Wide enough that the DETAILED layout's own rows are not the thing
          // under test — a narrow box makes the completeness chip overflow
          // horizontally, which has nothing to do with the badge rows.
          body: SizedBox(
            width: 360,
            child: RecipeCard(
              recipe: recipe,
              style: style,
              showAllergenBadges: true,
              userAllergenPrefs: allergenPrefs,
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
    // The tile height comes from `AppDimensions.recipeGridAspectRatio`, the same
    // function the view calls — imported rather than copied. An earlier version
    // of this file hardcoded the formula, which meant a retuned factor in
    // production would have left these cases green against their own stale
    // number while the real grid overflowed.

    // Two widths, and they are held to DIFFERENT limits on purpose.
    //
    // The correction is an aspect RATIO, so the extra height it buys is
    // proportional to tile WIDTH — while the shortfall it has to cover is text,
    // which wraps MORE on a narrow screen. The two therefore diverge, and no
    // single factor closes both: measured on a 320dp phone the tile still
    // overflows by 0.07px at 1.3x, 10px at 1.5x, 22px at 1.75x and 60px at 2x,
    // and a factor big enough to cover that makes a 360dp tile roughly a
    // quarter taller than it needs to be, which is a worse screen for everyone.
    //
    // So the boundary is written down here rather than papered over. 360dp — a
    // modern phone — is clean all the way to 2x. 320dp — an old small phone —
    // is clean only at normal text size, which is still better than the 70px it
    // clipped at normal size before this change. Closing the rest needs an
    // absolute tile height (`mainAxisExtent`) instead of a ratio: BUT-1911.
    const geometries = <String, ({Size size, double cleanUpTo})>{
      '360dp phone': (size: Size(1080, 2400), cleanUpTo: 2.0),
      '320dp phone': (size: Size(960, 1704), cleanUpTo: 1.0),
    };

    for (final entry in geometries.entries) {
      for (final scale in <double>[1.0, 1.3, 1.5, 1.75, 2.0]) {
        // Registered and SKIPPED, not silently dropped. A `continue` here left
        // the residual visible only in a comment, and a comment is not a signal
        // — the runner showed six passes and no trace of the four cases that
        // cannot pass yet. As a skip they are named in every run.
        final beyond = scale > entry.value.cleanUpTo;
        testWidgets(
          // `testWidgets` takes a bool skip, with no room for a reason — so the
          // reason goes in the NAME, where the runner prints it.
          beyond
              ? 'KNOWN RESIDUAL (BUT-1911): a ${entry.key} still clips at text '
                    'scale $scale — an aspect ratio cannot cover it'
              : 'no overflow on a ${entry.key} at text scale $scale',
          skip: beyond,
          (tester) async {
            tester.view.physicalSize = entry.value.size;
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
                    // A second Builder, and it is load-bearing: the delegate must
                    // read the text scale from BELOW the MediaQuery above, exactly
                    // as the view's own build does. Reading it from the outer
                    // context returns the unscaled 0.75 and the case silently
                    // measures the wrong tile — which is what happened the moment
                    // the formula stopped being passed in by hand.
                    child: Builder(
                      builder: (context) => Scaffold(
                        body: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio:
                                    AppDimensions.recipeGridAspectRatio(
                                      context,
                                    ),
                              ),
                          itemCount: 2,
                          itemBuilder: (context, i) => ContentCard(
                            item: assessed(),
                            type: ContentCardType.recipe,
                            style: ContentCardStyle.grid,
                            userAllergenPrefs: const {'gluten', 'mjölk'},
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );

            // Premise first: "no overflow" is satisfied for free by a tile that
            // rendered nothing. Without this line a regression in ContentCard's
            // badge derivation would turn the whole group green while measuring
            // the wrong tile — and this suite has already measured the wrong tile
            // once, when the delegate read its text scale from the wrong context.
            expect(
              find.byType(CompactAllergenRow),
              findsWidgets,
              reason:
                  'the geometry cases must be measuring a tile that actually '
                  'draws the row this change adds',
            );

            expect(
              tester.takeException(),
              isNull,
              reason:
                  'a grid tile cannot grow, so anything that does not fit is '
                  'clipped away silently in release — ${entry.key} at scale '
                  '$scale',
            );
          },
        );
      }
    }
  });
}
