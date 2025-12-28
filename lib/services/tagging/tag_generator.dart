import 'package:butlery/core/utils/logger.dart';
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
  ///
  /// Uses defensive error handling: if any phase fails, returns partial results
  /// from completed phases rather than failing entirely. This ensures recipes
  /// always get at least basic tagging even if advanced phases have issues.
  TagResult generate({
    required IngredientLookupResult ingredients,
    required Recipe recipe,
  }) {
    Phase1Result? phase1Result;
    Phase2Result? phase2Result;
    Phase3Result? phase3Result;
    Phase4Result? phase4Result;

    // Phase 1: Base tags (critical - if this fails, return failed result)
    try {
      phase1Result = _phase1.calculate(ingredients, recipe);
    } catch (e, stack) {
      AppLogger.error(
        'Phase 1 tagging failed for recipe ${recipe.id}',
        e,
        'TagGenerator',
        stack,
      );
      return TagResult.failed(reason: 'Phase 1 error: $e');
    }

    // Phase 2: Simple derived (can continue without if fails)
    try {
      phase2Result = _phase2.calculate(phase1Result, recipe);
    } catch (e) {
      AppLogger.warning(
        'Phase 2 tagging failed for recipe ${recipe.id}: $e, continuing with Phase 1 only',
        'TagGenerator',
      );
    }

    // Phase 3: Complex derived (needs Phase 2)
    if (phase2Result != null) {
      try {
        phase3Result = _phase3.calculate(phase1Result, phase2Result, recipe);
      } catch (e) {
        AppLogger.warning(
          'Phase 3 tagging failed for recipe ${recipe.id}: $e, continuing with Phases 1-2',
          'TagGenerator',
        );
      }
    }

    // Phase 4: Mood/occasion (needs Phases 2 & 3)
    if (phase2Result != null && phase3Result != null) {
      try {
        phase4Result = _phase4.calculate(
          phase1Result,
          phase2Result,
          phase3Result,
          recipe,
        );
      } catch (e) {
        AppLogger.warning(
          'Phase 4 tagging failed for recipe ${recipe.id}: $e, continuing with Phases 1-3',
          'TagGenerator',
        );
      }
    }

    // Combine results from all completed phases
    final allTags = <String>{
      ...phase1Result.tags,
      if (phase2Result != null) ...phase2Result.tags,
      if (phase3Result != null) ...phase3Result.tags,
      if (phase4Result != null) ...phase4Result.tags,
    };

    return TagResult(
      tags: allTags,
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
