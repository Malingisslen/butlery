/// Unit tests for SerializationUtils — safe* family + utilities.
///
/// Complements the existing serialization_utils_datetime_test.dart by
/// covering the safe-typed getters (string/int/double/bool/list/map/enum)
/// + cleanMap / hasRequiredFields / getMissingFields utilities.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/serialization_utils.dart';

enum _Color { red, green, blue }

void main() {
  group('safeString', () {
    test('returns value when string', () {
      expect(SerializationUtils.safeString({'k': 'v'}, 'k'), 'v');
    });

    test('returns default when null', () {
      expect(
          SerializationUtils.safeString({}, 'k', defaultValue: 'def'), 'def');
    });

    test('converts non-string via toString', () {
      expect(SerializationUtils.safeString({'k': 42}, 'k'), '42');
    });
  });

  group('safeNullableString', () {
    test('returns null when missing', () {
      expect(SerializationUtils.safeNullableString({}, 'k'), isNull);
    });

    test('returns string verbatim', () {
      expect(SerializationUtils.safeNullableString({'k': 'v'}, 'k'), 'v');
    });

    test('converts non-string via toString', () {
      expect(SerializationUtils.safeNullableString({'k': 7}, 'k'), '7');
    });
  });

  group('safeInt / safeNullableInt', () {
    test('safeInt returns int directly', () {
      expect(SerializationUtils.safeInt({'k': 5}, 'k'), 5);
    });

    test('safeInt converts num to int', () {
      expect(SerializationUtils.safeInt({'k': 5.7}, 'k'), 5);
    });

    test('safeInt parses numeric string', () {
      expect(SerializationUtils.safeInt({'k': '42'}, 'k'), 42);
    });

    test('safeInt falls back to default for non-parseable', () {
      expect(
          SerializationUtils.safeInt({'k': 'abc'}, 'k', defaultValue: 99), 99);
    });

    test('safeInt falls back to default for null', () {
      expect(SerializationUtils.safeInt({}, 'k', defaultValue: 11), 11);
    });

    test('safeNullableInt returns null for non-parseable', () {
      expect(SerializationUtils.safeNullableInt({'k': 'abc'}, 'k'), isNull);
    });

    test('safeNullableInt returns null for missing', () {
      expect(SerializationUtils.safeNullableInt({}, 'k'), isNull);
    });
  });

  group('safeDouble / safeNullableDouble', () {
    test('safeDouble returns double directly', () {
      expect(SerializationUtils.safeDouble({'k': 1.5}, 'k'), 1.5);
    });

    test('safeDouble converts int to double', () {
      expect(SerializationUtils.safeDouble({'k': 3}, 'k'), 3.0);
    });

    test('safeDouble parses numeric string', () {
      expect(SerializationUtils.safeDouble({'k': '4.2'}, 'k'), 4.2);
    });

    test('safeDouble falls back to default for non-parseable', () {
      expect(
          SerializationUtils.safeDouble({'k': 'abc'}, 'k', defaultValue: 9.9),
          9.9);
    });

    test('safeNullableDouble returns null for non-parseable', () {
      expect(SerializationUtils.safeNullableDouble({'k': 'abc'}, 'k'), isNull);
    });
  });

  group('safeBool / safeNullableBool', () {
    test('returns true for bool true', () {
      expect(SerializationUtils.safeBool({'k': true}, 'k'), isTrue);
    });

    test('returns false for bool false', () {
      expect(SerializationUtils.safeBool({'k': false}, 'k'), isFalse);
    });

    test('parses string "true"/"TRUE"/"1" as true', () {
      expect(SerializationUtils.safeBool({'k': 'true'}, 'k'), isTrue);
      expect(SerializationUtils.safeBool({'k': 'TRUE'}, 'k'), isTrue);
      expect(SerializationUtils.safeBool({'k': '1'}, 'k'), isTrue);
    });

    test('parses other strings as false', () {
      expect(SerializationUtils.safeBool({'k': 'yes'}, 'k'), isFalse);
    });

    test('numeric: non-zero = true, zero = false', () {
      expect(SerializationUtils.safeBool({'k': 1}, 'k'), isTrue);
      expect(SerializationUtils.safeBool({'k': 0}, 'k'), isFalse);
    });

    test('falls back to default for null', () {
      expect(SerializationUtils.safeBool({}, 'k', defaultValue: true), isTrue);
    });

    test('safeNullableBool returns null for missing', () {
      expect(SerializationUtils.safeNullableBool({}, 'k'), isNull);
    });
  });

  group('list utilities', () {
    test('safeList applies converter and skips bad items', () {
      final result = SerializationUtils.safeList<int>(
        {
          'k': [1, 'bad', 3]
        },
        'k',
        (raw) => raw as int, // throws on 'bad'
      );
      expect(result, [1, 3]);
    });

    test('safeList returns default when value not a list', () {
      final result = SerializationUtils.safeList<int>(
        {'k': 'not-a-list'},
        'k',
        (raw) => raw as int,
        defaultValue: const [42],
      );
      expect(result, [42]);
    });

    test('safeList returns empty when missing without default', () {
      expect(SerializationUtils.safeList<int>({}, 'k', (raw) => raw as int),
          isEmpty);
    });

    test('safeStringList converts each item via toString', () {
      expect(
          SerializationUtils.safeStringList({
            'k': ['a', 1, true]
          }, 'k'),
          ['a', '1', 'true']);
    });

    test('safeStringListMap returns null when missing or wrong type', () {
      expect(SerializationUtils.safeStringListMap({}, 'k'), isNull);
      expect(SerializationUtils.safeStringListMap({'k': 'str'}, 'k'), isNull);
    });

    test('safeStringListMap parses list-of-strings map', () {
      final result = SerializationUtils.safeStringListMap({
        'k': {
          'thumbs_up': ['u1', 'u2'],
          'heart': ['u3'],
        }
      }, 'k');
      expect(result?['thumbs_up'], ['u1', 'u2']);
      expect(result?['heart'], ['u3']);
    });

    test('safeObjectList unwraps Map<String, dynamic> with fromJson', () {
      final result = SerializationUtils.safeObjectList<String>(
        {
          'k': [
            {'name': 'a'},
            {'name': 'b'}
          ]
        },
        'k',
        (m) => m['name'] as String,
      );
      expect(result, ['a', 'b']);
    });
  });

  group('map utilities', () {
    test('safeMap returns map verbatim when Map<String,dynamic>', () {
      final m = SerializationUtils.safeMap({
        'k': <String, dynamic>{'a': 1}
      }, 'k');
      expect(m['a'], 1);
    });

    test('safeMap converts generic Map', () {
      final m = SerializationUtils.safeMap({
        'k': <dynamic, dynamic>{'a': 1}
      }, 'k');
      expect(m['a'], 1);
    });

    test('safeMap returns default for null', () {
      expect(SerializationUtils.safeMap({}, 'k'), isEmpty);
    });

    test('safeNullableMap returns null for missing', () {
      expect(SerializationUtils.safeNullableMap({}, 'k'), isNull);
    });

    test('safeNullableMap returns map when present', () {
      expect(
          SerializationUtils.safeNullableMap({
            'k': <String, dynamic>{'a': 1}
          }, 'k'),
          isNotNull);
    });
  });

  group('nested object utilities', () {
    test('safeNestedObject returns parsed result', () {
      final result = SerializationUtils.safeNestedObject<String>(
        {
          'k': {'name': 'a'}
        },
        'k',
        (m) => m['name'] as String,
      );
      expect(result, 'a');
    });

    test('safeNestedObject returns null for missing', () {
      expect(
          SerializationUtils.safeNestedObject<String>(
              {}, 'k', (m) => m['name'] as String),
          isNull);
    });

    test('safeNestedObject returns null when fromJson throws', () {
      final result = SerializationUtils.safeNestedObject<String>(
        {
          'k': {'name': 123}
        },
        'k',
        (m) => m['name'] as String, // throws on non-string
      );
      expect(result, isNull);
    });

    test('safeRequiredNestedObject falls back to default', () {
      final result = SerializationUtils.safeRequiredNestedObject<String>(
        {},
        'k',
        (m) => m['name'] as String,
        'default',
      );
      expect(result, 'default');
    });
  });

  group('enum utilities', () {
    test('safeEnum matches by enum string', () {
      expect(
          SerializationUtils.safeEnum(
              {'k': 'green'}, 'k', _Color.values, _Color.red, (e) => e.name),
          _Color.green);
    });

    test('safeEnum falls back to default for unknown value', () {
      expect(
          SerializationUtils.safeEnum(
              {'k': 'purple'}, 'k', _Color.values, _Color.red, (e) => e.name),
          _Color.red);
    });

    test('safeEnumByName uses Enum.byName', () {
      expect(
          SerializationUtils.safeEnumByName(_Color.values, 'blue', _Color.red),
          _Color.blue);
    });

    test('safeEnumByName falls back for missing name', () {
      expect(
          SerializationUtils.safeEnumByName(
              _Color.values, 'unknown', _Color.red),
          _Color.red);
    });

    test('safeNullableEnum returns null for unknown', () {
      expect(
          SerializationUtils.safeNullableEnum(
              {'k': 'unknown'}, 'k', _Color.values, (e) => e.name),
          isNull);
    });

    test('safeNullableEnum returns null for missing', () {
      expect(
          SerializationUtils.safeNullableEnum<_Color>(
              {}, 'k', _Color.values, (e) => e.name),
          isNull);
    });

    test('serializeEnum maps non-null + null', () {
      expect(
          SerializationUtils.serializeEnum(_Color.red, (e) => e.name), 'red');
      expect(SerializationUtils.serializeEnum<_Color>(null, (e) => e.name),
          isNull);
    });
  });

  group('cleanup / required fields', () {
    test('cleanMap removes null entries', () {
      final cleaned =
          SerializationUtils.cleanMap({'a': 1, 'b': null, 'c': 'x'});
      expect(cleaned.keys.toSet(), {'a', 'c'});
    });

    test('hasRequiredFields checks every field present and non-null', () {
      expect(SerializationUtils.hasRequiredFields({'a': 1, 'b': 2}, ['a', 'b']),
          isTrue);
      expect(
          SerializationUtils.hasRequiredFields({'a': 1}, ['a', 'b']), isFalse);
      expect(
          SerializationUtils.hasRequiredFields({'a': 1, 'b': null}, ['a', 'b']),
          isFalse);
    });

    test('getMissingFields returns absent + null keys', () {
      expect(
          SerializationUtils.getMissingFields(
              {'a': 1, 'b': null}, ['a', 'b', 'c']),
          ['b', 'c']);
    });
  });

  group('list-of-string serializer pass-through', () {
    test('serializeStringList returns input unchanged', () {
      expect(
          SerializationUtils.serializeStringList(const ['a', 'b']), ['a', 'b']);
      expect(SerializationUtils.serializeStringList(null), isNull);
    });

    test('serializeList maps each element + returns null for null input', () {
      expect(SerializationUtils.serializeList<int>([1, 2, 3], (n) => 'v$n'),
          ['v1', 'v2', 'v3']);
      expect(SerializationUtils.serializeList<int>(null, (n) => '$n'), isNull);
    });

    test('serializeDateTime returns ISO + null for null', () {
      final dt = DateTime.utc(2026, 1, 15);
      expect(
          SerializationUtils.serializeDateTime(dt), '2026-01-15T00:00:00.000Z');
      expect(SerializationUtils.serializeDateTime(null), isNull);
    });

    test('serializeNestedObject delegates to toJson when non-null', () {
      expect(SerializationUtils.serializeNestedObject<int>(5, (n) => {'v': n}),
          {'v': 5});
      expect(SerializationUtils.serializeNestedObject<int>(null, (n) => {}),
          isNull);
    });
  });
}
