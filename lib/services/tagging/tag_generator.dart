import 'package:clock/clock.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/firebase_tag_config.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_base.dart';
import 'package:butlery/services/tagging/phases/tag_phase2_derived.dart';
import 'package:butlery/services/tagging/phases/tag_phase3_complex.dart';
import 'package:butlery/services/tagging/phases/tag_phase4_mood.dart';
import 'package:butlery/services/tagging/phases/tag_phase5_cuisine.dart';

/// Generator version for tracking changes.
/// Bump on any tagging logic change so needsRetagging detects stale recipes.
/// 2.2.0: seafood→skaldjur safety net + vegetarisk/vegansk/kosher exclusion
/// fixes + 87 register corrections (2026-07-02) — retag flushes stale
/// pre-fix verdicts. Known cost: global-cache hits re-tag client-side per
/// hit until entries age out (write-back blocked by cache-poisoning rules;
/// roadmap P1). Accepted: safety > cost at current scale.
const String kTagGeneratorVersion = '2.2.0';

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

  /// Creates a TagGenerator with optional Firebase-backed configuration.
  ///
  /// If [firebaseConfig] is provided, it will be used for allergen, dietary,
  /// and cuisine configurations. Otherwise, phases fall back to hardcoded
  /// static configs.
  TagGenerator({
    FirebaseTagConfig? firebaseConfig,
    TagPhase1Base? phase1,
    TagPhase2Derived? phase2,
    TagPhase3Complex? phase3,
    TagPhase4Mood? phase4,
    TagPhase5Cuisine? phase5,
  }) : _phase1 = phase1 ?? TagPhase1Base(firebaseConfig: firebaseConfig),
       _phase2 = phase2 ?? TagPhase2Derived(),
       _phase3 = phase3 ?? _createPhase3(),
       _phase4 = phase4 ?? _createPhase4(),
       _phase5 = phase5 ?? TagPhase5Cuisine(firebaseConfig: firebaseConfig);

  // BUT-553: per-phase accessors expose individual phase calculation to
  // `TaggingPipelineRunner` so each phase can be wrapped in its own
  // Future.timeout. Kept thin — orchestration logic lives in the runner.
  Phase1Result runPhase1(IngredientLookupResult lookup, Recipe recipe) =>
      _phase1.calculate(lookup, recipe);

  Phase2Result runPhase2(Phase1Result phase1, Recipe recipe) =>
      _phase2.calculate(phase1, recipe);

  Phase3Result runPhase3(
    Phase1Result phase1,
    Phase2Result phase2,
    Recipe recipe,
  ) => _phase3.calculate(phase1, phase2, recipe);

  Phase4Result runPhase4(
    Phase1Result phase1,
    Phase2Result phase2,
    Phase3Result phase3,
    Recipe recipe,
  ) => _phase4.calculate(phase1, phase2, phase3, recipe);

  Phase5Result runPhase5(Phase4Result phase4, Recipe recipe) =>
      _phase5.calculate(phase4, recipe);

  /// CRIT-7 fallback path — used by the runner when Phases 2-4 are
  /// unavailable but Phase 1 succeeded, so we can still surface cuisine tags.
  Phase5ResultPartial runPhase5FromPhase1(
    Phase1Result phase1,
    Recipe recipe,
  ) => _phase5.calculateFromPhase1(phase1, recipe);

  /// Combines per-phase results into a final TagResult. Mirrors the
  /// combination logic at the bottom of [generate], extracted so the
  /// per-phase runner can produce a result from any subset of phases.
  TagResult assembleResult({
    required IngredientLookupResult ingredients,
    required Recipe recipe,
    required Phase1Result phase1Result,
    Phase2Result? phase2Result,
    Phase3Result? phase3Result,
    Phase4Result? phase4Result,
    Phase5Result? phase5Result,
    Phase5ResultPartial? phase5PartialResult,
    required bool isPartial,
  }) {
    final allTags = <String>{
      ...phase1Result.tags,
      if (phase2Result != null) ...phase2Result.tags,
      if (phase3Result != null) ...phase3Result.tags,
      if (phase4Result != null) ...phase4Result.tags,
      if (phase5Result != null) ...phase5Result.tags,
      if (phase5PartialResult != null) ...phase5PartialResult.tags,
    };

    final resolvedTags = _resolveTagConflicts(allTags, recipe);
    final hasDraft = ingredients.matched.any((i) => i.status == 'draft');

    return TagResult(
      tags: resolvedTags,
      allergenStatus: phase1Result.allergenStatus,
      dietaryStatus: phase1Result.dietaryStatus,
      coverage: ingredients.coverage,
      unknownIngredients: ingredients.unmatched,
      generatedAt: clock.now(),
      generatorVersion: kTagGeneratorVersion,
      isPartial: isPartial,
      hasDraftIngredients: hasDraft,
      decisions: phase1Result.decisions.isNotEmpty
          ? phase1Result.decisions
          : null,
    );
  }

  static TagPhase3Complex _createPhase3() {
    final flags = ServiceLocator.tryGet<FeatureFlagService>();
    if (flags == null) return TagPhase3Complex();
    return TagPhase3Complex(
      easyMaxIngredients: flags.getInt(FeatureFlags.tagEasyMaxIngredients),
      easyMaxMinutes: flags.getInt(FeatureFlags.tagEasyMaxMinutes),
      advancedMinIngredients: flags.getInt(
        FeatureFlags.tagAdvancedMinIngredients,
      ),
      advancedMinMinutes: flags.getInt(FeatureFlags.tagAdvancedMinMinutes),
      highProteinRatio: flags.getDouble(FeatureFlags.tagHighProteinRatio),
      spiceRichCount: flags.getInt(FeatureFlags.tagSpiceRichCount),
      veggieRichCount: flags.getInt(FeatureFlags.tagVeggieRichCount),
    );
  }

  static TagPhase4Mood _createPhase4() {
    final flags = ServiceLocator.tryGet<FeatureFlagService>();
    if (flags == null) return TagPhase4Mood();
    return TagPhase4Mood(
      seasonThreshold: flags.getInt(FeatureFlags.tagSeasonThreshold),
    );
  }

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

    // Phase 5: Cuisine tags
    // CRIT-7: Phase 5 can run with Phase 1 fallback if Phases 2-4 failed
    Phase5ResultPartial? phase5PartialResult;
    if (!timedOut && phase4Result != null) {
      // Full chain available - use normal calculation
      try {
        phase5Result = _phase5.calculate(phase4Result, recipe);
      } catch (e) {
        AppLogger.warning(
          'Phase 5 tagging failed for recipe ${recipe.id}: $e, continuing with Phases 1-4',
          'TagGenerator',
        );
      }
    } else if (!timedOut && phase4Result == null) {
      // CRIT-7 FIX: Phases 2-4 failed but we can still get cuisine tags
      // Phase 5 only needs Phase 1's ingredient lookup
      try {
        phase5PartialResult = _phase5.calculateFromPhase1(phase1Result, recipe);
        AppLogger.debug(
          'Phase 5 using Phase 1 fallback for recipe ${recipe.id}',
          'TagGenerator',
        );
      } catch (e) {
        AppLogger.warning(
          'Phase 5 fallback tagging failed for recipe ${recipe.id}: $e',
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
      if (phase5PartialResult != null) ...phase5PartialResult.tags,
    };

    // MED-5: Resolve conflicting tags (e.g., stark vs mild)
    final resolvedTags = _resolveTagConflicts(allTags, recipe);

    // C3: Mark as partial if timeout or if any phase was skipped
    // CRIT-7: Phase 5 partial result counts as having cuisine tags
    final hasPhase5Tags = phase5Result != null || phase5PartialResult != null;
    final isPartial =
        timedOut ||
        phase2Result == null ||
        phase3Result == null ||
        phase4Result == null ||
        !hasPhase5Tags;

    // Check for draft ingredients (AI-generated, unvalidated data)
    final hasDraft = ingredients.matched.any((i) => i.status == 'draft');

    return TagResult(
      tags: resolvedTags,
      allergenStatus: phase1Result.allergenStatus,
      dietaryStatus: phase1Result.dietaryStatus,
      coverage: ingredients.coverage,
      unknownIngredients: ingredients.unmatched,
      generatedAt: clock.now(),
      generatorVersion: kTagGeneratorVersion,
      isPartial: isPartial,
      hasDraftIngredients: hasDraft,
      // H3: Include decision logs from Phase 1
      decisions: phase1Result.decisions.isNotEmpty
          ? phase1Result.decisions
          : null,
    );
  }

  /// C3: Checks if the stopwatch has exceeded the timeout.
  bool _hasTimedOut(Stopwatch? stopwatch, Duration? timeout) {
    if (stopwatch == null || timeout == null) return false;
    return stopwatch.elapsed > timeout;
  }

  /// MED-5: Resolves conflicting tags by keeping the more specific/safer one.
  ///
  /// Conflicts are resolved with a safety-first approach:
  /// - 'stark' wins over 'mild' (safer to warn about spiciness)
  /// - 'avancerad' wins over 'enkel' (safer to warn about difficulty)
  /// - 'varm-rätt' wins over 'kall-rätt' (mutually exclusive, warm is more common)
  /// Season tags are NOT mutually exclusive: recipes can span multiple seasons
  /// when ingredients have multi-season seasonAvailability data.
  Set<String> _resolveTagConflicts(Set<String> tags, Recipe recipe) {
    final resolved = Set<String>.from(tags);

    // Define conflicting pairs: key wins over value
    const conflicts = {
      'stark': 'mild', // If both, keep 'stark' (safety: warn about spicy)
      'avancerad':
          'enkel', // If both, keep 'avancerad' (safety: warn difficulty)
      'varm-rätt': 'kall-rätt', // CRIT-9: Mutually exclusive temperature tags
    };

    for (final entry in conflicts.entries) {
      if (resolved.contains(entry.key) && resolved.contains(entry.value)) {
        resolved.remove(entry.value);
        AppLogger.debug(
          'Tag conflict resolved: removed "${entry.value}" in favor of "${entry.key}"',
          'TagGenerator',
        );
      }
    }

    return resolved;
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
      generatedAt: clock.now(),
      generatorVersion: '$kTagGeneratorVersion-phase1',
      isPartial: true, // C3: Phase 1 only is always partial
      // H3: Include decision logs from Phase 1
      decisions: phase1Result.decisions.isNotEmpty
          ? phase1Result.decisions
          : null,
    );
  }
}
