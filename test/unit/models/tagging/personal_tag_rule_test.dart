import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';

import '../../../infrastructure/builders/personal_tag_builder.dart';
import '../../../infrastructure/builders/recipe_builder.dart';

void main() {
  group('RuleCondition', () {
    group('creation', () {
      test('creates condition with required fields', () {
        const condition = RuleCondition(
          type: ConditionType.ingredient,
          operator: ConditionOperator.contains,
          value: 'kyckling',
        );

        expect(condition.type, ConditionType.ingredient);
        expect(condition.operator, ConditionOperator.contains);
        expect(condition.value, 'kyckling');
      });
    });

    group('ingredient evaluation', () {
      test('evaluates contains operator', () {
        const condition = RuleCondition(
          type: ConditionType.ingredient,
          operator: ConditionOperator.contains,
          value: 'kyckling',
        );

        // Recipe with matching ingredient
        final matchingRecipe = RecipeBuilder()
            .withIngredients(['500g kyckling', 'salt', 'peppar'])
            .build();

        expect(condition.evaluate(matchingRecipe, null), isTrue);

        // Recipe without matching ingredient
        final nonMatchingRecipe = RecipeBuilder()
            .withIngredients(['500g fläskfilé', 'salt'])
            .build();

        expect(condition.evaluate(nonMatchingRecipe, null), isFalse);
      });

      test('evaluates notContains operator', () {
        const condition = RuleCondition(
          type: ConditionType.ingredient,
          operator: ConditionOperator.notContains,
          value: 'fisk',
        );

        // Recipe without fish - returns true (at least one ingredient doesn't contain 'fisk')
        final meatRecipe = RecipeBuilder()
            .withIngredients(['kyckling', 'potatis'])
            .build();

        expect(condition.evaluate(meatRecipe, null), isTrue);

        // Recipe with ONLY fish - all ingredients contain 'fisk'
        final onlyFishRecipe = RecipeBuilder()
            .withIngredients(['500g fisk'])
            .build();

        expect(condition.evaluate(onlyFishRecipe, null), isFalse);
      });
    });

    group('keyword evaluation', () {
      test('evaluates contains in title', () {
        const condition = RuleCondition(
          type: ConditionType.keyword,
          operator: ConditionOperator.contains,
          value: 'pasta',
        );

        final pastaRecipe = RecipeBuilder()
            .withTitle('Krämig pasta carbonara')
            .build();

        expect(condition.evaluate(pastaRecipe, null), isTrue);

        final soupRecipe = RecipeBuilder()
            .withTitle('Tomatsoppa')
            .build();

        expect(condition.evaluate(soupRecipe, null), isFalse);
      });

      test('evaluates contains in description', () {
        const condition = RuleCondition(
          type: ConditionType.keyword,
          operator: ConditionOperator.contains,
          value: 'vegetarisk',
        );

        final veggieRecipe = RecipeBuilder()
            .withTitle('Böngryta')
            .withDescription('En god vegetarisk gryta')
            .build();

        expect(condition.evaluate(veggieRecipe, null), isTrue);
      });

      test('is case insensitive', () {
        const condition = RuleCondition(
          type: ConditionType.keyword,
          operator: ConditionOperator.contains,
          value: 'PASTA',
        );

        final recipe = RecipeBuilder()
            .withTitle('Krämig pasta carbonara')
            .build();

        expect(condition.evaluate(recipe, null), isTrue);
      });
    });

    group('sourceUrl evaluation', () {
      test('evaluates contains operator', () {
        const condition = RuleCondition(
          type: ConditionType.sourceUrl,
          operator: ConditionOperator.contains,
          value: 'recept.se',
        );

        final matchingRecipe = RecipeBuilder()
            .withSourceUrl('https://www.recept.se/pasta-carbonara')
            .build();

        expect(condition.evaluate(matchingRecipe, null), isTrue);

        final nonMatchingRecipe = RecipeBuilder()
            .withSourceUrl('https://tasteline.com/recept')
            .build();

        expect(condition.evaluate(nonMatchingRecipe, null), isFalse);
      });

      test('handles missing sourceUrl gracefully', () {
        const condition = RuleCondition(
          type: ConditionType.sourceUrl,
          operator: ConditionOperator.contains,
          value: 'recept.se',
        );

        final recipeNoSource = RecipeBuilder().build();

        expect(condition.evaluate(recipeNoSource, null), isFalse);
      });
    });

    group('property evaluation', () {
      test('returns false when lookup is null', () {
        const condition = RuleCondition(
          type: ConditionType.property,
          operator: ConditionOperator.contains,
          value: 'seafood',
        );

        final recipe = RecipeBuilder().build();

        // Property conditions require lookup data
        expect(condition.evaluate(recipe, null), isFalse);
      });

      test('returns false with empty lookup', () {
        const condition = RuleCondition(
          type: ConditionType.property,
          operator: ConditionOperator.contains,
          value: 'seafood',
        );

        final recipe = RecipeBuilder().build();

        expect(
          condition.evaluate(recipe, IngredientLookupResult.empty()),
          isFalse,
        );
      });
    });
  });

  group('PersonalTagRule', () {
    group('validation', () {
      test('validates empty name', () {
        final rule = PersonalTagRuleBuilder()
            .withName('')
            .withIngredientCondition('kyckling')
            .build();

        expect(PersonalTagRule.validate(rule), isNotNull);
      });

      test('validates empty conditions', () {
        final rule = PersonalTagRuleBuilder()
            .withName('Test Rule')
            .withConditions([])
            .build();

        expect(PersonalTagRule.validate(rule), isNotNull);
      });

      test('validates valid rule', () {
        final rule = PersonalTagRuleBuilder()
            .withName('Fish Rule')
            .withPropertyCondition('seafood')
            .build();

        expect(PersonalTagRule.validate(rule), isNull);
      });
    });

    group('evaluation', () {
      test('disabled rule returns false', () {
        final rule = PersonalTagRuleBuilder()
            .withIngredientCondition('kyckling')
            .asDisabled()
            .build();

        final recipe = RecipeBuilder()
            .withIngredients(['kyckling'])
            .build();

        expect(rule.evaluate(recipe, null), isFalse);
      });

      test('empty conditions returns false', () {
        final rule = PersonalTagRuleBuilder()
            .withConditions([])
            .build();

        final recipe = RecipeBuilder().build();

        expect(rule.evaluate(recipe, null), isFalse);
      });
    });

    group('match modes', () {
      test('MatchMode.all requires all conditions to match', () {
        final rule = PersonalTagRuleBuilder()
            .withName('Swedish fish')
            .withMatchMode(MatchMode.all)
            .withIngredientCondition('lax')
            .withKeywordCondition('svensk')
            .build();

        // Both conditions match
        final matchingRecipe = RecipeBuilder()
            .withTitle('Svensk laxgryta')
            .withIngredients(['lax', 'grädde'])
            .build();

        expect(rule.evaluate(matchingRecipe, null), isTrue);

        // Only one condition matches (has lax but not svensk in title)
        final partialRecipe = RecipeBuilder()
            .withTitle('Laxsoppa')
            .withIngredients(['lax'])
            .build();

        expect(rule.evaluate(partialRecipe, null), isFalse);
      });

      test('MatchMode.any requires only one condition to match', () {
        final rule = PersonalTagRuleBuilder()
            .withName('Any fish')
            .withMatchMode(MatchMode.any)
            .withIngredientCondition('lax')
            .withIngredientCondition('torsk')
            .build();

        // First condition matches
        final salmonRecipe = RecipeBuilder()
            .withIngredients(['400g lax'])
            .build();

        expect(rule.evaluate(salmonRecipe, null), isTrue);

        // Second condition matches
        final codRecipe = RecipeBuilder()
            .withIngredients(['färsk torsk'])
            .build();

        expect(rule.evaluate(codRecipe, null), isTrue);

        // No conditions match
        final chickenRecipe = RecipeBuilder()
            .withIngredients(['kyckling'])
            .build();

        expect(rule.evaluate(chickenRecipe, null), isFalse);
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final original = PersonalTagRuleBuilder()
            .withName('Original')
            .build();

        final updated = original.copyWith(
          name: 'Updated',
          isEnabled: false,
        );

        expect(updated.name, 'Updated');
        expect(updated.isEnabled, isFalse);
        expect(updated.id, original.id);
        expect(updated.tagId, original.tagId);
      });
    });

    group('requiresLookup', () {
      test('returns true when has property condition', () {
        final rule = PersonalTagRuleBuilder()
            .withPropertyCondition('seafood')
            .build();

        expect(rule.requiresLookup, isTrue);
      });

      test('returns false when no property conditions', () {
        final rule = PersonalTagRuleBuilder()
            .withIngredientCondition('kyckling')
            .build();

        expect(rule.requiresLookup, isFalse);
      });
    });
  });
}
