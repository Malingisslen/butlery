// BUT-553 — Per-phase budget tests for [TaggingPipelineRunner].
//
// Behaviours under test (one assertion focus per group):
//   1. Phase 2 hang → Phase 1 captured, Phase 2 times out, Phases 3-5 still
//      run with the Phase-1 result as input.
//   2. Phase 3 hang → Phases 1+2 captured, Phase 3 times out, Phases 4-5
//      still run.
//   3. Phase 5 hang → Phases 1-4 captured, Phase 5 times out, structured
//      log emitted, final TagResult contains tags from Phases 1-4.
//   4. Phase 1 hang → floor case kicks in, returns TagResult.failed.
//   5. Happy path → no regression vs the legacy single-wrapper timeout.
//
// Mocking strategy: we mock the **phase callables** (not the runner) by
// passing a custom [TaggingPhaseCallables] bundle. This lets us simulate
// hangs as `Future.delayed(...)` — which the runner's `Future.timeout()`
// can actually trip. fakeAsync is used to advance simulated time without
// real wall-clock waits.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_base.dart';
import 'package:butlery/services/tagging/phases/tag_phase2_derived.dart';
import 'package:butlery/services/tagging/phases/tag_phase3_complex.dart';
import 'package:butlery/services/tagging/phases/tag_phase4_mood.dart';
import 'package:butlery/services/tagging/phases/tag_phase5_cuisine.dart';
import 'package:butlery/services/tagging/tag_generator.dart';
import 'package:butlery/services/tagging/tagging_pipeline_runner.dart';

import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../infrastructure/helpers/tagging_test_helper.dart';

