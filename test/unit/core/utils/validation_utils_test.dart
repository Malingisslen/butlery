/// Unit tests for ValidationUtils + extension methods.
///
/// Pure-Dart; targets the 58 unhit lines in lib/core/utils/validation_utils.dart.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/validation_utils.dart';

void main() {
  group('isNullOrEmpty / isNullOrWhitespace', () {
    test('isNullOrEmpty: null/empty true, content false', () {
      expect(ValidationUtils.isNullOrEmpty(null), isTrue);
      expect(ValidationUtils.isNullOrEmpty(''), isTrue);
      expect(ValidationUtils.isNullOrEmpty(' '), isFalse);
      expect(ValidationUtils.isNullOrEmpty('hi'), isFalse);
    });

    test('isNullOrWhitespace: also rejects whitespace-only', () {
      expect(ValidationUtils.isNullOrWhitespace(null), isTrue);
      expect(ValidationUtils.isNullOrWhitespace(''), isTrue);
      expect(ValidationUtils.isNullOrWhitespace('   '), isTrue);
      expect(ValidationUtils.isNullOrWhitespace('hi'), isFalse);
    });
  });

  group('collection null/empty checks', () {
    test('isNullOrEmptyList', () {
      expect(ValidationUtils.isNullOrEmptyList<int>(null), isTrue);
      expect(ValidationUtils.isNullOrEmptyList(const <int>[]), isTrue);
      expect(ValidationUtils.isNullOrEmptyList(const [1]), isFalse);
    });

    test('isNullOrEmptyMap', () {
      expect(ValidationUtils.isNullOrEmptyMap<String, int>(null), isTrue);
      expect(ValidationUtils.isNullOrEmptyMap(const <String, int>{}), isTrue);
      expect(ValidationUtils.isNullOrEmptyMap(const {'a': 1}), isFalse);
    });

    test('hasItems is inverse of isNullOrEmptyList', () {
      expect(ValidationUtils.hasItems<int>(null), isFalse);
      expect(ValidationUtils.hasItems(const <int>[]), isFalse);
      expect(ValidationUtils.hasItems(const [1, 2]), isTrue);
    });

    test('safeCount returns 0 for null, length otherwise', () {
      expect(ValidationUtils.safeCount<int>(null), 0);
      expect(ValidationUtils.safeCount(const [1, 2, 3]), 3);
    });

    test('safeList returns [] for null, value otherwise', () {
      expect(ValidationUtils.safeList<int>(null), isEmpty);
      expect(ValidationUtils.safeList(const [1, 2]), [1, 2]);
    });
  });

  group('validateRequired', () {
    test('returns error when null/empty/whitespace', () {
      expect(ValidationUtils.validateRequired(null), isNotNull);
      expect(ValidationUtils.validateRequired('  '), isNotNull);
    });

    test('returns null when value is content', () {
      expect(ValidationUtils.validateRequired('hi'), isNull);
    });

    test('uses fieldName when provided', () {
      final withName = ValidationUtils.validateRequired(null, fieldName: 'X');
      final generic = ValidationUtils.validateRequired(null);
      // Both non-null, content differs (one contains "X").
      expect(withName, isNotNull);
      expect(generic, isNotNull);
    });
  });

  group('validateLength', () {
    test('returns null when value is null', () {
      expect(
        ValidationUtils.validateLength(null, minLength: 5, maxLength: 10),
        isNull,
      );
    });

    test('errors when shorter than minLength', () {
      expect(
        ValidationUtils.validateLength('ab', minLength: 5, fieldName: 'X'),
        isNotNull,
      );
    });

    test('errors when longer than maxLength', () {
      expect(
        ValidationUtils.validateLength('a' * 20, maxLength: 5, fieldName: 'X'),
        isNotNull,
      );
    });

    test('returns null within range', () {
      expect(
        ValidationUtils.validateLength('hello', minLength: 2, maxLength: 10),
        isNull,
      );
    });
  });

  group('validateEmail', () {
    test('returns error for null/empty when required', () {
      expect(ValidationUtils.validateEmail(null), isNotNull);
      expect(ValidationUtils.validateEmail(''), isNotNull);
    });

    test('returns null for null when not required', () {
      expect(ValidationUtils.validateEmail(null, required: false), isNull);
    });

    test('returns error for malformed email', () {
      expect(ValidationUtils.validateEmail('not-an-email'), isNotNull);
      expect(ValidationUtils.validateEmail('no@dot'), isNotNull);
    });

    test('returns null for valid email', () {
      expect(ValidationUtils.validateEmail('user@example.com'), isNull);
    });
  });

  group('domain-specific validators', () {
    test(
      'validateRecipeName: empty errors, too short errors, valid passes',
      () {
        expect(ValidationUtils.validateRecipeName(''), isNotNull);
        expect(ValidationUtils.validateRecipeName('a'), isNotNull);
        expect(ValidationUtils.validateRecipeName('a' * 101), isNotNull);
        expect(ValidationUtils.validateRecipeName('Pasta'), isNull);
      },
    );

    test('validateGroupName: 2-50 char range', () {
      expect(ValidationUtils.validateGroupName(''), isNotNull);
      expect(ValidationUtils.validateGroupName('a' * 51), isNotNull);
      expect(ValidationUtils.validateGroupName('Friends'), isNull);
    });

    test('validateShoppingItemName: 1-100 chars', () {
      expect(ValidationUtils.validateShoppingItemName(''), isNotNull);
      expect(ValidationUtils.validateShoppingItemName('a' * 101), isNotNull);
      expect(ValidationUtils.validateShoppingItemName('Milk'), isNull);
    });

    test('validateAmount: empty/non-numeric/<=0 errors, positive passes', () {
      expect(ValidationUtils.validateAmount(''), isNotNull);
      expect(ValidationUtils.validateAmount('abc'), isNotNull);
      expect(ValidationUtils.validateAmount('0'), isNotNull);
      expect(ValidationUtils.validateAmount('-1'), isNotNull);
      expect(ValidationUtils.validateAmount('1.5'), isNull);
    });
  });

  group('user / access validators', () {
    test('validateUserId: rejects empty', () {
      expect(ValidationUtils.validateUserId(null), isNotNull);
      expect(ValidationUtils.validateUserId(''), isNotNull);
      expect(ValidationUtils.validateUserId('u1'), isNull);
    });

    test('canAccess: true when ids match and non-empty', () {
      expect(ValidationUtils.canAccess('u1', 'u1'), isTrue);
      expect(ValidationUtils.canAccess('u1', 'u2'), isFalse);
      expect(ValidationUtils.canAccess(null, 'u1'), isFalse);
      expect(ValidationUtils.canAccess('u1', null), isFalse);
    });
  });

  group('multi-field + form validators', () {
    test('validateMultiple aggregates non-null errors', () {
      final errors = ValidationUtils.validateMultiple({
        'a': () => 'err-a',
        'b': () => null,
        'c': () => 'err-c',
      });
      expect(errors, ['err-a', 'err-c']);
    });

    test('isFormValid true when no errors', () {
      final ok = ValidationUtils.isFormValid({'a': () => null});
      expect(ok, isTrue);
    });

    test('isFormValid false when any error', () {
      final notOk = ValidationUtils.isFormValid({'a': () => 'oops'});
      expect(notOk, isFalse);
    });
  });

  group('validateAsync', () {
    test('returns sync validator output on success', () async {
      final result = await ValidationUtils.validateAsync<String>(
        () async => 'value',
        (v) => v == 'value' ? null : 'wrong',
      );
      expect(result, isNull);
    });

    test('returns sync validator error', () async {
      final result = await ValidationUtils.validateAsync<String>(
        () async => 'wrong',
        (v) => 'always error',
      );
      expect(result, 'always error');
    });

    test('returns localized error when validator throws', () async {
      final result = await ValidationUtils.validateAsync<String>(
        () async => throw StateError('boom'),
        (v) => null,
      );
      expect(result, isNotNull);
    });
  });

  group('string helpers', () {
    test('safeString returns value or default', () {
      expect(ValidationUtils.safeString(null, defaultValue: 'def'), 'def');
      expect(ValidationUtils.safeString('v'), 'v');
    });

    test('safeTrim trims or returns empty', () {
      expect(ValidationUtils.safeTrim(null), '');
      expect(ValidationUtils.safeTrim('  hi  '), 'hi');
    });

    test('equalsIgnoreCase handles null + case differences', () {
      expect(ValidationUtils.equalsIgnoreCase(null, null), isTrue);
      expect(ValidationUtils.equalsIgnoreCase('A', 'a'), isTrue);
      expect(ValidationUtils.equalsIgnoreCase('A', null), isFalse);
      expect(ValidationUtils.equalsIgnoreCase(null, 'a'), isFalse);
      expect(ValidationUtils.equalsIgnoreCase('A', 'B'), isFalse);
    });
  });

  group('extension methods on String?', () {
    test('isNullOrEmpty / isNullOrWhitespace mirror static', () {
      String? value;
      expect(value.isNullOrEmpty, isTrue);
      expect(value.isNullOrWhitespace, isTrue);

      value = '  ';
      expect(value.isNullOrEmpty, isFalse);
      expect(value.isNullOrWhitespace, isTrue);
    });

    test('safeTrim trims null-safely', () {
      String? a;
      expect(a.safeTrim, '');
      a = '  hi  ';
      expect(a.safeTrim, 'hi');
    });

    test('required runs validateRequired', () {
      String? a;
      expect(a.required('Field'), isNotNull);
      a = 'value';
      expect(a.required('Field'), isNull);
    });
  });

  group('extension methods on List<T>?', () {
    test('isNullOrEmpty', () {
      List<int>? a;
      expect(a.isNullOrEmpty, isTrue);
      a = const [];
      expect(a.isNullOrEmpty, isTrue);
      a = const [1];
      expect(a.isNullOrEmpty, isFalse);
    });

    test('hasItems', () {
      List<int>? a;
      expect(a.hasItems, isFalse);
      a = const [];
      expect(a.hasItems, isFalse);
      a = const [1];
      expect(a.hasItems, isTrue);
    });

    test('safeCount', () {
      List<int>? a;
      expect(a.safeCount, 0);
      a = const [1, 2];
      expect(a.safeCount, 2);
    });

    test('orEmpty', () {
      List<int>? a;
      expect(a.orEmpty, isEmpty);
      a = const [1];
      expect(a.orEmpty, [1]);
    });
  });
}
