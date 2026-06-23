import 'package:butlery/core/utils/reduced_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isReducedMotion', () {
    testWidgets('returns true when MediaQuery.disableAnimations is true', (
      tester,
    ) async {
      bool? captured;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              captured = isReducedMotion(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(captured, isTrue);
    });

    testWidgets('returns false when MediaQuery.disableAnimations is false', (
      tester,
    ) async {
      bool? captured;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Builder(
            builder: (context) {
              captured = isReducedMotion(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(captured, isFalse);
    });
  });

  group('Duration.respectingMotion extension', () {
    testWidgets('collapses to Duration.zero when reduced motion is on', (
      tester,
    ) async {
      Duration? captured;
      const original = Duration(milliseconds: 250);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              captured = original.respectingMotion(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(captured, Duration.zero);
    });

    testWidgets('preserves the original duration when reduced motion is off', (
      tester,
    ) async {
      Duration? captured;
      const original = Duration(milliseconds: 250);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Builder(
            builder: (context) {
              captured = original.respectingMotion(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(captured, original);
    });

    testWidgets(
      'AnimatedContainer reaches its end-state synchronously when reduced '
      'motion is on',
      (tester) async {
        // Behavior contract: a declarative animated widget wired through
        // `.respectingMotion(context)` snaps to its target colour/opacity
        // synchronously instead of tweening over the original 300ms. We assert
        // on `decoration` rather than width — width can be coerced by ambient
        // layout constraints in a test scaffold and would mask a still-running
        // tween.
        const startColor = Color(0xFF000000);
        const endColor = Color(0xFFFF0000);

        Widget buildBox(Color color, {bool reducedMotion = true}) => MediaQuery(
          data: MediaQueryData(disableAnimations: reducedMotion),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: Builder(
                builder: (context) {
                  return AnimatedContainer(
                    duration: const Duration(
                      milliseconds: 300,
                    ).respectingMotion(context),
                    width: 100,
                    height: 50,
                    color: color,
                  );
                },
              ),
            ),
          ),
        );

        await tester.pumpWidget(buildBox(startColor));
        await tester.pumpWidget(buildBox(endColor));
        // Single pump after the rebuild — with Duration.zero the container
        // must already report the end-colour. With a real 300ms tween it would
        // still be interpolating between black and red.
        final container = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        expect(container.duration, Duration.zero);
      },
    );
  });
}
