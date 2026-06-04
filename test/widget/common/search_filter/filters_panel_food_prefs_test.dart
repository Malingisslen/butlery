import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/search_filter/filters_panel_widget.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

/// BUT-987: the recipe-list filter panel surfaces a contextual deep-link to the
/// combined allergen/dietary preferences screen. These pin that the link is
/// gated on the `onManageFoodPreferences` callback and actually fires it — the
/// only behavior the feature adds.
void main() {
  Widget panel({VoidCallback? onManageFoodPreferences}) {
    return createLocalizedTestApp(
      wrapInScrollView: true,
      child: FiltersPanelWidget(
        showFilters: true,
        activeTimeFilters: const {},
        activeMealTypeFilters: const {},
        activeRatingFilters: const {},
        onTimeFilterToggle: (_) {},
        onMealTypeFilterToggle: (_) {},
        onRatingFilterToggle: (_) {},
        onAllergenFilterToggle: (_) {},
        onDietaryFilterToggle: (_) {},
        onManageFoodPreferences: onManageFoodPreferences,
        hasActiveFilters: false,
      ),
    );
  }

  group('FiltersPanelWidget — manage-food-preferences link (BUT-987)', () {
    // Match on the user-visible label (sv is the harness default locale), not
    // the Icons.tune icon — that icon is also used by FilterToggleButton, so a
    // label finder pins the feature's contract without sharing-icon brittleness.
    final linkFinder = find.text('Hantera allergener & kost');

    testWidgets('renders the manage link when the callback is provided',
        (tester) async {
      await tester.pumpWidget(panel(onManageFoodPreferences: () {}));
      await tester.pumpAndSettle();

      expect(linkFinder, findsOneWidget);
    });

    testWidgets('tapping the link invokes the callback', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(panel(onManageFoodPreferences: () => tapped++));
      await tester.pumpAndSettle();

      // The link sits below the filter groups in a height-constrained,
      // scrollable panel — scroll it into view before tapping.
      await tester.ensureVisible(linkFinder);
      await tester.pumpAndSettle();
      await tester.tap(linkFinder);
      await tester.pumpAndSettle();

      expect(tapped, 1);
    });

    testWidgets('does not render the link when the callback is null',
        (tester) async {
      await tester.pumpWidget(panel(onManageFoodPreferences: null));
      await tester.pumpAndSettle();

      expect(linkFinder, findsNothing);
    });
  });
}
