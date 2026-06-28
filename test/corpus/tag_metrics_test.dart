@TestOn('vm')
library;

import 'package:test/test.dart';

import '../../tools/corpus/tag_metrics.dart';
import '../../tools/corpus/tag_models.dart';

void main() {
  group('scoreTriStateMap — allergen safety scoring', () {
    test('exact matches across all three classes score fully correct', () {
      final score = scoreTriStateMap(
        {
          'gluten': TagTriState.contains,
          'mjölk': TagTriState.free,
          'soja': TagTriState.unknown,
        },
        {
          'gluten': TagTriState.contains,
          'mjölk': TagTriState.free,
          'soja': TagTriState.unknown,
        },
      );

      expect(score.total, 3);
      expect(score.correct, 3);
      expect(score.accuracy, 1.0);
      expect(score.falseFree, 0);
      expect(score.missedContains, 0);
    });

    test(
      'claiming FREE when truth is CONTAINS is a false-FREE (the dangerous error)',
      () {
        final score = scoreTriStateMap(
          {'nötter': TagTriState.contains},
          {'nötter': TagTriState.free},
        );

        expect(
          score.falseFree,
          1,
          reason: 'overclaimed safety on a real allergen',
        );
        expect(score.missedContains, 1);
        expect(score.correct, 0);
      },
    );

    test('claiming FREE when truth is UNKNOWN is also a false-FREE', () {
      final score = scoreTriStateMap(
        {'soja': TagTriState.unknown},
        {'soja': TagTriState.free},
      );

      expect(
        score.falseFree,
        1,
        reason: 'overclaimed certainty we do not have',
      );
      expect(score.missedContains, 0);
    });

    test(
      'UNKNOWN where truth is FREE is wrong but NOT a false-FREE (safe direction)',
      () {
        final score = scoreTriStateMap(
          {'gluten': TagTriState.free},
          {'gluten': TagTriState.unknown},
        );

        expect(score.correct, 0);
        expect(score.falseFree, 0, reason: 'under-claiming safety never harms');
      },
    );

    test('a missing prediction defaults to UNKNOWN, never to FREE', () {
      final score = scoreTriStateMap(
        {'gluten': TagTriState.free, 'mjölk': TagTriState.contains},
        const {}, // tagger emitted nothing
      );

      expect(score.correct, 0);
      expect(
        score.falseFree,
        0,
        reason: 'absent prediction must not read as a FREE claim',
      );
      expect(score.missedContains, 1);
    });

    test('empty answer key is vacuously perfect', () {
      final score = scoreTriStateMap(const {}, const {});
      expect(score.total, 0);
      expect(score.accuracy, 1.0);
      expect(score.falseFreeRate, 0.0);
    });
  });

  group('scoreRecipeTags — classification tags', () {
    test('expected tags score as set precision/recall/F1', () {
      final gold = GoldTags(
        verified: true,
        expectedTags: {'svensk', 'soppa', 'vegetarisk'},
      );
      final pred = PredictedTags(
        tags: {'svensk', 'soppa', 'gryta'}, // 2 hit, 1 miss, 1 spurious
        coverage: 1.0,
      );

      final score = scoreRecipeTags(gold, pred);
      expect(score.tags.matched, 2);
      expect(score.tags.recall, closeTo(2 / 3, 1e-9));
      expect(score.tags.precision, closeTo(2 / 3, 1e-9));
    });

    test('no expected tags is vacuously perfect (F1 = 1.0)', () {
      final score = scoreRecipeTags(
        const GoldTags(verified: true),
        const PredictedTags(tags: {'whatever'}, coverage: 1.0),
      );
      expect(score.tags.f1, 1.0);
    });
  });

  group('summarizeTags — corpus aggregate', () {
    test('sums tri-state counts and surfaces total false-FREE', () {
      final a = scoreRecipeTags(
        GoldTags(verified: true, allergens: {'nötter': TagTriState.contains}),
        const PredictedTags(
          allergens: {'nötter': TagTriState.free}, // false-FREE
          coverage: 1.0,
        ),
      );
      final b = scoreRecipeTags(
        GoldTags(verified: true, allergens: {'gluten': TagTriState.free}),
        const PredictedTags(
          allergens: {'gluten': TagTriState.free}, // correct
          coverage: 0.5,
        ),
      );

      final summary = summarizeTags([a, b]);
      expect(summary.count, 2);
      expect(summary.allergens.total, 2);
      expect(summary.allergens.falseFree, 1);
      expect(summary.allergens.correct, 1);
      expect(summary.meanCoverage, closeTo(0.75, 1e-9));
    });

    test('tag-F1 mean excludes recipes whose key asserts no tags', () {
      // Asserted recipe: precision 1/1, recall 1/2 → F1 = 0.6667.
      final asserted = scoreRecipeTags(
        GoldTags(verified: true, expectedTags: {'svensk', 'soppa'}),
        const PredictedTags(tags: {'svensk'}, coverage: 1.0),
      );
      // Allergen-only key (no tags asserted) but tagger emitted a tag anyway —
      // must NOT inflate the mean to a vacuous 1.0.
      final notAsserted = scoreRecipeTags(
        GoldTags(verified: true, allergens: {'gluten': TagTriState.free}),
        const PredictedTags(tags: {'hallucinated'}, coverage: 1.0),
      );

      final summary = summarizeTags([asserted, notAsserted]);
      expect(
        summary.meanTagF1,
        closeTo(2 / 3, 1e-9),
        reason: 'only the tag-asserting recipe counts toward the mean',
      );
    });

    test('empty corpus summarizes to zeros, not a crash', () {
      final summary = summarizeTags([]);
      expect(summary.count, 0);
      expect(summary.allergens.total, 0);
    });
  });
}
