/// Unit tests for TimeFormatUtils — cooking time formatting.
library;

import 'package:flutter_test/flutter_test.dart';
import '../../test_support/base_unit_test.dart';
import 'package:butlery/core/utils/time_format_utils.dart';

void main() {
  group('TimeFormatUtils', () {
    setUp(() async => await BaseUnitTest.setupUnit());
    tearDown(() => BaseUnitTest.resetMocks());

    group('formatCookingTime', () {
      test('0 minutes', () {
        expect(TimeFormatUtils.formatCookingTime(0), '0 min');
      });

      test('1 minute', () {
        expect(TimeFormatUtils.formatCookingTime(1), '1 min');
      });

      test('30 minutes', () {
        expect(TimeFormatUtils.formatCookingTime(30), '30 min');
      });

      test('59 minutes (just under 1 hour)', () {
        expect(TimeFormatUtils.formatCookingTime(59), '59 min');
      });

      test('60 minutes (exact 1 hour)', () {
        expect(TimeFormatUtils.formatCookingTime(60), '1 h');
      });

      test('61 minutes (1 hour 1 min)', () {
        expect(TimeFormatUtils.formatCookingTime(61), '1 h 1 min');
      });

      test('90 minutes (1 hour 30 min)', () {
        expect(TimeFormatUtils.formatCookingTime(90), '1 h 30 min');
      });

      test('120 minutes (exact 2 hours)', () {
        expect(TimeFormatUtils.formatCookingTime(120), '2 h');
      });

      test('121 minutes (2 hours 1 min)', () {
        expect(TimeFormatUtils.formatCookingTime(121), '2 h 1 min');
      });

      test('180 minutes (exact 3 hours)', () {
        expect(TimeFormatUtils.formatCookingTime(180), '3 h');
      });
    });
  });
}
