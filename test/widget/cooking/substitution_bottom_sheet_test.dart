/// BUT-202: Widget tests for [SubstitutionBottomSheet].
///
/// Proves:
/// 1. 3 suggestion rows render with names and ratio badges.
/// 2. Tapping "Byt i receptet" on a row fires the onReplace callback with
///    the chosen substitute.
/// 3. Empty-state copy ("Inga förslag just nu") renders when suggestions
///    are empty; the "Föreslå ett alternativ" CTA is disabled.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/cooking/ingredient_substitution.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/cooking/substitution_bottom_sheet.dart';

import '../../infrastructure/helpers/ink_fill.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  group('SubstitutionBottomSheet', () {
    testWidgets('renders 3 suggestion rows with names and ratios', (
      tester,
    ) async {
      const suggestions = [
        IngredientSubstitution(
          name: 'yoghurt',
          ratio: 1.0,
          context: 'i bakning',
        ),
        IngredientSubstitution(name: 'crème fraîche', ratio: 0.75),
        IngredientSubstitution(name: 'kvarg', ratio: 1.0),
      ];

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: const SubstitutionBottomSheet(
            ingredientName: 'smetana',
            suggestions: suggestions,
          ),
        ),
      );

      expect(
        find.textContaining('smetana'),
        findsOneWidget,
        reason: 'title should surface the source ingredient',
      );
      expect(find.text('yoghurt'), findsOneWidget);
      expect(find.text('crème fraîche'), findsOneWidget);
      expect(find.text('kvarg'), findsOneWidget);

      // Ratio badges: 1.0 → "1:1", 0.75 → "75%"
      expect(find.text('1:1'), findsNWidgets(2));
      expect(find.text('75%'), findsOneWidget);

      // Context hint renders when provided.
      expect(find.text('i bakning'), findsOneWidget);
    });

    testWidgets('tap Byt i receptet fires onReplace with that suggestion', (
      tester,
    ) async {
      IngredientSubstitution? captured;

      const suggestions = [
        IngredientSubstitution(name: 'yoghurt', ratio: 1.0),
        IngredientSubstitution(name: 'kvarg', ratio: 0.5),
      ];

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: SubstitutionBottomSheet(
            ingredientName: 'smetana',
            suggestions: suggestions,
            onReplace: (s) => captured = s,
          ),
        ),
      );

      // Each row has its own "Byt i receptet" button — tap the second one.
      final buttons = find.text('Byt i receptet');
      expect(buttons, findsNWidgets(2));

      await tester.tap(buttons.at(1));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.name, 'kvarg');
      expect(captured!.ratio, 0.5);
    });

    testWidgets('empty suggestions show empty-state copy and disabled CTA', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: const SubstitutionBottomSheet(
            ingredientName: 'gurkmeja',
            suggestions: [],
          ),
        ),
      );

      expect(find.text('Inga förslag just nu'), findsOneWidget);
      expect(find.text('Föreslå ett alternativ'), findsOneWidget);
      expect(find.text('Byt i receptet'), findsNothing);

      // "Föreslå ett alternativ" is a placeholder — the underlying InkWell
      // has onTap: null. Tapping is a no-op that does not throw.
      await tester.tap(find.text('Föreslå ett alternativ'));
      await tester.pump();
    });

    // BUT-1360: an empty sheet while offline must explain that suggestions
    // aren't reachable rather than implying none exist.
    testWidgets('offline + empty shows the offline message', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: const SubstitutionBottomSheet(
            ingredientName: 'gurkmeja',
            suggestions: [],
            isOffline: true,
          ),
        ),
      );

      expect(
        find.text('Förslag på alternativ är inte tillgängliga offline.'),
        findsOneWidget,
      );
      // The generic empty copy and the future-feature CTA are suppressed offline.
      expect(find.text('Inga förslag just nu'), findsNothing);
      expect(find.text('Föreslå ett alternativ'), findsNothing);
    });

    testWidgets('online + empty does NOT show the offline message', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: const SubstitutionBottomSheet(
            ingredientName: 'gurkmeja',
            suggestions: [],
            isOffline: false,
          ),
        ),
      );

      expect(
        find.text('Förslag på alternativ är inte tillgängliga offline.'),
        findsNothing,
      );
      // Online empty state is unchanged: generic copy + disabled CTA still show.
      expect(find.text('Inga förslag just nu'), findsOneWidget);
      expect(find.text('Föreslå ett alternativ'), findsOneWidget);
    });
  });

  // BUT-2205: "Byt i receptet" is an ink button, so its press takes the
  // step on ink.
  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    testWidgets('a pressed Byt i receptet takes the step on ink '
        '(${theme.brightness.name})', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Theme(
            data: theme,
            child: SubstitutionBottomSheet(
              ingredientName: 'smetana',
              suggestions: const [
                IngredientSubstitution(name: 'yoghurt', ratio: 1.0),
              ],
              onReplace: (_) {},
            ),
          ),
        ),
      );
      final target = find.text('Byt i receptet');
      final gesture = await holdPress(tester, target);
      expect(
        paintsInkFill(
          tester,
          target,
          ModeColors.of(theme.brightness).pressedOnInk,
        ),
        isTrue,
      );
      await gesture.cancel();
    });
  }
}
