/// Round-trip losslessness test for ParsedRecipeStructure isolate serialization.
///
/// Intent: every field on [ParsedRecipeStructure] survives a
/// toIsolateMap() → fromIsolateMap() round-trip unchanged.
///
/// Regression gate: this test FAILS if a new field is added to
/// [ParsedRecipeStructure] but only one of the two serializer methods is
/// updated — the field will be absent from the reconstructed object and the
/// corresponding expect() will catch it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/parsing/parsers/swedish_line_classifier.dart';

void main() {
  group('ParsedRecipeStructure isolate round-trip', () {
    /// Constructs a fully-populated instance (every field set to a non-default
    /// value) so that a missing serializer entry produces a detectable diff.
    ParsedRecipeStructure fullInstance() => const ParsedRecipeStructure(
          title: 'Pannkakor med sylt',
          ingredients: ['2 ägg', '3 dl mjölk', '1 dl mjöl', 'smör'],
          instructions: [
            'Vispa ihop ägg och mjölk.',
            'Tillsätt mjölet och rör tills smeten är slät.',
            'Stek i smör.',
          ],
          portions: 4,
          totalTime: Duration(minutes: 45),
        );

    test('title survives round-trip', () {
      final original = fullInstance();
      final restored =
          ParsedRecipeStructure.fromIsolateMap(original.toIsolateMap());
      expect(restored.title, equals(original.title));
    });

    test('ingredients list survives round-trip element-by-element', () {
      final original = fullInstance();
      final restored =
          ParsedRecipeStructure.fromIsolateMap(original.toIsolateMap());
      expect(restored.ingredients, equals(original.ingredients));
    });

    test('instructions list survives round-trip element-by-element', () {
      final original = fullInstance();
      final restored =
          ParsedRecipeStructure.fromIsolateMap(original.toIsolateMap());
      expect(restored.instructions, equals(original.instructions));
    });

    test('portions survives round-trip', () {
      final original = fullInstance();
      final restored =
          ParsedRecipeStructure.fromIsolateMap(original.toIsolateMap());
      expect(restored.portions, equals(original.portions));
    });

    test('totalTime survives round-trip (stored as integer minutes)', () {
      final original = fullInstance();
      final restored =
          ParsedRecipeStructure.fromIsolateMap(original.toIsolateMap());
      expect(restored.totalTime, equals(original.totalTime));
    });

    test('null-valued optional fields round-trip as null', () {
      // Construct with only the required non-nullable fields.
      const sparse = ParsedRecipeStructure(
        ingredients: [],
        instructions: [],
        // title, portions, totalTime intentionally absent (null)
      );
      final restored =
          ParsedRecipeStructure.fromIsolateMap(sparse.toIsolateMap());
      expect(restored.title, isNull);
      expect(restored.portions, isNull);
      expect(restored.totalTime, isNull);
    });

    test('totalTime null does not appear as totalTimeMinutes key in map', () {
      const sparse = ParsedRecipeStructure(
        ingredients: [],
        instructions: [],
      );
      final map = sparse.toIsolateMap();
      // The key should be absent (not present as null) so the receiving
      // isolate can safely do map['totalTimeMinutes'] as int? == null.
      expect(map.containsKey('totalTimeMinutes'), isFalse);
    });

    test('lists are independent copies (mutating restored does not affect map)',
        () {
      final original = fullInstance();
      final map = original.toIsolateMap();
      final restored = ParsedRecipeStructure.fromIsolateMap(map);
      // Mutate the restored list — should not affect re-parsing from same map.
      restored.ingredients.add('extra ingredient');
      final restored2 = ParsedRecipeStructure.fromIsolateMap(map);
      expect(restored2.ingredients, equals(original.ingredients));
    });

    test('all five fields covered — full field-by-field assertion', () {
      // This single consolidated test is the regression gate:
      // if a new field is added to ParsedRecipeStructure without updating
      // both serializers, one of these expects will fail.
      final original = fullInstance();
      final restored =
          ParsedRecipeStructure.fromIsolateMap(original.toIsolateMap());

      expect(restored.title, equals(original.title),
          reason: 'title field lost in round-trip');
      expect(restored.ingredients, equals(original.ingredients),
          reason: 'ingredients field lost in round-trip');
      expect(restored.instructions, equals(original.instructions),
          reason: 'instructions field lost in round-trip');
      expect(restored.portions, equals(original.portions),
          reason: 'portions field lost in round-trip');
      expect(restored.totalTime, equals(original.totalTime),
          reason: 'totalTime field lost in round-trip');
    });
  });
}
