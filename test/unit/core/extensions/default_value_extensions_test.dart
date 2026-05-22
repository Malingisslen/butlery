/// Unit tests for default_value_extensions.
///
/// Pure-Dart; targets the 22 unhit lines in
/// lib/core/extensions/default_value_extensions.dart.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';

void main() {
  group('StringDefaults', () {
    test('orEmpty / orDefault', () {
      String? a;
      expect(a.orEmpty(), '');
      expect(a.orDefault('def'), 'def');
      a = 'hi';
      expect(a.orEmpty(), 'hi');
      expect(a.orDefault('def'), 'hi');
    });

    test('orEmptyTrimmed', () {
      String? a;
      expect(a.orEmptyTrimmed(), '');
      a = '  hi  ';
      expect(a.orEmptyTrimmed(), 'hi');
    });

    test('isNullOrEmpty / hasValue / isNullOrWhitespace', () {
      String? a;
      expect(a.isNullOrEmpty, isTrue);
      expect(a.hasValue, isFalse);
      expect(a.isNullOrWhitespace, isTrue);

      a = '';
      expect(a.isNullOrEmpty, isTrue);
      expect(a.hasValue, isFalse);

      a = '   ';
      expect(a.isNullOrEmpty, isFalse);
      expect(a.hasValue, isTrue);
      expect(a.isNullOrWhitespace, isTrue);

      a = 'hi';
      expect(a.isNullOrEmpty, isFalse);
      expect(a.hasValue, isTrue);
      expect(a.isNullOrWhitespace, isFalse);
    });
  });

  group('ListDefaults', () {
    test('orEmpty / safeLength / isNullOrEmpty / hasItems', () {
      List<int>? a;
      expect(a.orEmpty(), isEmpty);
      expect(a.safeLength, 0);
      expect(a.isNullOrEmpty, isTrue);
      expect(a.hasItems, isFalse);

      a = const [];
      expect(a.isNullOrEmpty, isTrue);
      expect(a.hasItems, isFalse);

      a = const [1, 2, 3];
      expect(a.orEmpty(), [1, 2, 3]);
      expect(a.safeLength, 3);
      expect(a.isNullOrEmpty, isFalse);
      expect(a.hasItems, isTrue);
    });

    test('firstOrNull / lastOrNull', () {
      List<int>? a;
      expect(a.firstOrNull, isNull);
      expect(a.lastOrNull, isNull);

      a = const [];
      expect(a.firstOrNull, isNull);
      expect(a.lastOrNull, isNull);

      a = const [1, 2, 3];
      expect(a.firstOrNull, 1);
      expect(a.lastOrNull, 3);
    });
  });

  group('MapDefaults', () {
    test('orEmpty / safeLength / isNullOrEmpty / hasEntries', () {
      Map<String, int>? a;
      expect(a.orEmpty(), isEmpty);
      expect(a.safeLength, 0);
      expect(a.isNullOrEmpty, isTrue);
      expect(a.hasEntries, isFalse);

      a = const {'a': 1};
      expect(a.safeLength, 1);
      expect(a.hasEntries, isTrue);
    });
  });

  group('DateTimeDefaults', () {
    test('orNow returns current time when null', () {
      DateTime? a;
      withClock(Clock.fixed(DateTime.utc(2026, 1, 15)), () {
        expect(a.orNow(), DateTime.utc(2026, 1, 15));
      });

      a = DateTime.utc(2025, 6, 1);
      expect(a.orNow(), DateTime.utc(2025, 6, 1));
    });

    test('orDefault returns provided default when null', () {
      DateTime? a;
      final def = DateTime.utc(2026, 1, 1);
      expect(a.orDefault(def), def);

      a = DateTime.utc(2025, 6, 1);
      expect(a.orDefault(def), DateTime.utc(2025, 6, 1));
    });

    test('isNull / hasValue', () {
      DateTime? a;
      expect(a.isNull, isTrue);
      expect(a.hasValue, isFalse);

      a = DateTime.utc(2026, 1, 1);
      expect(a.isNull, isFalse);
      expect(a.hasValue, isTrue);
    });

    test('toIso8601OrEmpty', () {
      DateTime? a;
      expect(a.toIso8601OrEmpty(), '');
      a = DateTime.utc(2026, 1, 15);
      expect(a.toIso8601OrEmpty(), startsWith('2026-01-15'));
    });
  });

  group('IntDefaults', () {
    test('orZero / orDefault', () {
      int? a;
      expect(a.orZero(), 0);
      expect(a.orDefault(99), 99);
      a = 42;
      expect(a.orZero(), 42);
      expect(a.orDefault(99), 42);
    });

    test('isNullOrZero / isPositive', () {
      int? a;
      expect(a.isNullOrZero, isTrue);
      expect(a.isPositive, isFalse);

      a = 0;
      expect(a.isNullOrZero, isTrue);
      expect(a.isPositive, isFalse);

      a = 5;
      expect(a.isNullOrZero, isFalse);
      expect(a.isPositive, isTrue);

      a = -1;
      expect(a.isPositive, isFalse);
    });
  });

  group('DoubleDefaults', () {
    test('orZero / orDefault', () {
      double? a;
      expect(a.orZero(), 0.0);
      expect(a.orDefault(9.9), 9.9);
      a = 4.2;
      expect(a.orZero(), 4.2);
      expect(a.orDefault(9.9), 4.2);
    });

    test('isNullOrZero / isPositive', () {
      double? a;
      expect(a.isNullOrZero, isTrue);
      expect(a.isPositive, isFalse);

      a = 0.0;
      expect(a.isNullOrZero, isTrue);
      expect(a.isPositive, isFalse);

      a = 0.1;
      expect(a.isNullOrZero, isFalse);
      expect(a.isPositive, isTrue);

      a = -1.5;
      expect(a.isPositive, isFalse);
    });
  });

  group('BoolDefaults', () {
    test('orFalse / orTrue / orDefault', () {
      bool? a;
      expect(a.orFalse(), isFalse);
      expect(a.orTrue(), isTrue);
      expect(a.orDefault(true), isTrue);
      expect(a.orDefault(false), isFalse);

      a = true;
      expect(a.orFalse(), isTrue);
      expect(a.orTrue(), isTrue);
      expect(a.orDefault(false), isTrue);

      a = false;
      expect(a.orFalse(), isFalse);
      expect(a.orTrue(), isFalse);
      expect(a.orDefault(true), isFalse);
    });
  });
}
