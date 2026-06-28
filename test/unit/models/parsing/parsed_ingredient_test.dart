/// Direct unit tests for [ParsedIngredient] (BUT-1149 coverage burndown —
/// previously zero direct coverage).
///
/// Pure model for a parsed ingredient line: the two factory constructors, the
/// has-quantity/unit/structured predicates, the display-string assembly, JSON
/// round-trip (with the safe-enum confidence fallback), copyWith, and the
/// identity-by-(name, originalLine, confidence) equality.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';

void main() {
  group('factories', () {
    test('simple trims the name and uses medium confidence', () {
      final i = ParsedIngredient.simple('  salt  ');
      expect(i.name, 'salt');
      expect(i.originalLine, '  salt  ');
      expect(i.confidence, ParseConfidence.medium);
    });

    test('structured sets the fields with high confidence', () {
      final i = ParsedIngredient.structured(
        name: 'mjölk',
        originalLine: '2 dl mjölk',
        quantity: '2',
        unit: 'dl',
      );
      expect(i.confidence, ParseConfidence.high);
      expect(i.quantity, '2');
      expect(i.unit, 'dl');
    });
  });

  group('predicates', () {
    test('hasQuantity / hasUnit are false for null or empty', () {
      final none = ParsedIngredient.simple('salt');
      expect(none.hasQuantity, isFalse);
      expect(none.hasUnit, isFalse);
      expect(none.isStructured, isFalse);

      final empties = none.copyWith(quantity: '', unit: '');
      expect(empties.hasQuantity, isFalse);
      expect(empties.hasUnit, isFalse);
    });

    test('isStructured is true when quantity or unit is present', () {
      expect(
        ParsedIngredient.simple('salt').copyWith(quantity: '2').isStructured,
        isTrue,
      );
      expect(
        ParsedIngredient.simple('salt').copyWith(unit: 'dl').isStructured,
        isTrue,
      );
    });
  });

  group('displayString', () {
    test('assembles quantity, unit, size, name and parenthesised prep', () {
      final i = ParsedIngredient.structured(
        name: 'lök',
        originalLine: '1 stor lök, hackad',
        quantity: '1',
        unit: '',
        size: 'stor',
        preparation: 'hackad',
      );
      expect(i.displayString, '1 stor lök (hackad)');
    });

    test('is just the name when nothing else is set', () {
      expect(ParsedIngredient.simple('salt').displayString, 'salt');
    });
  });

  group('JSON', () {
    test('toJson omits null optional fields but always carries the core', () {
      final json = ParsedIngredient.simple('salt').toJson();
      expect(json['name'], 'salt');
      expect(json['confidence'], 'medium');
      expect(json.containsKey('quantity'), isFalse);
    });

    test('round-trips through fromJson', () {
      final original = ParsedIngredient.structured(
        name: 'mjölk',
        originalLine: '2 dl mjölk',
        quantity: '2',
        unit: 'dl',
      );
      final restored = ParsedIngredient.fromJson(original.toJson());
      expect(restored.name, 'mjölk');
      expect(restored.quantity, '2');
      expect(restored.unit, 'dl');
      expect(restored.confidence, ParseConfidence.high);
    });

    test(
      'fromJson defaults: empty name, originalLine←name, medium confidence',
      () {
        final i = ParsedIngredient.fromJson({'confidence': 'bogus'});
        expect(i.name, '');
        expect(i.originalLine, '');
        expect(i.confidence, ParseConfidence.medium); // safe-enum fallback
      },
    );
  });

  group('copyWith + equality', () {
    test('copyWith changes one field and keeps the rest', () {
      final i = ParsedIngredient.simple('salt');
      final j = i.copyWith(name: 'socker');
      expect(j.name, 'socker');
      expect(j.confidence, i.confidence);
    });

    test('equality is by name + originalLine + confidence only', () {
      final a = ParsedIngredient.simple('salt');
      // Same identity fields, different quantity → still equal.
      final b = a.copyWith(quantity: '2');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      // Different name → not equal.
      expect(a == a.copyWith(name: 'socker'), isFalse);
    });
  });
}
