import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/tag_generator.dart';

import '../infrastructure/builders/recipe_builder.dart';

void main() {
  late TagGenerator generator;
  late List<dynamic> dataset;

  setUpAll(() {
    generator = TagGenerator();
    final file = File('test/golden/tagging_golden_dataset.json');
    dataset = jsonDecode(file.readAsStringSync()) as List;
  });

  group('Tagging golden dataset', () {
    for (var i = 0; i < 20; i++) {
      test('recipe ${i + 1}', () {
        assert(i < dataset.length, 'Dataset has fewer than ${i + 1} entries');
        final entry = dataset[i] as Map<String, dynamic>;
        final id = entry['id'] as String;
        final title = entry['title'] as String;
        final ingredients = (entry['ingredients'] as List).cast<String>();
        final instructions = (entry['instructions'] as List).cast<String>();
        final timeMinutes = entry['timeMinutes'] as int?;
        final matchedRaw =
            (entry['matched'] as List).cast<Map<String, dynamic>>();
        final unmatchedRaw = (entry['unmatched'] as List).cast<String>();
        final expected = entry['expected'] as Map<String, dynamic>;

        // Build recipe
        final recipe = RecipeBuilder()
            .withId(id)
            .withTitle(title)
            .withIngredients(ingredients)
            .withInstructions(instructions)
            .withTimeMinutes(timeMinutes)
            .build();

        // Build ingredient lookup
        final matched = matchedRaw.map((m) {
          final props = (m['properties'] as List).cast<String>().toSet();
          return IngredientData(
            id: m['id'] as String,
            swedish: m['swedish'] as String,
            english: m['english'] as String,
            group: m['group'] as String,
            properties: props,
          );
        }).toList();

        final lookup = IngredientLookupResult.fromLists(
          matched: matched,
          unmatched: unmatchedRaw,
        );

        // Generate tags
        final result = generator.generate(
          ingredients: lookup,
          recipe: recipe,
        );

        // Assert allergens
        if (expected.containsKey('allergens')) {
          final expectedAllergens =
              (expected['allergens'] as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, _parseTriState(v as String)),
          );
          for (final allergen in expectedAllergens.entries) {
            expect(
              result.getAllergenStatus(allergen.key),
              allergen.value,
              reason:
                  '[$title] allergen "${allergen.key}" expected ${allergen.value}',
            );
          }
        }

        // Assert dietary
        if (expected.containsKey('dietary')) {
          final expectedDietary =
              (expected['dietary'] as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, _parseTriState(v as String)),
          );
          for (final diet in expectedDietary.entries) {
            expect(
              result.getDietaryStatus(diet.key),
              diet.value,
              reason: '[$title] dietary "${diet.key}" expected ${diet.value}',
            );
          }
        }

        // Assert minimum coverage
        if (expected.containsKey('minCoverage')) {
          final minCoverage = (expected['minCoverage'] as num).toDouble();
          expect(
            result.coverage,
            greaterThanOrEqualTo(minCoverage),
            reason:
                '[$title] coverage ${result.coverage} < minCoverage $minCoverage',
          );
        }

        // Assert hasTags
        if (expected.containsKey('hasTags')) {
          final hasTags = (expected['hasTags'] as List).cast<String>();
          for (final tag in hasTags) {
            expect(
              result.hasTag(tag),
              isTrue,
              reason:
                  '[$title] expected tag "$tag" not found in ${result.tags}',
            );
          }
        }

        // Assert notHasTags
        if (expected.containsKey('notHasTags')) {
          final notHasTags = (expected['notHasTags'] as List).cast<String>();
          for (final tag in notHasTags) {
            expect(
              result.hasTag(tag),
              isFalse,
              reason: '[$title] unexpected tag "$tag" found in ${result.tags}',
            );
          }
        }
      });
    }
  });
}

TriState _parseTriState(String value) {
  return TriStateParsing.fromString(value) ??
      (throw ArgumentError('Invalid TriState value: $value'));
}
