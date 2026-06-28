/// Direct unit tests for [SerializationUtils] + its Map extension + the
/// serialization mixin (BUT-1149 coverage burndown — previously zero direct
/// coverage).
///
/// This is the foundational type-coercion layer every Firestore document parse
/// runs through. The contract it must honor: read loosely-typed map values into
/// strict Dart types, coercing where sensible (num→int, "true"→bool, epoch→
/// DateTime), falling back to a default (or null) when a value is absent or
/// unconvertible, and — for the strict variants — throwing FormatException so
/// corrupt documents fail loud instead of masquerading as fresh data (BUT-1071).
library;

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/serialization_utils.dart';

enum _Color { red, green, blue }

class _Widget with SerializationMixin {
  _Widget({required this.name, this.valid = true});
  final String name;
  final bool valid;

  @override
  Map<String, dynamic> toJson() => {'name': name, 'note': null};

  @override
  bool get isValid => valid;

  @override
  List<String> get requiredFields => const [];
}

void main() {
  group('safeString / safeNullableString', () {
    test('returns the string, coerces non-strings, falls back on null', () {
      expect(SerializationUtils.safeString({'k': 'hi'}, 'k'), 'hi');
      expect(SerializationUtils.safeString({'k': 7}, 'k'), '7');
      expect(SerializationUtils.safeString({}, 'k'), '');
      expect(
        SerializationUtils.safeString({}, 'k', defaultValue: 'd'),
        'd',
      );
    });

    test('nullable variant returns null when absent', () {
      expect(SerializationUtils.safeNullableString({}, 'k'), isNull);
      expect(SerializationUtils.safeNullableString({'k': 9}, 'k'), '9');
    });
  });

  group('safeInt / safeNullableInt', () {
    test('passes ints, truncates nums, parses strings, defaults otherwise', () {
      expect(SerializationUtils.safeInt({'k': 5}, 'k'), 5);
      expect(SerializationUtils.safeInt({'k': 5.9}, 'k'), 5);
      expect(SerializationUtils.safeInt({'k': '42'}, 'k'), 42);
      expect(
        SerializationUtils.safeInt({'k': 'nope'}, 'k', defaultValue: -1),
        -1,
      );
      expect(SerializationUtils.safeInt({}, 'k'), 0);
    });

    test('nullable variant returns null when absent or unparseable', () {
      expect(SerializationUtils.safeNullableInt({}, 'k'), isNull);
      expect(SerializationUtils.safeNullableInt({'k': 'x'}, 'k'), isNull);
      expect(SerializationUtils.safeNullableInt({'k': '3'}, 'k'), 3);
    });
  });

  group('safeDouble / safeNullableDouble', () {
    test('passes doubles, widens nums, parses strings, defaults otherwise', () {
      expect(SerializationUtils.safeDouble({'k': 1.5}, 'k'), 1.5);
      expect(SerializationUtils.safeDouble({'k': 2}, 'k'), 2.0);
      expect(SerializationUtils.safeDouble({'k': '3.25'}, 'k'), 3.25);
      expect(SerializationUtils.safeDouble({}, 'k', defaultValue: 9.9), 9.9);
    });

    test('nullable variant returns null when absent or unparseable', () {
      expect(SerializationUtils.safeNullableDouble({}, 'k'), isNull);
      expect(SerializationUtils.safeNullableDouble({'k': 'x'}, 'k'), isNull);
    });
  });

  group('safeBool / safeNullableBool', () {
    test('reads bools, "true"/"1" strings and non-zero nums', () {
      expect(SerializationUtils.safeBool({'k': true}, 'k'), isTrue);
      expect(SerializationUtils.safeBool({'k': 'TRUE'}, 'k'), isTrue);
      expect(SerializationUtils.safeBool({'k': '1'}, 'k'), isTrue);
      expect(SerializationUtils.safeBool({'k': 'no'}, 'k'), isFalse);
      expect(SerializationUtils.safeBool({'k': 2}, 'k'), isTrue);
      expect(SerializationUtils.safeBool({'k': 0}, 'k'), isFalse);
      expect(SerializationUtils.safeBool({}, 'k', defaultValue: true), isTrue);
    });

    test('nullable variant returns null when absent', () {
      expect(SerializationUtils.safeNullableBool({}, 'k'), isNull);
      expect(SerializationUtils.safeNullableBool({'k': 'true'}, 'k'), isTrue);
    });
  });

  group('parseDateTimeValue', () {
    test('reads DateTime, ISO string, and epoch-millis int', () {
      final dt = DateTime.utc(2026, 1, 1);
      expect(SerializationUtils.parseDateTimeValue(dt), dt);
      expect(
        SerializationUtils.parseDateTimeValue('2026-01-01T00:00:00.000Z'),
        dt,
      );
      expect(
        SerializationUtils.parseDateTimeValue(0),
        DateTime.fromMillisecondsSinceEpoch(0),
      );
    });

    test('reads a Firebase Timestamp via duck-typing', () {
      final ts = Timestamp.fromDate(DateTime.utc(2020, 6, 1));
      expect(SerializationUtils.parseDateTimeValue(ts), isA<DateTime>());
    });

    test('reads raw Firestore {seconds,nanoseconds} and JS _seconds maps', () {
      expect(
        SerializationUtils.parseDateTimeValue({
          'seconds': 1000,
          'nanoseconds': 0,
        }),
        DateTime.fromMillisecondsSinceEpoch(1000000),
      );
      expect(
        SerializationUtils.parseDateTimeValue({
          '_seconds': 1,
          '_nanoseconds': 0,
        }),
        DateTime.fromMillisecondsSinceEpoch(1000),
      );
    });

    test('returns null for null and unrecognized shapes', () {
      expect(SerializationUtils.parseDateTimeValue(null), isNull);
      expect(SerializationUtils.parseDateTimeValue('not a date'), isNull);
      expect(SerializationUtils.parseDateTimeValue({'foo': 1}), isNull);
    });
  });

  group('required date/string (fail-loud, BUT-1071)', () {
    test('requiredDateTime throws when missing or unparseable', () {
      expect(
        () => SerializationUtils.requiredDateTime({}, 'k'),
        throwsFormatException,
      );
      expect(
        () => SerializationUtils.requiredDateTime({'k': 'bad'}, 'k'),
        throwsFormatException,
      );
      expect(
        SerializationUtils.requiredDateTime(
          {'k': '2026-01-01T00:00:00.000Z'},
          'k',
        ),
        DateTime.utc(2026, 1, 1),
      );
    });

    test('requiredString throws when missing or empty', () {
      expect(
        () => SerializationUtils.requiredString({}, 'k'),
        throwsFormatException,
      );
      expect(
        () => SerializationUtils.requiredString({'k': ''}, 'k'),
        throwsFormatException,
      );
      expect(SerializationUtils.requiredString({'k': 'ok'}, 'k'), 'ok');
    });
  });

  group('parseRequiredDateTimeValue / serializeDateTime', () {
    test('falls back to the explicit default, then to clock.now()', () {
      final fallback = DateTime.utc(2030);
      expect(
        SerializationUtils.parseRequiredDateTimeValue(
          null,
          defaultValue: fallback,
        ),
        fallback,
      );
      withClock(Clock.fixed(DateTime.utc(2026, 1, 1)), () {
        expect(
          SerializationUtils.parseRequiredDateTimeValue(null),
          DateTime.utc(2026, 1, 1),
        );
      });
    });

    test('serializeDateTime emits ISO-8601 or null', () {
      expect(SerializationUtils.serializeDateTime(null), isNull);
      expect(
        SerializationUtils.serializeDateTime(DateTime.utc(2026, 1, 1)),
        '2026-01-01T00:00:00.000Z',
      );
    });
  });

  group('lists', () {
    test('safeStringList coerces items and defaults when not a list', () {
      expect(
        SerializationUtils.safeStringList({
          'k': ['a', 1, true],
        }, 'k'),
        ['a', '1', 'true'],
      );
      expect(SerializationUtils.safeStringList({'k': 'notlist'}, 'k'), isEmpty);
      expect(
        SerializationUtils.safeStringList({}, 'k', defaultValue: ['d']),
        ['d'],
      );
    });

    test('safeList skips items whose converter throws', () {
      final result = SerializationUtils.safeList<int>(
        {
          'k': ['1', 'x', '3'],
        },
        'k',
        (item) => int.parse(item as String), // throws on 'x'
      );
      expect(result, [1, 3]);
    });

    test('safeStringListMap parses a map of string→list, null when absent', () {
      expect(
        SerializationUtils.safeStringListMap(
          {
            'k': <String, dynamic>{
              '👍': ['u1', 'u2'],
              'bad': 7,
            },
          },
          'k',
        ),
        {
          '👍': ['u1', 'u2'],
        },
      );
      expect(SerializationUtils.safeStringListMap({}, 'k'), isNull);
    });

    test('safeObjectList maps each entry through fromJson', () {
      final result = SerializationUtils.safeObjectList<String>(
        {
          'k': [
            {'n': 'a'},
            {'n': 'b'},
          ],
        },
        'k',
        (m) => m['n'] as String,
      );
      expect(result, ['a', 'b']);
    });

    test('serializeList / serializeStringList', () {
      expect(SerializationUtils.serializeList<int>(null, (x) => x), isNull);
      expect(
        SerializationUtils.serializeList<int>([1, 2], (x) => x * 10),
        [10, 20],
      );
      expect(SerializationUtils.serializeStringList(['a']), ['a']);
    });
  });

  group('maps + nested objects', () {
    test('safeMap returns the map or a default', () {
      expect(
        SerializationUtils.safeMap({
          'k': {'a': 1},
        }, 'k'),
        {'a': 1},
      );
      expect(SerializationUtils.safeMap({}, 'k'), <String, dynamic>{});
    });

    test('safeNullableMap returns null when absent', () {
      expect(SerializationUtils.safeNullableMap({}, 'k'), isNull);
      expect(
        SerializationUtils.safeNullableMap({
          'k': {'a': 1},
        }, 'k'),
        {'a': 1},
      );
    });

    test('safeNestedObject returns null on missing or throwing fromJson', () {
      expect(
        SerializationUtils.safeNestedObject<String>(
          {
            'k': {'n': 'x'},
          },
          'k',
          (m) => m['n'] as String,
        ),
        'x',
      );
      expect(
        SerializationUtils.safeNestedObject<String>({}, 'k', (m) => 'x'),
        isNull,
      );
      expect(
        SerializationUtils.safeNestedObject<String>(
          {
            'k': {'n': 'x'},
          },
          'k',
          (m) => throw StateError('boom'),
        ),
        isNull,
      );
    });

    test('safeRequiredNestedObject uses the default on failure', () {
      expect(
        SerializationUtils.safeRequiredNestedObject<String>(
          {},
          'k',
          (m) => 'x',
          'fallback',
        ),
        'fallback',
      );
    });

    test('serializeNestedObject emits toJson or null', () {
      expect(
        SerializationUtils.serializeNestedObject<String>('x', (s) => {'v': s}),
        {'v': 'x'},
      );
      expect(
        SerializationUtils.serializeNestedObject<String>(null, (s) => {'v': s}),
        isNull,
      );
    });
  });

  group('enums', () {
    test('safeEnum matches by string form, falls back on miss', () {
      String name(_Color c) => c.name;
      expect(
        SerializationUtils.safeEnum(
          {'c': 'green'},
          'c',
          _Color.values,
          _Color.red,
          name,
        ),
        _Color.green,
      );
      expect(
        SerializationUtils.safeEnum({}, 'c', _Color.values, _Color.red, name),
        _Color.red,
      );
      expect(
        SerializationUtils.safeEnum(
          {'c': 'purple'},
          'c',
          _Color.values,
          _Color.red,
          name,
        ),
        _Color.red,
      );
    });

    test('safeEnumByName looks up by name with a fallback', () {
      expect(
        SerializationUtils.safeEnumByName(_Color.values, 'blue', _Color.red),
        _Color.blue,
      );
      expect(
        SerializationUtils.safeEnumByName(_Color.values, 'cyan', _Color.red),
        _Color.red,
      );
    });

    test('safeEnumByIndex guards out-of-range and non-int indices', () {
      expect(
        SerializationUtils.safeEnumByIndex(1, _Color.values, _Color.red),
        _Color.green,
      );
      expect(
        SerializationUtils.safeEnumByIndex(99, _Color.values, _Color.red),
        _Color.red,
      );
      expect(
        SerializationUtils.safeEnumByIndex('x', _Color.values, _Color.red),
        _Color.red,
      );
    });

    test('safeNullableEnum returns null on miss, serializeEnum emits name', () {
      String name(_Color c) => c.name;
      expect(
        SerializationUtils.safeNullableEnum({}, 'c', _Color.values, name),
        isNull,
      );
      expect(SerializationUtils.serializeEnum(_Color.blue, name), 'blue');
      expect(SerializationUtils.serializeEnum<_Color>(null, name), isNull);
    });
  });

  group('validation + conversion utilities', () {
    test('cleanMap drops null-valued entries', () {
      expect(
        SerializationUtils.cleanMap({'a': 1, 'b': null, 'c': 'x'}),
        {'a': 1, 'c': 'x'},
      );
    });

    test(
      'hasRequiredFields / getMissingFields detect absent or null fields',
      () {
        final map = {'a': 1, 'b': null};
        expect(SerializationUtils.hasRequiredFields(map, ['a']), isTrue);
        expect(SerializationUtils.hasRequiredFields(map, ['a', 'b']), isFalse);
        expect(
          SerializationUtils.getMissingFields(map, ['a', 'b', 'c']),
          ['b', 'c'],
        );
      },
    );

    test('convertTo coerces to the requested type or null', () {
      expect(SerializationUtils.convertTo<String>(7), '7');
      expect(SerializationUtils.convertTo<int>('5'), 5);
      expect(SerializationUtils.convertTo<double>(2), 2.0);
      expect(SerializationUtils.convertTo<bool>('1'), isTrue);
      expect(SerializationUtils.convertTo<int>(null), isNull);
    });

    test('safeIntKeyIntMap parses string-keyed maps, null when empty', () {
      expect(
        SerializationUtils.safeIntKeyIntMap({
          'k': {'1': 10, '2': 20},
        }, 'k'),
        {1: 10, 2: 20},
      );
      expect(
        SerializationUtils.safeIntKeyIntMap({
          'k': {'x': 1},
        }, 'k'),
        isNull,
      );
      expect(SerializationUtils.safeIntKeyIntMap({}, 'k'), isNull);
    });

    test('convertMapValues converts values, skipping failures', () {
      final result = SerializationUtils.convertMapValues<int>(
        {'a': '1', 'b': 'x', 'c': '3'},
        (v) => int.parse(v as String),
      );
      expect(result, {'a': 1, 'c': 3});
    });
  });

  group('Map extension methods delegate to SerializationUtils', () {
    test('safeString / safeInt / cleaned()', () {
      final map = <String, dynamic>{'s': 'hi', 'n': '4', 'gone': null};
      expect(map.safeString('s'), 'hi');
      expect(map.safeInt('n'), 4);
      expect(map.cleaned(), {'s': 'hi', 'n': '4'});
    });
  });

  group('SerializationMixin', () {
    test('toCleanJson strips nulls from toJson()', () {
      expect(_Widget(name: 'x').toCleanJson(), {'name': 'x'});
    });

    test('toValidatedJson throws when the object is invalid', () {
      expect(
        () => _Widget(name: 'x', valid: false).toValidatedJson(),
        throwsStateError,
      );
      expect(_Widget(name: 'x').toValidatedJson(), {'name': 'x', 'note': null});
    });
  });
}
