import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/hoverable_card.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

/// HoverableCard is the new shared hover-affordance wrapper introduced for
/// recipe + menu cards. Its user-visible contract:
///   1. On pointer hover (web/desktop) it swaps restDecoration → hoverDecoration
///      and reverts on exit.
///   2. When disabled it never swaps decoration and keeps a non-clickable cursor
///      (a non-tappable card must not imply clickability).
///   3. With Reduce Motion on, the decoration still changes — only the
///      AnimatedContainer's duration collapses to zero (WCAG 2.3.3).
///
/// These are tested behaviourally (decoration the user sees, cursor the user
/// gets) rather than by widget topology.
void main() {
  const restDeco = BoxDecoration(color: Color(0xFFAAAAAA));
  const hoverDeco = BoxDecoration(color: Color(0xFFBBBBBB));

  // Reads the live decoration off the single AnimatedContainer that
  // HoverableCard drives. We assert against the decoration objects the caller
  // passed in, so a 4px shadow tweak in a *caller* would not break this test —
  // it only proves the swap happens.
  Decoration? currentDecoration(WidgetTester tester) {
    return tester
        .widget<AnimatedContainer>(find.byType(AnimatedContainer))
        .decoration;
  }

  Future<TestGesture> hoverOver(WidgetTester tester, Finder finder) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(finder));
    await tester.pumpAndSettle();
    return gesture;
  }

  testWidgets('shows restDecoration before any hover', (tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: const HoverableCard(
          restDecoration: restDeco,
          hoverDecoration: hoverDeco,
          child: SizedBox(width: 100, height: 100),
        ),
      ),
    );

    expect(currentDecoration(tester), restDeco);
  });

  testWidgets('swaps to hoverDecoration on pointer enter and reverts on exit',
      (tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: const HoverableCard(
          restDecoration: restDeco,
          hoverDecoration: hoverDeco,
          child: SizedBox(width: 100, height: 100),
        ),
      ),
    );

    final gesture = await hoverOver(tester, find.byType(HoverableCard));
    expect(currentDecoration(tester), hoverDeco,
        reason: 'hovering an enabled card must show the hover decoration');

    await gesture.moveTo(const Offset(-500, -500));
    await tester.pumpAndSettle();
    expect(currentDecoration(tester), restDeco,
        reason: 'leaving the card must revert to the rest decoration');
  });

  testWidgets('disabled card never swaps decoration on hover', (tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: const HoverableCard(
          enabled: false,
          restDecoration: restDeco,
          hoverDecoration: hoverDeco,
          child: SizedBox(width: 100, height: 100),
        ),
      ),
    );

    await hoverOver(tester, find.byType(HoverableCard));
    expect(currentDecoration(tester), restDeco,
        reason: 'a non-interactive card must not lift under the cursor');
  });

  testWidgets('disabled card uses non-clickable cursor', (tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: const HoverableCard(
          enabled: false,
          restDecoration: restDeco,
          hoverDecoration: hoverDeco,
          child: SizedBox(width: 100, height: 100),
        ),
      ),
    );

    final region = tester.widget<MouseRegion>(
      find
          .descendant(
            of: find.byType(HoverableCard),
            matching: find.byType(MouseRegion),
          )
          .first,
    );
    expect(region.cursor, isNot(SystemMouseCursors.click),
        reason: 'disabled card must not present a click cursor');
  });

  testWidgets('enabled card uses click cursor', (tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: const HoverableCard(
          restDecoration: restDeco,
          hoverDecoration: hoverDeco,
          child: SizedBox(width: 100, height: 100),
        ),
      ),
    );

    final region = tester.widget<MouseRegion>(
      find
          .descendant(
            of: find.byType(HoverableCard),
            matching: find.byType(MouseRegion),
          )
          .first,
    );
    expect(region.cursor, SystemMouseCursors.click);
  });

  // WCAG 2.3.3: Reduce Motion must not remove the hover feedback, only its
  // animation. The decoration still changes; the AnimatedContainer's duration
  // collapses to zero so the change is instant.
  testWidgets(
      'reduced motion collapses animation duration but keeps the decoration swap',
      (tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const HoverableCard(
            duration: Duration(milliseconds: 200),
            restDecoration: restDeco,
            hoverDecoration: hoverDeco,
            child: SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    );

    expect(
      tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).duration,
      Duration.zero,
      reason: 'reduce-motion must collapse the cross-fade to instant',
    );

    await hoverOver(tester, find.byType(HoverableCard));
    expect(currentDecoration(tester), hoverDeco,
        reason: 'reduce-motion still changes the decoration, just instantly');
  });

  testWidgets('honours the configured animation duration when motion is on',
      (tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: const HoverableCard(
          duration: Duration(milliseconds: 200),
          restDecoration: restDeco,
          hoverDecoration: hoverDeco,
          child: SizedBox(width: 100, height: 100),
        ),
      ),
    );

    expect(
      tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).duration,
      const Duration(milliseconds: 200),
    );
  });
}
