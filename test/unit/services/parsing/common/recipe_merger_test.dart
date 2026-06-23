import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/models/parsing/parsed_recipe.dart';
import 'package:butlery/models/parsing/tier_result.dart';
import 'package:butlery/services/parsing/common/recipe_merger.dart';
import 'package:butlery/services/parsing/tiers/llm_tier.dart';
import 'package:butlery/services/parsing/tiers/rule_based_tier.dart';
import 'package:butlery/services/parsing/tiers/schema_org_tier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late RecipeMerger merger;

  setUp(() {
    merger = RecipeMerger();
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  ParsedIngredient ingredient(
    String name, {
    ParseConfidence confidence = ParseConfidence.high,
    String? quantity,
    String? unit,
  }) {
    return ParsedIngredient(
      name: name,
      originalLine: [
        if (quantity != null) quantity,
        if (unit != null) unit,
        name,
      ].join(' '),
      confidence: confidence,
      quantity: quantity,
      unit: unit,
    );
  }

  ParseMetadata metadata() {
    return ParseMetadata(
      source: ImportSource.url,
      tierResults: const [],
      totalParseTime: const Duration(milliseconds: 100),
      parserVersion: '1.0',
      timestamp: DateTime(2026, 1, 1),
    );
  }

  ParsedRecipe makeRecipe({
    String title = 'Test Recipe',
    ParseConfidence titleConfidence = ParseConfidence.high,
    int portions = 4,
    ParseConfidence portionsConfidence = ParseConfidence.high,
    List<ParsedIngredient>? ingredients,
    ParseConfidence ingredientsConfidence = ParseConfidence.high,
    List<String>? instructions,
    ParseConfidence instructionsConfidence = ParseConfidence.high,
    Duration totalTime = const Duration(minutes: 30),
    ParseConfidence totalTimeConfidence = ParseConfidence.high,
    String? imageUrl,
    String? description,
  }) {
    return ParsedRecipe(
      title: FieldResult(value: title, confidence: titleConfidence),
      portions: FieldResult(value: portions, confidence: portionsConfidence),
      ingredients: FieldResult(
        value: ingredients ?? [ingredient('salt'), ingredient('peppar')],
        confidence: ingredientsConfidence,
      ),
      instructions: FieldResult(
        value: instructions ?? ['Steg 1', 'Steg 2'],
        confidence: instructionsConfidence,
      ),
      totalTime: FieldResult(value: totalTime, confidence: totalTimeConfidence),
      metadata: metadata(),
      imageUrl: imageUrl,
      description: description,
    );
  }

  TierResult tierSuccess(ParsedRecipe recipe, {String tierName = 'T1'}) {
    return TierResult.success(
      tierName: tierName,
      recipe: recipe,
      duration: const Duration(milliseconds: 50),
    );
  }

  TierResult tierFailure({String tierName = 'Failed'}) {
    return TierResult.failure(
      tierName: tierName,
      reason: TierFailureReason.parseError,
      duration: const Duration(milliseconds: 10),
    );
  }

  // ---------------------------------------------------------------------------
  // BUG-4: Word-set ingredient deduplication
  // ---------------------------------------------------------------------------

  group('BUG-4: Word-set ingredient deduplication', () {
    // _ingredientsSimilar is private, so we test through merge() which calls
    // _mergeIngredientLists -> _ingredientsSimilar. We construct two tier
    // results whose ingredient lists overlap in specific ways, then verify
    // the merged output to infer similarity decisions.

    test(
      'should NOT treat "salt" vs "basalt" as similar (substring false positive prevented)',
      () {
        // If "salt" and "basalt" were similar, merging would deduplicate them.
        // We expect both to appear in the merged result.
        final primary = makeRecipe(
          ingredients: [ingredient('salt')],
        );
        final secondary = makeRecipe(
          ingredients: [ingredient('basalt')],
        );

        final result = merger.merge([
          tierSuccess(primary, tierName: 'T1'),
          tierSuccess(secondary, tierName: 'T2'),
        ]);

        expect(result, isNotNull);
        final names = result!.ingredients.value!.map((i) => i.name).toList();
        expect(names, contains('salt'));
        expect(names, contains('basalt'));
        expect(
          names.length,
          2,
          reason:
              '"salt" and "basalt" are different words and should not be deduplicated',
        );
      },
    );

    test('should treat "salt" vs "salt" as similar (exact match)', () {
      final primary = makeRecipe(
        ingredients: [ingredient('salt', confidence: ParseConfidence.medium)],
      );
      final secondary = makeRecipe(
        ingredients: [ingredient('salt', confidence: ParseConfidence.high)],
      );

      final result = merger.merge([
        tierSuccess(primary, tierName: 'T1'),
        tierSuccess(secondary, tierName: 'T2'),
      ]);

      expect(result, isNotNull);
      final names = result!.ingredients.value!.map((i) => i.name).toList();
      expect(
        names.where((n) => n == 'salt').length,
        1,
        reason: 'Exact duplicates should be deduplicated to one entry',
      );
    });

    test(
      'should treat "olivolja" vs "olivolja extra virgin" as similar (word-subset)',
      () {
        // "olivolja" is a word-subset of "olivolja extra virgin"
        final primary = makeRecipe(
          ingredients: [ingredient('olivolja')],
        );
        final secondary = makeRecipe(
          ingredients: [ingredient('olivolja extra virgin')],
        );

        final result = merger.merge([
          tierSuccess(primary, tierName: 'T1'),
          tierSuccess(secondary, tierName: 'T2'),
        ]);

        expect(result, isNotNull);
        final names = result!.ingredients.value!.map((i) => i.name).toList();
        // One should be deduplicated as a match
        expect(
          names.length,
          1,
          reason:
              '"olivolja" is a word-subset of "olivolja extra virgin" and should be matched',
        );
      },
    );

    test(
      'should NOT treat "rodlok" vs "lok" as similar (different words, not subset)',
      () {
        // "rodlok" is a single word; "lok" is a different single word.
        // Neither word-set is a subset of the other.
        final primary = makeRecipe(
          ingredients: [ingredient('rodlok')],
        );
        final secondary = makeRecipe(
          ingredients: [ingredient('lok')],
        );

        final result = merger.merge([
          tierSuccess(primary, tierName: 'T1'),
          tierSuccess(secondary, tierName: 'T2'),
        ]);

        expect(result, isNotNull);
        final names = result!.ingredients.value!.map((i) => i.name).toList();
        expect(names, contains('rodlok'));
        expect(names, contains('lok'));
        expect(
          names.length,
          2,
          reason:
              '"rodlok" and "lok" are different words and should not be deduplicated',
        );
      },
    );

    test('should treat "smor" vs "smor" as similar (exact match)', () {
      final primary = makeRecipe(
        ingredients: [ingredient('smor')],
      );
      final secondary = makeRecipe(
        ingredients: [ingredient('smor')],
      );

      final result = merger.merge([
        tierSuccess(primary, tierName: 'T1'),
        tierSuccess(secondary, tierName: 'T2'),
      ]);

      expect(result, isNotNull);
      final names = result!.ingredients.value!.map((i) => i.name).toList();
      expect(
        names.where((n) => n == 'smor').length,
        1,
        reason: 'Exact match should deduplicate to a single entry',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // merge() basic behavior
  // ---------------------------------------------------------------------------

  group('merge() basic behavior', () {
    test(
      'should return recipe as-is when given a single successful result',
      () {
        final recipe = makeRecipe(title: 'Pannkakor');
        final result = merger.merge([tierSuccess(recipe)]);

        expect(result, isNotNull);
        expect(result!.title.value, 'Pannkakor');
      },
    );

    test('should return null when given empty results list', () {
      final result = merger.merge([]);
      expect(result, isNull);
    });

    test('should return null when all results are failures', () {
      final result = merger.merge([
        tierFailure(tierName: 'T1'),
        tierFailure(tierName: 'T2'),
      ]);
      expect(result, isNull);
    });

    test('should filter out failed results and use successful ones', () {
      final recipe = makeRecipe(title: 'Lasagne');
      final result = merger.merge([
        tierFailure(tierName: 'T1'),
        tierSuccess(recipe, tierName: 'T2'),
        tierFailure(tierName: 'T3'),
      ]);

      expect(result, isNotNull);
      expect(result!.title.value, 'Lasagne');
    });

    test(
      'should prefer higher confidence field when merging multiple results',
      () {
        final primaryRecipe = makeRecipe(
          title: 'Low Confidence Title',
          titleConfidence: ParseConfidence.low,
          portions: 4,
          portionsConfidence: ParseConfidence.high,
        );
        final secondaryRecipe = makeRecipe(
          title: 'High Confidence Title',
          titleConfidence: ParseConfidence.high,
          portions: 2,
          portionsConfidence: ParseConfidence.low,
        );

        // Primary has higher overall quality due to more high-confidence fields
        // so it will be sorted first. But the title field from secondary should
        // win since secondary title confidence (1.0) > primary title confidence
        // (0.3) + threshold (0.1).
        final result = merger.merge([
          tierSuccess(primaryRecipe, tierName: 'T1'),
          tierSuccess(secondaryRecipe, tierName: 'T2'),
        ]);

        expect(result, isNotNull);
        // The higher-quality recipe becomes primary after sort.
        // Secondary's title (high=1.0) beats primary's title (low=0.3) by >0.1.
        // Secondary's portions (low=0.3) does NOT beat primary's portions (high=1.0).
        expect(result!.portions.value, 4);
      },
    );

    test(
      'should keep primary field when secondary is not significantly better',
      () {
        // Both have high confidence (score=1.0). Secondary does NOT exceed
        // primary by more than the 0.1 threshold, so primary wins.
        final primaryRecipe = makeRecipe(
          title: 'Primary Title',
          titleConfidence: ParseConfidence.high,
        );
        final secondaryRecipe = makeRecipe(
          title: 'Secondary Title',
          titleConfidence: ParseConfidence.high,
        );

        final result = merger.merge([
          tierSuccess(primaryRecipe, tierName: 'T1'),
          tierSuccess(secondaryRecipe, tierName: 'T2'),
        ]);

        expect(result, isNotNull);
        expect(result!.title.value, 'Primary Title');
      },
    );

    test('should use secondary field when primary has no value', () {
      final primaryRecipe = ParsedRecipe(
        title: FieldResult.success('Title'),
        portions: FieldResult<int>.failed('No portions'),
        ingredients: FieldResult.success(
          [ingredient('salt')],
        ),
        instructions: FieldResult.success(['Steg 1']),
        totalTime: FieldResult.success(const Duration(minutes: 20)),
        metadata: metadata(),
      );
      final secondaryRecipe = makeRecipe(
        title: 'Another Title',
        portions: 6,
        portionsConfidence: ParseConfidence.medium,
      );

      final result = merger.merge([
        tierSuccess(primaryRecipe, tierName: 'T1'),
        tierSuccess(secondaryRecipe, tierName: 'T2'),
      ]);

      expect(result, isNotNull);
      expect(result!.portions.value, 6);
      expect(result.portions.confidence, ParseConfidence.medium);
    });

    test('should populate tierResults metadata in merged recipe', () {
      // Metadata update only happens when 2+ successful results are merged.
      // We need two successful tiers plus a failed one to verify all are
      // captured in the final metadata.
      final recipe1 = makeRecipe(title: 'From SchemaOrg');
      final recipe2 = makeRecipe(
        title: 'From RuleBased',
        titleConfidence: ParseConfidence.low,
      );
      final result = merger.merge([
        tierSuccess(recipe1, tierName: SchemaOrgTier.tierIdentifier),
        tierSuccess(recipe2, tierName: RuleBasedTier.tierIdentifier),
        tierFailure(tierName: LlmTier.tierIdentifier),
      ]);

      expect(result, isNotNull);
      final tierNames = result!.metadata.tierResults
          .map((t) => t.tierName)
          .toList();
      expect(tierNames, contains(SchemaOrgTier.tierIdentifier));
      expect(tierNames, contains(RuleBasedTier.tierIdentifier));
      expect(tierNames, contains(LlmTier.tierIdentifier));
      expect(tierNames.length, 3);
    });
  });

  // ---------------------------------------------------------------------------
  // _mergeIngredients behavior
  // ---------------------------------------------------------------------------

  group('_mergeIngredients', () {
    test(
      'should prefer secondary when it has significantly more ingredients (>1.5x)',
      () {
        // Primary: 2 ingredients, secondary: 4 ingredients (4 > 2 * 1.5 = 3)
        final primaryRecipe = makeRecipe(
          ingredients: [
            ingredient('salt'),
            ingredient('peppar'),
          ],
        );
        final secondaryRecipe = makeRecipe(
          ingredients: [
            ingredient('salt'),
            ingredient('peppar'),
            ingredient('olivolja'),
            ingredient('vitlok'),
          ],
        );

        // Make secondary lower quality overall so primary is sorted first
        // (we want to test that secondary ingredients still win via count)
        final result = merger.merge([
          tierSuccess(primaryRecipe, tierName: 'T1'),
          tierSuccess(secondaryRecipe, tierName: 'T2'),
        ]);

        expect(result, isNotNull);
        final names = result!.ingredients.value!.map((i) => i.name).toList();
        // Secondary has 4 ingredients which is > 2 * 1.5 = 3,
        // so secondary ingredients should be preferred wholesale
        expect(names.length, 4);
        expect(names, contains('olivolja'));
        expect(names, contains('vitlok'));
      },
    );

    test(
      'should prefer secondary when it has higher average confidence (>0.2 better)',
      () {
        // We need primary to be the higher-quality recipe overall so it is
        // sorted first, while secondary has better ingredient confidence.
        // Give primary high confidence on everything except ingredients.
        final primary = makeRecipe(
          title: 'Recipe',
          titleConfidence: ParseConfidence.high,
          portionsConfidence: ParseConfidence.high,
          instructionsConfidence: ParseConfidence.high,
          totalTimeConfidence: ParseConfidence.high,
          ingredients: [
            ingredient('salt', confidence: ParseConfidence.low),
            ingredient('peppar', confidence: ParseConfidence.low),
          ],
          ingredientsConfidence: ParseConfidence.low,
        );
        final secondary = makeRecipe(
          title: 'Recipe',
          titleConfidence: ParseConfidence.low,
          portionsConfidence: ParseConfidence.low,
          instructionsConfidence: ParseConfidence.low,
          totalTimeConfidence: ParseConfidence.low,
          ingredients: [
            ingredient('salt', confidence: ParseConfidence.high),
            ingredient('peppar', confidence: ParseConfidence.high),
          ],
          ingredientsConfidence: ParseConfidence.high,
        );

        final result = merger.merge([
          tierSuccess(primary, tierName: 'T1'),
          tierSuccess(secondary, tierName: 'T2'),
        ]);

        expect(result, isNotNull);
        // Secondary ingredients field (high confidence) should replace
        // primary ingredients field (low confidence) because
        // confidenceScore 1.0 > 0.3 + 0.1 threshold
        expect(result!.ingredients.confidence, ParseConfidence.high);
      },
    );

    test(
      'should merge individual ingredients when neither count nor confidence rule triggers',
      () {
        // Same count (3 each), similar average confidence, but secondary has
        // one unique ingredient that should get added to the merged list.
        final primaryRecipe = makeRecipe(
          ingredients: [
            ingredient('salt'),
            ingredient('peppar'),
            ingredient('olivolja'),
          ],
        );
        final secondaryRecipe = makeRecipe(
          ingredients: [
            ingredient('salt'),
            ingredient('peppar'),
            ingredient('vitlok'),
          ],
        );

        final result = merger.merge([
          tierSuccess(primaryRecipe, tierName: 'T1'),
          tierSuccess(secondaryRecipe, tierName: 'T2'),
        ]);

        expect(result, isNotNull);
        final names = result!.ingredients.value!.map((i) => i.name).toList();
        // All unique ingredients should be present
        expect(names, contains('salt'));
        expect(names, contains('peppar'));
        expect(names, contains('olivolja'));
        expect(names, contains('vitlok'));
        expect(names.length, 4);
      },
    );

    test(
      'should pick higher-confidence version when merging matching ingredients',
      () {
        final primaryRecipe = makeRecipe(
          ingredients: [
            ingredient('salt', confidence: ParseConfidence.medium),
          ],
        );
        final secondaryRecipe = makeRecipe(
          ingredients: [
            ingredient(
              'salt',
              confidence: ParseConfidence.high,
              quantity: '1',
              unit: 'tsk',
            ),
          ],
        );

        final result = merger.merge([
          tierSuccess(primaryRecipe, tierName: 'T1'),
          tierSuccess(secondaryRecipe, tierName: 'T2'),
        ]);

        expect(result, isNotNull);
        final merged = result!.ingredients.value!;
        expect(merged.length, 1);
        // The secondary version (high confidence, structured) should win
        expect(merged.first.confidence, ParseConfidence.high);
        expect(merged.first.quantity, '1');
        expect(merged.first.unit, 'tsk');
      },
    );
  });

  // ---------------------------------------------------------------------------
  // patchWeakFields
  // ---------------------------------------------------------------------------

  group('patchWeakFields', () {
    test('should patch weak field (below threshold) from secondary', () {
      final base = makeRecipe(
        title: 'Weak Title',
        titleConfidence: ParseConfidence.low, // score 0.3 < 0.5 threshold
      );
      final patch = makeRecipe(
        title: 'Strong Title',
        titleConfidence: ParseConfidence.high,
      );

      final result = merger.patchWeakFields(base, patch);

      expect(result.title.value, 'Strong Title');
      expect(result.title.confidence, ParseConfidence.high);
    });

    test('should keep strong field (above threshold) from base', () {
      final base = makeRecipe(
        title: 'Base Title',
        titleConfidence: ParseConfidence.high, // score 1.0 >= 0.5 threshold
      );
      final patch = makeRecipe(
        title: 'Patch Title',
        titleConfidence: ParseConfidence.high,
      );

      final result = merger.patchWeakFields(base, patch);

      expect(result.title.value, 'Base Title');
    });

    test('should keep base field when it is exactly at the threshold', () {
      // medium confidence score = 0.7 >= default threshold 0.5
      final base = makeRecipe(
        title: 'Base Title',
        titleConfidence: ParseConfidence.medium,
      );
      final patch = makeRecipe(
        title: 'Patch Title',
        titleConfidence: ParseConfidence.high,
      );

      final result = merger.patchWeakFields(base, patch);

      expect(result.title.value, 'Base Title');
    });

    test('should patch multiple weak fields independently', () {
      final base = makeRecipe(
        title: 'Weak Title',
        titleConfidence: ParseConfidence.low,
        portions: 2,
        portionsConfidence: ParseConfidence.low,
        instructions: ['Vag instructions'],
        instructionsConfidence: ParseConfidence.high, // strong, keep this
      );
      final patch = makeRecipe(
        title: 'Better Title',
        titleConfidence: ParseConfidence.high,
        portions: 4,
        portionsConfidence: ParseConfidence.high,
        instructions: ['Patch instructions'],
        instructionsConfidence: ParseConfidence.high,
      );

      final result = merger.patchWeakFields(base, patch);

      expect(
        result.title.value,
        'Better Title',
        reason: 'Weak title should be patched',
      );
      expect(
        result.portions.value,
        4,
        reason: 'Weak portions should be patched',
      );
      expect(
        result.instructions.value,
        ['Vag instructions'],
        reason: 'Strong instructions should be kept from base',
      );
    });

    test('should respect custom threshold parameter', () {
      // medium confidence score = 0.7
      final base = makeRecipe(
        title: 'Medium Title',
        titleConfidence: ParseConfidence.medium,
      );
      final patch = makeRecipe(
        title: 'Patched Title',
        titleConfidence: ParseConfidence.high,
      );

      // With threshold=0.8, medium (0.7) is below threshold -> patch
      final result = merger.patchWeakFields(base, patch, threshold: 0.8);
      expect(result.title.value, 'Patched Title');

      // With threshold=0.5, medium (0.7) is above threshold -> keep base
      final result2 = merger.patchWeakFields(base, patch, threshold: 0.5);
      expect(result2.title.value, 'Medium Title');
    });

    test('should not patch when patch has no value for weak field', () {
      final base = makeRecipe(
        title: 'Weak Title',
        titleConfidence: ParseConfidence.low,
      );
      final patch = ParsedRecipe(
        title: FieldResult<String>.failed('No title'),
        portions: FieldResult.success(4),
        ingredients: FieldResult.success([ingredient('salt')]),
        instructions: FieldResult.success(['Step 1']),
        totalTime: FieldResult.success(const Duration(minutes: 20)),
        metadata: metadata(),
      );

      final result = merger.patchWeakFields(base, patch);

      // Base title is weak, but patch has no value, so base is kept
      expect(result.title.value, 'Weak Title');
    });

    test('should use patch imageUrl when base has none', () {
      final base = makeRecipe();
      final patch = makeRecipe(imageUrl: 'https://example.com/image.jpg');

      final result = merger.patchWeakFields(base, patch);

      expect(result.imageUrl, 'https://example.com/image.jpg');
    });

    test('should keep base imageUrl when present', () {
      final base = makeRecipe(imageUrl: 'https://base.com/image.jpg');
      final patch = makeRecipe(imageUrl: 'https://patch.com/image.jpg');

      final result = merger.patchWeakFields(base, patch);

      expect(result.imageUrl, 'https://base.com/image.jpg');
    });

    test('should use patch description when base has none', () {
      final base = makeRecipe();
      final patch = makeRecipe(description: 'A tasty recipe');

      final result = merger.patchWeakFields(base, patch);

      expect(result.description, 'A tasty recipe');
    });

    test('should preserve base metadata', () {
      final base = makeRecipe();
      final patch = makeRecipe();

      final result = merger.patchWeakFields(base, patch);

      expect(result.metadata.source, base.metadata.source);
      expect(result.metadata.parserVersion, base.metadata.parserVersion);
    });
  });
}
