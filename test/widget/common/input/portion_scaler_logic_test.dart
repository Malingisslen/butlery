/// Unit tests for PortionScalerLogic — pure Dart logic, no Flutter widgets.
///
/// PortionScalerLogic is a static utility that:
/// 1. Detects American units in a list of ingredient strings.
/// 2. Scales an ingredient list from one portion count to another, optionally
///    converting American units to Swedish.
///
/// Behaviour-focused tests: we assert the OUTCOMES recipe authors care about
/// (correctly halved/doubled quantities, US→SI conversion when asked, gentle
/// passthrough for blanks and non-quantitative lines), not the internal call
/// sequence into IngredientParser / SmartUnitConverter / SwedishPluralization.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/widgets/common/input/portion_scaler_logic.dart';

void main() {
  group('PortionScalerLogic.detectAmericanUnits', () {
    test('returns false for an empty ingredient list', () {
      expect(PortionScalerLogic.detectAmericanUnits(const []), isFalse);
    });

    test('returns false for purely Swedish-unit ingredients', () {
      expect(
        PortionScalerLogic.detectAmericanUnits(const [
          '2 dl mjölk',
          '4 ägg',
          '1 tsk salt',
          '500 g mjöl',
        ]),
        isFalse,
      );
    });

    test('detects "cup" via parsed unit', () {
      expect(
        PortionScalerLogic.detectAmericanUnits(const ['1 cup flour']),
        isTrue,
      );
    });

    test('detects "cups" (plural) via parsed unit', () {
      expect(
        PortionScalerLogic.detectAmericanUnits(const ['2 cups sugar']),
        isTrue,
      );
    });

    test('detects "tbsp"', () {
      expect(
        PortionScalerLogic.detectAmericanUnits(const ['3 tbsp olja']),
        isTrue,
      );
    });

    test('detects "tsp"', () {
      expect(
        PortionScalerLogic.detectAmericanUnits(const ['1 tsp salt']),
        isTrue,
      );
    });

    test('detects "oz"', () {
      expect(
        PortionScalerLogic.detectAmericanUnits(const ['8 oz cream cheese']),
        isTrue,
      );
    });

    test('detects "pound" word form', () {
      expect(
        PortionScalerLogic.detectAmericanUnits(const ['1 pound ground beef']),
        isTrue,
      );
    });

    test('returns true when ONE line in a mixed list has American units', () {
      expect(
        PortionScalerLogic.detectAmericanUnits(const [
          '2 dl mjölk',
          '1 cup flour',
          '4 ägg',
        ]),
        isTrue,
      );
    });

    test('fallback string scan catches "cup" surrounded by spaces', () {
      // Even if the parser couldn't categorise this as a clean "unit", the
      // substring fallback at the end of the method should still fire.
      expect(
        PortionScalerLogic.detectAmericanUnits(const [
          'add 1 cup of warm water',
        ]),
        isTrue,
      );
    });

    test('case-insensitive match (CUP vs cup)', () {
      expect(
        PortionScalerLogic.detectAmericanUnits(const ['1 CUP flour']),
        isTrue,
      );
    });

    test('does NOT match "cup" as substring of another word', () {
      // "cupcake" should not trigger — the fallback requires word boundaries
      // (leading space, trailing space, or start/end of string).
      expect(
        PortionScalerLogic.detectAmericanUnits(const ['en cupcake']),
        isFalse,
      );
    });
  });

  group('PortionScalerLogic.scaleIngredients — passthrough', () {
    test('returns copy of original when originalPortions == 0', () {
      // Guard against divide-by-zero — should hand back the input unchanged
      // (as a copy, not the same instance, so the caller can mutate safely).
      const original = ['2 dl mjölk', '4 ägg'];
      final result = PortionScalerLogic.scaleIngredients(
        original,
        0,
        4,
        false,
      );
      expect(result, equals(original));
      expect(identical(result, original), isFalse);
    });

    test('returns copy of original when newPortions == originalPortions and '
        'no Swedish conversion requested', () {
      const original = ['2 dl mjölk', '4 ägg'];
      final result = PortionScalerLogic.scaleIngredients(
        original,
        4,
        4,
        false,
      );
      expect(result, equals(original));
      expect(identical(result, original), isFalse);
    });

    test('empty input list yields empty output', () {
      expect(
        PortionScalerLogic.scaleIngredients(const [], 4, 8, false),
        isEmpty,
      );
    });

    test('blank line passes through unchanged', () {
      final result = PortionScalerLogic.scaleIngredients(
        const ['   '],
        4,
        2,
        false,
      );
      // Whitespace-only lines should be returned as-is — see early-return on
      // `ingredient.trim().isEmpty` in _scaleIndividualIngredient.
      expect(result, equals(['   ']));
    });
  });

  group('PortionScalerLogic.scaleIngredients — scaling', () {
    test('halving portions halves a "N dl X" quantity', () {
      final result = PortionScalerLogic.scaleIngredients(
        const ['2 dl mjölk'],
        4,
        2,
        false,
      );
      // 2 dl scaled by 0.5 → 1 dl. Unit and name are preserved (lowercased
      // by IngredientParser).
      expect(result, hasLength(1));
      expect(result.single, contains('1'));
      expect(result.single, contains('dl'));
      expect(result.single, contains('mjölk'));
    });

    test('doubling portions doubles a "N tsk salt" quantity', () {
      final result = PortionScalerLogic.scaleIngredients(
        const ['1 tsk salt'],
        4,
        8,
        false,
      );
      expect(result.single, contains('2'));
      expect(result.single, contains('tsk'));
      expect(result.single, contains('salt'));
    });

    test('scales multiple ingredients in one call', () {
      final result = PortionScalerLogic.scaleIngredients(
        const ['2 dl mjölk', '4 ägg'],
        4,
        2, // half
        false,
      );
      expect(result, hasLength(2));
      expect(result[0], contains('1'));
      expect(result[0], contains('mjölk'));
      // 4 ägg at half → 2 ägg (ägg is invariant in Swedish)
      expect(result[1], contains('2'));
      expect(result[1], contains('ägg'));
    });

    test('non-quantitative ingredient passes through unchanged', () {
      // An ingredient with no parseable quantity (quantity=1.0, unit='',
      // name==original) should be returned verbatim per the early-return
      // branch in _scaleIndividualIngredient.
      final result = PortionScalerLogic.scaleIngredients(
        const ['salt och peppar efter smak'],
        4,
        2,
        false,
      );
      expect(result.single, equals('salt och peppar efter smak'));
    });
  });

  group('PortionScalerLogic.scaleIngredients — Swedish conversion', () {
    test('when portions unchanged but convertToSwedish=true, still converts '
        'American → Swedish units', () {
      final result = PortionScalerLogic.scaleIngredients(
        const ['1 cup flour'],
        4,
        4,
        true,
      );
      // 1 cup ≈ 2.37 dl per SmartUnitConverter — outcome we care about is
      // that the line is no longer in cups.
      expect(result.single.toLowerCase(), contains('dl'));
      expect(result.single.toLowerCase(), isNot(contains('cup')));
    });

    test('with convertToSwedish=false, US units stay in cups', () {
      final result = PortionScalerLogic.scaleIngredients(
        const ['1 cup flour'],
        4,
        4,
        false,
      );
      // No conversion path taken — early return hands back the original list.
      expect(result.single, equals('1 cup flour'));
    });

    test('tbsp converts to msk when convertToSwedish=true', () {
      final result = PortionScalerLogic.scaleIngredients(
        const ['2 tbsp olja'],
        4,
        4,
        true,
      );
      // 1 tbsp ≈ 1 msk per SmartUnitConverter.
      expect(result.single.toLowerCase(), contains('msk'));
      expect(result.single.toLowerCase(), isNot(contains('tbsp')));
    });

    test('scaling + Swedish conversion combined: doubling cups → ~4.74 dl', () {
      final result = PortionScalerLogic.scaleIngredients(
        const ['1 cup flour'],
        4,
        8, // double
        true,
      );
      // 1 cup × 2 = 2 cups → 2 × 2.37 ≈ 4.74 dl. Outcome focus: unit is dl,
      // and the line no longer mentions cup.
      expect(result.single.toLowerCase(), contains('dl'));
      expect(result.single.toLowerCase(), isNot(contains('cup')));
    });

    test('Swedish-unit ingredients are passed through scaling unchanged in '
        'unit even when convertToSwedish=true', () {
      // "2 dl mjölk" doubled to 4 dl — dl is already Swedish so the unit
      // shouldn't change. (The smart converter may promote dl→l at large
      // quantities; 4 dl is below that threshold.)
      final result = PortionScalerLogic.scaleIngredients(
        const ['2 dl mjölk'],
        4,
        8,
        true,
      );
      expect(result.single.toLowerCase(), contains('dl'));
      expect(result.single.toLowerCase(), contains('mjölk'));
    });
  });

  // BUT-444: structured-first scaling. The persisted amount is the source of
  // truth — no string re-parse — and range quantities scale both endpoints
  // instead of being coerced to 1.0 (the v1 "scales silently wrong" bug).
  group('PortionScalerLogic.scaleEntries (BUT-444)', () {
    test(
      'structured entry scales via the persisted amount, not the string',
      () {
        // "ca 2,5 dl vispgrädde" — the leading "ca" defeats the string parser
        // (quantity coerced to 1.0, "ca" dropped → '2 dl vispgrädde' at
        // factor 2), but the structured amount knows better. This pins
        // "no string re-parse on the structured path".
        const entry = RecipeIngredient(
          amount: 2.5,
          unit: 'dl',
          name: 'vispgrädde',
          raw: 'ca 2,5 dl vispgrädde',
        );
        final result = PortionScalerLogic.scaleEntries(
          const [entry],
          2,
          4,
          false,
        );
        expect(result.single, '5 dl vispgrädde');
      },
    );

    test('structured entry keeps its note through scaling', () {
      const entry = RecipeIngredient(
        amount: 1,
        unit: 'msk',
        name: 'smör',
        note: 'rumstempererat',
        raw: '1 msk smör, rumstempererat',
      );
      final result = PortionScalerLogic.scaleEntries(
        const [entry],
        2,
        4,
        false,
      );
      expect(result.single, '2 msk smör, rumstempererat');
    });

    test('range "2-3 dl" doubles to "4-6 dl" (both endpoints)', () {
      // Ranges have amount == null in the structured model; v1 coerced the
      // quantity to 1.0 and scaled from that — silently wrong.
      const entry = RecipeIngredient(
        name: 'mjölk',
        raw: '2-3 dl mjölk',
      );
      final result = PortionScalerLogic.scaleEntries(
        const [entry],
        2,
        4,
        false,
      );
      expect(result.single, '4-6 dl mjölk');
    });

    test('range scales fractionally with Swedish fraction formatting', () {
      const entry = RecipeIngredient(
        name: 'vitlöksklyftor',
        raw: '1-2 vitlöksklyftor',
      );
      final result = PortionScalerLogic.scaleEntries(
        const [entry],
        2,
        3,
        false,
      );
      expect(result.single, '1 ½-3 vitlöksklyftor');
    });

    test(
      'raw-only entry falls back to the v1 string path (identical output)',
      () {
        final viaEntries = PortionScalerLogic.scaleEntries(
          [RecipeIngredient.rawOnly('2 dl mjölk')],
          2,
          4,
          false,
        );
        final viaStrings = PortionScalerLogic.scaleIngredients(
          const ['2 dl mjölk'],
          2,
          4,
          false,
        );
        expect(
          viaEntries,
          viaStrings,
          reason: 'legacy recipes must scale exactly as before',
        );
      },
    );

    test(
      'same portions without conversion returns the raw lines unchanged',
      () {
        const entry = RecipeIngredient(
          amount: 2,
          unit: 'dl',
          name: 'mjölk',
          raw: '2 dl mjölk',
        );
        final result = PortionScalerLogic.scaleEntries(
          const [entry],
          4,
          4,
          false,
        );
        expect(result.single, '2 dl mjölk');
      },
    );

    test('string path also scales ranges now (legacy callers fixed too)', () {
      final result = PortionScalerLogic.scaleIngredients(
        const ['2-3 dl mjölk'],
        2,
        4,
        false,
      );
      expect(result.single, '4-6 dl mjölk');
    });

    test('hyphenated ingredient names without quantities are not mangled by '
        'the range matcher', () {
      // The range regex requires digits on BOTH sides of the dash.
      final result = PortionScalerLogic.scaleIngredients(
        const ['chili-flakes efter smak'],
        2,
        4,
        false,
      );
      expect(result.single, 'chili-flakes efter smak');
    });
  });
}
