import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/parsing/tiers/schema_org_tier.dart';
import 'package:butlery/services/parsing/tiers/parsing_context.dart';
import 'package:butlery/services/parsing/common/recipe_merger.dart';

import '../fixtures/swedish_sites/ica_test_data.dart';
import '../fixtures/swedish_sites/arla_test_data.dart';

void main() {
  // Load eagerly so test names can reference dataset entries
  final file = File('test/golden/parsing_golden_dataset.json');
  final dataset = jsonDecode(file.readAsStringSync()) as List;

  final schemaOrgTier = SchemaOrgTier();
  final merger = RecipeMerger();

  final fixtures = <String, String>{
    'IcaTestFixtures.kottbullarComplete': IcaTestFixtures.kottbullarComplete,
    'IcaTestFixtures.recipeWithoutJsonLd': IcaTestFixtures.recipeWithoutJsonLd,
    'IcaTestFixtures.recipeWithSwedishChars':
        IcaTestFixtures.recipeWithSwedishChars,
    'ArlaTestFixtures.chokladbollarComplete':
        ArlaTestFixtures.chokladbollarComplete,
  };

  group('Parsing golden dataset', () {
    for (var i = 0; i < dataset.length; i++) {
      final entry = dataset[i] as Map<String, dynamic>;
      final id = entry['id'] as String;

      test('[$id]', () async {
        final domain = entry['domain'] as String;
        final fixtureKey = entry['fixture'] as String;
        final expected = entry['expected'] as Map<String, dynamic>;

        final html = fixtures[fixtureKey];
        if (html == null) {
          fail('Unknown fixture: $fixtureKey for entry $id');
        }

        final context = ParsingContext.fromUrl(
          url: 'https://$domain/test-recipe',
          htmlContent: html,
          userId: 'golden-test',
          parserVersion: '2.0.0',
        );

        final result = await schemaOrgTier.parseWithTimeout(context);
        final merged = merger.merge([result]);

        // No JSON-LD — SchemaOrg produces no result; skip field assertions
        if (fixtureKey.contains('WithoutJsonLd')) {
          return;
        }

        expect(merged, isNotNull, reason: '$id: merge produced null');
        final recipe = merged!;

        if (expected.containsKey('titleContains')) {
          expect(
            recipe.title.value?.toLowerCase(),
            contains((expected['titleContains'] as String).toLowerCase()),
            reason: '$id: title mismatch',
          );
        }

        if (expected.containsKey('portions')) {
          expect(
            recipe.portions.value,
            equals(expected['portions']),
            reason: '$id: portions mismatch',
          );
        }

        final ingredients = recipe.ingredients.value ?? [];

        if (expected.containsKey('ingredientCountMin')) {
          expect(
            ingredients.length,
            greaterThanOrEqualTo(expected['ingredientCountMin'] as int),
            reason: '$id: too few ingredients',
          );
        }

        if (expected.containsKey('ingredientSubstrings')) {
          final substrings =
              (expected['ingredientSubstrings'] as List).cast<String>();
          final ingredientText =
              ingredients.map((i) => i.originalLine.toLowerCase()).join(' ');
          for (final sub in substrings) {
            expect(
              ingredientText,
              contains(sub.toLowerCase()),
              reason: '$id: ingredient "$sub" not found',
            );
          }
        }

        if (expected.containsKey('instructionCountMin')) {
          final instructions = recipe.instructions.value ?? [];
          expect(
            instructions.length,
            greaterThanOrEqualTo(expected['instructionCountMin'] as int),
            reason: '$id: too few instructions',
          );
        }

        if (expected.containsKey('totalTimeMinutes')) {
          expect(
            recipe.totalTime.value?.inMinutes,
            equals(expected['totalTimeMinutes']),
            reason: '$id: totalTimeMinutes mismatch',
          );
        }

        if (expected.containsKey('minQuality')) {
          expect(
            recipe.overallQuality,
            greaterThanOrEqualTo(expected['minQuality'] as double),
            reason: '$id: quality too low',
          );
        }
      });
    }
  });
}
