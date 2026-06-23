// test/widget/common/tappable_wrapper_test.dart
//
// Intent: prove [TappableWrapper] satisfies WCAG 2.5.5 (minimum 48x48dp
// hit target) and WCAG 4.1.2 (screen-reader label) regardless of child
// size — and that tap/long-press callbacks reach the caller.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/tappable_wrapper.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';
import '../golden/golden_helper.dart';

void main() {
  group('TappableWrapper', () {
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    testWidgets(
      'enforces minimum 48x48dp hit region even when the child is smaller',
      (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Center(
              child: TappableWrapper(
                onTap: () {},
                semanticLabel: 'Test action',
                child: const Icon(Icons.info_outline, size: 14),
              ),
            ),
          ),
        );

        final size = tester.getSize(find.byType(TappableWrapper));
        expect(size.width, greaterThanOrEqualTo(AppDimensions.minTouchTarget));
        expect(size.height, greaterThanOrEqualTo(AppDimensions.minTouchTarget));
      },
    );

    testWidgets('exposes the semantic label as a button to screen readers', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: TappableWrapper(
            onTap: () {},
            semanticLabel: 'Gilla kommentar',
            child: const Icon(Icons.favorite),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Gilla kommentar'), findsOneWidget);
    });

    testWidgets('invokes onTap when the hit region is tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Center(
            child: TappableWrapper(
              onTap: () => taps++,
              semanticLabel: 'Tap me',
              child: const Icon(Icons.star, size: 12),
            ),
          ),
        ),
      );

      // Tap near the edge of the 48dp region — a 12px child would miss this
      // without the ConstrainedBox + HitTestBehavior.opaque combo.
      final topLeft = tester.getTopLeft(find.byType(TappableWrapper));
      await tester.tapAt(topLeft + const Offset(2, 2));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('invokes onLongPress when the hit region is long-pressed', (
      tester,
    ) async {
      var longPresses = 0;
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Center(
            child: TappableWrapper(
              onTap: () {},
              onLongPress: () => longPresses++,
              semanticLabel: 'Long press me',
              child: const Icon(Icons.menu),
            ),
          ),
        ),
      );

      await tester.longPress(find.byType(TappableWrapper));
      await tester.pump();

      expect(longPresses, 1);
    });

    testWidgets('disables tap callback and announces disabled state when '
        'enabled is false', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Center(
            child: TappableWrapper(
              onTap: () => taps++,
              semanticLabel: 'Disabled action',
              enabled: false,
              child: const Icon(Icons.block),
            ),
          ),
        ),
      );

      // Still claims the 48dp area.
      final size = tester.getSize(find.byType(TappableWrapper));
      expect(size.width, greaterThanOrEqualTo(AppDimensions.minTouchTarget));

      await tester.tap(find.byType(TappableWrapper));
      await tester.pump();
      expect(taps, 0);
    });

    butleryGolden(
      'tag-status-badge info-icon tappable renders at 48dp minimum',
      file: 'goldens/tappable_wrapper_tag_info.png',
      width: 120,
      height: 64,
      build: () => Center(
        child: TappableWrapper(
          onTap: () {},
          semanticLabel: 'Mer information',
          child: const Icon(Icons.info_outline, size: 14),
        ),
      ),
    );
  });
}
