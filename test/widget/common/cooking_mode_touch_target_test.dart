// test/widget/common/cooking_mode_touch_target_test.dart
//
// Intent: prove the cooking-mode top-bar buttons (font-scale toggle, close)
// still satisfy WCAG 2.5.5 — minimum 48x48dp hit target — after the A3
// migration from `InkWell + SizedBox(minTouchTarget)` to [TappableWrapper].
// These are the most risky surface-colored tappables in the app because
// they sit over a saturated primary background where visual affordance is
// limited — if the hit region shrinks, users mistap during cooking.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/tappable_wrapper.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';

/// Mirrors the exact structure used by `cooking_mode_view._buildTopBar`
/// after the A3 migration. Matching the wrapping (ColoredBox parent,
/// TappableWrapper with child) is what we're asserting the contract on —
/// if that contract drifts, the cooking-mode view would too.
Widget _cookingModeCloseButton(BuildContext context, VoidCallback onTap) {
  final cs = Theme.of(context).colorScheme;
  return ColoredBox(
    color: cs.surface,
    child: TappableWrapper(
      onTap: onTap,
      semanticLabel: 'Avsluta matlagning',
      child: Icon(
        Icons.close,
        color: cs.primary,
        size: AppDimensions.iconSizeM,
      ),
    ),
  );
}

Widget _cookingModeFontScaleToggle(BuildContext context, VoidCallback onTap) {
  final cs = Theme.of(context).colorScheme;
  return ColoredBox(
    color: cs.surface,
    child: TappableWrapper(
      onTap: onTap,
      semanticLabel: 'Ändra textstorlek',
      child: Text(
        'A+',
        style: AppTextStyles.titleMedium.copyWith(
          color: cs.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

void main() {
  group('Cooking mode migrated tappables', () {
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    testWidgets(
        'close button hit region is at least 48x48dp after TappableWrapper '
        'migration', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Center(
            child: Builder(
              builder: (ctx) => _cookingModeCloseButton(ctx, () {}),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(TappableWrapper));
      expect(size.width, greaterThanOrEqualTo(AppDimensions.minTouchTarget));
      expect(size.height, greaterThanOrEqualTo(AppDimensions.minTouchTarget));
    });

    testWidgets(
        'font-scale toggle hit region is at least 48x48dp even when the '
        'child is a short Text glyph', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Center(
            child: Builder(
              builder: (ctx) => _cookingModeFontScaleToggle(ctx, () {}),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(TappableWrapper));
      expect(size.width, greaterThanOrEqualTo(AppDimensions.minTouchTarget));
      expect(size.height, greaterThanOrEqualTo(AppDimensions.minTouchTarget));
    });
  });
}
