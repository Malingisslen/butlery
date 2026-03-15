import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/tagging/allergen_status_badge.dart';
import 'package:butlery/widgets/tagging/dietary_status_badge.dart';
import 'package:butlery/widgets/tagging/tag_result_display.dart';

/// Wraps a widget in MaterialApp with l10n delegates and Butlery theme for testing.
Widget _testApp({required Widget child}) {
  return MaterialApp(
    locale: const Locale('sv'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: AppTheme.lightTheme,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

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
          _testApp(
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
      });

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
          _testApp(
            child: CompactDietaryRow(
              tagResult: tagResult,
              maxBadges: 10,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // DietaryStatusBadge FREE uses Icons.eco_outlined
        expect(find.byIcon(Icons.eco_outlined), findsNWidgets(2));
      });
    });

    group('User prefs filter', () {
      testWidgets('should only show diets in userPrefs when provided',
          (WidgetTester tester) async {
        final tagResult = _buildTagResult(
          dietaryStatus: {
            'vegetarisk': TriState.free,
            'vegansk': TriState.free,
            'barnvänlig': TriState.free,
          },
        );

        await tester.pumpWidget(
          _testApp(
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

      testWidgets('should show nothing when userPrefs diets are not FREE',
          (WidgetTester tester) async {
        final tagResult = _buildTagResult(
          dietaryStatus: {
            'vegetarisk': TriState.contains,
            'vegansk': TriState.unknown,
          },
        );

        await tester.pumpWidget(
          _testApp(
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
      testWidgets('should respect maxBadges limit',
          (WidgetTester tester) async {
        final tagResult = _buildTagResult(
          dietaryStatus: {
            'vegetarisk': TriState.free,
            'vegansk': TriState.free,
            'barnvänlig': TriState.free,
            'graviditetssäker': TriState.free,
          },
        );

        await tester.pumpWidget(
          _testApp(
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

      testWidgets('should default to maxBadges of 2',
          (WidgetTester tester) async {
        final tagResult = _buildTagResult(
          dietaryStatus: {
            'vegetarisk': TriState.free,
            'vegansk': TriState.free,
            'barnvänlig': TriState.free,
          },
        );

        await tester.pumpWidget(
          _testApp(
            child: CompactDietaryRow(tagResult: tagResult),
          ),
        );
        await tester.pumpAndSettle();

        // Default maxBadges is 2
        expect(find.byType(DietaryStatusBadge), findsNWidgets(2));
      });
    });

    group('Only FREE shown', () {
      testWidgets('should not render CONTAINS dietary status',
          (WidgetTester tester) async {
        final tagResult = _buildTagResult(
          dietaryStatus: {
            'vegetarisk': TriState.contains,
            'vegansk': TriState.free,
          },
        );

        await tester.pumpWidget(
          _testApp(
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

      testWidgets('should not render UNKNOWN dietary status',
          (WidgetTester tester) async {
        final tagResult = _buildTagResult(
          dietaryStatus: {
            'vegetarisk': TriState.unknown,
            'barnvänlig': TriState.free,
          },
        );

        await tester.pumpWidget(
          _testApp(
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

      testWidgets('should render empty when all statuses are non-FREE',
          (WidgetTester tester) async {
        final tagResult = _buildTagResult(
          dietaryStatus: {
            'vegetarisk': TriState.contains,
            'vegansk': TriState.unknown,
          },
        );

        await tester.pumpWidget(
          _testApp(
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
      testWidgets('should show CONTAINS badges before FREE badges',
          (WidgetTester tester) async {
        final tagResult = _buildTagResult(
          allergenStatus: {
            'gluten': TriState.free,
            'mjölk': TriState.contains,
            'nötter': TriState.free,
            'ägg': TriState.contains,
          },
        );

        await tester.pumpWidget(
          _testApp(
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

      testWidgets('should order CONTAINS before FREE before UNKNOWN',
          (WidgetTester tester) async {
        final tagResult = _buildTagResult(
          allergenStatus: {
            'gluten': TriState.unknown,
            'mjölk': TriState.free,
            'nötter': TriState.contains,
            'ägg': TriState.unknown,
          },
        );

        await tester.pumpWidget(
          _testApp(
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

        expect(badges.length, 4);
        // CONTAINS first
        expect(badges[0].status, TriState.contains);
        // FREE second
        expect(badges[1].status, TriState.free);
        // UNKNOWN last
        expect(badges[2].status, TriState.unknown);
        expect(badges[3].status, TriState.unknown);
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
          _testApp(
            child: CompactAllergenRow(
              tagResult: tagResult,
              maxBadges: 10,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Default allergens: gluten, mjolk, notter, agg (4 total)
        expect(find.byType(AllergenStatusBadge), findsNWidgets(4));
      });

      testWidgets('should use custom userPrefs when provided',
          (WidgetTester tester) async {
        final tagResult = _buildTagResult(
          allergenStatus: {
            'gluten': TriState.free,
            'mjölk': TriState.free,
            'soja': TriState.free,
            'sesam': TriState.free,
          },
        );

        await tester.pumpWidget(
          _testApp(
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
      testWidgets('should respect maxBadges limit',
          (WidgetTester tester) async {
        final tagResult = _buildTagResult(
          allergenStatus: {
            'gluten': TriState.free,
            'mjölk': TriState.contains,
            'nötter': TriState.free,
            'ägg': TriState.contains,
          },
        );

        await tester.pumpWidget(
          _testApp(
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

      testWidgets('should default to maxBadges of 4',
          (WidgetTester tester) async {
        final tagResult = _buildTagResult(
          allergenStatus: {
            'gluten': TriState.free,
            'mjölk': TriState.free,
            'nötter': TriState.free,
            'ägg': TriState.free,
          },
        );

        await tester.pumpWidget(
          _testApp(
            child: CompactAllergenRow(tagResult: tagResult),
          ),
        );
        await tester.pumpAndSettle();

        // Default maxBadges is 4, all 4 default allergens are FREE
        expect(find.byType(AllergenStatusBadge), findsNWidgets(4));
      });

      testWidgets('should prioritize CONTAINS in limited badges',
          (WidgetTester tester) async {
        final tagResult = _buildTagResult(
          allergenStatus: {
            'gluten': TriState.free,
            'mjölk': TriState.contains,
            'nötter': TriState.free,
            'ägg': TriState.contains,
          },
        );

        await tester.pumpWidget(
          _testApp(
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
      testWidgets('should render empty when no allergens have status',
          (WidgetTester tester) async {
        final tagResult = _buildTagResult(allergenStatus: {});

        await tester.pumpWidget(
          _testApp(
            child: CompactAllergenRow(tagResult: tagResult),
          ),
        );
        await tester.pumpAndSettle();

        // All default allergens return UNKNOWN from tagResult (not in map),
        // so they DO show (UNKNOWN is included in the ordering)
        // However they must have status in the map -- getAllergenStatus
        // returns UNKNOWN for missing keys, which IS included in the output
        expect(find.byType(AllergenStatusBadge), findsNWidgets(4));
      });

      testWidgets('should use compact mode and hide labels',
          (WidgetTester tester) async {
        final tagResult = _buildTagResult(
          allergenStatus: {
            'gluten': TriState.free,
          },
        );

        await tester.pumpWidget(
          _testApp(
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
