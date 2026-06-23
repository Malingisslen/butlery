/// Unit tests for JsonSerializableMixin + TimestampedMixin + IdentifiableMixin
/// + OwnedMixin + SerializationUtils (mixin-file variant).
///
/// Pure-Dart; targets the 117 unhit lines in
/// lib/core/mixins/json_serializable_mixin.dart.
library;

import 'package:flutter_test/flutter_test.dart';

// Aliased to avoid name clash with the other SerializationUtils in
// lib/core/utils/serialization_utils.dart.
import 'package:butlery/core/mixins/json_serializable_mixin.dart' as mixin_lib;

enum _Color { red, green, blue }

/// Concrete model exercising all four mixins.
class _Model
    with
        mixin_lib.JsonSerializableMixin,
        mixin_lib.TimestampedMixin,
        mixin_lib.IdentifiableMixin,
        mixin_lib.OwnedMixin {
  @override
  final String id;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;
  @override
  final String? ownerId;
  @override
  final String? createdBy;

  final String name;

  _Model({
    required this.id,
    required this.name,
    this.createdAt,
    this.updatedAt,
    this.ownerId,
    this.createdBy,
  });

  @override
  Map<String, dynamic> toJson() => {
    ...serializeId(),
    ...serializeTimestamps(),
    ...serializeOwnership(),
    'name': name,
  };
}

