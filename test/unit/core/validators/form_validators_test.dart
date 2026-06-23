/// Unit tests for FormValidators.
///
/// Pure-Dart, no Flutter test infrastructure. Targets the 153 unhit lines
/// in lib/core/validators/form_validators.dart by walking each validator
/// across its happy + error paths.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/validators/form_validators.dart';

void main() {
  group('required', () {
    final v = FormValidators.required('Titel');

    test('null and empty return error', () {
      expect(v(null), isNotNull);
      expect(v(''), isNotNull);
      expect(v('   '), isNotNull);
    });

    test('non-empty returns null', () {
      expect(v('hej'), isNull);
    });
  });

  group('minLength', () {
    final v = FormValidators.minLength(3, 'Titel');

    test('shorter than min returns error', () {
      expect(v('ab'), isNotNull);
    });

    test('equal or longer returns null', () {
      expect(v('abc'), isNull);
      expect(v('abcd'), isNull);
    });

    test('null passes through (combine with required for non-null check)', () {
      expect(v(null), isNull);
    });
  });

  group('maxLength', () {
    final v = FormValidators.maxLength(5, 'Titel');

    test('longer than max returns error', () {
      expect(v('toolong'), isNotNull);
    });

    test('equal or shorter returns null', () {
      expect(v('hello'), isNull);
      expect(v('hi'), isNull);
    });
  });

  group('numberRange', () {
    test('non-numeric returns error', () {
      final v = FormValidators.numberRange(min: 0, max: 10);
      expect(v('abc'), isNotNull);
    });

    test('below min returns error', () {
      final v = FormValidators.numberRange(min: 5);
      expect(v('3'), isNotNull);
    });

    test('above max returns error', () {
      final v = FormValidators.numberRange(max: 5);
      expect(v('7'), isNotNull);
    });

    test('in range returns null', () {
      final v = FormValidators.numberRange(min: 0, max: 10);
      expect(v('5'), isNull);
    });

    test('empty/null passes through', () {
      final v = FormValidators.numberRange(min: 0, max: 10);
      expect(v(null), isNull);
      expect(v(''), isNull);
    });

    test('accepts comma-decimal separator (Swedish)', () {
      final v = FormValidators.numberRange(min: 0, max: 10);
      expect(v('3,5'), isNull);
    });
  });

  group('url', () {
    final v = FormValidators.url();

    test('valid http/https URL returns null', () {
      expect(v('https://example.com'), isNull);
      expect(v('http://example.com/path'), isNull);
    });

    test('missing scheme returns error', () {
      expect(v('example.com'), isNotNull);
    });

    test('non-http scheme returns error', () {
      expect(v('ftp://example.com'), isNotNull);
    });

    test('host without dot returns error', () {
      expect(v('http://localhost'), isNotNull);
    });

    test('empty/null passes through', () {
      expect(v(null), isNull);
      expect(v(''), isNull);
    });
  });

  group('rating / portions / cookingTime — preset ranges', () {
    test('rating accepts 0-5', () {
      expect(FormValidators.rating()('3'), isNull);
      expect(FormValidators.rating()('-1'), isNotNull);
      expect(FormValidators.rating()('6'), isNotNull);
    });

    test('portions accepts 1-100', () {
      expect(FormValidators.portions()('4'), isNull);
      expect(FormValidators.portions()('0'), isNotNull);
      expect(FormValidators.portions()('101'), isNotNull);
    });

    test('cookingTime accepts 1-1440 minutes', () {
      expect(FormValidators.cookingTime()('30'), isNull);
      expect(FormValidators.cookingTime()('0'), isNotNull);
      expect(FormValidators.cookingTime()('1441'), isNotNull);
    });
  });

  group('displayName', () {
    final v = FormValidators.displayName();

    test('valid name returns null', () {
      expect(v('Anna'), isNull);
      expect(v('Anna Andersson'), isNull);
      expect(v('Anna-Maria'), isNull);
    });

    test('empty returns error', () {
      expect(v(''), isNotNull);
    });

    test('too short returns error', () {
      expect(v('A'), isNotNull);
    });

    test('too long returns error', () {
      expect(v('A' * 31), isNotNull);
    });

    test('invalid characters return error', () {
      expect(v('Anna@Andersson'), isNotNull);
    });

    test('only separators with no letters returns error', () {
      expect(v('---'), isNotNull);
    });

    test('leading/trailing whitespace returns error', () {
      expect(v(' Anna'), isNotNull);
      expect(v('Anna '), isNotNull);
    });
  });

  group('comment', () {
    final v = FormValidators.comment();

    test('empty returns error', () {
      expect(v(''), isNotNull);
    });

    test('too short returns error', () {
      expect(v('ab'), isNotNull);
    });

    test('too long returns error', () {
      expect(v('a' * 501), isNotNull);
    });

    test('valid returns null', () {
      expect(v('A good comment'), isNull);
    });
  });

  group('shareMessage', () {
    final v = FormValidators.shareMessage();

    test('empty/null passes (optional)', () {
      expect(v(null), isNull);
      expect(v(''), isNull);
    });

    test('too long returns error', () {
      expect(v('a' * 201), isNotNull);
    });

    test('within limit returns null', () {
      expect(v('Hello'), isNull);
    });
  });

  group('combine', () {
    test('returns first error from validator chain', () {
      final v = FormValidators.combine([
        FormValidators.required('Titel'),
        FormValidators.minLength(3, 'Titel'),
      ]);
      expect(v(null), isNotNull); // required fails first
      expect(v('ab'), isNotNull); // minLength fails
      expect(v('abc'), isNull); // both pass
    });

    test('empty list returns null', () {
      expect(FormValidators.combine([])('anything'), isNull);
    });
  });

  group('auth validators', () {
    test('authName: empty + too short return error, valid returns null', () {
      final v = FormValidators.authName();
      expect(v(null), isNotNull);
      expect(v(''), isNotNull);
      expect(v('A'), isNotNull);
      expect(v('Anna'), isNull);
    });

    test(
      'authEmail: empty + missing @ or . return error, valid returns null',
      () {
        final v = FormValidators.authEmail();
        expect(v(null), isNotNull);
        expect(v(''), isNotNull);
        expect(v('no-at-sign.com'), isNotNull);
        expect(v('no-dot@com'), isNotNull);
        expect(v('a@b.c'), isNull);
      },
    );

    test('authPassword: required + min-length only when isSignUp', () {
      expect(FormValidators.authPassword()(null), isNotNull);
      expect(FormValidators.authPassword()(''), isNotNull);
      // Without isSignUp, any non-empty password passes.
      expect(FormValidators.authPassword()('short'), isNull);
      // With isSignUp, min length is enforced.
      expect(FormValidators.authPassword(isSignUp: true)('short'), isNotNull);
      expect(FormValidators.authPassword(isSignUp: true)('longenough'), isNull);
    });
  });

  group('shopping item validators', () {
    test('shoppingItemName empty returns error', () {
      final v = FormValidators.shoppingItemName();
      expect(v(null), isNotNull);
      expect(v('   '), isNotNull);
      expect(v('Mjölk'), isNull);
    });

    test('shoppingItemAmount accepts positive numbers', () {
      final v = FormValidators.shoppingItemAmount();
      expect(v(null), isNotNull);
      expect(v(''), isNotNull);
      expect(v('abc'), isNotNull);
      expect(v('0'), isNotNull);
      expect(v('-1'), isNotNull);
      expect(v('1.5'), isNull);
      expect(v('2,5'), isNull);
    });
  });

  group('recipeTags', () {
    final v = FormValidators.recipeTags();

    test('empty/null passes', () {
      expect(v(null), isNull);
      expect(v(''), isNull);
    });

    test('valid CSV tags pass', () {
      expect(v('veg, snabb, middag'), isNull);
    });

    test('too short tag returns error', () {
      expect(v('a, snabb'), isNotNull);
    });

    test('too long tag returns error', () {
      expect(v('${'a' * 21}, snabb'), isNotNull);
    });

    test('empty entries are skipped', () {
      expect(v('veg, , snabb'), isNull);
    });
  });

  group('nonEmptyText', () {
    final v = FormValidators.nonEmptyText('Field');

    test('empty/null returns error', () {
      expect(v(null), isNotNull);
      expect(v(''), isNotNull);
      expect(v('   '), isNotNull);
    });

    test('non-empty returns null', () {
      expect(v('hej'), isNull);
    });
  });

  group('strongPassword', () {
    final v = FormValidators.strongPassword();

    test('empty returns error', () {
      expect(v(null), isNotNull);
      expect(v(''), isNotNull);
    });

    test('below min returns error', () {
      expect(v('short'), isNotNull);
    });

    test('at or above min returns null', () {
      expect(v('longenough'), isNull);
    });
  });

  group('conditional', () {
    test('runs validator only when condition is true', () {
      final required = FormValidators.required('X');
      expect(
        FormValidators.conditional(condition: false, validator: required)(null),
        isNull,
      );
      expect(
        FormValidators.conditional(condition: true, validator: required)(null),
        isNotNull,
      );
    });
  });

  group('recipeSourceUrl', () {
    final v = FormValidators.recipeSourceUrl();

    test('empty/null passes (optional)', () {
      expect(v(null), isNull);
      expect(v(''), isNull);
    });

    test('Butlery system URLs pass without URL validation', () {
      expect(v('Delad från Anna'), isNull);
      expect(v('Importerad från web'), isNull);
      expect(v('Custom Butlery share'), isNull);
    });

    test('other URLs go through normal URL validation', () {
      expect(v('https://example.com'), isNull);
      expect(v('notaurl'), isNotNull);
    });
  });

  group('optional', () {
    final inner = FormValidators.minLength(3, 'X');
    final v = FormValidators.optional(inner);

    test('empty/null skips inner validator', () {
      expect(v(null), isNull);
      expect(v(''), isNull);
    });

    test('non-empty runs inner validator', () {
      expect(v('ab'), isNotNull);
      expect(v('abcd'), isNull);
    });
  });

  group('requiredDisplayName + requiredComment composites', () {
    test('requiredDisplayName chains required + displayName rules', () {
      final v = FormValidators.requiredDisplayName();
      expect(v(null), isNotNull);
      expect(v('A'), isNotNull); // too short
      expect(v('Anna'), isNull);
    });

    test('requiredComment chains required + comment rules', () {
      final v = FormValidators.requiredComment();
      expect(v(null), isNotNull);
      expect(v('ab'), isNotNull); // too short
      expect(v('Valid comment text'), isNull);
    });
  });

  group('contentFilter', () {
    test('returns null when ContentFilterService not registered', () {
      // No ServiceLocator setup in this test → tryGet returns null →
      // validator becomes a no-op.
      final v = FormValidators.contentFilter('Field');
      expect(v(null), isNull);
      expect(v('anything goes'), isNull);
    });
  });
}
