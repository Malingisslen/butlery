import 'dart:async';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/config/allergen_config.dart';
import 'package:butlery/services/tagging/config/dietary_config.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_base.dart';
import 'package:butlery/services/tagging/phases/tag_phase2_derived.dart';
import 'package:butlery/services/tagging/phases/tag_phase3_complex.dart';
import 'package:butlery/services/tagging/phases/tag_phase4_mood.dart';
import 'package:butlery/services/tagging/phases/tag_phase5_cuisine.dart';
import 'package:butlery/services/tagging/tag_generator.dart';
import 'package:butlery/services/tagging/tagging_phase_budgets.dart';
import 'package:clock/clock.dart';

/// Outcome of a single phase invocation. Used by the runner's structured
/// log emit and (in tests) to assert which phases timed out.
class TaggingPhaseOutcome {
  final String phaseName;
  final int phaseIndex;
  final int elapsedMs;
  final int budgetMs;

  /// One of: `'ok'`, `'timeout'`, `'error'`.
  final String result;

  /// Class name of the thrown error (only set when [result] == `'error'`).
  final String? errorClass;

  const TaggingPhaseOutcome({
    required this.phaseName,
    required this.phaseIndex,
    required this.elapsedMs,
    required this.budgetMs,
    required this.result,
    this.errorClass,
  });

  Map<String, Object?> toLogMap() => {
        'phase_index': phaseIndex,
        'phase_name': phaseName,
        'elapsed_ms': elapsedMs,
        'budget_ms': budgetMs,
        'result': result,
        if (errorClass != null) 'error_class': errorClass,
      };
}

/// Result bundle returned by [TaggingPipelineRunner.run].
///
/// Exposes both the final [TagResult] (what callers consume) and the
/// per-phase [outcomes] list (what tests assert on, what observability
/// can scrape later). Outcomes are emitted to AppLogger in real time;
/// the list is a captured trace for the same events.
class TaggingPipelineResult {
  final TagResult tagResult;
  final List<TaggingPhaseOutcome> outcomes;

  const TaggingPipelineResult({
    required this.tagResult,
    required this.outcomes,
  });
}

/// Bundle of injectable phase callables. Tests pass custom Future-returning
/// implementations to simulate hangs; production passes the
/// [_defaultPhaseCallables] which delegate to [TagGenerator].
///
/// Why phase-level injection (rather than mocking [TagGenerator] directly):
/// the per-phase methods on [TagGenerator] are sync, so wrapping them as
/// `Future(() => sync())` always completes after one microtask — there is
/// no way for a mock-of-sync to "hang." Tests need to substitute a
/// `Future.delayed(...)` directly. Passing callables here keeps that
/// substitution clean without polluting the production happy-path.
class TaggingPhaseCallables {
  final Future<IngredientLookupResult> Function(
    List<String> ingredients,
    String? userId,
  ) lookup;
  final Future<Phase1Result> Function(
    IngredientLookupResult,
    Recipe,
  ) phase1;
  final Future<Phase2Result> Function(Phase1Result, Recipe) phase2;
  final Future<Phase3Result> Function(
    Phase1Result,
    Phase2Result,
    Recipe,
  ) phase3;
  final Future<Phase4Result> Function(
    Phase1Result,
    Phase2Result,
    Phase3Result,
    Recipe,
  ) phase4;
  final Future<Phase5Result> Function(Phase4Result, Recipe) phase5;
  final Future<Phase5ResultPartial> Function(
    Phase1Result,
    Recipe,
  ) phase5FromPhase1;

  const TaggingPhaseCallables({
    required this.lookup,
    required this.phase1,
    required this.phase2,
    required this.phase3,
    required this.phase4,
    required this.phase5,
    required this.phase5FromPhase1,
  });
}

