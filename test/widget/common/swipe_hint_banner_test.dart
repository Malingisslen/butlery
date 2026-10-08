import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
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

      expect(find.byIcon(ButleryIcons.hand), findsOneWidget);
    });

    testWidgets('does not render once the seen flag is set', (tester) async {
      SharedPreferences.setMockInitialValues({
        SwipeHintBanner.recipeSwipeSeenKey: true,
      });
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.byIcon(ButleryIcons.hand), findsNothing);
    });

    testWidgets('dismiss hides the banner and persists the seen flag', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byIcon(ButleryIcons.hand), findsOneWidget);

      await tester.tap(find.byIcon(ButleryIcons.x));
      await tester.pumpAndSettle();

      expect(find.byIcon(ButleryIcons.hand), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(SwipeHintBanner.recipeSwipeSeenKey), isTrue);
    });

    testWidgets('the dismiss control meets the 48 dp tap target (BUT-2194)', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      // A banner that rendered nothing would pass the guideline vacuously.
      expect(find.byIcon(ButleryIcons.x), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });

  group('SwipeHintBanner — B83-2 = A status box', () {
    for (final (name, theme, tint, textColor, iconColor) in [
      (
        'light',
        AppTheme.lightTheme,
        const Color(0xFFF0EEE2),
        const Color(0xFF37453A),
        const Color(0xFF24382C),
      ),
      (
        'dark',
        AppTheme.darkTheme,
        const Color(0xFF2F4437),
        const Color(0xFFF5F4ED),
        const Color(0xFFF5F4ED),
      ),
    ]) {
      testWidgets('$name: surface.tint.warning fill, no border', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Theme(data: theme, child: const SwipeHintBanner()),
          ),
        );
        await tester.pumpAndSettle();

        final box = tester.widget<Container>(
          find
              .ancestor(
                of: find.byIcon(ButleryIcons.hand),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = box.decoration! as BoxDecoration;
        expect(decoration.color, tint);
        expect(decoration.border, isNull);
        // B83-2c: the control radius.
        expect(
          decoration.borderRadius,
          BorderRadius.circular(AppDimensions.radiusControl),
        );
        expect(
          tester.widget<Icon>(find.byIcon(ButleryIcons.hand)).color,
          iconColor,
        );
        final text = tester.widget<Text>(
          find.descendant(
            of: find.byType(SwipeHintBanner),
            matching: find.byType(Text),
          ),
        );
        expect(text.style!.color, textColor);
      });
    }
  });

  group('SwipeHintBanner — parameterized per gesture (BUT-1199)', () {
    testWidgets('renders the supplied icon + message', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: const SwipeHintBanner(
            seenKey: SwipeHintBanner.cookingStepSeenKey,
            icon: ButleryIcons.hand,
            message: 'Long-press a step',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(ButleryIcons.hand), findsOneWidget);
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
                icon: ButleryIcons.hand,
                message: 'Long-press a step',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // One hand on screen: the cooking hint's. The recipe hint shows the
      // same glyph, so a second hand would mean it ignored its seen flag.
      expect(find.text('Long-press a step'), findsOneWidget);
      expect(find.byIcon(ButleryIcons.hand), findsOneWidget);
    });

    testWidgets('dismiss persists its own key only', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: const SwipeHintBanner(
            seenKey: SwipeHintBanner.shoppingClaimSeenKey,
            icon: ButleryIcons.hand,
            message: 'Swipe to claim',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(ButleryIcons.x));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(SwipeHintBanner.shoppingClaimSeenKey), isTrue);
      // The recipe key is untouched.
      expect(prefs.getBool(SwipeHintBanner.recipeSwipeSeenKey), isNull);
    });
  });
}
