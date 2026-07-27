/// Unit tests for the ASSISTED-import copy of `IngredientLineDetector`
/// (`lib/widgets/import/ingredient_line_detector.dart`).
///
/// This class had no test file at all, which is how BUT-1691 shipped a fix to
/// the identically-named services copy while leaving the user-visible symptom
/// live here: `assisted_import_viewmodel.dart` calls [detectFromLines] for
/// every photo/OCR and text import, and the `\b`-bounded unit list pre-ticked
/// ordinary Swedish section headings as ingredient lines.
///
/// Behaviours pinned:
/// 1.  Too-short and too-long lines are never ingredients.
/// 2.  Exclusion patterns beat everything else.
/// 3.  Every declared unit matches when it genuinely stands alone.
/// 4.  A unit letter EMBEDDED in a Swedish word does NOT match — both boundary
///     halves (lookbehind for å/ä/ö before the unit, lookahead for å/ä/ö after
///     it) get their own fixture group, so a one-sided mutant stays red.
/// 5.  Fraction / leading-number / starter-word branches still fire.
/// 6.  `detectFromLines` and `detectIngredientLines` return 0-based indices.
/// 7.  `getConfidence` scores the same boundary correctly (it repeats the unit
///     match, so a fix applied to only one of the two would show up here).
/// 8.  `detectInstructionLines` does not claim a real ingredient line.
library;

