// Verifies the BUT-514 fix: AppColors.textLight must satisfy WCAG 1.4.3 AA
// (>= 4.5:1 contrast for body text) against the cream background, which is
// where the previous #767676 value silently failed at ~4.1:1.
//
// Why inline the WCAG math instead of pulling a package: keeps the test free
// of transitive deps and makes the failure mode obvious — if someone tweaks
// textLight later, the assertion message shows the actual computed ratio.

import 'dart:math' as math;

import 'package:butlery/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _channelLuminance(int eightBit) {
  final c = eightBit / 255.0;
  return c <= 0.03928
      ? c / 12.92
      : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double _relativeLuminance(Color c) {
  // Flutter 3.27+ exposes Color channels as 0..1 doubles via .r/.g/.b; convert
  // to 8-bit before applying the WCAG 2.x relative-luminance transform.
  final r = _channelLuminance((c.r * 255).round());
  final g = _channelLuminance((c.g * 255).round());
  final b = _channelLuminance((c.b * 255).round());
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('AppColors.textLight WCAG AA contrast (BUT-514)', () {
    test('passes 4.5:1 against cream (#F8F4E8)', () {
      final ratio = _contrastRatio(AppColors.textLight, AppColors.cream);
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: 'textLight on cream measured ${ratio.toStringAsFixed(2)}:1, '
            'WCAG 1.4.3 AA requires >= 4.5:1 for body text',
      );
    });

    test('passes 4.5:1 against white (#FFFFFF) — secondary surfaces', () {
      final ratio = _contrastRatio(AppColors.textLight, AppColors.cardWhite);
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('passes 4.5:1 against creamDark — card surfaces', () {
      final ratio = _contrastRatio(AppColors.textLight, AppColors.creamDark);
      expect(ratio, greaterThanOrEqualTo(4.5));
    });
  });
}
