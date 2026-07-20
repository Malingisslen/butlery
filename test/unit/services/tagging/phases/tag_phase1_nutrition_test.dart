/// Behavioural tests for [Phase1NutritionCalculator.calculateProteinTags] —
/// specifically the protein-detection gaps closed in BUT-1631: duck compounds
/// were missed, and poultry / plant-based groups had no generic fallback, so an
/// unrecognised protein emitted no tag and silently escaped the weekly
/// protein-balance cap (BUT-1324). Fish already had its generic 'fisk'
/// fallback; these tests pin the mirrored poultry ('fågel') and plant-based
/// ('växtprotein') fallbacks plus the broadened duck match.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/services/tagging/phases/tag_phase1_nutrition.dart';

void main() {
  IngredientData ingredient(String swedish, String group) => IngredientData(
    id: swedish,
    swedish: swedish,
    english: swedish,
    group: group,
    properties: const {},
  );

  IngredientLookupResult lookupOf(List<IngredientData> matched) =>
      IngredientLookupResult.fromLists(matched: matched, unmatched: const []);

  group('calculateProteinTags — poultry (BUT-1631)', () {
    test('a duck cut whose name is a compound still tags as duck', () {
      // "ankbröst" does not contain the whole word 'anka' — the old
      // contains('anka') check missed it, dropping the duck out of the cap.
      final tags = Phase1NutritionCalculator.calculateProteinTags(
        lookupOf([ingredient('ankbröst', 'protein/meat/poultry')]),
      );
      expect(tags, contains('anka'));
      expect(tags, contains('fågel'));
    });

    test('an unrecognised bird still contributes the generic poultry tag', () {
      // Guinea fowl / quail match no species branch; without the generic
      // fallback they would emit nothing and escape the poultry balance cap.
      final tags = Phase1NutritionCalculator.calculateProteinTags(
        lookupOf([ingredient('pärlhöna', 'protein/meat/poultry')]),
      );
      expect(tags, contains('fågel'));
    });

    test('chicken still tags as both chicken and the generic poultry', () {
      final tags = Phase1NutritionCalculator.calculateProteinTags(
        lookupOf([ingredient('kycklingfilé', 'protein/meat/poultry')]),
      );
      expect(tags, containsAll(<String>['kyckling', 'fågel']));
    });

    test('no poultry ingredient means no poultry tag', () {
      final tags = Phase1NutritionCalculator.calculateProteinTags(
        lookupOf([ingredient('nötfärs', 'protein/meat/beef')]),
      );
      expect(tags, isNot(contains('fågel')));
      expect(tags, contains('nötkött'));
    });
  });

  group('calculateProteinTags — plant-based (BUT-1631)', () {
    test('an unrecognised plant protein contributes the generic tag', () {
      // A novel meat substitute matches no specific branch; the generic
      // 'växtprotein' fallback keeps it inside the balance cap.
      final tags = Phase1NutritionCalculator.calculateProteinTags(
        lookupOf([ingredient('ärtprotein', 'protein/plant-based')]),
      );
      expect(tags, contains('växtprotein'));
    });

    test('a specific plant protein tags as both itself and the generic', () {
      final tags = Phase1NutritionCalculator.calculateProteinTags(
        lookupOf([ingredient('rökt tofu', 'protein/plant-based')]),
      );
      expect(tags, containsAll(<String>['tofu', 'växtprotein']));
    });

    test('no plant-based ingredient means no generic plant tag', () {
      final tags = Phase1NutritionCalculator.calculateProteinTags(
        lookupOf([ingredient('nötfärs', 'protein/meat/beef')]),
      );
      expect(tags, isNot(contains('växtprotein')));
    });
  });

  group('calculateProteinTags — plant dairy-alternatives are not protein', () {
    // The register files vegan dairy-alternatives and näringsjäst under
    // protein/plant-based, so a group-wide fallback would count a splash of
    // vegan cream as a plant-protein main and pollute the BUT-1324 weekly
    // balance nudge. Names below are taken verbatim from the live register.
    for (final name in const [
      'vegansk vispgrädde',
      'vegansk crème fraîche',
      'vegansk ost riven',
      'vegansk fetaost',
      'vegansk kvarg',
      'vegansk parmesan',
      'kokosyoghurt',
      'näringsjäst',
    ]) {
      test('$name alone does not make the dish a plant-protein main', () {
        final tags = Phase1NutritionCalculator.calculateProteinTags(
          lookupOf([ingredient(name, 'protein/plant-based')]),
        );
        expect(tags, isNot(contains('växtprotein')));
      });
    }

    test('a real protein still counts when a dairy-alt accompanies it', () {
      // The guard suppresses the fallback only when NOTHING in the group is
      // center-of-plate — tofu simmered in vegan cream is still a protein main.
      final tags = Phase1NutritionCalculator.calculateProteinTags(
        lookupOf([
          ingredient('tofu', 'protein/plant-based'),
          ingredient('vegansk vispgrädde', 'protein/plant-based'),
        ]),
      );
      expect(tags, containsAll(<String>['tofu', 'växtprotein']));
    });

    test('a vegan product without a dairy word is still a protein', () {
      // Conservative by design: 'vegansk korv' carries no dairy word, so the
      // guard must not swallow it.
      final tags = Phase1NutritionCalculator.calculateProteinTags(
        lookupOf([ingredient('vegansk korv', 'protein/plant-based')]),
      );
      expect(tags, contains('växtprotein'));
    });

    test('a roasted protein is not mistaken for cheese', () {
      // Regression guard for the substring trap: matching bare 'ost' would also
      // match 'rostad', wrongly excluding a genuine protein.
      final tags = Phase1NutritionCalculator.calculateProteinTags(
        lookupOf([ingredient('rostade kikärter', 'protein/plant-based')]),
      );
      expect(tags, contains('växtprotein'));
    });

    test('plant cream cheese is not tagged as mince', () {
      // 'växtfärskost' CONTAINS 'växtfärs', so an unbounded specifics match
      // tagged a tub of cream cheese as a mince-based protein main. It must be
      // excluded from the fallback AND never reach the mince branch.
      final tags = Phase1NutritionCalculator.calculateProteinTags(
        lookupOf([ingredient('växtfärskost', 'protein/plant-based')]),
      );
      expect(tags, isNot(contains('växtfärs')));
      expect(tags, isNot(contains('växtprotein')));
    });

    test('real mince still tags as mince', () {
      // Control for the bounded pattern above — the real product must survive.
      final tags = Phase1NutritionCalculator.calculateProteinTags(
        lookupOf([ingredient('sojafärs', 'protein/plant-based')]),
      );
      expect(tags, containsAll(<String>['växtfärs', 'växtprotein']));
    });

    test('a cooking method never disqualifies a protein', () {
      // Swedish preparation adjectives collide with dairy nouns: 'gräddad'
      // (griddled) contains 'grädd', and 'jäst'/'jästa' (fermented) is also the
      // word for yeast — and fermentation is how plant proteins are described.
      // An unbounded stem silently dropped these from the BUT-1324 balance
      // nudge, which is the exact failure this guard must not cause.
      for (final name in const [
        'gräddad falafel',
        'gräddade vegobiffar',
        'jästa sojabönor',
        'tempeh jäst',
      ]) {
        final tags = Phase1NutritionCalculator.calculateProteinTags(
          lookupOf([ingredient(name, 'protein/plant-based')]),
        );
        expect(
          tags,
          contains('växtprotein'),
          reason: '$name is a protein, not an accompaniment',
        );
      }
    });

    test('a vegan roast is a protein, not a cheese', () {
      // The 'vegansk' marker and the 'rost' stem can coexist — "vegansk
      // rostbiff" is a real product. Pairing alone was not enough; the 'ost'
      // fragment has to be bounded so it cannot match inside 'rostbiff'.
      for (final name in const [
        'vegansk rostbiff',
        'vegansk rostad kikärtsmix',
      ]) {
        final tags = Phase1NutritionCalculator.calculateProteinTags(
          lookupOf([ingredient(name, 'protein/plant-based')]),
        );
        expect(
          tags,
          contains('växtprotein'),
          reason: '$name is a center-of-plate protein',
        );
      }
    });

    test('base-named plant dairy-alts are accompaniments, not protein', () {
      // The register names most of this family WITHOUT a 'vegansk' marker
      // (kokosyoghurt, havreyoghurt), so the guard must not require one.
      // These specific names are known product names from
      // lib/constants/known_ingredients.dart rather than rows currently in the
      // protein/plant-based group — they pin the guard against the naming
      // convention the register actually uses, before such a row lands.
      for (final name in const [
        'havregrädde',
        'växtfeta',
        'sojaqvarg',
        'sojagurt',
        'växtcreme',
        'jästflingor',
      ]) {
        final tags = Phase1NutritionCalculator.calculateProteinTags(
          lookupOf([ingredient(name, 'protein/plant-based')]),
        );
        expect(
          tags,
          isNot(contains('växtprotein')),
          reason: '$name is a dairy-alt, not the protein of the dish',
        );
      }
    });
  });

  group('calculateProteinTags — species precedence (BUT-1631)', () {
    test('an exact species match out-ranks the broad duck stem', () {
      // 'ank' is a deliberately broad stem; it must be tested after the exact
      // species so a compound merely containing it cannot win. 'kalkonskank'
      // is a SYNTHETIC probe name (not a register row) — it exists purely to
      // exercise the branch order.
      final tags = Phase1NutritionCalculator.calculateProteinTags(
        lookupOf([ingredient('kalkonskank', 'protein/meat/poultry')]),
      );
      expect(tags, contains('kalkon'));
      expect(tags, isNot(contains('anka')));
    });
  });

  test('every emitted protein tag lives in the shared vocabulary', () {
    // Guards the BUT-1458 contract from the tagger side: the assert inside
    // calculateProteinTags would trip in debug builds if an emit drifted out of
    // proteinTags. Exercise the fallbacks and confirm the invariant holds.
    final tags = Phase1NutritionCalculator.calculateProteinTags(
      lookupOf([
        ingredient('ankbröst', 'protein/meat/poultry'),
        ingredient('ärtprotein', 'protein/plant-based'),
        ingredient('lax', 'protein/seafood/fish'),
      ]),
    );
    expect(tags, everyElement(isIn(Phase1NutritionCalculator.proteinTags)));
  });
}
