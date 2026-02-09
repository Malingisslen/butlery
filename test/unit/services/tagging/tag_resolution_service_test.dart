import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_overrides.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/tag_editing_service.dart';
import 'package:butlery/services/tagging/tag_resolution_service.dart';

void main() {
  late TagResolutionService service;

  setUp(() {
    service = TagResolutionService(
      tagEditingService: TagEditingService(),
    );
  });

  Recipe makeRecipe({
    Set<String>? autoTags,
    Map<String, TriState>? allergenStatus,
    Map<String, TriState>? dietaryStatus,
    TagOverrides? overrides,
    List<String>? personalTagIds,
    double coverage = 1.0,
  }) {
    final recipe = Recipe.personal(
      title: 'Test',
      description: 'Test',
      ingredients: ['test'],
      instructions: ['test'],
      mealType: 'Middag',
      createdBy: 'user1',
    );

    return recipe.copyWith(
      tagResult: autoTags != null
          ? TagResult(
              tags: autoTags,
              allergenStatus: allergenStatus ?? {},
              dietaryStatus: dietaryStatus ?? {},
              coverage: coverage,
              unknownIngredients: [],
              generatedAt: DateTime.now(),
            )
          : null,
      tagOverrides: overrides,
      personalTagIds: personalTagIds,
    );
  }

  group('TagResolutionService', () {
    test('resolve returns empty data for recipe with no tags', () {
      final recipe = makeRecipe();
      final result = service.resolve(recipe);

      expect(result.autoTags, isEmpty);
      expect(result.personalTags, isEmpty);
      expect(result.effectiveAutoTags, isEmpty);
      expect(result.allTags, isEmpty);
      expect(result.hasAutoTags, false);
      expect(result.hasPersonalTags, false);
    });

    test('resolve includes auto-tags', () {
      final recipe = makeRecipe(
        autoTags: {'kyckling', 'pasta'},
      );
      final result = service.resolve(recipe);

      expect(result.autoTags, {'kyckling', 'pasta'});
      expect(result.effectiveAutoTags, {'kyckling', 'pasta'});
      expect(result.hasAutoTags, true);
    });

    test('resolve applies overrides to auto-tags', () {
      final recipe = makeRecipe(
        autoTags: {'kyckling', 'pasta'},
        overrides: TagOverrides(
          addedTags: {'gryta'},
          removedTags: {'pasta'},
        ),
      );
      final result = service.resolve(recipe);

      expect(result.autoTags, {'kyckling', 'pasta'});
      expect(result.effectiveAutoTags, {'kyckling', 'gryta'});
      expect(result.hasManualEdits, true);
    });

    test('resolve includes personal tags separately', () {
      final recipe = makeRecipe(
        autoTags: {'kyckling'},
        personalTagIds: ['middag', 'favoriter'],
      );
      final result = service.resolve(recipe);

      expect(result.autoTags, {'kyckling'});
      expect(result.personalTags, {'middag', 'favoriter'});
      expect(result.allTags, {'kyckling', 'middag', 'favoriter'});
    });

    test('resolve includes allergen and dietary status', () {
      final recipe = makeRecipe(
        autoTags: {'kyckling'},
        allergenStatus: {
          'gluten': TriState.free,
          'laktos': TriState.contains,
        },
        dietaryStatus: {
          'vegetarian': TriState.contains,
        },
      );
      final result = service.resolve(recipe);

      expect(result.effectiveAllergenStatus['gluten'], TriState.free);
      expect(result.effectiveAllergenStatus['laktos'], TriState.contains);
      expect(result.effectiveDietaryStatus['vegetarian'], TriState.contains);
    });

    test('resolve applies allergen overrides', () {
      final recipe = makeRecipe(
        autoTags: {'kyckling'},
        allergenStatus: {
          'laktos': TriState.contains,
        },
        overrides: TagOverrides(
          allergenOverrides: {'laktos': TriState.free},
        ),
      );
      final result = service.resolve(recipe);

      expect(result.effectiveAllergenStatus['laktos'], TriState.free);
      expect(result.hasManualEdits, true);
    });

    test('hasTags returns false for empty recipe', () {
      final recipe = makeRecipe();
      expect(service.hasTags(recipe), false);
    });

    test('hasTags returns true for recipe with auto-tags', () {
      final recipe = makeRecipe(autoTags: {'kyckling'});
      expect(service.hasTags(recipe), true);
    });

    test('hasTags returns true for recipe with personal tags only', () {
      final recipe = makeRecipe(personalTagIds: ['middag']);
      expect(service.hasTags(recipe), true);
    });

    test('hasTags respects overrides removing all auto-tags', () {
      final recipe = makeRecipe(
        autoTags: {'kyckling'},
        overrides: TagOverrides(removedTags: {'kyckling'}),
      );
      // All auto-tags removed, no personal tags
      expect(service.hasTags(recipe), false);
    });
  });
}
