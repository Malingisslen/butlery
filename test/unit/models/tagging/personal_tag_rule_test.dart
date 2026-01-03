import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';

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
            .withIngredients(['500g kyckling', 'salt', 'peppar']).build();

        expect(condition.evaluate(matchingRecipe, null), isTrue);

        // Recipe without matching ingredient
        final nonMatchingRecipe =
            RecipeBuilder().withIngredients(['500g fläskfilé', 'salt']).build();

        expect(condition.evaluate(nonMatchingRecipe, null), isFalse);
      });

      test('evaluates notContains operator', () {
        const condition = RuleCondition(
          type: ConditionType.ingredient,
          operator: ConditionOperator.notContains,
          value: 'fisk',
        );

        // Recipe without fish - returns true (at least one ingredient doesn't contain 'fisk')
        final meatRecipe =
            RecipeBuilder().withIngredients(['kyckling', 'potatis']).build();

        expect(condition.evaluate(meatRecipe, null), isTrue);

        // Recipe with ONLY fish - all ingredients contain 'fisk'
        final onlyFishRecipe =
            RecipeBuilder().withIngredients(['500g fisk']).build();

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

        final pastaRecipe =
            RecipeBuilder().withTitle('Krämig pasta carbonara').build();

        expect(condition.evaluate(pastaRecipe, null), isTrue);

        final soupRecipe = RecipeBuilder().withTitle('Tomatsoppa').build();

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

        final recipe =
            RecipeBuilder().withTitle('Krämig pasta carbonara').build();

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

    group('cuisine evaluation', () {
      test('evaluates equals operator', () {
        const condition = RuleCondition(
          type: ConditionType.cuisine,
          operator: ConditionOperator.equals,
          value: 'italian',
        );

        final matchingRecipe = RecipeBuilder()
            .withTagResult(TagResult(
              tags: {'italian', 'pasta'},
              allergenStatus: {},
              dietaryStatus: {},
              coverage: 1.0,
              generatedAt: DateTime.now(),
            ))
            .build();

        expect(condition.evaluate(matchingRecipe, null), isTrue);

        final nonMatchingRecipe = RecipeBuilder()
            .withTagResult(TagResult(
              tags: {'swedish', 'meatballs'},
              allergenStatus: {},
              dietaryStatus: {},
              coverage: 1.0,
              generatedAt: DateTime.now(),
            ))
            .build();

        expect(condition.evaluate(nonMatchingRecipe, null), isFalse);
      });

      test('evaluates contains operator', () {
        const condition = RuleCondition(
          type: ConditionType.cuisine,
          operator: ConditionOperator.contains,
          value: 'asian',
        );

        final matchingRecipe = RecipeBuilder()
            .withTagResult(TagResult(
              tags: {'asian-fusion', 'noodles'},
              allergenStatus: {},
              dietaryStatus: {},
              coverage: 1.0,
              generatedAt: DateTime.now(),
            ))
            .build();

        expect(condition.evaluate(matchingRecipe, null), isTrue);
      });

      test('returns false when no tagResult', () {
        const condition = RuleCondition(
          type: ConditionType.cuisine,
          operator: ConditionOperator.equals,
          value: 'italian',
        );

        final recipe = RecipeBuilder().build();

        expect(condition.evaluate(recipe, null), isFalse);
      });

      test('is case insensitive', () {
        const condition = RuleCondition(
          type: ConditionType.cuisine,
          operator: ConditionOperator.equals,
          value: 'ITALIAN',
        );

        final recipe = RecipeBuilder()
            .withTagResult(TagResult(
              tags: {'italian'},
              allergenStatus: {},
              dietaryStatus: {},
              coverage: 1.0,
              generatedAt: DateTime.now(),
            ))
            .build();

        expect(condition.evaluate(recipe, null), isTrue);
      });
    });

    group('dietary evaluation', () {
      test('evaluates vegetarian status', () {
        const condition = RuleCondition(
          type: ConditionType.dietary,
          operator: ConditionOperator.equals,
          value: 'vegetarian',
        );

        final vegRecipe = RecipeBuilder()
            .withTagResult(TagResult(
              tags: {},
              allergenStatus: {},
              dietaryStatus: {'vegetarian': TriState.free},
              coverage: 1.0,
              generatedAt: DateTime.now(),
            ))
            .build();

        expect(condition.evaluate(vegRecipe, null), isTrue);

        final meatRecipe = RecipeBuilder()
            .withTagResult(TagResult(
              tags: {},
              allergenStatus: {},
              dietaryStatus: {'vegetarian': TriState.contains},
              coverage: 1.0,
              generatedAt: DateTime.now(),
            ))
            .build();

        expect(condition.evaluate(meatRecipe, null), isFalse);
      });

      test('evaluates vegan status', () {
        const condition = RuleCondition(
          type: ConditionType.dietary,
          operator: ConditionOperator.equals,
          value: 'vegan',
        );

        final veganRecipe = RecipeBuilder()
            .withTagResult(TagResult(
              tags: {},
              allergenStatus: {},
              dietaryStatus: {'vegan': TriState.free},
              coverage: 1.0,
              generatedAt: DateTime.now(),
            ))
            .build();

        expect(condition.evaluate(veganRecipe, null), isTrue);
      });

      test('returns false when dietary key not present', () {
        const condition = RuleCondition(
          type: ConditionType.dietary,
          operator: ConditionOperator.equals,
          value: 'pescetarian',
        );

        final recipe = RecipeBuilder()
            .withTagResult(TagResult(
              tags: {},
              allergenStatus: {},
              dietaryStatus: {'vegetarian': TriState.free},
              coverage: 1.0,
              generatedAt: DateTime.now(),
            ))
            .build();

        expect(condition.evaluate(recipe, null), isFalse);
      });

      test('returns false when no tagResult', () {
        const condition = RuleCondition(
          type: ConditionType.dietary,
          operator: ConditionOperator.equals,
          value: 'vegetarian',
        );

        final recipe = RecipeBuilder().build();

        expect(condition.evaluate(recipe, null), isFalse);
      });
    });

    group('time evaluation', () {
      test('evaluates lessThan operator', () {
        const condition = RuleCondition(
          type: ConditionType.time,
          operator: ConditionOperator.lessThan,
          value: 30,
        );

        final quickRecipe = RecipeBuilder().withTimeMinutes(20).build();
        expect(condition.evaluate(quickRecipe, null), isTrue);

        final slowRecipe = RecipeBuilder().withTimeMinutes(45).build();
        expect(condition.evaluate(slowRecipe, null), isFalse);

        final exactRecipe = RecipeBuilder().withTimeMinutes(30).build();
        expect(condition.evaluate(exactRecipe, null), isFalse);
      });

      test('evaluates lessThanOrEqual operator', () {
        const condition = RuleCondition(
          type: ConditionType.time,
          operator: ConditionOperator.lessThanOrEqual,
          value: 30,
        );

        final quickRecipe = RecipeBuilder().withTimeMinutes(20).build();
        expect(condition.evaluate(quickRecipe, null), isTrue);

        final exactRecipe = RecipeBuilder().withTimeMinutes(30).build();
        expect(condition.evaluate(exactRecipe, null), isTrue);

        final slowRecipe = RecipeBuilder().withTimeMinutes(31).build();
        expect(condition.evaluate(slowRecipe, null), isFalse);
      });

      test('evaluates greaterThan operator', () {
        const condition = RuleCondition(
          type: ConditionType.time,
          operator: ConditionOperator.greaterThan,
          value: 60,
        );

        final longRecipe = RecipeBuilder().withTimeMinutes(90).build();
        expect(condition.evaluate(longRecipe, null), isTrue);

        final shortRecipe = RecipeBuilder().withTimeMinutes(45).build();
        expect(condition.evaluate(shortRecipe, null), isFalse);
      });

      test('evaluates greaterThanOrEqual operator', () {
        const condition = RuleCondition(
          type: ConditionType.time,
          operator: ConditionOperator.greaterThanOrEqual,
          value: 60,
        );

        final exactRecipe = RecipeBuilder().withTimeMinutes(60).build();
        expect(condition.evaluate(exactRecipe, null), isTrue);

        final longRecipe = RecipeBuilder().withTimeMinutes(90).build();
        expect(condition.evaluate(longRecipe, null), isTrue);

        final shortRecipe = RecipeBuilder().withTimeMinutes(59).build();
        expect(condition.evaluate(shortRecipe, null), isFalse);
      });

      test('handles null timeMinutes', () {
        const condition = RuleCondition(
          type: ConditionType.time,
          operator: ConditionOperator.lessThan,
          value: 30,
        );

        final recipe = RecipeBuilder().withTimeMinutes(null).build();

        // Null time is treated as 0
        expect(condition.evaluate(recipe, null), isTrue);
      });
    });

    group('rating evaluation', () {
      test('evaluates greaterThanOrEqual operator', () {
        const condition = RuleCondition(
          type: ConditionType.rating,
          operator: ConditionOperator.greaterThanOrEqual,
          value: 4,
        );

        final highRatedRecipe = RecipeBuilder().withRating(4.5).build();
        expect(condition.evaluate(highRatedRecipe, null), isTrue);

        final exactRatedRecipe = RecipeBuilder().withRating(4.0).build();
        expect(condition.evaluate(exactRatedRecipe, null), isTrue);

        final lowRatedRecipe = RecipeBuilder().withRating(3.5).build();
        expect(condition.evaluate(lowRatedRecipe, null), isFalse);
      });

      test('evaluates equals operator', () {
        const condition = RuleCondition(
          type: ConditionType.rating,
          operator: ConditionOperator.equals,
          value: 5,
        );

        final fiveStarRecipe = RecipeBuilder().withRating(5.0).build();
        expect(condition.evaluate(fiveStarRecipe, null), isTrue);

        final fourStarRecipe = RecipeBuilder().withRating(4.0).build();
        expect(condition.evaluate(fourStarRecipe, null), isFalse);
      });

      test('handles null rating', () {
        const condition = RuleCondition(
          type: ConditionType.rating,
          operator: ConditionOperator.greaterThan,
          value: 0,
        );

        final recipe = RecipeBuilder().withRating(null).build();

        // Null rating is treated as 0
        expect(condition.evaluate(recipe, null), isFalse);
      });
    });

    group('recency evaluation', () {
      test('evaluates withinDays operator', () {
        const condition = RuleCondition(
          type: ConditionType.recency,
          operator: ConditionOperator.withinDays,
          value: 7,
        );

        // Recipe created yesterday
        final recentRecipe = RecipeBuilder()
            .withCreatedAt(DateTime.now().subtract(const Duration(days: 1)))
            .build();
        expect(condition.evaluate(recentRecipe, null), isTrue);

        // Recipe created today
        final todayRecipe =
            RecipeBuilder().withCreatedAt(DateTime.now()).build();
        expect(condition.evaluate(todayRecipe, null), isTrue);

        // Recipe created 10 days ago
        final oldRecipe = RecipeBuilder()
            .withCreatedAt(DateTime.now().subtract(const Duration(days: 10)))
            .build();
        expect(condition.evaluate(oldRecipe, null), isFalse);
      });

      test('evaluates lessThan operator for days since created', () {
        const condition = RuleCondition(
          type: ConditionType.recency,
          operator: ConditionOperator.lessThan,
          value: 30,
        );

        final recentRecipe = RecipeBuilder()
            .withCreatedAt(DateTime.now().subtract(const Duration(days: 10)))
            .build();
        expect(condition.evaluate(recentRecipe, null), isTrue);

        final oldRecipe = RecipeBuilder()
            .withCreatedAt(DateTime.now().subtract(const Duration(days: 60)))
            .build();
        expect(condition.evaluate(oldRecipe, null), isFalse);
      });
    });

    group('numeric operators', () {
      test('all numeric operators work correctly', () {
        final recipe = RecipeBuilder().withTimeMinutes(50).build();

        // lessThan
        expect(
          const RuleCondition(
            type: ConditionType.time,
            operator: ConditionOperator.lessThan,
            value: 60,
          ).evaluate(recipe, null),
          isTrue,
        );

        // lessThanOrEqual
        expect(
          const RuleCondition(
            type: ConditionType.time,
            operator: ConditionOperator.lessThanOrEqual,
            value: 50,
          ).evaluate(recipe, null),
          isTrue,
        );

        // greaterThan
        expect(
          const RuleCondition(
            type: ConditionType.time,
            operator: ConditionOperator.greaterThan,
            value: 40,
          ).evaluate(recipe, null),
          isTrue,
        );

        // greaterThanOrEqual
        expect(
          const RuleCondition(
            type: ConditionType.time,
            operator: ConditionOperator.greaterThanOrEqual,
            value: 50,
          ).evaluate(recipe, null),
          isTrue,
        );
      });

      test('isNumeric returns true for numeric types', () {
        expect(ConditionType.time.isNumeric, isTrue);
        expect(ConditionType.rating.isNumeric, isTrue);
        expect(ConditionType.recency.isNumeric, isTrue);
      });

      test('isNumeric returns false for text types', () {
        expect(ConditionType.ingredient.isNumeric, isFalse);
        expect(ConditionType.keyword.isNumeric, isFalse);
        expect(ConditionType.sourceUrl.isNumeric, isFalse);
        expect(ConditionType.cuisine.isNumeric, isFalse);
        expect(ConditionType.dietary.isNumeric, isFalse);
      });

      test('operator isNumeric returns correct values', () {
        expect(ConditionOperator.lessThan.isNumeric, isTrue);
        expect(ConditionOperator.lessThanOrEqual.isNumeric, isTrue);
        expect(ConditionOperator.greaterThan.isNumeric, isTrue);
        expect(ConditionOperator.greaterThanOrEqual.isNumeric, isTrue);
        expect(ConditionOperator.withinDays.isNumeric, isTrue);

        expect(ConditionOperator.contains.isNumeric, isFalse);
        expect(ConditionOperator.equals.isNumeric, isFalse);
        expect(ConditionOperator.notContains.isNumeric, isFalse);
      });
    });

    group('condition serialization', () {
      test('numeric condition preserves numeric value', () {
        const original = RuleCondition(
          type: ConditionType.time,
          operator: ConditionOperator.lessThan,
          value: 30,
        );

        final map = original.toMap();
        final restored = RuleCondition.fromMap(map);

        expect(restored.type, ConditionType.time);
        expect(restored.operator, ConditionOperator.lessThan);
        expect(restored.numericValue, 30);
      });

      test('text condition preserves string value', () {
        const original = RuleCondition(
          type: ConditionType.ingredient,
          operator: ConditionOperator.contains,
          value: 'kyckling',
        );

        final map = original.toMap();
        final restored = RuleCondition.fromMap(map);

        expect(restored.type, ConditionType.ingredient);
        expect(restored.stringValue, 'kyckling');
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
            .withConditions([]).build();

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

        final recipe = RecipeBuilder().withIngredients(['kyckling']).build();

        expect(rule.evaluate(recipe, null), isFalse);
      });

      test('empty conditions returns false', () {
        final rule = PersonalTagRuleBuilder().withConditions([]).build();

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
            .withIngredients(['lax', 'grädde']).build();

        expect(rule.evaluate(matchingRecipe, null), isTrue);

        // Only one condition matches (has lax but not svensk in title)
        final partialRecipe = RecipeBuilder()
            .withTitle('Laxsoppa')
            .withIngredients(['lax']).build();

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
        final salmonRecipe =
            RecipeBuilder().withIngredients(['400g lax']).build();

        expect(rule.evaluate(salmonRecipe, null), isTrue);

        // Second condition matches
        final codRecipe =
            RecipeBuilder().withIngredients(['färsk torsk']).build();

        expect(rule.evaluate(codRecipe, null), isTrue);

        // No conditions match
        final chickenRecipe =
            RecipeBuilder().withIngredients(['kyckling']).build();

        expect(rule.evaluate(chickenRecipe, null), isFalse);
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final original = PersonalTagRuleBuilder().withName('Original').build();

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
        final rule =
            PersonalTagRuleBuilder().withPropertyCondition('seafood').build();

        expect(rule.requiresLookup, isTrue);
      });

      test('returns false when no property conditions', () {
        final rule = PersonalTagRuleBuilder()
            .withIngredientCondition('kyckling')
            .build();

        expect(rule.requiresLookup, isFalse);
      });
    });

    group('embedded serialization', () {
      test('toEmbeddedMap excludes tagId', () {
        final rule = PersonalTagRuleBuilder()
            .withTagId('tag-123')
            .withName('Test Rule')
            .withIngredientCondition('kyckling')
            .build();

        final map = rule.toEmbeddedMap();

        expect(map.containsKey('tagId'), isFalse);
        expect(map['id'], rule.id);
        expect(map['name'], 'Test Rule');
        expect(map['conditions'], isA<List>());
        expect(map['matchMode'], 'ALL');
        expect(map['isEnabled'], isTrue);
        expect(map['createdAt'], isA<Timestamp>());
        expect(map['updatedAt'], isA<Timestamp>());
      });

      test('fromEmbeddedMap creates rule without tagId', () {
        final now = Timestamp.now();
        final rule = PersonalTagRule.fromEmbeddedMap({
          'id': 'rule-abc',
          'name': 'Embedded Rule',
          'conditions': const [
            {
              'type': 'ingredient',
              'operator': 'contains',
              'value': 'lax',
              'caseSensitive': false,
            }
          ],
          'matchMode': 'ANY',
          'isEnabled': true,
          'createdAt': now,
          'updatedAt': now,
        });

        expect(rule.id, 'rule-abc');
        expect(rule.tagId, isEmpty);
        expect(rule.name, 'Embedded Rule');
        expect(rule.conditions, hasLength(1));
        expect(rule.matchMode, MatchMode.any);
        expect(rule.isEnabled, isTrue);
      });

      test('fromEmbeddedMap generates ID if missing', () {
        final rule = PersonalTagRule.fromEmbeddedMap({
          'name': 'No ID Rule',
          'conditions': const [],
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        });

        expect(rule.id, isNotEmpty);
      });

      test('roundtrip toEmbeddedMap/fromEmbeddedMap preserves data', () {
        final original = PersonalTagRuleBuilder()
            .withId('rule-123')
            .withName('Fish Rule')
            .withPropertyCondition('seafood')
            .withMatchMode(MatchMode.any)
            .asDisabled()
            .build();

        final map = original.toEmbeddedMap();
        final restored = PersonalTagRule.fromEmbeddedMap(map);

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.matchMode, original.matchMode);
        expect(restored.isEnabled, original.isEnabled);
        expect(restored.conditions.length, original.conditions.length);
      });
    });

    group('embedded validation', () {
      test('validateEmbedded does not require tagId', () {
        final rule = PersonalTagRuleBuilder()
            .withTagId('')
            .withName('Valid Rule')
            .withIngredientCondition('test')
            .build();

        expect(PersonalTagRule.validateEmbedded(rule), isNull);
      });

      test('validateEmbedded requires name', () {
        final rule = PersonalTagRuleBuilder()
            .withName('')
            .withIngredientCondition('test')
            .build();

        expect(PersonalTagRule.validateEmbedded(rule), isNotNull);
      });

      test('validateEmbedded requires at least one condition', () {
        final rule = PersonalTagRuleBuilder()
            .withName('No Conditions')
            .withConditions([]).build();

        expect(PersonalTagRule.validateEmbedded(rule), isNotNull);
      });

      test('isValidEmbedded returns true for valid embedded rule', () {
        final rule = PersonalTagRuleBuilder()
            .withTagId('') // Empty tagId is OK for embedded
            .withName('Valid')
            .withKeywordCondition('pasta')
            .build();

        expect(rule.isValidEmbedded, isTrue);
      });

      test('isValid requires tagId while isValidEmbedded does not', () {
        final rule = PersonalTagRuleBuilder()
            .withTagId('')
            .withName('Valid')
            .withKeywordCondition('pasta')
            .build();

        // Standard validation requires tagId
        expect(rule.isValid, isFalse);
        // Embedded validation does not
        expect(rule.isValidEmbedded, isTrue);
      });

      test('validates numeric condition values', () {
        final rule = PersonalTagRuleBuilder()
            .withName('Time Rule')
            .withTimeCondition(30)
            .build();

        expect(PersonalTagRule.validateEmbedded(rule), isNull);
      });

      test('validates empty string value in text condition', () {
        final rule = PersonalTagRule(
          id: 'test',
          name: 'Test',
          conditions: const [
            RuleCondition(
              type: ConditionType.ingredient,
              operator: ConditionOperator.contains,
              value: '',
            ),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(PersonalTagRule.validateEmbedded(rule), isNotNull);
      });
    });

    group('condition type serialization', () {
      test('all condition types serialize correctly', () {
        for (final type in ConditionType.values) {
          final firestoreValue = type.toFirestore();
          final restored = ConditionTypeExtension.fromFirestore(firestoreValue);
          expect(restored, type, reason: 'Failed for $type');
        }
      });

      test('handles legacy sourceUrl formats', () {
        expect(
          ConditionTypeExtension.fromFirestore('sourceUrl'),
          ConditionType.sourceUrl,
        );
        expect(
          ConditionTypeExtension.fromFirestore('source_url'),
          ConditionType.sourceUrl,
        );
      });
    });

    group('operator serialization', () {
      test('all operators serialize correctly', () {
        for (final op in ConditionOperator.values) {
          final firestoreValue = op.toFirestore();
          final restored =
              ConditionOperatorExtension.fromFirestore(firestoreValue);
          expect(restored, op, reason: 'Failed for $op');
        }
      });

      test('handles legacy operator formats', () {
        expect(
          ConditionOperatorExtension.fromFirestore('not_contains'),
          ConditionOperator.notContains,
        );
        expect(
          ConditionOperatorExtension.fromFirestore('less_than'),
          ConditionOperator.lessThan,
        );
        expect(
          ConditionOperatorExtension.fromFirestore('greater_than_or_equal'),
          ConditionOperator.greaterThanOrEqual,
        );
      });
    });

    group('labels', () {
      test('condition types have Swedish labels', () {
        expect(ConditionType.ingredient.label, 'Ingrediens');
        expect(ConditionType.cuisine.label, 'Kök');
        expect(ConditionType.dietary.label, 'Kost');
        expect(ConditionType.time.label, 'Tid');
        expect(ConditionType.rating.label, 'Betyg');
        expect(ConditionType.recency.label, 'Nyligen');
      });

      test('operators have Swedish labels', () {
        expect(ConditionOperator.contains.label, 'innehåller');
        expect(ConditionOperator.lessThan.label, 'mindre än');
        expect(ConditionOperator.greaterThanOrEqual.label, 'minst');
        expect(ConditionOperator.withinDays.label, 'inom dagar');
      });
    });

    // #10: Tests for previously untested condition types
    group('ownership condition', () {
      test('matches "mine" when currentUserId matches recipe owner', () {
        final condition = RuleCondition(
          type: ConditionType.ownership,
          value: 'mine',
          operator: ConditionOperator.equals,
        );

        final recipe = RecipeBuilder().withCreatedBy('user-123').build();

        // Should match when currentUserId equals createdBy
        expect(
          condition.evaluate(recipe, null, currentUserId: 'user-123'),
          isTrue,
        );
      });

      test('does not match "mine" when currentUserId differs', () {
        final condition = RuleCondition(
          type: ConditionType.ownership,
          value: 'mine',
          operator: ConditionOperator.equals,
        );

        final recipe = RecipeBuilder().withCreatedBy('user-123').build();

        // Should not match when currentUserId differs
        expect(
          condition.evaluate(recipe, null, currentUserId: 'other-user'),
          isFalse,
        );
      });

      test('matches "collaborative" for collaborative recipes', () {
        final condition = RuleCondition(
          type: ConditionType.ownership,
          value: 'collaborative',
          operator: ConditionOperator.equals,
        );

        final recipe =
            RecipeBuilder().withType(RecipeType.collaborative).build();

        expect(
          condition.evaluate(recipe, null, currentUserId: 'other-user'),
          isTrue,
        );
      });

      test('matches "shared" for non-owned, non-collaborative recipes', () {
        final condition = RuleCondition(
          type: ConditionType.ownership,
          value: 'shared',
          operator: ConditionOperator.equals,
        );

        final recipe = RecipeBuilder()
            .withCreatedBy('owner-123')
            .withType(RecipeType.personal)
            .build();

        // Personal recipe not owned by current user = shared
        expect(
          condition.evaluate(recipe, null, currentUserId: 'viewer-456'),
          isTrue,
        );
      });

      test('notEquals operator works correctly', () {
        final condition = RuleCondition(
          type: ConditionType.ownership,
          value: 'mine',
          operator: ConditionOperator.notEquals,
        );

        final recipe = RecipeBuilder().withCreatedBy('owner-123').build();

        // Should match when ownership is NOT mine
        expect(
          condition.evaluate(recipe, null, currentUserId: 'other-user'),
          isTrue,
        );
      });
    });

    group('hasImage condition', () {
      test('matches true when recipe has images', () {
        final condition = RuleCondition(
          type: ConditionType.hasImage,
          value: 'true',
          operator: ConditionOperator.equals,
        );

        final recipe = RecipeBuilder()
            .withImageUrls(['https://example.com/image.jpg']).build();

        expect(condition.evaluate(recipe, null), isTrue);
      });

      test('matches false when recipe has no images', () {
        final condition = RuleCondition(
          type: ConditionType.hasImage,
          value: 'false',
          operator: ConditionOperator.equals,
        );

        final recipe = RecipeBuilder().withImageUrls([]).build();

        expect(condition.evaluate(recipe, null), isTrue);
      });

      test('does not match true when recipe has no images', () {
        final condition = RuleCondition(
          type: ConditionType.hasImage,
          value: 'true',
          operator: ConditionOperator.equals,
        );

        final recipe = RecipeBuilder().withImageUrls([]).build();

        expect(condition.evaluate(recipe, null), isFalse);
      });

      test('notEquals operator works correctly', () {
        final condition = RuleCondition(
          type: ConditionType.hasImage,
          value: 'true',
          operator: ConditionOperator.notEquals,
        );

        final recipe = RecipeBuilder().withImageUrls([]).build();

        // hasImage is false, so notEquals 'true' should be true
        expect(condition.evaluate(recipe, null), isTrue);
      });

      test('isBoolean returns true for hasImage', () {
        expect(ConditionType.hasImage.isBoolean, isTrue);
        expect(ConditionType.ingredient.isBoolean, isFalse);
        expect(ConditionType.time.isBoolean, isFalse);
      });
    });

    group('completeness condition', () {
      test('matches "missing_image" when recipe has no images', () {
        final condition = RuleCondition(
          type: ConditionType.completeness,
          value: 'missing_image',
          operator: ConditionOperator.equals,
        );

        final recipe = RecipeBuilder()
            .withImageUrls([])
            .withDescription('Has description')
            .build();

        expect(condition.evaluate(recipe, null), isTrue);
      });

      test('matches "missing_description" when recipe has no description', () {
        final condition = RuleCondition(
          type: ConditionType.completeness,
          value: 'missing_description',
          operator: ConditionOperator.equals,
        );

        final recipe = RecipeBuilder()
            .withImageUrls(['https://example.com/image.jpg'])
            .withDescription('')
            .build();

        expect(condition.evaluate(recipe, null), isTrue);
      });

      test('matches "incomplete" when missing image OR description', () {
        final condition = RuleCondition(
          type: ConditionType.completeness,
          value: 'incomplete',
          operator: ConditionOperator.equals,
        );

        // Missing image
        final missingImage = RecipeBuilder()
            .withImageUrls([])
            .withDescription('Has description')
            .build();

        // Missing description
        final missingDesc = RecipeBuilder()
            .withImageUrls(['https://example.com/image.jpg'])
            .withDescription('')
            .build();

        // Missing both
        final missingBoth =
            RecipeBuilder().withImageUrls([]).withDescription('').build();

        expect(condition.evaluate(missingImage, null), isTrue);
        expect(condition.evaluate(missingDesc, null), isTrue);
        expect(condition.evaluate(missingBoth, null), isTrue);
      });

      test('matches "complete" when recipe has image AND description', () {
        final condition = RuleCondition(
          type: ConditionType.completeness,
          value: 'complete',
          operator: ConditionOperator.equals,
        );

        final completeRecipe = RecipeBuilder()
            .withImageUrls(['https://example.com/image.jpg'])
            .withDescription('A complete recipe description')
            .build();

        expect(condition.evaluate(completeRecipe, null), isTrue);
      });

      test('does not match "complete" when missing image', () {
        final condition = RuleCondition(
          type: ConditionType.completeness,
          value: 'complete',
          operator: ConditionOperator.equals,
        );

        final incompleteRecipe = RecipeBuilder()
            .withImageUrls([])
            .withDescription('Has description')
            .build();

        expect(condition.evaluate(incompleteRecipe, null), isFalse);
      });

      test('does not match "complete" when missing description', () {
        final condition = RuleCondition(
          type: ConditionType.completeness,
          value: 'complete',
          operator: ConditionOperator.equals,
        );

        final incompleteRecipe = RecipeBuilder()
            .withImageUrls(['https://example.com/image.jpg'])
            .withDescription('')
            .build();

        expect(condition.evaluate(incompleteRecipe, null), isFalse);
      });

      test('notEquals operator works correctly', () {
        final condition = RuleCondition(
          type: ConditionType.completeness,
          value: 'complete',
          operator: ConditionOperator.notEquals,
        );

        final incompleteRecipe =
            RecipeBuilder().withImageUrls([]).withDescription('').build();

        // Should match because recipe is NOT complete
        expect(condition.evaluate(incompleteRecipe, null), isTrue);
      });
    });
  });
}
