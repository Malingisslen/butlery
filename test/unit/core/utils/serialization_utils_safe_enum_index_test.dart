import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/core/utils/serialization_utils.dart';

enum _Sample { a, b, c }

void main() {
  group('SerializationUtils.safeEnumByIndex', () {
    test('returns the enum value at a valid in-range index', () {
      expect(
        SerializationUtils.safeEnumByIndex(0, _Sample.values, _Sample.c),
        equals(_Sample.a),
      );
      expect(
        SerializationUtils.safeEnumByIndex(2, _Sample.values, _Sample.a),
        equals(_Sample.c),
      );
    });

    test('falls back to default for an index past the end (no RangeError)', () {
      // A newer client could write an index this client's enum doesn't have.
      expect(
        SerializationUtils.safeEnumByIndex(99, _Sample.values, _Sample.a),
        equals(_Sample.a),
      );
    });

    test('treats exactly values.length as out of range (no off-by-one)', () {
      // Boundary: last valid index is length-1; length itself must fall back.
      expect(
        SerializationUtils.safeEnumByIndex(
          _Sample.values.length - 1,
          _Sample.values,
          _Sample.a,
        ),
        equals(_Sample.c),
      );
      expect(
        SerializationUtils.safeEnumByIndex(
          _Sample.values.length,
          _Sample.values,
          _Sample.a,
        ),
        equals(_Sample.a),
      );
    });

    test('falls back to default for a negative index', () {
      expect(
        SerializationUtils.safeEnumByIndex(-1, _Sample.values, _Sample.b),
        equals(_Sample.b),
      );
    });

    test('falls back to default for non-int / null stored values', () {
      expect(
        SerializationUtils.safeEnumByIndex('1', _Sample.values, _Sample.b),
        equals(_Sample.b),
      );
      expect(
        SerializationUtils.safeEnumByIndex(null, _Sample.values, _Sample.b),
        equals(_Sample.b),
      );
      expect(
        SerializationUtils.safeEnumByIndex(1.0, _Sample.values, _Sample.b),
        equals(_Sample.b),
      );
    });
  });
}
