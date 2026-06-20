import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe/recipe_serialization.dart';

/// Guards the deserialization path against a corrupt or future `type` index.
/// Before the fix, `RecipeType.values[index]` threw a RangeError that would
/// crash recipe loading; now it clamps to a safe default.
void main() {
  Recipe buildRecipe(RecipeType type) => Recipe(
        core: RecipeCore(
          title: 'Köttbullar',
          description: 'Klassiska',
          ingredients: const ['köttfärs'],
          instructions: const ['Stek'],
          mealType: 'Middag',
        ),
        type: type,
      );

  group('RecipeSerialization type-index safety', () {
    test('round-trips a valid type unchanged', () {
      final json = RecipeSerialization.toJson(buildRecipe(RecipeType.shared));
      expect(RecipeSerialization.fromJson(json).type, RecipeType.shared);
    });

    test('fromJson clamps an out-of-range type index to personal (no throw)',
        () {
      final json = RecipeSerialization.toJson(buildRecipe(RecipeType.shared));
      json['type'] = 99; // e.g. a value written by a newer client
      expect(RecipeSerialization.fromJson(json).type, RecipeType.personal);
    });

    test('fromMap clamps a non-int type to personal (no throw)', () {
      final json = RecipeSerialization.toJson(buildRecipe(RecipeType.shared));
      json['type'] = 'corrupt';
      expect(
        RecipeSerialization.fromMap('r1', json).type,
        RecipeType.personal,
      );
    });
  });
}