TaggingPhaseCallables _defaultPhaseCallables(
  IngredientLookupService lookupService,
  TagGenerator generator,
) {
  return TaggingPhaseCallables(
    lookup: (ingredients, userId) =>
        lookupService.lookupFromRaw(ingredients, userId: userId),
    phase1: (lookup, recipe) =>
        Future<Phase1Result>(() => generator.runPhase1(lookup, recipe)),
    phase2: (p1, recipe) =>
        Future<Phase2Result>(() => generator.runPhase2(p1, recipe)),
    phase3: (p1, p2, recipe) =>
        Future<Phase3Result>(() => generator.runPhase3(p1, p2, recipe)),
    phase4: (p1, p2, p3, recipe) =>
        Future<Phase4Result>(() => generator.runPhase4(p1, p2, p3, recipe)),
    phase5: (p4, recipe) =>
        Future<Phase5Result>(() => generator.runPhase5(p4, recipe)),
    phase5FromPhase1: (p1, recipe) => Future<Phase5ResultPartial>(
        () => generator.runPhase5FromPhase1(p1, recipe)),
  );
}

/// BUT-553 — Runs the 6-phase tagging pipeline (lookup + Phase 1..5) with
/// independent per-phase timeout budgets and graceful degradation.
///
/// Replaces the previous single 30s wrapper-timeout that, when Phase 3
/// hung, caused the whole pipeline to abandon and fall back to
/// `generatePhase1Only`. The runner continues past any timed-out or
/// erroring phase using the most recent successful intermediate result
/// as input — so a Phase 2 hang no longer starves Phases 3-5.
///
/// Public contract:
/// - Each phase wrapped in its own `Future.timeout(budget)`.
/// - On timeout or non-timeout exception: structured log emitted, runner
///   continues with last-good intermediate result.
/// - Phase 1 floor: if Phase 1 itself fails (timeout OR exception), the
///   runner returns `TagResult.failed` — there is no usable result below
///   Phase 1 (no allergen/dietary status, no safe tagging).
/// - Lookup floor: if the lookup phase fails entirely, runner returns
///   the existing safe-defaults result (`timeout-warning` tag, all
///   allergens UNKNOWN).
class TaggingPipelineRunner {
  final TagGenerator _generator;

  /// When non-null, called for every phase outcome (alongside the
  /// AppLogger emit). Test seam — production code leaves this null.
  final void Function(TaggingPhaseOutcome)? onPhaseOutcome;

  /// Phase implementations. Production gets [_defaultPhaseCallables];
  /// tests inject hang-simulating Futures.
  final TaggingPhaseCallables _phases;

  TaggingPipelineRunner({
    required IngredientLookupService lookupService,
    required TagGenerator generator,
    TaggingPhaseCallables? phaseCallables,
    this.onPhaseOutcome,
  })  : _generator = generator,
        _phases =
            phaseCallables ?? _defaultPhaseCallables(lookupService, generator);

  /// Test-only constructor: injects [TaggingPhaseCallables] without
  /// requiring a real lookup service. The generator is still required for
  /// `assembleResult` (which combines phase results into a TagResult).
  TaggingPipelineRunner.forTesting({
    required TagGenerator generator,
    required TaggingPhaseCallables phaseCallables,
    this.onPhaseOutcome,
  })  : _generator = generator,
        _phases = phaseCallables;

