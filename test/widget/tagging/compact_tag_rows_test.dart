import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/widgets/tagging/allergen_status_badge.dart';
import 'package:butlery/widgets/tagging/dietary_status_badge.dart';
import 'package:butlery/widgets/tagging/tag_result_display.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

/// Creates a TagResult with specific allergen and dietary statuses for testing.
TagResult _buildTagResult({
  Map<String, TriState>? allergenStatus,
  Map<String, TriState>? dietaryStatus,
  double coverage = 1.0,
}) {
  return TagResult(
    tags: {},
    allergenStatus: allergenStatus ?? {},
    dietaryStatus: dietaryStatus ?? {},
    coverage: coverage,
    generatedAt: DateTime(2026, 1, 1),
    generatorVersion: '1.0',
    hasCoverageAnomaly: false,
  );
}

void main() {
  group('CompactDietaryRow', () {
    group('Bug 1a regression - all FREE diets render', () {
      testWidgets(
        'should render all three dietary badges when barnvanlig, graviditetssaker, and notkottsfri are FREE',
        (WidgetTester tester) async {
          final tagResult = _buildTagResult(
            dietaryStatus: {
              'barnvänlig': TriState.free,
              'graviditetssäker': TriState.free,
              'nötkötsfri': TriState.free,
            },
          );

          await tester.pumpWidget(
            createLocalizedTestApp(
              wrapInScrollView: true,
              child: CompactDietaryRow(
                tagResult: tagResult,
                // No userPrefs - should show all FREE diets from DietaryConfig order
                maxBadges: 10,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // All three FREE diets should produce DietaryStatusBadge widgets
          expect(find.byType(DietaryStatusBadge), findsNWidgets(3));
        },
      );

      testWidgets(
        'should render badges with eco_outlined icon for FREE dietary status',
        (WidgetTester tester) async {
          final tagResult = _buildTagResult(
            dietaryStatus: {
              'barnvänlig': TriState.free,
              'graviditetssäker': TriState.free,
            },
          );

          await tester.pumpWidget(
            createLocalizedTestApp(
              wrapInScrollView: true,
              child: CompactDietaryRow(
                tagResult: tagResult,
                maxBadges: 10,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // DietaryStatusBadge FREE uses Icons.eco_outlined
          expect(find.byIcon(Icons.eco_outlined), findsNWidgets(2));
        },
      );
    });

    group('User prefs filter', () {
      testWidgets('should only show diets in userPrefs when provided', (
        WidgetTester tester,
      ) async {
        final tagResult = _buildTagResult(
          dietaryStatus: {
            'vegetarisk': TriState.free,
            'vegansk': TriState.free,
            'barnvänlig': TriState.free,
          },
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: CompactDietaryRow(
              tagResult: tagResult,
              userPrefs: const {'vegetarisk', 'barnvänlig'},
              maxBadges: 10,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Only vegetarisk and barnvanlig should render (vegansk filtered out)
        expect(find.byType(DietaryStatusBadge), findsNWidgets(2));
      });

      testWidgets('should show nothing when userPrefs diets are not FREE', (
        WidgetTester tester,
      ) async {
        final tagResult = _buildTagResult(
          dietaryStatus: {
            'vegetarisk': TriState.contains,
            'vegansk': TriState.unknown,
          },
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: CompactDietaryRow(
              tagResult: tagResult,
              userPrefs: const {'vegetarisk', 'vegansk'},
              maxBadges: 10,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // None are FREE so SizedBox.shrink is returned
        expect(find.byType(DietaryStatusBadge), findsNothing);
      });
    });

    group('Max badges limit', () {
      testWidgets('should respect maxBadges limit', (
        WidgetTester tester,
      ) async {
        final tagResult = _buildTagResult(
          dietaryStatus: {
            'vegetarisk': TriState.free,
            'vegansk': TriState.free,
            'barnvänlig': TriState.free,
            'graviditetssäker': TriState.free,
          },
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: CompactDietaryRow(
              tagResult: tagResult,
              maxBadges: 2,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Only 2 badges even though 4 are FREE
        expect(find.byType(DietaryStatusBadge), findsNWidgets(2));
      });

      testWidgets('should default to maxBadges of 2', (
        WidgetTester tester,
      ) async {
        final tagResult = _buildTagResult(
          dietaryStatus: {
            'vegetarisk': TriState.free,
            'vegansk': TriState.free,
            'barnvänlig': TriState.free,
          },
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: CompactDietaryRow(tagResult: tagResult),
          ),
        );
        await tester.pumpAndSettle();

        // Default maxBadges is 2
        expect(find.byType(DietaryStatusBadge), findsNWidgets(2));
      });
    });

    group('Only FREE shown', () {
      testWidgets('should not render CONTAINS dietary status', (
        WidgetTester tester,
      ) async {
        final tagResult = _buildTagResult(
          dietaryStatus: {
            'vegetarisk': TriState.contains,
            'vegansk': TriState.free,
          },
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: CompactDietaryRow(
              tagResult: tagResult,
              maxBadges: 10,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Only vegansk (FREE) should render, not vegetarisk (CONTAINS)
        expect(find.byType(DietaryStatusBadge), findsOneWidget);
      });

      testWidgets('should not render UNKNOWN dietary status', (
        WidgetTester tester,
      ) async {
        final tagResult = _buildTagResult(
          dietaryStatus: {
            'vegetarisk': TriState.unknown,
            'barnvänlig': TriState.free,
          },
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: CompactDietaryRow(
              tagResult: tagResult,
              maxBadges: 10,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Only barnvanlig (FREE) should render
        expect(find.byType(DietaryStatusBadge), findsOneWidget);
      });

      testWidgets('should render empty when all statuses are non-FREE', (
        WidgetTester tester,
      ) async {
        final tagResult = _buildTagResult(
          dietaryStatus: {
            'vegetarisk': TriState.contains,
            'vegansk': TriState.unknown,
          },
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: CompactDietaryRow(
              tagResult: tagResult,
              maxBadges: 10,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(DietaryStatusBadge), findsNothing);
        // Returns SizedBox.shrink when no badges
        expect(find.byType(SizedBox), findsOneWidget);
      });
    });
  });

  group('CompactAllergenRow', () {
    group('Priority ordering', () {
      testWidgets('should show CONTAINS badges before FREE badges', (
        WidgetTester tester,
      ) async {
        final tagResult = _buildTagResult(
          allergenStatus: {
            'gluten': TriState.free,
            'mjölk': TriState.contains,
            'nötter': TriState.free,
            'ägg': TriState.contains,
          },
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: CompactAllergenRow(
              tagResult: tagResult,
              maxBadges: 10,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final badges = tester
            .widgetList<AllergenStatusBadge>(find.byType(AllergenStatusBadge))
            .toList();

        // CONTAINS allergens should appear first
        expect(badges.length, 4);
        // First two should be CONTAINS (mjolk and agg)
        expect(badges[0].status, TriState.contains);
        expect(badges[1].status, TriState.contains);
        // Last two should be FREE (gluten and notter)
        expect(badges[2].status, TriState.free);
        expect(badges[3].status, TriState.free);
      });

      // REWRITTEN 2026-08-18. This case used to assert
      // CONTAINS-before-FREE-before-UNKNOWN and pinned four badges. UNKNOWN is
      // no longer drawn at all — Malin's call, made when BUT-1780 put this row
      // on every recipe card for the first time and the grey question marks
      // became visible to a real user.
      //
      // The rewrite is deliberate, not a test bent to fit a change: her reason
      // was that a grey badge reads as a verdict when it is the absence of one.
      // (An earlier draft of this comment added that they "crowded out the real
      // answers" — false: UNKNOWN sorted last and the take() runs after, so it
      // could never displace one. The true cost is that on an untagged recipe
      // the four grey badges WERE the whole row — 'untagged' is the wrong word for
      // it, since a null tagResult never built the row at all.) The decision was already
      // recorded UNSCOPED in ACCEPTED_DEVIATIONS.md — so this row was not outside a
      // detail-view rule, it was in violation of a general one ("UNKNOWN
      // allergen status is intentionally hidden"); this row was the odd one
      // out, invisibly, because until BUT-1780 nothing constructed it.
      //
      // What is still pinned: the ORDER of what remains, which is the half of
      // the original intent that survives — a warning must precede good news.
      testWidgets('should order CONTAINS before FREE, and drop UNKNOWN', (
        WidgetTester tester,
      ) async {
        final tagResult = _buildTagResult(
          allergenStatus: {
            'gluten': TriState.unknown,
            'mjölk': TriState.free,
            'nötter': TriState.contains,
            'ägg': TriState.unknown,
          },
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: CompactAllergenRow(
              tagResult: tagResult,
              maxBadges: 10,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final badges = tester
            .widgetList<AllergenStatusBadge>(find.byType(AllergenStatusBadge))
            .toList();

        expect(
          badges.length,
          2,
          reason:
              'the two UNKNOWN allergens must not be drawn — the fixture '
              'has four, and a regression restoring them shows 4 here',
        );
        expect(badges[0].status, TriState.contains);
        expect(badges[1].status, TriState.free);
        expect(
          badges.every((b) => b.status != TriState.unknown),
          isTrue,
          // Deliberately redundant: `expect` throws on the first failure, so
          // the count above always reddens first and this line can never be
          // the one that fails. It is here to name the intent at the failure
          // site, not to guard anything the count does not already guard —
          // said plainly because the previous wording claimed otherwise.
          reason:
              'names what the count is really about; not an independent '
              'guard',
        );
      });
    });

    group('Default allergens', () {
      testWidgets(
        'should show default four allergens when no userPrefs provided',
        (WidgetTester tester) async {
          final tagResult = _buildTagResult(
            allergenStatus: {
              'gluten': TriState.free,
              'mjölk': TriState.free,
              'nötter': TriState.free,
              'ägg': TriState.free,
              'soja': TriState.free,
              'sesam': TriState.free,
            },
          );

          await tester.pumpWidget(
            createLocalizedTestApp(
              wrapInScrollView: true,
              child: CompactAllergenRow(
                tagResult: tagResult,
                maxBadges: 10,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Default allergens: gluten, mjolk, notter, agg (4 total)
          expect(find.byType(AllergenStatusBadge), findsNWidgets(4));
        },
      );

      testWidgets('should use custom userPrefs when provided', (
        WidgetTester tester,
      ) async {
        final tagResult = _buildTagResult(
          allergenStatus: {
            'gluten': TriState.free,
            'mjölk': TriState.free,
            'soja': TriState.free,
            'sesam': TriState.free,
          },
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: CompactAllergenRow(
              tagResult: tagResult,
              userPrefs: const {'soja', 'sesam'},
              maxBadges: 10,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Only soja and sesam from userPrefs
        expect(find.byType(AllergenStatusBadge), findsNWidgets(2));
      });
    });

    group('Max badges limit', () {
      testWidgets('should respect maxBadges limit', (
        WidgetTester tester,
      ) async {
        final tagResult = _buildTagResult(
          allergenStatus: {
            'gluten': TriState.free,
            'mjölk': TriState.contains,
            'nötter': TriState.free,
            'ägg': TriState.contains,
          },
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: CompactAllergenRow(
              tagResult: tagResult,
              maxBadges: 2,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Only 2 badges shown
        expect(find.byType(AllergenStatusBadge), findsNWidgets(2));
      });

      testWidgets('should default to maxBadges of 4', (
        WidgetTester tester,
      ) async {
        final tagResult = _buildTagResult(
          allergenStatus: {
            'gluten': TriState.free,
            'mjölk': TriState.free,
            'nötter': TriState.free,
            'ägg': TriState.free,
          },
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: CompactAllergenRow(tagResult: tagResult),
          ),
        );
        await tester.pumpAndSettle();

        // Default maxBadges is 4, all 4 default allergens are FREE
        expect(find.byType(AllergenStatusBadge), findsNWidgets(4));
      });

      testWidgets('should prioritize CONTAINS in limited badges', (
        WidgetTester tester,
      ) async {
        final tagResult = _buildTagResult(
          allergenStatus: {
            'gluten': TriState.free,
            'mjölk': TriState.contains,
            'nötter': TriState.free,
            'ägg': TriState.contains,
          },
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: CompactAllergenRow(
              tagResult: tagResult,
              maxBadges: 2,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // With maxBadges=2, CONTAINS should be shown first
        final badges = tester
            .widgetList<AllergenStatusBadge>(find.byType(AllergenStatusBadge))
            .toList();

        expect(badges.length, 2);
        expect(badges[0].status, TriState.contains);
        expect(badges[1].status, TriState.contains);
      });
    });

    group('Empty state', () {
      testWidgets('should render empty when no allergens have status', (
        WidgetTester tester,
      ) async {
        final tagResult = _buildTagResult(allergenStatus: {});

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: CompactAllergenRow(tagResult: tagResult),
          ),
        );
        await tester.pumpAndSettle();

        // REWRITTEN 2026-08-18, same decision as the ordering case above.
        // `getAllergenStatus` returns UNKNOWN for a key that is not in the map,
        // so an empty TagResult used to paint all four default allergens as
        // grey question marks. It now paints nothing, and the row collapses to
        // SizedBox.shrink() — which is what makes the card's spacer gate
        // (BUT-1869) necessary rather than decorative: an untagged recipe is
        // the common case, not the edge one.
        expect(
          find.byType(AllergenStatusBadge),
          findsNothing,
          reason:
              'an untagged recipe says nothing, rather than saying '
              '"unknown" four times',
        );
      });

      testWidgets('should use compact mode and hide labels', (
        WidgetTester tester,
      ) async {
        final tagResult = _buildTagResult(
          allergenStatus: {
            'gluten': TriState.free,
          },
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScrollView: true,
            child: CompactAllergenRow(tagResult: tagResult),
          ),
        );
        await tester.pumpAndSettle();

        // CompactAllergenRow uses compact: true, showLabel: false
        final badges = tester
            .widgetList<AllergenStatusBadge>(find.byType(AllergenStatusBadge))
            .toList();

        for (final badge in badges) {
          expect(badge.compact, true);
          expect(badge.showLabel, false);
        }
      });
    });
  });
}
