import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/widgets/tagging/tag_result_display.dart';

import '../../infrastructure/helpers/tagging_test_helper.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  group('TagResultDisplay', () {
    testWidgets('empty allergen/dietary shows tagResultNoAllergens text',
        (tester) async {
      final result =
          TaggingTestHelper.createTagResult(generatorVersion: '2.0.0');
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScrollView: true,
          child: TagResultDisplay(tagResult: result),
        ),
      );
      await tester.pumpAndSettle();

      // When no allergens or dietary statuses have non-unknown values,
      // the italic "no allergens" text appears (shown as fontStyle.italic Text)
      expect(find.byType(TagResultDisplay), findsOneWidget);
      final italicText = find.byWidgetPredicate(
        (w) => w is Text && w.style?.fontStyle == FontStyle.italic,
      );
      expect(italicText, findsOneWidget);
    });

    testWidgets('isDegraded: true shows degraded warning', (tester) async {
      final result =
          TaggingTestHelper.createTagResult(generatorVersion: '2.0.0');
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScrollView: true,
          child: TagResultDisplay(tagResult: result, isDegraded: true),
        ),
      );
      await tester.pumpAndSettle();

      // Degraded warning uses warning_amber icon
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    });

    testWidgets(
        'outdated version shows retag banner and update button calls onRetagRequested',
        (tester) async {
      bool retagCalled = false;
      final result =
          TaggingTestHelper.createTagResult(generatorVersion: '0.0.1');
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScrollView: true,
          child: TagResultDisplay(
            tagResult: result,
            onRetagRequested: () => retagCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Retag banner has an update icon
      expect(find.byIcon(Icons.update), findsOneWidget);

      // Find and tap the update button
      final updateButton = find.byType(TextButton);
      expect(updateButton, findsOneWidget);
      await tester.tap(updateButton);
      expect(retagCalled, isTrue);
    });

    testWidgets('hasDraftIngredients shows unverified warning', (tester) async {
      final result = TaggingTestHelper.createTagResult(
          hasDraftIngredients: true, generatorVersion: '2.0.0');
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScrollView: true,
          child: TagResultDisplay(tagResult: result),
        ),
      );
      await tester.pumpAndSettle();

      // Draft warning uses info_outline icon
      expect(find.byIcon(Icons.info_outline), findsAtLeastNWidgets(1));
    });

    testWidgets('showCoverage: false hides coverage section', (tester) async {
      final result = TaggingTestHelper.createTagResult(
        allergenStatus: {'gluten': TriState.free},
        coverage: 0.8,
        unknownIngredients: ['unknown1'],
        generatorVersion: '2.0.0',
      );
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScrollView: true,
          child: TagResultDisplay(tagResult: result, showCoverage: false),
        ),
      );
      await tester.pumpAndSettle();

      // No analytics icon (coverage section header)
      expect(find.byIcon(Icons.analytics_outlined), findsNothing);
    });

    testWidgets('coverage section visible when showCoverage: true',
        (tester) async {
      final result = TaggingTestHelper.createTagResult(
        allergenStatus: {'gluten': TriState.free},
        coverage: 0.8,
        unknownIngredients: ['unknown1'],
        generatorVersion: '2.0.0',
      );
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScrollView: true,
          child: TagResultDisplay(tagResult: result, showCoverage: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);
    });

    testWidgets('unknown ingredients row tappable when callback provided',
        (tester) async {
      bool tapped = false;
      final result = TaggingTestHelper.createTagResult(
        allergenStatus: {'gluten': TriState.free},
        coverage: 0.8,
        unknownIngredients: ['unknown1'],
        generatorVersion: '2.0.0',
      );
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScrollView: true,
          child: TagResultDisplay(
            tagResult: result,
            onUnknownIngredientsTap: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Chevron indicates tappable
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      // Tap the unknown ingredients row
      await tester.tap(find.byIcon(Icons.warning_amber_rounded));
      expect(tapped, isTrue);
    });

    testWidgets('userAllergenPrefs filters badge set', (tester) async {
      final result = TaggingTestHelper.createTagResult(
        allergenStatus: {
          'gluten': TriState.free,
          'mjölk': TriState.contains,
          'ägg': TriState.free,
        },
        generatorVersion: '2.0.0',
      );
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScrollView: true,
          child: TagResultDisplay(
            tagResult: result,
            userAllergenPrefs: const {'gluten'},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Only gluten badge should be shown (mjölk and ägg filtered out)
      // AllergenStatusBadge renders check_circle_outline for FREE
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('AllergenDisclaimer always renders', (tester) async {
      final result =
          TaggingTestHelper.createTagResult(generatorVersion: '2.0.0');
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScrollView: true,
          child: TagResultDisplay(tagResult: result),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AllergenDisclaimer), findsOneWidget);
    });
  });
}
