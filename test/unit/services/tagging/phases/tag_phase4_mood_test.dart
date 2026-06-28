/// Direct unit tests for [TagPhase4Mood] (BUT-1149 coverage burndown —
/// previously zero direct coverage).
///
/// Phase 4 derives occasion/mood/holiday tags from the prior phases + the
/// recipe. The deterministic, lookup-independent rules are tested here: the
/// time-based occasion tags (from prior-phase tags + cook time), the tag-based
/// "värmande", the title-based Swedish-holiday tags (incl. the "julienne" false
/// positive), and Phase4Result.allTags spanning all four phases. The
/// ingredient-group-dependent mood/luxury/season tags are left to integration.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_base.dart';
import 'package:butlery/services/tagging/phases/tag_phase2_derived.dart';
import 'package:butlery/services/tagging/phases/tag_phase3_complex.dart';
import 'package:butlery/services/tagging/phases/tag_phase4_mood.dart';

import '../../../../infrastructure/factories/recipe_factory.dart';

Phase1Result p1({Set<String> tags = const {}}) => Phase1Result(
  tags: tags,
  allergenStatus: const {},
  dietaryStatus: const {},
  lookup: IngredientLookupResult.empty(),
);
Phase2Result p2(Phase1Result a) => Phase2Result(tags: const {}, phase1: a);
Phase3Result p3(Phase1Result a, {Set<String> tags = const {}}) =>
    Phase3Result(tags: tags, phase1: a, phase2: p2(a));

void main() {
  final phase4 = TagPhase4Mood();

  Phase4Result run({
    Set<String> p1Tags = const {},
    Set<String> p3Tags = const {},
    int timeMinutes = 30,
    String title = 'Vardagsmat',
  }) {
    final a = p1(tags: p1Tags);
    final recipe = RecipeFactory.build(title: title, timeMinutes: timeMinutes);
    return phase4.calculate(a, p2(a), p3(a, tags: p3Tags), recipe);
  }

  group('time-based occasion tags', () {
    test('under-45-min + easy → vardagsmiddag', () {
      final r = run(p1Tags: {'under-45-min'}, p3Tags: {'enkel'});
      expect(r.tags, contains('vardagsmiddag'));
    });

    test('advanced → helgmat', () {
      expect(run(p3Tags: {'avancerad'}).tags, contains('helgmat'));
    });

    test('under-15-min + easy → snabblagat', () {
      final r = run(p1Tags: {'under-15-min'}, p3Tags: {'enkel'});
      expect(r.tags, contains('snabblagat'));
    });

    test('long cook + stew → söndagsmiddag', () {
      final r = run(p1Tags: {'gryta'}, timeMinutes: 90);
      expect(r.tags, contains('söndagsmiddag'));
    });
  });

  group('mood (tag-based)', () {
    test('soup → värmande', () {
      expect(run(p1Tags: {'soppa'}).tags, contains('värmande'));
    });
  });

  group('Swedish holiday tags (title-based)', () {
    test('a Christmas dish title → jul', () {
      expect(run(title: 'Julskinka med senap').tags, contains('jul'));
    });

    test('"julienne" is NOT mistaken for Christmas', () {
      expect(run(title: 'Julienne på grönsaker').tags, isNot(contains('jul')));
    });

    test('Lucia + Easter title keywords', () {
      expect(run(title: 'Lussekatter').tags, contains('lucia'));
      expect(run(title: 'Påskmust kyckling').tags, contains('påsk'));
    });
  });

  group('Phase4Result.allTags', () {
    test('spans phase 1-4 tags', () {
      final a = p1(tags: {'p1tag'});
      final result = phase4.calculate(
        a,
        Phase2Result(tags: const {'p2tag'}, phase1: a),
        Phase3Result(tags: const {'avancerad'}, phase1: a, phase2: p2(a)),
        RecipeFactory.build(title: 'Vardagsmat'),
      );
      // p1tag (phase1) + p2tag (phase2) + avancerad (phase3) + helgmat (phase4).
      expect(
        result.allTags,
        containsAll(<String>['p1tag', 'p2tag', 'avancerad', 'helgmat']),
      );
    });
  });
}
