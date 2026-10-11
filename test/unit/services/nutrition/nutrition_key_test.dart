import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/nutrition/nutrition_key.dart';

// The shape firestore.rules accepts for a household choice key.
final _ruleShape = RegExp(r'^[a-zåäö0-9_]{1,60}$');

void main() {
  group('NutritionKey.storageKey golden cases', () {
    // Household choices are stored under these strings, so changing any of
    // them orphans choices users already saved.
    const golden = <String, String?>{
      'Crème fraiche': 'creme_fraiche',
      'creme  fraiche,': 'creme_fraiche',
      'Kycklingfilé': 'kycklingfile',
      'Gul lök': 'gul_lök',
      '1,5% mjölk': '1_5_mjölk',
      'Smör (osaltat)': 'smör_osaltat',
      'sour-cream': 'sour_cream',
      '  Äpple  ': 'äpple',
    };
    golden.forEach((input, expected) {
      test('"$input" is stored as $expected', () {
        expect(NutritionKey.storageKey(input), expected);
      });
    });

    test(
      'a decomposed å (a + U+030A) gets the same key as a precomposed å',
      () {
        const decomposed = 'ålg';
        const precomposed = 'ålg';
        expect(NutritionKey.storageKey(decomposed), 'ålg');
        expect(
          NutritionKey.storageKey(decomposed),
          NutritionKey.storageKey(precomposed),
        );
        expect(
          NutritionKey.lookupKey('Kycklingfilé'),
          NutritionKey.lookupKey('Kycklingfilé'),
        );
      },
    );

    test('a name with nothing usable left has no storage key', () {
      for (final input in ['', '   ', '!!!', '...,,,', '---', '%%', '😀']) {
        expect(NutritionKey.storageKey(input), isNull, reason: '"$input"');
      }
    });

    test('a 70-character name is cut to 60 characters', () {
      final key = NutritionKey.storageKey('a' * 70);
      expect(key, 'a' * 60);
    });

    test(
      'a cut that lands on a separator does not leave a trailing underscore',
      () {
        // 59 letters, a space, then more: the 60th character is the separator.
        final key = NutritionKey.storageKey('${'a' * 59} ${'b' * 10}');
        expect(key, 'a' * 59);
        expect(_ruleShape.hasMatch(key!), isTrue);
      },
    );

    test('whatever the input, the key is null or accepted by the rules', () {
      final inputs = <String>[
        'Crème fraiche',
        '1,5% mjölk',
        'å̈ weird',
        'ÅÄÖ åäö',
        'x' * 200,
        '${'ö' * 30} ${'ä' * 30} ${'å' * 30}',
        'rött vin - 12 %',
        'tomat/paprika; (färsk)',
        'ß ñ ç ü ø æ',
        '\t\n multi\nline ',
        '100%',
        '_leading_and_trailing_',
        '日本語',
        '${'a' * 59}-bbbbb',
        '${'a' * 58}%-bbbbb',
      ];
      for (final input in inputs) {
        final key = NutritionKey.storageKey(input);
        if (key != null) {
          expect(
            _ruleShape.hasMatch(key),
            isTrue,
            reason: 'storageKey("$input") = "$key"',
          );
        }
      }
    });
  });

  group('NutritionKey.lookupKey', () {
    test('"Crème fraiche," and "creme  fraiche" give the same key', () {
      expect(
        NutritionKey.lookupKey('Crème fraiche,'),
        NutritionKey.lookupKey('creme  fraiche'),
      );
      expect(NutritionKey.lookupKey('Crème fraiche,'), 'creme fraiche');
    });

    test('å, ä and ö survive, other accents are folded', () {
      expect(NutritionKey.lookupKey('Smörgås Äpple'), 'smörgås äpple');
      expect(NutritionKey.lookupKey('Kycklingfilé'), 'kycklingfile');
      expect(NutritionKey.lookupKey('Crème'), 'creme');
      expect(NutritionKey.lookupKey('Ñandú'), 'nandu');
    });

    test('percent and hyphen stay readable, other punctuation is a space', () {
      expect(NutritionKey.lookupKey('1,5% mjölk'), '1 5% mjölk');
      expect(NutritionKey.lookupKey('sour-cream'), 'sour-cream');
      expect(NutritionKey.lookupKey('smör (osaltat)'), 'smör osaltat');
    });
  });
}
