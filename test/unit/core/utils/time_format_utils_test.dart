/// Unit tests for TimeFormatUtils.formatCookingTime.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/time_format_utils.dart';

void main() {
  group('formatCookingTime', () {
    test('< 60 minutes → "N min"', () {
      expect(TimeFormatUtils.formatCookingTime(0), '0 min');
      expect(TimeFormatUtils.formatCookingTime(5), '5 min');
      expect(TimeFormatUtils.formatCookingTime(59), '59 min');
    });

    test('exact hours (60, 120, ...) → "N h" (no min suffix)', () {
      expect(TimeFormatUtils.formatCookingTime(60), '1 h');
      expect(TimeFormatUtils.formatCookingTime(120), '2 h');
      expect(TimeFormatUtils.formatCookingTime(180), '3 h');
    });

    test('hours + remainder → "N h M min"', () {
      expect(TimeFormatUtils.formatCookingTime(75), '1 h 15 min');
      expect(TimeFormatUtils.formatCookingTime(125), '2 h 5 min');
    });

    test('threshold transition 60 vs 59 is correct', () {
      expect(TimeFormatUtils.formatCookingTime(59), '59 min');
      expect(TimeFormatUtils.formatCookingTime(60), '1 h');
      expect(TimeFormatUtils.formatCookingTime(61), '1 h 1 min');
    });
  });
}