import 'package:butlery/widgets/import/ingredient_line_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IngredientLineDetector (assisted import) — length guards', () {
    test('lines shorter than 3 chars are never ingredients', () {
      expect(IngredientLineDetector.detectFromLines(['', 'ab', '  ']), isEmpty);
    });

    test('lines longer than 100 chars are never ingredients', () {
      final long = '2 dl ${'mjölk ' * 40}';
      expect(long.length, greaterThan(100));
      expect(IngredientLineDetector.detectFromLines([long]), isEmpty);
    });
  });

  group('IngredientLineDetector (assisted import) — exclusions', () {
    /// Proves the headers a recipe page always has are not offered as
    /// ingredients, even though several contain unit letters.
    test('section headers and step markers are excluded', () {
      const headers = [
        'Ingredienser',
        'Ingredienser:',
        'Instruktioner',
        'Tillagning:',
        'Gör så här',
        'Steg 1',
        'För 4 portioner',
      ];
      expect(
        IngredientLineDetector.detectFromLines(headers),
        isEmpty,
        reason: 'no recipe-page header may be pre-ticked as an ingredient',
      );
    });
  });

  group('IngredientLineDetector (assisted import) — Swedish word boundary', () {
    /// BUT-1691, trailing edge. Dart's `\b` is ASCII-only, so it reports a
    /// phantom boundary beside å/ä/ö: `\bl\b` matched the final "l" of "Kål"
    /// and `\bst\b` the "st" of "Höst". Only the negative LOOKBEHIND rejects
    /// these, so a lookahead-only mutant of the boundary keeps this group red.
    test('a unit letter at the END of a Swedish word does not match', () {
      const headings = [
        'Kål',
        'Mjöl',
        'Höst',
        'Råg',
        'Rödkål:',
        'Kålrot och mjöl',
      ];
      for (final heading in headings) {
        expect(
          IngredientLineDetector.detectFromLines([heading]),
          isEmpty,
          reason: heading,
        );
      }
    });

    /// The other half: å/ä/ö AFTER the unit letter, rejected only by the
    /// negative LOOKAHEAD. A lookbehind-only mutant keeps this group red.
    test('a unit letter at the START of a Swedish word does not match', () {
      const headings = ['Lök:', 'Gäddan', 'Löken hackas', 'Gräddfil'];
      for (final heading in headings) {
        expect(
          IngredientLineDetector.detectFromLines([heading]),
          isEmpty,
          reason: heading,
        );
      }
    });

    /// The fix must not have thrown out the feature: a unit genuinely standing
    /// on its own next to a Swedish word still counts.
    ///
    /// None of these may start with a digit or with an `_ingredientStarters`
    /// word: the leading-quantity branch and the starter branch both answer
    /// before the unit loop is consulted, so such a fixture would pass with the
    /// whole boundary deleted.
    test('a real unit next to a Swedish word still matches', () {
      const lines = ['en st kål', 'en nypa salt', 'ett paket smör'];
      for (final line in lines) {
        expect(
          IngredientLineDetector.detectFromLines([line]),
          [0],
          reason: line,
        );
      }
    });

    /// A unit spelled inside a longer ASCII word must not match either — this
    /// is the half plain `\b` already got right, kept so the replacement is not
    /// a regression on it.
    test('a unit embedded in a longer ASCII word does not match', () {
      for (final line in ['glossy paper', 'milligrampower', 'asterisk here']) {
        expect(
          IngredientLineDetector.detectFromLines([line]),
          isEmpty,
          reason: line,
        );
      }
    });
  });

  group('IngredientLineDetector (assisted import) — other branches', () {
    test('a leading unicode fraction marks the line', () {
      expect(IngredientLineDetector.detectFromLines(['½ tomat']), [0]);
      expect(IngredientLineDetector.detectFromLines(['¾ banan']), [0]);
    });

    /// `_fractionPattern`'s trailing `\s*` is optional, so ANY line starting
    /// with a digit is marked here and the separate number-start branch is
    /// never the decider in `detectFromLines` — it still matters in
    /// `getConfidence`. The name says what the code does, not what the branch
    /// list suggests.
    test('a line starting with a digit is marked', () {
      expect(IngredientLineDetector.detectFromLines(['2 äpplen']), [0]);
      expect(IngredientLineDetector.detectFromLines(['2äpplen']), [0]);
    });

    test('a numbered instruction is not a leading-number ingredient', () {
      expect(
        IngredientLineDetector.detectFromLines(['1. Hacka löken']),
        isEmpty,
      );
    });

    test('an approximation starter marks the line', () {
      expect(IngredientLineDetector.detectFromLines(['cirka två morötter']), [
        0,
      ]);
      expect(IngredientLineDetector.detectFromLines(['eventuellt persilja']), [
        0,
      ]);
    });
  });

  group('IngredientLineDetector (assisted import) — index reporting', () {
    test('detectFromLines returns 0-based indices of the matches only', () {
      const lines = [
        'Ingredienser', // excluded header
        '2 dl mjölk', // match
        'Kål', // BUT-1691 trap — must NOT match
        '500 g mjöl', // match
      ];
      expect(IngredientLineDetector.detectFromLines(lines), [1, 3]);
    });

    test('detectIngredientLines splits on newlines with the same result', () {
      const text = 'Ingredienser\n2 dl mjölk\nKål\n500 g mjöl';
      expect(IngredientLineDetector.detectIngredientLines(text), [1, 3]);
    });
  });

  group('IngredientLineDetector (assisted import) — getConfidence', () {
    /// `getConfidence` repeats the unit match independently of
    /// `_isLikelyIngredient`, so a fix applied to only one of the two would
    /// leave this scoring the trap words as confident ingredients.
    test('a Swedish word ending in a unit letter scores no unit bonus', () {
      // "Kål" is only 3 chars: short-line bonus 0.1, no unit bonus, no number.
      expect(IngredientLineDetector.getConfidence('Kål'), closeTo(0.1, 1e-9));
      expect(IngredientLineDetector.getConfidence('Lök'), closeTo(0.1, 1e-9));
    });

    test('a genuine unit line scores the unit bonus', () {
      // No leading digit, so the 0.4 unit bonus is isolated from the number
      // and fraction bonuses: 0.4 unit + 0.1 short line.
      expect(
        IngredientLineDetector.getConfidence('en st kål'),
        closeTo(0.5, 1e-9),
      );
      // With a leading digit the score saturates: the number and fraction
      // patterns BOTH match a bare digit (0.4 + 0.3 + 0.3 + 0.1 = 1.1),
      // so the clamp is what keeps it in range. Pinned so a future change to
      // either pattern shows up as a diff rather than as silent double-count.
      expect(IngredientLineDetector.getConfidence('2 dl mjölk'), 1.0);
    });

    test('an excluded header scores zero', () {
      expect(IngredientLineDetector.getConfidence('Ingredienser'), 0.0);
    });

    test('out-of-range lengths score zero', () {
      expect(IngredientLineDetector.getConfidence('ab'), 0.0);
      expect(IngredientLineDetector.getConfidence('x' * 101), 0.0);
    });
  });

  group(
    'IngredientLineDetector (assisted import) — detectInstructionLines',
    () {
      /// Proves the two detectors stay disjoint on the trap words: with the old
      /// `\b`, "Kål" counted as an ingredient and so was skipped here too. The
      /// real contract is that a genuine ingredient line is never offered as an
      /// instruction.
      test('a genuine ingredient line is not offered as an instruction', () {
        const lines = ['2 dl mjölk och lite socker på toppen'];
        expect(IngredientLineDetector.detectInstructionLines(lines), isEmpty);
      });

      test('a cooking-verb sentence is offered as an instruction', () {
        const lines = ['Vispa grädden tills den är fluffig'];
        expect(IngredientLineDetector.detectInstructionLines(lines), [0]);
      });

      test('excludeIndices are skipped', () {
        const lines = ['Vispa grädden tills den är fluffig'];
        expect(
          IngredientLineDetector.detectInstructionLines(
            lines,
            excludeIndices: {0},
          ),
          isEmpty,
        );
      });
    },
  );
}
