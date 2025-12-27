import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_base.dart';
import 'package:butlery/services/tagging/phases/tag_phase2_derived.dart';
import 'package:butlery/services/tagging/phases/tag_phase3_complex.dart';
import 'package:butlery/services/tagging/phases/tag_phase4_mood.dart';

/// Generator version for tracking changes.
const String kTagGeneratorVersion = '1.0.0';

/// Orchestrates the 4-phase tag generation process.
///
/// Each phase depends on results from previous phases:
/// - Phase 1: Base tags from properties and metadata
/// - Phase 2: Simple derived tags
/// - Phase 3: Complex derived tags
/// - Phase 4: Mood and occasion tags
class TagGenerator {
  final TagPhase1Base _phase1;
  final TagPhase2Derived _phase2;
  final TagPhase3Complex _phase3;
  final TagPhase4Mood _phase4;

  TagGenerator({
    TagPhase1Base? phase1,
    TagPhase2Derived? phase2,
    TagPhase3Complex? phase3,
    TagPhase4Mood? phase4,
  })  : _phase1 = phase1 ?? TagPhase1Base(),
        _phase2 = phase2 ?? TagPhase2Derived(),
        _phase3 = phase3 ?? TagPhase3Complex(),
        _phase4 = phase4 ?? TagPhase4Mood();

  /// Generates tags for a recipe given its ingredient lookup result.
  TagResult generate({
    required IngredientLookupResult ingredients,
    required Recipe recipe,
  }) {
    // Phase 1: Base tags
    final phase1Result = _phase1.calculate(ingredients, recipe);

    // Phase 2: Simple derived
    final phase2Result = _phase2.calculate(phase1Result, recipe);

    // Phase 3: Complex derived
    final phase3Result = _phase3.calculate(phase1Result, phase2Result, recipe);

    // Phase 4: Mood/occasion
    final phase4Result = _phase4.calculate(
      phase1Result,
      phase2Result,
      phase3Result,
      recipe,
    );

    // Combine all results
    return TagResult(
      tags: phase4Result.allTags,
      allergenStatus: phase1Result.allergenStatus,
      dietaryStatus: phase1Result.dietaryStatus,
      coverage: ingredients.coverage,
      unknownIngredients: ingredients.unmatched,
      generatedAt: DateTime.now(),
      generatorVersion: kTagGeneratorVersion,
    );
  }

  /// Generates only Phase 1 tags (for quick preview).
  TagResult generatePhase1Only({
    required IngredientLookupResult ingredients,
    required Recipe recipe,
  }) {
    final phase1Result = _phase1.calculate(ingredients, recipe);

    return TagResult(
      tags: phase1Result.tags,
      allergenStatus: phase1Result.allergenStatus,
      dietaryStatus: phase1Result.dietaryStatus,
      coverage: ingredients.coverage,
      unknownIngredients: ingredients.unmatched,
      generatedAt: DateTime.now(),
      generatorVersion: '$kTagGeneratorVersion-phase1',
    );
  }
}