  /// Runs the full pipeline. [userId] is forwarded to the lookup service
  /// for user-defined ingredient resolution.
  Future<TaggingPipelineResult> run({
    required Recipe recipe,
    required List<String> ingredients,
    String? userId,
  }) async {
    final outcomes = <TaggingPhaseOutcome>[];

    // Phase 0 — lookup (the Firestore-bound phase the ticket calls "P2").
    final lookupExec = await _runAsync<IngredientLookupResult>(
      phaseIndex: 0,
      phaseName: 'lookup',
      budget: kLookupBudget,
      work: () => _phases.lookup(ingredients, userId),
    );
    outcomes.add(lookupExec.outcome);
    final lookupResult = lookupExec.value;

    if (lookupResult == null) {
      // Lookup floor — match legacy CRIT-4 behaviour.
      return TaggingPipelineResult(
        tagResult: _lookupFloorResult(ingredients, lookupExec.outcome),
        outcomes: outcomes,
      );
    }

    // Edge case: every ingredient unknown. Same shape as legacy service:
    // return `TagResult.allUnknown` without running any phase.
    if (lookupResult.matched.isEmpty && lookupResult.unmatched.isNotEmpty) {
      return TaggingPipelineResult(
        tagResult: TagResult.allUnknown(lookupResult.unmatched),
        outcomes: outcomes,
      );
    }

    // Phase 1 — base tags (FLOOR — allergen/dietary safety).
    final phase1Exec = await _runAsync<Phase1Result>(
      phaseIndex: 1,
      phaseName: 'phase1_base',
      budget: kPhase1Budget,
      work: () => _phases.phase1(lookupResult, recipe),
    );
    outcomes.add(phase1Exec.outcome);
    final phase1 = phase1Exec.value;

    if (phase1 == null) {
      // Phase 1 floor: no usable allergen/dietary status. Match legacy
      // `TagResult.failed` behaviour from `TagGenerator.generate`.
      return TaggingPipelineResult(
        tagResult: TagResult.failed(
          reason: 'Phase 1 ${phase1Exec.outcome.result}',
        ),
        outcomes: outcomes,
      );
    }

    // Phase 2.
    final phase2Exec = await _runAsync<Phase2Result>(
      phaseIndex: 2,
      phaseName: 'phase2_derived',
      budget: kPhase2Budget,
      work: () => _phases.phase2(phase1, recipe),
    );
    outcomes.add(phase2Exec.outcome);
    final phase2 = phase2Exec.value;
    // Graceful degradation: if Phase 2 failed, downstream phases still
    // get a usable upstream — an empty Phase 2 wrapping the real Phase 1.
    // Tags from Phase 1 are still discoverable via `phase2.hasTag(...)`
    // delegation. This is what BUT-553 calls "Phase 3-5 run with the
    // Phase-1 result as input."
    final phase2OrEmpty =
        phase2 ?? Phase2Result(tags: const {}, phase1: phase1);

    // Phase 3.
    final phase3Exec = await _runAsync<Phase3Result>(
      phaseIndex: 3,
      phaseName: 'phase3_complex',
      budget: kPhase3Budget,
      work: () => _phases.phase3(phase1, phase2OrEmpty, recipe),
    );
    outcomes.add(phase3Exec.outcome);
    final phase3 = phase3Exec.value;
    final phase3OrEmpty = phase3 ??
        Phase3Result(
          tags: const {},
          phase1: phase1,
          phase2: phase2OrEmpty,
        );

    // Phase 4.
    final phase4Exec = await _runAsync<Phase4Result>(
      phaseIndex: 4,
      phaseName: 'phase4_mood',
      budget: kPhase4Budget,
      work: () => _phases.phase4(phase1, phase2OrEmpty, phase3OrEmpty, recipe),
    );
    outcomes.add(phase4Exec.outcome);
    final phase4 = phase4Exec.value;

    // Phase 5 — two paths, matching legacy CRIT-7:
    //   - Full chain (Phases 2..4 all real) → cuisine from phase4
    //   - Phase-1 fallback (any of 2..4 failed) → cuisine from phase1
    Phase5Result? phase5;
    Phase5ResultPartial? phase5Partial;
    if (phase2 != null && phase3 != null && phase4 != null) {
      final phase5Exec = await _runAsync<Phase5Result>(
        phaseIndex: 5,
        phaseName: 'phase5_cuisine',
        budget: kPhase5Budget,
        work: () => _phases.phase5(phase4, recipe),
      );
      outcomes.add(phase5Exec.outcome);
      phase5 = phase5Exec.value;
    } else {
      final phase5Exec = await _runAsync<Phase5ResultPartial>(
        phaseIndex: 5,
        phaseName: 'phase5_cuisine_from_phase1',
        budget: kPhase5Budget,
        work: () => _phases.phase5FromPhase1(phase1, recipe),
      );
      outcomes.add(phase5Exec.outcome);
      phase5Partial = phase5Exec.value;
    }

    // Anything missing → result is partial. Mirrors the legacy isPartial
    // bookkeeping at the bottom of TagGenerator.generate.
    final hasPhase5Tags = phase5 != null || phase5Partial != null;
    final isPartial =
        phase2 == null || phase3 == null || phase4 == null || !hasPhase5Tags;

    final tagResult = _generator.assembleResult(
      ingredients: lookupResult,
      recipe: recipe,
      phase1Result: phase1,
      phase2Result: phase2,
      phase3Result: phase3,
      phase4Result: phase4,
      phase5Result: phase5,
      phase5PartialResult: phase5Partial,
      isPartial: isPartial,
    );

    return TaggingPipelineResult(tagResult: tagResult, outcomes: outcomes);
  }

