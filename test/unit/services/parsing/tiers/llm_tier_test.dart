import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/tier_result.dart';
import 'package:butlery/services/llm/llm_models.dart';
import 'package:butlery/services/llm/llm_service.dart';
import 'package:butlery/services/parsing/tiers/llm_tier.dart';
import 'package:butlery/services/parsing/tiers/parsing_context.dart';

/// Mock LlmService that returns canned responses.
class MockLlmService implements LlmService {
  StructureRecipeResponse? nextResponse;
  Exception? nextError;
  int callCount = 0;

  @override
  Future<StructureRecipeResponse> structureRecipe({
    required String text,
    StructureMode mode = StructureMode.extract,
    String? sourceUrl,
    Map<String, dynamic>? partialData,
  }) async {
    callCount++;
    if (nextError != null) throw nextError!;
    return nextResponse ??
        const StructureRecipeResponse(
          success: false,
          estimatedCost: 0.0,
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockLlmService mockLlmService;
  late LlmTier tier;

  ParsingContext createContext(
      {String content =
          'A long enough recipe text for testing purposes that exceeds the minimum length requirement of fifty chars'}) {
    return ParsingContext.fromText(
      text: content,
      source: ImportSource.text,
      userId: 'test-user',
      parserVersion: '2.0.0',
    );
  }

  ExtractedRecipe validRecipe({
    String title = 'Pannkakor',
    int? portions = 4,
    int? prepTime = 10,
    int? cookTime = 20,
    List<ExtractedIngredient>? ingredients,
    List<String>? instructions,
  }) {
    return ExtractedRecipe(
      title: title,
      portions: portions,
      prepTimeMinutes: prepTime,
      cookTimeMinutes: cookTime,
      ingredients: ingredients ??
          const [
            ExtractedIngredient(name: 'mjol', amount: 3, unit: 'dl'),
            ExtractedIngredient(name: 'mjolk', amount: 6, unit: 'dl'),
            ExtractedIngredient(name: 'agg', amount: 3),
          ],
      instructions: instructions ??
          const [
            'Blanda mjol och halva mjolken till en slat smet.',
            'Tillsatt resten av mjolken och aggen.',
            'Stek tunna pannkakor i smor.',
          ],
    );
  }

  setUp(() {
    mockLlmService = MockLlmService();
    tier = LlmTier(llmService: mockLlmService);
  });

  group('LlmTier', () {
    test('returns medium confidence for all fields (not high)', () async {
      mockLlmService.nextResponse = StructureRecipeResponse(
        success: true,
        recipe: validRecipe(),
        estimatedCost: 0.01,
      );

      final context = createContext();
      final result = await tier.parse(context);

      expect(result.success, isTrue);
      final recipe = result.recipe!;

      // Title should be medium, not high
      expect(recipe.title.confidence, ParseConfidence.medium);
      expect(recipe.portions.confidence, ParseConfidence.medium);
      expect(recipe.ingredients.confidence, ParseConfidence.medium);
      expect(recipe.instructions.confidence, ParseConfidence.medium);

      // Per-ingredient confidence should be medium
      for (final ing in recipe.ingredients.value!) {
        expect(ing.confidence, ParseConfidence.medium);
      }
    });

    test('validates empty title triggers validation failure', () async {
      mockLlmService.nextResponse = StructureRecipeResponse(
        success: true,
        recipe: validRecipe(title: ''),
        estimatedCost: 0.01,
      );

      final context = createContext();
      final result = await tier.parse(context);

      // Should still succeed with partial result (has valid ingredients)
      expect(result.success, isTrue);
      expect(result.recipe, isNotNull);
      expect(result.recipe!.title.confidence, ParseConfidence.failed);
      expect(result.recipe!.ingredients.hasValue, isTrue);
    });

    test('validates unreasonable portions triggers validation', () async {
      mockLlmService.nextResponse = StructureRecipeResponse(
        success: true,
        recipe: validRecipe(portions: 999),
        estimatedCost: 0.01,
      );

      final context = createContext();
      final result = await tier.parse(context);

      // Should succeed with partial result — portions invalid but rest valid
      expect(result.success, isTrue);
      expect(result.recipe, isNotNull);
      // Portions should fall back to default
      expect(result.recipe!.portions.value, 4);
      expect(result.recipe!.portions.confidence, ParseConfidence.low);
    });

    test('validates title containing URL triggers validation', () async {
      mockLlmService.nextResponse = StructureRecipeResponse(
        success: true,
        recipe: validRecipe(title: 'https://evil.com/recipe'),
        estimatedCost: 0.01,
      );

      final context = createContext();
      final result = await tier.parse(context);

      expect(result.success, isTrue);
      expect(result.recipe!.title.confidence, ParseConfidence.failed);
    });

    test('validates time over 2880 minutes triggers validation', () async {
      mockLlmService.nextResponse = StructureRecipeResponse(
        success: true,
        recipe: validRecipe(prepTime: 3000, cookTime: 0),
        estimatedCost: 0.01,
      );

      final context = createContext();
      final result = await tier.parse(context);

      expect(result.success, isTrue);
      expect(result.recipe!.totalTime.confidence, ParseConfidence.failed);
    });

    test('returns null when both title and ingredients are invalid', () async {
      mockLlmService.nextResponse = StructureRecipeResponse(
        success: true,
        recipe: validRecipe(
          title: '',
          ingredients: const [],
        ),
        estimatedCost: 0.01,
      );

      final context = createContext();
      final result = await tier.parse(context);

      expect(result.success, isFalse);
      expect(result.failureReason, TierFailureReason.schemaValidationFailed);
    });

    test('P0-2 suspicious pattern check still works', () async {
      mockLlmService.nextResponse = StructureRecipeResponse(
        success: true,
        recipe: validRecipe(title: '<script>alert("xss")</script>'),
        estimatedCost: 0.01,
      );

      final context = createContext();
      final result = await tier.parse(context);

      expect(result.success, isFalse);
      expect(result.failureReason, TierFailureReason.invalidResponse);
    });

    test('handles LLM service returning unsuccessful response', () async {
      mockLlmService.nextResponse = const StructureRecipeResponse(
        success: false,
        estimatedCost: 0.01,
        error: 'Model unavailable',
      );

      final context = createContext();
      final result = await tier.parse(context);

      expect(result.success, isFalse);
      expect(result.failureReason, TierFailureReason.noData);
    });

    test('handles exception from LLM service', () async {
      mockLlmService.nextError = Exception('Network error');

      final context = createContext();
      final result = await tier.parse(context);

      expect(result.success, isFalse);
      expect(result.failureReason, TierFailureReason.parseError);
    });

    test('skips when content too short', () async {
      final context = createContext(content: 'too short');
      final result = await tier.parse(context);

      expect(result.success, isFalse);
      expect(result.failureReason, TierFailureReason.noData);
    });

    test('skips when llmService is null', () {
      final nullTier = LlmTier(llmService: null);
      final context = createContext();
      expect(nullTier.shouldSkip(context), isTrue);
    });

    test('threads promptVersion from response into successful TierResult',
        () async {
      mockLlmService.nextResponse = StructureRecipeResponse(
        success: true,
        recipe: validRecipe(),
        estimatedCost: 0.01,
        promptVersion: 'v3.1',
      );

      final context = createContext();
      final result = await tier.parse(context);

      expect(result.success, isTrue);
      expect(result.promptVersion, 'v3.1');
    });

    test('threads promptVersion into failed TierResult (no recipe path)',
        () async {
      mockLlmService.nextResponse = const StructureRecipeResponse(
        success: false,
        estimatedCost: 0.01,
        promptVersion: 'v3.1',
      );

      final context = createContext();
      final result = await tier.parse(context);

      expect(result.success, isFalse);
      expect(result.promptVersion, 'v3.1');
    });

    // BUT-512: per-unit amount validation
    group('per-unit amount ceilings (BUT-512)', () {
      test('rejects 5000 kg salt as implausible', () async {
        mockLlmService.nextResponse = StructureRecipeResponse(
          success: true,
          recipe: validRecipe(
            ingredients: const [
              ExtractedIngredient(name: 'salt', amount: 5000, unit: 'kg'),
            ],
          ),
          estimatedCost: 0.01,
        );

        final result = await tier.parse(createContext());

        // Above-ceiling kg → ingredient_amount_range → no valid ingredients
        // → partial recipe with failed ingredients → still has title.
        expect(result.recipe!.ingredients.confidence, ParseConfidence.failed);
      });

      test('keeps 2 kg flour (below ceiling)', () async {
        mockLlmService.nextResponse = StructureRecipeResponse(
          success: true,
          recipe: validRecipe(
            ingredients: const [
              ExtractedIngredient(name: 'mjol', amount: 2, unit: 'kg'),
            ],
          ),
          estimatedCost: 0.01,
        );

        final result = await tier.parse(createContext());

        expect(result.success, isTrue);
        expect(result.recipe!.ingredients.value!.length, 1);
      });

      test('keeps unitless 50 (under unitless ceiling)', () async {
        mockLlmService.nextResponse = StructureRecipeResponse(
          success: true,
          recipe: validRecipe(
            ingredients: const [
              ExtractedIngredient(name: 'agg', amount: 50),
            ],
          ),
          estimatedCost: 0.01,
        );

        final result = await tier.parse(createContext());

        expect(result.success, isTrue);
        expect(result.recipe!.ingredients.value!.length, 1);
      });

      test('rejects 200 dl (above per-unit ceiling 50)', () async {
        mockLlmService.nextResponse = StructureRecipeResponse(
          success: true,
          recipe: validRecipe(
            ingredients: const [
              ExtractedIngredient(name: 'mjolk', amount: 200, unit: 'dl'),
            ],
          ),
          estimatedCost: 0.01,
        );

        final result = await tier.parse(createContext());

        expect(result.recipe!.ingredients.confidence, ParseConfidence.failed);
      });
    });

    // BUT-516: drop unknown-unit ingredient rows at conversion time
    group('unknown-unit drop (BUT-516)', () {
      test('drops ingredient with unknown unit "glass"', () async {
        mockLlmService.nextResponse = StructureRecipeResponse(
          success: true,
          recipe: validRecipe(
            ingredients: const [
              ExtractedIngredient(name: 'mjol', amount: 3, unit: 'dl'),
              ExtractedIngredient(name: 'vatten', amount: 2, unit: 'glass'),
              ExtractedIngredient(name: 'agg', amount: 3),
            ],
          ),
          estimatedCost: 0.01,
        );

        final result = await tier.parse(createContext());

        expect(result.success, isTrue);
        // 3 input → 1 dropped (glass) → 2 kept (mjol + agg)
        final names =
            result.recipe!.ingredients.value!.map((i) => i.name).toList();
        expect(names, contains('mjol'));
        expect(names, contains('agg'));
        expect(names, isNot(contains('vatten')));
      });

      test('returns no-data when ALL ingredients have unknown units', () async {
        // All-unknown drop → empty ingredients → recipe.isComplete false
        // → TierResult.noData (recipe null).
        mockLlmService.nextResponse = StructureRecipeResponse(
          success: true,
          recipe: validRecipe(
            ingredients: const [
              ExtractedIngredient(name: 'mjol', amount: 3, unit: 'glass'),
              ExtractedIngredient(name: 'vatten', amount: 2, unit: 'mug'),
            ],
          ),
          estimatedCost: 0.01,
        );

        final result = await tier.parse(createContext());

        expect(result.success, isFalse);
        expect(result.recipe, isNull);
      });

      test('keeps ingredients with empty/null unit (not unknown)', () async {
        mockLlmService.nextResponse = StructureRecipeResponse(
          success: true,
          recipe: validRecipe(
            ingredients: const [
              ExtractedIngredient(name: 'agg', amount: 3),
              ExtractedIngredient(name: 'gurka', amount: 1, unit: ''),
            ],
          ),
          estimatedCost: 0.01,
        );

        final result = await tier.parse(createContext());

        expect(result.success, isTrue);
        expect(result.recipe!.ingredients.value!.length, 2);
      });
    });

    // BUT-528: cap instruction count
    group('instruction count cap (BUT-528)', () {
      test('keeps recipe with exactly 50 instructions untouched', () async {
        final fifty = List.generate(
          50,
          (i) => 'Step ${i + 1}: do something useful for the recipe.',
        );
        mockLlmService.nextResponse = StructureRecipeResponse(
          success: true,
          recipe: validRecipe(instructions: fifty),
          estimatedCost: 0.01,
        );

        final result = await tier.parse(createContext());

        expect(result.success, isTrue);
        expect(result.recipe!.instructions.value!.length, 50);
      });

      test('truncates 100 instructions down to 50', () async {
        final hundred = List.generate(
          100,
          (i) => 'Step ${i + 1}: do something useful for the recipe.',
        );
        mockLlmService.nextResponse = StructureRecipeResponse(
          success: true,
          recipe: validRecipe(instructions: hundred),
          estimatedCost: 0.01,
        );

        final result = await tier.parse(createContext());

        expect(result.success, isTrue);
        expect(result.recipe!.instructions.value!.length, 50);
        // Front-loaded — first 50 retained
        expect(result.recipe!.instructions.value!.first, contains('Step 1:'));
        expect(result.recipe!.instructions.value!.last, contains('Step 50:'));
      });
    });
  });
}
