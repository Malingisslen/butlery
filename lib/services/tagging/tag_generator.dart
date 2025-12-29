import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_base.dart';
import 'package:butlery/services/tagging/phases/tag_phase2_derived.dart';
import 'package:butlery/services/tagging/phases/tag_phase3_complex.dart';
import 'package:butlery/services/tagging/phases/tag_phase4_mood.dart';
import 'package:butlery/services/tagging/phases/tag_phase5_cuisine.dart';

/// Generator version for tracking changes.
const String kTagGeneratorVersion = '1.0.0';

/// Orchestrates the 5-phase tag generation process.
///
/// Each phase depends on results from previous phases:
/// - Phase 1: Base tags from properties and metadata
/// - Phase 2: Simple derived tags
/// - Phase 3: Complex derived tags
/// - Phase 4: Mood and occasion tags
/// - Phase 5: Cuisine tags
class TagGenerator {
  final TagPhase1Base _phase1;
  final TagPhase2Derived _phase2;
  final TagPhase3Complex _phase3;
  final TagPhase4Mood _phase4;
  final TagPhase5Cuisine _phase5;

  TagGenerator({
    TagPhase1Base? phase1,
    TagPhase2Derived? phase2,
    TagPhase3Complex? phase3,
    TagPhase4Mood? phase4,
    TagPhase5Cuisine? phase5,
  })  : _phase1 = phase1 ?? TagPhase1Base(),
        _phase2 = phase2 ?? TagPhase2Derived(),
        _phase3 = phase3 ?? TagPhase3Complex(),
        _phase4 = phase4 ?? TagPhase4Mood(),
        _phase5 = phase5 ?? TagPhase5Cuisine();