  /// Wraps an async operation in `Future.timeout(budget)` with structured
  /// outcome reporting. Used for the lookup phase.
  Future<_PhaseExecution<T>> _runAsync<T>({
    required int phaseIndex,
    required String phaseName,
    required Duration budget,
    required Future<T> Function() work,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final value = await work().timeout(budget);
      stopwatch.stop();
      final outcome = TaggingPhaseOutcome(
        phaseName: phaseName,
        phaseIndex: phaseIndex,
        elapsedMs: stopwatch.elapsedMilliseconds,
        budgetMs: budget.inMilliseconds,
        result: 'ok',
      );
      _emit(outcome);
      return _PhaseExecution<T>(value: value, outcome: outcome);
    } on TimeoutException {
      stopwatch.stop();
      final outcome = TaggingPhaseOutcome(
        phaseName: phaseName,
        phaseIndex: phaseIndex,
        elapsedMs: stopwatch.elapsedMilliseconds,
        budgetMs: budget.inMilliseconds,
        result: 'timeout',
      );
      _emit(outcome);
      return _PhaseExecution<T>(value: null, outcome: outcome);
    } catch (e) {
      stopwatch.stop();
      final outcome = TaggingPhaseOutcome(
        phaseName: phaseName,
        phaseIndex: phaseIndex,
        elapsedMs: stopwatch.elapsedMilliseconds,
        budgetMs: budget.inMilliseconds,
        result: 'error',
        errorClass: e.runtimeType.toString(),
      );
      _emit(outcome);
      return _PhaseExecution<T>(value: null, outcome: outcome);
    }
  }

  void _emit(TaggingPhaseOutcome outcome) {
    // Structured single-line log so the JSON-ish payload is grep-able in
    // log aggregators. Severity reflects outcome: ok→debug, timeout/error
    // →warning.
    final payload = outcome.toLogMap();
    switch (outcome.result) {
      case 'ok':
        AppLogger.debug('TaggingPipeline phase: $payload', 'TaggingPipeline');
        break;
      case 'timeout':
      case 'error':
      default:
        AppLogger.warning(
          'TaggingPipeline phase budget breached: $payload',
          'TaggingPipeline',
        );
    }
    onPhaseOutcome?.call(outcome);
  }

  TagResult _lookupFloorResult(
    List<String> ingredients,
    TaggingPhaseOutcome outcome,
  ) {
    return TagResult(
      tags: const {'timeout-warning'},
      allergenStatus: {
        for (final k in AllergenConfig.allKeys) k: TriState.unknown,
      },
      dietaryStatus: {
        for (final k in DietaryConfig.allKeys) k: TriState.unknown,
      },
      coverage: 0.0,
      unknownIngredients: ingredients,
      generatedAt: clock.now(),
      generatorVersion: 'lookup_${outcome.result}',
      isPartial: true,
      errorReason: 'Ingredient lookup ${outcome.result} '
          '(elapsed=${outcome.elapsedMs}ms / budget=${outcome.budgetMs}ms)',
    );
  }
}

/// Internal "either value or null + recorded outcome" used by phase wrappers.
class _PhaseExecution<T> {
  final T? value;
  final TaggingPhaseOutcome outcome;
  const _PhaseExecution({required this.value, required this.outcome});
}
