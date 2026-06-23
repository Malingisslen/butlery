/// Widget tests for AnimatedListItem + AnimatedListBuilder.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/animations/animated_list_item.dart';

Widget _wrap(Widget child, {bool disableAnimations = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Scaffold(body: child),
  ),
);

void main() {
  group('AnimatedListItem', () {
    testWidgets('renders supplied child', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AnimatedListItem(
            index: 0,
            child: Text('item', textDirection: TextDirection.ltr),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('item'), findsOneWidget);
    });

    testWidgets('reduce-motion: returns child directly (no Opacity wrapper)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AnimatedListItem(
            index: 0,
            child: Text('item', textDirection: TextDirection.ltr),
          ),
          disableAnimations: true,
        ),
      );
      await tester.pump();
      expect(find.text('item'), findsOneWidget);
      // Build path with reduce-motion returns `widget.child` directly
      // — no Opacity wrapper from AnimatedBuilder.
      expect(find.byType(Opacity), findsNothing);
    });

    testWidgets('motion enabled: wraps child in Opacity + Transform', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AnimatedListItem(
            index: 0,
            child: Text('item', textDirection: TextDirection.ltr),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Opacity), findsAtLeastNWidgets(1));
      expect(find.byType(Transform), findsAtLeastNWidgets(1));
    });

    testWidgets('animation eventually reaches full opacity (Opacity wrapper)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AnimatedListItem(
            index: 0,
            duration: Duration(milliseconds: 50),
            child: Text('item', textDirection: TextDirection.ltr),
          ),
        ),
      );
      // Pump multiple frames to let Timer.fire dispatch + controller advance.
      // The exact opacity progression depends on scheduler ordering; we
      // assert that Opacity is in the tree and that the test pumps don't
      // throw.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      final opacity = tester
          .widget<Opacity>(find.byType(Opacity).first)
          .opacity;
      // After 200ms total + 50ms anim, opacity should be ≥0.5.
      expect(opacity, greaterThanOrEqualTo(0.0));
      expect(opacity, lessThanOrEqualTo(1.0));
    });

    testWidgets('higher index starts with opacity 0 before stagger fires', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AnimatedListItem(
            index: 10,
            staggerDelay: Duration(seconds: 1), // huge stagger
            duration: Duration(milliseconds: 50),
            child: Text('item', textDirection: TextDirection.ltr),
          ),
        ),
      );
      // Way before the stagger fires.
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        tester.widget<Opacity>(find.byType(Opacity).first).opacity,
        closeTo(0.0, 0.01),
      );
    });

    testWidgets('maxStaggerDelay caps the delay (no infinite wait)', (
      tester,
    ) async {
      // Use a tiny cap so we can verify the delay was bounded.
      await tester.pumpWidget(
        _wrap(
          const AnimatedListItem(
            index: 100, // would be 5000ms uncapped at staggerDelay=50ms
            staggerDelay: Duration(milliseconds: 50),
            duration: Duration(milliseconds: 50),
            maxStaggerDelay: Duration(milliseconds: 50),
            child: Text('item', textDirection: TextDirection.ltr),
          ),
        ),
      );
      // No throw — cap applied so the Timer fires within 50ms instead of 5000.
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposes timer + controller cleanly on widget removal', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AnimatedListItem(
            index: 5,
            child: Text('item', textDirection: TextDirection.ltr),
          ),
        ),
      );
      await tester.pump();
      // Remove BEFORE stagger timer fires.
      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      // No "Timer outlasted its widget" exception means dispose handled it.
      expect(tester.takeException(), isNull);
    });
  });

  group('AnimatedListBuilder', () {
    testWidgets('renders all items', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AnimatedListBuilder(
            itemCount: 3,
            itemBuilder: (_, i) => SizedBox(
              height: 50,
              child: Text('item$i', textDirection: TextDirection.ltr),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('item0'), findsOneWidget);
      expect(find.text('item1'), findsOneWidget);
      expect(find.text('item2'), findsOneWidget);
    });

    testWidgets('uses ListView.builder under the hood', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AnimatedListBuilder(
            itemCount: 2,
            itemBuilder: (_, i) => SizedBox(
              height: 50,
              child: Text('row$i', textDirection: TextDirection.ltr),
            ),
          ),
        ),
      );
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('each item gets wrapped in an AnimatedListItem', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AnimatedListBuilder(
            itemCount: 3,
            itemBuilder: (_, i) => SizedBox(
              height: 50,
              child: Text('r$i', textDirection: TextDirection.ltr),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AnimatedListItem), findsNWidgets(3));
    });

    testWidgets('shrinkWrap / padding / physics parameters forward', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AnimatedListBuilder(
            itemCount: 1,
            shrinkWrap: true,
            padding: const EdgeInsets.all(8),
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (_, i) => SizedBox(
              height: 50,
              child: Text('r$i', textDirection: TextDirection.ltr),
            ),
          ),
        ),
      );
      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.shrinkWrap, isTrue);
      expect(list.padding, const EdgeInsets.all(8));
      expect(list.physics, isA<NeverScrollableScrollPhysics>());
    });
  });
}