void main() {
  group('extractString / extractOptionalString', () {
    final m = _Model(id: 'i', name: 'n');

    test('extractString returns value when string', () {
      expect(m.extractString(const {'k': 'v'}, 'k'), 'v');
    });

    test('extractString returns default when missing', () {
      expect(m.extractString(const {}, 'k', defaultValue: 'def'), 'def');
    });

    test('extractString returns default when wrong type', () {
      expect(m.extractString(const {'k': 42}, 'k', defaultValue: 'def'), 'def');
    });

    test('extractOptionalString returns null when missing', () {
      expect(m.extractOptionalString(const {}, 'k'), isNull);
    });

    test('extractOptionalString returns value when present', () {
      expect(m.extractOptionalString(const {'k': 'v'}, 'k'), 'v');
    });
  });

  group('extractInt / extractDouble / extractBool', () {
    final m = _Model(id: 'i', name: 'n');

    test('extractInt parses int / double / string', () {
      expect(m.extractInt(const {'k': 5}, 'k'), 5);
      expect(m.extractInt(const {'k': 5.7}, 'k'), 5);
      expect(m.extractInt(const {'k': '42'}, 'k'), 42);
      expect(m.extractInt(const {'k': 'abc'}, 'k', defaultValue: 99), 99);
      expect(m.extractInt(const {}, 'k', defaultValue: 11), 11);
    });

    test('extractDouble parses double / int / string', () {
      expect(m.extractDouble(const {'k': 1.5}, 'k'), 1.5);
      expect(m.extractDouble(const {'k': 3}, 'k'), 3.0);
      expect(m.extractDouble(const {'k': '4.2'}, 'k'), 4.2);
      expect(m.extractDouble(const {'k': 'bad'}, 'k', defaultValue: 9.9), 9.9);
    });

    test('extractBool handles bool / string / default', () {
      expect(m.extractBool(const {'k': true}, 'k'), isTrue);
      expect(m.extractBool(const {'k': 'TRUE'}, 'k'), isTrue);
      expect(m.extractBool(const {'k': 'yes'}, 'k'), isFalse);
      expect(m.extractBool(const {}, 'k', defaultValue: true), isTrue);
    });
  });

  group('serializeDateTime / deserializeDateTime', () {
    final m = _Model(id: 'i', name: 'n');

    test('serializeDateTime null safety', () {
      expect(m.serializeDateTime(null), isNull);
      expect(
        m.serializeDateTime(DateTime.utc(2026, 1, 1)),
        startsWith('2026-01-01'),
      );
    });

    test('deserializeDateTime parses ISO + handles null + invalid', () {
      expect(m.deserializeDateTime(null), isNull);
      expect(
        m.deserializeDateTime('2026-01-01T00:00:00Z'),
        DateTime.utc(2026, 1, 1),
      );
      expect(m.deserializeDateTime('not-a-date'), isNull);
      expect(m.deserializeDateTime(42), isNull);
    });
  });

  group('serializeList / deserializeList', () {
    final m = _Model(id: 'i', name: 'n');

    test('serializeList null returns null', () {
      expect(m.serializeList<_Model>(null), isNull);
    });

    test('serializeList of JsonSerializableMixin items maps to toJson()', () {
      final items = [_Model(id: '1', name: 'a'), _Model(id: '2', name: 'b')];
      final result = m.serializeList(items);
      expect(result?.length, 2);
      expect(result?[0]['id'], '1');
    });

    test('serializeList throws ArgumentError for non-serializable items', () {
      expect(
        () => m.serializeList<String>(const ['a']),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('deserializeList returns empty for null / non-list', () {
      expect(m.deserializeList<int>(null, (j) => j['v'] as int), isEmpty);
      expect(m.deserializeList<int>('str', (j) => j['v'] as int), isEmpty);
    });

    test('deserializeList skips malformed entries', () {
      final result = m.deserializeList<int>(
        [
          {'v': 1},
          'not-a-map',
          {'v': 3},
        ],
        (j) => j['v'] as int,
      );
      expect(result, [1, 3]);
    });

    test('deserializeList swallows fromJson errors', () {
      final result = m.deserializeList<int>(
        [
          {'v': 'bad'},
          {'v': 2},
        ],
        (j) => j['v'] as int, // throws on 'bad'
      );
      expect(result, [2]);
    });
  });

  group('serializeEnum / deserializeEnum', () {
    final m = _Model(id: 'i', name: 'n');

    test('serializeEnum returns name or null', () {
      expect(m.serializeEnum(_Color.red), 'red');
      expect(m.serializeEnum<_Color>(null), isNull);
    });

    test('deserializeEnum returns enum or null', () {
      expect(m.deserializeEnum('blue', _Color.values), _Color.blue);
      expect(m.deserializeEnum(null, _Color.values), isNull);
      expect(m.deserializeEnum(42, _Color.values), isNull);
      expect(m.deserializeEnum('unknown', _Color.values), isNull);
    });
  });

  group('extractList / extractMap', () {
    final m = _Model(id: 'i', name: 'n');

    test('extractList returns converted items, skips errors', () {
      final result = m.extractList<int>(
        const {
          'k': [1, 2, 'bad', 4],
        },
        'k',
        (item) => item as int,
      );
      expect(result, [1, 2, 4]);
    });

    test('extractList returns default for non-list', () {
      expect(
        m.extractList<int>(
          const {'k': 'str'},
          'k',
          (item) => item as int,
          defaultValue: const [99],
        ),
        [99],
      );
    });

    test('extractMap converts entries, skips errors', () {
      final result = m.extractMap<int>(
        const {
          'k': {'a': 1, 'b': 'bad', 'c': 3},
        },
        'k',
        (v) => v as int,
      );
      expect(result, {'a': 1, 'c': 3});
    });

    test('extractMap returns default for non-map', () {
      expect(
        m.extractMap<int>(
          const {'k': 'str'},
          'k',
          (v) => v as int,
          defaultValue: const {'def': 1},
        ),
        {'def': 1},
      );
    });
  });

  group('TimestampedMixin', () {
    test('serializeTimestamps emits both keys', () {
      final m = _Model(
        id: 'i',
        name: 'n',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 2, 1),
      );
      final ts = m.serializeTimestamps();
      expect(ts['createdAt'], startsWith('2026-01-01'));
      expect(ts['updatedAt'], startsWith('2026-02-01'));
    });

    test('deserializeTimestamps parses both', () {
      final m = _Model(id: 'i', name: 'n');
      final result = m.deserializeTimestamps(const {
        'createdAt': '2026-01-01T00:00:00Z',
        'updatedAt': '2026-02-01T00:00:00Z',
      });
      expect(result['createdAt'], DateTime.utc(2026, 1, 1));
      expect(result['updatedAt'], DateTime.utc(2026, 2, 1));
    });
  });

  group('IdentifiableMixin', () {
    test('serializeId emits {id: ...}', () {
      final m = _Model(id: 'abc', name: 'n');
      expect(m.serializeId(), {'id': 'abc'});
    });

    test('extractId returns the id string', () {
      final m = _Model(id: 'placeholder', name: 'n');
      expect(m.extractId(const {'id': 'extracted'}), 'extracted');
    });
  });

  group('OwnedMixin', () {
    test('serializeOwnership emits ownerId + createdBy', () {
      final m = _Model(id: 'i', name: 'n', ownerId: 'o', createdBy: 'c');
      expect(m.serializeOwnership(), {'ownerId': 'o', 'createdBy': 'c'});
    });

    test('deserializeOwnership extracts both fields', () {
      final m = _Model(id: 'i', name: 'n');
      final result = m.deserializeOwnership(const {
        'ownerId': 'o',
        'createdBy': 'c',
      });
      expect(result, {'ownerId': 'o', 'createdBy': 'c'});
    });
  });

  group('SerializationUtils (mixin-file)', () {
    test('parseJson returns null for null/empty/invalid', () {
      expect(mixin_lib.SerializationUtils.parseJson(null), isNull);
      expect(mixin_lib.SerializationUtils.parseJson(''), isNull);
      expect(mixin_lib.SerializationUtils.parseJson('not-json'), isNull);
    });

    test('parseJson returns map for valid JSON object', () {
      final m = mixin_lib.SerializationUtils.parseJson('{"a": 1}');
      expect(m, {'a': 1});
    });

    test('parseJson returns null for valid JSON that is not a map', () {
      expect(mixin_lib.SerializationUtils.parseJson('[1, 2, 3]'), isNull);
    });

    test('encodeJson returns null for null', () {
      expect(mixin_lib.SerializationUtils.encodeJson(null), isNull);
    });

    test('encodeJson returns JSON string for map', () {
      expect(
        mixin_lib.SerializationUtils.encodeJson(const {'a': 1}),
        contains('"a":1'),
      );
    });

    test('deepCopyJson returns null for null', () {
      expect(mixin_lib.SerializationUtils.deepCopyJson(null), isNull);
    });

    test('deepCopyJson returns independent copy', () {
      final original = <String, dynamic>{
        'a': 1,
        'nested': {'b': 2},
      };
      final copy = mixin_lib.SerializationUtils.deepCopyJson(original);
      expect(copy, original);
      (copy?['nested'] as Map<String, dynamic>)['b'] = 999;
      expect((original['nested'] as Map)['b'], 2);
    });

    test('validateRequiredFields true when all present + non-null', () {
      expect(
        mixin_lib.SerializationUtils.validateRequiredFields(
          const {'a': 1, 'b': 2},
          ['a', 'b'],
        ),
        isTrue,
      );
    });

    test('validateRequiredFields false when missing or null', () {
      expect(
        mixin_lib.SerializationUtils.validateRequiredFields(
          const {'a': 1},
          ['a', 'b'],
        ),
        isFalse,
      );
      expect(
        mixin_lib.SerializationUtils.validateRequiredFields(
          const {'a': null},
          ['a'],
        ),
        isFalse,
      );
    });

    test('cleanJson removes top-level null', () {
      final cleaned = mixin_lib.SerializationUtils.cleanJson(const {
        'a': 1,
        'b': null,
        'c': 'x',
      });
      expect(cleaned.keys.toSet(), {'a', 'c'});
    });

    test('cleanJson recurses into nested maps + filters null list items', () {
      final cleaned = mixin_lib.SerializationUtils.cleanJson(const {
        'nested': {'a': 1, 'b': null},
        'list': [1, null, 3],
        'empty_nested': {'a': null},
      });
      expect((cleaned['nested'] as Map).keys, ['a']);
      expect(cleaned['list'], [1, 3]);
      expect(cleaned.containsKey('empty_nested'), isFalse);
    });
  });

  group('end-to-end: concrete model toJson includes all mixin output', () {
    test('toJson contains id + timestamps + ownership + custom field', () {
      final m = _Model(
        id: 'abc',
        name: 'X',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 2, 1),
        ownerId: 'o',
        createdBy: 'c',
      );
      final json = m.toJson();
      expect(json['id'], 'abc');
      expect(json['name'], 'X');
      expect(json['ownerId'], 'o');
      expect(json['createdBy'], 'c');
      expect(json['createdAt'], startsWith('2026-01-01'));
      expect(json['updatedAt'], startsWith('2026-02-01'));
    });
  });
}
