/// BUT-1216: structured ingredient foundation.
///
/// Intent: a Recipe can carry amount/unit/name per ingredient (round-trips
/// through serialization), legacy free-text-only docs stay fully functional,
/// and stale structured data (free-text edited after import) is never served
/// — each test pins one of those contracts.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe_unified.dart';

void main() {
  group('RecipeIngredient.fromParsed', () {
    test('maps quantity/unit/name and folds size+preparation into note', () {
      final parsed = ParsedIngredient.structured(
        name: 'lök',
        originalLine: '2 stora lökar, hackade',
        quantity: '2',
        unit: 'st',
        size: 'stora',
        preparation: 'hackade',
      );
      final ing = RecipeIngredient.fromParsed(parsed);
      expect(ing.amount, 2);
      expect(ing.unit, 'st');
      expect(ing.name, 'lök');
      expect(ing.note, 'stora, hackade');
      expect(ing.raw, '2 stora lökar, hackade');
    });

    test('parses Swedish decimal comma ("1,5" → 1.5)', () {
      final ing = RecipeIngredient.fromParsed(
        ParsedIngredient.structured(
          name: 'mjölk',
          originalLine: '1,5 dl mjölk',
          quantity: '1,5',
          unit: 'dl',
        ),
      );
      expect(ing.amount, 1.5);
    });

    test('unparseable quantity (range) yields null amount but keeps raw', () {
      final ing = RecipeIngredient.fromParsed(
        ParsedIngredient.structured(
          name: 'vitlöksklyftor',
          originalLine: '1-2 vitlöksklyftor',
          quantity: '1-2',
        ),
      );
      expect(ing.amount, isNull);
      expect(ing.raw, '1-2 vitlöksklyftor');
      expect(ing.isStructured, isFalse);
    });
  });

  group('serialization', () {
    test('toJson + fromJson round-trip preserves every field', () {
      const original = RecipeIngredient(
        amount: 2.5,
        unit: 'dl',
        name: 'vetemjöl',
        note: 'siktat',
        raw: '2,5 dl vetemjöl, siktat',
      );
      final restored = RecipeIngredient.fromJson(original.toJson());
      expect(restored, original);
    });

    test('rawOnly entry round-trips (null amount/unit/note omitted)', () {
      final original = RecipeIngredient.rawOnly('en nypa salt');
      final json = original.toJson();
      expect(json.containsKey('amount'), isFalse);
      expect(RecipeIngredient.fromJson(json), original);
    });

    test('listFromJson drops garbage entries instead of throwing', () {
      final result = RecipeIngredient.listFromJson([
        {'name': 'salt', 'raw': 'salt'},
        'not-a-map',
        42,
      ]);
      expect(result, hasLength(1));
      expect(result!.single.name, 'salt');
      expect(RecipeIngredient.listFromJson('not-a-list'), isNull);
      expect(RecipeIngredient.listFromJson(null), isNull);
    });
  });

  group('RecipeCore integration', () {
    RecipeCore coreWith({List<RecipeIngredient>? structured}) => RecipeCore(
      id: 'r1',
      title: 'Pannkakor',
      description: '',
      ingredients: ['2,5 dl vetemjöl', '3 ägg'],
      structuredIngredients: structured,
      instructions: ['Vispa', 'Stek'],
      mealType: 'Middag',
    );

    final structured = [
      const RecipeIngredient(
        amount: 2.5,
        unit: 'dl',
        name: 'vetemjöl',
        raw: '2,5 dl vetemjöl',
      ),
      const RecipeIngredient(amount: 3, name: 'ägg', raw: '3 ägg'),
    ];

    test('structured ingredients round-trip through toJson/fromJson', () {
      final restored = RecipeCore.fromJson(
        coreWith(structured: structured).toJson(),
      );
      expect(restored.structuredIngredients, structured);
    });

    test(
      'structured ingredients round-trip through fromMap (Firestore path)',
      () {
        final data = coreWith(structured: structured).toJson()
          ..remove('createdAt')
          ..remove('updatedAt');
        final restored = RecipeCore.fromMap('r1', data);
        expect(restored.structuredIngredients, structured);
      },
    );

    test('legacy doc without the field deserializes to null (no throw)', () {
      final data = coreWith().toJson();
      expect(data.containsKey('structuredIngredients'), isFalse);
      final restored = RecipeCore.fromJson(data);
      expect(restored.structuredIngredients, isNull);
    });

    test('dataChecksum is byte-identical with and without structured data', () {
      // The checksum guards the user-visible content (raw strings); the
      // derived structured form must not invalidate existing checksums.
      final without = coreWith()..updateChecksum();
      final with_ = coreWith(structured: structured)..updateChecksum();
      expect(with_.dataChecksum, without.dataChecksum);
    });
  });

  group('Recipe.structuredIngredients (alignment-validated getter)', () {
    Recipe recipeWith({
      required List<String> ingredients,
      List<RecipeIngredient>? structured,
    }) => Recipe(
      core: RecipeCore(
        id: 'r1',
        title: 'T',
        description: '',
        ingredients: ingredients,
        structuredIngredients: structured,
        instructions: const ['x'],
        mealType: 'Middag',
      ),
      type: RecipeType.personal,
    );

    test('returns stored data when aligned with the ingredient strings', () {
      final structured = [
        const RecipeIngredient(
          amount: 2,
          unit: 'dl',
          name: 'mjöl',
          raw: '2 dl mjöl',
        ),
      ];
      final recipe = recipeWith(
        ingredients: ['2 dl mjöl'],
        structured: structured,
      );
      expect(recipe.structuredIngredients, same(structured));
    });

    test('falls back to raw-only when free-text was edited after import', () {
      final recipe = recipeWith(
        ingredients: ['4 dl mjöl'], // edited — no longer matches raw below
        structured: [
          const RecipeIngredient(
            amount: 2,
            unit: 'dl',
            name: 'mjöl',
            raw: '2 dl mjöl',
          ),
        ],
      );
      final effective = recipe.structuredIngredients;
      expect(effective.single.raw, '4 dl mjöl');
      expect(
        effective.single.amount,
        isNull,
        reason: 'stale amount (2) must never be served for the edited line',
      );
    });

    test('legacy recipe (no structured data) yields raw-only entries', () {
      final recipe = recipeWith(ingredients: ['salt', 'peppar']);
      final effective = recipe.structuredIngredients;
      expect(effective, hasLength(2));
      expect(effective.map((i) => i.raw), ['salt', 'peppar']);
      expect(effective.every((i) => !i.isStructured), isTrue);
    });
  });

  group('ParsedRecipe → import wire-through shape', () {
    test('fromParsed list is index-aligned with the originalLine strings', () {
      // Mirrors url_import_strategy._convertParsedRecipeToImportResult:
      // ingredients[i] = parsed[i].originalLine AND structured[i].raw must
      // match — otherwise the alignment getter would discard the data.
      final parsedList = [
        ParsedIngredient.structured(
          name: 'mjöl',
          originalLine: '2 dl mjöl',
          quantity: '2',
          unit: 'dl',
        ),
        ParsedIngredient.simple('en nypa salt'),
      ];
      final strings = parsedList.map((p) => p.originalLine).toList();
      final structured = parsedList.map(RecipeIngredient.fromParsed).toList();
      for (var i = 0; i < strings.length; i++) {
        expect(structured[i].raw, strings[i]);
      }
      expect(structured[0].amount, 2);
      expect(structured[1].isStructured, isFalse);
    });
  });
}