void main() {
  late Recipe recipe;
  late IngredientLookupResult lookupResult;
  late TagGenerator generator;

  setUp(() {
    recipe = RecipeBuilder()
        .withTitle('Test Recipe')
        .withTimeMinutes(30)
        .withIngredients(['rice', 'chicken'])
        .build();
    lookupResult = TaggingTestHelper.createLookup([
      TaggingTestHelper.ingredient('rice', 'grain', const {}),
      TaggingTestHelper.ingredient('chicken', 'protein/meat/poultry', const {
        'meat',
        'poultry',
      }),
    ]);
    // Real generator — phase combination logic (assembleResult) is part
    // of the contract we want to verify, not mocked away.
    generator = TagGenerator();
  });

  // ---- Test fixtures --------------------------------------------------

  /// Builds a callables bundle where every phase succeeds with a minimal
  /// result. Tests override individual phases to simulate hangs/errors.
  TaggingPhaseCallables buildCallables({
    Future<IngredientLookupResult> Function(List<String>, String?)? lookup,
    Future<Phase1Result> Function(IngredientLookupResult, Recipe)? phase1,
    Future<Phase2Result> Function(Phase1Result, Recipe)? phase2,
    Future<Phase3Result> Function(Phase1Result, Phase2Result, Recipe)? phase3,
    Future<Phase4Result> Function(
      Phase1Result,
      Phase2Result,
      Phase3Result,
      Recipe,
    )?
    phase4,
    Future<Phase5Result> Function(Phase4Result, Recipe)? phase5,
    Future<Phase5ResultPartial> Function(Phase1Result, Recipe)? phase5FromP1,
  }) {
    return TaggingPhaseCallables(
      lookup: lookup ?? (_, __) async => lookupResult,
      phase1:
          phase1 ??
          (lk, r) async => Phase1Result(
            tags: const {'p1-tag', 'under-30-min'},
            allergenStatus: const {},
            dietaryStatus: const {},
            lookup: lk,
          ),
      phase2:
          phase2 ??
          (p1, r) async => Phase2Result(
            tags: const {'p2-tag'},
            phase1: p1,
          ),
      phase3:
          phase3 ??
          (p1, p2, r) async => Phase3Result(
            tags: const {'p3-tag'},
            phase1: p1,
            phase2: p2,
          ),
      phase4:
          phase4 ??
          (p1, p2, p3, r) async => Phase4Result(
            tags: const {'p4-tag'},
            phase1: p1,
            phase2: p2,
            phase3: p3,
          ),
      phase5:
          phase5 ??
          (p4, r) async => Phase5Result(
            tags: const {'p5-tag'},
            phase4: p4,
          ),
      phase5FromPhase1:
          phase5FromP1 ??
          (p1, r) async => Phase5ResultPartial(
            tags: const {'p5-fallback-tag'},
            phase1: p1,
          ),
    );
  }

  TaggingPipelineRunner buildRunner(TaggingPhaseCallables callables) {
    return TaggingPipelineRunner.forTesting(
      generator: generator,
      phaseCallables: callables,
    );
  }

  /// Advances fake time enough for any pending phase Future + the
  /// timeout machinery to settle. 60s is well over any single budget.
  void drain(FakeAsync async) {
    async.elapse(const Duration(seconds: 60));
    async.flushMicrotasks();
  }

  // ---- Mandatory targeted test ----------------------------------------

  group('BUT-553: Phase 2 hang (the targeted scenario)', () {
    test(
      'Phase 2 hang times out, Phases 3-5 still run with Phase-1 result',
      () {
        fakeAsync((async) {
          // Phase 2 returns a Future that completes after 1 hour — well past
          // its 5s budget. Other phases use the default (success).
          final callables = buildCallables(
            phase2: (p1, r) => Future.delayed(
              const Duration(hours: 1),
              () => Phase2Result(
                tags: const {'never-emitted'},
                phase1: p1,
              ),
            ),
          );
          final runner = buildRunner(callables);

          TaggingPipelineResult? result;
          runner
              .run(recipe: recipe, ingredients: ['rice', 'chicken'])
              .then((r) => result = r);

          drain(async);
          expect(result, isNotNull, reason: 'pipeline should complete');

          // Outcomes ordered by phase index: lookup (0), p1, p2, p3, p4, p5.
          final outcomes = result!.outcomes;
          final byIndex = {for (final o in outcomes) o.phaseIndex: o};

          // 1) Phase 1 captured.
          expect(
            byIndex[1]!.result,
            'ok',
            reason: 'Phase 1 should have run successfully',
          );

          // 2) Phase 2 timed out at the 5s budget.
          expect(
            byIndex[2]!.result,
            'timeout',
            reason: 'Phase 2 should hit its 5s budget',
          );
          expect(byIndex[2]!.budgetMs, 5000);

          // 3) Phase 3, 4, 5 ran (using Phase-1 as input via empty Phase-2).
          expect(
            byIndex[3]!.result,
            'ok',
            reason: 'Phase 3 should run despite Phase 2 timeout',
          );
          expect(byIndex[4]!.result, 'ok');
          expect(byIndex[5]!.result, 'ok');

          // 4) Final TagResult contains contributions from Phases 1, 3, 4, 5.
          // The Phase-1-fallback path is taken for Phase 5 (because
          // Phase 2 didn't really run), so the cuisine tag is the
          // p5-fallback variant.
          final tags = result!.tagResult.tags;
          expect(
            tags,
            contains('p1-tag'),
            reason: 'Phase 1 contribution preserved',
          );
          expect(
            tags,
            contains('p3-tag'),
            reason: 'Phase 3 ran with Phase-1 result',
          );
          expect(
            tags,
            contains('p4-tag'),
            reason: 'Phase 4 ran with Phase-1 result',
          );
          expect(
            tags,
            contains('p5-fallback-tag'),
            reason: 'Phase 5 took the Phase-1-fallback path',
          );
          expect(
            tags,
            isNot(contains('p2-tag')),
            reason: 'Phase 2 hang means no Phase-2 tags',
          );
          expect(
            tags,
            isNot(contains('never-emitted')),
            reason: 'Hung Phase 2 must not contribute tags',
          );

          // 5) Result marked partial — Phase 2 missing.
          expect(result!.tagResult.isPartial, isTrue);
        });
      },
    );
  });

  // ---- Bonus tests (4 of them — happy path + 3 phase hangs) -----------

  group('BUT-553: Phase 3 hang', () {
    test('Phases 4-5 still run when Phase 3 times out', () {
      fakeAsync((async) {
        final callables = buildCallables(
          phase3: (p1, p2, r) => Future.delayed(
            const Duration(hours: 1),
            () => Phase3Result(
              tags: const {'never-p3'},
              phase1: p1,
              phase2: p2,
            ),
          ),
        );
        final runner = buildRunner(callables);

        TaggingPipelineResult? result;
        runner
            .run(recipe: recipe, ingredients: ['rice', 'chicken'])
            .then((r) => result = r);
        drain(async);

        final byIndex = {for (final o in result!.outcomes) o.phaseIndex: o};
        expect(byIndex[1]!.result, 'ok');
        expect(byIndex[2]!.result, 'ok');
        expect(byIndex[3]!.result, 'timeout');
        expect(byIndex[3]!.budgetMs, 10000);
        expect(
          byIndex[4]!.result,
          'ok',
          reason: 'Phase 4 should run despite Phase 3 timeout',
        );
        expect(byIndex[5]!.result, 'ok');

        final tags = result!.tagResult.tags;
        expect(tags, containsAll({'p1-tag', 'p2-tag', 'p4-tag'}));
        // Phase 5 takes the Phase-1-fallback path because Phase 3 didn't run.
        expect(tags, contains('p5-fallback-tag'));
        expect(tags, isNot(contains('never-p3')));
        expect(result!.tagResult.isPartial, isTrue);
      });
    });
  });

  group('BUT-553: Phase 5 hang', () {
    test('Phases 1-4 contributions preserved + structured log emitted', () {
      fakeAsync((async) {
        final logged = <TaggingPhaseOutcome>[];
        final callables = buildCallables(
          phase5: (p4, r) => Future.delayed(
            const Duration(hours: 1),
            () => Phase5Result(
              tags: const {'never-p5'},
              phase4: p4,
            ),
          ),
        );
        final runner = TaggingPipelineRunner.forTesting(
          generator: generator,
          phaseCallables: callables,
          onPhaseOutcome: logged.add,
        );

        TaggingPipelineResult? result;
        runner
            .run(recipe: recipe, ingredients: ['rice', 'chicken'])
            .then((r) => result = r);
        drain(async);

        final byIndex = {for (final o in result!.outcomes) o.phaseIndex: o};
        expect(byIndex[5]!.result, 'timeout');
        expect(byIndex[5]!.phaseName, 'phase5_cuisine');
        expect(byIndex[5]!.budgetMs, 8000);

        // Structured log was emitted for the Phase 5 timeout (and for
        // every other phase too — onPhaseOutcome captures all of them).
        final phase5Log = logged.singleWhere((o) => o.phaseIndex == 5);
        expect(phase5Log.result, 'timeout');
        expect(phase5Log.toLogMap(), {
          'phase_index': 5,
          'phase_name': 'phase5_cuisine',
          'elapsed_ms': anything,
          'budget_ms': 8000,
          'result': 'timeout',
        });

        // Tags from Phases 1-4 preserved; no Phase 5 cuisine tag.
        final tags = result!.tagResult.tags;
        expect(tags, containsAll({'p1-tag', 'p2-tag', 'p3-tag', 'p4-tag'}));
        expect(tags, isNot(contains('p5-tag')));
        expect(tags, isNot(contains('never-p5')));
        expect(result!.tagResult.isPartial, isTrue);
      });
    });
  });

  group('BUT-553: Phase 1 floor case', () {
    test('Phase 1 hang → TagResult.failed (no usable safety floor below)', () {
      fakeAsync((async) {
        final callables = buildCallables(
          phase1: (lk, r) => Future.delayed(
            const Duration(hours: 1),
            () => Phase1Result(
              tags: const {'never-p1'},
              allergenStatus: const {},
              dietaryStatus: const {},
              lookup: lk,
            ),
          ),
        );
        final runner = buildRunner(callables);

        TaggingPipelineResult? result;
        runner
            .run(recipe: recipe, ingredients: ['rice', 'chicken'])
            .then((r) => result = r);
        drain(async);

        final byIndex = {for (final o in result!.outcomes) o.phaseIndex: o};
        expect(byIndex[1]!.result, 'timeout');

        // No Phase 2-5 outcomes recorded — pipeline returned early.
        expect(byIndex.keys, [0, 1]);

        // TagResult.failed has the "failed" generator-version sentinel
        // and an errorReason explaining why. isPartial is false because
        // a failed result isn't "partial" — it's the floor case.
        expect(result!.tagResult.generatorVersion, contains('failed'));
        expect(result!.tagResult.errorReason, contains('Phase 1'));
        expect(result!.tagResult.tags, isEmpty);
      });
    });
  });

  group('BUT-553: happy path (regression check)', () {
    test('All phases succeed → result is non-partial with all phase tags', () {
      fakeAsync((async) {
        final runner = buildRunner(buildCallables());

        TaggingPipelineResult? result;
        runner
            .run(recipe: recipe, ingredients: ['rice', 'chicken'])
            .then((r) => result = r);
        drain(async);

        final byIndex = {for (final o in result!.outcomes) o.phaseIndex: o};
        for (var i = 0; i <= 5; i++) {
          expect(
            byIndex[i]!.result,
            'ok',
            reason: 'Phase $i should be ok in happy path',
          );
        }

        final tags = result!.tagResult.tags;
        expect(
          tags,
          containsAll(<String>{
            'p1-tag',
            'p2-tag',
            'p3-tag',
            'p4-tag',
            'p5-tag',
          }),
          reason: 'All phase contributions present',
        );
        expect(
          tags,
          isNot(contains('p5-fallback-tag')),
          reason: 'Full chain → no fallback path',
        );
        expect(
          result!.tagResult.isPartial,
          isFalse,
          reason: 'No phases skipped → not partial',
        );
      });
    });
  });
}
