import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/tagging/tag_decision.dart';
import 'package:butlery/models/tagging/tri_state.dart';

void main() {
  group('TagDecision', () {
    group('construction', () {
      test('creates allergen decision with factory', () {
        final decision = TagDecision.allergen(
          key: 'gluten',
          result: TriState.contains,
          reason: 'Ingredient with property "contains-gluten" found',
          triggeringIngredients: ['vetemjöl', 'pasta'],
        );

        expect(decision.type, 'allergen');
        expect(decision.key, 'gluten');
        expect(decision.result, TriState.contains);
        expect(decision.reason,
            'Ingredient with property "contains-gluten" found');
        expect(decision.triggeringIngredients, ['vetemjöl', 'pasta']);
      });

      test('creates dietary decision with factory', () {
        final decision = TagDecision.dietary(
          key: 'vegetarisk',
          result: TriState.free,
          reason: 'No excluded properties at 100% coverage',
        );

        expect(decision.type, 'dietary');
        expect(decision.key, 'vegetarisk');
        expect(decision.result, TriState.free);
        expect(decision.triggeringIngredients, isNull);
      });

      test('creates decision with null triggering ingredients', () {
        final decision = TagDecision.allergen(
          key: 'mjölk',
          result: TriState.unknown,
          reason: 'Coverage 75% < 100% - cannot confirm',
        );

        expect(decision.triggeringIngredients, isNull);
      });
    });

    group('JSON serialization', () {
      test('toJson includes all fields', () {
        final decision = TagDecision.allergen(
          key: 'ägg',
          result: TriState.contains,
          reason: 'Ingredient with property "egg" found',
          triggeringIngredients: ['ägg'],
        );

        final json = decision.toJson();

        expect(json['type'], 'allergen');
        expect(json['key'], 'ägg');
        expect(json['result'], 'contains');
        expect(json['reason'], 'Ingredient with property "egg" found');
        expect(json['triggeringIngredients'], ['ägg']);
      });

      test('toJson excludes empty triggeringIngredients', () {
        final decision = TagDecision.dietary(
          key: 'vegansk',
          result: TriState.free,
          reason: 'No excluded properties at 100% coverage',
        );

        final json = decision.toJson();

        expect(json.containsKey('triggeringIngredients'), isFalse);
      });

      test('fromJson parses all fields', () {
        final json = {
          'type': 'allergen',
          'key': 'fisk',
          'result': 'CONTAINS',
          'reason': 'Ingredient with property "fish" found',
          'triggeringIngredients': ['lax', 'torsk'],
        };

        final decision = TagDecision.fromJson(json);

        expect(decision.type, 'allergen');
        expect(decision.key, 'fisk');
        expect(decision.result, TriState.contains);
        expect(decision.reason, 'Ingredient with property "fish" found');
        expect(decision.triggeringIngredients, ['lax', 'torsk']);
      });

      test('fromJson handles missing fields gracefully', () {
        final json = <String, dynamic>{};

        final decision = TagDecision.fromJson(json);

        expect(decision.type, 'unknown');
        expect(decision.key, '');
        expect(decision.result, TriState.unknown);
        expect(decision.reason, '');
        expect(decision.triggeringIngredients, isNull);
      });

      test('JSON roundtrip preserves data', () {
        final original = TagDecision.dietary(
          key: 'halalanpassad',
          result: TriState.contains,
          reason: 'Has excluded property (pork)',
          triggeringIngredients: ['fläsk', 'bacon'],
        );

        final json = original.toJson();
        final restored = TagDecision.fromJson(json);

        expect(restored, equals(original));
      });
    });

    group('equality', () {
      test('equal decisions are equal', () {
        final d1 = TagDecision.allergen(
          key: 'gluten',
          result: TriState.free,
          reason:
              'No ingredients with property "contains-gluten" at 100% coverage',
        );
        final d2 = TagDecision.allergen(
          key: 'gluten',
          result: TriState.free,
          reason:
              'No ingredients with property "contains-gluten" at 100% coverage',
        );

        expect(d1, equals(d2));
        expect(d1.hashCode, equals(d2.hashCode));
      });

      test('different keys are not equal', () {
        final d1 = TagDecision.allergen(
          key: 'gluten',
          result: TriState.free,
          reason: 'Test',
        );
        final d2 = TagDecision.allergen(
          key: 'mjölk',
          result: TriState.free,
          reason: 'Test',
        );

        expect(d1, isNot(equals(d2)));
      });

      test('different results are not equal', () {
        final d1 = TagDecision.allergen(
          key: 'gluten',
          result: TriState.free,
          reason: 'Test',
        );
        final d2 = TagDecision.allergen(
          key: 'gluten',
          result: TriState.contains,
          reason: 'Test',
        );

        expect(d1, isNot(equals(d2)));
      });

      test('different triggering ingredients are not equal', () {
        final d1 = TagDecision.allergen(
          key: 'ägg',
          result: TriState.contains,
          reason: 'Test',
          triggeringIngredients: ['ägg'],
        );
        final d2 = TagDecision.allergen(
          key: 'ägg',
          result: TriState.contains,
          reason: 'Test',
          triggeringIngredients: ['ägg', 'äggvita'],
        );

        expect(d1, isNot(equals(d2)));
      });
    });

    group('toString', () {
      test('includes type, key, result and reason', () {
        final decision = TagDecision.allergen(
          key: 'mjölk',
          result: TriState.contains,
          reason: 'Ingredient with property "dairy" found',
        );

        final str = decision.toString();

        expect(str, contains('allergen'));
        expect(str, contains('mjölk'));
        expect(str, contains('contains'));
        expect(str, contains('Ingredient with property "dairy" found'));
      });

      test('includes triggering ingredients when present', () {
        final decision = TagDecision.allergen(
          key: 'mjölk',
          result: TriState.contains,
          reason: 'Test',
          triggeringIngredients: ['ost', 'grädde'],
        );

        final str = decision.toString();

        expect(str, contains('ost'));
        expect(str, contains('grädde'));
      });
    });
  });
}
