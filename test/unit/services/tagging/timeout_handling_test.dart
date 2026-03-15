import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/tag_generator.dart';

import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../infrastructure/helpers/tagging_test_helper.dart';

/// Tests for TagGenerator timeout handling.
///
/// These tests verify the C3 timeout behavior:
/// - Phase 1 (allergens/dietary) ALWAYS completes (safety-critical)
/// - Remaining phases are skipped if timeout exceeded
/// - isPartial=true when phases are skipped
/// - Tags from completed phases are preserved
void main() {
  late TagGenerator generator;

  setUp(() {
    generator = TagGenerator();
  });

  group('TagGenerator timeout handling', () {
    group('C3: Phase 1 always completes', () {
      test('Phase 1 completes even with zero timeout', () {
        // A zero timeout means we're already "timed out" before starting,
        // but Phase 1 should still complete because it's safety-critical
        final recipe = RecipeBuilder()
            .withTitle('Test Recipe')
            .withTimeMinutes(30)
            .withIngredients(['milk', 'eggs']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
              'milk', 'dairy', {'dairy', 'contains-lactose'}),
          TaggingTestHelper.ingredient(
              'eggs', 'protein/eggs', {'egg', 'animal-product'}),
        ]);

        // Use a Duration.zero timeout - everything should be "timed out"
        // But Phase 1 MUST complete before checking timeout
        final result = generator.generate(
          ingredients: lookup,
          recipe: recipe,
          timeout: Duration.zero,
        );

        // Phase 1 tags should be present
        expect(result.getAllergenStatus('mjölk'), TriState.contains);
        expect(result.getAllergenStatus('ägg'), TriState.contains);

        // Result should be marked partial since phases 2-4 were skipped
        expect(result.isPartial, isTrue);
      });

      test('allergen status populated even on immediate timeout', () {
        final recipe = RecipeBuilder()
            .withTitle('Gluten Recipe')
            .withIngredients(['wheat flour']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
              'wheat flour', 'grain', {'contains-gluten'}),
        ]);

        final result = generator.generate(
          ingredients: lookup,
          recipe: recipe,
          timeout: Duration.zero,
        );

        // Allergen status from Phase 1 MUST be populated
        expect(result.getAllergenStatus('gluten'), TriState.contains);
        expect(result.isPartial, isTrue);
      });

      test('dietary status populated even on immediate timeout', () {
        final recipe = RecipeBuilder()
            .withTitle('Vegan Recipe')
            .withIngredients(['tofu', 'vegetables']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
              'tofu', 'protein/plant', {'plant-based'}),
          TaggingTestHelper.ingredient(
              'vegetables', 'vegetable', {'plant-based'}),
        ]);

        final result = generator.generate(
          ingredients: lookup,
          recipe: recipe,
          timeout: Duration.zero,
        );

        // Dietary status from Phase 1 MUST be populated
        // With 100% plant-based coverage, should be vegan-safe
        expect(result.getDietaryStatus('vegansk'), TriState.free);
        expect(result.isPartial, isTrue);
      });
    });

    group('C3: isPartial flag', () {
      test('isPartial=false when no timeout', () {
        final recipe = RecipeBuilder()
            .withTitle('Normal Recipe')
            .withTimeMinutes(30)
            .withIngredients(['rice']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('rice', 'grain', {}),
        ]);

        // No timeout - all phases should complete
        final result = generator.generate(
          ingredients: lookup,
          recipe: recipe,
        );

        expect(result.isPartial, isFalse);
      });

      test('isPartial=true when phases skipped due to timeout', () {
        final recipe = RecipeBuilder()
            .withTitle('Test Recipe')
            .withTimeMinutes(30)
            .withIngredients(['pasta']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('pasta', 'grain', {'contains-gluten'}),
        ]);

        // Zero timeout - phases 2-4 should be skipped
        final result = generator.generate(
          ingredients: lookup,
          recipe: recipe,
          timeout: Duration.zero,
        );

        expect(result.isPartial, isTrue);
      });

      test('isPartial=false with generous timeout', () {
        final recipe = RecipeBuilder()
            .withTitle('Normal Recipe')
            .withTimeMinutes(30)
            .withIngredients(['chicken']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
              'chicken', 'protein/meat/poultry', {'meat', 'poultry'}),
        ]);

        // Generous timeout - all phases should complete
        final result = generator.generate(
          ingredients: lookup,
          recipe: recipe,
          timeout: const Duration(seconds: 30),
        );

        expect(result.isPartial, isFalse);
      });
    });

    group('C3: Phase 1-only generation', () {
      test('generatePhase1Only always returns isPartial=true', () {
        final recipe = RecipeBuilder()
            .withTitle('Preview Recipe')
            .withTimeMinutes(20)
            .withIngredients(['salmon']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
              'salmon', 'protein/seafood/fish', {'fish', 'seafood'}),
        ]);

        final result = generator.generatePhase1Only(
          ingredients: lookup,
          recipe: recipe,
        );

        // Phase 1 only is always partial
        expect(result.isPartial, isTrue);

        // But allergen data should be complete
        expect(result.getAllergenStatus('fisk'), TriState.contains);
      });

      test('generatePhase1Only includes allergen status', () {
        final recipe = RecipeBuilder()
            .withTitle('Nut Recipe')
            .withIngredients(['almonds', 'walnuts']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('almonds', 'nut', {'tree-nut'}),
          TaggingTestHelper.ingredient('walnuts', 'nut', {'tree-nut'}),
        ]);

        final result = generator.generatePhase1Only(
          ingredients: lookup,
          recipe: recipe,
        );

        expect(result.getAllergenStatus('nötter'), TriState.contains);
      });

      test('generatePhase1Only includes dietary status', () {
        final recipe = RecipeBuilder()
            .withTitle('Vegetarian Recipe')
            .withIngredients(['tofu', 'broccoli']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
              'tofu', 'protein/plant', {'plant-based'}),
          TaggingTestHelper.ingredient(
              'broccoli', 'vegetable', {'plant-based'}),
        ]);

        final result = generator.generatePhase1Only(
          ingredients: lookup,
          recipe: recipe,
        );

        // Should be vegetarian-safe with no meat
        expect(result.getDietaryStatus('vegetarisk'), TriState.free);
      });
    });

    group('Tags from completed phases preserved', () {
      test('time tags (Phase 1) preserved on timeout', () {
        final recipe = RecipeBuilder()
            .withTitle('Quick Recipe')
            .withTimeMinutes(15)
            .withIngredients(['lettuce']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient('lettuce', 'vegetable', {'plant-based'}),
        ]);

        final result = generator.generate(
          ingredients: lookup,
          recipe: recipe,
          timeout: Duration.zero,
        );

        // Time tags from Phase 1 should be present
        expect(result.hasTag('under-15-min'), isTrue);
        expect(result.hasTag('under-30-min'), isTrue);
      });

      test('protein tags (Phase 1) preserved on timeout', () {
        // Protein tags like 'kyckling' are generated when ingredient name contains the word
        final recipe = RecipeBuilder()
            .withTitle('Kycklinggryta')
            .withIngredients(['kycklingbröst']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
              'kycklingbröst', 'protein/meat/poultry', {'meat', 'poultry'}),
        ]);

        final result = generator.generate(
          ingredients: lookup,
          recipe: recipe,
          timeout: Duration.zero,
        );

        // Protein tags from Phase 1 should be present (matched by name containing 'kyckling')
        expect(result.hasTag('kyckling'), isTrue);
      });

      test('allergen decision logs (H3) preserved on timeout', () {
        final recipe = RecipeBuilder()
            .withTitle('Dairy Recipe')
            .withIngredients(['milk', 'cheese']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
              'milk', 'dairy', {'dairy', 'contains-lactose'}),
          TaggingTestHelper.ingredient('cheese', 'dairy', {'dairy'}),
        ]);

        final result = generator.generate(
          ingredients: lookup,
          recipe: recipe,
          timeout: Duration.zero,
        );

        // Decision logs should be present
        expect(result.decisions, isNotNull);
        expect(result.decisions, isNotEmpty);

        // Should have dairy allergen decision
        final dairyDecision = result.decisions!.where(
          (d) => d.type == 'allergen' && d.key == 'mjölk',
        );
        expect(dairyDecision, isNotEmpty);
      });
    });

    group('H3: Decision audit trail on timeout', () {
      test('decisions explain allergen status even with timeout', () {
        final recipe = RecipeBuilder()
            .withTitle('Shellfish Recipe')
            .withIngredients(['shrimp', 'crab']).build();
        final lookup = TaggingTestHelper.createLookup([
          TaggingTestHelper.ingredient(
              'shrimp', 'protein/seafood', {'crustacean', 'seafood'}),
          TaggingTestHelper.ingredient(
              'crab', 'protein/seafood', {'crustacean', 'seafood'}),
        ]);

        final result = generator.generate(
          ingredients: lookup,
          recipe: recipe,
          timeout: Duration.zero,
        );

        // Find the shellfish (skaldjur) decision
        expect(result.decisions, isNotNull);
        final shellDecisions = result.decisions!.where(
          (d) => d.type == 'allergen' && d.key == 'skaldjur',
        );
        expect(shellDecisions, isNotEmpty);

        // Decision should explain why CONTAINS
        final decision = shellDecisions.first;
        expect(decision.result, TriState.contains);
        expect(decision.triggeringIngredients, isNotEmpty);
      });
    });
  });
}
