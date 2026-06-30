/// Unit tests for ButleryColors theme extension.
///
/// Coverage focus: the `iconMuted` slot added in BUT-572 wave preparation.
/// Other slots are visually-validated through golden tests on consuming widgets.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

void main() {
  group('ButleryColors.iconMuted', () {
    test('light value matches legacy AppColors.greenMuted hex', () {
      expect(ButleryColors.light.iconMuted, equals(const Color(0xFF526A55)));
    });

    test(
      'dark value is a lighter brand-green tone (readable on dark surfaces)',
      () {
        expect(ButleryColors.dark.iconMuted, equals(const Color(0xFF7A9C7E)));
      },
    );

    test('copyWith preserves iconMuted when not overridden', () {
      final copy = ButleryColors.light.copyWith();
      expect(copy.iconMuted, equals(ButleryColors.light.iconMuted));
    });

    test('copyWith overrides iconMuted when provided', () {
      final override = const Color(0xFF000000);
      final copy = ButleryColors.light.copyWith(iconMuted: override);
      expect(copy.iconMuted, equals(override));
    });

    test('lerp interpolates iconMuted between light and dark', () {
      final mid = ButleryColors.light.lerp(ButleryColors.dark, 0.5);
      final expected = Color.lerp(
        ButleryColors.light.iconMuted,
        ButleryColors.dark.iconMuted,
        0.5,
      )!;
      expect(mid.iconMuted, equals(expected));
    });

    testWidgets('extension accessor resolves iconMuted via Theme', (
      tester,
    ) async {
      Color? observed;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [ButleryColors.light]),
          home: Builder(
            builder: (context) {
              observed = context.butleryColors.iconMuted;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(observed, equals(ButleryColors.light.iconMuted));
    });
  });

  group('ButleryColors.heroPaleGreen', () {
    test('light value matches legacy AppColors.greenPale hex', () {
      // BUT-1447: light mode must stay byte-identical after the token swap,
      // so this slot has to equal the hardcoded value the screens used before.
      expect(
        ButleryColors.light.heroPaleGreen,
        equals(const Color(0xFFE8F0EA)),
      );
    });

    test('dark value is a low-chroma green on the warm-dark surface', () {
      expect(
        ButleryColors.dark.heroPaleGreen,
        equals(const Color(0xFF24302A)),
      );
    });

    test('copyWith preserves heroPaleGreen when not overridden', () {
      final copy = ButleryColors.light.copyWith();
      expect(copy.heroPaleGreen, equals(ButleryColors.light.heroPaleGreen));
    });

    test('copyWith overrides heroPaleGreen when provided', () {
      final override = const Color(0xFF000000);
      final copy = ButleryColors.light.copyWith(heroPaleGreen: override);
      expect(copy.heroPaleGreen, equals(override));
    });

    test('lerp interpolates heroPaleGreen between light and dark', () {
      final mid = ButleryColors.light.lerp(ButleryColors.dark, 0.5);
      final expected = Color.lerp(
        ButleryColors.light.heroPaleGreen,
        ButleryColors.dark.heroPaleGreen,
        0.5,
      )!;
      expect(mid.heroPaleGreen, equals(expected));
    });

    testWidgets('extension accessor resolves heroPaleGreen via Theme', (
      tester,
    ) async {
      Color? observed;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [ButleryColors.light]),
          home: Builder(
            builder: (context) {
              observed = context.butleryColors.heroPaleGreen;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(observed, equals(ButleryColors.light.heroPaleGreen));
    });
  });
}
