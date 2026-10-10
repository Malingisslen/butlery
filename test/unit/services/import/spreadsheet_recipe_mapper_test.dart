import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/spreadsheet_recipe_mapper.dart';

/// A row as the strategy builds it: headers pass through normalizeHeader.
Recipe? _map(Map<String, String> row) => SpreadsheetRecipeMapper.fromRow({
  for (final e in row.entries)
    SpreadsheetRecipeMapper.normalizeHeader(e.key): e.value,
});

void main() {
  group('SpreadsheetRecipeMapper header matching', () {
    test(
      'proves Swedish column names land in the right fields when a Swedish '
      'Excel sheet is imported',
      () {
        final recipe = _map({
          'Titel': 'Köttbullar',
          'Ingredienser': '5 dl mjölk;1 ägg',
          'Gör så här': 'Rulla bullar. Stek.',
          'Portioner': '6',
          'Tid': '45 min',
          'Kategori': 'Middag',
          'Taggar': 'Barnvänligt',
        })!;

        expect(recipe.title, 'Köttbullar');
        expect(recipe.ingredients, ['5 dl mjölk', '1 ägg']);
        expect(recipe.instructions, ['Rulla bullar. Stek.']);
        expect(recipe.portions, 6);
        expect(recipe.timeMinutes, 45);
        expect(recipe.personalTagIds, ['Barnvänligt']);
      },
    );

    test('proves header spelling noise still finds the column', () {
      expect(
        SpreadsheetRecipeMapper.normalizeHeader('  Gör_så  här '),
        'gör så här',
      );
      expect(
        SpreadsheetRecipeMapper.normalizeHeader('recipe_name'),
        'recipe name',
      );
      expect(SpreadsheetRecipeMapper.normalizeHeader(null), '');
    });

    test('proves a row without any title column is skipped, not named', () {
      expect(_map({'Ingredienser': '1 ägg', 'Gör så här': 'Stek'}), isNull);
      expect(_map({'Titel': '   ', 'Ingredienser': '1 ägg'}), isNull);
    });

    test('proves nothing is invented for cells the file left empty', () {
      final recipe = _map({'Titel': 'Bara en titel'})!;

      expect(recipe.title, 'Bara en titel');
      expect(recipe.description, '');
      expect(recipe.ingredients, isEmpty);
      expect(recipe.instructions, isEmpty);
      expect(recipe.sourceUrl, isNull);
      expect(recipe.personalTagIds, isEmpty);
    });

    test('proves a decimal comma in Betyg is read as a number', () {
      expect(_map({'Titel': 'X', 'Betyg': '4,5'})!.rating, 4.5);
    });
  });

  group('SpreadsheetRecipeMapper steps', () {
    List<String> steps(String cell) =>
        _map({'Titel': 'X', 'Gör så här': cell})!.instructions;

    test(
      'proves a temperature followed by a full stop is not read as numbering',
      () {
        expect(steps('Sätt ugnen på 175. Blanda mjöl.'), [
          'Sätt ugnen på 175. Blanda mjöl.',
        ]);
      },
    );

    test('proves inline 1. 2. 3. numbering splits into steps without the '
        'numbers and keeps "175." inside its step', () {
      final result = steps('1. Sätt ugnen på 175. 2. Blanda. 3. Grädda');

      expect(result, ['Sätt ugnen på 175.', 'Blanda.', 'Grädda']);
    });

    test('proves numbering on separate lines is stripped per line', () {
      expect(steps('1. A\n2. B'), ['A', 'B']);
    });
  });

  group('SpreadsheetRecipeMapper Kategori and Taggar', () {
    test('proves a Kategori naming a meal type sets mealType and no tag', () {
      final recipe = _map({'Titel': 'X', 'Kategori': 'Efterrätt'})!;

      expect(recipe.mealType, 'Dessert');
      expect(recipe.personalTagIds, isEmpty);
    });

    test('proves a Kategori in English or without å is read through the '
        'app\'s one meal-type vocabulary (BUT-1875)', () {
      expect(
        _map({'Titel': 'X', 'Kategori': 'Breakfast'})!.mealType,
        'Frukost',
      );
      expect(
        _map({'Titel': 'X', 'Kategori': 'mellanmal'})!.mealType,
        'Mellanmål',
      );
    });

    test('proves any other Kategori is the user\'s own tag, mealType stays '
        'the default', () {
      final recipe = _map({'Titel': 'X', 'Kategori': 'Mormors'})!;

      expect(recipe.mealType, 'Middag');
      expect(recipe.personalTagIds, ['Mormors']);
    });

    test('proves Taggar are split on commas into one name each', () {
      final recipe = _map({'Titel': 'X', 'Taggar': 'Snabbt, Vegetariskt'})!;

      expect(recipe.personalTagIds, ['Snabbt', 'Vegetariskt']);
    });
  });
}
