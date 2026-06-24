// BUT-1363: web/desktop hover affordance for interactive badges/custom chips.
// Material FilterChip/ChoiceChip and InkWell hover natively, so only genuinely
// interactive bare-GestureDetector tap targets are wrapped — here, UnifiedBadge.

library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/badges/unified_badge.dart';
import 'package:butlery/widgets/common/hoverable_tap.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  group('HoverableTap', () {
    testWidgets('adds a click cursor and scales up on hover', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(child: const HoverableTap(child: Text('tap'))),
      );

      final region = tester.widget<MouseRegion>(
        find
            .descendant(
              of: find.byType(HoverableTap),
              matching: find.byType(MouseRegion),
            )
            .first,
      );
      expect(region.cursor, SystemMouseCursors.click);

      double scale() =>
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
      expect(scale(), 1.0, reason: 'rest state is unscaled');

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(HoverableTap)));
      await tester.pump();

      expect(scale(), greaterThan(1.0), reason: 'hover scales the child up');
    });

    testWidgets('disabled renders the child with no hover wrapper', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: const HoverableTap(enabled: false, child: Text('plain')),
        ),
      );

      expect(find.byType(AnimatedScale), findsNothing);
      expect(find.text('plain'), findsOneWidget);
    });
  });

  group('UnifiedBadge hover', () {
    testWidgets(
      'interactive badge (onTap) wraps its tap target in HoverableTap',
      (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: UnifiedBadge(label: 'Tag', onTap: () {}),
          ),
        );

        expect(find.byType(HoverableTap), findsOneWidget);
      },
    );

    testWidgets('decorative badge (no onTap) has no HoverableTap', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(child: const UnifiedBadge(label: 'Tag')),
      );

      expect(find.byType(HoverableTap), findsNothing);
    });
  });
}
