/// BUT-1875: one meal-type vocabulary — synonyms read as the app's spelling,
/// free text is left alone.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/recipe/meal_types.dart';
import 'package:butlery/models/recipe/recipe_serialization.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/extractors/schema_org_recipe_extractor.dart';

void main() {
  group('MealTypes.match', () {
    test('English, lower-case and spaced synonyms read as the app spells '
        'them', () {
      expect(MealTypes.match('dinner'), 'Middag');
      expect(MealTypes.match(' Middag '), 'Middag');
      expect(MealTypes.match('MAIN   COURSE'), 'Middag');
      expect(MealTypes.match('breakfast'), 'Frukost');
      expect(MealTypes.match('Efterrätt'), 'Dessert');
      expect(MealTypes.match('mellanmal'), 'Mellanmål');
      expect(MealTypes.match('snacks'), 'Mellanmål');
      expect(MealTypes.match('fika'), 'Fika');
    });

    test('every offered value matches itself', () {
      for (final value in MealTypes.all) {
        expect(MealTypes.match(value), value);
      }
    });

    test('free text is not a meal type', () {
      expect(MealTypes.match('Soppor'), isNull);
      expect(MealTypes.match(''), isNull);
      expect(MealTypes.normalize('Soppor'), 'Soppor');
    });
  });

  group('stored recipes are read in the one vocabulary', () {
    Map<String, dynamic> core(String mealType) => {
      'title': 'Gryta',
      'ingredients': <String>[],
      'instructions': <String>[],
      'mealType': mealType,
    };

    test('a Firestore document', () {
      expect(RecipeCore.fromMap('r1', core('dinner')).mealType, 'Middag');
      expect(RecipeCore.fromMap('r1', core('Soppor')).mealType, 'Soppor');
    });

    test('a JSON copy', () {
      expect(RecipeCore.fromJson(core('lunch')).mealType, 'Lunch');
    });

    test('a simple import and the compressed device copy', () {
      expect(
        RecipeSerialization.fromSimpleImport(core('dessert')).mealType,
        'Dessert',
      );
      final compressed = RecipeSerialization.toCompressed(
        RecipeSerialization.fromSimpleImport(core('Soppor')),
      )..['m'] = 'snack';
      expect(
        RecipeSerialization.fromCompressed(compressed).mealType,
        'Mellanmål',
      );
    });
  });

  group('a schema.org category', () {
    String mealTypeOf(Object? category) => SchemaOrgRecipeExtractor
        .createRecipe({
          'name': 'Gryta',
          'recipeCategory': ?category,
        }, 'https://example.com/gryta')
        .mealType;

    test('that names a meal type is stored in the app\'s spelling', () {
      expect(mealTypeOf('Main course'), 'Middag');
      expect(mealTypeOf(['Efterrätter']), 'Dessert');
    });

    test('that does not is not stored as one', () {
      expect(mealTypeOf('Kycklingrätter'), 'Middag');
      expect(mealTypeOf(null), 'Middag');
    });
  });
}
