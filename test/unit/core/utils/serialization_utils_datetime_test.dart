import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/core/utils/serialization_utils.dart';

void main() {
  group('SerializationUtils.parseDateTimeValue', () {
    test('null returns null', () {
      expect(SerializationUtils.parseDateTimeValue(null), isNull);
    });

    test('DateTime passes through unchanged', () {
      final dt = DateTime(2024, 1, 15, 10, 30);
      expect(SerializationUtils.parseDateTimeValue(dt), equals(dt));
    });

    test('valid ISO string parses correctly', () {
      final result = SerializationUtils.parseDateTimeValue(
        '2024-01-15T10:30:00.000',
      );
      expect(result, equals(DateTime(2024, 1, 15, 10, 30)));
    });

    test('invalid string returns null', () {
      expect(SerializationUtils.parseDateTimeValue('not-a-date'), isNull);
    });

    test('empty string returns null', () {
      expect(SerializationUtils.parseDateTimeValue(''), isNull);
    });

    test('int epoch millis parses correctly', () {
      final millis = DateTime(2024, 1, 15, 10, 30).millisecondsSinceEpoch;
      final result = SerializationUtils.parseDateTimeValue(millis);
      expect(result, equals(DateTime(2024, 1, 15, 10, 30)));
    });

    test('Map with seconds and nanoseconds parses correctly', () {
      final result = SerializationUtils.parseDateTimeValue({
        'seconds': 1705312200,
        'nanoseconds': 500000000,
      });
      expect(result, isNotNull);
      expect(result!.millisecondsSinceEpoch, equals(1705312200 * 1000 + 500));
    });

    test('Map with _seconds (JS SDK variant) parses correctly', () {
      final result = SerializationUtils.parseDateTimeValue({
        '_seconds': 1705312200,
      });
      expect(result, isNotNull);
      expect(result!.millisecondsSinceEpoch, equals(1705312200 * 1000));
    });

    test('Map with _seconds and _nanoseconds parses correctly', () {
      final result = SerializationUtils.parseDateTimeValue({
        '_seconds': 1705312200,
        '_nanoseconds': 500000000,
      });
      expect(result, isNotNull);
      expect(result!.millisecondsSinceEpoch, equals(1705312200 * 1000 + 500));
    });

    test('Map without seconds key returns null', () {
      expect(
        SerializationUtils.parseDateTimeValue({'unrelated': 'map'}),
        isNull,
      );
    });

    test('unsupported type returns null', () {
      expect(SerializationUtils.parseDateTimeValue(3.14), isNull);
      expect(SerializationUtils.parseDateTimeValue(true), isNull);
      expect(SerializationUtils.parseDateTimeValue([1, 2, 3]), isNull);
    });
  });

  group('SerializationUtils.parseRequiredDateTimeValue', () {
    test('null returns approximately DateTime.now()', () {
      final before = DateTime.now();
      final result = SerializationUtils.parseRequiredDateTimeValue(null);
      final after = DateTime.now();
      expect(
        result.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(result.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('null with custom default returns that default', () {
      final custom = DateTime(2020, 6, 15);
      final result = SerializationUtils.parseRequiredDateTimeValue(
        null,
        defaultValue: custom,
      );
      expect(result, equals(custom));
    });

    test('valid value parses normally', () {
      final result = SerializationUtils.parseRequiredDateTimeValue(
        '2024-01-15T10:30:00.000',
      );
      expect(result, equals(DateTime(2024, 1, 15, 10, 30)));
    });

    test('invalid string falls back to DateTime.now()', () {
      final before = DateTime.now();
      final result = SerializationUtils.parseRequiredDateTimeValue(
        'not-a-date',
      );
      final after = DateTime.now();
      expect(
        result.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(result.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });
  });

  group('SerializationUtils.safeDateTime delegates correctly', () {
    test('map + key works for String value', () {
      final map = {'date': '2024-01-15T10:30:00.000'};
      expect(
        SerializationUtils.safeDateTime(map, 'date'),
        equals(DateTime(2024, 1, 15, 10, 30)),
      );
    });

    test('map + key works for int value', () {
      final millis = DateTime(2024, 1, 15).millisecondsSinceEpoch;
      final map = {'date': millis};
      expect(
        SerializationUtils.safeDateTime(map, 'date'),
        equals(DateTime(2024, 1, 15)),
      );
    });

    test('map + key handles Map seconds value', () {
      final map = {
        'date': {'seconds': 1705312200, 'nanoseconds': 0},
      };
      final result = SerializationUtils.safeDateTime(map, 'date');
      expect(result, isNotNull);
      expect(result!.millisecondsSinceEpoch, equals(1705312200 * 1000));
    });

    test('missing key returns null', () {
      expect(SerializationUtils.safeDateTime({}, 'date'), isNull);
    });
  });

  group('SerializationUtils.safeRequiredDateTime', () {
    test('valid key returns parsed DateTime', () {
      final map = {'date': '2024-01-15T10:30:00.000'};
      expect(
        SerializationUtils.safeRequiredDateTime(map, 'date'),
        equals(DateTime(2024, 1, 15, 10, 30)),
      );
    });

    test('missing key returns DateTime.now()', () {
      final before = DateTime.now();
      final result = SerializationUtils.safeRequiredDateTime({}, 'date');
      final after = DateTime.now();
      expect(
        result.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(result.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });
  });

  group('parseDateTimeValue edge cases', () {
    test('Map with explicit seconds: null returns null', () {
      expect(
        SerializationUtils.parseDateTimeValue({'seconds': null}),
        isNull,
      );
    });

    test('Map with seconds: 0 returns epoch', () {
      final result = SerializationUtils.parseDateTimeValue({'seconds': 0});
      expect(result, equals(DateTime.fromMillisecondsSinceEpoch(0)));
    });
  });
}
