import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/widgets/common/swipe_hint_banner.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

/// BUT-982 / BUT-1199: the gesture hint teaches a hidden gesture, shown once
/// per device. These pin the contract that matters: it shows on first use,
/// hides once the seen-flag is set, and dismissing both hides it AND persists
/// the flag (so it never returns). BUT-1199 generalized it to a parameterized
/// seenKey/icon/message — the per-gesture isolation is pinned below.
void main() {
  Widget app() => createLocalizedTestApp(child: const SwipeHintBanner());

  group('SwipeHintBanner (BUT-982)', () {
    testWidgets('renders on first use (no seen flag)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.swipe), findsOneWidget);
    });

    testWidgets('does not render once the seen flag is set', (tester) async {
      SharedPreferences.setMockInitialValues({
        SwipeHintBanner.recipeSwipeSeenKey: true,
      });
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.swipe), findsNothing);
    });

    testWidgets('dismiss hides the banner and persists the seen flag', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.swipe), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.swipe), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(SwipeHintBanner.recipeSwipeSeenKey), isTrue);
    });
  });

  group('SwipeHintBanner — parameterized per gesture (BUT-1199)', () {
    testWidgets('renders the supplied icon + message', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: const SwipeHintBanner(
            seenKey: SwipeHintBanner.cookingStepSeenKey,
            icon: Icons.touch_app,
            message: 'Long-press a step',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.touch_app), findsOneWidget);
      expect(find.text('Long-press a step'), findsOneWidget);
    });

    testWidgets('honours its own seenKey, independent of the recipe hint', (
      tester,
    ) async {
      // Recipe hint dismissed; the cooking hint must still show AND the recipe
      // hint must stay hidden — pinning both halves so a "always-show, ignore
      // the flag" regression also fails here, not just a key-bleed regression.
      SharedPreferences.setMockInitialValues({
        SwipeHintBanner.recipeSwipeSeenKey: true,
      });
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: const Column(
            children: [
              SwipeHintBanner(), // recipe default — seen, must stay hidden
              SwipeHintBanner(
                seenKey: SwipeHintBanner.cookingStepSeenKey,
                icon: Icons.touch_app,
                message: 'Long-press a step',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.swipe), findsNothing);
      expect(find.byIcon(Icons.touch_app), findsOneWidget);
    });

    testWidgets('dismiss persists its own key only', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: const SwipeHintBanner(
            seenKey: SwipeHintBanner.shoppingClaimSeenKey,
            icon: Icons.swipe,
            message: 'Swipe to claim',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(SwipeHintBanner.shoppingClaimSeenKey), isTrue);
      // The recipe key is untouched.
      expect(prefs.getBool(SwipeHintBanner.recipeSwipeSeenKey), isNull);
    });
  });
}
