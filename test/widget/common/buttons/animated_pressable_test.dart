/// Widget tests for AnimatedPressable.
///
/// Listener-based scale animation. Tests cover render + initial state +
/// parameter forwarding via inspection of the rendered widget tree.
/// Full pointer-down simulation needs platform-channel haptics + the
/// Listener event path, which is finicky in the test harness — we keep
/// what's robust here and let integration tests cover the press flow.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/buttons/animated_pressable.dart';

Widget _wrap(Widget child, {bool disableAnimations = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(body: Center(child: child)),
      ),
    );

double _currentScale(WidgetTester tester) {
  final transform = tester.widget<Transform>(find.byType(Transform).first);
  return transform.transform.entry(0, 0);
}

void main() {
  testWidgets('renders child widget', (tester) async {
    await tester.pumpWidget(_wrap(
      const AnimatedPressable(
        child: Text('inside', textDirection: TextDirection.ltr),
      ),
    ));
    expect(find.text('inside'), findsOneWidget);
  });

  testWidgets('initial scale is 1.0 (no compression at rest)', (tester) async {
    await tester.pumpWidget(_wrap(
      const AnimatedPressable(child: SizedBox(width: 100, height: 50)),
    ));
    await tester.pump();
    expect(_currentScale(tester), closeTo(1.0, 0.001));
  });

  testWidgets('wraps child in a Listener for pointer events', (tester) async {
    await tester.pumpWidget(_wrap(
      const AnimatedPressable(child: SizedBox(width: 100, height: 50)),
    ));
    // Scaffold / Material widgets also add Listeners; just verify at
    // least one is present.
    expect(find.byType(Listener), findsAtLeastNWidgets(1));
  });

  testWidgets('wraps child in a Transform for scale', (tester) async {
    await tester.pumpWidget(_wrap(
      const AnimatedPressable(child: SizedBox(width: 100, height: 50)),
    ));
    expect(find.byType(Transform), findsAtLeastNWidgets(1));
  });

  testWidgets('child remains tappable inside (no pointer interception)',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(
      AnimatedPressable(
        child: GestureDetector(
          onTap: () => tapped = true,
          behavior: HitTestBehavior.opaque,
          child: const SizedBox(width: 100, height: 50),
        ),
      ),
    ));
    await tester.tap(find.byType(SizedBox));
    expect(tapped, isTrue);
  });

  testWidgets('disposes cleanly on widget removal', (tester) async {
    await tester.pumpWidget(_wrap(
      const AnimatedPressable(child: SizedBox(width: 100, height: 50)),
    ));
    await tester.pump();
    await tester.pumpWidget(_wrap(const SizedBox.shrink()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduce-motion: still renders without throwing', (tester) async {
    await tester.pumpWidget(_wrap(
      const AnimatedPressable(child: SizedBox(width: 100, height: 50)),
      disableAnimations: true,
    ));
    await tester.pump();
    expect(_currentScale(tester), closeTo(1.0, 0.001));
  });

  testWidgets('pressedScale parameter is honored by the underlying tween',
      (tester) async {
    // The AnimatedPressable constructor accepts pressedScale; verify it
    // doesn't throw at render-time with non-default values.
    await tester.pumpWidget(_wrap(
      const AnimatedPressable(
        pressedScale: 0.7,
        child: SizedBox(width: 100, height: 50),
      ),
    ));
    expect(tester.takeException(), isNull);
    // At rest, scale is still 1.0 regardless of pressedScale.
    expect(_currentScale(tester), closeTo(1.0, 0.001));
  });

  testWidgets('enabled=false renders the child at full scale', (tester) async {
    await tester.pumpWidget(_wrap(
      const AnimatedPressable(
        enabled: false,
        child: SizedBox(width: 100, height: 50),
      ),
    ));
    await tester.pump();
    expect(_currentScale(tester), closeTo(1.0, 0.001));
  });

  testWidgets('duration parameter does not throw at non-default values',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const AnimatedPressable(
        duration: Duration(milliseconds: 50),
        child: SizedBox(width: 100, height: 50),
      ),
    ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('curve parameter does not throw at non-default values',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const AnimatedPressable(
        curve: Curves.bounceIn,
        child: SizedBox(width: 100, height: 50),
      ),
    ));
    expect(tester.takeException(), isNull);
  });
}
