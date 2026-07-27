/// Unit tests for IngredientLineDetector.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/import/heuristics/ingredient_line_detector.dart';

void main() {
  group('looksLikeIngredient', () {
    test('false for empty / whitespace-only lines', () {
      expect(IngredientLineDetector.looksLikeIngredient(''), isFalse);
      expect(IngredientLineDetector.looksLikeIngredient('   '), isFalse);
    });

    test('false for too-short lines (< 3 chars after trim)', () {
      expect(IngredientLineDetector.looksLikeIngredient('a'), isFalse);
      expect(IngredientLineDetector.looksLikeIngredient('ab'), isFalse);
    });

    test('false for too-long lines (> 100 chars)', () {
      final long = 'a' * 101;
      expect(IngredientLineDetector.looksLikeIngredient(long), isFalse);
    });

    // The fixture deliberately does NOT start with a digit: `looksLikeIngredient`
    // returns true for any line beginning with a digit or fraction, so a
    // "2 $unit …" fixture passes even with the whole unit loop deleted. "ca …"
    // is the shape a Swedish recipe actually uses and leaves the unit patterns
    // as the only branch that can answer.
    test('true when a Swedish unit word matches as a whole word', () {
      for (final unit in IngredientLineDetector.measurements) {
        expect(
          IngredientLineDetector.looksLikeIngredient('ca $unit mjölk'),
          isTrue,
          reason: unit,
        );
      }
    });

    test('false when unit appears as a substring of another word', () {
      // "gloss" contains "g" but not as a word boundary
      expect(
        IngredientLineDetector.looksLikeIngredient('gloss is shiny'),
        isFalse,
      );
      // "milligram" contains "g" but not as a whole word
      expect(
        IngredientLineDetector.looksLikeIngredient('milligrampower'),
        isFalse,
      );
    });

    // BUT-1691: Dart's ASCII \b reports a phantom boundary beside å/ä/ö, so
    // the one-letter units used to match inside ordinary Swedish words and
    // every heading built from one was pre-ticked as an ingredient line.
    //
    // The boundary has TWO independent halves and each needs its own fixture:
    // these words put the å/ä/ö BEFORE the unit letter, so only the negative
    // lookBEHIND rejects them. Deleting the lookahead keeps this test green —
    // that is what the leading-edge group below covers.
    test('false for Swedish words that merely END in a unit letter', () {
      for (final heading in [
        'Kål', // \bl\b matched between å and the end
        'Mjöl',
        'Höst', // \bst\b matched between ö and the end
        'Råg', // \bg\b matched between å and the end
        'Kålrot och mjöl', // the same trap mid-sentence
        'Rödkål:', // section heading with a colon
      ]) {
        expect(
          IngredientLineDetector.looksLikeIngredient(heading),
          isFalse,
          reason: heading,
        );
      }
    });

    // The other half: å/ä/ö AFTER the unit letter, so only the negative
    // lookAHEAD rejects them — which means a LOOKBEHIND-ONLY mutant of the
    // boundary keeps this group red while the trailing-edge group above stays
    // green. (The sibling widgets suite states the same pairing.)
    test('false for Swedish words that merely START with a unit letter', () {
      for (final heading in [
        'Gör så här', // the instruction header — \bg\b matched g before ö
        'Lök:', // \bl\b matched l before ö
        'Gäddan', // \bg\b matched g before ä
      ]) {
        expect(
          IngredientLineDetector.looksLikeIngredient(heading),
          isFalse,
          reason: heading,
        );
      }
    });

    // Recall controls, paired with the two negative groups above: the boundary
    // must still admit a one-letter unit that genuinely stands alone. None of
    // these may start with a digit, or the leading-quantity branch answers for
    // them and the control proves nothing about the boundary.
    test('still true for a real unit standing next to a Swedish word', () {
      expect(
        IngredientLineDetector.looksLikeIngredient('ca 2 l mjölk'),
        isTrue,
      );
      expect(IngredientLineDetector.looksLikeIngredient('en st kål'), isTrue);
      expect(
        IngredientLineDetector.looksLikeIngredient('ca 3 dl grädde'),
        isTrue,
      );
    });

    test('true when line starts with a digit', () {
      expect(IngredientLineDetector.looksLikeIngredient('2 äpplen'), isTrue);
      expect(IngredientLineDetector.looksLikeIngredient('15 minuter'), isTrue);
    });

    test('true when line starts with a Unicode fraction', () {
      expect(IngredientLineDetector.looksLikeIngredient('½ tomat'), isTrue);
      expect(IngredientLineDetector.looksLikeIngredient('¼ kopp'), isTrue);
      expect(IngredientLineDetector.looksLikeIngredient('¾ banan'), isTrue);
      expect(IngredientLineDetector.looksLikeIngredient('⅓ avokado'), isTrue);
    });

    test('false for plain prose without unit / leading digit', () {
      expect(
        IngredientLineDetector.looksLikeIngredient('Stek köttet i pannan'),
        isFalse,
      );
      expect(
        IngredientLineDetector.looksLikeIngredient('Häll i mjölken försiktigt'),
        isFalse,
      );
    });

    // The patterns are compiled case-SENSITIVE over lowercase tokens and the
    // subject is lowercased inside the method — an OCR/HTML line in caps must
    // still be recognised. No leading digit, so the unit loop is the only
    // branch that can answer.
    test('case-insensitive unit matching', () {
      expect(IngredientLineDetector.looksLikeIngredient('Ca DL Mjölk'), isTrue);
      expect(IngredientLineDetector.looksLikeIngredient('CA KG Kött'), isTrue);
      // …and the phantom-boundary rejection survives the same lowercasing.
      expect(IngredientLineDetector.looksLikeIngredient('RÖDKÅL'), isFalse);
    });
  });

  group('findIngredientLines', () {
    test('returns empty list for empty input', () {
      expect(IngredientLineDetector.findIngredientLines([]), isEmpty);
    });

    test('returns indices of matching lines, in input order', () {
      final lines = [
        'Recept för pasta',
        '2 dl mjölk',
        'Häll i mjölken i en kastrull',
        '500 g pasta',
        '½ tomat',
        '',
      ];
      expect(
        IngredientLineDetector.findIngredientLines(lines),
        [1, 3, 4],
      );
    });

    test('mixed content: prose and ingredient lines', () {
      final lines = [
        '1 kg potatis',
        'Skala potatisarna',
        '2 msk olja',
      ];
      expect(IngredientLineDetector.findIngredientLines(lines), [0, 2]);
    });

    // The user-visible symptom of BUT-1691: these indices become the
    // pre-ticked checkboxes in the user-assisted import wizard
    // (`url_import_strategy._createUserAssistedResult`). A Swedish heading
    // whose word merely ends or starts with a unit letter must not arrive
    // pre-selected, while the real lines around it must.
    test(
      'Swedish section headings are not pre-selected between ingredients',
      () {
        final lines = [
          'Rödkål:', // trailing-edge trap — \bl\b fired after å
          'ca 3 dl vinäger',
          'Gör så här', // leading-edge trap — \bg\b fired before ö
          'ca 2 msk salt',
        ];
        expect(IngredientLineDetector.findIngredientLines(lines), [1, 3]);
      },
    );
  });
}