  /// Generates tags for a recipe given its ingredient lookup result.
  ///
  /// Uses defensive error handling: if any phase fails, returns partial results
  /// from completed phases rather than failing entirely. This ensures recipes
  /// always get at least basic tagging even if advanced phases have issues.
  ///
  /// C3: If [timeout] is provided and elapsed time exceeds it after any phase,
  /// returns a partial result with `isPartial: true`. Phase 1 (allergens/dietary)
  /// always completes to ensure safety-critical tags are preserved.
  ///
  /// HIGH-7: Phase skip behavior (intentional asymmetry):
  /// - **Exception in phase**: Skip only that phase, continue to next phases.
  ///   Rationale: Exceptions may be phase-specific bugs; other phases may succeed.
  /// - **Timeout**: Skip ALL remaining phases immediately.
  ///   Rationale: Time is exhausted; return available results without delay.
  TagResult generate({
    required IngredientLookupResult ingredients,
    required Recipe recipe,
    Duration? timeout,
  }) {
    final stopwatch = timeout != null ? (Stopwatch()..start()) : null;

    Phase1Result? phase1Result;
    Phase2Result? phase2Result;
    Phase3Result? phase3Result;
    Phase4Result? phase4Result;
    Phase5Result? phase5Result;
    bool timedOut = false;

    // Phase 1: Base tags (critical - if this fails, return failed result)
    // Phase 1 ALWAYS completes (allergens/dietary are safety-critical)
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

    // C3: Check timeout after Phase 1
    if (_hasTimedOut(stopwatch, timeout)) {
      timedOut = true;
      AppLogger.debug(
        'Tag generation timeout after Phase 1 for recipe ${recipe.id}',
        'TagGenerator',
      );
    }

    // Phase 2: Simple derived (can continue without if fails)
    if (!timedOut) {
      try {
        phase2Result = _phase2.calculate(phase1Result, recipe);
      } catch (e) {
        AppLogger.warning(
          'Phase 2 tagging failed for recipe ${recipe.id}: $e, continuing with Phase 1 only',
          'TagGenerator',
        );
      }

      // C3: Check timeout after Phase 2
      if (_hasTimedOut(stopwatch, timeout)) {
        timedOut = true;
        AppLogger.debug(
          'Tag generation timeout after Phase 2 for recipe ${recipe.id}',
          'TagGenerator',
        );
      }
    }

    // Phase 3: Complex derived (needs Phase 2)
    if (!timedOut && phase2Result != null) {
      try {
        phase3Result = _phase3.calculate(phase1Result, phase2Result, recipe);
      } catch (e) {
        AppLogger.warning(
          'Phase 3 tagging failed for recipe ${recipe.id}: $e, continuing with Phases 1-2',
          'TagGenerator',
        );
      }

      // C3: Check timeout after Phase 3
      if (_hasTimedOut(stopwatch, timeout)) {
        timedOut = true;
        AppLogger.debug(
          'Tag generation timeout after Phase 3 for recipe ${recipe.id}',
          'TagGenerator',
        );
      }
    }

    // Phase 4: Mood/occasion (needs Phases 2 & 3)
    if (!timedOut && phase2Result != null && phase3Result != null) {
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

      // C3: Check timeout after Phase 4
      if (_hasTimedOut(stopwatch, timeout)) {
        timedOut = true;
        AppLogger.debug(
          'Tag generation timeout after Phase 4 for recipe ${recipe.id}',
          'TagGenerator',
        );
      }
    }

    // Phase 5: Cuisine tags (needs Phase 4)
    if (!timedOut && phase4Result != null) {
      try {
        phase5Result = _phase5.calculate(phase4Result, recipe);
      } catch (e) {
        AppLogger.warning(
          'Phase 5 tagging failed for recipe ${recipe.id}: $e, continuing with Phases 1-4',
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
      if (phase5Result != null) ...phase5Result.tags,
    };

    // C3: Mark as partial if timeout or if any phase was skipped
    final isPartial = timedOut ||
        phase2Result == null ||
        phase3Result == null ||
        phase4Result == null ||
        phase5Result == null;

    return TagResult(
      tags: allTags,
      allergenStatus: phase1Result.allergenStatus,
      dietaryStatus: phase1Result.dietaryStatus,
      coverage: ingredients.coverage,
      unknownIngredients: ingredients.unmatched,
      generatedAt: DateTime.now(),
      generatorVersion: kTagGeneratorVersion,
      isPartial: isPartial,
      // H3: Include decision logs from Phase 1
      decisions:
          phase1Result.decisions.isNotEmpty ? phase1Result.decisions : null,
    );
  }

  /// C3: Checks if the stopwatch has exceeded the timeout.
  bool _hasTimedOut(Stopwatch? stopwatch, Duration? timeout) {
    if (stopwatch == null || timeout == null) return false;
    return stopwatch.elapsed > timeout;
  }

  /// Generates only Phase 1 tags (for quick preview).
  /// C3: Always returns isPartial: true since only Phase 1 is included.
  ///
  /// HIGH-8: Optional [timeout] parameter for future-proofing. Note that
  /// Phase 1 is synchronous, so timeout is only checked AFTER calculation.
  /// For true timeout protection in async contexts, wrap the call in
  /// `Future.timeout()` at the caller level.
  TagResult generatePhase1Only({
    required IngredientLookupResult ingredients,
    required Recipe recipe,
    Duration? timeout,
  }) {
    final stopwatch = timeout != null ? (Stopwatch()..start()) : null;
    final phase1Result = _phase1.calculate(ingredients, recipe);

    // HIGH-8: Check timeout after calculation (can't interrupt sync code)
    final timedOut = _hasTimedOut(stopwatch, timeout);
    if (timedOut) {
      AppLogger.warning(
        'Phase 1 preview exceeded timeout (${stopwatch?.elapsedMilliseconds}ms)',
        'TagGenerator',
      );
    }

    return TagResult(
      tags: phase1Result.tags,
      allergenStatus: phase1Result.allergenStatus,
      dietaryStatus: phase1Result.dietaryStatus,
      coverage: ingredients.coverage,
      unknownIngredients: ingredients.unmatched,
      generatedAt: DateTime.now(),
      generatorVersion: '$kTagGeneratorVersion-phase1',
      isPartial: true, // C3: Phase 1 only is always partial
      // H3: Include decision logs from Phase 1
      decisions:
          phase1Result.decisions.isNotEmpty ? phase1Result.decisions : null,
    );
  }
}
