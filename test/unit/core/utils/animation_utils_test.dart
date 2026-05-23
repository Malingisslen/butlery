/// Widget tests for AnimationUtils — accessibility-aware animation helpers.
///
/// Drives `MediaQuery.disableAnimations` via wrapping MediaQuery so we
/// can exercise both branches of each helper (animations on/off) without
/// touching real platform settings.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/animation_utils.dart';

Widget _wrap({required bool disableAnimations, required Widget child}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Builder(builder: (_) => child),
    ),
  );
}

void main() {
  group('shouldAnimate', () {
    testWidgets('true when disableAnimations is false', (tester) async {
      bool? observed;
      await tester.pumpWidget(_wrap(
        disableAnimations: false,
        child: Builder(builder: (ctx) {
          observed = AnimationUtils.shouldAnimate(ctx);
          return const SizedBox.shrink();
        }),
      ));
      expect(observed, isTrue);
    });

    testWidgets('false when disableAnimations is true', (tester) async {
      bool? observed;
      await tester.pumpWidget(_wrap(
        disableAnimations: true,
        child: Builder(builder: (ctx) {
          observed = AnimationUtils.shouldAnimate(ctx);
          return const SizedBox.shrink();
        }),
      ));
      expect(observed, isFalse);
    });
  });

  group('getDuration', () {
    testWidgets('returns normal duration when animations enabled',
        (tester) async {
      Duration? observed;
      await tester.pumpWidget(_wrap(
        disableAnimations: false,
        child: Builder(builder: (ctx) {
          observed = AnimationUtils.getDuration(
              ctx, const Duration(milliseconds: 300));
          return const SizedBox.shrink();
        }),
      ));
      expect(observed, const Duration(milliseconds: 300));
    });

    testWidgets('returns Duration.zero when animations disabled',
        (tester) async {
      Duration? observed;
      await tester.pumpWidget(_wrap(
        disableAnimations: true,
        child: Builder(builder: (ctx) {
          observed = AnimationUtils.getDuration(
              ctx, const Duration(milliseconds: 300));
          return const SizedBox.shrink();
        }),
      ));
      expect(observed, Duration.zero);
    });
  });

  group('getCurve', () {
    testWidgets('returns provided curve when animations enabled',
        (tester) async {
      Curve? observed;
      await tester.pumpWidget(_wrap(
        disableAnimations: false,
        child: Builder(builder: (ctx) {
          observed = AnimationUtils.getCurve(ctx, Curves.bounceIn);
          return const SizedBox.shrink();
        }),
      ));
      expect(observed, Curves.bounceIn);
    });

    testWidgets('defaults to Curves.easeInOut when no override + animated',
        (tester) async {
      Curve? observed;
      await tester.pumpWidget(_wrap(
        disableAnimations: false,
        child: Builder(builder: (ctx) {
          observed = AnimationUtils.getCurve(ctx);
          return const SizedBox.shrink();
        }),
      ));
      expect(observed, Curves.easeInOut);
    });

    testWidgets('returns Curves.linear when animations disabled',
        (tester) async {
      Curve? observed;
      await tester.pumpWidget(_wrap(
        disableAnimations: true,
        child: Builder(builder: (ctx) {
          observed = AnimationUtils.getCurve(ctx, Curves.bounceIn);
          return const SizedBox.shrink();
        }),
      ));
      expect(observed, Curves.linear);
    });
  });

  group('getReducedDuration', () {
    testWidgets('normal duration when animations enabled', (tester) async {
      Duration? observed;
      await tester.pumpWidget(_wrap(
        disableAnimations: false,
        child: Builder(builder: (ctx) {
          observed = AnimationUtils.getReducedDuration(
              ctx, const Duration(milliseconds: 500),
              reducedDuration: const Duration(milliseconds: 100));
          return const SizedBox.shrink();
        }),
      ));
      expect(observed, const Duration(milliseconds: 500));
    });

    testWidgets('explicit reducedDuration when animations disabled',
        (tester) async {
      Duration? observed;
      await tester.pumpWidget(_wrap(
        disableAnimations: true,
        child: Builder(builder: (ctx) {
          observed = AnimationUtils.getReducedDuration(
              ctx, const Duration(milliseconds: 500),
              reducedDuration: const Duration(milliseconds: 100));
          return const SizedBox.shrink();
        }),
      ));
      expect(observed, const Duration(milliseconds: 100));
    });

    testWidgets('Duration.zero fallback when disabled + no reducedDuration',
        (tester) async {
      Duration? observed;
      await tester.pumpWidget(_wrap(
        disableAnimations: true,
        child: Builder(builder: (ctx) {
          observed = AnimationUtils.getReducedDuration(
              ctx, const Duration(milliseconds: 500));
          return const SizedBox.shrink();
        }),
      ));
      expect(observed, Duration.zero);
    });
  });
}
