/// BUT-202: Model round-trip + serialization tests for the cooking-mode
/// [IngredientSubstitution]. Proves that null context is preserved as null
/// (and omitted from the wire form), and that ratio edge cases round-trip.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/cooking/ingredient_substitution.dart';

void main() {
  group('IngredientSubstitution', () {
    test('round-trips a fully-populated map', () {
      const before = IngredientSubstitution(
        name: 'yoghurt',
        ratio: 0.75,
        context: 'i bakning',
      );
      final after = IngredientSubstitution.fromMap(before.toMap());

      expect(after.name, 'yoghurt');
      expect(after.ratio, 0.75);
      expect(after.context, 'i bakning');
    });

    test('null context round-trips as null and is omitted from toMap', () {
      const before = IngredientSubstitution(
        name: 'crème fraîche',
        ratio: 1.0,
      );

      final map = before.toMap();
      expect(
        map.containsKey('context'),
        isFalse,
        reason: 'context should be omitted when null (safe-map)',
      );

      final after = IngredientSubstitution.fromMap(map);
      expect(after.context, isNull);
      expect(after.name, 'crème fraîche');
      expect(after.ratio, 1.0);
    });

    test('missing ratio falls back to 1.0 rather than 0.0', () {
      // Guard against the "0%" UX regression — a malformed doc should read
      // as a 1:1 badge, which is at least plausible.
      final parsed = IngredientSubstitution.fromMap({'name': 'mjölk'});
      expect(parsed.ratio, 1.0);
    });

    group('ratio edge cases', () {
      test('ratio 0 preserves through round-trip', () {
        const before = IngredientSubstitution(name: 'x', ratio: 0);
        final after = IngredientSubstitution.fromMap(before.toMap());
        expect(after.ratio, 0);
      });

      test('ratio 1 preserves', () {
        const before = IngredientSubstitution(name: 'x', ratio: 1);
        final after = IngredientSubstitution.fromMap(before.toMap());
        expect(after.ratio, 1);
      });

      test('ratio 2 (double-quantity substitute) preserves', () {
        const before = IngredientSubstitution(name: 'x', ratio: 2);
        final after = IngredientSubstitution.fromMap(before.toMap());
        expect(after.ratio, 2);
      });
    });

    test('parses a substitutes-list wire form (Firestore shape)', () {
      // Mirrors the doc schema documented on the model: the `substitutes`
      // field is a List<Map>. This proves nested entries parse correctly
      // without surprising behavior on missing optional fields.
      const doc = {
        'substitutes': [
          {'name': 'yoghurt', 'ratio': 1.0, 'context': 'i bakning'},
          {'name': 'crème fraîche', 'ratio': 0.75},
        ],
      };

      final list = (doc['substitutes']! as List)
          .map(
            (e) => IngredientSubstitution.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();

      expect(list, hasLength(2));
      expect(list[0].context, 'i bakning');
      expect(list[1].context, isNull);
      expect(list[1].ratio, 0.75);
    });
  });
}
